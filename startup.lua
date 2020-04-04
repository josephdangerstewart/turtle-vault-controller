local NetworkManager = dofile("vault-controller/network-manager.lua")
local MenuManager = dofile("vault-controller/menu-manager.lua")
local UiManager = dofile("vault-controller/ui-manager.lua")

local defaultProfileModel = {
	globalIndex = {}
}

if not fs.exists("profile.data") then
	local file = fs.open("profile.data", "w")
	file.write(textutils.serialise(defaultProfileModel))
	file.close()
end

local file = fs.open("profile.data", "r")
local profile = textutils.unserialise(file.readAll())
file.close()

local function registerTurtle(id, roomSize)
	profile.globalIndex[id] = {
		roomSize = roomSize,
		outputs = {},
		index = {}
	}

	local pFile = fs.open("profile.data", "w")
	pFile.write(textutils.serialise(profile))
	pFile.close()
end

local function getGlobalIndex()
	return profile.globalIndex
end

local function updateIndexForTurtle(id, index)
	if profile.globalIndex[id] == nil then
		return
	end

	profile.globalIndex[id].index = index

	local pFile = fs.open("profile.data", "w")
	pFile.write(textutils.serialise(profile))
	pFile.close()
end

local function updateOutputsForVault(id, outputs)
	if profile.globalIndex[id] == nil then
		return
	end

	profile.globalIndex[id].outputs = outputs

	local pFile = fs.open("profile.data", "w")
	pFile.write(textutils.serialise(profile))
	pFile.close()
end

local function refreshIndex()
	for i,v in pairs(profile.globalIndex) do
		networkManager:getIndexUpdate(i)
	end
end

networkManager = NetworkManager.new(profile, registerTurtle, updateIndexForTurtle)
local menuManager = MenuManager.new()
local uiManager = UiManager.new(getGlobalIndex, menuManager, MenuManager.itemTypes, networkManager, updateOutputsForVault)

local mainMenu = {
	title = "Turtle Vault",
	showHelp = true,
	items = {
		{
			text = "List items",
			type = MenuManager.itemTypes.custom,
			action = function()
				uiManager:listItems()
			end
		},
		{
			text = "Search items",
			type = MenuManager.itemTypes.custom,
			action = function()
				uiManager:displaySearch()
			end,
		},
		{
			text = "Your cart",
			type = MenuManager.itemTypes.custom,
			action = function()
				uiManager:displayCart()
			end
		},
		{
			text = "Refresh index",
			type = MenuManager.itemTypes.custom,
			action = function()
				refreshIndex()
			end
				
		},
		{
			text = "List vaults",
			type = MenuManager.itemTypes.custom,
			action = function()
				uiManager:listVaults()
			end
		},
	},
}

menuManager:registerMenu("main", mainMenu)

local function networkLoop()
	while true do
		networkManager:listen()
	end
end

local function displayLoop()
	refreshIndex()

	while true do
		menuManager:display("main")
	end
end

parallel.waitForAll(networkLoop, displayLoop)
