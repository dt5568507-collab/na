-- ROBLOX DELTA COMPATIBLE - REMOTE FORCE LOAD VERSION
-- Solves the exact problem: "只有他加載出來才能預覽"
-- Now uses REMOTE calls first to attempt forcing the server to replicate
-- the target player's build data EVEN IF they are not currently loaded/streamed to you.
-- Then falls back to normal Workspace.Blocks check + force spawn in front of you.
-- Player avatars still included.

local oldGui = game:GetService("CoreGui"):FindFirstChild("InventoryTrackerGui")
if oldGui then oldGui:Destroy() end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "InventoryTrackerGui"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function styleCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
end

local currentMode = "Data"
local activeTargetPlayer = nil
local liveConnections = {}
local playerTitleConnections = {}

local rainbowElements = {}
local shakingFrames = {}

-- ==================== GUI ====================
local ListFrame = Instance.new("Frame")
ListFrame.Name = "ListFrame"
ListFrame.Parent = ScreenGui
ListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ListFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
ListFrame.Size = UDim2.new(0, 200, 0, 320)
ListFrame.Active = true
ListFrame.Draggable = true
styleCorner(ListFrame, 8)

local ListTitle = Instance.new("TextLabel")
ListTitle.Parent = ListFrame
ListTitle.Size = UDim2.new(1, 0, 0, 28)
ListTitle.BackgroundTransparency = 1
ListTitle.Font = Enum.Font.SourceSansBold
ListTitle.Text = "PLAYER LIST + REMOTE FORCE"
ListTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
ListTitle.TextSize = 15

-- Search bar for player list (new feature)
local PlayerSearchBar = Instance.new("TextBox")
PlayerSearchBar.Name = "PlayerSearchBar"
PlayerSearchBar.Parent = ListFrame
PlayerSearchBar.Size = UDim2.new(1, -10, 0, 24)
PlayerSearchBar.Position = UDim2.new(0, 5, 0, 30)
PlayerSearchBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PlayerSearchBar.BorderSizePixel = 0
PlayerSearchBar.Font = Enum.Font.SourceSans
PlayerSearchBar.PlaceholderText = "Search player name (or type name + Enter to force preview)..."
PlayerSearchBar.Text = ""
PlayerSearchBar.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerSearchBar.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
PlayerSearchBar.TextSize = 13
PlayerSearchBar.TextXAlignment = Enum.TextXAlignment.Left
styleCorner(PlayerSearchBar, 4)

local PlayerSearchPadding = Instance.new("UIPadding")
PlayerSearchPadding.PaddingLeft = UDim.new(0, 8)
PlayerSearchPadding.Parent = PlayerSearchBar

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Parent = ListFrame
PlayerScroll.BackgroundTransparency = 1
PlayerScroll.Position = UDim2.new(0, 5, 0, 58)
PlayerScroll.Size = UDim2.new(1, -10, 1, -63)
PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerScroll.ScrollBarThickness = 4

local PlayerLayout = Instance.new("UIListLayout")
PlayerLayout.Parent = PlayerScroll
PlayerLayout.SortOrder = Enum.SortOrder.Name
PlayerLayout.Padding = UDim.new(0, 5)

PlayerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, PlayerLayout.AbsoluteContentSize.Y)
end)

-- Player list search + force preview by name
PlayerSearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local txt = string.lower(PlayerSearchBar.Text)
    for _, child in ipairs(PlayerScroll:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            local nameLbl = child:FindFirstChild("NameLbl") or child:FindFirstChildOfClass("TextLabel")
            if nameLbl then
                child.Visible = (txt == "" or string.find(string.lower(nameLbl.Text), txt))
            end
        end
    end
end)

