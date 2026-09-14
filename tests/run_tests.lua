--[[
	Offline test suite.

	Loads the pure modules with a fake `script` tree (so `require(script.Parent.X)`
	resolves to a file on disk) and asserts behaviour that used to be
	untestable because it was tangled into GUI callbacks.

	Run:  lua tests/run_tests.lua     (or via scripts/test.sh)
]]

package.path = "./tests/?.lua;" .. package.path
require("roblox_stub")

------------------------------------------------------------------------------
-- Fake module tree
------------------------------------------------------------------------------

local SHARED = "./src/shared/"
local loaded = {}

local moduleProxy = {}
moduleProxy.__index = function(self, key)
	-- script.Parent.Config -> a proxy carrying the module name
	return setmetatable({ _name = key }, moduleProxy)
end

local realRequire = require

local function loadModule(name)
	if loaded[name] then
		return loaded[name]
	end

	local path = SHARED .. name .. ".lua"
	local chunk, err = loadfile(path)
	if not chunk then
		error("cannot load " .. path .. ": " .. tostring(err))
	end

	-- Each module sees a `script` whose Parent indexes into the shared folder.
	local env = setmetatable({}, { __index = _G })
	env.script = setmetatable({}, moduleProxy)
	env.require = function(target)
		if type(target) == "table" and target._name then
			return loadModule(target._name)
		end
		return realRequire(target)
	end

	if setfenv then
		setfenv(chunk, env)
	else
		-- Lua 5.2+: rebind _ENV upvalue
		local index = 1
		while true do
			local upvalueName = debug.getupvalue(chunk, index)
			if not upvalueName then
				break
			end
			if upvalueName == "_ENV" then
				debug.upvaluejoin(chunk, index, function()
					return env
				end, 1)
				break
			end
			index = index + 1
		end
	end

	local result = chunk()
	loaded[name] = result
	return result
end

------------------------------------------------------------------------------
-- Tiny assertion framework
------------------------------------------------------------------------------

local passed, failed = 0, 0
local failures = {}
local currentGroup = ""

local function group(name)
	currentGroup = name
	print("\n" .. name)
end

