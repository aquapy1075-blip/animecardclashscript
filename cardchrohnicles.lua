

local function safeGet(fn)
	local ok, result = pcall(fn)
	return ok and result or nil
end

local function triggerConnections(signal)
	if type(getconnections) ~= "function" then
		return
	end

	for _, c in ipairs(getconnections(signal or {})) do
		pcall(c.Function)
	end
end

local function safeClick(button)
	if not button then
		return false
	end

	if type(getconnections) == "function" then
		triggerConnections(button.Activated)
		triggerConnections(button.MouseButton1Click)
	else
		pcall(function()
			button:Activate()
		end)
	end

	return true
end


local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "Aqua Hub",
    Icon = "door-open",
    Author = "by .aquane"
	Folder = "CardChronicles"
})
local MyConfig = Window.ConfigManager:Config("CC")
local BossTab = Window:Tab({
    Title = "Boss",
    Icon = "swords"
})

local Remote = game:GetService("ReplicatedStorage").RemoteEvents.BossFightAttempt
local PauseRemote = game:GetService("ReplicatedStorage").RemoteEvents.FightPauseRequest

local Bosses = {
    "Meliodas",
    "Geto",
	"Zeref"
}

local Difficulties = {
    "Base",
    "Gold",
    "Magmatic",
    "Abyssal",
    "Mystic",
    "Chronicle"
}

local AutoBoss = false
local BossConfig = {}

for _, BossName in ipairs(Bosses) do
    BossConfig[BossName] = {
        Enabled = false,
        Difficulty = "Base"
    }
end

for _, BossName in ipairs(Bosses) do

    BossTab:Toggle({
        Title = BossName,
        Value = false,
        Flag = "Boss_" .. BossName,
        Callback = function(state)
            BossConfig[BossName].Enabled = state
        end
    })

    BossTab:Dropdown({
        Title = BossName .. " Difficulty",
        Values = Difficulties,
        Value = "base",
        Multi = false,
        Flag = "BossDiff_" .. BossName,
        Callback = function(selected)
            BossConfig[BossName].Difficulty = selected
        end
    })

end
BossTab:Divider()
BossTab:Toggle({
	Title = "Auto Hide Battle",
	Value = false,
	Flag = "AutoHideBattle",
	Callback = function(state)
		AutoHideBattle = state
	end
})

BossTab:Toggle({
    Title = "Auto Boss",
    Value = false,
    Flag = "AutoBoss",
    Callback = function(state)
        AutoBoss = state
    end
})
local function WaitForBossFinish(BossName, Difficulty)
    local Start = tick()

    while tick() - Start < 75 do
        task.wait(5)

        local success, result = pcall(function()
            return Remote:InvokeServer(BossName, Difficulty)
        end)

        if success
            and type(result) == "table"
            and result.reason == "cooldown"
            and result.secondsLeft > 0 then

            print(BossName, "finished")
            return true
        end
    end

    warn(BossName, "timeout")
    return false
end

task.spawn(function()
    while true do -- 3 phút
        task.wait(2)
        if not AutoBoss then
            continue
        end

        -- Dừng Infinite Mode
        pcall(function()
            PauseRemote:FireServer(1)
        end)
        
        task.wait(2)

        -- Đánh các boss được bật
        for BossName, Data in pairs(BossConfig) do
            if Data.Enabled then
                pcall(function()
                    return Remote:InvokeServer(
                        BossName,
                        Data.Difficulty
                    )
                end)
                WaitForBossFinish(BossName, Data.Difficulty)
                print("Boss xong")

                task.wait(0.5)
            end
        end

        -- Chờ boss teleport xong
        task.wait(5)

        -- Quay lại Infinite Mode
        local Character = game.Players.LocalPlayer.Character
        if Character and Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.CFrame = CFrame.new(3601, 19, 2)
            task.wait(1)
            Character.HumanoidRootPart.CFrame = CFrame.new(3143, 18, -228)
            
        end
        task.wait(180)
    end
end)


local function HideBattle()
	local button = safeGet(function()
		return game:GetService("Players").LocalPlayer.PlayerGui.UI.OtherUI.BattleUI1.HideButton
	end)

	if not button then
		return false
	end

	return safeClick(button)
end

task.spawn(function()
	while task.wait(3) do
		if AutoHideBattle then
			HideBattle()
		end
	end
end)
