--[[
	Ui
	--
	A very small widget helper layer. The goal is not a framework: it is to
	remove the ~600 lines of copy-pasted Instance.new/UICorner/UIStroke noise
	from the original file so the window code reads as layout, not plumbing.

	Every widget returns the raw Instance, so anything not covered here can
	still be done directly.
]]

local Config = require(script.Parent.Config)
local Env = require(script.Parent.Env)

local Theme = Config.Theme

local Ui = {}

--- Instance.new with a property table, tolerant of unsupported properties.
function Ui.new(className, properties, children)
	local ok, instance = pcall(Instance.new, className)
	if not ok or not instance then
		return nil
	end

	if properties then
		-- Parent last: setting it first causes a reflow per property.
		local parent = properties.Parent
		properties.Parent = nil
		for key, value in pairs(properties) do
			pcall(function()
				instance[key] = value
			end)
		end
		if parent then
			instance.Parent = parent
		end
		properties.Parent = parent
	end

	if children then
		for _, child in ipairs(children) do
			if child then
				child.Parent = instance
			end
		end
	end

	return instance
end

function Ui.corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.CornerRadius)
	corner.Parent = parent
	return corner
end

function Ui.stroke(parent, colour, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour or Theme.Outline
	stroke.Thickness = thickness or 1
	stroke.Transparency = Theme.StrokeTransparency
	stroke.Parent = parent
	return stroke
end

function Ui.padding(parent, amount)
	local padding = Instance.new("UIPadding")
	local offset = UDim.new(0, amount or 8)
	padding.PaddingTop = offset
	padding.PaddingBottom = offset
	padding.PaddingLeft = offset
	padding.PaddingRight = offset
	padding.Parent = parent
	return padding
end

function Ui.list(parent, direction, gap)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, gap or 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Ui.label(properties)
	properties = properties or {}
	properties.BackgroundTransparency = properties.BackgroundTransparency or 1
	properties.TextColor3 = properties.TextColor3 or Theme.Text
	properties.Font = properties.Font or Enum.Font.Gotham
	properties.TextSize = properties.TextSize or 10
	properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
	return Ui.new("TextLabel", properties)
end

function Ui.heading(text, parent, order)
	return Ui.label({
		Size = UDim2.new(1, 0, 0, 14),
		Text = text,
		TextColor3 = Theme.Accent,
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		LayoutOrder = order,
		Parent = parent,
	})
end

--- Button with hover feedback and a guarded click handler.
function Ui.button(properties, onClick)
	properties = properties or {}
	local base = properties.BackgroundColor3 or Theme.Neutral

	properties.AutoButtonColor = false
	properties.BorderSizePixel = 0
	properties.TextColor3 = properties.TextColor3 or Theme.OnAccent
	properties.Font = properties.Font or Enum.Font.GothamBold
	properties.TextSize = properties.TextSize or 9

	local button = Ui.new("TextButton", properties)
	if not button then
		return nil
	end

	Ui.corner(button, properties.CornerRadius or 4)

	local hover = base:Lerp(Color3.new(1, 1, 1), 0.15)
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = hover
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = base
	end)

	if onClick then
		button.MouseButton1Click:Connect(function()
			-- A failing handler must not kill the button's future clicks.
			local ok, err = pcall(onClick)
			if not ok then
				require(script.Parent.Log).error("ui", "button handler failed: %s", tostring(err))
			end
		end)
	end

	return button
end

--- Root ScreenGui, replacing any previous instance of the same name.
function Ui.screen(name)
	local parent = Env.guiParent()

	local existing = parent and parent:FindFirstChild(name)
	if existing then
		pcall(existing.Destroy, existing)
	end

	return Ui.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = Config.Window.DisplayOrder,
		Parent = parent,
	})
end

--- Makes `frame` draggable by `handle`, mouse and touch.
--- Returns a disconnect function; the original leaked a global
--- UserInputService connection per window.
function Ui.draggable(frame, handle)
	handle = handle or frame

	local dragging = false
	local dragStart, startPosition

	local function update(input)
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end

	local connections = {}

	connections[#connections + 1] = handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = frame.Position

			local changed
			changed = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					changed:Disconnect()
				end
			end)
		end
	end)

	connections[#connections + 1] = Env.UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			update(input)
		end
	end)

	return function()
		for _, connection in ipairs(connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
end

--- Standard window chrome: draggable titlebar, close button, content frame.
function Ui.window(screen, title, width, height)
	local frame = Ui.new("Frame", {
		Size = UDim2.new(0, width, 0, height),
		Position = UDim2.new(0.5, -width / 2, 0.25, 0),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Active = true,
		Parent = screen,
	})
	Ui.corner(frame, 8)
	Ui.stroke(frame, Theme.Outline, 1.5)

	local titlebar = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, Config.Window.TitlebarHeight),
		BackgroundColor3 = Theme.Titlebar,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = frame,
	})
	Ui.corner(titlebar, 8)

	Ui.label({
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		Text = title,
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		Parent = titlebar,
	})

	Ui.button({
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -30, 0.5, -12),
		BackgroundColor3 = Theme.Danger,
		Text = "✕",
		TextSize = 12,
		Parent = titlebar,
	}, function()
		screen:Destroy()
	end)

	local content = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 1, -Config.Window.TitlebarHeight),
		Position = UDim2.new(0, 0, 0, Config.Window.TitlebarHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = frame,
	})
	Ui.padding(content, 10)
	Ui.list(content, Enum.FillDirection.Vertical, 6)

	local disconnectDrag = Ui.draggable(frame, titlebar)
	screen.Destroying:Connect(disconnectDrag)

	return frame, content, titlebar
end

return Ui
