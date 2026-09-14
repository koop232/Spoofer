--[[
	Catalogue
	---------
	Brainrot metadata: generation figures, model lookup, animation lookup.

	The original code re-`require`d the game's data module on every single list
	row (65 requires per keystroke while searching). Results are memoised here.
]]

local Config = require(script.Parent.Config)
local Env = require(script.Parent.Env)
local Log = require(script.Parent.Log)
local Util = require(script.Parent.Util)

local Catalogue = {}

local generationCache = {}
local animalData = nil
local assetModule = nil
local loaded = false

local function load()
	if loaded then
		return
	end
	loaded = true

	local rs = Env.ReplicatedStorage
	if not rs then
		return
	end

	animalData = Env.safeRequire(Env.resolve(rs, Config.Paths.AnimalData))
	assetModule = Env.safeRequire(Env.resolve(rs, Config.Paths.BrainrotAssets))

	if not animalData then
		Log.debug("catalogue", "animal data module unavailable; generations show as $0/s")
	end
end

--- Every known brainrot name, alphabetically.
function Catalogue.names()
	return Config.Brainrots
end

function Catalogue.exists(name)
	return Config.BrainrotSet[name] == true
end

--- Income per second for `name`, memoised. Returns 0 when unknown.
function Catalogue.generation(name)
	if generationCache[name] ~= nil then
		return generationCache[name]
	end

	load()

	local value = 0
	if animalData and type(animalData) == "table" then
		local entry = animalData[name]
		if type(entry) == "table" and tonumber(entry.Generation) then
			value = tonumber(entry.Generation)
		end
	end

	generationCache[name] = value
	return value
end

--- Pre-formatted "$1.2M/s" string for `name`.
function Catalogue.generationText(name)
	return Util.formatGeneration(Catalogue.generation(name))
end

--- Returns a fresh clone of the display model, or nil.
function Catalogue.model(name)
	load()

	if assetModule and type(assetModule.getModel) == "function" then
		local ok, resolved = pcall(assetModule.getModel, name)
		if ok and resolved then
			local cloneOk, clone = pcall(resolved.Clone, resolved)
			if cloneOk and clone then
				return clone
			end
		end
	end

	local rs = Env.ReplicatedStorage
	if rs then
		local folder = Env.resolve(rs, Config.Paths.ModelsFolder)
		local template = folder and folder:FindFirstChild(name)
		if template then
			local ok, clone = pcall(template.Clone, template)
			if ok then
				return clone
			end
		end
	end

	Log.warn("catalogue", "no model available for %s", name)
	return nil
end

--- Idle Animation instance for `name`, or nil.
function Catalogue.idleAnimation(name)
	local rs = Env.ReplicatedStorage
	if not rs then
		return nil
	end
	local folder = Env.resolve(rs, Config.Paths.AnimationsFolder)
	local perAnimal = folder and folder:FindFirstChild(name)
	return perAnimal and perAnimal:FindFirstChild("Idle") or nil
end

--- Drops memoised values; call after a game update.
function Catalogue.invalidate()
	table.clear(generationCache)
	animalData = nil
	assetModule = nil
	loaded = false
end

return Catalogue
