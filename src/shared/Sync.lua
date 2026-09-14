--[[
	Sync
	----
	Fans a payload out across every available transport and, on the receiving
	end, de-duplicates what comes back in.

	The admin publishes; the tester subscribes. Both sides share this object so
	the sequencing and replay rules live in exactly one place.
]]

local Config = require(script.Parent.Config)
local Env = require(script.Parent.Env)
local Log = require(script.Parent.Log)
local Protocol = require(script.Parent.Protocol)
local Signal = require(script.Parent.Signal)
local Transport = require(script.Parent.Transport)

local Sync = {}
Sync.__index = Sync

function Sync.new(options)
	options = options or {}

	local self = setmetatable({
		transports = options.transports or Transport.defaults(),
		session = options.session or Protocol.newSessionId(),
		clock = options.clock or Env.now,
		_sequence = 0,
		_last = nil,
		_applied = { session = nil, sequence = -1 },
		_unsubscribers = {},
		_heartbeat = nil,
		received = Signal.new("sync.received"),
		rejected = Signal.new("sync.rejected"),
	}, Sync)

	return self
end

--- Transports that reported themselves usable, cheapest check first.
function Sync:activeTransports()
	local active = {}
	for _, transport in ipairs(self.transports) do
		local ok, available = pcall(transport.isAvailable, transport)
		if ok and available then
			active[#active + 1] = transport
		end
	end
	return active
end

--- True when at least one transport can reach another machine.
function Sync:hasCrossClient()
	for _, transport in ipairs(self:activeTransports()) do
		if transport.crossClient then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Publishing
------------------------------------------------------------------------------

--- Publishes a slot assignment. Returns the payload and a delivery report.
function Sync:publish(slot, brainrot)
	self._sequence = self._sequence + 1

	local payload = Protocol.encode(
		slot,
		brainrot,
		self._sequence,
		self.session,
		self.clock()
	)

	local ok, reason = Protocol.validate(payload)
	if not ok then
		Log.error("sync", "refusing to publish invalid payload: %s", reason)
		return nil, { delivered = 0, attempted = 0 }
	end

	self._last = payload
	return payload, self:_deliver(payload)
end

function Sync:_deliver(payload)
	local report = { delivered = 0, attempted = 0, byTransport = {} }

	for _, transport in ipairs(self.transports) do
		local available = select(2, pcall(transport.isAvailable, transport))
		if available then
			report.attempted = report.attempted + 1
			local sent = select(2, pcall(transport.send, transport, payload))
			report.byTransport[transport.id] = sent and true or false
			if sent then
				report.delivered = report.delivered + 1
			end
		end
	end

	if report.delivered == 0 then
		Log.warn("sync", "payload reached no transport")
	else
		Log.debug("sync", "published %s=%s via %d transport(s)",
			payload.slot, payload.brainrot, report.delivered)
	end

	return report
end

--- Re-sends the most recent payload so late joiners converge.
function Sync:republish()
	if not self._last then
		return false
	end
	self._last.sentAt = self.clock()
	self:_deliver(self._last)
	return true
end

--- Starts a background heartbeat that keeps republishing `_last`.
function Sync:startHeartbeat(interval)
	if self._heartbeat then
		return
	end
	interval = interval or Config.Behaviour.HeartbeatInterval
	self._heartbeat = true

	task.spawn(function()
		while self._heartbeat do
			task.wait(interval)
			if self._heartbeat then
				pcall(function()
					self:republish()
				end)
			end
		end
	end)
end

function Sync:stopHeartbeat()
	self._heartbeat = nil
end

------------------------------------------------------------------------------
-- Receiving
------------------------------------------------------------------------------

--- Runs an inbound payload through validation + replay rules.
--- Returns true when it was accepted and the `received` signal fired.
function Sync:ingest(payload)
	local ok, reasonOrPayload = Protocol.validate(payload)
	if not ok then
		self.rejected:fire(payload, reasonOrPayload)
		Log.trace("sync", "rejected payload: %s", reasonOrPayload)
		return false
	end

	-- Never react to our own broadcast.
	if payload.session == self.session then
		return false
	end

	if not Protocol.isNewer(self._applied, payload) then
		return false
	end

	self._applied = { session = payload.session, sequence = payload.sequence }
	self._last = payload
	self.received:fire(payload)
	return true
end

--- Subscribes to every available transport. Returns a disconnect function.
function Sync:listen()
	self:disconnect()

	for _, transport in ipairs(self.transports) do
		local available = select(2, pcall(transport.isAvailable, transport))
		if available then
			local ok, unsubscribe = pcall(transport.subscribe, transport, function(payload)
				self:ingest(payload)
			end)
			if ok and type(unsubscribe) == "function" then
				table.insert(self._unsubscribers, unsubscribe)
			end
		end
	end

	Log.info("sync", "listening on %d transport(s)", #self._unsubscribers)

	return function()
		self:disconnect()
	end
end

function Sync:disconnect()
	for _, unsubscribe in ipairs(self._unsubscribers) do
		pcall(unsubscribe)
	end
	table.clear(self._unsubscribers)
end

--- Most recently published or accepted payload.
function Sync:last()
	return self._last
end

--- True when nothing has arrived recently.
function Sync:isStale()
	if not self._last then
		return true
	end
	return Protocol.isStale(self._last, self.clock())
end

function Sync:destroy()
	self:stopHeartbeat()
	self:disconnect()
	self.received:destroy()
	self.rejected:destroy()
end

return Sync
