if game.PlaceId ~= 114758508835875 then
    return
end
local VIM = game:GetService("VirtualInputManager")



local JUMP_INTERVAL = 120

task.spawn(function()
	while true do
		task.wait(JUMP_INTERVAL)
		VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
		task.wait(0.1)
		VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
	end
end)

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
    Author = "by .aquane",
	Folder = "CardChronicles",
    Size = UDim2.fromOffset(580, 460), -- window size
    MinSize = Vector2.new(560, 350), -- minimal window size
    MaxSize = Vector2.new(850, 560), -- maximum window size
	Transparent = true, -- window transparency
    Theme = "Dark", -- library theme
    Resizable = true, -- the ability to rezize window
    ToggleKey = Enum.KeyCode.V, -- key to toggle window
	   KeySystem = { -- key system from this library
        --  ↓ DEPRECATED
        -- Key = { "1234", "5678" },
 
        -- ✓ use this instead:
        KeyValidator = function(enteredKey)
            if enteredKey == "2005" then
                return true -- this means the key is correct
            end
            return false -- this is if the key is not correct 
        end,
 
        Note = "Example Key System.",
        
        Thumbnail = { -- the image which is located on the left. optional. it can be removed
            Image = "rbxassetid://114289527320220",
            Title = "AquaHub", -- optional. it can be removed
        },
        
        SaveKey = true, -- automatically save and load the key.
    },
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
	"Zeref",
	"Whitebeard"
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
local AutoHideBattle = false
local UseWeatherPotion = false
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
        Value = "Base",
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
	Title = "Auto Use Weather Potion When No Weather",
	Value = false,
	Flag = "AutoUseWeatherPotion",
	Callback = function(state)
		UseWeatherPotion = state
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

local Button = BossTab:Button({
    Title = "Save Config",
    Desc = "",
    Locked = false,
    Callback = function()
        MyConfig:Save()
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

        for i = 1,5 do 
            pcall(function()
              PauseRemote:FireServer(1)
            end)
            task.wait(0.5)
		end

        -- Đánh các boss được bật
        for _, BossName in ipairs(Bosses) do
            local Data = BossConfig[BossName]
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
        task.wait(120)
    end
end)


local function HideBattle()
    local battleUI = safeGet(function()
        return game:GetService("Players")
            .LocalPlayer
            .PlayerGui
            .UI
            .OtherUI
            .BattleUI1
    end)

    if not battleUI then
        return false
    end

    if not battleUI.Visible then
        return false
    end

    local button = safeGet(function()
        return battleUI.HideButton
    end)

    if not button then
        return false
    end

    return safeClick(button)
end

task.spawn(function()
	while task.wait(2) do
		if AutoHideBattle then
			HideBattle()
		end
	end
end)

task.spawn(function()
	while task.wait(30) do
		if not UseWeatherPotion then
			continue
		end

		local weatherName = safeGet(function()
			return game.Players.LocalPlayer.PlayerGui.UI.MainUI.WeatherUI.WeatherName
		end)

		if weatherName and weatherName.Text == "RELEASE EVENT" then
			game:GetService("ReplicatedStorage")
				.RemoteEvents
				.ItemUseRequest
				:FireServer("weather_potion", 1)
		end
	end
end)
