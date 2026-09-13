-- Duel GUI - Advanced Plot Cleaner & Brainrot Swapper
-- + Improved Broadcast to Receiver

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ── THEME ────────────────────────────────────────────────
local BG = Color3.fromRGB(10, 10, 15)
local ACCENT = Color3.fromRGB(225, 18, 48)
local BTNGRN = Color3.fromRGB(38, 178, 92)
local BTNRED = Color3.fromRGB(200, 50, 50)
local TEXT = Color3.fromRGB(248, 244, 246)
local SUBTEXT = Color3.fromRGB(160, 160, 180)
local GOLD = Color3.fromRGB(255, 215, 0)

-- ── ALL BRAINROTS ──────────────────────────────────────
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

-- ── HELPERS ──────────────────────────────────────────────
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

-- ── MAKE DRAGGABLE ───────────────────────────────────────
local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging = false
    local dragStart = nil
    local startPos = nil

    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                update(input)
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

-- ── BROADCAST TO RECEIVER (Improved) ─────────────────────
local currentSlot = "Main"
local currentBrainrot = ""

local function BroadcastChoice(slot, name)
    currentSlot = slot
    currentBrainrot = name

    local function forceSend()
        -- ReplicatedStorage (more reliable)
        local rsFolder = RS:FindFirstChild("DuelSpoofSync")
        if not rsFolder then
            rsFolder = Instance.new("Folder")
            rsFolder.Name = "DuelSpoofSync"
            rsFolder.Parent = RS
        end
        rsFolder:SetAttribute("Slot", currentSlot)
        rsFolder:SetAttribute("Brainrot", currentBrainrot)
        rsFolder:SetAttribute("Time", tick())

        -- Workspace backup
        local wsFolder = Workspace:FindFirstChild("DuelSpoofSync")
        if not wsFolder then
            wsFolder = Instance.new("Folder")
            wsFolder.Name = "DuelSpoofSync"
            wsFolder.Parent = Workspace
        end
        wsFolder:SetAttribute("Slot", currentSlot)
        wsFolder:SetAttribute("Brainrot", currentBrainrot)
        wsFolder:SetAttribute("Time", tick())
    end

    forceSend()
    print("📡 Broadcasted → " .. slot .. " = " .. name)
end

-- Keep forcing every second
task.spawn(function()
    while true do
        task.wait(1)
        if currentBrainrot ~= "" then
            pcall(function()
                local rsFolder = RS:FindFirstChild("DuelSpoofSync")
                if rsFolder then
                    rsFolder:SetAttribute("Slot", currentSlot)
                    rsFolder:SetAttribute("Brainrot", currentBrainrot)
                    rsFolder:SetAttribute("Time", tick())
                end
            end)
        end
    end
end)

-- ── FIND PLAYER'S PLOT ──────────────────────────────────
local function GetPlayerPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then 
        print("❌ No Plots folder found!")
        return nil 
    end
    
    local char = LocalPlayer.Character
    if not char then 
        print("❌ Character not found!")
        return nil 
    end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then 
        print("❌ HumanoidRootPart not found!")
        return nil 
    end
    
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
                    if dist < bestDist then
                        bestDist = dist
                        best = plot
                    end
                end
            end
        end
    end
    
    if best then
        print("✅ Found your plot: " .. best.Name .. " (distance: " .. math.floor(bestDist) .. " studs)")
    else
        print("❌ Could not find your plot! Make sure you're standing on it.")
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
    if not plot then
        print("❌ Could not find your plot!")
        return 0
    end
    
    local count = 0
    local removedNames = {}
    local podiumPositions = GetPodiumPositions(plot)
    
    local modelsToCheck = {}
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") then
            table.insert(modelsToCheck, child)
        end
    end
    
    for _, model in ipairs(modelsToCheck) do
        local shouldRemove = false
        local reason = ""
        
        if model:GetAttribute("KVSpawned") == true then
            shouldRemove = true
            reason = "KVSpawned attribute"
        end
        
        if not shouldRemove and #podiumPositions > 0 then
            local modelPos = model:GetPivot().Position
            for _, pos in ipairs(podiumPositions) do
                local dist = (modelPos - pos).Magnitude
                if dist < 8 then
                    shouldRemove = true
                    reason = "near podium (dist: " .. math.floor(dist) .. ")"
                    break
                end
            end
        end
        
        if not shouldRemove then
            local modelPos = model:GetPivot().Position
            local plotPos = plot:GetPivot().Position
            local distFromPlot = (modelPos - plotPos).Magnitude
            
            if distFromPlot < 60 then
                local hasHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil
                local hasAnimator = model:FindFirstChildOfClass("AnimationController") ~= nil
                local nameMatches = false
                
                for _, brainrotName in ipairs(ALL_BRAINROTS) do
                    if model.Name == brainrotName then
                        nameMatches = true
                        break
                    end
                end
                
                if hasHumanoid or hasAnimator or nameMatches then
                    shouldRemove = true
                    reason = "brainrot-like (dist: " .. math.floor(distFromPlot) .. ")"
                end
            end
        end
        
        if not shouldRemove then
            local parent = model.Parent
            while parent do
                if parent:IsA("Model") and parent.Name == "AnimalPodiums" then
                    shouldRemove = true
                    reason = "in AnimalPodiums"
                    break
                end
                parent = parent.Parent
            end
        end
        
        if shouldRemove then
            pcall(function() 
                model:Destroy() 
                count = count + 1
                table.insert(removedNames, model.Name)
                print("🗑️ Removed: " .. model.Name .. " (" .. reason .. ")")
            end)
        end
    end
    
    if count > 0 then
        print("✅ Removed " .. count .. " brainrot(s): " .. table.concat(removedNames, ", "))
    else
        print("ℹ️ No brainrots found on your plot")
    end
    
    return count
