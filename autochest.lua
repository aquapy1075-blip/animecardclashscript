
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
local GameAction = CFG.GameAction or "PlayAgain"


--------------------------------------------------
-- TABLE QUẢN LÝ UNIT
--------------------------------------------------
local UnitIds = {}        -- [Prefix] = {unit1, unit2}
local AutoUpgrade = {}   -- [Prefix] = true/false

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

local function waitForLives()
	local Lives = workspace:WaitForChild("Lives")
	while #Lives:GetChildren() == 0 do
		task.wait(0.1)
	end
	return Lives
end
local Presets = workspace:WaitForChild("Presets")
--------------------------------------------------
-- TRACK UNIT SAU KHI PLACE
--------------------------------------------------
local function trackPlacedUnit(unitPrefix)
	local conn
	conn = Presets.ChildAdded:Connect(function(unit)
		task.wait(0.05)
		if unit:GetAttribute("Prefix") == unitPrefix then
			UnitIds[unitPrefix] = UnitIds[unitPrefix] or {}
			table.insert(UnitIds[unitPrefix], unit)
			print("📌 Track:", unitPrefix)
			conn:Disconnect()
		end
	end)

	-- auto disconnect nếu không thấy sau 2s
	task.delay(2, function()
		if conn.Connected then
			conn:Disconnect()
		end
	end)
end


-- PLACE UNIT
local function placeUnit(slot, unitName, tileName)
	trackPlacedUnit(unitName)
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

--------------------------------------------------
-- AUTO UPGRADE (CHẠY NỀN)
--------------------------------------------------
task.spawn(function()
	while task.wait(0.3) do
		for prefix, enabled in pairs(AutoUpgrade) do
			if enabled and UnitIds[prefix] then
				for _, unit in ipairs(UnitIds[prefix]) do
					if unit and unit.Parent then
						UpgradeRemote:FireServer("Upgrade", unit)
						task.wait(0.05)
					end
				end
			end
		end
	end
end)


--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------
local lastWave = 0

task.spawn(function()
	while task.wait(0.6) do
		local wave, maxWave = getWave()
		if wave and wave ~= lastWave then
			lastWave = wave
			print("🌊 Wave", wave, "/", maxWave)

			-- RESET KHI GAME MỚI
			if wave == 1 then
				UnitIds = {}
				AutoUpgrade = {}
				print("♻️ Reset UnitIds & AutoUpgrade")
			end

			local actions = WaveActions[wave]
			if actions then
				for _, info in ipairs(actions) do
					if info.slot and info.unit and info.tile then
						placeUnit(info.slot, info.unit, info.tile)
						task.wait(PLACE_DELAY)
					elseif info.autoUpgrade then
						AutoUpgrade[info.autoUpgrade] = true
					end
				end
			end
			task.wait(0.3)
            Remote:FireServer("Vote")
		end
		task.wait(0.1)
		Remote:FireServer(GameAction)
	end
end)

