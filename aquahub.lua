

-- Anti AFK
local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)


-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- UI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
-- Net
local Net = {
    fightStoryBoss = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("fightStoryBoss"),
    setPartySlot   = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("setPartySlot"),
    fightBattleTowerWave = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("fightBattleTowerWave"),
    fightGlobalBoss = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("fightGlobalBoss"),
    fightInfinite = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("fightInfinite"),
    forfeitBattle = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("forfeitBattle"),
    claimInfinite = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("claimInfinite"),
    pauseInfinite = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("pauseInfinite"),
    netSetting = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("setSetting")
}


-------------------------------------------------
-- Data
-------------------------------------------------


local BossData = {
       Names = {
        [308] = "Naruto", [381] = "Frieza", [330] = "Sukuna",
        [355] = "Titan", [458] = "Muzan", [348] = "Big Mom",
        [322] = "Sungjinwoo", [300] = "Cid",
        [366] = "Celestial Sovereign", [343] = "Dead King",
    },
    List = {
        {id=308, modes={"normal","medium","hard","extreme"}},
        {id=381, modes={"normal","medium","hard","extreme"}},
        {id=330, modes={"normal","medium","hard","extreme"}},
        {id=355, modes={"normal","medium","hard","extreme"}},
        {id=458, modes={"normal","medium","hard","extreme"}},
        {id=348, modes={"normal","medium","hard","extreme"}},
        {id=322, modes={"normal","medium","hard","extreme"}},
        {id=300, modes={"normal","medium","hard","extreme"}},
        {id=366, modes={"normal","medium","hard","extreme"}},
        {id=343, modes={"normal","medium","hard","extreme"}},
    },
    TeamOptions = {"slot_1","slot_2","slot_3","slot_4","slot_5","slot_6","slot_7","slot_8"},
}
    local TowerData = {
    Modes = {"battle_tower","frozen_landscape","inferno_depths","lunar_esclipe"},
    ModeNames = {
        battle_tower = "Battle Tower",
        frozen_landscape = "Frozen Landscape",
        inferno_depths = "Inferno Depths Tower",
        lunar_esclipe = "Lunar Esclipe",
    },
    TeamOptions = {"slot_1","slot_2","slot_3","slot_4","slot_5","slot_6","slot_7","slot_8"}
}  


    local GlobalBossData = {
            Position = CFrame.new(1019,9,-245),
            SpawnUTCWindows = { {18,20}, {21,23}, {0,2}, {3,5},{6,8}, {9,11}, {12,14}, {15,17}},
            DurationHours = 2, 
            TeamOptions = {"slot_1","slot_2","slot_3","slot_4","slot_5","slot_6","slot_7","slot_8"}
    }

  local InfiniteData = {
    Modes = {
        "base", "nightmare", "potion", "ninja_village", "green_planet",
        "shibuya_station", "titans_city", "dimensional_fortress",
        "candy_island", "solo_city", "eminence_lookout",
        "invaded_ninja_village", "necromancer_graveyard"
    },

    ModeNames = {
        base = "Infinite",
        nightmare = "HardCore",
        potion = "Potion",
        ninja_village = "Ninja Village",
        green_planet = "Green Planet",
        shibuya_station = "Shibuya Station",
        titans_city = "Titans City",
        dimensional_fortress = "Dimensional Fortress",
        candy_island = "Candy Island",
        solo_city = "Solo City",
        eminence_lookout = "Eminence Lookout",
        invaded_ninja_village = "Invaded Ninja Village",
        necromancer_graveyard = "Necromancer Graveyard"
    },
    TeamOptions = {"slot_1","slot_2","slot_3","slot_4","slot_5","slot_6","slot_7","slot_8"}
}

-------------------------------------------------
-- State
-------------------------------------------------
local State = {}


------------- Boss--------------

State.selectedBosses = {}      -- toggle chọn boss trong UI
State.bossTeams = {}           -- team slot cho từng boss
State.alreadyFought = {}       -- boss đã đánh xong, table { [bossId] = {mode1=true, mode2=true} }
State.bossSelectedModes = {}   -- multi-mode chọn trong UI, table { [bossId] = {"normal","medium"} }

-- Auto control riêng cho Boss
State.autoEnabledBoss = false
State.autoRunIdBoss = 0
-- Khởi tạo Boss 

for id in pairs(BossData.Names) do
    State.selectedBosses[id] = false
    State.bossTeams[id] = "slot_1"
    State.alreadyFought[id] = {}
    State.bossSelectedModes[id] = {}  -- chưa chọn mode nào
end

-------------- Battle Tower-------------
State.selectedTowerModes = {}       -- toggle chọn mode trong UI
State.towerTeams = {}               -- team slot cho từng mode
State.towerAlreadyFought = {}       -- wave đã đánh xong, table { [mode] = {wave1=true, wave2=true} }
State.towerSelectedWaves = {}       -- multi-wave chọn trong UI, table { [mode] = {1,2,3} }