end

local function FindDuelGUI()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    
    local screenGui = pg:FindFirstChild("DuelsMachineSession")
    if not screenGui then
        for _, child in ipairs(pg:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name == "DuelsMachineSession" then
                screenGui = child
                break
            end
        end
    end
    if not screenGui then return nil end
    
    local inner = screenGui:FindFirstChild("DuelsMachineSession")
    if not inner then return nil end
    
    return {
        screenGui = screenGui,
        inner = inner,
        main = inner:FindFirstChild("Main"),
        other = inner:FindFirstChild("Other")
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
        section = section,
        item = item,
        viewport = vp,
        title = title,
        cash = cash,
        name = title and title.Text or "Unknown"
    }
end

local BrainrotAssets = nil
pcall(function()
    BrainrotAssets = require(RS.Shared.BrainrotAssets)
end)

local function GetBrainrotModel(name)
    local model = nil
    if BrainrotAssets and type(BrainrotAssets.getModel) == "function" then
        pcall(function()
            local resolved = BrainrotAssets.getModel(name)
            if resolved and resolved:IsA("Model") then
                model = resolved:Clone()
            end
        end)
    end
    if not model then
        local cached = RS:FindFirstChild("Models")
            and RS.Models:FindFirstChild("Animals")
            and RS.Models.Animals:FindFirstChild(name)
        if cached then model = cached:Clone() end
    end
    return model
end

local function GetGeneration(name)
    local gen = 0
    pcall(function()
        local AnimalData = require(RS.Datas.Animals)
        if AnimalData and AnimalData[name] then
            gen = AnimalData[name].Generation or 0
        end
    end)
    return gen
end

local function FormatGen(gen)
    if gen >= 1e12 then return string.format("$%.1fT/s", gen/1e12)
    elseif gen >= 1e9 then return string.format("$%.1fB/s", gen/1e9)
    elseif gen >= 1e6 then return string.format("$%.1fM/s", gen/1e6)
    elseif gen >= 1e3 then return string.format("$%.1fK/s", gen/1e3)
    else return "$" .. tostring(math.floor(gen)) .. "/s" end
end

local function ClearViewport(viewport)
    if not viewport then return end
    for _, child in ipairs(viewport:GetChildren()) do
        pcall(function() child:Destroy() end)
    end
end

local function PlaceBrainrotInViewport(viewport, modelName)
    if not viewport then return false end
    
    ClearViewport(viewport)
    
    local model = GetBrainrotModel(modelName)
    if not model then
        print("❌ Could not load model: " .. modelName)
        return false
    end
    
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Anchored = true
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
    local maxDim = math.max(extents.X, extents.Y, extents.Z)
    local dist = (maxDim * 0.5 / math.tan(math.rad(25))) * 0.85
    
    local lookAt = model.PrimaryPart and model.PrimaryPart.CFrame or CFrame.new(0, 0, 0)
    local camPos = lookAt.Position + Vector3.new(-(dist + maxDim * 0.35), extents.Y * 0.1, 0)
    local lookTarget = lookAt.Position + Vector3.new(0, extents.Y * 0.05, 0)
    
    camera.CFrame = CFrame.new(camPos, lookTarget)
    
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
            if animFolder then
                local idle = animFolder:FindFirstChild("Idle")
                if idle then
                    local track = animator:LoadAnimation(idle)
                    track.Looped = true
                    track:Play()
                    track:AdjustSpeed(1)
                end
            end
        end)
    end)
    
    return true
