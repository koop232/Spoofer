-- ═══════════════════════════════════════════════════════════════════════════
--  DUEL SPOOFER - ONE SCRIPT, BOTH SIDES
--
--  Run this SAME file on every account. It looks at the Roblox username and
--  picks its own role:
--
--    username == fmly_funke  ->  ADMIN. Header reads "ADMIN DETECTED".
--                                Whatever you pick is pushed out to everyone.
--    anyone else             ->  TESTER. Header reads "WELCOME".
--                                Shows what the admin pushed (name, $/s, model).
--
--  The tester ONLY accepts a spoof that was authored by fmly_funke. A push
--  from any other name is ignored and logged.
--
--  HOW THE TWO SIDES TALK
--    Roblox executor scripts run CLIENT-SIDE. Instances an executor creates are
--    never replicated to other players, so two accounts cannot see each other's
--    local state. The admin writes into a GitHub Gist; the tester polls it.
--    Nothing to host, nothing to keep running.
--
--  SETUP  (full notes in README.md)
--    1. Admin makes a token at https://github.com/settings/tokens
--       -> "Generate new token (classic)", tick ONLY the `gist` scope.
--    2. Admin puts it in TOKEN below and runs the script once. It creates the
--       Gist and prints + copies a GIST_ID.
--    3. Put that GIST_ID into this file. Give the tester the same file with
--       their own token (any classic token; `gist` scope to read a secret gist).
--
--    Both accounts need a token: GitHub only makes conditional polls free when
--    the request is authenticated (5000/hr and 304s cost nothing). Without one
--    it is 60/hr and 304s still count, so the tester self-throttles to 1/min.
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG = {
    -- WHO IS THE ADMIN ------------------------------------------------------
    ADMIN_USER = "fmly_funke",   -- compared case-insensitively

    -- GITHUB SYNC -----------------------------------------------------------
    TOKEN   = "",                -- admin: token with `gist` scope (write)
                                 -- tester: any classic token (read)
    GIST_ID = "",                -- blank on the admin's first run; it prints one
    ROOM    = "default",         -- must match on both accounts
    PUBLIC_GIST = false,         -- secret gist (unlisted, not private)

    -- BEHAVIOUR -------------------------------------------------------------
    -- true  = whatever the admin picks goes out as DRAGON_NAME
    -- false = the tester sees exactly what the admin picked
    FORCE_DRAGON = true,
    DRAGON_NAME  = "Dragon Cannelloni",

    POLL         = 1.5,          -- tester poll interval (seconds)
    AUTO_RENDER  = true,         -- draw the 3D model in the viewport
    LOCAL_MIRROR = true,         -- also set local attributes (same-client receivers)
    TOGGLE_KEY   = Enum.KeyCode.F2,
}

-- ── SERVICES ─────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local RS               = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer

-- ── ROLE DETECTION ───────────────────────────────────────────────────────────
local function CurrentUserName()
    local name = nil
    pcall(function() name = LocalPlayer and LocalPlayer.Name end)
    return tostring(name or "")
end

local USER_NAME = CurrentUserName()
local IS_ADMIN  = USER_NAME:lower() == tostring(CONFIG.ADMIN_USER):lower()

-- ── THEME ────────────────────────────────────────────────────────────────────
local BG      = Color3.fromRGB(10, 10, 15)
local ACCENT  = Color3.fromRGB(225, 18, 48)
local BTNGRN  = Color3.fromRGB(38, 178, 92)
local BTNRED  = Color3.fromRGB(200, 50, 50)
local TEXT    = Color3.fromRGB(248, 244, 246)
local SUBTEXT = Color3.fromRGB(160, 160, 180)
local GOLD    = Color3.fromRGB(255, 215, 0)
local PANEL   = Color3.fromRGB(25, 25, 35)
local LINE    = Color3.fromRGB(60, 60, 80)

-- ── ALL BRAINROTS ────────────────────────────────────────────────────────────
local ALL_BRAINROTS = {
    "Noobini Pizzanini", "Svinina Bombardino",
    "Skibidi Toilet", "Strawberry Elephant", "Headless Horseman", "Meowl", "John Pork",
    "Dragon Cannelloni", "Garama and Madundung", "Elefanto Frigo", "Signore Carapace",
    "Fragola La La La", "Love Love Bear", "Hydra Dragon Cannelloni", "Tang Tang Keletang",
    "Ketchuru and Musturu", "Burguro And Fryuro", "La Secret Combinasion", "Tictac Sahur",
    "Cerberus", "Capitano Moby", "Foxini Lanternini", "Antonio", "Ginger Gerat",
    "Fishino Clownino", "Guerriro Digitale", "Ginger Globo", "Cappuccino Clownino",
    "Griffin", "La Supreme Combinasion", "Arcadragon", "Rosey and Teddy",
    "Hydra Bunny", "Ketupat Bros", "Tirilikalika Tirilikalako", "Pancake and Syrup",
    "Cash or Card", "Dragon Gingerini", "Globa Steppa", "Gym Bros", "Money Money Bros",
    "Dug dug dug", "Digi Narwhal", "Popcuru and Fizzuru", "Reinito Sleighito",
    "Los Amigos", "Los Sekolahs", "Los Spaghettis", "Spaghetti Tualetti",
    "Spooky and Pumpky", "Ventoliero Pavonero", "Quackini Snackini", "Sammyni Fattini",
    "Nacho Spyder", "Rosetti Tualetti", "Lavadorito Spinito", "Las Sis", "La Casa Boo",
    "Fragrama and Chocrama", "Cooki and Milki", "Bunny and Eggy", "Celestial Pegasus",
    "Chillin Chili", "Chipso and Queso", "Cloverat Clapat"
}
table.sort(ALL_BRAINROTS)

