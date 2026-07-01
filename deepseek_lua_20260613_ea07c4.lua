if not isfolder("ShipTreasureData") then
    makefolder("ShipTreasureData")
end

local function Save(name, text)
    pcall(function()
        writefile("ShipTreasureData/" .. name, text)
    end)
end

local function Tree(root)
    local t = {}
    local function Scan(obj, d)
        table.insert(t, string.rep(" ", d) .. obj.ClassName .. " | " .. obj:GetFullName())
        for _, v in ipairs(obj:GetChildren()) do
            Scan(v, d + 1)
        end
    end
    Scan(root, 0)
    return table.concat(t, "\n")
end

local function Values()
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("StringValue") or v:IsA("BoolValue") or v:IsA("IntValue") or v:IsA("NumberValue") then
            local ok, val = pcall(function() return tostring(v.Value) end)
            if ok then
                table.insert(t, v:GetFullName() .. " = " .. val)
            end
        end
    end
    return table.concat(t, "\n")
end

local function Remotes()
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            table.insert(t, v.ClassName .. " | " .. v:GetFullName())
        end
    end
    return table.concat(t, "\n")
end

local function Modules()
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("ModuleScript") then
            table.insert(t, v:GetFullName())
        end
    end
    return table.concat(t, "\n")
end

local function Scripts()
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript") then
            table.insert(t, v.ClassName .. " | " .. v:GetFullName())
        end
    end
    return table.concat(t, "\n")
end

local function Models()
    local t = {}
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") then
            local c = 0
            for _, x in ipairs(m:GetDescendants()) do
                if x:IsA("BasePart") then
                    c = c + 1
                end
            end
            if c > 0 then
                table.insert(t, m:GetFullName() .. " | Parts=" .. c)
            end
        end
    end
    return table.concat(t, "\n")
end

local function Candidates()
    local keys = {
        "save", "load", "build", "boat", "ship", "preview",
        "encode", "decode", "json", "slot", "block", "serializer",
        "inventory", "plot", "team", "remote", "data"
    }
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        local n = v.Name:lower()
        for _, k in ipairs(keys) do
            if n:find(k, 1, true) then
                table.insert(t, v.ClassName .. " | " .. v:GetFullName())
                break
            end
        end
    end
    return table.concat(t, "\n")
end

local function Blocks()
    local t = {}
    local b = workspace:FindFirstChild("Blocks")
    if b then
        for _, v in ipairs(b:GetDescendants()) do
            table.insert(t, v.ClassName .. " | " .. v:GetFullName())
        end
    end
    return table.concat(t, "\n")
end

-- 新增：掃描所有金幣（支援常見命名與數值物件）
local function GoldCoins()
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        local n = v.Name:lower()
        if n:find("coin") or n:find("gold") or n:find("金") or n:find("寶") or n:find("treasure") then
            local valInfo = ""
            if v:IsA("IntValue") or v:IsA("NumberValue") or v:IsA("StringValue") or v:IsA("BoolValue") then
                local ok, val = pcall(function() return tostring(v.Value) end)
                if ok then
                    valInfo = " | Value=" .. val
                end
            end
            table.insert(t, v.ClassName .. " | " .. v:GetFullName() .. valInfo)
        end
    end
    return table.concat(t, "\n")
end

-- 新增：掃描保存方塊相關資料（資料夾、模型、設定與數值物件）
local function SavedBlocks()
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        local n = v.Name:lower()
        if (n:find("save") or n:find("block") or n:find("ship") or n:find("boat") or n:find("build") or n:find("data"))
           and (v:IsA("Folder") or v:IsA("Model") or v:IsA("Configuration") or v:IsA("ValueBase")) then
            table.insert(t, v.ClassName .. " | " .. v:GetFullName())
        end
    end
    return table.concat(t, "\n")
end

-- 新增：掃描活動道具與事件相關物件
local function EventProps()
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        local n = v.Name:lower()
        if n:find("event") or n:find("prop") or n:find("item") or n:find("道具") or n:find("活動") or n:find("quest") or n:find("reward") then
            table.insert(t, v.ClassName .. " | " .. v:GetFullName())
        end
    end
    return table.concat(t, "\n")
end

-- 執行所有儲存動作
Save("01_GameTree.txt", Tree(game))
Save("02_Workspace.txt", Tree(workspace))
Save("03_Player.txt", Tree(game.Players.LocalPlayer))
Save("04_ReplicatedStorage.txt", Tree(game.ReplicatedStorage))
Save("05_Values.txt", Values())
Save("06_Remotes.txt", Remotes())
Save("07_Modules.txt", Modules())
Save("08_Scripts.txt", Scripts())
Save("09_Blocks.txt", Blocks())
Save("10_Models.txt", Models())
Save("11_Candidates.txt", Candidates())
Save("12_GoldCoins.txt", GoldCoins())
Save("13_SavedBlocks.txt", SavedBlocks())
Save("14_EventProps.txt", EventProps())

print("掃描完成！資料已儲存至 ShipTreasureData 資料夾。")
print("請開啟 ShipTreasureData 資料夾以查看輸出檔案。")