end

local function SwapBrainrot(section, newName, slotName)
    if not section then return false, 0 end
    
    local data = GetViewportData(section)
    if not data or not data.viewport or not data.title or not data.cash then
        return false, 0
    end
    
    local oldName = data.title.Text
    local gen = GetGeneration(newName)
    local genText = FormatGen(gen)
    
    print("🗑️ Cleaning plot...")
    local removed = RemoveBrainrotsFromPlot()
    
    local success = PlaceBrainrotInViewport(data.viewport, newName)
    
    if success then
        data.title.Text = newName
        data.cash.Text = genText
        
        print("✅ Swapped " .. oldName .. " → " .. newName .. " (" .. genText .. ")")
        
        -- Broadcast to receiver
        BroadcastChoice(slotName or "Main", newName)
        
        return true, removed
    end
    
    return false, 0
end

-- ── GUI ──────────────────────────────────────────────────
if GetSafeParent():FindFirstChild("DuelSwapper") then
    GetSafeParent():FindFirstChild("DuelSwapper"):Destroy()
end

local sg = New("ScreenGui", {
    Name = "DuelSwapper",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 5000,
    Parent = GetSafeParent(),
})

local WIN_W = 380
local WIN_H = 460
local win = New("Frame", {
    Size = UDim2.new(0, WIN_W, 0, WIN_H),
    Position = UDim2.new(0.5, -WIN_W/2, 0.25, 0),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    Active = true,
    Parent = sg,
})
Corner(win, 8)
local stroke = Instance.new("UIStroke", win)
stroke.Color = Color3.fromRGB(60, 60, 80)
stroke.Thickness = 1.5
stroke.Transparency = 0.3

local tbar = New("Frame", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = Color3.fromRGB(16, 9, 12),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Parent = win,
})
Corner(tbar, 8)

New("TextLabel", {
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "⚔️ Duel Swapper",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = tbar,
})

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
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

MakeDraggable(win, tbar)

local mainContent = New("Frame", {
    Size = UDim2.new(1, 0, 1, -30),
    Position = UDim2.new(0, 0, 0, 30),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = win,
})

local pad = Instance.new("UIPadding", mainContent)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)

local mainLayout = Instance.new("UIListLayout", mainContent)
mainLayout.Padding = UDim.new(0, 6)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder

local slotSection = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 1,
    Parent = mainContent,
})

New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "CURRENT DUEL SLOTS",
    TextColor3 = ACCENT,
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = slotSection,
})

local slotContainer = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = slotSection,
})

local slotLayout = Instance.new("UIListLayout", slotContainer)
slotLayout.FillDirection = Enum.FillDirection.Horizontal
slotLayout.Padding = UDim.new(0, 6)
slotLayout.SortOrder = Enum.SortOrder.LayoutOrder

local slotFrames = {}