-- ── UI HELPERS ───────────────────────────────────────────────────────────────
local function GetSafeParent()
    if typeof(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok2, pg = pcall(function() return LocalPlayer.PlayerGui end)
    if ok2 and pg then return pg end
    return game:GetService("CoreGui")
end

local function New(cls, props)
    local ok, obj = pcall(Instance.new, cls)
    if not ok or not obj then return nil end
    if props then
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    return obj
end

local function Corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function Stroke(p, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or LINE
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.3
    s.Parent = p
    return s
end

local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos = false, nil, nil

    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

-- ── HTTP LAYER (executor-agnostic) ───────────────────────────────────────────
local function ResolveRequest()
    -- NOTE: build this list with explicit indices and walk it with a numeric
    -- for. A table constructor whose leading entries are nil has an undefined
    -- border, so ipairs() would stop at the first hole and miss a bare
    -- request() -- which is exactly what most executors expose.
    local candidates = {}
    candidates[1] = (syn and syn.request) or nil
    candidates[2] = (http and http.request) or nil
    candidates[3] = http_request
    candidates[4] = request
    candidates[5] = (fluxus and fluxus.request) or nil
    candidates[6] = (krnl and krnl.request) or nil
    for i = 1, 6 do
        local fn = candidates[i]
        if typeof(fn) == "function" then return fn end
    end
    return nil
end

local RequestFn  = ResolveRequest()
local GITHUB_API = "https://api.github.com"

local function StateFileName() return "spoof-" .. tostring(CONFIG.ROOM) .. ".json" end

local function JSONDecode(text)
    local ok, decoded = pcall(function() return HttpService:JSONDecode(text) end)
    if ok then return decoded end
    return nil
end

local function AuthHeaders(extra)
    local h = {
        ["Accept"]               = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"]           = "DuelSpoofer",
    }
    if CONFIG.TOKEN ~= "" then h["Authorization"] = "Bearer " .. CONFIG.TOKEN end
    for k, v in pairs(extra or {}) do h[k] = v end
    return h
end

-- Writing needs a real POST/PATCH with headers, which game:HttpGet cannot do.
local function GitHubWrite(method, path, bodyTable)
    if not RequestFn then
        return nil, 0, "executor has no request() function - cannot write to GitHub"
    end

    local opts = {
        Url = GITHUB_API .. path,
        Method = method,
        Headers = AuthHeaders({ ["Content-Type"] = "application/json" }),
    }
    if bodyTable then
        local ok, encoded = pcall(function() return HttpService:JSONEncode(bodyTable) end)
        if not ok then return nil, 0, "encode failed" end
        opts.Body = encoded
    end

    local ok, res = pcall(RequestFn, opts)
    if not ok or not res then return nil, 0, tostring(res) end

    local code = res.StatusCode or res.status_code or 0
    local body = res.Body or res.body or ""
    if code < 200 or code >= 300 then
        local msg = body
        local decoded = JSONDecode(body)
        if decoded and decoded.message then msg = decoded.message end
        return nil, code, tostring(msg)
    end
    return JSONDecode(body), code, nil
end

-- Conditional GET. 304 -> unchanged (free when authenticated).
local function GitHubGet(path, etag)
    local url = GITHUB_API .. path

    if RequestFn then
        local headers = AuthHeaders()
        if etag and etag ~= "" then headers["If-None-Match"] = etag end

        local ok, res = pcall(RequestFn, { Url = url, Method = "GET", Headers = headers })
        if not ok or not res then return 0, nil, etag, tostring(res) end

        local code = res.StatusCode or res.status_code or 0
        if code == 304 then return 304, nil, etag, nil end

        -- Executors spell the header table differently; check both.
        local resHeaders = res.Headers or res.headers or {}
        local newEtag = resHeaders["ETag"] or resHeaders["etag"] or etag

        local body = res.Body or res.body or ""
        if code < 200 or code >= 300 then
            local msg = body
            local decoded = JSONDecode(body)
            if decoded and decoded.message then msg = decoded.message end
            return code, nil, etag, tostring(msg)
        end
        return code, JSONDecode(body), newEtag, nil
    end

    -- Fallback: GET-only, unauthenticated, no ETag.
    local getter = (syn and syn.http_get) or game.HttpGet
    local ok, body = pcall(function()
        if getter == game.HttpGet then return game:HttpGet(url, true) end
        return getter(url)
    end)
    if not ok then return 0, nil, etag, tostring(body) end
    return 200, JSONDecode(body), etag, nil
end

-- ── BRAINROT ASSETS ──────────────────────────────────────────────────────────
local BrainrotAssets = nil
pcall(function() BrainrotAssets = require(RS.Shared.BrainrotAssets) end)

local function GetBrainrotModel(name)
    local model = nil
    if BrainrotAssets and type(BrainrotAssets.getModel) == "function" then
        pcall(function()
            local resolved = BrainrotAssets.getModel(name)
            if resolved and resolved:IsA("Model") then model = resolved:Clone() end
        end)
    end
    if not model then
        pcall(function()
            local cached = RS:FindFirstChild("Models")
                and RS.Models:FindFirstChild("Animals")
                and RS.Models.Animals:FindFirstChild(name)
            if cached then model = cached:Clone() end
        end)
    end
    return model
end

local function GetGeneration(name)
    local gen = 0
    pcall(function()
        local AnimalData = require(RS.Datas.Animals)
        if AnimalData and AnimalData[name] then gen = AnimalData[name].Generation or 0 end
    end)
    return gen
end

local function FormatGen(gen)
    if gen >= 1e12 then return string.format("$%.1fT/s", gen / 1e12)
    elseif gen >= 1e9 then return string.format("$%.1fB/s", gen / 1e9)
    elseif gen >= 1e6 then return string.format("$%.1fM/s", gen / 1e6)
    elseif gen >= 1e3 then return string.format("$%.1fK/s", gen / 1e3)
    else return "$" .. tostring(math.floor(gen)) .. "/s" end
end

local function ClearViewport(viewport)
    if not viewport then return end
    for _, child in ipairs(viewport:GetChildren()) do
        pcall(function() child:Destroy() end)
    end
end

local function RenderModelInto(viewport, modelName, spin)
    if not viewport then return false end
    ClearViewport(viewport)
    if not CONFIG.AUTO_RENDER then return false end

    local model = GetBrainrotModel(modelName)
    if not model then return false end

    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery   = false
            part.CanTouch   = false
            part.Anchored   = true
            part.CastShadow = false
        end
    end

    local worldModel = Instance.new("WorldModel")
    worldModel.Parent = viewport

    local camera = Instance.new("Camera")
    camera.FieldOfView = 50
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    model:PivotTo(CFrame.new(0, 0, 0))
    model.Parent = worldModel

    local extents = model:GetExtentsSize()
    local maxDim  = math.max(extents.X, extents.Y, extents.Z)
    local dist    = (maxDim * 0.5 / math.tan(math.rad(25))) * 0.85
    local origin  = Vector3.new(0, extents.Y * 0.05, 0)

    camera.CFrame = CFrame.new(
        origin + Vector3.new(-(dist + maxDim * 0.35), extents.Y * 0.1, 0),
        origin
    )

    task.spawn(function()
        task.wait(0.1)
        pcall(function()
            local ac = model:FindFirstChildOfClass("AnimationController")
            if not ac then
                ac = Instance.new("AnimationController")
                ac.Parent = model
            end
            local animator = ac:FindFirstChildOfClass("Animator")
            if not animator then
                animator = Instance.new("Animator")
                animator.Parent = ac
            end
            local animFolder = RS.Animations.Animals:FindFirstChild(modelName)
            local idle = animFolder and animFolder:FindFirstChild("Idle")
            if idle then
                local track = animator:LoadAnimation(idle)
                track.Looped = true
                track:Play()
            end
        end)
    end)

    if spin then
        task.spawn(function()
            local angle = 0
            while viewport.Parent and worldModel.Parent do
                angle = angle + 0.9
                pcall(function() model:PivotTo(CFrame.Angles(0, math.rad(angle), 0)) end)
                task.wait(0.03)
            end
        end)
    end

    return true
end

-- ── SHARED WINDOW SHELL ──────────────────────────────────────────────────────
local parentGui = GetSafeParent()
local existing = parentGui:FindFirstChild("DuelSpoofer")
if existing then existing:Destroy() end

local sg = New("ScreenGui", {
    Name = "DuelSpoofer",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 5000,
    Parent = parentGui,
})

local WIN_W = 380
local WIN_H = IS_ADMIN and 500 or 480

local win = New("Frame", {
    Size = UDim2.new(0, WIN_W, 0, WIN_H),
    Position = UDim2.new(0.5, -WIN_W / 2, 0.2, 0),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    Active = true,
    Parent = sg,
})
Corner(win, 8)
Stroke(win, LINE, 1.5, 0.3)

local tbar = New("Frame", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = Color3.fromRGB(16, 9, 12),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Parent = win,
})
Corner(tbar, 8)

New("TextLabel", {
    Size = UDim2.new(1, -70, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = IS_ADMIN and "⚔️ Duel Spoofer" or "📡 Duel Spoofer",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = tbar,
})

local liveDot = New("Frame", {
    Size = UDim2.new(0, 8, 0, 8),
    Position = UDim2.new(1, -52, 0.5, -4),
    BackgroundColor3 = Color3.fromRGB(90, 90, 110),
    BorderSizePixel = 0,
    Parent = tbar,
})
Corner(liveDot, 4)

local closeBtn = New("TextButton", {
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -30, 0.5, -12),
    BackgroundColor3 = BTNRED,
    Text = "✕",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    AutoButtonColor = false,
    BorderSizePixel = 0,
    Parent = tbar,
})
Corner(closeBtn, 5)

MakeDraggable(win, tbar)

local content = New("Frame", {
    Size = UDim2.new(1, 0, 1, -30),
    Position = UDim2.new(0, 0, 0, 30),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = win,
})
local pad = Instance.new("UIPadding", content)
pad.PaddingLeft   = UDim.new(0, 10)
pad.PaddingRight  = UDim.new(0, 10)
pad.PaddingTop    = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)

