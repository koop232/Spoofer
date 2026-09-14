--[[
	Transport
	---------
	Pluggable delivery channels for sync payloads.

	IMPORTANT CORRECTNESS NOTE
	--------------------------
	The original script created folders and set attributes on ReplicatedStorage
	and Workspace *from the client*. Client-created instances and client-set
	attributes DO NOT replicate to the server, and therefore never reach a
	second player's client. That transport can only ever work when both scripts
	run inside the same client.

	Genuine cross-client delivery requires the server to relay the message, so
	the only honest options are:

	  * Global    - same machine, two script tabs. Always reliable.
	  * Folder    - same client, survives script restarts. Legacy compatible.
	  * Remote    - fires an existing game RemoteEvent so the SERVER relays it.
	                Works across machines only if the game happens to expose a
	                remote that echoes arbitrary data to other players. Most
	                games do not, and firing unknown remotes is detectable.

	`Transport.remote` therefore probes for a candidate, reports honestly
	whether it found one, and never pretends to have delivered anything.
]]

local Config = require(script.Parent.Config)
local Env = require(script.Parent.Env)
local Log = require(script.Parent.Log)
local Protocol = require(script.Parent.Protocol)

local Transport = {}

------------------------------------------------------------------------------
-- Global transport: shared getgenv() table, same machine only.
------------------------------------------------------------------------------

local Global = {}
Global.__index = Global
Global.id = "global"
Global.crossClient = false

function Global.new()
	return setmetatable({}, Global)
end

function Global:isAvailable()
	return true
end

function Global:send(payload)
	local globals = Env.globals()
	local bucket = globals[Config.Sync.GlobalKey]
	if type(bucket) ~= "table" then
		bucket = { listeners = {} }
		globals[Config.Sync.GlobalKey] = bucket
	end
	bucket.latest = payload

	for _, listener in ipairs(bucket.listeners) do
		pcall(listener, payload)
	end
	return true
end

function Global:subscribe(handler)
	local globals = Env.globals()
	local bucket = globals[Config.Sync.GlobalKey]
	if type(bucket) ~= "table" then
		bucket = { listeners = {} }
		globals[Config.Sync.GlobalKey] = bucket
	end

	table.insert(bucket.listeners, handler)

	-- Replay whatever the admin already published so a late tester catches up.
	if bucket.latest then
		pcall(handler, bucket.latest)
	end

	return function()
		for index, candidate in ipairs(bucket.listeners) do
			if candidate == handler then
				table.remove(bucket.listeners, index)
				break
			end
		end
	end
end

Transport.Global = Global

------------------------------------------------------------------------------
-- Folder transport: attributes on a ReplicatedStorage folder.
------------------------------------------------------------------------------

local Folder = {}
Folder.__index = Folder
Folder.id = "folder"
Folder.crossClient = false

function Folder.new()
	return setmetatable({ _connections = {} }, Folder)
end

function Folder:_folder()
	local parent = Env.ReplicatedStorage
	if not parent then
		return nil
	end
	local existing = parent:FindFirstChild(Config.Sync.Channel)
	if existing then
		return existing
	end
	local ok, created = pcall(function()
		local folder = Instance.new("Folder")
		folder.Name = Config.Sync.Channel
		folder.Parent = parent
		return folder
	end)
	return ok and created or nil
end

function Folder:isAvailable()
	return self:_folder() ~= nil
end

function Folder:send(payload)
	local folder = self:_folder()
	if not folder then
		return false
	end
	local attributes = Protocol.toAttributes(payload)
	for key, value in pairs(attributes) do
		pcall(folder.SetAttribute, folder, key, value)
	end
	return true
end

function Folder:subscribe(handler)
	local folder = self:_folder()
	if not folder then
		return function() end
	end

	local function emit()
		local attributes = {}
		local ok, map = pcall(folder.GetAttributes, folder)
		if ok and type(map) == "table" then
			for key, value in pairs(map) do
				attributes[key] = value
			end
		end
		local payload = Protocol.fromAttributes(attributes)
		if payload then
			pcall(handler, payload)
		end
	end

	local connection = folder:GetAttributeChangedSignal("Sequence"):Connect(emit)
	table.insert(self._connections, connection)

	emit()

	return function()
		pcall(function()
			connection:Disconnect()
		end)
	end
end

Transport.Folder = Folder

------------------------------------------------------------------------------
-- Remote transport: relay through a server owned RemoteEvent.
------------------------------------------------------------------------------

local Remote = {}
Remote.__index = Remote
Remote.id = "remote"
Remote.crossClient = true

function Remote.new()
	return setmetatable({ _cached = nil, _searched = false }, Remote)
end

--- Breadth-first hunt for a RemoteEvent whose name matches a configured hint.
function Remote:_discover()
	if self._searched then
		return self._cached
	end
	self._searched = true

	local root = Env.ReplicatedStorage
	if not root then
		return nil
	end

	local queue = { { node = root, depth = 0 } }
	local head = 1

	while head <= #queue do
		local item = queue[head]
		head = head + 1

		local ok, children = pcall(item.node.GetChildren, item.node)
		if ok then
			for _, child in ipairs(children) do
				local isRemote = false
				pcall(function()
					isRemote = child:IsA("RemoteEvent")
				end)

				if isRemote then
					for _, hint in ipairs(Config.Sync.RemoteHints) do
						if child.Name == hint then
							self._cached = child
							Log.info("sync", "remote transport bound to %s", child:GetFullName())
							return child
						end
					end
				elseif item.depth < Config.Sync.RemoteSearchDepth then
					queue[#queue + 1] = { node = child, depth = item.depth + 1 }
				end
			end
		end
	end

	Log.warn("sync", "no relay RemoteEvent found; cross-client sync unavailable")
	return nil
end

function Remote:isAvailable()
	return self:_discover() ~= nil
end

function Remote:send(payload)
	local remote = self:_discover()
	if not remote then
		return false
	end
	local ok = pcall(function()
		remote:FireServer(Config.Sync.Channel, payload)
	end)
	if not ok then
		Log.warn("sync", "remote FireServer failed")
	end
	return ok
end

function Remote:subscribe(handler)
	local remote = self:_discover()
	if not remote then
		return function() end
	end

	local connection = remote.OnClientEvent:Connect(function(channel, payload)
		if channel == Config.Sync.Channel then
			pcall(handler, payload)
		end
	end)

	return function()
		pcall(function()
			connection:Disconnect()
		end)
	end
end

Transport.Remote = Remote

------------------------------------------------------------------------------

--- Builds the default transport stack, best delivery guarantee first.
function Transport.defaults()
	return { Remote.new(), Global.new(), Folder.new() }
end

return Transport