local function UpdateSlots()
    for _, f in ipairs(slotFrames) do
        pcall(function() f:Destroy() end)
    end
    slotFrames = {}
    
    local duel = FindDuelGUI()
    if not duel then
        local lbl = New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = "Open duel GUI",
            TextColor3 = SUBTEXT,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = slotContainer,
        })
        table.insert(slotFrames, lbl)
        return
    end
    
    local sections = {}
    if duel.main then table.insert(sections, {section = duel.main, name = "Main"}) end
    if duel.other then table.insert(sections, {section = duel.other, name = "Other"}) end
    
    for _, data in ipairs(sections) do
        local info = GetViewportData(data.section)
        if info then
            local frame = New("Frame", {
                Size = UDim2.new(0, 170, 0, 50),
                BackgroundColor3 = Color3.fromRGB(25, 25, 35),
                BorderSizePixel = 0,
                Parent = slotContainer,
            })
            Corner(frame, 5)
            local s = Instance.new("UIStroke", frame)
            s.Color = Color3.fromRGB(60, 60, 80)
            s.Thickness = 1
            s.Transparency = 0.3
            
            local color = data.name == "Main" and ACCENT or GOLD
            New("Frame", {
                Size = UDim2.new(1, 0, 0, 2),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Parent = frame,
            })
            
            New("TextLabel", {
                Size = UDim2.new(1, -10, 0, 12),
                Position = UDim2.new(0, 8, 0, 4),
                BackgroundTransparency = 1,
                Text = data.name,
                TextColor3 = color,
                Font = Enum.Font.GothamBold,
                TextSize = 7,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            
            New("TextLabel", {
                Size = UDim2.new(1, -10, 0, 18),
                Position = UDim2.new(0, 8, 0, 18),
                BackgroundTransparency = 1,
                Text = info.name:len() > 15 and info.name:sub(1, 13)..".." or info.name,
                TextColor3 = TEXT,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            
            New("TextLabel", {
                Size = UDim2.new(1, -10, 0, 14),
                Position = UDim2.new(0, 8, 0, 34),
                BackgroundTransparency = 1,
                Text = info.cash and info.cash.Text or "",
                TextColor3 = BTNGRN,
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            
            table.insert(slotFrames, frame)
        end
    end
end

local listSection = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 2,
    Parent = mainContent,
})

New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "SELECT BRAINROT",
    TextColor3 = ACCENT,
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = listSection,
})

local searchRow = New("Frame", {
    Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = Color3.fromRGB(18, 18, 25),
    BorderSizePixel = 0,
    Parent = listSection,
})
Corner(searchRow, 5)
local s = Instance.new("UIStroke", searchRow)
s.Color = Color3.fromRGB(60, 60, 80)
s.Thickness = 1
s.Transparency = 0.3

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
    Size = UDim2.new(1, 0, 0, 200),
    BackgroundColor3 = Color3.fromRGB(18, 18, 25),
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = ACCENT,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = listSection,
})
Corner(listFrame, 5)
local s2 = Instance.new("UIStroke", listFrame)
s2.Color = Color3.fromRGB(60, 60, 80)
s2.Thickness = 1
s2.Transparency = 0.3

local listLayout2 = Instance.new("UIListLayout", listFrame)
listLayout2.Padding = UDim.new(0, 1)

local listPad2 = Instance.new("UIPadding", listFrame)
listPad2.PaddingLeft = UDim.new(0, 3)
listPad2.PaddingRight = UDim.new(0, 3)
listPad2.PaddingTop = UDim.new(0, 3)
listPad2.PaddingBottom = UDim.new(0, 3)

local actionSection = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 3,
    Parent = mainContent,
})

local actionRow = New("Frame", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = actionSection,
})

local actionLayout = Instance.new("UIListLayout", actionRow)
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.Padding = UDim.new(0, 4)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder

local slotSelector = New("Frame", {
    Size = UDim2.new(0, 100, 0, 26),
    BackgroundColor3 = Color3.fromRGB(25, 25, 35),
    BorderSizePixel = 0,
    Parent = actionRow,
})
Corner(slotSelector, 4)
local ss = Instance.new("UIStroke", slotSelector)
ss.Color = Color3.fromRGB(60, 60, 80)
ss.Thickness = 1
ss.Transparency = 0.3

local targetSlot = "Main"
local slotSelectorLayout = Instance.new("UIListLayout", slotSelector)
slotSelectorLayout.FillDirection = Enum.FillDirection.Horizontal
slotSelectorLayout.Padding = UDim.new(0, 0)
slotSelectorLayout.SortOrder = Enum.SortOrder.LayoutOrder

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
        Size = UDim2.new(0, 70, 0, 26),
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
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = color
    end)
    btn.MouseButton1Click:Connect(cb)
    return btn
end

local statusLbl = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    Text = "Ready",
    TextColor3 = SUBTEXT,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Center,
    LayoutOrder = 4,
    Parent = mainContent,
})

local brainrotButtons = {}