local layout = Instance.new("UIListLayout", content)
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- ── ROLE BANNER (the "on top" line) ──────────────────────────────────────────
local banner = New("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = IS_ADMIN and Color3.fromRGB(45, 12, 20) or Color3.fromRGB(14, 30, 22),
    BorderSizePixel = 0,
    LayoutOrder = 0,
    Parent = content,
})
Corner(banner, 6)
Stroke(banner, IS_ADMIN and ACCENT or BTNGRN, 1.2, 0.25)

New("Frame", {
    Size = UDim2.new(0, 3, 1, 0),
    BackgroundColor3 = IS_ADMIN and ACCENT or BTNGRN,
    BorderSizePixel = 0,
    Parent = banner,
})

New("TextLabel", {
    Size = UDim2.new(1, -18, 0, 15),
    Position = UDim2.new(0, 12, 0, 4),
    BackgroundTransparency = 1,
    Text = IS_ADMIN and "⚡ ADMIN DETECTED" or "👋 WELCOME",
    TextColor3 = IS_ADMIN and ACCENT or BTNGRN,
    Font = Enum.Font.GothamBlack,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = banner,
})

New("TextLabel", {
    Size = UDim2.new(1, -18, 0, 11),
    Position = UDim2.new(0, 12, 0, 19),
    BackgroundTransparency = 1,
    Text = IS_ADMIN
        and (USER_NAME .. " · you control what everyone sees")
        or  (USER_NAME .. " · watching for " .. CONFIG.ADMIN_USER),
    TextColor3 = SUBTEXT,
    Font = Enum.Font.Gotham,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = banner,
})

local statusLbl = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    Text = "Ready",
    TextColor3 = SUBTEXT,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Center,
    LayoutOrder = 90,
    Parent = content,
})

local syncLbl = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "📡 github: starting…",
    TextColor3 = SUBTEXT,
    Font = Enum.Font.Gotham,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Center,
    LayoutOrder = 91,
    Parent = content,
})

closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CONFIG.TOGGLE_KEY then
        win.Visible = not win.Visible
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  ADMIN SIDE
-- ═══════════════════════════════════════════════════════════════════════════
if IS_ADMIN then

local state = { seq = 0, updated = 0, admin = USER_NAME, slots = {} }
local gistReady, lastSyncOk, lastSyncErr = false, nil, nil

local function EncodeState()
    state.admin = USER_NAME
    state.updated = os.time()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(state) end)
    return ok and encoded or "{}"
end

local function WriteGist()
    if CONFIG.GIST_ID == "" then return false, "no GIST_ID" end
    local files = {}
    files[StateFileName()] = { content = EncodeState() }
    local _, code, err = GitHubWrite("PATCH", "/gists/" .. CONFIG.GIST_ID, { files = files })
    if err then
        lastSyncOk, lastSyncErr = false, err
        warn("📡 GitHub write failed (" .. tostring(code) .. "): " .. tostring(err))
        return false, err
    end
    lastSyncOk, lastSyncErr = true, nil
    return true
end

local function EnsureGist()
    if CONFIG.GIST_ID ~= "" then gistReady = true return true end
    if CONFIG.TOKEN == "" then
        warn("📡 No TOKEN set - cannot create a Gist. See README.")
        return false
    end
    local files = {}
    files[StateFileName()] = { content = EncodeState() }
    local data, code, err = GitHubWrite("POST", "/gists", {
        description = "Duel Spoofer sync",
        public = CONFIG.PUBLIC_GIST and true or false,
        files = files,
    })
    if err or not data or not data.id then
        warn("📡 Could not create Gist (" .. tostring(code) .. "): " .. tostring(err))
        return false
    end
    CONFIG.GIST_ID = data.id
    gistReady = true
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📡 Created sync Gist. PUT THIS ID IN THE SCRIPT (both copies):")
    print("     GIST_ID = \"" .. tostring(data.id) .. "\"")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    pcall(function() if setclipboard then setclipboard(tostring(data.id)) end end)
    return true
end

-- Serialise writes: GitHub asks for >=1s between mutating calls, and two
-- in-flight PATCHes can clobber each other. Queue + coalesce instead.
local writeQueued, writing, lastWriteAt = false, false, 0
local function RequestWrite()
    writeQueued = true
    if writing then return end
    writing = true
    task.spawn(function()
        while writeQueued do
            writeQueued = false
            local gap = os.clock() - lastWriteAt
            if gap < 1.1 then task.wait(1.1 - gap) end
            lastWriteAt = os.clock()
            WriteGist()
        end
        writing = false
    end)
end

local currentSlot, currentBrainrot = "Main", ""

local function MirrorLocally(slot, name)
    if not CONFIG.LOCAL_MIRROR then return end
    pcall(function()
        for _, root in ipairs({ RS, Workspace }) do
            local folder = root:FindFirstChild("DuelSpoofSync")
            if not folder then
                folder = Instance.new("Folder")
                folder.Name = "DuelSpoofSync"
                folder.Parent = root
            end
            folder:SetAttribute("Slot", slot)
            folder:SetAttribute("Brainrot", name)
            folder:SetAttribute("Time", tick())
        end
    end)
end

local function BroadcastChoice(slot, name, genValue, genText)
    currentSlot, currentBrainrot = slot, name
    MirrorLocally(slot, name)
    state.seq = state.seq + 1
    state.slots[slot] = {
        slot = slot, brainrot = name,
        gen = genValue or 0, genText = genText or "",
        seq = state.seq, at = os.time(),
    }
    if not gistReady then if not EnsureGist() then return end end
    RequestWrite()
    print("📡 Synced → " .. slot .. " = " .. name)
end

local function BroadcastRevert()
    currentBrainrot = ""
    state.seq = state.seq + 1
    state.slots = {}
    if not gistReady then if not EnsureGist() then return end end
    RequestWrite()
    print("📡 Synced → REVERT")
end

task.spawn(function()
    while true do
        task.wait(1)
        if currentBrainrot ~= "" then MirrorLocally(currentSlot, currentBrainrot) end
    end
end)

task.spawn(function() if CONFIG.TOKEN ~= "" then EnsureGist() end end)

-- FORCE_DRAGON: whatever the admin picks goes out as the dragon.
local function ResolveOutgoing(name)
    if CONFIG.FORCE_DRAGON then return CONFIG.DRAGON_NAME end
    return name
end

-- ── DUEL GUI PLUMBING ────────────────────────────────────────────────────────
local function FindDuelGUI()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local screenGui = pg:FindFirstChild("DuelsMachineSession")
    if not screenGui then return nil end
    local inner = screenGui:FindFirstChild("DuelsMachineSession")
    if not inner then return nil end
    return {
        screenGui = screenGui, inner = inner,
        main = inner:FindFirstChild("Main"),
        other = inner:FindFirstChild("Other"),
    }
end

local function GetViewportData(section)
    if not section then return nil end
    local item = section:FindFirstChild("Item")
    if not item then return nil end
    local vp = item:FindFirstChild("ViewportFrame")
    if not vp then return nil end
    local title = item:FindFirstChild("Title")
    local cash = item:FindFirstChild("Cash")
    return {
        section = section, item = item, viewport = vp,
        title = title, cash = cash,
        name = title and title.Text or "Unknown",
    }
end

local function GetPlayerPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local best, bestDist = nil, math.huge
    local hrpPos = hrp.Position

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") then
            local spawns = {}
            local spawn = plot:FindFirstChild("Spawn")
            if spawn then table.insert(spawns, spawn) end
            local mainRoot = plot:FindFirstChild("MainRoot")
            if mainRoot then table.insert(spawns, mainRoot) end
            local podiums = plot:FindFirstChild("AnimalPodiums")
            if podiums then
                for _, podium in ipairs(podiums:GetChildren()) do
                    local base = podium:FindFirstChild("Base")
                    if base then
                        local sp = base:FindFirstChild("Spawn")
                        if sp then table.insert(spawns, sp) end
                    end
                end
            end
            for _, sp in ipairs(spawns) do
                if sp:IsA("BasePart") then
                    local dist = (sp.Position - hrpPos).Magnitude
                    if dist < bestDist then bestDist, best = dist, plot end
                end
            end
        end
    end
    return best
