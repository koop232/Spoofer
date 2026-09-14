--[[
	Protocol
	--------
	Pure payload construction and validation for the admin -> tester link.

	Keeping this free of Roblox types means every rule (revision checks,
	staleness, replay rejection, slot validation) is unit tested offline.

	Wire shape:
		{
			protocol = 2,          -- integer, must match Config.Sync.Protocol
			slot     = "Main",     -- one of Config.Slots
			brainrot = "Griffin",  -- name; "" clears the slot
			sequence = 17,         -- monotonic per session, rejects replays
			session  = "a1b2c3",   -- identifies the broadcasting admin
			sentAt   = 1234.5,     -- sender clock, used for staleness display
		}
]]

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local Protocol = {}

Protocol.REVISION = Config.Sync.Protocol

--- Builds a well formed payload. `sequence` must increase per session.
function Protocol.encode(slot, brainrot, sequence, session, sentAt)
	return {
		protocol = Protocol.REVISION,
		slot = slot,
		brainrot = brainrot or "",
		sequence = sequence,
		session = session,
		sentAt = sentAt,
	}
end

--- Validates an inbound payload.
--- Returns `true, payload` or `false, reason`.
function Protocol.validate(payload)
	if type(payload) ~= "table" then
		return false, "payload is not a table"
	end

	if payload.protocol ~= Protocol.REVISION then
		return false, string.format(
			"protocol mismatch (got %s, want %d)",
			tostring(payload.protocol),
			Protocol.REVISION
		)
	end

	if type(payload.slot) ~= "string" or not Util.contains(Config.Slots, payload.slot) then
		return false, "unknown slot " .. tostring(payload.slot)
	end

	if type(payload.brainrot) ~= "string" then
		return false, "brainrot must be a string"
	end

	-- An empty name is the documented "clear this slot" instruction.
	if payload.brainrot ~= "" and not Config.BrainrotSet[payload.brainrot] then
		return false, "unknown brainrot " .. payload.brainrot
	end

	if type(payload.sequence) ~= "number" or payload.sequence < 0 then
		return false, "sequence must be a non-negative number"
	end

	if type(payload.session) ~= "string" or payload.session == "" then
		return false, "missing session id"
	end

	return true, payload
end

--- Decides whether `payload` supersedes what we already applied.
--- `state` is a table of { session = string?, sequence = number? }.
function Protocol.isNewer(state, payload)
	if not state or state.session ~= payload.session then
		-- A different admin took over; always accept the first message.
		return true
	end
	return payload.sequence > (state.sequence or -1)
end

--- True when the payload is older than Config.Behaviour.StaleAfter.
function Protocol.isStale(payload, now)
	if type(payload) ~= "table" or type(payload.sentAt) ~= "number" then
		return true
	end
	return (now - payload.sentAt) > Config.Behaviour.StaleAfter
end

--- Flattens a payload into the attribute pairs used by the folder transport.
function Protocol.toAttributes(payload)
	return {
		Protocol = payload.protocol,
		Slot = payload.slot,
		Brainrot = payload.brainrot,
		Sequence = payload.sequence,
		Session = payload.session,
		SentAt = payload.sentAt,
	}
end

--- Inverse of `toAttributes`.
function Protocol.fromAttributes(attributes)
	if type(attributes) ~= "table" then
		return nil
	end
	return {
		protocol = attributes.Protocol,
		slot = attributes.Slot,
		brainrot = attributes.Brainrot,
		sequence = attributes.Sequence,
		session = attributes.Session,
		sentAt = attributes.SentAt,
	}
end

--- Short random session identifier, no HttpService dependency.
function Protocol.newSessionId()
	local chars = "0123456789abcdef"
	local out = {}
	for index = 1, 8 do
		local pick = math.random(1, #chars)
		out[index] = chars:sub(pick, pick)
	end
	return table.concat(out)
end

return Protocol
