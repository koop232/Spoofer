--[[
	Env
	---
	Every direct touch of a Roblox service or an executor global lives here.

	Two reasons:
	  1. The rest of the codebase stays loadable by the offline test harness,
	     which injects a fake `Env`.
	  2. Executor differences (gethui, hookfunction, getgenv, http_request)
	     are probed exactly once instead of being re-pcall'd at every site.
]]

local Env = {}

--- GetService that survives `game` being absent entirely (test harness) and
--- a service being unavailable (some executors block CoreGui).
local function service(name)
	local ok, result = pcall(function()
		return game:GetService(name)
	end)
	return ok and result or nil
end

Env.Players = service("Players")
Env.UserInputService = service("UserInputService")
Env.RunService = service("RunService")
Env.ReplicatedStorage = service("ReplicatedStorage")
Env.Workspace = service("Workspace") or rawget(_G, "workspace")
Env.CoreGui = service("CoreGui")
Env.TweenService = service("TweenService")
Env.HttpService = service("HttpService")

Env.LocalPlayer = Env.Players and Env.Players.LocalPlayer or nil

------------------------------------------------------------------------------
-- Executor capability probe
------------------------------------------------------------------------------

local function capability(name)
	local ok, value = pcall(function()
		local scope = getfenv and getfenv(0) or _G
		return rawget(scope, name)
	end)
	if ok and type(value) == "function" then
		return value
	end
	return nil
end

Env.Capabilities = {
	gethui = capability("gethui"),
	getgenv = capability("getgenv"),
	httpRequest = capability("http_request") or capability("request"),
	getNilInstances = capability("getnilinstances"),
	fireSignal = capability("firesignal"),
}

--- True when running under an exploit executor rather than a plain client.
Env.IsExecutor = Env.Capabilities.getgenv ~= nil or Env.Capabilities.gethui ~= nil

--- Shared global table. Falls back to a module-local table so the same-machine
--- transport degrades gracefully instead of erroring.
local fallbackGlobals = {}
function Env.globals()
	local getgenv = Env.Capabilities.getgenv
	if getgenv then
		local ok, result = pcall(getgenv)
		if ok and type(result) == "table" then
			return result
		end
	end
	return fallbackGlobals
end

------------------------------------------------------------------------------
-- GUI parenting
------------------------------------------------------------------------------

--- Most protected place available for a ScreenGui, in descending preference.
function Env.guiParent()
	local gethui = Env.Capabilities.gethui
	if gethui then
		local ok, hidden = pcall(gethui)
		if ok and hidden then
			return hidden
		end
	end

	if Env.LocalPlayer then
		local ok, playerGui = pcall(function()
			return Env.LocalPlayer:WaitForChild("PlayerGui", 5)
		end)
		if ok and playerGui then
			return playerGui
		end
	end

	return Env.CoreGui
end

------------------------------------------------------------------------------
-- Convenience accessors
------------------------------------------------------------------------------

--- Walks a path of child names from `root`, returning nil at the first miss.
function Env.resolve(root, path)
	local node = root
	for _, name in ipairs(path) do
		if not node then
			return nil
		end
		local ok, child = pcall(node.FindFirstChild, node, name)
		if not ok then
			return nil
		end
		node = child
	end
	return node
end

--- require() that never throws.
function Env.safeRequire(instance)
	if not instance then
		return nil
	end
	local ok, module = pcall(require, instance)
	if ok then
		return module
	end
	return nil
end

--- Character root part, or nil while respawning.
function Env.rootPart()
	local player = Env.LocalPlayer
	if not player then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

--- Monotonic-ish clock that works in both Roblox and the harness.
function Env.now()
	local ok, value = pcall(os.clock)
	if ok then
		return value
	end
	return 0
end

return Env