PlayerSearchBar.FocusLost:Connect(function(enterPressed)
    if enterPressed and PlayerSearchBar.Text ~= "" then
        local searchName = PlayerSearchBar.Text
        -- Try to find existing player
        local target = Players:FindFirstChild(searchName)
        if target then
            loadPlayerDataDisplay(target)
        else
            -- Force remote attempt even if player not currently in server list
            PreviewTitle.Text = "Force Remote: " .. searchName
            PreviewInfoLabel.Text = "Attempting remote query for " .. searchName .. "..."
            PreviewFrame.Visible = true

            -- Try remote
            pcall(function()
                local blockReq = workspace:FindFirstChild("BlockRequestsRemote")
                if blockReq and blockReq:IsA("RemoteFunction") then
                    blockReq:InvokeServer(searchName)
                end
                local queueReq = ReplicatedStorage:FindFirstChild("InputLocalScript")
                    and ReplicatedStorage.InputLocalScript:FindFirstChild("QueueBlocksRequest")
                if queueReq and queueReq:IsA("RemoteEvent") then
                    queueReq:FireServer(searchName)
                end
            end)

            task.wait(1.5)

            -- Try to spawn if now available
            local blocksRoot = workspace:FindFirstChild("Blocks")
            local playerBuild = blocksRoot and blocksRoot:FindFirstChild(searchName)
            local localChar = Players.LocalPlayer.Character
            if playerBuild and localChar and localChar:FindFirstChild("HumanoidRootPart") then
                local root = localChar.HumanoidRootPart
                local prev = workspace:FindFirstChild("ForcePreview_" .. searchName)
                if prev then prev:Destroy() end

                local newModel = Instance.new("Model")
                newModel.Name = "ForcePreview_" .. searchName
                newModel.Parent = workspace
                for _, child in ipairs(playerBuild:GetChildren()) do
                    if child:IsA("Model") then
                        child:Clone().Parent = newModel
                    end
                end
                local spawnPos = root.Position + root.CFrame.LookVector * 14 + Vector3.new(0, 7, 0)
                newModel:PivotTo(CFrame.new(spawnPos))
                PreviewInfoLabel.Text = "Force spawned from remote query!"
            else
                PreviewInfoLabel.Text = "Remote query sent. Build may not be available or player not in this server."
            end
        end
        PlayerSearchBar.Text = ""
    end
end)

local DetailFrame = Instance.new("Frame")
DetailFrame.Name = "DetailFrame"
DetailFrame.Parent = ScreenGui
DetailFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
DetailFrame.Position = UDim2.new(0.05, 210, 0.3, 0)
DetailFrame.Size = UDim2.new(0, 290, 0, 320)
DetailFrame.Visible = false
DetailFrame.Active = true
DetailFrame.Draggable = true
styleCorner(DetailFrame, 8)

local UserLabel = Instance.new("TextLabel")
UserLabel.Parent = DetailFrame
UserLabel.Size = UDim2.new(1, -130, 0, 35)
UserLabel.Position = UDim2.new(0, 10, 0, 0)
UserLabel.BackgroundTransparency = 1
UserLabel.Font = Enum.Font.SourceSansBold
UserLabel.Text = "Username's Data"
UserLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
UserLabel.TextSize = 15
UserLabel.TextXAlignment = Enum.TextXAlignment.Left

local SearchBar = Instance.new("TextBox")
SearchBar.Name = "SearchBar"
SearchBar.Parent = DetailFrame
SearchBar.Size = UDim2.new(1, -10, 0, 25)
SearchBar.Position = UDim2.new(0, 5, 0, 35)
SearchBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SearchBar.BorderSizePixel = 0
SearchBar.Font = Enum.Font.SourceSans
SearchBar.PlaceholderText = "Search item or slot name..."
SearchBar.Text = ""
SearchBar.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBar.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
SearchBar.TextSize = 14
SearchBar.TextXAlignment = Enum.TextXAlignment.Left
styleCorner(SearchBar, 4)

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingLeft = UDim.new(0, 8)
UIPadding.Parent = SearchBar

local ItemScroll = Instance.new("ScrollingFrame")
ItemScroll.Parent = DetailFrame
ItemScroll.BackgroundTransparency = 1
ItemScroll.Position = UDim2.new(0, 5, 0, 65)
ItemScroll.Size = UDim2.new(1, -10, 1, -70)
ItemScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ItemScroll.ScrollBarThickness = 4

local ItemLayout = Instance.new("UIListLayout")
ItemLayout.Parent = ItemScroll
ItemLayout.SortOrder = Enum.SortOrder.LayoutOrder
ItemLayout.Padding = UDim.new(0, 4)

ItemLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ItemScroll.CanvasSize = UDim2.new(0, 0, 0, ItemLayout.AbsoluteContentSize.Y)
end)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = DetailFrame
CloseBtn.Position = UDim2.new(1, -25, 0, 8)
CloseBtn.Size = UDim2.new(0, 18, 0, 18)
CloseBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 11
styleCorner(CloseBtn, 9)

local SwitchBtn = Instance.new("TextButton")
SwitchBtn.Parent = DetailFrame
SwitchBtn.Position = UDim2.new(1, -115, 0, 6)
SwitchBtn.Size = UDim2.new(0, 85, 0, 22)
SwitchBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SwitchBtn.Font = Enum.Font.SourceSansBold
SwitchBtn.Text = "SWITCH MODE"
SwitchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SwitchBtn.TextSize = 11
styleCorner(SwitchBtn, 4)

