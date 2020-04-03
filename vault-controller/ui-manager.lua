local UiManager = {}
UiManager.__index = UiManager

local function clear()
	term.clear()
	term.setCursorPos(1, 1)
end

function UiManager.new(getGlobalIndex, menuManager, menuItemTypes, networkManager, updateOutputsForVault)
	local self = setmetatable(UiManager, {})

	self.getGlobalIndex = getGlobalIndex
	self.menuManager = menuManager
	self.menuItemTypes = menuItemTypes
	self.order = {}
	self.networkManager = networkManager
	self.updateOutputsForVault = updateOutputsForVault

	return self
end

function UiManager:getNormalizedIndex()
	local globalIndex = self.getGlobalIndex()

	-- Build a local index for all items across all storage units
	local totalIndex = {}
	for i,v in pairs(globalIndex) do
		for item, value in pairs(v.index) do
			if totalIndex[item] == nil then
				totalIndex[item] = value.count
			else
				totalIndex[item] = totalIndex[item] + value.count
			end
		end
	end

	local normalizedIndex = {}
	for i,v in pairs(totalIndex) do
		table.insert(normalizedIndex, { item = i, count = v })
	end

	return normalizedIndex
end

function UiManager:listItems(goBack)
	local page = 1

	local w,h = term.getSize()
	local pageSize = h - 4

	while true do
		local normalizedIndex = self:getNormalizedIndex()

		table.sort(normalizedIndex, function(a, b) return a.count > b.count end)
		local totalPages = math.ceil(#normalizedIndex / pageSize)

		-- Render the display
		clear()
		print("All items - item (count)")
		print()

		for i = ((page - 1) * pageSize) + 1, pageSize - 1 do
			local entry = normalizedIndex[i]
			if entry == nil then
				break
			end

			print(entry.item .. " (" .. entry.count .. ")")
		end

		term.setCursorPos(1, h)
		term.write("left/right - navigate, s - search, b - back")

		local timer = os.startTimer(2)

		-- Wait for input or wait for timer to refresh the page
		while true do
			local e, code = os.pullEvent()

			if e == "timer" and code == timer then
				break
			elseif e == "key" then
				if code == keys.b then
					return
				elseif code == keys.left and page > 1 then
					page = page - 1
					break
				elseif code == keys.right and page < totalPages then
					page = page + 1
					break
				elseif code == keys.s then
					self:displaySearch()
					break
				end
			end
		end
	end
end

function UiManager:displayItemScreen(itemEntry)
	local items = {
		{
			text = "Back",
			type = self.menuItemTypes.back,
		},
		{
			text = "Place all in cart",
			type = self.menuItemTypes.custom,
			action = function(goBack)
				self.order[itemEntry.item] = itemEntry.count
				goBack()
			end
		},
		{
			text = "Place some in cart",
			type = self.menuItemTypes.custom,
			action = function(goBack)
				clear()
				print(itemEntry.item)
				print()
				term.write("Enter quantity (" .. itemEntry.count .. " total): ")
				local quantity = tonumber(read())

				if quantity ~= nil and quantity <= itemEntry.count then
					self.order[itemEntry.item] = quantity
				end

				return goBack()
			end
		}
	}

	local menu = {
		title = "Options for " .. itemEntry.item .. " (" .. itemEntry.count .. ")",
		items = items
	}

	self.menuManager:registerMenu("item-options", menu)
	self.menuManager:display("item-options")
end

function UiManager:displaySearch()
	clear()
	print("Press enter to go back")
	print()

	term.write("Search for item: ")
	local search = read()

	if string.find(search, "^%s*$") ~= nil then
		return
	end

	local results = {}
	local normalizedIndex = self:getNormalizedIndex()

	table.insert(results, {
		text = "Back",
		type = self.menuItemTypes.back
	})

	for i,v in pairs(normalizedIndex) do
		if string.match(v.item, search) then
			table.insert(results, {
				text = v.item .. " (" .. v.count .. ")",
				type = self.menuItemTypes.custom,
				action = function(goBack)
					self:displayItemScreen(v)
				end
			})
		end
	end

	local menu = {
		title = "Results for \"" .. search .. "\"",
		items = results
	}

	self.menuManager:registerMenu("search-results", menu)
	self.menuManager:display("search-results")
end

function UiManager:placeOrder()
	local globalIndex = self.getGlobalIndex()

	local uniqueOutputs = {}
	for i,v in pairs(globalIndex) do
		for j, output in pairs(v.outputs) do
			if uniqueOutputs[output.name] == nil then
				uniqueOutputs[output.name] = {}
			end

			table.insert(uniqueOutputs[output.name], {
				turtleId = i,
				coords = output.coords,
			})
		end
	end

	local items = {}
	local selectedOutput = nil
	table.insert({
		text = "Back",
		type = self.menuItemTypes.back
	})
	for i,v in pairs(uniqueOutputs) do
		table.insert(items, {
			text = i,
			type = self.menuItemTypes.custom,
			action = function()
				selectedOutput = v
			end
		})
	end

	local menu = {
		title = "Select output",
		items = items,
	}

	self.menuManager:registerMenu("place-order-select-output", menu)
	self.menuManager:display("place-order-select-output")

	if selectedOutput == nil then
		return
	end

	local orderRemaining = {}
	for i,v in pairs(self.order) do
		orderRemaining[i] = self.order[i]
	end
	local turtleOrders = {}

	for i,v in pairs(selectedOutput) do
		local vault = globalIndex[v.turtleId]
		local itemsForTurtle = {}

		for name, entry in pairs(vault.index) do
			if orderRemaining[name] ~= nil and orderRemaining[name] > 0 then
				local countForTurtle = 0
				if entry.count > orderRemaining[name] then
					countForTurtle = orderRemaining[name]
					orderRemaining[name] = 0
				else
					countForTurtle = entry.count
					orderRemaining[name] = orderRemaining[name] - entry.count
				end

				table.insert(itemsForTurtle, {
					item = name,
					count = countForTurtle,
				})
			end
		end

		if #itemsForTurtle ~= 0 then
			turtleOrders[v.turtleId] = {
				command = "pickup",
				order = itemsForTurtle,
				output = v.coords
			}
		end
	end

	for i,v in pairs(turtleOrders) do
		self.networkManager:send(i, v)
	end

	self.order = {}

	clear()
	print("Order is placed! It should arrive shortly")
	print()
	print("Press enter to continue")
	read()
end

function UiManager:displayCart()
	clear()
	print("Place order? Y = yes, N = no")
	print()

	local count = 0
	for i,v in pairs(self.order) do
		count = count + 1
		print(i .. " (" .. v .. ")")
	end

	if count == 0 then
		print("Your cart is empty")
	end

	while true do
		local e, code = os.pullEvent("key")

		if code == keys.y then
			self:placeOrder()
			break
		elseif code == keys.n then
			break
		end
	end
end

function UiManager:displayVault(turtleId)
	local vault = self.getGlobalIndex()[turtleId]

	if vault == nil then
		return
	end

	local items = {
		{
			text = "Back",
			type = self.menuItemTypes.back,
		},
		{
			text = "Show outputs",
			type = self.menuItemTypes.custom,
			action = function()
				clear()

				if #vault.outputs == 0 then
					print("No outputs")
				end

				for i,v in pairs(vault.outputs) do
					print(v.name .. " (" .. v.coords.x .. ", " .. v.coords.y .. ")")
				end
				print()
				print("Press enter to continue")
				read()
			end
		},
		{
			text = "Delete output",
			type = self.menuItemTypes.custom,
			action = function()
				clear()

				if #vault.outputs == 0 then
					print("No outputs. Press enter to continue")
					read()
				end

				local output, i = self:selectOutput(vault.outputs)
				if output ~= nil then
					table.remove(vault.outputs, i)
				end

				self.updateOutputsForVault(turtleId, vault.outputs)
			end
		},
		{
			text = "Add output",
			type = self.menuItemTypes.custom,
			action = function(goBack)
				clear()

				print("Enter relative vault coordinates")
				term.write("X: ")
				local x = tonumber(read())

				if x == nil then
					print("Invalid input, press enter to continue")
					read()
					return
				end

				term.write("Y: ")
				local y = tonumber(read())

				if y == nil then
					print("Invalid input, press enter to continue")
					read()
					return
				end

				print()
				print()

				term.write("Enter name: ")
				local name = read()

				local output = {
					name = name,
					coords = {
						x = x,
						y = y
					}
				}

				table.insert(vault.outputs, output)

				self.updateOutputsForVault(turtleId, vault.outputs)
			end
		}
	}

	local menu = {
		title = "Vault for turtle " .. turtleId,
		items = items
	}

	self.menuManager:registerMenu("display-vault", menu)
	self.menuManager:display("display-vault")
end

function UiManager:selectOutput(outputs)
	local selectedOutput = nil
	local selectionIndex = nil
	local items = {}

	table.insert(items, {
		text = "Back",
		type = self.menuItemTypes.back,
	})

	for i,v in pairs(outputs) do
		table.insert(items, {
			text = v.name .. " (" .. v.coords.x .. ", " .. v.coords.y .. ")",
			type = self.menuItemTypes.custom,
			action = function(goBack)
				selectedOutput = v
				selectionIndex = i
				goBack()
			end
		})
	end

	self.menuManager:registerMenu("select-output", {
		title = "Select output",
		items = items
	})
	self.menuManager:display("select-output")

	return selectedOutput, selectionIndex
end

function UiManager:listVaults()
	local globalIndex = self.getGlobalIndex()

	local items = {}
	table.insert(items, {
		text = "Back",
		type = self.menuItemTypes.back
	})
	for i,v in pairs(globalIndex) do
		table.insert(items, {
			text = "Turtle " .. i,
			type = self.menuItemTypes.custom,
			action = function()
				self:displayVault(i)
			end
		})
	end

	self.menuManager:registerMenu("list-vaults", {
		title = "Vaults",
		items = items
	})
	self.menuManager:display("list-vaults")
end

return UiManager