local function BuildBrainrotList(filter)
    filter = (filter or ""):lower()
    
    for _, btn in ipairs(brainrotButtons) do
        pcall(function() btn:Destroy() end)
    end
    brainrotButtons = {}
    
    local count = 0
    for _, name in ipairs(ALL_BRAINROTS) do
        if filter == "" or name:lower():find(filter, 1, true) then
            count = count + 1
            local btn = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Color3.fromRGB(15, 15, 22),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                Parent = listFrame,
            })
            Corner(btn, 3)
            
            btn.MouseEnter:Connect(function()
                btn.BackgroundColor3 = Color3.fromRGB(35, 25, 35)
            end)
            btn.MouseLeave:Connect(function()
                btn.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
            end)
            
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
            
            local gen = GetGeneration(name)
            local genText = FormatGen(gen)
            New("TextLabel", {
                Size = UDim2.new(0.3, -8, 1, 0),
                Position = UDim2.new(0.7, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = genText,
                TextColor3 = BTNGRN,
                Font = Enum.Font.GothamBold,
                TextSize = 8,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = btn,
            })
            
            btn.MouseButton1Click:Connect(function()
                local duel = FindDuelGUI()
                if not duel then
                    statusLbl.Text = "❌ Open duel GUI!"
                    return
                end
                
                local section = (targetSlot == "Main") and duel.main or duel.other
                if not section then
                    statusLbl.Text = "❌ Slot not found!"
                    return
                end
                
                local success, removed = SwapBrainrot(section, name, targetSlot)
                if success then
                    statusLbl.Text = "✅ " .. targetSlot .. " → " .. name
                    if removed > 0 then
                        statusLbl.Text = statusLbl.Text .. " (🗑️ " .. removed .. " removed)"
                    end
                    UpdateSlots()
                else
                    statusLbl.Text = "❌ Failed!"
                end
            end)
            
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
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = listFrame,
        })
        table.insert(brainrotButtons, lbl)
    end
end

MakeActionBtn("REPLACE", BTNGRN, function()
    local duel = FindDuelGUI()
    if not duel then
        statusLbl.Text = "❌ Open duel GUI!"
        return
    end
    
    local section = (targetSlot == "Main") and duel.main or duel.other
    if not section then
        statusLbl.Text = "❌ Slot not found!"
        return
    end
    
    local success, removed = SwapBrainrot(section, "Dragon Cannelloni", targetSlot)
    if success then
        statusLbl.Text = "✅ Dragon Cannelloni!"
        if removed > 0 then
            statusLbl.Text = statusLbl.Text .. " (🗑️ " .. removed .. " removed)"
        end
        UpdateSlots()
    else
        statusLbl.Text = "❌ Failed!"
    end
end)

MakeActionBtn("REVERT", BTNRED, function()
    local duel = FindDuelGUI()
    if not duel then return end
    
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
    
    statusLbl.Text = "↩️ Reverted"
    UpdateSlots()
end)

MakeActionBtn("CLEAN PLOT", Color3.fromRGB(200, 150, 50), function()
    local removed = RemoveBrainrotsFromPlot()
    statusLbl.Text = "🗑️ Removed " .. removed .. " brainrot(s) from plot"
    UpdateSlots()
end)

MakeActionBtn("REFRESH", Color3.fromRGB(60, 60, 80), function()
    BuildBrainrotList(searchBox.Text or "")
    UpdateSlots()
    statusLbl.Text = "🔄 Refreshed"
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    BuildBrainrotList(searchBox.Text)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        local duel = FindDuelGUI()
        if duel then
            local section = (targetSlot == "Main") and duel.main or duel.other
            if section then
                local success, removed = SwapBrainrot(section, "Dragon Cannelloni", targetSlot)
                if success then
                    statusLbl.Text = "✅ Dragon Cannelloni!"
                    if removed > 0 then
                        statusLbl.Text = statusLbl.Text .. " (🗑️ " .. removed .. " removed)"
                    end
                    UpdateSlots()
                end
            end
        end
    elseif input.KeyCode == Enum.KeyCode.F5 then
        BuildBrainrotList(searchBox.Text or "")
        UpdateSlots()
        statusLbl.Text = "🔄 Refreshed"
    elseif input.KeyCode == Enum.KeyCode.F6 then
        local removed = RemoveBrainrotsFromPlot()
        statusLbl.Text = "🗑️ Removed " .. removed .. " brainrot(s)"
        UpdateSlots()
    end
end)

BuildBrainrotList("")
task.delay(0.3, function()
    UpdateSlots()
    statusLbl.Text = "✅ Ready - Select slot & click brainrot"
    statusLbl.TextColor3 = SUBTEXT
end)

task.spawn(function()
    while sg and sg.Parent do
        task.wait(3)
        pcall(UpdateSlots)
    end
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("⚔️ Duel Swapper + Improved Broadcast Loaded!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
