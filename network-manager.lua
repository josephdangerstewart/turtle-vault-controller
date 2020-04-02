local NetworkManager = {}
NetworkManager.__index = NetworkManager

function NetworkManager.new(profile, registerTurtle, updateIndexForTurtle)
	local self = setmetatable(NetworkManager, {})

	local isModemFound = false
	for i,v in pairs(peripheral.getNames()) do
		if peripheral.getType(v) == "modem" then
			rednet.open(v)
			isModemFound = true
		end
	end

	if not isModemFound then
		error("No modem found")
		return false
	end

	self.registerTurtle = registerTurtle
	self.messageQueue = {}
	self.turtlePollingMap = {}
	self.updateIndexForTurtle = updateIndexForTurtle

	for i,v in pairs(profile.globalIndex) do
		self.turtlePollingMap[i] = true
	end

	return self
end

function NetworkManager:listen()
	local id, msg = rednet.receive()

	if msg == nil then
		return
	end

	local data = textutils.unserialise(msg)
	local command = data.command

	if command == "register" then
		self.turtlePollingMap[id] = true
		self.registerTurtle(id, data.roomSize)
	elseif command == "set-polling" then
		self:setPolling(id, command.value)
	elseif command == "index" then
		self.updateIndexForTurtle(id, data.index)
	end
end

function NetworkManager:setPolling(id, value)
	self.turtlePollingMap[id] = value

	-- If we are marking this turtle as available, flush the message queue
	if value and #self.messageQueue[id] > 0 then
		rednet.send(id, textutils.serialise({
			command = "batch-message",
			messages = self.messageQueue[id]
		}))
	end
end

function NetworkManager:send(id, data)
	if self.turtlePollingMap[id] then
		table.insert(self.messageQueue[id], data)
		return
	end

	rednet.send(id, textutils.serialise(data))
end

return NetworkManager