end

local function GetPodiumPositions(plot)
    local positions = {}
    if not plot then return positions end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return positions end
    for _, podium in ipairs(podiums:GetChildren()) do
        local base = podium:FindFirstChild("Base")
        if base then
            local spawn = base:FindFirstChild("Spawn")
            if spawn and spawn:IsA("BasePart") then
                table.insert(positions, spawn.Position)
            end
        end
    end
    return positions
end

local function RemoveBrainrotsFromPlot()
    local plot = GetPlayerPlot()
    if not plot then return 0 end

    local count = 0
    local podiumPositions = GetPodiumPositions(plot)
    local modelsToCheck = {}
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") then table.insert(modelsToCheck, child) end
    end

    for _, model in ipairs(modelsToCheck) do
        local shouldRemove = false

        if model:GetAttribute("KVSpawned") == true then shouldRemove = true end

        if not shouldRemove and #podiumPositions > 0 then
            local modelPos = model:GetPivot().Position
            for _, pos in ipairs(podiumPositions) do
                if (modelPos - pos).Magnitude < 8 then shouldRemove = true break end
            end
        end

        if not shouldRemove then
            local modelPos = model:GetPivot().Position
            local plotPos = plot:GetPivot().Position
            if (modelPos - plotPos).Magnitude < 60 then
                local hasHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil
                local hasAnimator = model:FindFirstChildOfClass("AnimationController") ~= nil
                local nameMatches = false
                for _, brainrotName in ipairs(ALL_BRAINROTS) do
                    if model.Name == brainrotName then nameMatches = true break end
                end
                if hasHumanoid or hasAnimator or nameMatches then shouldRemove = true end
            end
        end

        if shouldRemove then
            pcall(function() model:Destroy() count = count + 1 end)
        end
    end
    return count
end

local function SwapBrainrot(section, requestedName, slotName)
    if not section then return false, 0 end
    local data = GetViewportData(section)
    if not data or not data.viewport or not data.title or not data.cash then return false, 0 end

    -- FORCE_DRAGON is applied here so the admin's own duel card and the pushed
    -- state always agree with what the tester will be shown.
    local newName = ResolveOutgoing(requestedName)
    local gen = GetGeneration(newName)
    local genText = FormatGen(gen)

    local removed = RemoveBrainrotsFromPlot()
    local success = RenderModelInto(data.viewport, newName, false)

    -- Even if the model asset is missing we still relabel and sync; the tester
    -- falls back to a text badge rather than showing nothing.
    data.title.Text = newName
    data.cash.Text = genText
    BroadcastChoice(slotName or "Main", newName, gen, genText)

    return true, removed, newName
end

-- ── ADMIN GUI ────────────────────────────────────────────────────────────────
if CONFIG.FORCE_DRAGON then
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = "🐉 FORCE DRAGON ON — every pick sends " .. CONFIG.DRAGON_NAME,
        TextColor3 = GOLD,
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = content,
    })
end

New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "SELECT BRAINROT",
    TextColor3 = ACCENT,
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 2,
    Parent = content,
})

local searchRow = New("Frame", {
    Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = Color3.fromRGB(18, 18, 25),
    BorderSizePixel = 0,
    LayoutOrder = 3,
    Parent = content,
})
Corner(searchRow, 5)
Stroke(searchRow, LINE, 1, 0.3)

New("TextLabel", {
    Size = UDim2.new(0, 20, 1, 0),
    Position = UDim2.new(0, 6, 0, 0),
    BackgroundTransparency = 1,
    Text = "🔍",
    TextColor3 = SUBTEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = searchRow,
})

local searchBox = New("TextBox", {
    Size = UDim2.new(1, -30, 1, 0),
    Position = UDim2.new(0, 26, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Search...",
    PlaceholderColor3 = SUBTEXT,
    TextColor3 = TEXT,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    ClearTextOnFocus = false,
    Parent = searchRow,
})

local listFrame = New("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 210),
    BackgroundColor3 = Color3.fromRGB(18, 18, 25),
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = ACCENT,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    LayoutOrder = 4,
    Parent = content,
})
Corner(listFrame, 5)
Stroke(listFrame, LINE, 1, 0.3)

local listLayout = Instance.new("UIListLayout", listFrame)
listLayout.Padding = UDim.new(0, 1)
local listPad = Instance.new("UIPadding", listFrame)
listPad.PaddingLeft   = UDim.new(0, 3)
listPad.PaddingRight  = UDim.new(0, 3)
listPad.PaddingTop    = UDim.new(0, 3)
listPad.PaddingBottom = UDim.new(0, 3)

local actionRow = New("Frame", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 5,
    Parent = content,
})
local actionLayout = Instance.new("UIListLayout", actionRow)
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.Padding = UDim.new(0, 4)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder

local slotSelector = New("Frame", {
    Size = UDim2.new(0, 96, 0, 26),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
    Parent = actionRow,
})
Corner(slotSelector, 4)
Stroke(slotSelector, LINE, 1, 0.3)
local ssLayout = Instance.new("UIListLayout", slotSelector)
ssLayout.FillDirection = Enum.FillDirection.Horizontal
ssLayout.SortOrder = Enum.SortOrder.LayoutOrder