-- ==================== HELPERS ====================
local function isFiltered(itemName)
    if string.find(itemName, "Tool") then return true end
    local badSuffixes = {"XY", "XZ", "YZ", "X", "Y", "Z"}
    for _, suffix in ipairs(badSuffixes) do
        if string.sub(itemName, -string.len(suffix)) == suffix then return true end
    end
    return false
end

local function getInventoryTemplateData(itemName)
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return "", "" end
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        local blocksFrame = playerGui:FindFirstChild("BuildGui")
            and playerGui.BuildGui:FindFirstChild("InventoryFrame")
            and playerGui.BuildGui.InventoryFrame:FindFirstChild("ScrollingFrame")
            and playerGui.BuildGui.InventoryFrame.ScrollingFrame:FindFirstChild("BlocksFrame")
        if blocksFrame then
            local visualTemplate = blocksFrame:FindFirstChild(itemName)
            if visualTemplate then
                local typeIconId = ""
                local frameImageId = ""
                if visualTemplate:FindFirstChild("TypeIcon") and visualTemplate.TypeIcon:IsA("ImageLabel") then
                    typeIconId = visualTemplate.TypeIcon.Image
                end
                if visualTemplate:IsA("ImageButton") then
                    frameImageId = visualTemplate.Image
                end
                return typeIconId, frameImageId
            end
        end
    end
    return "", ""
end

local function updateLabelStyle(rowFrame, valueLabel, imagesList, value)
    local num = tonumber(value) or 0
    valueLabel.TextStrokeTransparency = 1
    rainbowElements[valueLabel] = nil
    shakingFrames[rowFrame] = nil
    for _, img in ipairs(imagesList) do rainbowElements[img] = nil end
    rowFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

    if num >= 10000000 then
        rainbowElements[valueLabel] = "Text"
        shakingFrames[rowFrame] = true
        for _, img in ipairs(imagesList) do rainbowElements[img] = "Image" end
    elseif num < 10 then
        valueLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    elseif num >= 10 and num < 100 then
        valueLabel.TextColor3 = Color3.fromRGB(255, 220, 0)
    elseif num >= 100 and num < 1000 then
        valueLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    elseif num >= 1000 and num < 10000 then
        valueLabel.TextColor3 = Color3.fromRGB(180, 50, 255)
    elseif num >= 10000 and num < 100000 then
        valueLabel.TextColor3 = Color3.fromRGB(255, 120, 0)
        valueLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        valueLabel.TextStrokeTransparency = 0
    elseif num >= 100000 and num < 1000000 then
        valueLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
        valueLabel.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
        valueLabel.TextStrokeTransparency = 0
    else
        rainbowElements[valueLabel] = "Text"
    end
end

task.spawn(function()
    local rng = Random.new()
    while task.wait() do
        local hue = (tick() % 1.5) / 1.5
        local rainbowColor = Color3.fromHSV(hue, 0.85, 1)
        for element, mode in pairs(rainbowElements) do
            if element and element.Parent then
                if mode == "Text" then element.TextColor3 = rainbowColor
                elseif mode == "Image" then element.ImageColor3 = rainbowColor end
            end
        end
        for frame in pairs(shakingFrames) do
            if frame and frame.Parent then
                frame.Position = UDim2.new(0, rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
            end
        end
    end
end)

local function updatePlayerDataDisplays(player, titleLabel, countLabel)
    rainbowElements[titleLabel] = nil
    titleLabel.TextStrokeTransparency = 1
    local dataFolder = player:FindFirstChild("Data")
    if not dataFolder then
        countLabel.Text = "[Items: 0]"
        titleLabel.Text = "[No Data]"
        titleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        return
    end
    local totalItems = 0
    for _, child in ipairs(dataFolder:GetChildren()) do
        if child:IsA("ValueBase") and not string.find(string.lower(child.Name), "gold") then
            totalItems = totalItems + (tonumber(child.Value) or 0)
        end
    end
    countLabel.Text = string.format("[Items: %s]", string.format("%.0f", totalItems):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))
    if totalItems < 100 then titleLabel.Text = "Starter" titleLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
    elseif totalItems < 1000 then titleLabel.Text = "Little Pro" titleLabel.TextColor3 = Color3.fromRGB(0, 230, 100)
    elseif totalItems < 5000 then titleLabel.Text = "Pro" titleLabel.TextColor3 = Color3.fromRGB(255, 230, 0)
    elseif totalItems < 20000 then titleLabel.Text = "Very Pro" titleLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    elseif totalItems < 100000 then titleLabel.Text = "Serious Pro" titleLabel.TextColor3 = Color3.fromRGB(170, 50, 255)
    elseif totalItems < 1000000 then titleLabel.Text = "OG" titleLabel.TextColor3 = Color3.fromRGB(255, 120, 0)
    elseif totalItems < 10000000 then titleLabel.Text = "Hacker" titleLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    else titleLabel.Text = "GOD" rainbowElements[titleLabel] = "Text" end