-- Auto control riêng cho Battle Tower
State.autoEnabledTower = false
State.autoRunIdTower = 0
-- Khởi tạo Battle Tower
for _, mode in ipairs(TowerData.Modes) do
    State.selectedTowerModes[mode] = false
    State.towerTeams[mode] = "slot_1"
    State.towerAlreadyFought[mode] = {}   -- chưa đánh wave nào
    State.towerSelectedWaves[mode] = {}   -- chưa chọn wave nào
end

--------------- Global Boss ---------------
State.globalBossTeamHighHP = "slot_1"   -- team khi boss HP ≥ 75m
State.globalBossTeamLowHP  = "slot_1"   -- team khi boss HP < 75m
State.gbSwitchedHighHp = false
State.autoEnabledGb = false
State.hasTeleported = false
--------------- Infinite Tower ------------
State.InfinitieTeam = "slot_1"
State.selectedInfMode = "base"
State.autoEnabledInf = false

--------------- Combine Mode --------------
-- State cho Combine Mode
State.combineRunning = false  -- bật/tắt Combine Mode
State.combinePriority = {      -- toggle chọn mode nào tham gia Combine
    BattleTower = false,
    StoryBoss  = false,
    GlobalBoss = false,
    InfTower   = false
}
State.combineInputCooldown = {  -- lưu giá trị người chơi nhập (xhxm) nếu cần hiển thị
    BattleTower = "0",
    StoryBoss  = "0"
}
-- Không cần countdown hiện tại nữa, controller tự quản lý cooldown

-------------------------------------------------
-- Utils
-------------------------------------------------
local Utils = {}

function Utils.notify(title, content, duration)
    Rayfield:Notify({ Title = title, Content = content, Duration = duration or 2 })
end

-- Global Boss Check -- 
function Utils.isBossSpawnTime()
    local now = os.date("!*t")  -- giờ UTC
    local hour = now.hour

    for _, window in ipairs(GlobalBossData.SpawnUTCWindows) do
        local startH, endH = table.unpack(window)
        if startH <= endH then
            if hour >= startH and hour < endH then
                return true
            end
        else
            -- qua 0h
            if hour >= startH or hour < endH then
                return true
            end
        end
    end
    return false
end

function Utils.teleportToBoss()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    hrp.CFrame = GlobalBossData.Position
end


-- Popup check
function Utils.hasPopupContaining(PlayerGui, keyword)
     if not PlayerGui then return false end
    if not keyword or keyword == "" then return false end
    local kw = keyword:lower()
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local ok, txt = pcall(function() return tostring(gui.Text) end)
            if ok and txt and txt ~= "" and string.find(txt:lower(), kw, 1, true) then
                return true
            end
        end
    end
    return false
end

function Utils.isErrorPopupPresent(PlayerGui)
    if not PlayerGui then return false end
    local errorKeywords = {"need to beat", "locked", "not unlocked", "on cooldown"}
    for _, k in ipairs(errorKeywords) do
        if Utils.hasPopupContaining(PlayerGui, k) then return true end
    end
    if Utils.hasPopupContaining(PlayerGui, "error")
        and not Utils.hasPopupContaining(PlayerGui, "already in battle") then
        return true
    end
    return false
end

function Utils.isInBattlePopupPresent(PlayerGui)    pg = pg or PlayerGui
    if not PlayerGui then return false end
    return Utils.hasPopupContaining(pg, "hide battle")
        or Utils.hasPopupContaining(pg, "show battle")
        or Utils.hasPopupContaining(pg, "already in battle")
end

function Utils.didBattleEndAsWinOrLoss(PlayerGui)
     if not PlayerGui then return false end
    return Utils.hasPopupContaining(PlayerGui, "victory")
        or Utils.hasPopupContaining(PlayerGui, "defeat")
        or Utils.isErrorPopupPresent(PlayerGui)
end
-- Tower check
function Utils.isTowerBattlePopupPresent(PlayerGui, TowerData)
    if not PlayerGui then return false end
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local ok, txt = pcall(function() return tostring(gui.Text) end)
            if ok and txt and txt ~= "" then
                local lowerTxt = txt:lower()
                -- Kiểm tra nút hide battle
                if lowerTxt:find("hide battle") or lowerTxt:find("show battle")then
                    return true
                end
                -- Kiểm tra dòng đang đánh tower
            end    
        end
    end
    return false
end

-------------------------------------------------
-- Global Boss Controller
-------------------------------------------------

local GlobalBossController = {}


local function getBossHP()
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("TextLabel") then
            local txt = v.Text:gsub(",", ""):gsub("%s+", "")
            local cur, max = txt:match("(%d+%.?%d*)/(%d+)")
            if cur and max then
                cur = math.floor(tonumber(cur))
                max = tonumber(max)
                if max and max >= 1000000 then
                    
                    return cur -- chỉ trả current HP
                end
            end
        end
    end
    return nil
