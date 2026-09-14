--[[
	PlotService
	-----------
	Locating the local player's plot and clearing brainrots from it.

	SAFETY REWRITE
	--------------
	The original cleaner iterated every top level model in Workspace and
	deleted anything within 60 studs of the plot pivot that had a Humanoid or
	an AnimationController. On a crowded server that happily deleted other
	players' characters, NPCs and vendors, because a player character is a
	Model with a Humanoid.

	`classify` below is a pure function with an explicit, ordered rule set and
	a hard exclusion list for player characters. It returns a decision plus the
	rule that fired, so the behaviour is unit tested and auditable.
]]

local Config = require(script.Parent.Config)
local Env = require(script.Parent.Env)
local Log = require(script.Parent.Log)

local PlotService = {}

------------------------------------------------------------------------------
-- Pure classification
------------------------------------------------------------------------------

--[[
	`subject` describes a candidate model without referencing Roblox types:
		{
			name             = string,
			isPlayerCharacter= boolean,
			isSpawnedMarker  = boolean,  -- KVSpawned attribute
			inPodiumsFolder  = boolean,
			distanceToPodium = number?,  -- nil when there are no podiums
			distanceToPlot   = number?,
			hasHumanoid      = boolean,
			isKnownBrainrot  = boolean,
		}

	Returns: remove (boolean), rule (string)
]]
function PlotService.classify(subject)
	-- Rule 0: never touch a player character. Highest precedence, no override.
	if subject.isPlayerCharacter then
		return false, "player-character"
	end

	-- Rule 1: explicit marker set by the game on spawned brainrots.
	if subject.isSpawnedMarker then
		return true, "kv-spawned"
	end

	-- Rule 2: parented under the plot's podium folder.
	if subject.inPodiumsFolder then
		return true, "in-podiums"
	end

	-- Rule 3: sitting on one of our podium spawn pads.
	local podiumDistance = subject.distanceToPodium
	if podiumDistance and podiumDistance < Config.Behaviour.PodiumRadius then
		return true, "on-podium"
	end

	-- Rule 4: a *named* brainrot loose inside our plot radius. Unlike the old
	-- code this requires the name to be in the catalogue; "has a Humanoid" is
	-- no longer sufficient on its own.
	local plotDistance = subject.distanceToPlot
	if subject.isKnownBrainrot and plotDistance and plotDistance < Config.Behaviour.PlotRadius then
		return true, "named-in-plot"
	end

	return false, "keep"
end

------------------------------------------------------------------------------
-- Roblox bound helpers
------------------------------------------------------------------------------

local function characterSet()
	local set = {}
	local players = Env.Players
	if not players then
		return set
	end
	local ok, list = pcall(players.GetPlayers, players)
	if ok then
		for _, player in ipairs(list) do
			if player.Character then
				set[player.Character] = true
			end
		end
	end
	return set
end

--- Nearest plot model to the local character, or nil.
function PlotService.findPlot()
	local plots = Env.Workspace and Env.Workspace:FindFirstChild(Config.Paths.PlotsFolder)
	if not plots then
		Log.warn("plot", "no %s folder in Workspace", Config.Paths.PlotsFolder)
		return nil
	end

	local root = Env.rootPart()
	if not root then
		Log.warn("plot", "character not ready")
		return nil
	end

	local origin = root.Position
	local best, bestDistance = nil, math.huge

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") then
			for _, marker in ipairs(PlotService.plotMarkers(plot)) do
				local distance = (marker.Position - origin).Magnitude
				if distance < bestDistance then
					bestDistance, best = distance, plot
				end
			end
		end
	end

	if best then
		Log.debug("plot", "matched %s at %d studs", best.Name, math.floor(bestDistance))
	else
		Log.warn("plot", "no plot matched; stand on your plot and retry")
	end

	return best, bestDistance
end

--- Reference parts belonging to a plot (spawn, root, podium pads).
function PlotService.plotMarkers(plot)
	local markers = {}
	if not plot then
		return markers
	end

	for _, name in ipairs({ "Spawn", "MainRoot" }) do
		local part = plot:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			markers[#markers + 1] = part
		end
	end

	for _, pad in ipairs(PlotService.podiumPads(plot)) do
		markers[#markers + 1] = pad
	end

	return markers
end

--- Spawn pads inside the plot's podium folder.
function PlotService.podiumPads(plot)
	local pads = {}
	local podiums = plot and plot:FindFirstChild(Config.Paths.PodiumsFolder)
	if not podiums then
		return pads
	end

	for _, podium in ipairs(podiums:GetChildren()) do
		local base = podium:FindFirstChild("Base")
		local spawn = base and base:FindFirstChild("Spawn")
		if spawn and spawn:IsA("BasePart") then
			pads[#pads + 1] = spawn
		end
	end

	return pads
end

local function isDescendantOfPodiums(model, podiums)
	if not podiums then
		return false
	end
	local ok, result = pcall(model.IsDescendantOf, model, podiums)
	return ok and result or false
end

--- Removes brainrots belonging to the local player's plot.
--- Returns removedCount, inspectedCount.
function PlotService.clean(plot)
	plot = plot or PlotService.findPlot()
	if not plot then
		return 0, 0
	end

	local pads = PlotService.podiumPads(plot)
	local podiums = plot:FindFirstChild(Config.Paths.PodiumsFolder)
	local characters = characterSet()
	local plotPivot = plot:GetPivot().Position

	local removed, inspected = 0, 0
	local names = {}

	for _, model in ipairs(Env.Workspace:GetChildren()) do
		if inspected >= Config.Behaviour.MaxModelsPerClean then
			Log.warn("plot", "inspection cap reached at %d models", inspected)
			break
		end

		if model:IsA("Model") then
			inspected = inspected + 1

			local ok, pivot = pcall(function()
				return model:GetPivot().Position
			end)
			if ok then
				local nearestPad = nil
				for _, pad in ipairs(pads) do
					local distance = (pivot - pad.Position).Magnitude
					if not nearestPad or distance < nearestPad then
						nearestPad = distance
					end
				end

				local remove, rule = PlotService.classify({
					name = model.Name,
					isPlayerCharacter = characters[model] == true,
					isSpawnedMarker = model:GetAttribute("KVSpawned") == true,
					inPodiumsFolder = isDescendantOfPodiums(model, podiums),
					distanceToPodium = nearestPad,
					distanceToPlot = (pivot - plotPivot).Magnitude,
					hasHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil,
					isKnownBrainrot = Config.BrainrotSet[model.Name] == true,
				})

				if remove then
					local destroyed = pcall(model.Destroy, model)
					if destroyed then
						removed = removed + 1
						names[#names + 1] = model.Name
						Log.trace("plot", "removed %s (%s)", model.Name, rule)
					end
				end
			end
		end
	end

	if removed > 0 then
		Log.info("plot", "removed %d brainrot(s): %s", removed, table.concat(names, ", "))
	else
		Log.debug("plot", "nothing to remove (%d models inspected)", inspected)
	end

	return removed, inspected
end

return PlotService
