-- 📌 Auto Boss GUI – Mobile Friendly + Hide Status after Finished
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local networkEvent = game:GetService("ReplicatedStorage")
    :WaitForChild("shared/network@eventDefinitions")
    :WaitForChild("fightStoryBoss")

-- 🌟 Boss ID -> Name
local bossNames = {
    [308] = "Naruto",
    [381] = "Frieza",
    [330] = "Sukuna",
    [355] = "Titan",
    [458] = "Muzan",
    [348] = "Big Mom",
    [322] = "Sungjinwoo",
    [300] = "Cid",
    [366] = "Celestial Sovereign",
    [343] = "Dead King",
}

-- 🎨 GUI chính
local autoGui = Instance.new("ScreenGui")
autoGui.Name = "AutoBossUI"
autoGui.ResetOnSpawn = false
autoGui.IgnoreGuiInset = true
autoGui.Parent = playerGui

-- 🔘 Nút AUTO FIGHT BOSS (nhỏ hơn)
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(0, 120, 0, 40)
autoBtn.Position = UDim2.new(0.5, -60, 0.8, 0)
autoBtn.AnchorPoint = Vector2.new(0.5,0)
autoBtn.Text = "⚔️ AUTO"
autoBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
autoBtn.TextScaled = true
autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoBtn.Parent = autoGui

-- 🏷️ Status label (khung vàng)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 400, 0, 60)
statusLabel.Position = UDim2.new(0, 20, 0, 20)
statusLabel.BackgroundTransparency = 0.3
statusLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
statusLabel.BorderSizePixel = 2
statusLabel.BorderColor3 = Color3.fromRGB(255, 215, 0)
statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextStrokeTransparency = 0.2
statusLabel.ZIndex = 10
statusLabel.Text = ""
statusLabel.Visible = false
statusLabel.Parent = autoGui

-- 📌 Boss list
local bossList = {
    {id=308, modes={"medium","hard","extreme"}},
    {id=381, modes={"medium","hard","extreme"}},
    {id=330, modes={"medium","hard","extreme"}},
    {id=355, modes={"normal","medium","hard","extreme"}},
    {id=458, modes={"normal","medium","hard","extreme"}},
    {id=348, modes={"normal","medium","hard","extreme"}},
    {id=322, modes={"normal","medium","hard","extreme"}},
    {id=300, modes={"normal","medium","hard","extreme"}},
    {id=366, modes={"normal","medium","hard","extreme"}},
    {id=343, modes={"normal","medium","hard","extreme"}},
}

local alreadyFought = {}

-- 📌 Tìm popup
local function findPopup(keyword)
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextLabel") and string.find(gui.Text, keyword) then
            return true
        end
    end
    return false
end

-- 📌 Chờ kết quả trận
local function waitBattleEnd(timeout)
    local t = 0
    while t < timeout do
        if findPopup("Victory") or findPopup("Defeat") then
            return true
        end
        task.wait(1)
        t = t + 1
    end
    return false
end

-- 📌 Fight boss logic
local function fightBoss(id, mode)
    alreadyFought[id] = alreadyFought[id] or {}
    if alreadyFought[id][mode] then return end

    local bossName = bossNames[id] or ("Boss "..id)
    statusLabel.Text = "⚔️ "..bossName.." | "..mode
    task.wait()

    -- Fire boss
    networkEvent:FireServer(id, mode)
    task.wait(1.5)

    if findPopup("On Cooldown") then
        alreadyFought[id][mode] = true
        return
    elseif findPopup("You are in battle") then
        if waitBattleEnd(40) then
            alreadyFought[id][mode] = true
        else
            networkEvent:FireServer(id, mode)
            task.wait(1.5)
            if findPopup("On Cooldown") then
                alreadyFought[id][mode] = true
            end
        end
    else
        if waitBattleEnd(40) then
            alreadyFought[id][mode] = true
        else
            networkEvent:FireServer(id, mode)
            task.wait(1.5)
            if findPopup("On Cooldown") then
                alreadyFought[id][mode] = true
            end
        end
    end

    task.wait(3)
end

-- 🔥 Auto boss button click
autoBtn.MouseButton1Click:Connect(function()
    spawn(function()
        statusLabel.Visible = true
        statusLabel.Text = "⚔️ Auto Boss: Running..."
        for _, boss in ipairs(bossList) do
            for _, mode in ipairs(boss.modes) do
                fightBoss(boss.id, mode)
            end
        end
        statusLabel.Text = "✅ Auto Boss Finished!"
        task.wait(3)
        statusLabel.Visible = false -- 📴 Ẩn sau khi xong
    end)
end)

-- 🖱️📱 Drag GUI (PC + Mobile)
local dragging = false
local dragInput, dragStart, startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    autoBtn.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

autoBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = autoBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

autoBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement 
    or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        updateDrag(input)
    end
end)
