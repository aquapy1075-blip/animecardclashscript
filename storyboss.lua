-- 📌 Auto Boss GUI – Improved with Boss Names
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

-- 🔘 Nút AUTO FIGHT BOSS
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(0, 160, 0, 50)
autoBtn.Position = UDim2.new(0.5, -80, 0.8, 0)
autoBtn.AnchorPoint = Vector2.new(0.5,0)
autoBtn.Text = "⚔️ AUTO BOSS"
autoBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
autoBtn.TextScaled = true
autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoBtn.Parent = autoGui

-- 🏷️ Status label (to, nổi bật)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 400, 0, 60)
statusLabel.Position = UDim2.new(0, 20, 0, 20) -- góc trên trái
statusLabel.AnchorPoint = Vector2.new(0, 0)
statusLabel.BackgroundTransparency = 0.3
statusLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
statusLabel.BorderSizePixel = 2
statusLabel.BorderColor3 = Color3.fromRGB(255, 215, 0)
statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
statusLabel.TextScaled = true
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextStrokeTransparency = 0.2
statusLabel.ZIndex = 10
statusLabel.Text = ""
statusLabel.Parent = autoGui

-- 📌 Boss list
local bossList = {
    {id=308, modes={"medium","hard","extreme"}},
    {id=381, modes={"medium","hard","extreme"}},
    {id=330, modes={"medium","hard","extreme"}},
    {id=355, modes={"normal","medium","hard","extreme"}},
    {id=458, modes={"normal","medium","hard","extreme"}},
    {id=348, modes={"normal","medium","hard","extreme"}},
    {id=322, modes={"normal"}},
    {id=300, modes={"normal"}},
    {id=366, modes={"normal"}},
    {id=343, modes={"normal"}},
}

-- 🌟 Already fought
local alreadyFought = {}

-- Check battle finished
local function isBattleFinished()
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextLabel") and (string.find(gui.Text, "Victory") or string.find(gui.Text, "Defeat")) then
            return true
        end
    end
    return false
end

-- Fight one boss
local function fightBoss(id, mode)
    alreadyFought[id] = alreadyFought[id] or {}

    local bossName = bossNames[id] or ("Boss "..id)
    statusLabel.Text = "⚔️ Fighting "..bossName.." | Mode: "..mode.."..."
    wait() -- đảm bảo GUI update

    if alreadyFought[id][mode] then
        statusLabel.Text = "⏭️ "..bossName.." | Mode: "..mode.." already done, skipping"
        wait(1)
        return
    end

    local success, err = pcall(function()
        networkEvent:FireServer(id, mode)
    end)
    if not success then
        statusLabel.Text = "❌ Error with "..bossName.." | Mode: "..mode
        wait(1)
        return
    end

    -- Timeout for cooldown
    local timer = 0
    local timeout = 1.5
    repeat
        wait(0.5)
        timer = timer + 0.5
    until isBattleFinished() or timer >= timeout

    if timer >= timeout then
        statusLabel.Text = "⏱️ "..bossName.." | Mode: "..mode.." on cooldown, skipping"
    else
        statusLabel.Text = "✅ "..bossName.." | Mode: "..mode.." finished!"
        alreadyFought[id][mode] = true
    end
    wait(1)
end

-- 🔥 Auto boss button click
autoBtn.MouseButton1Click:Connect(function()
    spawn(function()
        statusLabel.Text = "⚔️ Auto Boss: Running..."
        for _, boss in ipairs(bossList) do
            for _, mode in ipairs(boss.modes) do
                fightBoss(boss.id, mode)
            end
        end
        statusLabel.Text = "✅ Auto Boss: All bosses finished!"
        wait(5)
        statusLabel.Text = ""
    end)
end)

-- 🖱️ Drag GUI
local dragging = false
local dragInput, dragStart, startPos
autoBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        autoBtn.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)
