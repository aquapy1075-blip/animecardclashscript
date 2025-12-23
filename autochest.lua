
-- Anti AFK
local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
	vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- GUI WAVE
local WaveLabel = Player.PlayerGui.Upboard.Wave.WaveFrame.BG.TextLabel

-- REMOTE (ĐỔI NẾU TÊN KHÁC)
local PlaceRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TilePlacement")
local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Upboard")
local UpgradeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Champion")


local CFG = getgenv().AutoConfig

local PRIORITY_PREFIXES = CFG.priorityUpgrade
local WaveActions = CFG.waveActions
local PLACE_DELAY = 0.75
local UPGRADE_DELAY = 0.005
local GameAction = CFG.GameAction or "PlayAgain"

-- PARSE WAVE
local function getWave()
    local text = WaveLabel.Text
    local current, max = text:match("(%d+)%s*/%s*(%d+)")
    return tonumber(current), tonumber(max)
end

local function upgradeUnit(unit)
    local args = {
        "Upgrade",
        unit
    }
    UpgradeRemote:FireServer(unpack(args))
end

local function waitForLiveLoaded()
    local Lives = workspace:WaitForChild("Lives")

    while #Lives:GetChildren() == 0 do
        task.wait(0.1)
    end
end
local function waitForPrefix(unit, timeout)
    timeout = timeout or 2
    local start = tick()

    while not unit:GetAttribute("Prefix") do
        if tick() - start > timeout then
            return false
        end
        task.wait(0.05)
    end
    return true
end

local function autoUpgradePriority()
	local Presets = workspace.Presets
   for _, unit in ipairs(Presets:GetChildren()) do
            local prefix = unit:GetAttribute("Prefix")
            if PRIORITY_PREFIXES[prefix] then
                upgradeUnit(unit)
                task.wait()
            end
    end
end
local function autoUpgradeAll()
	waitForLiveLoaded()
   local Lives = workspace.Lives
   for _, unit in ipairs(Lives:GetChildren()) do
        upgradeUnit(unit)
        task.wait()
    end
    print("⬆️ Auto Upgrade All Units")
end


-- PLACE UNIT
local function placeUnit(slot, unitName, tileName)
    local args = {
        "Place",
        slot,
        unitName,
        CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        workspace:WaitForChild("Arena"):WaitForChild(tileName),
        0
    }

    PlaceRemote:FireServer(unpack(args))
end


-- MAIN LOOP
local lastWave = 0

task.spawn(function()
    while task.wait(0.65) do
        local wave, maxWave = getWave()
        if wave and wave ~= lastWave then
            lastWave = wave
            print("🌊 Wave", wave, "/", maxWave)

            local actions = WaveActions[wave]
            if actions then
               for _, info in ipairs(actions) do
                 if info.upgradePriority then
                       autoUpgradePriority()
					   task.wait(0.005)
                   elseif info.upgradeAll then
                       autoUpgradeAll()
					   task.wait(0.005)
                   else
                       placeUnit(info.slot, info.unit, info.tile)
                       task.wait(PLACE_DELAY)
                    end
                end
            end
        end
		task.wait(0.1)
        Remote:FireServer("Vote")
		task.wait(0.1)
        Remote:FireServer(GameAction)
    end
end)

