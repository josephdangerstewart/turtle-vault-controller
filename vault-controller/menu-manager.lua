local MenuManager = {}
MenuManager.__index = MenuManager

MenuManager.itemTypes = {
	menu = "menu",
	back = "back",
	custom = "custom"
}

local function clear()
	term.clear()
	term.setCursorPos(1, 1)
end

function MenuManager.new()
	local self = setmetatable(MenuManager, {})

	self.menus = {}
	self.cursorPositions = {}

	return self
end

function MenuManager:registerMenu(name, menu)
	self.menus[name] = menu
	self.cursorPositions[name] = 1
end

local function renderMenu(menu, cursorPosition)
	local title = menu.title
	local items = menu.items
	local showHelp = menu.showHelp or false
	local helpText = menu.helpText or "Use up/down to navigate and press enter to select"
	local w, h = term.getSize()

	-- Render
	clear()

	print(title)
	print()

	for i,v in pairs(items) do
		local text = v.text
		if cursorPosition == i then
			text = "> " .. text
		else
			text = "  " .. text
		end

		print(text)
	end

	if showHelp then
		term.setCursorPos(1, h)
		term.write(helpText)
	end
end

--[[
	Sample menu structure

	menuManager:registerMenu(
		"sample",
		{
			title = "Sample Menu",
			showHelp = true,
			items = {
				{
					type = MenuManager.itemTypes.custom,
					text = "Do a thing",
					action = function(goBack) doThing() goBack() end
				},
			}
		}
	)
]]

function MenuManager:display(name)
	local menu = self.menus[name]

	if menu == nil then
		return false
	end

	while true do
		if self.cursorPositions[name] > #menu.items then
			self.cursorPositions[name] = #menu.items
		elseif self.cursorPositions[name] < 1 then
			self.cursorPositions[name] = 1
		end

		renderMenu(menu, self.cursorPositions[name])

		local e, key = os.pullEvent("key")

		if key == keys.up then
			local next = self.cursorPositions[name] - 1
			if next < 1 then
				next = #menu.items
			end
			self.cursorPositions[name] = next
		elseif key == keys.down then
			local next = self.cursorPositions[name] + 1
			if next > #menu.items then
				next = 1
			end
			self.cursorPositions[name] = next
		elseif key == keys.enter then
			local shouldContinueLoop = false
			local item = menu.items[self.cursorPositions[name]]

			if item.type == MenuManager.itemTypes.menu then
				shouldContinueLoop = self:display(item.menu)
			elseif item.type == MenuManager.itemTypes.back then
				return true
			elseif item.type == MenuManager.itemTypes.custom then
				local goBackSignal = false
				item.action(function() goBackSignal = true end)
				if goBackSignal then
					return true
				end
			end

			if not shouldContinueLoop then
				return false
			end
		end
	end
end

return MenuManager
