--!strict-ish (annotations omitted for portability with the test harness)
--[[
	Config
	------
	Single source of truth for every tunable value in the project.

	Nothing in here may touch a Roblox service, so the table can be loaded by
	the offline test harness. Anything environment specific belongs in
	`shared/Env.lua` instead.
]]

local Config = {}

Config.VERSION = "2.0.0"

--- Name used for every GUI root, sync folder and log prefix.
Config.APP_NAME = "Spoofer"

------------------------------------------------------------------------------
-- Theme
------------------------------------------------------------------------------

Config.Theme = {
	Background = Color3.fromRGB(10, 10, 15),
	Surface = Color3.fromRGB(18, 18, 25),
	SurfaceAlt = Color3.fromRGB(25, 25, 35),
	Row = Color3.fromRGB(15, 15, 22),
	RowHover = Color3.fromRGB(35, 25, 35),
	Outline = Color3.fromRGB(60, 60, 80),
	Titlebar = Color3.fromRGB(16, 9, 12),

	Accent = Color3.fromRGB(225, 18, 48),
	Success = Color3.fromRGB(38, 178, 92),
	Danger = Color3.fromRGB(200, 50, 50),
	Warning = Color3.fromRGB(200, 150, 50),
	Neutral = Color3.fromRGB(60, 60, 80),
	Gold = Color3.fromRGB(255, 215, 0),

	Text = Color3.fromRGB(248, 244, 246),
	SubText = Color3.fromRGB(160, 160, 180),
	OnAccent = Color3.fromRGB(255, 255, 255),

	CornerRadius = 6,
	StrokeTransparency = 0.3,
}

------------------------------------------------------------------------------
-- Window / layout
------------------------------------------------------------------------------

Config.Window = {
	Width = 380,
	Height = 460,
	TitlebarHeight = 30,
	ListHeight = 200,
	RowHeight = 24,
	DisplayOrder = 5000,
}

------------------------------------------------------------------------------
-- Behaviour
------------------------------------------------------------------------------

Config.Behaviour = {
	--- How often the admin re-publishes its current selection (seconds).
	HeartbeatInterval = 1,
	--- How often the slot panel refreshes itself (seconds).
	SlotRefreshInterval = 3,
	--- A tester treats the link as dead after this many seconds of silence.
	StaleAfter = 8,
	--- Radius (studs) around a podium spawn that counts as "on the podium".
	PodiumRadius = 8,
	--- Radius (studs) around the plot pivot searched for stray brainrots.
	PlotRadius = 60,
	--- Upper bound on models inspected per plot clean, protects against lag.
	MaxModelsPerClean = 4000,
	--- Search debounce for the brainrot list (seconds).
	SearchDebounce = 0.08,
	--- Viewport camera field of view.
	FieldOfView = 50,
}

------------------------------------------------------------------------------
-- Keybinds
------------------------------------------------------------------------------

Config.Keybinds = {
	QuickSwap = "F1",
	Refresh = "F5",
	CleanPlot = "F6",
	ToggleWindow = "RightBracket",
}

--- Brainrot applied by the QuickSwap keybind and the REPLACE button.
Config.QuickSwapTarget = "Dragon Cannelloni"

--- Values restored by the REVERT action.
Config.RevertDefaults = {
	Main = { name = "Noobini Pizzanini", cash = "$1/s" },
	Other = { name = "Svinina Bombardino", cash = "$10/s" },
}

------------------------------------------------------------------------------
-- Sync
------------------------------------------------------------------------------

Config.Sync = {
	--- Protocol revision; testers reject payloads from another revision.
	Protocol = 2,
	--- Shared folder / attribute namespace.
	Channel = "DuelSpoofSync",
	--- getgenv() key used for the same-machine transport.
	GlobalKey = "__SPOOFER_SYNC__",
	--- Remote names searched for when relaying through the server.
	RemoteHints = { "DuelSpoofSync", "Sync", "Replicate", "Broadcast" },
	--- Maximum depth walked when hunting for a usable RemoteEvent.
	RemoteSearchDepth = 4,
}

Config.Slots = { "Main", "Other" }

------------------------------------------------------------------------------
-- Game object paths (kept here so a game update is a one line fix)
------------------------------------------------------------------------------

Config.Paths = {
	DuelGui = "DuelsMachineSession",
	PlotsFolder = "Plots",
	PodiumsFolder = "AnimalPodiums",
	AnimalData = { "Datas", "Animals" },
	BrainrotAssets = { "Shared", "BrainrotAssets" },
	ModelsFolder = { "Models", "Animals" },
	AnimationsFolder = { "Animations", "Animals" },
}

------------------------------------------------------------------------------
-- Catalogue
------------------------------------------------------------------------------

Config.Brainrots = {
	"Antonio", "Arcadragon", "Bunny and Eggy", "Burguro And Fryuro",
	"Capitano Moby", "Cappuccino Clownino", "Cash or Card", "Celestial Pegasus",
	"Cerberus", "Chillin Chili", "Chipso and Queso", "Cloverat Clapat",
	"Cooki and Milki", "Digi Narwhal", "Dragon Cannelloni", "Dragon Gingerini",
	"Dug dug dug", "Elefanto Frigo", "Fishino Clownino", "Foxini Lanternini",
	"Fragola La La La", "Fragrama and Chocrama", "Garama and Madundung",
	"Ginger Gerat", "Ginger Globo", "Globa Steppa", "Griffin",
	"Guerriro Digitale", "Gym Bros", "Headless Horseman", "Hydra Bunny",
	"Hydra Dragon Cannelloni", "John Pork", "Ketchuru and Musturu",
	"Ketupat Bros", "La Casa Boo", "La Secret Combinasion",
	"La Supreme Combinasion", "Las Sis", "Lavadorito Spinito", "Los Amigos",
	"Los Sekolahs", "Los Spaghettis", "Love Love Bear", "Meowl",
	"Money Money Bros", "Nacho Spyder", "Noobini Pizzanini",
	"Pancake and Syrup", "Popcuru and Fizzuru", "Quackini Snackini",
	"Reinito Sleighito", "Rosetti Tualetti", "Rosey and Teddy",
	"Sammyni Fattini", "Signore Carapace", "Skibidi Toilet",
	"Spaghetti Tualetti", "Spooky and Pumpky", "Strawberry Elephant",
	"Svinina Bombardino", "Tang Tang Keletang", "Tictac Sahur",
	"Tirilikalika Tirilikalako", "Ventoliero Pavonero",
}

--- Frozen lookup so membership tests are O(1) instead of O(n).
Config.BrainrotSet = {}
for _, name in ipairs(Config.Brainrots) do
	Config.BrainrotSet[name] = true
end

return Config
