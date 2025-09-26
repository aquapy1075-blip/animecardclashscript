-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Teleport tới tọa độ mong muốn
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
local farmArgs = {"titans_city"}

-- State
local auto = true
local currentTeam = "slot_1"
local spammingBoss = false
local farmMode = false
local farmSpamming = false
local currentHP, maxHP = nil, nil

-- UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoStatusGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 500, 0, 60)
statusLabel.Position = UDim2.new(0, 10, 0, 10)
statusLabel.BackgroundTransparency = 0.3
statusLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.Text = "LOADING..."
statusLabel.Parent = screenGui

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function updateStatusUI()
    local hpText = currentHP and maxHP and string.format("%s/%s", currentHP, maxHP) or "N/A"
    local farmText = farmMode and "ON" or "OFF"
    statusLabel.Text = string.format("AUTO: %s | HP: %s | Team: %s | FARM: %s",
        auto and "ON" or "OFF", hpText, currentTeam, farmText)
end

local function switchTeamSafe(slotName)
    if currentTeam ~= slotName then
        setParty:FireServer(slotName)
        currentTeam = slotName
        updateStatusUI()
        print("Đã chuyển sang", slotName)
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
        while farmMode do
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
    print("Bắt đầu farm mode")
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
        updateStatusUI()
        task.wait(0.2)
    end
end)