end

local function setupRankTracking(player, titleLabel, countLabel)
    if playerTitleConnections[player.Name] then for _, c in ipairs(playerTitleConnections[player.Name]) do c:Disconnect() end end
    playerTitleConnections[player.Name] = {}
    local function watchDataFolder()
        local dataFolder = player:FindFirstChild("Data")
        if dataFolder then
            local function hookItems()
                updatePlayerDataDisplays(player, titleLabel, countLabel)
                for _, item in ipairs(dataFolder:GetChildren()) do
                    if item:IsA("ValueBase") then
                        table.insert(playerTitleConnections[player.Name], item.Changed:Connect(function() updatePlayerDataDisplays(player, titleLabel, countLabel) end))
                    end
                end
            end
            hookItems()
            table.insert(playerTitleConnections[player.Name], dataFolder.ChildAdded:Connect(function() task.wait(0.1) hookItems() end))
        end
    end
    watchDataFolder()
    table.insert(playerTitleConnections[player.Name], player.ChildAdded:Connect(function(child) if child.Name == "Data" then watchDataFolder() end end))
end

local function clearInventoryConnections()
    for _, c in ipairs(liveConnections) do c:Disconnect() end
    liveConnections = {}
    for f in pairs(shakingFrames) do shakingFrames[f] = nil end
    for _, child in ipairs(ItemScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
end

SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local txt = string.lower(SearchBar.Text)
    for _, child in ipairs(ItemScroll:GetChildren()) do
        if child:IsA("Frame") then
            local lbl = child:FindFirstChild("ItemNameLabel")
            if lbl then child.Visible = (txt == "" or string.find(string.lower(lbl.Text), txt)) end
        end
    end
end)

-- ==================== REMOTE FORCE LOAD + PREVIEW ====================
-- Key new feature: Try to use remotes to force server to send build data
-- even if the player/build is not currently replicated to your client.

local PreviewFrame = Instance.new("Frame")
PreviewFrame.Name = "SlotPreviewFrame"
PreviewFrame.Parent = ScreenGui
PreviewFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
PreviewFrame.Position = UDim2.new(0.32, 0, 0.28, 0)
PreviewFrame.Size = UDim2.new(0, 320, 0, 280)
PreviewFrame.Visible = false
PreviewFrame.Active = true
PreviewFrame.Draggable = true
styleCorner(PreviewFrame, 8)

local PreviewTitle = Instance.new("TextLabel")
PreviewTitle.Parent = PreviewFrame
PreviewTitle.Size = UDim2.new(1, -40, 0, 28)
PreviewTitle.Position = UDim2.new(0, 10, 0, 6)
PreviewTitle.BackgroundTransparency = 1
PreviewTitle.Font = Enum.Font.SourceSansBold
PreviewTitle.Text = "REMOTE FORCE PREVIEW"
PreviewTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
PreviewTitle.TextSize = 15

local PreviewClose = Instance.new("TextButton")
PreviewClose.Parent = PreviewFrame
PreviewClose.Position = UDim2.new(1, -26, 0, 6)
PreviewClose.Size = UDim2.new(0, 20, 0, 20)
PreviewClose.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
PreviewClose.Font = Enum.Font.SourceSansBold
PreviewClose.Text = "X"
PreviewClose.TextColor3 = Color3.fromRGB(255, 255, 255)
PreviewClose.TextSize = 12
styleCorner(PreviewClose, 6)

local PreviewViewport = Instance.new("ViewportFrame")
PreviewViewport.Parent = PreviewFrame
PreviewViewport.Size = UDim2.new(1, -20, 0, 160)
PreviewViewport.Position = UDim2.new(0, 10, 0, 38)
PreviewViewport.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
PreviewViewport.Ambient = Color3.fromRGB(130, 130, 150)
PreviewViewport.LightColor = Color3.fromRGB(255, 255, 255)
PreviewViewport.LightDirection = Vector3.new(0.5, -0.9, 0.3)
styleCorner(PreviewViewport, 4)

