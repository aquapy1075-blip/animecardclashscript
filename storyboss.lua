-- 📌 Auto Boss GUI – Optimized
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local networkEvent = game:GetService("ReplicatedStorage")
    :WaitForChild("shared/network@eventDefinitions")
    :WaitForChild("fightStoryBoss")

-- 🌟 Boss ID -> Name
local bossNames = {
    [308] = "Naruto", [381] = "Frieza", [330] = "Sukuna", [355] = "Titan",
    [458] = "Muzan", [348] = "Big Mom", [322] = "Sungjinwoo", [300] = "Cid",
    [366] = "Celestial Sovereign", [343] = "Dead King",
}

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

-- 🌟 Already fought
local alreadyFought = {}

-- 🎨 GUI
local autoGui = Instance.new("ScreenGui")
autoGui.Name = "AutoBossUI"
autoGui.ResetOnSpawn = false
autoGui.IgnoreGuiInset = true
autoGui.Parent = playerGui

-- 🔘 Nút AUTO
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(0, 120, 0, 40)
autoBtn.Position = UDim2.new(0.5, 0, 0, 10)
autoBtn.AnchorPoint = Vector2.new(0.5,0)
autoBtn.Text = "⚔️ AUTO BOSS"
autoBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
autoBtn.TextScaled = true
autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoBtn.Parent = autoGui

-- 🏷️ Status label
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
statusLabel.Parent = autoGui

-------------------------------------------------
-- 🔎 Popup helpers
-------------------------------------------------
local function hasPopupContaining(keyword)
    if not keyword or keyword == "" then return false end
    local kw = keyword:lower()
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local ok, txt = pcall(function() return tostring(gui.Text) end)
            if ok and txt and txt ~= "" and string.find(txt:lower(), kw, 1, true) then
                return true
            end
        end
    end
    return false
end

local function isCooldownPopupPresent()
    return hasPopupContaining("on cooldown")
        or hasPopupContaining("need to beat")
        or hasPopupContaining("locked")
        or hasPopupContaining("not unlocked")
end

local function isInBattlePopupPresent()
    return hasPopupContaining("hide battle")
        or hasPopupContaining("show battle")
        or hasPopupContaining("you are in battle")
end

local function didBattleEndAsWinOrLoss()
    return hasPopupContaining("victory") or hasPopupContaining("defeat")
end

-------------------------------------------------
-- ⚔️ Fight logic
-------------------------------------------------
local function fightBoss(id, mode)
    alreadyFought[id] = alreadyFought[id] or {}
    local bossName = bossNames[id] or ("Boss "..id)

    if alreadyFought[id][mode] then
        updateStatus("⏭️ "..bossName.." | "..mode.." already done",1)
        return
    end

    updateStatus("⚔️ Fighting "..bossName.." | "..mode,0.15)
    local ok, err = pcall(function() networkEvent:FireServer(id, mode) end)
    if not ok then
        updateStatus("❌ FireServer error: "..tostring(err),2)
        return
    end

    task.wait(1)

    -- Case 1: Boss on cooldown / locked
    if isCooldownPopupPresent() then
        updateStatus("⏱️ "..bossName.." | "..mode.." cooldown/locked",3)
        alreadyFought[id][mode] = true
        return
    end

    -- Case 2: Battle started
    if isInBattlePopupPresent() then
        while isInBattlePopupPresent() do task.wait(1) end  -- đợi popup biến mất
        task.wait(1)

        if didBattleEndAsWinOrLoss() then
            updateStatus("✅ "..bossName.." | "..mode.." finished!",1)
            alreadyFought[id][mode] = true
        else
            -- fallback: coi như skip luôn
            updateStatus("❌ "..bossName.." | "..mode.." ended with no result",2)
            alreadyFought[id][mode] = true
        end
        return
    end

    -- Case 3: Không thấy gì
    updateStatus("❌ "..bossName.." | "..mode.." no response",2)
    alreadyFought[id][mode] = true
end

-------------------------------------------------
-- 🔥 Auto loop
-------------------------------------------------
autoBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        updateStatus("⚔️ Auto Boss: Running...")
        for _, boss in ipairs(bossList) do
            for _, mode in ipairs(boss.modes) do
                fightBoss(boss.id, mode)
            end
        end
        updateStatus("✅ Auto Boss: All finished!",4)
        updateStatus("")
    end)
end)

-------------------------------------------------
-- 🖱️ Drag support
-------------------------------------------------
local function enableDrag(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

enableDrag(autoBtn)
