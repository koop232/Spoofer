--[[
	Admin
	-----
	The controlling side. Picks a brainrot, writes it into the local duel GUI,
	cleans the plot, and publishes the choice to any listening tester.

	This file is deliberately only wiring + layout; all behaviour lives in the
	shared services so it can be tested without Roblox.
]]

local Shared = script.Parent.Parent.shared

local Catalogue = require(Shared.Catalogue)
local Config = require(Shared.Config)
local DuelService = require(Shared.DuelService)
local Env = require(Shared.Env)
local Log = require(Shared.Log)
local PlotService = require(Shared.PlotService)
local Sync = require(Shared.Sync)
local Ui = require(Shared.Ui)
local Util = require(Shared.Util)

local Theme = Config.Theme

local Admin = {}

function Admin.start()
	local sync = Sync.new()
	local state = {
		slot = Config.Slots[1],
		filter = "",
		searchToken = 0,
	}

	local screen = Ui.screen(Config.APP_NAME .. "Admin")
	if not screen then
		Log.error("admin", "could not create ScreenGui")
		return
	end

	local _, content = Ui.window(
		screen,
		"⚔️ Duel Swapper " .. Config.VERSION,
		Config.Window.Width,
		Config.Window.Height
	)

	----------------------------------------------------------------------
	-- Status line
	----------------------------------------------------------------------

	local status = Ui.label({
		Size = UDim2.new(1, 0, 0, 16),
		Text = "Starting…",
		TextColor3 = Theme.SubText,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 100,
		Parent = content,
	})

	local function say(colour, message, ...)
		local text = select("#", ...) > 0 and string.format(message, ...) or message
		status.Text = text
		status.TextColor3 = colour
	end

	local function ok(message, ...)
		say(Theme.Success, message, ...)
	end

	local function fail(message, ...)
		say(Theme.Danger, message, ...)
	end

	----------------------------------------------------------------------
	-- Current slots panel
	----------------------------------------------------------------------

	Ui.heading("CURRENT DUEL SLOTS", content, 1)

	local slotPanel = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Parent = content,
	})
	Ui.list(slotPanel, Enum.FillDirection.Horizontal, 6)

	local slotCards = {}

	local function buildSlotCards()
		for _, card in pairs(slotCards) do
			pcall(card.frame.Destroy, card.frame)
		end
		table.clear(slotCards)

		for index, slot in ipairs(Config.Slots) do
			local accent = slot == "Main" and Theme.Accent or Theme.Gold

			local frame = Ui.new("Frame", {
				Size = UDim2.new(0.5, -3, 1, 0),
				BackgroundColor3 = Theme.SurfaceAlt,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Parent = slotPanel,
			})
			Ui.corner(frame, 5)
			Ui.stroke(frame)

			Ui.new("Frame", {
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Parent = frame,
			})

			Ui.label({
				Size = UDim2.new(1, -10, 0, 12),
				Position = UDim2.new(0, 8, 0, 4),
				Text = slot:upper(),
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 7,
				Parent = frame,
			})

			local name = Ui.label({
				Size = UDim2.new(1, -10, 0, 18),
				Position = UDim2.new(0, 8, 0, 18),
				Text = "—",
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				Parent = frame,
			})

			local cash = Ui.label({
				Size = UDim2.new(1, -10, 0, 14),
				Position = UDim2.new(0, 8, 0, 34),
				Text = "",
				TextColor3 = Theme.Success,
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				Parent = frame,
			})

			slotCards[slot] = { frame = frame, name = name, cash = cash }
		end
	end

	local function refreshSlots()
		local snapshot = DuelService.snapshot()
		for slot, card in pairs(slotCards) do
			local entry = snapshot and snapshot[slot]
			card.name.Text = entry and Util.truncate(entry.name, 15) or "duel closed"
			card.name.TextColor3 = entry and Theme.Text or Theme.SubText
			card.cash.Text = entry and entry.cash or ""
		end
	end

	buildSlotCards()

	----------------------------------------------------------------------
	-- Brainrot list
	----------------------------------------------------------------------

	Ui.heading("SELECT BRAINROT", content, 3)

	local searchRow = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		LayoutOrder = 4,
		Parent = content,
	})
	Ui.corner(searchRow, 5)
	Ui.stroke(searchRow)

	Ui.label({
		Size = UDim2.new(0, 20, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		Text = "🔍",
		TextColor3 = Theme.SubText,
		Parent = searchRow,
	})

	local search = Ui.new("TextBox", {
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.new(0, 26, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "Search… (fuzzy, try 'dgc')",
		PlaceholderColor3 = Theme.SubText,
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 10,
		ClearTextOnFocus = false,
		Parent = searchRow,
	})

	local list = Ui.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, Config.Window.ListHeight),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = content,
	})
	Ui.corner(list, 5)
	Ui.stroke(list)
	Ui.list(list, Enum.FillDirection.Vertical, 1)
	Ui.padding(list, 3)

	local rows = {}

	-- Forward declaration: the row click handler needs `applySlot`.
	local applySlot

	local function clearRows()
		for _, row in ipairs(rows) do
			pcall(row.Destroy, row)
		end
		table.clear(rows)
	end

	local function buildList(filter)
		clearRows()

		local matches = Util.searchNames(Catalogue.names(), filter)

		if #matches == 0 then
			rows[1] = Ui.label({
				Size = UDim2.new(1, 0, 0, Config.Window.RowHeight),
				Text = "No brainrots match " .. string.format("%q", filter),
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = list,
			})
			return
		end

		for index, name in ipairs(matches) do
			local row = Ui.button({
				Size = UDim2.new(1, 0, 0, Config.Window.RowHeight),
				BackgroundColor3 = Theme.Row,
				Text = "",
				LayoutOrder = index,
				CornerRadius = 3,
				Parent = list,
			}, function()
				applySlot(state.slot, name)
			end)

			Ui.label({
				Size = UDim2.new(0.7, -8, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				Text = name,
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})

			Ui.label({
				Size = UDim2.new(0.3, -8, 1, 0),
				Position = UDim2.new(0.7, 0, 0, 0),
				Text = Catalogue.generationText(name),
				TextColor3 = Theme.Success,
				Font = Enum.Font.GothamBold,
				TextSize = 8,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = row,
			})

			rows[#rows + 1] = row
		end
	end

	----------------------------------------------------------------------
	-- Actions
	----------------------------------------------------------------------

	local actionRow = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 6,
		Parent = content,
	})
	Ui.list(actionRow, Enum.FillDirection.Horizontal, 4)

	-- Slot selector
	local selector = Ui.new("Frame", {
		Size = UDim2.new(0, 100, 0, 26),
		BackgroundColor3 = Theme.SurfaceAlt,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = actionRow,
	})
	Ui.corner(selector, 4)
	Ui.stroke(selector)
	Ui.list(selector, Enum.FillDirection.Horizontal, 0)

	local slotButtons = {}

	local function highlightSlot()
		for slot, button in pairs(slotButtons) do
			button.BackgroundColor3 = (slot == state.slot) and Theme.Accent or Color3.fromRGB(30, 30, 40)
		end
	end

	for index, slot in ipairs(Config.Slots) do
		slotButtons[slot] = Ui.button({
			Size = UDim2.new(0.5, 0, 1, 0),
			BackgroundColor3 = Theme.Neutral,
			Text = slot:upper(),
			TextSize = 8,
			LayoutOrder = index,
			CornerRadius = 3,
			Parent = selector,
		}, function()
			state.slot = slot
			highlightSlot()
			say(Theme.SubText, "Target slot: %s", slot)
		end)
	end
	highlightSlot()

	--- Applies a brainrot: clean plot, rewrite GUI, publish to testers.
	function applySlot(slot, name)
		local removed = PlotService.clean()
		local applied, detail = DuelService.apply(slot, name)

		if not applied then
			fail("❌ %s", detail)
			return false
		end

		local payload, report = sync:publish(slot, name)
		refreshSlots()

		local suffix = ""
		if removed > 0 then
			suffix = string.format(" · 🗑️ %d", removed)
		end
		if payload and report.delivered > 0 then
			suffix = suffix .. string.format(" · 📡 %d", report.delivered)
		else
			suffix = suffix .. " · 📡 none"
		end

		ok("✅ %s → %s%s", slot, name, suffix)
		return true
	end

	Ui.button({
		Size = UDim2.new(0, 70, 0, 26),
		BackgroundColor3 = Theme.Success,
		Text = "REPLACE",
		LayoutOrder = 2,
		Parent = actionRow,
	}, function()
		applySlot(state.slot, Config.QuickSwapTarget)
	end)

	Ui.button({
		Size = UDim2.new(0, 60, 0, 26),
		BackgroundColor3 = Theme.Danger,
		Text = "REVERT",
		LayoutOrder = 3,
		Parent = actionRow,
	}, function()
		local reverted, reason = DuelService.revert()
		if reverted then
			for _, slot in ipairs(Config.Slots) do
				sync:publish(slot, "")
			end
			refreshSlots()
			say(Theme.SubText, "↩️ Reverted both slots")
		else
			fail("❌ %s", reason)
		end
	end)

	Ui.button({
		Size = UDim2.new(0, 70, 0, 26),
		BackgroundColor3 = Theme.Warning,
		Text = "CLEAN",
		LayoutOrder = 4,
		Parent = actionRow,
	}, function()
		local removed, inspected = PlotService.clean()
		say(Theme.Warning, "🗑️ Removed %d of %d models", removed, inspected)
	end)

	Ui.button({
		Size = UDim2.new(0, 60, 0, 26),
		BackgroundColor3 = Theme.Neutral,
		Text = "REFRESH",
		LayoutOrder = 5,
		Parent = actionRow,
	}, function()
		Catalogue.invalidate()
		buildList(state.filter)
		refreshSlots()
		say(Theme.SubText, "🔄 Refreshed")
	end)

	----------------------------------------------------------------------
	-- Input
	----------------------------------------------------------------------

	-- Debounced search: rebuilding 65 rows on every keystroke was the single
	-- biggest source of input lag in the original script.
	search:GetPropertyChangedSignal("Text"):Connect(function()
		state.filter = search.Text
		state.searchToken = state.searchToken + 1
		local token = state.searchToken

		task.delay(Config.Behaviour.SearchDebounce, function()
			if token == state.searchToken then
				buildList(state.filter)
			end
		end)
	end)

	local actions = {
		[Config.Keybinds.QuickSwap] = function()
			applySlot(state.slot, Config.QuickSwapTarget)
		end,
		[Config.Keybinds.Refresh] = function()
			buildList(state.filter)
			refreshSlots()
			say(Theme.SubText, "🔄 Refreshed")
		end,
		[Config.Keybinds.CleanPlot] = function()
			local removed = PlotService.clean()
			say(Theme.Warning, "🗑️ Removed %d", removed)
		end,
		[Config.Keybinds.ToggleWindow] = function()
			screen.Enabled = not screen.Enabled
		end,
	}

	Env.UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local handler = actions[input.KeyCode.Name]
		if handler then
			pcall(handler)
		end
	end)

	----------------------------------------------------------------------
	-- Boot
	----------------------------------------------------------------------

	buildList("")
	refreshSlots()
	sync:startHeartbeat()

	-- Keep the slot panel honest without a per-frame loop.
	task.spawn(function()
		while screen.Parent do
			task.wait(Config.Behaviour.SlotRefreshInterval)
			pcall(refreshSlots)
		end
		sync:destroy()
	end)

	local transports = sync:activeTransports()
	local ids = {}
	for _, transport in ipairs(transports) do
		ids[#ids + 1] = transport.id
	end

	if sync:hasCrossClient() then
		ok("Ready · sync: %s", table.concat(ids, "+"))
	else
		say(Theme.Warning, "Ready · same-machine sync only (%s)", table.concat(ids, "+"))
		Log.warn("admin", "no cross-client relay found: a tester on another " ..
			"machine will not receive updates. See docs/SYNC.md")
	end

	Log.info("admin", "%s v%s ready (session %s)", Config.APP_NAME, Config.VERSION, sync.session)

	return {
		sync = sync,
		screen = screen,
		apply = applySlot,
	}
end

return Admin
