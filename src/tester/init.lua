--[[
	Tester
	------
	The receiving side. This file did not exist before: `Tester side` in the
	repository root was a single empty byte, so nothing ever consumed the
	admin's broadcast.

	Responsibilities:
	  * listen on every available transport
	  * apply accepted payloads to the local duel GUI
	  * show link health so the operator can tell "idle" from "broken"
]]

local Shared = script.Parent.Parent.shared

local Config = require(Shared.Config)
local DuelService = require(Shared.DuelService)
local Log = require(Shared.Log)
local Sync = require(Shared.Sync)
local Ui = require(Shared.Ui)
local Util = require(Shared.Util)

local Theme = Config.Theme

local Tester = {}

local WINDOW_HEIGHT = 200

function Tester.start()
	local sync = Sync.new()

	local screen = Ui.screen(Config.APP_NAME .. "Tester")
	if not screen then
		Log.error("tester", "could not create ScreenGui")
		return
	end

	local _, content = Ui.window(
		screen,
		"📡 Duel Receiver " .. Config.VERSION,
		320,
		WINDOW_HEIGHT
	)

	----------------------------------------------------------------------
	-- Link status
	----------------------------------------------------------------------

	Ui.heading("LINK", content, 1)

	local linkRow = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.SurfaceAlt,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Parent = content,
	})
	Ui.corner(linkRow, 5)
	Ui.stroke(linkRow)

	local dot = Ui.new("Frame", {
		Size = UDim2.new(0, 8, 0, 8),
		Position = UDim2.new(0, 10, 0.5, -4),
		BackgroundColor3 = Theme.Danger,
		BorderSizePixel = 0,
		Parent = linkRow,
	})
	Ui.corner(dot, 4)

	local linkLabel = Ui.label({
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.new(0, 26, 0, 0),
		Text = "Waiting for admin…",
		TextColor3 = Theme.SubText,
		TextSize = 9,
		Parent = linkRow,
	})

	----------------------------------------------------------------------
	-- Received slots
	----------------------------------------------------------------------

	Ui.heading("RECEIVED", content, 3)

	local slotPanel = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 4,
		Parent = content,
	})
	Ui.list(slotPanel, Enum.FillDirection.Horizontal, 6)

	local cards = {}

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

		Ui.label({
			Size = UDim2.new(1, -10, 0, 12),
			Position = UDim2.new(0, 8, 0, 4),
			Text = slot:upper(),
			TextColor3 = accent,
			Font = Enum.Font.GothamBold,
			TextSize = 7,
			Parent = frame,
		})

		cards[slot] = Ui.label({
			Size = UDim2.new(1, -10, 0, 18),
			Position = UDim2.new(0, 8, 0, 20),
			Text = "—",
			TextColor3 = Theme.SubText,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			Parent = frame,
		})
	end

	local status = Ui.label({
		Size = UDim2.new(1, 0, 0, 16),
		Text = "",
		TextColor3 = Theme.SubText,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 5,
		Parent = content,
	})

	----------------------------------------------------------------------
	-- Applying inbound payloads
	----------------------------------------------------------------------

	local received = 0

	sync.received:connect(function(payload)
		received = received + 1

		local card = cards[payload.slot]

		if payload.brainrot == "" then
			-- Documented "clear this slot" instruction.
			local section = DuelService.section(payload.slot)
			local data = section and DuelService.slotData(section)
			if data then
				DuelService.clearViewport(data.viewport)
				local defaults = Config.RevertDefaults[payload.slot]
				if defaults then
					if data.title then
						data.title.Text = defaults.name
					end
					if data.cash then
						data.cash.Text = defaults.cash
					end
				end
			end
			if card then
				card.Text = "cleared"
				card.TextColor3 = Theme.SubText
			end
			status.Text = string.format("↩️ %s cleared", payload.slot)
			status.TextColor3 = Theme.SubText
			return
		end

		local applied, detail = DuelService.apply(payload.slot, payload.brainrot)

		if card then
			card.Text = Util.truncate(payload.brainrot, 15)
			card.TextColor3 = applied and Theme.Text or Theme.Danger
		end

		if applied then
			status.Text = string.format("✅ %s → %s", payload.slot, payload.brainrot)
			status.TextColor3 = Theme.Success
		else
			status.Text = string.format("❌ %s", detail)
			status.TextColor3 = Theme.Danger
			Log.warn("tester", "could not apply %s: %s", payload.brainrot, tostring(detail))
		end
	end)

	sync.rejected:connect(function(_, reason)
		Log.debug("tester", "dropped payload: %s", reason)
	end)

	----------------------------------------------------------------------
	-- Link health loop
	----------------------------------------------------------------------

	local function transportNames()
		local ids = {}
		for _, transport in ipairs(sync:activeTransports()) do
			ids[#ids + 1] = transport.id
		end
		return #ids > 0 and table.concat(ids, "+") or "none"
	end

	sync:listen()

	task.spawn(function()
		while screen.Parent do
			local stale = sync:isStale()
			local last = sync:last()

			if not last then
				dot.BackgroundColor3 = Theme.Warning
				linkLabel.Text = string.format("Listening on %s · no data yet", transportNames())
				linkLabel.TextColor3 = Theme.SubText
			elseif stale then
				dot.BackgroundColor3 = Theme.Danger
				linkLabel.Text = string.format("Stale · last update >%ds ago", Config.Behaviour.StaleAfter)
				linkLabel.TextColor3 = Theme.Danger
			else
				dot.BackgroundColor3 = Theme.Success
				linkLabel.Text = string.format("Connected · %s · %d msg", transportNames(), received)
				linkLabel.TextColor3 = Theme.Success
			end

			task.wait(1)
		end
		sync:destroy()
	end)

	Log.info("tester", "%s receiver v%s ready (session %s)",
		Config.APP_NAME, Config.VERSION, sync.session)

	return {
		sync = sync,
		screen = screen,
	}
end

return Tester
