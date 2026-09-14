--[[
	DuelService
	-----------
	Reading and rewriting the in-game duel GUI: locating the window, finding
	each slot's viewport, and rendering a brainrot model into it.
]]

local Catalogue = require(script.Parent.Catalogue)
local Config = require(script.Parent.Config)
local Env = require(script.Parent.Env)
local Log = require(script.Parent.Log)

local DuelService = {}

--- Locates the duel window. Returns nil when it is closed.
function DuelService.findGui()
	local player = Env.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local screenGui = playerGui:FindFirstChild(Config.Paths.DuelGui)
	if not screenGui then
		return nil
	end

	local inner = screenGui:FindFirstChild(Config.Paths.DuelGui)
	if not inner then
		return nil
	end

	return {
		screenGui = screenGui,
		inner = inner,
		Main = inner:FindFirstChild("Main"),
		Other = inner:FindFirstChild("Other"),
	}
end

--- Returns the section frame for a slot name, or nil.
function DuelService.section(slot)
	local gui = DuelService.findGui()
	if not gui then
		return nil, "duel GUI is closed"
	end
	local section = gui[slot]
	if not section then
		return nil, "slot " .. tostring(slot) .. " not present"
	end
	return section
end

--- Pulls the viewport, title and cash labels out of a slot section.
function DuelService.slotData(section)
	if not section then
		return nil
	end
	local item = section:FindFirstChild("Item")
	local viewport = item and item:FindFirstChild("ViewportFrame")
	if not viewport then
		return nil
	end

	local title = item:FindFirstChild("Title")
	local cash = item:FindFirstChild("Cash")

	return {
		section = section,
		item = item,
		viewport = viewport,
		title = title,
		cash = cash,
		name = title and title.Text or "Unknown",
		cashText = cash and cash.Text or "",
	}
end

--- Current contents of both slots, for the status panel.
function DuelService.snapshot()
	local gui = DuelService.findGui()
	if not gui then
		return nil
	end

	local out = {}
	for _, slot in ipairs(Config.Slots) do
		local data = DuelService.slotData(gui[slot])
		if data then
			out[slot] = { name = data.name, cash = data.cashText }
		end
	end
	return out
end

------------------------------------------------------------------------------
-- Viewport rendering
------------------------------------------------------------------------------

local function clearViewport(viewport)
	for _, child in ipairs(viewport:GetChildren()) do
		pcall(child.Destroy, child)
	end
end

DuelService.clearViewport = clearViewport

--- Strips physics + shadows so the preview model is inert and cheap.
local function neutralise(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			-- Never let a cloned asset run behaviour inside our preview.
			pcall(descendant.Destroy, descendant)
		end
	end
end

--- Frames `model` inside `camera` using its bounding box.
local function frameModel(camera, model)
	local extents = model:GetExtentsSize()
	local maxDimension = math.max(extents.X, extents.Y, extents.Z, 1)
	local halfFov = math.rad(Config.Behaviour.FieldOfView * 0.5)
	local distance = (maxDimension * 0.5 / math.tan(halfFov)) * 0.85

	local pivot = model:GetPivot().Position
	local position = pivot + Vector3.new(-(distance + maxDimension * 0.35), extents.Y * 0.1, 0)
	local target = pivot + Vector3.new(0, extents.Y * 0.05, 0)

	camera.CFrame = CFrame.new(position, target)
end

local function playIdle(model, name)
	local animation = Catalogue.idleAnimation(name)
	if not animation then
		return
	end

	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	if ok and track then
		track.Looped = true
		track:Play()
	end
end

--- Renders `name` into `viewport`. Returns true on success.
function DuelService.render(viewport, name)
	if not viewport then
		return false
	end

	local model = Catalogue.model(name)
	if not model then
		return false
	end

	clearViewport(viewport)
	neutralise(model)

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = Config.Behaviour.FieldOfView
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = world

	frameModel(camera, model)

	-- Animations need the model parented and settled for a frame.
	task.defer(function()
		pcall(playIdle, model, name)
	end)

	return true
end

------------------------------------------------------------------------------
-- High level actions
------------------------------------------------------------------------------

--- Writes `name` into `slot`: renders the model and updates the labels.
--- Returns ok, message.
function DuelService.apply(slot, name)
	local section, reason = DuelService.section(slot)
	if not section then
		return false, reason
	end

	local data = DuelService.slotData(section)
	if not data then
		return false, "slot layout not recognised"
	end

	if not DuelService.render(data.viewport, name) then
		return false, "model unavailable for " .. name
	end

	local cashText = Catalogue.generationText(name)
	if data.title then
		data.title.Text = name
	end
	if data.cash then
		data.cash.Text = cashText
	end

	Log.info("duel", "%s -> %s (%s)", slot, name, cashText)
	return true, cashText
end

--- Restores both slots to their vanilla contents.
function DuelService.revert()
	local gui = DuelService.findGui()
	if not gui then
		return false, "duel GUI is closed"
	end

	for slot, defaults in pairs(Config.RevertDefaults) do
		local data = DuelService.slotData(gui[slot])
		if data then
			clearViewport(data.viewport)
			if data.title then
				data.title.Text = defaults.name
			end
			if data.cash then
				data.cash.Text = defaults.cash
			end
		end
	end

	Log.info("duel", "reverted both slots")
	return true
end

return DuelService