local targetSlot = "Main"
local function MakeSlotBtn(text, slotName)
    local btn = New("TextButton", {
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundColor3 = (targetSlot == slotName) and ACCENT or Color3.fromRGB(30, 30, 40),
        Text = text,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = slotSelector,
    })
    Corner(btn, 3)
    btn.MouseButton1Click:Connect(function()
        targetSlot = slotName
        for _, child in ipairs(slotSelector:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = (child.Text == text) and ACCENT or Color3.fromRGB(30, 30, 40)
            end
        end
    end)
    return btn
end
MakeSlotBtn("MAIN", "Main")
MakeSlotBtn("OTHER", "Other")

local function MakeActionBtn(text, color, cb)
    local btn = New("TextButton", {
        Size = UDim2.new(0, 84, 0, 26),
        BackgroundColor3 = color,
        Text = text,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = actionRow,
    })
    Corner(btn, 4)
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.15)
    end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = color end)
    btn.MouseButton1Click:Connect(cb)
    return btn
end

local function DoSwap(name)
    local duel = FindDuelGUI()
    if not duel then
        statusLbl.Text = "❌ Open the duel GUI first!"
        statusLbl.TextColor3 = BTNRED
        return
    end
    local section = (targetSlot == "Main") and duel.main or duel.other
    if not section then
        statusLbl.Text = "❌ Slot not found!"
        statusLbl.TextColor3 = BTNRED
        return
    end
    local success, removed, sentName = SwapBrainrot(section, name, targetSlot)
    if success then
        statusLbl.Text = "✅ " .. targetSlot .. " → " .. tostring(sentName)
        statusLbl.TextColor3 = SUBTEXT
        if removed and removed > 0 then
            statusLbl.Text = statusLbl.Text .. " (🗑️ " .. removed .. ")"
        end
    else
        statusLbl.Text = "❌ Failed!"
        statusLbl.TextColor3 = BTNRED
    end
end

local brainrotButtons = {}
local function BuildBrainrotList(filter)
    filter = (filter or ""):lower()
    for _, btn in ipairs(brainrotButtons) do pcall(function() btn:Destroy() end) end
    brainrotButtons = {}

    local count = 0
    for _, name in ipairs(ALL_BRAINROTS) do
        if filter == "" or name:lower():find(filter, 1, true) then
            count = count + 1
            local btn = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Color3.fromRGB(15, 15, 22),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                Parent = listFrame,
            })
            Corner(btn, 3)
            btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(35, 25, 35) end)
            btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(15, 15, 22) end)

            New("TextLabel", {
                Size = UDim2.new(0.7, -8, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = TEXT,
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = btn,
            })
            New("TextLabel", {
                Size = UDim2.new(0.3, -8, 1, 0),
                Position = UDim2.new(0.7, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = FormatGen(GetGeneration(name)),
                TextColor3 = BTNGRN,
                Font = Enum.Font.GothamBold,
                TextSize = 8,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = btn,
            })

            btn.MouseButton1Click:Connect(function() DoSwap(name) end)
            table.insert(brainrotButtons, btn)
        end
    end

    if count == 0 then
        local lbl = New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            Text = "No brainrots found",
            TextColor3 = SUBTEXT,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            Parent = listFrame,
        })
        table.insert(brainrotButtons, lbl)
    end
end

MakeActionBtn("DRAGON", BTNGRN, function() DoSwap(CONFIG.DRAGON_NAME) end)

MakeActionBtn("REVERT", BTNRED, function()
    local duel = FindDuelGUI()
    if duel then
        local mainData = GetViewportData(duel.main)
        local otherData = GetViewportData(duel.other)
        if mainData and mainData.viewport then
            ClearViewport(mainData.viewport)
            if mainData.title then mainData.title.Text = "Noobini Pizzanini" end
            if mainData.cash then mainData.cash.Text = "$1/s" end
        end
        if otherData and otherData.viewport then
            ClearViewport(otherData.viewport)
            if otherData.title then otherData.title.Text = "Svinina Bombardino" end
            if otherData.cash then otherData.cash.Text = "$10/s" end
        end
    end
    BroadcastRevert()
    statusLbl.Text = "↩️ Reverted"
    statusLbl.TextColor3 = SUBTEXT
end)

MakeActionBtn("CLEAN", Color3.fromRGB(200, 150, 50), function()
    local removed = RemoveBrainrotsFromPlot()
    statusLbl.Text = "🗑️ Removed " .. removed .. " brainrot(s)"
    statusLbl.TextColor3 = SUBTEXT
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    BuildBrainrotList(searchBox.Text)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        DoSwap(CONFIG.DRAGON_NAME)
    elseif input.KeyCode == Enum.KeyCode.F5 then
        BuildBrainrotList(searchBox.Text or "")
        statusLbl.Text = "🔄 Refreshed"
    elseif input.KeyCode == Enum.KeyCode.F6 then
        local removed = RemoveBrainrotsFromPlot()
        statusLbl.Text = "🗑️ Removed " .. removed .. " brainrot(s)"
    end
end)

BuildBrainrotList("")
statusLbl.Text = "✅ Ready — pick a slot, then a brainrot"

task.spawn(function()
    while syncLbl and syncLbl.Parent do
        if not RequestFn then
            syncLbl.Text = "📡 executor can't POST — admin needs request()"
            syncLbl.TextColor3 = BTNRED
            liveDot.BackgroundColor3 = BTNRED
        elseif CONFIG.TOKEN == "" then
            syncLbl.Text = "📡 no TOKEN set — see README"
            syncLbl.TextColor3 = BTNRED
            liveDot.BackgroundColor3 = BTNRED
        elseif CONFIG.GIST_ID == "" then
            syncLbl.Text = "📡 creating gist…"
            syncLbl.TextColor3 = GOLD
            liveDot.BackgroundColor3 = GOLD
        elseif lastSyncOk == false then
            syncLbl.Text = "📡 sync FAILED: " .. tostring(lastSyncErr or "?"):sub(1, 30)
            syncLbl.TextColor3 = BTNRED
            liveDot.BackgroundColor3 = BTNRED
        elseif lastSyncOk == true then
            syncLbl.Text = "📡 synced → room \"" .. CONFIG.ROOM .. "\""
            syncLbl.TextColor3 = BTNGRN
            liveDot.BackgroundColor3 = BTNGRN
        else
            syncLbl.Text = "📡 ready → room \"" .. CONFIG.ROOM .. "\""
            syncLbl.TextColor3 = SUBTEXT
            liveDot.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
        end
        task.wait(2)
    end
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("⚡ ADMIN DETECTED — " .. USER_NAME)
print("   Force dragon : " .. tostring(CONFIG.FORCE_DRAGON))
print("   Room         : " .. CONFIG.ROOM)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ═══════════════════════════════════════════════════════════════════════════
--  TESTER SIDE
-- ═══════════════════════════════════════════════════════════════════════════
else

New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "INCOMING SPOOF",
    TextColor3 = ACCENT,
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 1,
    Parent = content,
})

