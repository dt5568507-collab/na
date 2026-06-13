-- Sypher Hub | Natural Disaster Survival (撞击版)
-- 方块被吸向玩家，触碰到玩家后弹飞，猛烈撞击其他玩家
-- 本地玩家不会被自己的方块撞到，但其他玩家会被撞飞

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ========== 参数配置 ==========
local enabled = false
local pullStrength = 120      -- 拉力灵敏度 (越高吸得越快)
local ejectForce = 80         -- 弹飞力度 (影响撞击效果)
local radius = 12             -- 弹飞半径 (超过此距离不会弹飞)
local spinTorque = 1e6        -- 自旋扭矩

local rootPart = nil
local playerCharacter = nil
local activeBlocks = {}       -- 记录被操控的方块，方便清理

-- ========== 碰撞组设置 (让自己免疫方块撞击) ==========
local function setupCollisionGroups()
    -- 创建碰撞组 (如果不存在)
    local success, err = pcall(function()
        PhysicsService:CreateCollisionGroup("LocalPlayer")
    end)
    success, err = pcall(function()
        PhysicsService:CreateCollisionGroup("BlackholeBlocks")
    end)
    -- 设置两组之间不碰撞
    PhysicsService:CollisionGroupSetCollidable("LocalPlayer", "BlackholeBlocks", false)
end

-- 将方块加入黑洞组，自身角色加入本地组
local function setCollisionGroup(part, isBlock)
    if isBlock then
        if part:IsA("BasePart") then
            pcall(function()
                PhysicsService:SetPartCollisionGroup(part, "BlackholeBlocks")
            end)
        end
    else
        if part:IsA("BasePart") then
            pcall(function()
                PhysicsService:SetPartCollisionGroup(part, "LocalPlayer")
            end)
        end
    end
end

-- ========== 辅助函数 ==========
local function isPartSelf(part)
    if not part then return true end
    if playerCharacter and part:IsDescendantOf(playerCharacter) then
        return true
    end
    local parent = part.Parent
    if parent and (parent:FindFirstChild("Humanoid") or parent:FindFirstChild("Head")) then
        return true
    end
    if part.Name == "Handle" then
        return true
    end
    return false
end

-- 清除零件上的旧约束
local function clearConstraints(part)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("BodyAngularVelocity") or child:IsA("BodyForce") or child:IsA("BodyGyro") or
           child:IsA("BodyPosition") or child:IsA("BodyThrust") or child:IsA("BodyVelocity") or
           child:IsA("RocketPropulsion") or child:IsA("Torque") or child:IsA("AlignPosition") then
            child:Destroy()
        end
    end
end

-- 为零件添加吸附和自旋
local function processPart(part)
    if not part:IsA("BasePart") then return end
    if part.Anchored then return end
    if isPartSelf(part) then return end
    
    clearConstraints(part)
    
    -- 添加自旋扭矩
    local att = part:FindFirstChild("Attachment")
    if not att then
        att = Instance.new("Attachment", part)
    end
    local torque = part:FindFirstChild("Torque")
    if not torque then
        torque = Instance.new("Torque", part)
        torque.Torque = Vector3.new(spinTorque, spinTorque, spinTorque)
        torque.Attachment0 = att
    end
    
    -- 添加吸附 (目标: 玩家根部)
    local align = part:FindFirstChild("AlignPosition")
    if not align then
        align = Instance.new("AlignPosition", part)
        align.MaxForce = math.huge
        align.MaxVelocity = math.huge
        align.Responsiveness = pullStrength
        align.Attachment0 = att
    end
    -- 动态更新目标附件 (玩家根部的附件)
    local targetAtt = rootPart:FindFirstChild("BlackholeTarget")
    if not targetAtt then
        targetAtt = Instance.new("Attachment", rootPart)
        targetAtt.Name = "BlackholeTarget"
    end
    align.Attachment1 = targetAtt
    
    -- 确保有碰撞且属于黑洞组
    part.CanCollide = true
    setCollisionGroup(part, true)
    
    -- 记录活跃方块
    if not activeBlocks[part] then
        activeBlocks[part] = true
    end
end

