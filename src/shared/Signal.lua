--[[
	Signal
	------
	Minimal observer used to decouple the controllers from the GUI. Listeners
	are isolated with pcall so one broken handler cannot stop the rest.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new(name)
	return setmetatable({
		_name = name or "signal",
		_handlers = {},
	}, Signal)
end

--- Registers `handler`; returns a disconnect function.
function Signal:connect(handler)
	assert(type(handler) == "function", "Signal:connect expects a function")
	local handlers = self._handlers
	handlers[#handlers + 1] = handler

	return function()
		for index, candidate in ipairs(handlers) do
			if candidate == handler then
				table.remove(handlers, index)
				break
			end
		end
	end
end

--- Calls every listener. Errors are swallowed and returned as a count.
function Signal:fire(...)
	local failures = 0
	-- Iterate a copy so a listener may disconnect during dispatch.
	local snapshot = {}
	for index, value in ipairs(self._handlers) do
		snapshot[index] = value
	end

	for _, handler in ipairs(snapshot) do
		local ok = pcall(handler, ...)
		if not ok then
			failures = failures + 1
		end
	end
	return failures
end

function Signal:destroy()
	table.clear(self._handlers)
end

return Signal