local cardRow = New("Frame", {
    Size = UDim2.new(1, 0, 0, 190),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 2,
    Parent = content,
})
local cardLayout = Instance.new("UIListLayout", cardRow)
cardLayout.FillDirection = Enum.FillDirection.Horizontal
cardLayout.Padding = UDim.new(0, 6)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function BuildCard(slotName, color, order)
    local card = New("Frame", {
        Size = UDim2.new(0.5, -3, 1, 0),
        BackgroundColor3 = PANEL,
        BorderSizePixel = 0,
        LayoutOrder = order,
        Parent = cardRow,
    })
    Corner(card, 6)
    local cardStroke = Stroke(card, LINE, 1, 0.3)

    New("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = card,
    })
    New("TextLabel", {
        Size = UDim2.new(1, -12, 0, 12),
        Position = UDim2.new(0, 8, 0, 6),
        BackgroundTransparency = 1,
        Text = slotName:upper() .. " SLOT",
        TextColor3 = color,
        Font = Enum.Font.GothamBold,
        TextSize = 7,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    local viewport = New("ViewportFrame", {
        Size = UDim2.new(1, -16, 0, 104),
        Position = UDim2.new(0, 8, 0, 22),
        BackgroundColor3 = Color3.fromRGB(15, 15, 22),
        BorderSizePixel = 0,
        Ambient = Color3.fromRGB(190, 190, 190),
        LightColor = Color3.fromRGB(255, 255, 255),
        Parent = card,
    })
    Corner(viewport, 5)

    New("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "waiting…",
        TextColor3 = Color3.fromRGB(68, 68, 92),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        Parent = viewport,
    })

    local nameLbl = New("TextLabel", {
        Size = UDim2.new(1, -16, 0, 16),
        Position = UDim2.new(0, 8, 0, 132),
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = card,
    })
    local genLbl = New("TextLabel", {
        Size = UDim2.new(1, -16, 0, 14),
        Position = UDim2.new(0, 8, 0, 150),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = BTNGRN,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
    local metaLbl = New("TextLabel", {
        Size = UDim2.new(1, -16, 0, 12),
        Position = UDim2.new(0, 8, 0, 166),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = SUBTEXT,
        Font = Enum.Font.Gotham,
        TextSize = 7,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    return {
        card = card, stroke = cardStroke, viewport = viewport,
        name = nameLbl, gen = genLbl, meta = metaLbl,
        color = color, lastSeq = -1,
    }
end

local cards = {
    Main  = BuildCard("Main",  ACCENT, 1),
    Other = BuildCard("Other", GOLD,   2),
}

New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "EVENT FEED",
    TextColor3 = ACCENT,
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 3,
    Parent = content,
})

local feed = New("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 140),
    BackgroundColor3 = Color3.fromRGB(18, 18, 25),
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = ACCENT,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    LayoutOrder = 4,
    Parent = content,
})
Corner(feed, 5)
Stroke(feed, LINE, 1, 0.3)

local feedLayout = Instance.new("UIListLayout", feed)
feedLayout.Padding = UDim.new(0, 2)
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
local feedPad = Instance.new("UIPadding", feed)
feedPad.PaddingLeft   = UDim.new(0, 4)
feedPad.PaddingRight  = UDim.new(0, 4)
feedPad.PaddingTop    = UDim.new(0, 4)
feedPad.PaddingBottom = UDim.new(0, 4)

local feedRows, feedOrder = {}, 0
local function AddFeed(text, color)
    feedOrder = feedOrder + 1
    local row = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = color or TEXT,
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = -feedOrder,
        Parent = feed,
    })
    table.insert(feedRows, 1, row)
    while #feedRows > 40 do
        local old = table.remove(feedRows)
        pcall(function() old:Destroy() end)
    end
end

local function FlashCard(entry)
    if not entry or not entry.stroke then return end
    entry.stroke.Color = entry.color
    entry.stroke.Transparency = 0
    TweenService:Create(entry.stroke, TweenInfo.new(0.85), {
        Color = LINE, Transparency = 0.3,
    }):Play()
end

local function ApplySlot(slotName, data)
    local entry = cards[slotName]
    if not entry then return end

    if not data then
        if entry.lastSeq ~= -1 then
            ClearViewport(entry.viewport)
            New("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "waiting…",
                TextColor3 = Color3.fromRGB(68, 68, 92),
                Font = Enum.Font.Gotham,
                TextSize = 10,
                Parent = entry.viewport,
            })
            entry.name.Text = "—"
            entry.gen.Text = ""
            entry.meta.Text = ""
            entry.lastSeq = -1
        end
        return
    end

    if entry.lastSeq == data.seq then return end
    entry.lastSeq = data.seq

    local brainrot = tostring(data.brainrot or "Unknown")
    local genText = data.genText
    if not genText or genText == "" then
        genText = FormatGen(tonumber(data.gen) or GetGeneration(brainrot))
    end

    entry.name.Text = brainrot
    entry.gen.Text  = genText
    entry.meta.Text = "from " .. tostring(data.admin or CONFIG.ADMIN_USER) .. " · #" .. tostring(data.seq)

    if not RenderModelInto(entry.viewport, brainrot, true) then
        ClearViewport(entry.viewport)
        New("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "🐉\n" .. brainrot,
            TextColor3 = SUBTEXT,
            Font = Enum.Font.GothamBold,
            TextSize = 9,
            TextWrapped = true,
            Parent = entry.viewport,
        })
    end

    FlashCard(entry)
    AddFeed("⬇ " .. slotName .. " → " .. brainrot .. "  " .. genText,
            slotName == "Main" and ACCENT or GOLD)
    print("📥 [Tester] " .. slotName .. " → " .. brainrot .. " (" .. genText .. ")")