local PV_Cam = Instance.new("Camera")
PV_Cam.FieldOfView = 70
PV_Cam.Parent = PreviewViewport
PreviewViewport.CurrentCamera = PV_Cam

local PV_World = Instance.new("WorldModel")
PV_World.Parent = PreviewViewport

local PreviewInfoLabel = Instance.new("TextLabel")
PreviewInfoLabel.Parent = PreviewFrame
PreviewInfoLabel.Size = UDim2.new(1, -20, 0, 18)
PreviewInfoLabel.Position = UDim2.new(0, 10, 0, 205)
PreviewInfoLabel.BackgroundTransparency = 1
PreviewInfoLabel.Font = Enum.Font.SourceSans
PreviewInfoLabel.Text = ""
PreviewInfoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
PreviewInfoLabel.TextSize = 13

local SpawnWorkspaceBtn = Instance.new("TextButton")
SpawnWorkspaceBtn.Parent = PreviewFrame
SpawnWorkspaceBtn.Position = UDim2.new(0, 10, 0, 230)
SpawnWorkspaceBtn.Size = UDim2.new(1, -20, 0, 24)
SpawnWorkspaceBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
SpawnWorkspaceBtn.Font = Enum.Font.SourceSansBold
SpawnWorkspaceBtn.Text = "FORCE SPAWN IN FRONT (REMOTE)"
SpawnWorkspaceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpawnWorkspaceBtn.TextSize = 12
styleCorner(SpawnWorkspaceBtn, 5)

PreviewClose.MouseButton1Click:Connect(function()
    PreviewFrame.Visible = false
    for _, c in ipairs(PV_World:GetChildren()) do c:Destroy() end
end)

local currentPreviewSlotValue = 0
local currentPreviewSlotName = ""
local currentPreviewTargetPlayer = nil

-- Helper: Try multiple known remotes to force load player build data
-- Only attempts remote if the build folder is completely missing, to reduce side effects on other slots/saves.
local function tryForceLoadPlayerBuild(targetPlayer)
    local blocksRoot = workspace:FindFirstChild("Blocks")
    if blocksRoot and blocksRoot:FindFirstChild(targetPlayer.Name) then
        return false -- Already present, skip remote to avoid overwriting current slot state
    end

    local success = false
    pcall(function()
        local blockReq = workspace:FindFirstChild("BlockRequestsRemote")
        if blockReq and blockReq:IsA("RemoteFunction") then
            blockReq:InvokeServer(targetPlayer.Name)
            task.wait(0.8)
            success = true
        end

        local queueReq = ReplicatedStorage:FindFirstChild("InputLocalScript")
            and ReplicatedStorage.InputLocalScript:FindFirstChild("QueueBlocksRequest")
        if queueReq and queueReq:IsA("RemoteEvent") then
            queueReq:FireServer(targetPlayer.UserId or targetPlayer.Name)
            task.wait(0.7)
            success = true
        end

        local loadBoat = workspace:FindFirstChild("LoadBoatData")
        if loadBoat and loadBoat:IsA("RemoteEvent") then
            loadBoat:FireServer(targetPlayer.Name)
            task.wait(0.5)
        end
    end)
    return success
end

SpawnWorkspaceBtn.MouseButton1Click:Connect(function()
    if not currentPreviewTargetPlayer then return end
    local localChar = Players.LocalPlayer.Character
    if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return end
    local root = localChar.HumanoidRootPart

    -- First try remote force load
    tryForceLoadPlayerBuild(currentPreviewTargetPlayer)
    task.wait(0.8)

    local prev = workspace:FindFirstChild("ForcePreview_" .. currentPreviewTargetPlayer.Name)
    if prev then prev:Destroy() end

    local blocksRoot = workspace:FindFirstChild("Blocks")
    local playerBuild = blocksRoot and blocksRoot:FindFirstChild(currentPreviewTargetPlayer.Name)
    if playerBuild then
        local newModel = Instance.new("Model")
        newModel.Name = "ForcePreview_" .. currentPreviewTargetPlayer.Name
        newModel.Parent = workspace

        for _, child in ipairs(playerBuild:GetChildren()) do
            if child:IsA("Model") then
                local cl = child:Clone()
                cl.Parent = newModel
            end
        end
        local spawnPos = root.Position + root.CFrame.LookVector * 14 + Vector3.new(0, 6, 0)
        newModel:PivotTo(CFrame.new(spawnPos))
    end
end)

