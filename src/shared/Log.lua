--[[
	Log
	---
	Levelled logging with a ring buffer.

	The original script printed emoji straight to the console from a dozen
	call sites, which made it impossible to silence, filter, or surface
	messages inside the GUI. Everything now flows through here:

		Log.info("plot", "found %s at %d studs", plot.Name, dist)

	* `Log.level` gates what reaches the console.
	* `Log.history` keeps the last N records so the UI can show a status line
	  or a debug pane without re-plumbing every call site.
	* `Log.onMessage` lets one listener (the GUI) mirror output.
]]

local Config = require(script.Parent.Config)

local Log = {}

Log.Level = {
	TRACE = 10,
	DEBUG = 20,
	INFO = 30,
	WARN = 40,
	ERROR = 50,
	NONE = 100,
}

local LEVEL_NAME = {
	[Log.Level.TRACE] = "TRACE",
	[Log.Level.DEBUG] = "DEBUG",
	[Log.Level.INFO] = "INFO",
	[Log.Level.WARN] = "WARN",
	[Log.Level.ERROR] = "ERROR",
}

Log.level = Log.Level.INFO
Log.history = {}
Log.historyLimit = 200
Log.onMessage = nil

local function timestamp()
	local ok, clock = pcall(os.clock)
	return ok and clock or 0
end

--- Formats safely: a stray `%` in user data must never error the caller.
local function safeFormat(message, ...)
	if select("#", ...) == 0 then
		return message
	end
	local ok, formatted = pcall(string.format, message, ...)
	return ok and formatted or message
end

local function record(level, scope, message, ...)
	local text = safeFormat(message, ...)
	local entry = {
		level = level,
		levelName = LEVEL_NAME[level] or "LOG",
		scope = scope or "app",
		message = text,
		clock = timestamp(),
	}

	local history = Log.history
	history[#history + 1] = entry
	if #history > Log.historyLimit then
		table.remove(history, 1)
	end

	if level >= Log.level then
		local line = string.format("[%s][%s] %s", Config.APP_NAME, entry.scope, text)
		if level >= Log.Level.ERROR then
			pcall(warn, line)
		else
			pcall(print, line)
		end
	end

	if Log.onMessage then
		pcall(Log.onMessage, entry)
	end

	return entry
end

function Log.trace(scope, message, ...)
	return record(Log.Level.TRACE, scope, message, ...)
end

function Log.debug(scope, message, ...)
	return record(Log.Level.DEBUG, scope, message, ...)
end

function Log.info(scope, message, ...)
	return record(Log.Level.INFO, scope, message, ...)
end

function Log.warn(scope, message, ...)
	return record(Log.Level.WARN, scope, message, ...)
end

function Log.error(scope, message, ...)
	return record(Log.Level.ERROR, scope, message, ...)
end

--- Clears the ring buffer (used by tests).
function Log.clear()
	table.clear(Log.history)
end

return Log