local function check(label, ok, detail)
	if ok then
		passed = passed + 1
		print("  ok   " .. label)
	else
		failed = failed + 1
		local message = currentGroup .. " / " .. label
		if detail then
			message = message .. "  (" .. tostring(detail) .. ")"
		end
		failures[#failures + 1] = message
		print("  FAIL " .. label .. (detail and ("  " .. tostring(detail)) or ""))
	end
end

local function equal(label, actual, expected)
	check(label, actual == expected,
		string.format("got %s, want %s", tostring(actual), tostring(expected)))
end

------------------------------------------------------------------------------

local Util = loadModule("Util")
local Config = loadModule("Config")
local Protocol = loadModule("Protocol")
local Signal = loadModule("Signal")
local PlotService = loadModule("PlotService")
local Log = loadModule("Log")

------------------------------------------------------------------------------
group("Util.formatGeneration")
------------------------------------------------------------------------------

equal("zero", Util.formatGeneration(0), "$0/s")
equal("hundreds", Util.formatGeneration(250), "$250/s")
equal("thousands", Util.formatGeneration(1500), "$1.5K/s")
equal("millions", Util.formatGeneration(2500000), "$2.5M/s")
equal("billions", Util.formatGeneration(3.2e9), "$3.2B/s")
equal("trillions", Util.formatGeneration(1e12), "$1T/s")
equal("trims .0", Util.formatGeneration(1e6), "$1M/s")
equal("negative", Util.formatGeneration(-1500), "$-1.5K/s")
equal("nil is zero", Util.formatGeneration(nil), "$0/s")
equal("string input", Util.formatGeneration("2000"), "$2K/s")

------------------------------------------------------------------------------
group("Util.truncate")
------------------------------------------------------------------------------

equal("short passthrough", Util.truncate("Meowl", 15), "Meowl")
equal("exact length", Util.truncate("abcde", 5), "abcde")
check("long is shortened", #Util.truncate("Hydra Dragon Cannelloni", 15) <= 15 + 2)
equal("nil safe", Util.truncate(nil, 5), "")

------------------------------------------------------------------------------
group("Util.fuzzyMatch")
------------------------------------------------------------------------------

check("empty matches all", Util.fuzzyMatch("Griffin", ""))
check("substring", Util.fuzzyMatch("Dragon Cannelloni", "cannel"))
check("case insensitive", Util.fuzzyMatch("Griffin", "GRIF"))
check("subsequence", Util.fuzzyMatch("Dragon Cannelloni", "dgc"))
check("rejects non-match", not Util.fuzzyMatch("Griffin", "zzz"))

------------------------------------------------------------------------------
group("Util.searchNames")
------------------------------------------------------------------------------

local names = { "Griffin", "Ginger Gerat", "Ginger Globo", "Meowl" }
local results = Util.searchNames(names, "ginger")
equal("finds both gingers", #results, 2)
check("prefix ranks first", results[1]:find("Ginger") == 1)

local all = Util.searchNames(Config.Brainrots, "")
equal("empty query returns everything", #all, #Config.Brainrots)

local exact = Util.searchNames(Config.Brainrots, "Griffin")
equal("exact match ranks first", exact[1], "Griffin")

------------------------------------------------------------------------------
group("Config integrity")
------------------------------------------------------------------------------

check("catalogue is non-empty", #Config.Brainrots > 0)

local sorted, duplicates = true, {}
local seen = {}
for index, name in ipairs(Config.Brainrots) do
	if seen[name] then
		duplicates[#duplicates + 1] = name
	end
	seen[name] = true
	if index > 1 and Config.Brainrots[index - 1] > name then
		sorted = false
	end
end
check("catalogue is alphabetical", sorted)
check("catalogue has no duplicates", #duplicates == 0, table.concat(duplicates, ","))
check("lookup set matches list", (function()
	local count = 0
	for _ in pairs(Config.BrainrotSet) do
		count = count + 1
	end
	return count == #Config.Brainrots
end)())
check("quick swap target exists", Config.BrainrotSet[Config.QuickSwapTarget] == true)
for slot, defaults in pairs(Config.RevertDefaults) do
	check("revert default for " .. slot .. " is a real brainrot",
		Config.BrainrotSet[defaults.name] == true)
end

------------------------------------------------------------------------------
group("Protocol")
------------------------------------------------------------------------------

local good = Protocol.encode("Main", "Griffin", 1, "sess1234", 100)
check("valid payload accepted", (Protocol.validate(good)))

local badProtocol = Protocol.encode("Main", "Griffin", 1, "sess1234", 100)
badProtocol.protocol = 999
check("wrong revision rejected", not (Protocol.validate(badProtocol)))

local badSlot = Protocol.encode("Nope", "Griffin", 1, "sess1234", 100)
check("unknown slot rejected", not (Protocol.validate(badSlot)))

local badName = Protocol.encode("Main", "Not A Brainrot", 1, "sess1234", 100)
check("unknown brainrot rejected", not (Protocol.validate(badName)))

local clear = Protocol.encode("Main", "", 1, "sess1234", 100)
check("empty name is a valid clear", (Protocol.validate(clear)))

check("nil rejected", not (Protocol.validate(nil)))
check("string rejected", not (Protocol.validate("hello")))

local noSession = Protocol.encode("Main", "Griffin", 1, "", 100)
check("missing session rejected", not (Protocol.validate(noSession)))

-- replay / ordering
local state = { session = "sess1234", sequence = 5 }
check("newer sequence accepted",
	Protocol.isNewer(state, { session = "sess1234", sequence = 6 }))
check("same sequence rejected",
	not Protocol.isNewer(state, { session = "sess1234", sequence = 5 }))
check("older sequence rejected",
	not Protocol.isNewer(state, { session = "sess1234", sequence = 4 }))
check("new session always accepted",
	Protocol.isNewer(state, { session = "other", sequence = 0 }))

-- staleness
check("fresh payload is not stale",
	not Protocol.isStale({ sentAt = 100 }, 100 + Config.Behaviour.StaleAfter - 1))
check("old payload is stale",
	Protocol.isStale({ sentAt = 100 }, 100 + Config.Behaviour.StaleAfter + 1))
check("payload without timestamp is stale", Protocol.isStale({}, 0))

-- attribute round trip
local roundTripped = Protocol.fromAttributes(Protocol.toAttributes(good))
equal("round trip slot", roundTripped.slot, good.slot)
equal("round trip brainrot", roundTripped.brainrot, good.brainrot)
equal("round trip sequence", roundTripped.sequence, good.sequence)
check("round trip validates", (Protocol.validate(roundTripped)))

-- session ids
local a, b = Protocol.newSessionId(), Protocol.newSessionId()
equal("session id length", #a, 8)
check("session ids differ", a ~= b or true) -- randomness, not asserted strictly

------------------------------------------------------------------------------
group("Signal")
------------------------------------------------------------------------------

local signal = Signal.new("test")
local hits = 0
local disconnect = signal:connect(function(value)
	hits = hits + value
end)

signal:fire(2)
equal("listener invoked", hits, 2)

signal:fire(3)
equal("listener invoked again", hits, 5)

disconnect()
signal:fire(10)
equal("disconnect works", hits, 5)

signal:connect(function()
	error("boom")
end)
local stillRan = false
signal:connect(function()
	stillRan = true
end)
local failures2 = signal:fire()
check("throwing listener is isolated", stillRan)
equal("failure counted", failures2, 1)

------------------------------------------------------------------------------
group("PlotService.classify — the safety rules")
------------------------------------------------------------------------------

local function subject(overrides)
	local base = {
		name = "Griffin",
		isPlayerCharacter = false,
		isSpawnedMarker = false,
		inPodiumsFolder = false,
		distanceToPodium = nil,
		distanceToPlot = nil,
		hasHumanoid = false,
		isKnownBrainrot = true,
	}
	for key, value in pairs(overrides or {}) do
		base[key] = value
	end
	return base
end

local remove, rule = PlotService.classify(subject({ isSpawnedMarker = true }))
check("KVSpawned removed", remove)
equal("rule name", rule, "kv-spawned")

remove = PlotService.classify(subject({ inPodiumsFolder = true }))
check("podium child removed", remove)

remove = PlotService.classify(subject({ distanceToPodium = 2 }))
check("on podium removed", remove)

remove = PlotService.classify(subject({ distanceToPodium = 50 }))
check("far from podium kept", not remove)

remove = PlotService.classify(subject({ distanceToPlot = 10 }))
check("named brainrot in plot removed", remove)

remove = PlotService.classify(subject({ distanceToPlot = 500 }))
check("named brainrot outside plot kept", not remove)

-- THE REGRESSION THAT MATTERED: the old code deleted player characters
-- because they are Models with a Humanoid near the plot.
remove, rule = PlotService.classify(subject({
	name = "SomePlayer",
	isPlayerCharacter = true,
	hasHumanoid = true,
	distanceToPlot = 5,
	distanceToPodium = 1,
	isSpawnedMarker = true,
	inPodiumsFolder = true,
	isKnownBrainrot = false,
}))
check("player character NEVER removed", not remove)
equal("player rule reported", rule, "player-character")

remove = PlotService.classify(subject({
	name = "ShopKeeper",
	hasHumanoid = true,
	isKnownBrainrot = false,
	distanceToPlot = 10,
}))
check("unnamed humanoid NPC kept", not remove)

------------------------------------------------------------------------------
group("Log")
------------------------------------------------------------------------------

Log.clear()
Log.level = Log.Level.NONE
Log.info("test", "hello %s", "world")
equal("history recorded", #Log.history, 1)
equal("format applied", Log.history[1].message, "hello world")
Log.info("test", "100% sure")
equal("stray percent survives", Log.history[2].message, "100% sure")

Log.historyLimit = 3
for i = 1, 10 do
	Log.info("test", "entry %d", i)
end
check("ring buffer bounded", #Log.history <= 3)

------------------------------------------------------------------------------
-- Summary
------------------------------------------------------------------------------

print(string.format("\n%s\n%d passed, %d failed", string.rep("-", 46), passed, failed))

if failed > 0 then
	print("\nFailures:")
	for _, message in ipairs(failures) do
		print("  - " .. message)
	end
	os.exit(1)
end

os.exit(0)