end

local function ApplyState(st)
    if not st or not st.slots then return end
    ApplySlot("Main",  st.slots.Main)
    ApplySlot("Other", st.slots.Other)
end

-- ── POLL LOOP ────────────────────────────────────────────────────────────────
local running, lastSeq, failures = true, -1, 0
local etag, stateError = nil, nil
local warnedImpostor = false

local function SetLive(isLive, message)
    liveDot.BackgroundColor3 = isLive and BTNGRN or Color3.fromRGB(150, 60, 60)
    statusLbl.Text = message
    statusLbl.TextColor3 = isLive and SUBTEXT or Color3.fromRGB(220, 120, 120)
end

closeBtn.MouseButton1Click:Connect(function() running = false end)

local function ExtractState(gist)
    if not gist or not gist.files then return nil, "gist has no files" end
    local file = gist.files[StateFileName()]
    if not file then
        return nil, "no file \"" .. StateFileName() .. "\" (ROOM mismatch?)"
    end
    if file.truncated then return nil, "state file truncated" end
    local decoded = JSONDecode(file.content or "")
    if not decoded then return nil, "state file is not valid JSON" end
    return decoded, nil
end

task.spawn(function()
    if RequestFn then
        print("📡 [Tester] HTTP transport: executor request()")
    else
        print("📡 [Tester] HTTP transport: game:HttpGet fallback (no ETag, unauthenticated)")
    end
    if CONFIG.TOKEN == "" then
        warn("📡 [Tester] No TOKEN set: unauthenticated 304s still count against the "
             .. "60/hour limit, so updates will be slow. See README.")
    end

    AddFeed("• watching room \"" .. CONFIG.ROOM .. "\" for " .. CONFIG.ADMIN_USER, SUBTEXT)

    if CONFIG.GIST_ID == "" then
        SetLive(false, "🔴 No GIST_ID set — see README")
        AddFeed("✕ GIST_ID is empty", BTNRED)
        return
    end

    local unauthed = (CONFIG.TOKEN == "" or not RequestFn)
    local basePoll = math.max(CONFIG.POLL, unauthed and 60 or 0.8)

    while running and sg.Parent do
        local code, gist, newEtag, err = GitHubGet("/gists/" .. CONFIG.GIST_ID, etag)

        if code == 304 then
            failures = 0
            if stateError then
                SetLive(false, "⚠️ " .. tostring(stateError))
            else
                SetLive(true, "🟢 Live · room \"" .. CONFIG.ROOM .. "\" · seq " .. tostring(lastSeq))
            end

        elseif code == 200 and gist then
            failures = 0
            etag = newEtag
            local data, perr = ExtractState(gist)
            if data then
                -- Only honour a spoof authored by the configured admin.
                local author = tostring(data.admin or "")
                if author:lower() ~= tostring(CONFIG.ADMIN_USER):lower() then
                    stateError = nil
                    if not warnedImpostor then
                        warnedImpostor = true
                        AddFeed("⚠ ignoring push from \"" .. author .. "\" (not "
                                .. CONFIG.ADMIN_USER .. ")", BTNRED)
                        print("⚠️ [Tester] ignored spoof authored by " .. author)
                    end
                    SetLive(true, "🟢 Live · ignoring non-admin push")
                else
                    warnedImpostor = false
                    stateError = nil
                    local seq = tonumber(data.seq) or 0
                    if seq ~= lastSeq then
                        lastSeq = seq
                        ApplyState(data)
                    end
                    SetLive(true, "🟢 Live · room \"" .. CONFIG.ROOM .. "\" · seq " .. tostring(seq))
                end
            else
                if stateError ~= perr then AddFeed("✕ " .. tostring(perr), BTNRED) end
                stateError = perr
                SetLive(false, "⚠️ " .. tostring(perr))
            end

        elseif code == 401 or code == 403 then
            failures = failures + 1
            SetLive(false, "🔴 Auth/rate-limit: " .. tostring(err or code))
            if failures == 1 then AddFeed("✕ " .. tostring(err or code), BTNRED) end

        elseif code == 404 then
            failures = failures + 1
            SetLive(false, "🔴 Gist not found — check GIST_ID")
            if failures == 1 then AddFeed("✕ gist 404 (bad ID, or secret gist needs a token)", BTNRED) end

        else
            failures = failures + 1
            SetLive(false, "🔴 GitHub unreachable (" .. tostring(err or code) .. ")")
            if failures == 1 then AddFeed("✕ " .. tostring(err or code), BTNRED) end
        end

        if failures > 0 then
            task.wait(math.min(basePoll + failures * 2, 30))
        else
            task.wait(basePoll)
        end
    end
end)

task.spawn(function()
    while syncLbl and syncLbl.Parent do
        if CONFIG.TOKEN == "" then
            syncLbl.Text = "📡 no TOKEN — polling once a minute (see README)"
            syncLbl.TextColor3 = GOLD
        else
            syncLbl.Text = "📡 polling gist every " .. tostring(CONFIG.POLL) .. "s"
            syncLbl.TextColor3 = SUBTEXT
        end
        task.wait(5)
    end
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("👋 WELCOME — " .. USER_NAME .. " (tester)")
print("   Watching  : " .. CONFIG.ADMIN_USER)
print("   Room      : " .. CONFIG.ROOM)
print("   Auth      : " .. (CONFIG.TOKEN ~= "" and "token set (fast)" or "NONE (slow, 60/hr)"))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

end
