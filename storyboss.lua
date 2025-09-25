-- 📌 Auto Boss – Headless + On-screen Boss Name
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local networkEvent = game:GetService("ReplicatedStorage")
    :WaitForChild("shared/network@eventDefinitions")
    :WaitForChild("fightStoryBoss")

-- 🌟 Mapping id -> boss name
local bossNames = {
    [308] = "Cuu Vi",
    [381] = "Frieza",
    [330] = "Sukuna",
    [355] = "Titan",
    [458] = "Muzan",
    [348] = "Big Mom",
    [322] = "Sungjinwoo",
    [300] = "Cid",
    [366] = "Boruto",
    [343] = "Dead King",
}

-- 📌 Boss list with modes
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

-- 🖥️ TextLabel hiển thị trạng thái boss (đẹp hơn)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 400, 0, 60)            -- to hơn
statusLabel.Position = UDim2.new(0, 20, 0, 20)         -- góc trên trái
statusLabel.AnchorPoint = Vector2.new(0, 0)
statusLabel.BackgroundTransparency = 0.4               -- hơi mờ
statusLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- nền đen
statusLabel.BorderSizePixel = 2
statusLabel.BorderColor3 = Color3.fromRGB(255, 215, 0) -- viền vàng
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)   -- chữ vàng
statusLabel.TextScaled = true
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.GothamBold                 -- font đẹp
statusLabel.TextStrokeTransparency = 0.2                -- viền chữ mờ
statusLabel.ZIndex = 10                                 -- nổi trên các GUI khác
statusLabel.Text = ""
statusLabel.Parent = playerGui


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

    if alreadyFought[id][mode] then
        statusLabel.Text = "⏭️ "..bossNames[id].." | Mode: "..mode.." already done, skipping"
        wait(1)
        return
    end

    statusLabel.Text = "⚔️ Fighting "..(bossNames[id] or ("Unknown Boss "..id)).." | Mode: "..mode.."..."
    
    local success, err = pcall(function()
        networkEvent:FireServer(id, mode)
    end)

    if not success then
        statusLabel.Text = "❌ Error with "..(bossNames[id] or id).." | Mode: "..mode
        wait(1)
        return
    end

    -- Wait until battle finishes or timeout
    local timer = 0
    local timeout = 1.5
    repeat
        wait(0.5)
        timer = timer + 0.5
    until isBattleFinished() or timer >= timeout

    if timer >= timeout then
        statusLabel.Text = "⏱️ "..(bossNames[id] or id).." | Mode: "..mode.." on cooldown, skipping"
    else
        statusLabel.Text = "✅ "..(bossNames[id] or id).." | Mode: "..mode.." finished!"
        alreadyFought[id][mode] = true
    end

    wait(1) -- hiển thị trạng thái 1s trước khi chuyển boss khác
end

-- 🔥 Execute auto boss
spawn(function()
    for _, boss in ipairs(bossList) do
        for _, mode in ipairs(boss.modes) do
            fightBoss(boss.id, mode)
        end
    end
    statusLabel.Text = "✅ Auto Boss: All bosses finished!"
end)

-- 🌐 Load external storyboss.lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/storyboss.lua", true))()
