-- 📌 Auto Boss GUI – Final Optimized
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
statusLabel.Visible = false   -- 🚩 Thêm dòng này
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

local function isErrorPopupPresent()
    -- mấy lỗi cần skip
    local errorKeywords = {"on cooldown", "need to beat", "locked", "not unlocked"}
    for _, k in ipairs(errorKeywords) do
        if hasPopupContaining(k) then return true end
    end
    -- check error chung, nhưng bỏ qua "already in battle"
    if hasPopupContaining("error") and not hasPopupContaining("already in battle") then
        return true
    end
    return false
end

local function isInBattlePopupPresent()
    -- thêm cả trường hợp "already in battle" vào
    return hasPopupContaining("hide battle") 
        or hasPopupContaining("show battle") 
        or hasPopupContaining("already in battle")
end


local function didBattleEndAsWinOrLoss()
    return hasPopupContaining("victory") or hasPopupContaining("defeat") or isErrorPopupPresent()
end

-------------------------------------------------
-- ⚔️ Fight logic
-------------------------------------------------
local function fightBoss(id, mode)
    alreadyFought[id] = alreadyFought[id] or {}
    local bossName = bossNames[id] or ("Boss "..id)

    if alreadyFought[id][mode] then
        statusLabel.Text = "⏭️ "..bossName.." | "..mode.." already done"
        task.wait(1)
        return
    end

    statusLabel.Text = "⚔️ Fighting "..bossName.." | "..mode
    task.wait(0.15)

    local ok, err = pcall(function()
        networkEvent:FireServer(id, mode)
    end)
    if not ok then
        statusLabel.Text = "❌ FireServer error: "..tostring(err)
        task.wait(2)
        return
    end

    task.wait(1.2)

    if isErrorPopupPresent() then
        statusLabel.Text = "⏱️ "..bossName.." | "..mode.." error/cooldown"
        task.wait(5)
        alreadyFought[id][mode] = true
        return
    end

    if isInBattlePopupPresent() then
        local elapsed = 0
        while isInBattlePopupPresent() and elapsed < 35 do
            task.wait(1)
            elapsed += 1
        end

        task.wait(0.8)
        if didBattleEndAsWinOrLoss() then
            statusLabel.Text = "✅ "..bossName.." | "..mode.." finished!"
            alreadyFought[id][mode] = true
            task.wait(1.2)
            return
        else
            -- retry 1 lần
            statusLabel.Text = "⚠️ "..bossName.." | "..mode.." retry..."
            task.wait(1)
            local ok2 = pcall(function() networkEvent:FireServer(id, mode) end)
            task.wait(1.2)
            if isErrorPopupPresent() then
                statusLabel.Text = "✅ "..bossName.." | "..mode.." finished (cooldown)"
                alreadyFought[id][mode] = true
                task.wait(1.2)
                return
            elseif isInBattlePopupPresent() then
                while isInBattlePopupPresent() do task.wait(1) end
                task.wait(1.2)
                if didBattleEndAsWinOrLoss() then
                    statusLabel.Text = "✅ "..bossName.." | "..mode.." finished (after retry)"
                    alreadyFought[id][mode] = true
                    task.wait(1.2)
                    return
                end
            end
            statusLabel.Text = "❌ "..bossName.." | "..mode.." unknown, skipping"
            task.wait(2)
            alreadyFought[id][mode] = true
            return
        end
    end

    statusLabel.Text = "❌ "..bossName.." | "..mode.." no response"
    task.wait(2)
    alreadyFought[id][mode] = true
end

-------------------------------------------------
-- 🔥 Auto loop
-------------------------------------------------
autoBtn.MouseButton1Click:Connect(function()
    spawn(function()
        alreadyFought = {}  -- reset lại mỗi lần bấm nút
         statusLabel.Visible = true
        statusLabel.Text = "⚔️ Auto Boss: Running..."
        for _, boss in ipairs(bossList) do
            for _, mode in ipairs(boss.modes) do
                fightBoss(boss.id, mode)
            end
        end
        statusLabel.Text = "✅ Auto Boss: All finished!"
        task.wait(4)
  statusLabel.Visible = false                
    end)
end)


-------------------------------------------------
-- 🖱️ Drag support (PC + Mobile)
-------------------------------------------------
local dragging, dragInput, dragStart, startPos
autoBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        autoBtn.Position = UDim2.new( startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y ) end end)