end

-- Run Auto Global Boss
function GlobalBossController.runAuto()
    if State.autoEnabledGb then return end
    State.autoEnabledGb = true

    task.spawn(function()
        while State.autoEnabledGb do
            -- Kiểm tra boss spawn theo giờ
            if Utils.isBossSpawnTime() then
                -- Teleport nếu chưa teleport trong khung giờ
                if not State.hasTeleported then
                    Utils.teleportToBoss()
                    State.hasTeleported = true
                    State.gbCheckedHighHp = false
                    Utils.notify("Global Boss", "Teleported to boss!", 2)
                     Net.setPartySlot:FireServer(State.globalBossTeamLowHP or "slot_1")
                end

                -- use whichever PlayerGui variable exists
                local gui = PlayerGui

                -- Nếu không đang popup combat → bắt đầu fight
                if not Utils.isInBattlePopupPresent(gui) then
                    -- Lấy current HP của boss
                    local curHp = getBossHP()

                    -- Đổi team theo HP (chỉ ELSE nằm trong cùng if curHp)
                     if curHp and curHp >= 75000000 and not State.gbCheckedHighHp then
                        
                            Net.setPartySlot:FireServer(State.globalBossTeamHighHP or "slot_1")
                            Utils.notify("Global Boss", "Switch to High HP Team ("..curHp..")", 2)
                          State.gbCheckedHighHp = true
                    end

                    -- Spam fight boss
                    pcall(function()
                        Net.fightGlobalBoss:FireServer(450) -- boss ID fix = 450
                    end)
                end
            else
                -- Boss despawn → reset flag
                State.hasTeleported = false
                State.gbSwitchedHighHp = false
            end

            task.wait(0.5) -- delay giữa mỗi lần check/fight
        end
    end)
end


-- Stop Auto Global Boss
function GlobalBossController.stopAuto()
    State.autoEnabledGb = false
    State.hasTeleported = false
end
-------------------------------------------------
-- Boss Controller
-------------------------------------------------   
local BossController = {}

function BossController.fightBoss(id, mode, runId)
    if not State.autoEnabledBoss or runId ~= State.autoRunIdBoss then return end

    -- set team cho boss
    Net.setPartySlot:FireServer(State.bossTeams[id] or "slot_1")

    local name = BossData.Names[id] or ("Boss "..id)
    Utils.notify("Story Boss", "⚔️ Fighting "..name.." | "..mode, 2)
    print("Fighting Boss:", id, mode, "with team", State.bossTeams[id])
    local ok, err = pcall(function()
        Net.fightStoryBoss:FireServer(id, mode)
    end)
    if not ok then
        Utils.notify("Error", tostring(err), 2)
        State.alreadyFought[id] = State.alreadyFought[id] or {}
        State.alreadyFought[id][mode] = true
        return
    end

    task.wait(0.5)

    -- chờ popup battle xuất hiện
    local battleElapsed = 0
    while not Utils.isInBattlePopupPresent(PlayerGui) and battleElapsed < 3 do
        if not State.autoEnabledBoss or runId ~= State.autoRunIdBoss then return end
        task.wait(1)
        battleElapsed += 1
    end

    -- nếu vẫn không thấy popup, thông báo no response
    if not Utils.isInBattlePopupPresent(PlayerGui) then
        Utils.notify("No Response", name.." | "..mode.." no response", 2)
        State.alreadyFought[id] = State.alreadyFought[id] or {}
        State.alreadyFought[id][mode] = true
        return
    end

    -- đợi battle kết thúc
    local elapsed = 0
    while Utils.isInBattlePopupPresent(PlayerGui) and elapsed < 180 do
        if not State.autoEnabledBoss or runId ~= State.autoRunIdBoss then return end
        task.wait(1)
        elapsed += 1
    end

    -- check kết quả
    if Utils.didBattleEndAsWinOrLoss(PlayerGui) then
        Utils.notify("Finished", name.." | "..mode.." done!", 2)
    elseif Utils.isErrorPopupPresent(PlayerGui) then
        Utils.notify("Cooldown/Error", name.." | "..mode, 3)
    else
        Utils.notify("Skipped", name.." | "..mode.." skipped", 2)
    end

    State.alreadyFought[id] = State.alreadyFought[id] or {}
    State.alreadyFought[id][mode] = true
end