-- ==================== MAIN PREVIEW WITH REMOTE FORCE ====================
local function loadPlayerDataDisplay(targetPlayer)
    clearInventoryConnections()
    activeTargetPlayer = targetPlayer
    currentPreviewTargetPlayer = targetPlayer
    DetailFrame.Visible = true
    PreviewFrame.Visible = false
    for _, c in ipairs(PV_World:GetChildren()) do c:Destroy() end

    if currentMode == "Data" then
        UserLabel.Text = targetPlayer.Name .. "'s Data"
        local dataFolder = targetPlayer:WaitForChild("Data", 5)
        if not dataFolder then return end

        local function renderItemRow(item)
            if not item:IsA("ValueBase") or isFiltered(item.Name) then return end

            local Container = Instance.new("Frame")
            Container.Name = item.Name
            Container.Parent = ItemScroll
            Container.Size = UDim2.new(1, 0, 0, 32)
            Container.BackgroundTransparency = 1

            local Row = Instance.new("Frame")
            Row.Name = "RowFrame"
            Row.Parent = Container
            Row.Size = UDim2.new(1, 0, 1, 0)
            Row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            styleCorner(Row, 4)

            local typeIcon, frameIcon = getInventoryTemplateData(item.Name)

            local BtnDecal = Instance.new("ImageLabel")
            BtnDecal.Parent = Row
            BtnDecal.Size = UDim2.new(0, 24, 0, 24)
            BtnDecal.Position = UDim2.new(0, 6, 0, 4)
            BtnDecal.BackgroundTransparency = 1
            BtnDecal.Image = frameIcon ~= "" and frameIcon or "rbxassetid://12328114032"

            local TypeDecal = Instance.new("ImageLabel")
            TypeDecal.Parent = Row
            TypeDecal.Size = UDim2.new(0, 24, 0, 24)
            TypeDecal.Position = UDim2.new(0, 34, 0, 4)
            TypeDecal.BackgroundTransparency = 1
            TypeDecal.Image = typeIcon ~= "" and typeIcon or "rbxassetid://12328114032"

            local NameLbl = Instance.new("TextLabel")
            NameLbl.Name = "ItemNameLabel"
            NameLbl.Parent = Row
            NameLbl.Size = UDim2.new(0.5, -65, 1, 0)
            NameLbl.Position = UDim2.new(0, 65, 0, 0)
            NameLbl.BackgroundTransparency = 1
            NameLbl.Font = Enum.Font.SourceSans
            NameLbl.Text = item.Name
            NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            NameLbl.TextSize = 14
            NameLbl.TextXAlignment = Enum.TextXAlignment.Left

            local ValLbl = Instance.new("TextLabel")
            ValLbl.Parent = Row
            ValLbl.Size = UDim2.new(0.4, -10, 1, 0)
            ValLbl.Position = UDim2.new(0.6, 0, 0, 0)
            ValLbl.BackgroundTransparency = 1
            ValLbl.Font = Enum.Font.SourceSansBold
            ValLbl.Text = tostring(item.Value)
            ValLbl.TextSize = 14
            ValLbl.TextXAlignment = Enum.TextXAlignment.Right

            updateLabelStyle(Row, ValLbl, {BtnDecal, TypeDecal}, item.Value)

            table.insert(liveConnections, item.Changed:Connect(function(newVal)
                ValLbl.Text = tostring(newVal)
                updateLabelStyle(Row, ValLbl, {BtnDecal, TypeDecal}, newVal)
            end))
        end

        for _, it in ipairs(dataFolder:GetChildren()) do renderItemRow(it) end
        table.insert(liveConnections, dataFolder.ChildAdded:Connect(function(newIt) renderItemRow(newIt) end))

    elseif currentMode == "OtherData" then
        UserLabel.Text = targetPlayer.Name .. "'s Slots (REMOTE FORCE LOAD)"
        local otherData = targetPlayer:WaitForChild("OtherData", 5)
        if not otherData then return end

        local function renderSlotRow(item)
            if not string.match(item.Name, "^NameOfSlot%d*$") then return end

            local numStr = string.match(item.Name, "%d+$")
            local slotNum = numStr and tonumber(numStr) or 1
            local displayName = (slotNum > 1) and ("Slot Name " .. slotNum) or "Slot Name"

            local Container = Instance.new("Frame")
            Container.Name = item.Name
            Container.Parent = ItemScroll
            Container.Size = UDim2.new(1, 0, 0, 38)
            Container.BackgroundTransparency = 1
            Container.LayoutOrder = slotNum

            local Row = Instance.new("Frame")
            Row.Name = "RowFrame"
            Row.Parent = Container
            Row.Size = UDim2.new(1, 0, 1, 0)
            Row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            styleCorner(Row, 4)

            local NameLbl = Instance.new("TextLabel")
            NameLbl.Name = "ItemNameLabel"
            NameLbl.Parent = Row
            NameLbl.Size = UDim2.new(0.38, 0, 1, 0)
            NameLbl.Position = UDim2.new(0, 10, 0, 0)
            NameLbl.BackgroundTransparency = 1
            NameLbl.Font = Enum.Font.SourceSansBold
            NameLbl.Text = displayName
            NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            NameLbl.TextSize = 14
            NameLbl.TextXAlignment = Enum.TextXAlignment.Left

            local ValLbl = Instance.new("TextLabel")
            ValLbl.Parent = Row
            ValLbl.Size = UDim2.new(0.25, -10, 1, 0)
            ValLbl.Position = UDim2.new(0.38, 0, 0, 0)
            ValLbl.BackgroundTransparency = 1
            ValLbl.Font = Enum.Font.SourceSansBold
            ValLbl.Text = tostring(item.Value)
            ValLbl.TextSize = 14
            ValLbl.TextXAlignment = Enum.TextXAlignment.Right

            updateLabelStyle(Row, ValLbl, {}, item.Value)

            local PreviewBtn = Instance.new("TextButton")
            PreviewBtn.Parent = Row
            PreviewBtn.Size = UDim2.new(0, 52, 0, 22)
            PreviewBtn.Position = UDim2.new(1, -58, 0.5, -11)
            PreviewBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
            PreviewBtn.Font = Enum.Font.SourceSansBold
            PreviewBtn.Text = "PREVIEW"
            PreviewBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            PreviewBtn.TextSize = 11
            styleCorner(PreviewBtn, 5)

            PreviewBtn.MouseButton1Click:Connect(function()
                currentPreviewSlotValue = tonumber(item.Value) or 0
                currentPreviewSlotName = displayName
                currentPreviewTargetPlayer = targetPlayer

                PreviewTitle.Text = "Remote Force: " .. displayName
                PreviewInfoLabel.Text = "Requesting remote data..."

                -- ========== KEY FIX: Use remote to force load even if not streamed ==========
                local remoteSuccess = tryForceLoadPlayerBuild(targetPlayer)
                if remoteSuccess then
                    PreviewInfoLabel.Text = "Remote request sent. Waiting for replication..."
                    task.wait(1.2)  -- give server time to replicate
                end

                -- Now try to find the build (should be more likely after remote call)
                for _, c in ipairs(PV_World:GetChildren()) do c:Destroy() end

                local localChar = Players.LocalPlayer.Character
                local spawned = false

                if localChar and localChar:FindFirstChild("HumanoidRootPart") then
                    local root = localChar.HumanoidRootPart
                    local prev = workspace:FindFirstChild("ForcePreview_" .. targetPlayer.Name)
                    if prev then prev:Destroy() end

                    local blocksRoot = workspace:FindFirstChild("Blocks")
                    local playerBuild = blocksRoot and blocksRoot:FindFirstChild(targetPlayer.Name)

                    if playerBuild and #playerBuild:GetChildren() > 0 then
                        local newModel = Instance.new("Model")
                        newModel.Name = "ForcePreview_" .. targetPlayer.Name
                        newModel.Parent = workspace

                        local count = 0
                        for _, child in ipairs(playerBuild:GetChildren()) do
                            if child:IsA("Model") then
                                local cl = child:Clone()
                                cl.Parent = newModel
                                count += 1
                                if count >= 300 then break end
                            end
                        end
                        local spawnPos = root.Position + root.CFrame.LookVector * 14 + Vector3.new(0, 7, 0)
                        newModel:PivotTo(CFrame.new(spawnPos))
                        PreviewInfoLabel.Text = "SUCCESS: Real build force-spawned in front of you!"
                        spawned = true
                    end
                end

                if not spawned then
                    -- Fallback synthetic
                    PreviewInfoLabel.Text = "Remote request sent but build not yet visible. Showing value preview."
                    local num = currentPreviewSlotValue
                    local count = math.max(3, math.min(math.floor(num / 1000) + 5, 12))
                    for i = 1, count do
                        local p = Instance.new("Part")
                        p.Size = Vector3.new(2.3, 2.3, 2.3)
                        p.Position = Vector3.new(((i-1)%4)*2.6 - 4, math.floor((i-1)/4)*2.8, 0)
                        p.Anchored = true
                        p.Material = Enum.Material.Neon
                        p.Color = Color3.fromHSV((i * 0.11) % 1, 0.85, 1)
                        p.Parent = PV_World
                    end
                    PV_Cam.CFrame = CFrame.lookAt(Vector3.new(0, 5, 14), Vector3.new(0, 2, 0))
                end

                PreviewFrame.Visible = true
            end)

            table.insert(liveConnections, item.Changed:Connect(function(newVal)
                ValLbl.Text = tostring(newVal)
                updateLabelStyle(Row, ValLbl, {}, newVal)
            end))
        end

        for _, it in ipairs(otherData:GetChildren()) do renderSlotRow(it) end
        table.insert(liveConnections, otherData.ChildAdded:Connect(function(newIt) renderSlotRow(newIt) end))
    end