-- 弹飞逻辑：当方块距离玩家中心过近时，给它一个向外的高速
local function checkAndEject()
    if not rootPart then return end
    local center = rootPart.Position
    for part, _ in pairs(activeBlocks) do
        if part and part.Parent and part:IsDescendantOf(Workspace) and part:IsA("BasePart") then
            local dist = (part.Position - center).Magnitude
            if dist < radius then
                -- 计算径向方向 (从玩家指向方块)
                local dir = (part.Position - center).Unit
                -- 随机偏转，使飞散方向多样化
                local randomAngle = math.rad(math.random(0, 360))
                local right = Vector3.new(dir.Z, 0, -dir.X).Unit
                local up = Vector3.new(0, 1, 0)
                local finalDir = (dir + right * math.sin(randomAngle) + up * math.cos(randomAngle)).Unit
                -- 施加冲量
                local velocity = finalDir * ejectForce
                -- 保留原有Y轴速度，避免直接飞天
                velocity = Vector3.new(velocity.X, part.Velocity.Y * 0.5 + 5, velocity.Z)
                part.Velocity = velocity
                -- 可选：同时增加角速度使碰撞更有力
                part.RotVelocity = Vector3.new(math.random(-50,50), math.random(-50,50), math.random(-50,50))
            end
        else
            -- 移除无效方块
            activeBlocks[part] = nil
        end
    end
end

-- 扫描整个场景并处理所有零件
local function scanAndProcess()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        processPart(obj)
    end
end

-- 开启/关闭黑洞
local function toggleBlackhole()
    enabled = not enabled
    if enabled then
        scanAndProcess()
        -- 监听新零件
        local conn
        conn = Workspace.DescendantAdded:Connect(function(obj)
            if enabled then
                processPart(obj)
            end
        end)
        -- 定期弹飞检查
        local ejectConn
        ejectConn = RunService.Heartbeat:Connect(function()
            if enabled then
                checkAndEject()
            end
        end)
        -- 清理连接
        task.spawn(function()
            while enabled do
                RunService.RenderStepped:Wait()
            end
            conn:Disconnect()
            ejectConn:Disconnect()
        end)
    else
        -- 关闭时清除所有效果，恢复零件原有属性
        for part, _ in pairs(activeBlocks) do
            if part and part.Parent then
                clearConstraints(part)
                pcall(function()
                    PhysicsService:SetPartCollisionGroup(part, "Default")
                end)
            end
        end
        activeBlocks = {}
        if rootPart then
            local targetAtt = rootPart:FindFirstChild("BlackholeTarget")
            if targetAtt then targetAtt:Destroy() end
        end
    end
end

-- 角色重生时重建附件和碰撞组
local function onCharacterAdded(char)
    playerCharacter = char
    rootPart = char:WaitForChild("HumanoidRootPart")
    -- 将自身角色所有部件设为 LocalPlayer 碰撞组
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            setCollisionGroup(part, false)
        end
    end
    -- 如果黑洞开启，需要重新激活
    if enabled then
        enabled = false
        toggleBlackhole()
    end
end