function BossController.runAuto()
    State.autoRunIdBoss += 1
    local runId = State.autoRunIdBoss

    task.spawn(function()
        while State.autoEnabledBoss and runId == State.autoRunIdBoss do
            -- build plan từ boss được chọn
            local plan = {}
            for _, boss in ipairs(BossData.List) do
                if State.selectedBosses[boss.id] then
                    local modesToFight = {}
                    local selectedModes = State.bossSelectedModes[boss.id] or {}

                    -- nếu người chơi chưa chọn mode nào, fallback đánh tất cả mode boss hỗ trợ
                    if #selectedModes == 0 then
                        selectedModes = boss.modes
                    end

                    for _, mode in ipairs(selectedModes) do
                        if not (State.alreadyFought[boss.id] and State.alreadyFought[boss.id][mode]) then
                            table.insert(modesToFight, mode)
                        end
                    end

                    if #modesToFight > 0 then
                        table.insert(plan, {id=boss.id, modes=modesToFight})
                    end
                end
            end

            if #plan == 0 then
                Utils.notify("Info", "All selected bosses are on cooldown or done", 2)
                State.autoEnabledBoss = false
                break
            else
                for _, item in ipairs(plan) do
                    for _, mode in ipairs(item.modes) do
                        if not State.autoEnabledBoss or runId ~= State.autoRunIdBoss then break end
                        BossController.fightBoss(item.id, mode, runId)
                    end
                    if not State.autoEnabledBoss or runId ~= State.autoRunIdBoss then break end
                end
            end

            task.wait(2)
        end
    end)
end
function BossController.stopAuto()
    State.autoRunIdBoss += 1
    State.alreadyFought = {}
end

-------------------------------------------------
-- BATTLE TOWER CONTROLLER 
-------------------------------------------------
local TowerController = {}

-- Mỗi wave đánh bao nhiêu floor
local FloorsPerWave = {
    battle_tower = 5,
    frozen_landscape = 10,
    inferno_depths = 10,
    lunar_esclipe = 10,
}

--- Fight Tower Wave Logic ---
function TowerController.fightWave(mode, wave, runId)
    if not State.autoEnabledTower or runId ~= State.autoRunIdTower then return end

    local startFloor = (wave - 1) * FloorsPerWave[mode] + 1
    local endFloor   = wave * FloorsPerWave[mode]
    local currentFloor = startFloor

    Utils.notify("Tower", "⚔️ Fighting "..TowerData.ModeNames[mode].." | Wave "..wave.." (Floor "..startFloor.." → "..endFloor..")", 5)

    -- Set team cho mode hiện tại
    local selectedTeam = State.towerTeams[mode] or "slot_1"
    Net.setPartySlot:FireServer(selectedTeam)

    -- Gửi request đánh Tower
    print("Fighting Tower Mode:", mode, "Wave:", wave, "with team", State.towerTeams[mode])
    pcall(function()
        Net.fightBattleTowerWave:FireServer(mode, wave)
    end)

    -- Đợi battle bắt đầu (dựa vào nút hide/show battle)
    local battleStartElapsed = 0
    while not Utils.isTowerBattlePopupPresent(PlayerGui, TowerData) and battleStartElapsed < 10 do
        if not State.autoEnabledTower or runId ~= State.autoRunIdTower then return end
        task.wait(1)
        battleStartElapsed += 1
    end

    if not Utils.isTowerBattlePopupPresent(PlayerGui, TowerData) then
        -- Không thấy popup → coi như wave thắng ngay
        State.towerAlreadyFought[mode] = State.towerAlreadyFought[mode] or {}
        State.towerAlreadyFought[mode][wave] = true
        Utils.notify("Finished", TowerData.ModeNames[mode].." | Wave "..wave.." done!", 2)
        return
    end

    -- Đợi battle kết thúc (popup biến mất giữa các floor)
    local missingTime = 0
    while currentFloor <= endFloor do
        if not State.autoEnabledTower or runId ~= State.autoRunIdTower then return end

        if Utils.isTowerBattlePopupPresent(PlayerGui, TowerData) then
            missingTime = 0  -- popup còn → reset timer
        else
            missingTime += 0.1 -- popup biến mất tạm → tăng timer
        end

        -- Nếu popup biến mất > 1.2s → coi như battle kết thúc floor hiện tại
        if missingTime >= 1.2 then
            currentFloor += 1
            missingTime = 0
        end

        task.wait(0.1)
    end

    -- Mark wave đã đánh xong
    State.towerAlreadyFought[mode] = State.towerAlreadyFought[mode] or {}
    State.towerAlreadyFought[mode][wave] = true
    Utils.notify("Finished", TowerData.ModeNames[mode].." | Wave "..wave.." done!", 2)
end
  ---- Run Auto Battle Tower ----
function TowerController.runAuto()
    State.autoRunIdTower += 1
    local runId = State.autoRunIdTower

    task.spawn(function()
        while State.autoEnabledTower and runId == State.autoRunIdTower do
            local hasWaveToFight = false

            for _, mode in ipairs(TowerData.Modes) do
                if State.selectedTowerModes[mode] then
                    local selectedWaves = State.towerSelectedWaves[mode] or {}
                    for _, wave in ipairs(selectedWaves) do
                        if not (State.towerAlreadyFought[mode] and State.towerAlreadyFought[mode][wave]) then
                            hasWaveToFight = true
                            TowerController.fightWave(mode, wave, runId)
                        end
                        if not State.autoEnabledTower or runId ~= State.autoRunIdTower then break end
                    end
                end
            end

            if not hasWaveToFight then
                Utils.notify("Info", "All selected tower waves are done", 2)
                State.autoEnabledTower = false
                break
            end

            task.wait(2)
        end
    end)