end

SwitchBtn.MouseButton1Click:Connect(function()
    currentMode = (currentMode == "Data") and "OtherData" or "Data"
    if activeTargetPlayer then loadPlayerDataDisplay(activeTargetPlayer) end
end)

CloseBtn.MouseButton1Click:Connect(function()
    DetailFrame.Visible = false
    PreviewFrame.Visible = false
    for _, c in ipairs(PV_World:GetChildren()) do c:Destroy() end
    clearInventoryConnections()
    activeTargetPlayer = nil
    currentPreviewTargetPlayer = nil
    SearchBar.Text = ""
end)

-- ==================== PLAYER LIST WITH AVATAR ====================
local function addPlayerButton(player)
    if PlayerScroll:FindFirstChild(player.Name) then return end
    local Container = Instance.new("Frame")
    Container.Name = player.Name
    Container.Parent = PlayerScroll
    Container.Size = UDim2.new(1, 0, 0, 56)
    Container.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    styleCorner(Container, 4)

    local Avatar = Instance.new("ImageLabel")
    Avatar.Name = "Avatar"
    Avatar.Parent = Container
    Avatar.Size = UDim2.new(0, 42, 0, 42)
    Avatar.Position = UDim2.new(0, 6, 0.5, -21)
    Avatar.BackgroundTransparency = 1
    Avatar.Image = "rbxassetid://0"
    Avatar.ScaleType = Enum.ScaleType.Crop
    styleCorner(Avatar, 6)

    task.spawn(function()
        local success, thumbUrl = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
        if success and Avatar and Avatar.Parent then
            Avatar.Image = thumbUrl
        end
    end)

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 1, 0)
    Btn.BackgroundTransparency = 1
    Btn.Text = ""
    Btn.Parent = Container

    local CountLbl = Instance.new("TextLabel")
    CountLbl.Parent = Container
    CountLbl.Size = UDim2.new(1, -60, 0, 14)
    CountLbl.Position = UDim2.new(0, 54, 0, 4)
    CountLbl.BackgroundTransparency = 1
    CountLbl.Font = Enum.Font.SourceSansBold
    CountLbl.Text = "[Items: Calculating...]"
    CountLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    CountLbl.TextSize = 11

    local NameLbl = Instance.new("TextLabel")
    NameLbl.Parent = Container
    NameLbl.Size = UDim2.new(1, -60, 0, 16)
    NameLbl.Position = UDim2.new(0, 54, 0, 18)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Font = Enum.Font.SourceSansBold
    NameLbl.Text = player.Name
    NameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameLbl.TextSize = 13

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Name = "RankTitle"
    TitleLbl.Parent = Container
    TitleLbl.Size = UDim2.new(1, -60, 0, 14)
    TitleLbl.Position = UDim2.new(0, 54, 0, 35)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Font = Enum.Font.SourceSansBold
    TitleLbl.Text = "Calculating..."
    TitleLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    TitleLbl.TextSize = 12

    Btn.MouseButton1Click:Connect(function() loadPlayerDataDisplay(player) end)
    setupRankTracking(player, TitleLbl, CountLbl)
end

local function removePlayerButton(player)
    local f = PlayerScroll:FindFirstChild(player.Name)
    if f then f:Destroy() end
    if playerTitleConnections[player.Name] then
        for _, c in ipairs(playerTitleConnections[player.Name]) do c:Disconnect() end
        playerTitleConnections[player.Name] = nil
    end
    if activeTargetPlayer == player then
        DetailFrame.Visible = false
        PreviewFrame.Visible = false
        for _, c in ipairs(PV_World:GetChildren()) do c:Destroy() end
        clearInventoryConnections()
        activeTargetPlayer = nil
        currentPreviewTargetPlayer = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do addPlayerButton(p) end
Players.PlayerAdded:Connect(addPlayerButton)
Players.PlayerRemoving:Connect(removePlayerButton)

print("[REMOTE FORCE VERSION] Now attempts remote calls to load builds even when player is not streamed in.")
