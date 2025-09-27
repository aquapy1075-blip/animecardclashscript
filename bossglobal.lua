-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Teleport tới tọa độ mong muốn khi execute
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
hrp.CFrame = CFrame.new(1019, 9, -245)
task.wait(2)

-- Events
local fightBoss = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("fightGlobalBoss")
local setParty = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("setPartySlot")
local fightFarm = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("fightInfinite")
local forfeitBattle = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("forfeitBattle")
local claimInfinite = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("claimInfinite")

-- Args
local bossArgs = {450}

-- Danh sách map farm
local farmModes = {
    titans_city = "Titans City",
    dimensional_fortress = "Dimensional Fortress",
    candy_island = "Candy Island",
    base = "Infinite",
    nightmare = "Hard Core"
}

-- Map mặc định
local farmArgs = {"Dimensional Fortress"}

-- State
local auto = true
local currentTeam = "slot_1"
local spammingBoss = false
local farmMode = false
local farmSpamming = false
local currentHP, maxHP = nil, nil

-- UI gốc
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoStatusGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -12, 0, 32)
statusLabel.BackgroundTransparency = 0.1
statusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
statusLabel.TextScaled = true
statusLabel.Font = Font.SourceSans
statusLabel.Text = "LOADING..."

local mapButton = Instance.new("TextButton")
mapButton.Size = UDim2.new(1, -12, 0, 28)
mapButton.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
mapButton.TextColor3 = Color3.fromRGB(255, 255, 255)
mapButton.TextScaled = true
mapButton.Font = Font.SourceSansBold
mapButton.Text = "Chọn Map"

local mapFrame = Instance.new("Frame")
mapFrame.Size = UDim2.new(1, -12, 0, 120)
mapFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
mapFrame.Visible = false

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -12, 0, 28)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 130, 70)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextScaled = true
toggleButton.Font = Font.SourceSansBold
toggleButton.Text = "AUTO: ON"

----------------------------------------------------------------
-- Panel UI bên phải
----------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 160, 0, 220)
panel.Position = UDim2.new(1, -170, 0.5, -110)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Parent = panel
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top

local function addCorner(ui, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = ui
end

statusLabel.Parent = panel
addCorner(statusLabel)

toggleButton.Parent = panel
addCorner(toggleButton)

mapButton.Parent = panel
addCorner(mapButton)

mapFrame.Parent = panel
addCorner(mapFrame)

local uiPadding = Instance.new("UIPadding", mapFrame)
uiPadding.PaddingTop = UDim.new(0, 8)
uiPadding.PaddingLeft = UDim.new(0, 8)
uiPadding.PaddingRight = UDim.new(0, 8)
uiPadding.PaddingBottom = UDim.new(0, 8)

local uiList = Instance.new("UIListLayout", mapFrame)
uiList.FillDirection = Enum.FillDirection.Vertical
uiList.Padding = UDim.new(0, 6)

for key, displayName in pairs(farmModes) do
    local btn = Instance.new("TextButton")
   btn.Size = UDim2.new(1, 0, 0, 24)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.Text = displayName
    btn.Parent = mapFrame
    addCorner(btn)

    btn.MouseButton1Click:Connect(function()
        farmArgs = {key}
        print("Đã chọn map:", displayName, "("..key..")")
        mapFrame.Visible = false
        updateStatusUI()
    end)
end

mapButton.MouseButton1Click:Connect(function()
    mapFrame.Visible = not mapFrame.Visible
end)

toggleButton.MouseButton1Click:Connect(function()
    auto = not auto
    if auto then
        toggleButton.Text = "AUTO: ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
        print("Auto bật ✅")
    else
        toggleButton.Text = "AUTO: OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        -- Tắt auto → dừng tất cả
        stopFarmMode()
        spammingBoss = false
        farmSpamming = false
        currentHP, maxHP = nil, nil
        print("Auto tắt ❌")
    end
    updateStatusUI()
end)
----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function updateStatusUI()
    local hpText = (currentHP and maxHP) and string.format("%s/%s", currentHP, maxHP) or "N/A"
    local farmName = farmModes[farmArgs[1]] or farmArgs[1]
    local farmText = farmMode and ("ON (" .. farmName .. ")") or "OFF"
    statusLabel.Text = string.format("AUTO: %s | HP: %s | Team: %s | FARM: %s",
        auto and "ON" or "OFF", hpText, currentTeam, farmText)
end

local function switchTeamSafe(slotName)
    if currentTeam ~= slotName then
        setParty:FireServer(slotName)
        currentTeam = slotName
        updateStatusUI()
    end
end

local function inCombat()
    for _, v in ipairs(playerGui:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextButton") then
            local txt = v.Text:lower()
            if txt:find("show battle") or txt:find("hide battle") then
                return false
            end
        end
    end
    return true
end

local function getBossHP()
    for _, v in ipairs(playerGui:GetDescendants()) do
        if v:IsA("TextLabel") then
            local txt = v.Text:gsub(",", ""):gsub("%s+", "")
            local cur, max = txt:match("(%d+%.?%d*)/(%d+)")
            if cur and max then
                cur = math.floor(tonumber(cur))
                max = tonumber(max)
                if max and max >= 1000000 then
                    return cur, max
                end
            end
        end
    end
    return nil, nil
end

----------------------------------------------------------------
-- Spam functions
----------------------------------------------------------------

local function spamBoss()
    if spammingBoss then return end
    spammingBoss = true
    task.spawn(function()
        while auto and currentHP and currentHP > 0 and inCombat() do
            fightBoss:FireServer(unpack(bossArgs))
            task.wait(0.5)
        end
        spammingBoss = false
    end)
end

local function spamFarm()
    if farmSpamming then return end
    farmSpamming = true
    task.spawn(function()
        while farmMode and auto do
            if inCombat() then
                fightFarm:FireServer(unpack(farmArgs))
            end
            task.wait(3)
        end
        farmSpamming = false
    end)
end

local function startFarmMode()
    if farmMode then return end
    farmMode = true
    switchTeamSafe("slot_4")
    spamFarm()
    print("Bắt đầu farm mode:", farmModes[farmArgs[1]])
    updateStatusUI()
end

local function stopFarmMode()
    if not farmMode then return end
    farmMode = false
    print("Dừng farm mode")
    updateStatusUI()
end

----------------------------------------------------------------
-- Main loop
----------------------------------------------------------------
task.spawn(function()
    while true do
        currentHP, maxHP = getBossHP()

        if auto then
            if currentHP and currentHP > 0 then
                -- Boss spawn → dừng farm, forfeit + claim trước
                if farmMode then
                    stopFarmMode()
                    forfeitBattle:FireServer()
                    task.wait(2)
                    claimInfinite:FireServer(unpack(farmArgs))
                    print("Đã forfeit + claim reward, chuẩn bị spam boss")
                end

                -- Chọn team và spam boss
                if currentHP >= 75000000 then
                    switchTeamSafe("slot_2")
                else
                    switchTeamSafe("slot_1")
                end
                spamBoss()
            else
                -- Boss chưa spawn → farm
                startFarmMode()
            end
        end

        updateStatusUI()
        task.wait(0.2)
    end
end)