end
----- stop Battle Tower -----
function TowerController.stopAuto()
    State.autoRunIdTower += 1
    State.towerAlreadyFought = {}
end

-------------------------------------------------
-- Infinitie Tower Control (gọn)
-------------------------------------------------
local InfTowerController = {}

-- Internal state để quản lý pause/resume
local InfState = {
    isPaused = false,
}

-- Hàm run auto
function InfTowerController.runAuto()
    if State.autoEnabledInf then return end
    State.autoEnabledInf = true

    task.spawn(function()
        while State.autoEnabledInf do
            if not Utils.isInBattlePopupPresent(PlayerGui) then
                local args = {State.selectedInfMode}
                Net.setPartySlot:FireServer(State.InfinitieTeam)
                pcall(function() Net.fightInfinite:FireServer(unpack(args)) end)
            end
            task.wait(2)
        end
    end)
end

-- Hàm pause Infinite nâng cao
function InfTowerController.pause()
    State.autoEnabledInf = false
    Utils.notify("Inf Tower", "Pausing Infinite Tower...", 2)

    -- Set auto advance timer = 10 để dễ pause
    pcall(function()
    Net.netSetting:FireServer({key="infinite_tower_auto_advance_timer", value=10})
end)

    -- Spam pause trong 45 giây
    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < 45 do
             if not Utils.isInBattlePopupPresent(PlayerGui) then
                 break  -- combat kết thúc → thoát vòng lặp sớm
            end
            pcall(function() Net.pauseInfinite:FireServer() end)
            task.wait(1)
        end
        pcall(function() Net.pauseInfinite:FireServer() end)
        -- Reset auto advance timer = 1
     pcall(function()
    Net.netSetting:FireServer({key="infinite_tower_auto_advance_timer", value=1})
     end)
        Utils.notify("Inf Tower", "Infinite Tower paused successfully", 2)
    end)
end

-- Hàm stop auto hoàn toàn
function InfTowerController.stopAuto()
    State.autoEnabledInf = false
end

-------------------------------------------------
-- Combine Mode Controller
-------------------------------------------------
local CombineModeController = {}
local combineState = {
    running = false,
    priority = {
        BattleTower = false,
        StoryBoss = false,
        GlobalBoss = false,
        InfTower = false
    },
    cooldown = {
        BattleTower = 0,
        StoryBoss = 0
    }
}


-- Hàm convert input "xhxm" sang giây
local function parseTimeInput(input)
    if input == "0" then return 0 end
    local h, m = input:match("(%d+)h(%d+)m")
    if not h then h = input:match("(%d+)h") or 0 end
    if not m then m = input:match("(%d+)m") or 0 end
    return tonumber(h)*3600 + tonumber(m)*60
end

-- Hàm update cooldown
local function updateCooldowns(dt)
    for k,v in pairs(combineState.cooldown) do
        if v > 0 then
            combineState.cooldown[k] = math.max(0, v - dt)
        end
    end
end
-- Hàm hiển thị cooldown mỗi 5 giây
local function displayCooldowns()
    task.spawn(function()
        while combineState.running do
            local btCd = combineState.cooldown.BattleTower
            local sbCd = combineState.cooldown.StoryBoss

            if btCd > 0 then
                print(string.format("Battle Tower cooldown: %dh %dm", math.floor(btCd/3600), math.floor((btCd%3600)/60)))
            else
                print("Battle Tower: Can fight now!")
            end

            if sbCd > 0 then
                print(string.format("Story Boss cooldown: %dh %dm", math.floor(sbCd/3600), math.floor((sbCd%3600)/60)))
            else
                print("Story Boss: Can fight now!")
            end

            task.wait(60)
        end
    end)
end


function CombineModeController.run()
    combineState.running = true
    displayCooldowns()
    task.spawn(function()
        while combineState.running do
            updateCooldowns(1) -- giảm cooldown mỗi giây
            
            -- Battle Tower
            if combineState.priority.BattleTower and State.selectedTowerModes then
                if combineState.cooldown.BattleTower <= 0 then
                    State.autoEnabledTower = true
                    InfTowerController.pause()
                    TowerController.runAuto()
                    repeat task.wait(1) until not State.autoEnabledTower
                    combineState.cooldown.BattleTower = 24*3600
                end
            end

            -- Story Boss
            if combineState.priority.StoryBoss and State.selectedBosses then
                if combineState.cooldown.StoryBoss <= 0 and not State.autoEnabledTower then
                    State.autoEnabledBoss = true
                    InfTowerController.pause()
                    BossController.runAuto()
                    repeat task.wait(1) until not State.autoEnabledBoss
                    combineState.cooldown.StoryBoss = 6*3600
                end
            end

            -- Global Boss
            if combineState.priority.GlobalBoss then
                
                if Utils.isBossSpawnTime() and not State.autoEnabledTower and not State.autoEnabledBoss then
                    InfTowerController.pause()
                    GlobalBossController.runAuto()
                    repeat task.wait(1) until not Utils.isBossSpawnTime()
                    State.autoEnabledGb = false
                end
            end

            -- Infinite Tower
            if combineState.priority.InfTower then
                if not State.autoEnabledInf and not State.autoEnabledTower and not State.autoEnabledBoss and not State.autoEnabledGb then
                    InfTowerController.runAuto()
                end
            end

            task.wait(1)
        end
    end)
