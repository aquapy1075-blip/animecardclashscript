-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- GUI WAVE
local WaveLabel = Player.PlayerGui.Upboard.Wave.WaveFrame.BG.TextLabel

-- REMOTE (ĐỔI NẾU TÊN KHÁC)
local PlaceRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Champion")

-- ========= CONFIG =========

local WaveActions = {
    [1] = {
        {slot="Slot_03", unit="Blade Master", tile="PlacementTile_3_2"},
    },
    [2] = {
        {slot="Slot_01", unit="Cat Burglar", tile="PlacementTile_3_5"},
    },
    [3] = {
        {slot="Slot_01", unit="Cat Burglar", tile="PlacementTile_3_6"},
        {slot="Slot_02", unit="Medic Ninja", tile="PlacementTile_4_2"},
    },
    [4] = {
        {slot="Slot_01", unit="Cat Burglar", tile="PlacementTile_3_6"},
        {slot="Slot_04", unit="Fused Gatsu", tile="PlacementTile_1_3"},
    },
    [5] = {
        {slot="Slot_02", unit="Medic Ninja", tile="PlacementTile_4_3"},
        {slot="Slot_02", unit="Medic Ninja", tile="PlacementTile_4_4"},
         {slot="Slot_04", unit="Fused Gatsu", tile="PlacementTile_1_1"},
    },
    [6] = {
        {slot="Slot_05", unit="Light Admiral", tile="PlacementTile_1_6"},
        {slot="Slot_05", unit="Light Admiral", tile="PlacementTile_2_5"},
    },
    [7] = {
        {slot="Slot_04", unit="Fused Gatsu", tile="PlacementTile_1_5"},
    },
}

local PLACE_DELAY = 0.25

-- ==========================

-- PARSE WAVE
local function getWave()
    local text = WaveLabel.Text
    local current, max = text:match("(%d+)%s*/%s*(%d+)")
    return tonumber(current), tonumber(max)
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
    while task.wait(0.4) do
        local wave, maxWave = getWave()
        if wave and wave ~= lastWave then
            lastWave = wave
            print("🌊 Wave", wave, "/", maxWave)

            local actions = WaveActions[wave]
            if actions then
                for _, info in ipairs(actions) do
                    placeUnit(info.slot, info.unit, info.tile)
                    task.wait(PLACE_DELAY)
                end
            end
        end
    end
end)

