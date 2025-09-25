-- 📌 Auto Boss – Headless
local player = game.Players.LocalPlayer
local networkEvent = game:GetService("ReplicatedStorage")
    :WaitForChild("shared/network@eventDefinitions")
    :WaitForChild("fightStoryBoss")

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
    for _, gui in ipairs(player.PlayerGui:GetDescendants()) do
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
        return
    end

    local success, err = pcall(function()
        networkEvent:FireServer(id, mode)
    end)

    if not success then
        warn("Error with Boss "..id.." | Mode: "..mode)
        return
    end

    -- Wait until battle finishes or timeout
    local timer = 0
    local timeout = 1.5
    repeat
        wait(0.5)
        timer = timer + 0.5
    until isBattleFinished() or timer >= timeout

    alreadyFought[id][mode] = true
end

-- 🔥 Execute auto boss
spawn(function()
    for _, boss in ipairs(bossList) do
        for _, mode in ipairs(boss.modes) do
            fightBoss(boss.id, mode)
        end
    end
    print("✅ Auto Boss: All bosses finished!")
end)