end

function CombineModeController.stop()
    combineState.running = false
    State.autoEnabledGb = false
    State.autoEnabledInf = false
    
end

-- Hàm để UI set priority
function CombineModeController.setPriority(mode, value)
    if combineState.priority[mode] ~= nil then
        combineState.priority[mode] = value
    end
end

-- Hàm để UI set cooldown từ input "xhxm"
function CombineModeController.setCooldown(mode, input)
    if combineState.cooldown[mode] ~= nil then
        combineState.cooldown[mode] = parseTimeInput(input)
    end
end

-------------------------------------------------
-- UI
-------------------------------------------------
local Window = Rayfield:CreateWindow({
    Name = "Aqua Hub",
    LoadingTitle = "Anime Card Clash",
    LoadingSubtitle = "by Aquane",
    ConfigurationSaving = { Enabled = true, FolderName = "AccConfig", FileName = "ACC" },
    KeySystem = false
})
-------------------------------------------------
-- Story Boss Tab
-------------------------------------------------
local storyTab = Window:CreateTab("Story Boss", 4483345998)
storyTab:CreateSection("Chọn Boss")

for _, b in ipairs(BossData.List) do
    local label = BossData.Names[b.id] or ("Boss "..b.id)

    -- Toggle chọn boss
    storyTab:CreateToggle({
        Name = label,
        CurrentValue = false,
        Flag = "Boss_"..b.id,
        Callback = function(state)
            State.selectedBosses[b.id] = state
            if Rayfield and type(Rayfield.Notify) == "function" then
                Rayfield:Notify({Title="Boss Select", Content=(state and "✔ " or "✖ ")..label, Duration=1.5})
            end
        end
    })

    -- Input chọn mode (multi-mode)
    storyTab:CreateInput({
        Name = label.." | Modes (ex: normal,medium)",
        PlaceholderText = "normal,medium",
        Flag = "BossModes_"..b.id,
        Callback = function(text)
            local modes = {}
            for mode in string.gmatch(text, "%a+") do
                local validModes = {normal=true, medium=true, hard=true, extreme=true}
                if validModes[mode:lower()] then
                    table.insert(modes, mode:lower())
                end
            end
            State.bossSelectedModes[b.id] = modes
            if Rayfield and type(Rayfield.Notify) == "function" then
                Rayfield:Notify({Title="Boss Modes", Content=label.." → "..table.concat(modes, ","), Duration=2})
            end
        end
    })
end

storyTab:CreateSection("Fight Boss Selected")
storyTab:CreateToggle({
    Name = "Auto Fight",
    CurrentValue = false,
    Flag = "AutoFight",
    Callback = function(state)
        State.autoEnabledBoss = state
        if state then
            BossController.runAuto()
        else
            BossController.stopAuto()
        end
    end
})

-------------------------------------------------
-- Tower Tab
-------------------------------------------------
local towerTab = Window:CreateTab("Tower", 4483345998)
towerTab:CreateSection("Select Tower Modes")

for _, mode in ipairs(TowerData.Modes) do
    local label = TowerData.ModeNames[mode] or mode

    -- Toggle chọn mode để auto đánh
    towerTab:CreateToggle({
        Name = label,
        CurrentValue = false,
        Flag = "TowerMode_"..mode,
        Callback = function(state)
            State.selectedTowerModes[mode] = state
            if Rayfield and type(Rayfield.Notify) == "function" then
                Rayfield:Notify({Title="Tower", Content=(state and "✔ " or "✖ ")..label.." selected", Duration=1.5})
            end
        end
    })

    -- Input chọn waves
    towerTab:CreateInput({
        Name = label.." | Select Waves (ex: 1,2,3)",
        PlaceholderText = "1,2,3",
        Flag = "TowerWaves_"..mode,
        Callback = function(text)
            local waves = {}
            for w in string.gmatch(text, "%d+") do
                table.insert(waves, tonumber(w))
            end
            State.towerSelectedWaves[mode] = waves
            if Rayfield and type(Rayfield.Notify) == "function" then
                Rayfield:Notify({Title="Tower", Content=label.." waves selected: "..table.concat(waves, ","), Duration=1.5})
            end
        end
    })
end