-- ========== UI ==========
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SypherHub_NDS"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 210)
    mainFrame.Position = UDim2.new(0.5, -140, 0.5, -105)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = "Sypher Hub | 黑洞撞击版"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = mainFrame
    
    -- 拉力灵敏度
    local pullLabel = Instance.new("TextLabel")
    pullLabel.Size = UDim2.new(1, 0, 0, 20)
    pullLabel.Position = UDim2.new(0, 0, 0, 30)
    pullLabel.BackgroundTransparency = 1
    pullLabel.Text = "吸力强度: " .. pullStrength
    pullLabel.TextColor3 = Color3.fromRGB(220,220,220)
    pullLabel.Font = Enum.Font.Gotham
    pullLabel.TextSize = 12
    pullLabel.Parent = mainFrame
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(0.8, 0, 0, 4)
    sliderBg.Position = UDim2.new(0.1, 0, 0, 52)
    sliderBg.BackgroundColor3 = Color3.fromRGB(80,80,90)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = mainFrame
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1,0)
    bgCorner.Parent = sliderBg
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((pullStrength-20)/180, 0, 1, 0) -- 20~200
    fill.BackgroundColor3 = Color3.fromRGB(0,150,255)
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1,0)
    fillCorner.Parent = fill
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Position = UDim2.new((pullStrength-20)/180, -5, 0.5, -5)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.Parent = sliderBg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1,0)
    knobCorner.Parent = knob
    
    local function updatePull(val)
        pullStrength = math.floor(val)
        pullLabel.Text = "吸力强度: " .. pullStrength
        local pos = (pullStrength-20)/180
        fill.Size = UDim2.new(pos, 0, 1, 0)
        knob.Position = UDim2.new(pos, -5, 0.5, -5)
        -- 更新已有 AlignPosition
        for part, _ in pairs(activeBlocks) do
            local align = part:FindFirstChild("AlignPosition")
            if align then align.Responsiveness = pullStrength end
        end
    end
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local function move(input2)
                if input2.UserInputType == Enum.UserInputType.MouseMovement then
                    local pos = math.clamp((input2.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
                    local val = 20 + pos * 180
                    updatePull(val)
                end
            end
            move(input)
            local connection
            connection = UserInputService.InputChanged:Connect(move)
            UserInputService.InputEnded:Connect(function(input2)
                if input2.UserInputType == Enum.UserInputType.MouseButton1 then
                    connection:Disconnect()
                end
            end)
        end
    end)
    
    -- 弹飞力度
    local ejectLabel = Instance.new("TextLabel")
    ejectLabel.Size = UDim2.new(1, 0, 0, 20)
    ejectLabel.Position = UDim2.new(0, 0, 0, 70)
    ejectLabel.BackgroundTransparency = 1
    ejectLabel.Text = "撞击力度: " .. ejectForce
    ejectLabel.TextColor3 = Color3.fromRGB(220,220,220)
    ejectLabel.Font = Enum.Font.Gotham
    ejectLabel.TextSize = 12
    ejectLabel.Parent = mainFrame
    
    local sliderBg2 = Instance.new("Frame")
    sliderBg2.Size = UDim2.new(0.8, 0, 0, 4)
    sliderBg2.Position = UDim2.new(0.1, 0, 0, 92)
    sliderBg2.BackgroundColor3 = Color3.fromRGB(80,80,90)
    sliderBg2.BorderSizePixel = 0
    sliderBg2.Parent = mainFrame
    local bgCorner2 = Instance.new("UICorner")
    bgCorner2.CornerRadius = UDim.new(1,0)
    bgCorner2.Parent = sliderBg2
    
    local fill2 = Instance.new("Frame")
    fill2.Size = UDim2.new((ejectForce-20)/180, 0, 1, 0) -- 20~200
    fill2.BackgroundColor3 = Color3.fromRGB(0,150,255)
    fill2.BorderSizePixel = 0
    fill2.Parent = sliderBg2
    local fillCorner2 = Instance.new("UICorner")
    fillCorner2.CornerRadius = UDim.new(1,0)
    fillCorner2.Parent = fill2
    
    local knob2 = Instance.new("Frame")
    knob2.Size = UDim2.new(0, 10, 0, 10)
    knob2.Position = UDim2.new((ejectForce-20)/180, -5, 0.5, -5)
    knob2.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob2.BorderSizePixel = 0
    knob2.Parent = sliderBg2
    local knobCorner2 = Instance.new("UICorner")
    knobCorner2.CornerRadius = UDim.new(1,0)
    knobCorner2.Parent = knob2
    
    local function updateEject(val)
        ejectForce = math.floor(val)
        ejectLabel.Text = "撞击力度: " .. ejectForce
        local pos = (ejectForce-20)/180
        fill2.Size = UDim2.new(pos, 0, 1, 0)
        knob2.Position = UDim2.new(pos, -5, 0.5, -5)
    end
    
    sliderBg2.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local function move(input2)
                if input2.UserInputType == Enum.UserInputType.MouseMovement then
                    local pos = math.clamp((input2.Position.X - sliderBg2.AbsolutePosition.X) / sliderBg2.AbsoluteSize.X, 0, 1)
                    local val = 20 + pos * 180
                    updateEject(val)
                end
            end
            move(input)
            local connection
            connection = UserInputService.InputChanged:Connect(move)
            UserInputService.InputEnded:Connect(function(input2)
                if input2.UserInputType == Enum.UserInputType.MouseButton1 then
                    connection:Disconnect()
                end
            end)
        end
    end)
    
    -- 弹飞半径
    local radiusLabel = Instance.new("TextLabel")
    radiusLabel.Size = UDim2.new(1, 0, 0, 20)
    radiusLabel.Position = UDim2.new(0, 0, 0, 110)
    radiusLabel.BackgroundTransparency = 1
    radiusLabel.Text = "弹飞半径: " .. radius
    radiusLabel.TextColor3 = Color3.fromRGB(220,220,220)
    radiusLabel.Font = Enum.Font.Gotham
    radiusLabel.TextSize = 12
    radiusLabel.Parent = mainFrame
    
    local sliderBg3 = Instance.new("Frame")
    sliderBg3.Size = UDim2.new(0.8, 0, 0, 4)
    sliderBg3.Position = UDim2.new(0.1, 0, 0, 132)
    sliderBg3.BackgroundColor3 = Color3.fromRGB(80,80,90)
    sliderBg3.BorderSizePixel = 0
    sliderBg3.Parent = mainFrame
    local bgCorner3 = Instance.new("UICorner")
    bgCorner3.CornerRadius = UDim.new(1,0)
    bgCorner3.Parent = sliderBg3
    
    local fill3 = Instance.new("Frame")
    fill3.Size = UDim2.new((radius-2)/18, 0, 1, 0) -- 2~20
    fill3.BackgroundColor3 = Color3.fromRGB(0,150,255)
    fill3.BorderSizePixel = 0
    fill3.Parent = sliderBg3
    local fillCorner3 = Instance.new("UICorner")
    fillCorner3.CornerRadius = UDim.new(1,0)
    fillCorner3.Parent = fill3
    
    local knob3 = Instance.new("Frame")
    knob3.Size = UDim2.new(0, 10, 0, 10)
    knob3.Position = UDim2.new((radius-2)/18, -5, 0.5, -5)
    knob3.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob3.BorderSizePixel = 0
    knob3.Parent = sliderBg3
    local knobCorner3 = Instance.new("UICorner")
    knobCorner3.CornerRadius = UDim.new(1,0)
    knobCorner3.Parent = knob3
    
    local function updateRadius(val)
        radius = math.floor(val)
        radiusLabel.Text = "弹飞半径: " .. radius
        local pos = (radius-2)/18
        fill3.Size = UDim2.new(pos, 0, 1, 0)
        knob3.Position = UDim2.new(pos, -5, 0.5, -5)
    end
    
    sliderBg3.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local function move(input2)
                if input2.UserInputType == Enum.UserInputType.MouseMovement then
                    local pos = math.clamp((input2.Position.X - sliderBg3.AbsolutePosition.X) / sliderBg3.AbsoluteSize.X, 0, 1)
                    local val = 2 + pos * 18
                    updateRadius(val)
                end
            end
            move(input)
            local connection
            connection = UserInputService.InputChanged:Connect(move)
            UserInputService.InputEnded:Connect(function(input2)
                if input2.UserInputType == Enum.UserInputType.MouseButton1 then
                    connection:Disconnect()
                end
            end)
        end
    end)
    
    -- 开关按钮
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 80, 0, 28)
    toggleBtn.Position = UDim2.new(0.5, -40, 1, -38)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0,150,0)
    toggleBtn.Text = "开启黑洞"
    toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.Parent = mainFrame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0,4)
    btnCorner.Parent = toggleBtn
    
    local function setToggle(state)
        if state == enabled then return end
        toggleBlackhole()
        if enabled then
            toggleBtn.BackgroundColor3 = Color3.fromRGB(200,0,0)
            toggleBtn.Text = "关闭黑洞"
        else
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0,150,0)
            toggleBtn.Text = "开启黑洞"
        end
    end
    
    toggleBtn.MouseButton1Click:Connect(function()
        setToggle(not enabled)
    end)
    
    setToggle(true)
end

-- ========== 初始化 ==========
setupCollisionGroups()
-- 等待角色出现
if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
else
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
end
-- 角色重连时重新应用碰撞组
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

createUI()