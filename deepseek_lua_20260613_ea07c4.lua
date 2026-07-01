-- 自动购买所有绝版活动商品（Delta 脚本）
-- 只针对已下架的活动物品，普通商品不会被购买

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ShopGui = PlayerGui:WaitForChild("ShopGui", 10)
if not ShopGui then
    warn("找不到 ShopGui，请确保你在游戏中")
    return
end

local MainFrame = ShopGui:WaitForChild("MainFrame")
local TabFrame = MainFrame:WaitForChild("TabFrame")
local ShopFrame = TabFrame:WaitForChild("ShopFrame")
local ScrollingFrame = ShopFrame:WaitForChild("ScrollingFrameChests")

-- 判断是否为活动物品（绝版）
local function IsEventItem(frame)
    -- 1. 如果 Frame 名称包含 "Event"（如 FrameEvent）
    if frame.Name:find("Event") then
        return true
    end
    
    -- 2. 检查子对象中的描述文本是否包含 "Goes off sale" 或 "Event"
    for _, child in ipairs(frame:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            local text = child.Text or ""
            if text:find("Goes off sale") or text:find("Event") or text:find("Sale") then
                return true
            end
        end
    end
    return false
end

-- 获取所有 Frame
local allFrames = {}
for _, child in ipairs(ScrollingFrame:GetChildren()) do
    if child:IsA("Frame") then
        table.insert(allFrames, child)
    end
end

-- 购买函数：点击购买按钮
local function BuyItem(frame)
    local buyButton = frame:FindFirstChildWhichIsA("ImageButton") or frame:FindFirstChildWhichIsA("TextButton")
    if not buyButton then
        for _, obj in ipairs(frame:GetDescendants()) do
            if obj:IsA("ImageButton") or obj:IsA("TextButton") then
                buyButton = obj
                break
            end
        end
    end
    if buyButton and buyButton.Visible then
        buyButton:FireClick()
        return true
    end
    return false
end

local purchasedCount = 0
for _, frame in ipairs(allFrames) do
    -- 检查是否已拥有（Owns 为 true 则跳过）
    local owns = frame:FindFirstChild("Owns")
    if owns and owns.Value == true then
        continue
    end
    
    -- 只处理活动物品
    if IsEventItem(frame) then
        local success = BuyItem(frame)
        if success then
            purchasedCount = purchasedCount + 1
            print("成功购买活动物品: " .. frame.Name)
            wait(0.5)  -- 防止点击过快
        else
            print("无法购买活动物品: " .. frame.Name .. "（可能已售罄或无购买按钮）")
        end
    end
end

print("共成功购买 " .. tostring(purchasedCount) .. " 件绝版活动商品。")