towerTab:CreateSection("Auto Tower")
towerTab:CreateToggle({
    Name = "Auto Fight Tower",
    CurrentValue = false,
    Flag = "AutoTower",
    Callback = function(state)
        State.autoEnabledTower = state
        if state then
            TowerController.runAuto()
        else
            TowerController.stopAuto()
        end
    end
})
-------------------------------------------------
-- Infinite Tower Tab
-------------------------------------------------
local InfiniteTab = Window:CreateTab("Infinite Tower", 4483362458)

local modeOptions = {}
for _, key in ipairs(InfiniteData.Modes) do
    table.insert(modeOptions, InfiniteData.ModeNames[key] or key)
end

InfiniteTab:CreateSection("Infinite Mode")
InfiniteTab:CreateDropdown({
    Name = "Mode",
    Options = modeOptions,
    CurrentOption = {InfiniteData.ModeNames[State.selectedInfMode]},
    Flag = "InfiniteModeDropdown",
    Callback = function(option)
        for k,v in pairs(InfiniteData.ModeNames) do
            if v == option[1] then
                State.selectedInfMode = k
                break
            end
        end
        Utils.notify("Inf Tower", "Mode selected: " .. InfiniteData.ModeNames[State.selectedInfMode], 2)
    end
})

InfiniteTab:CreateToggle({
    Name = "Auto Fight Infinite Tower",
    CurrentValue = false,
    Flag = "InfiniteAutoFight",
    Callback = function(value)
        State.autoEnabledInf = value
        if State.autoEnabledInf then
            print("Auto fight started for mode:", InfiniteData.ModeNames[State.selectedInfMode])
            InfTowerController.runAuto()
        else
            InfTowerController.stopAuto()
        end
    end
})

-------------------------------------------------
-- Global Boss Tab
-------------------------------------------------
local globalBossTab = Window:CreateTab("Global Boss", 4483362458)
globalBossTab:CreateToggle({
    Name = "Auto Global Boss",
    CurrentValue = false,
    Flag = "AutoGlobalBoss",
    Callback = function(value)
        if value then
            GlobalBossController.runAuto()
        else
            GlobalBossController.stopAuto()
        end
    end
})
-------------------------------------------------
-- Team Select Tab
-------------------------------------------------

local teamTab = Window:CreateTab("Team Select", 4483345998)
teamTab:CreateSection("Select Team for Each Boss")
for _, b in ipairs(BossData.List) do
    local label = BossData.Names[b.id] or ("Boss "..b.id)
    teamTab:CreateDropdown({
        Name = label.." | Choose Team",
        Options = BossData.TeamOptions,
        CurrentOption = {State.bossTeams[b.id]},
        Flag = "Team_"..b.id,
        Callback = function(option)
            local selected = option[1] or "slot_1"
            -- ép kiểu về string để tránh lỗi concatenate
            selected = tostring(selected)
            State.bossTeams[b.id] = selected
            Utils.notify("Team Changed", label.." → "..selected, 2)
        end
    })
end

teamTab:CreateSection("Select Team for Each BT")
for _, mode in ipairs(TowerData.Modes) do
    local label = TowerData.ModeNames[mode] or mode
    teamTab:CreateDropdown({
        Name = label.." | Team Slot",
        Options = TowerData.TeamOptions,
        CurrentOption = {State.towerTeams[mode]},
        Flag = "TowerTeam_"..mode,
        Callback = function(option)
            local selected = option[1] or "slot_1"
            -- ép kiểu về string để tránh lỗi concatenate
            selected = tostring(selected)
            State.towerTeams[mode] = selected
            Utils.notify("Team Changed", label.." → "..selected, 2)
        end
    })
end
teamTab:CreateSection("Select Team for Infinite Tower")

teamTab:CreateDropdown({
    Name = "Inf Team Slot",
    Options = InfiniteData.TeamOptions,
    CurrentOption = {State.InfinitieTeam or "slot_1"},
    Flag = "InfiniteTeamDropdown",
    Callback = function(option)
        local selected = option[1] or "slot_1"
        State.InfinitieTeam = tostring(selected)
        print("Đã chọn team slot:", option)
        Utils.notify("INF TOWER", " Set Inf Team: " .. selected, 2)
    end
}) 
 teamTab:CreateSection("Select Team for Global Boss") 

teamTab:CreateDropdown({
    Name = "Team (Boss HP ≥ 75M)",
    Options = GlobalBossData.TeamOptions,
    CurrentOption = {State.globalBossTeamHighHP or "slot_1"},
    Flag = "GbHighHpTeam",
    Callback = function(option)
        local selected = option[1] or "slot_1"
        State.globalBossTeamHighHP = tostring(selected)
        Utils.notify("Global Boss", "Set High HP Team: " .. selected, 2)
    end
})

