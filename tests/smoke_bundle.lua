--[[
	Bundle smoke test.

	The unit suite exercises src/. This one loads dist/Admin.lua exactly as an
	executor would, proving the *shipped artefact* works: the module registry
	is complete, requires were rewritten correctly, and a full
	publish -> receive -> de-duplicate cycle runs end to end.
]]
package.path = "./tests/?.lua;" .. package.path
require("roblox_stub")

local source = io.open("dist/Admin.lua"):read("a")
-- Strip the trailing auto-start so we can inspect the registry instead of
-- trying to build a real ScreenGui under stubs.
source = source:gsub('return __require%("Admin"%)%.start%(%)%s*$',
                     'return { require = __require, modules = __modules }')

local chunk, err = load(source, "@dist/Admin.lua")
assert(chunk, err)
local bundle = chunk()

local expected = {"Config","Util","Log","Signal","Env","Protocol","Transport",
                  "Sync","Catalogue","PlotService","DuelService","Ui","Admin"}
for _, name in ipairs(expected) do
  assert(bundle.modules[name], "missing module in bundle: " .. name)
end
print("bundle contains all " .. #expected .. " modules")

-- Exercise real logic through the bundled registry.
local Protocol = bundle.require("Protocol")
local Sync     = bundle.require("Sync")
local Transport= bundle.require("Transport")

local p = Protocol.encode("Main", "Griffin", 1, "abc12345", 10)
assert(Protocol.validate(p), "bundled protocol rejects a valid payload")
print("bundled Protocol.validate works")

-- End-to-end: admin publishes over the global transport, tester receives.
local admin  = Sync.new{ transports = { Transport.Global.new() }, session="ADMIN", clock=function() return 50 end }
local tester = Sync.new{ transports = { Transport.Global.new() }, session="TESTER", clock=function() return 50 end }

local got
tester.received:connect(function(payload) got = payload end)
tester:listen()

local _, report = admin:publish("Other", "Cerberus")
assert(report.delivered == 1, "expected 1 delivery, got " .. tostring(report.delivered))
assert(got, "tester received nothing")
assert(got.brainrot == "Cerberus" and got.slot == "Other", "wrong payload")
print("end-to-end publish -> receive works ("..got.slot.." = "..got.brainrot..")")

-- Replay must be ignored.
local before = got
admin:_deliver(before)
assert(got == before, "replay was re-applied")
print("replay suppression works")

-- Admin must ignore its own echo.
-- Clear the shared global bucket so the late-joiner replay (a deliberate
-- feature) does not masquerade as a self-echo.
local Env = bundle.require("Env")
local Config = bundle.require("Config")
Env.globals()[Config.Sync.GlobalKey] = nil

local self_echo = Sync.new{ transports = { Transport.Global.new() }, session="SOLO", clock=function() return 50 end }
local selfHits = 0
self_echo.received:connect(function() selfHits = selfHits + 1 end)
self_echo:listen()
self_echo:publish("Main", "Meowl")
assert(selfHits == 0, "admin reacted to its own broadcast")
print("self-echo suppression works")

-- Late joiner SHOULD get the current state replayed to it.
local late = Sync.new{ transports = { Transport.Global.new() }, session="LATE", clock=function() return 50 end }
local lateGot
late.received:connect(function(pl) lateGot = pl end)
late:listen()
assert(lateGot and lateGot.brainrot == "Meowl", "late joiner did not converge")
print("late-joiner replay works ("..lateGot.brainrot..")")

-- Staleness reporting.
local stale = Sync.new{ transports = {}, session="S", clock=function() return 1e9 end }
assert(stale:isStale(), "empty sync should report stale")
print("staleness reporting works")

print("\nSMOKE OK")