teamTab:CreateDropdown({
    Name = "Team (Boss HP < 75M)",
    Options = GlobalBossData.TeamOptions,
    CurrentOption = {State.globalBossTeamLowHP or "slot_1"},
    Flag = "GbLowHpTeam",
    Callback = function(option)
        local selected = option[1] or "slot_1"
        State.globalBossTeamLowHP = tostring(selected)
        Utils.notify("Global Boss", "Set Low HP Team: " .. selected, 2)
    end
})

local combineTab = Window:CreateTab("Combine Mode", 4483345998)
-- Input cooldown cho Battle Tower
combineTab:CreateSection("Enter Cooldown StoryBoss and Battle Tower") 
combineTab:CreateInput({
    Name = "Battle Tower Cooldown",
    PlaceholderText = "Default:0",
    Description = "",
    Text = tostring(State.combineInputCooldown.BattleTower),
    Flag = "CombineBTCooldown",
    Callback = function(input)
        State.combineInputCooldown.BattleTower = input
        CombineModeController.setCooldown("BattleTower", input)
    end
})
combineTab:CreateLabel("2h10m = 2h10m until next fight, 0 = can fight now")
combineTab:CreateLabel("Auto set to 24h after fighting ")

-- Input cooldown cho Story Boss
combineTab:CreateInput({
    Name = "Story Boss Cooldown",
    PlaceholderText = "Default:0",
    Description = "2h10m = 2 giờ 10 phút nữa sẽ đánh, 0 = can fight now, will reset after run",
    Text = tostring(State.combineInputCooldown.StoryBoss),
    Flag = "CombineSBCooldown",
    Callback = function(input)
        State.combineInputCooldown.StoryBoss = input
        CombineModeController.setCooldown("StoryBoss", input)
    end
})
combineTab:CreateLabel("2h10m = 2h10m until next fight, 0 = can fight now")
combineTab:CreateLabel("Auto set to 6h after fighting ")


-- Toggle chọn mode ưu tiên
combineTab:CreateSection("Select Mode to add to MultiMode") 

for _, mode in ipairs({"BattleTower", "StoryBoss", "GlobalBoss", "InfTower"}) do
    local m = mode
    combineTab:CreateToggle({
        Name = m,
        CurrentValue = State.combinePriority[m],
        Flag = "Combine"..m,
        Callback = function(value)
            State.combinePriority[m] = value
            CombineModeController.setPriority(m, value)
        end
    })
end
combineTab:CreateSection("Run MultiMode") 
-- Toggle bật/tắt Combine Mode
combineTab:CreateToggle({
    Name = "Run Combine Mode",
    CurrentValue = State.combineRunning,
    Flag = "RunCombineMode",
    Callback = function(value)
        State.combineRunning = value
        if value then
            CombineModeController.run()
        else
            CombineModeController.stop()
        end
    end
})

-- Script Control Tab --
local scriptTab = Window:CreateTab("🔄 Script", 4483345998)
scriptTab:CreateSection("Script Control")

-- Reload Script
scriptTab:CreateButton({
    Name = "Reload Script",
    Callback = function()
        -- Boss reset
        if State then
            State.autoEnabledBoss = false
            State.autoRunIdBoss = State.autoRunIdBoss + 1
            State.alreadyFought = {}
        end
        -- Tower reset
        if State then
            State.autoEnabledTower = false
            State.autoRunIdTower = State.autoRunIdTower + 1
            State.towerAlreadyFought = {}
        end

        -- Destroy UI before reload
        if Rayfield then
            pcall(function() Rayfield:Destroy() end)
        end
        _G.AquaHubLoaded = false

        pcall(function()
            local success, err = pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/aquahub.lua"))()
            end)
            if not success then
                warn("Error loading script:", err)
            end
        end)
    end
})

scriptTab:CreateButton({
    Name = "❌ Destroy Script",
    Callback = function()
        -- Stop Boss auto
        if State then
            State.autoEnabledBoss = false
            State.autoRunIdBoss = State.autoRunIdBoss + 1
            State.alreadyFought = {}
            -- Stop Tower auto
            State.autoEnabledTower = false
            State.autoRunIdTower = State.autoRunIdTower + 1
            State.towerAlreadyFought = {}
        end

        task.wait(0.05)

        -- Destroy UI
        pcall(function() if Window and type(Window.Destroy) == "function" then Window:Destroy() end end)
        pcall(function() if Rayfield and type(Rayfield.Destroy) == "function" then Rayfield:Destroy() end end)

        -- Reset State
        if State then
            State.autoEnabledBoss = false
            State.autoRunIdBoss = 0
            State.selectedBosses = {}
            State.bossTeams = {}
            State.alreadyFought = {}

            State.autoEnabledTower = false
            State.autoRunIdTower = 0
            State.selectedTowerModes = {}
            State.towerTeams = {}
            State.towerSelectedWaves = {}
            State.towerAlreadyFought = {}
        end

        _G.AquaHubLoaded = false
        print("✅ Script destroyed: UI removed and auto stopped.")
    end
})

-- Load config safely
pcall(function()
    Rayfield:LoadConfiguration()
end)


