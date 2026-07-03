local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- CONFIGURATION
-- ============================================================

local Config = {
    -- Enable auto-battle on battle start
    Enabled = true,
    -- Delay before enabling auto-battle (seconds)
    StartDelay = 1.0,
    -- Auto-battle mode: true = full auto, false = semi-auto
    FullAuto = true,
    -- Also auto-enable for wild encounters
    WildEncounters = true,
    -- Also auto-enable for trainer battles
    TrainerBattles = true,
    -- Also auto-enable for NPC battles
    NpcBattles = true,
    -- Also auto-enable for boss battles
    BossBattles = true,
    -- Also auto-enable for dungeon encounters
    DungeonEncounters = true,
    -- Also auto-enable for PvP (if applicable)
    PvP = false,
    -- Auto-select first available skill when in full auto mode
    AutoSelectSkill = false,
    -- Auto-switch pet when current pet faints
    AutoSwitch = true,
    -- Auto-use catch ball in wild encounters (if available)
    AutoCatch = false,
    -- Delay between auto-actions (seconds)
    ActionDelay = 0.5,
    -- Battle speed multiplier (1=normal, 2=fast, 5=very fast, 10=ultra)
    BattleSpeedMult = 10,
}

local isActive = false
local currentBattleType = nil

-- ============================================================
-- GET REMOTES
-- ============================================================

local Remote = ReplicatedStorage:FindFirstChild("Remote")
if not Remote then
    return
end

local BattleRemote = Remote:FindFirstChild("Battle")
if not BattleRemote then
    return
end

local ReqAutoBattle = BattleRemote:FindFirstChild("ReqAutoBattle")
local ReqOperateBattle = BattleRemote:FindFirstChild("ReqOperateBattle")
local ReqEnterPetBattle = BattleRemote:FindFirstChild("ReqEnterPetBattle")
local ReqEnterNpcBattle = BattleRemote:FindFirstChild("ReqEnterNpcBattle")
local ReqCanEnterBattle = BattleRemote:FindFirstChild("ReqCanEnterBattle")

-- ============================================================
-- GET BINDABLES
-- ============================================================

local Bindable = ReplicatedStorage:FindFirstChild("Bindable")
local BattleBindable = Bindable and Bindable:FindFirstChild("Battle")

local ClientBattleStart = BattleBindable and BattleBindable:FindFirstChild("ClientBattleStart")
local ClientBattleAnimationComplete = BattleBindable and BattleBindable:FindFirstChild("ClientBattleAnimationComplete")

-- ============================================================
-- GET SERVICES
-- ============================================================

local Script = ReplicatedStorage:FindFirstChild("Script")
local BattleScript = Script and Script:FindFirstChild("Battle")
local BattleService = nil

if BattleScript then
    pcall(function()
        BattleService = require(BattleScript:WaitForChild("BattleService", 10))
    end)
end

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

local function isBattleTypeEnabled(battleType)
    if battleType == 1 then  -- PVE_PET (wild encounter)
        return Config.WildEncounters
    elseif battleType == 4 then  -- PVE_NPC (trainer battle)
        return Config.TrainerBattles
    elseif battleType == 3 then  -- PVE_BOSS
        return Config.BossBattles
    elseif battleType == 6 then  -- PVE_DUNGEON
        return Config.DungeonEncounters
    elseif battleType == 5 then  -- PVP
        return Config.PvP
    elseif battleType == 7 then  -- GUIDER
        return true
    elseif battleType == 8 then  -- SUMMON_MONSTER
        return true
    end
    return true
end

local function getBattleType()
    if not BattleService then return nil end
    local battle = BattleService.getCurrentBattle()
    if battle and type(battle) == "table" then
        return battle.type
    end
    return nil
end

local function enableAutoBattle()
    if not ReqAutoBattle then
        return false
    end
    
    local success, result = pcall(function()
        return ReqAutoBattle:InvokeServer(Config.FullAuto)
    end)
    
    if success then
        isActive = true
        return true
    else
        return false
    end
end

local function disableAutoBattle()
    if not ReqAutoBattle then return end
    
    pcall(function()
        ReqAutoBattle:InvokeServer(false)
    end)
    
    isActive = false
    print("[AutoBattle] Auto-battle disabled")
end

-- ============================================================
-- BATTLE MONITOR
-- ============================================================

local function onBattleStart()
    if not Config.Enabled then return end
    
    local battleType = getBattleType()
    currentBattleType = battleType
    
    if not isBattleTypeEnabled(battleType) then
        return
    end
    
    task.delay(Config.StartDelay, function()
        enableAutoBattle()
    end)
end

local function onBattleEnd()
    isActive = false
    currentBattleType = nil
end

-- ============================================================
-- HOOK INTO BATTLE EVENTS
-- ============================================================

if ClientBattleStart then
    ClientBattleStart.Event:Connect(onBattleStart)
end

-- Monitor for battle end via ResSettleBattle
if BattleRemote:FindFirstChild("ResSettleBattle") then
    BattleRemote.ResSettleBattle.OnClientEvent:Connect(function()
        task.wait(0.5)
        onBattleEnd()
    end)
end

-- Also monitor ResEnterBattleFail
if BattleRemote:FindFirstChild("ResEnterBattleFail") then
    BattleRemote.ResEnterBattleFail.OnClientEvent:Connect(function()
        onBattleEnd()
    end)
end

-- ============================================================
-- AUTO-ACTION LOOP (for games that need manual input)
-- ============================================================

task.spawn(function()
    while true do
        task.wait(Config.ActionDelay)
        
        if not isActive or not Config.Enabled then continue end
        
        if not Config.FullAuto and ReqOperateBattle then
            -- Semi-auto mode: need to send actions manually
            -- This is a fallback for when ReqAutoBattle doesn't fully work
            pcall(function()
                -- Send a basic attack action
                local actionData = {
                    actionType = 1,  -- SKILL
                    skillId = 0,     -- First skill
                    targetCampId = 2,  -- Enemy camp
                    targetPos = 1,   -- First enemy position
                }
                ReqOperateBattle:InvokeServer(actionData)
            end)
        end
    end
end)

-- ============================================================
-- TOGGLE FUNCTIONS
-- ============================================================

function ToggleAutoBattle()
    Config.Enabled = not Config.Enabled
    
    if not Config.Enabled and isActive then
        disableAutoBattle()
    end
end

function SetAutoBattleMode(fullAuto)
    Config.FullAuto = fullAuto
    
    if isActive then
        enableAutoBattle()
    end
end

function SetBattleSpeed(delay)
    Config.ActionDelay = delay
end

-- ============================================================
-- BATTLE SPEED HACK (BattleChoreoConst + SkillPerformanceCfg)
-- ============================================================

task.spawn(function()
    -----------------------
    -- Part 1: BattleChoreoConst
    -----------------------
    local ScriptFolder = ReplicatedStorage:FindFirstChild("Script", 15)
    if not ScriptFolder then
        return
    end
    
    local BattleChoreo = ScriptFolder:FindFirstChild("BattleChoreo", 15)
    if not BattleChoreo then
        return
    end
    
    local Basic = BattleChoreo:FindFirstChild("Basic", 15)
    if not Basic then
        return
    end
    
    local ChoreoConstModule = Basic:FindFirstChild("BattleChoreoConst", 15)
    if not ChoreoConstModule then
        return
    end
    
    local success, CC = pcall(require, ChoreoConstModule)
    
    if success and type(CC) == "table" then
        local mult = Config.BattleSpeedMult
        
        -- Scalar wait times
        if type(CC.DefaultActionWaitTime) == "number" then
            CC.DefaultActionWaitTime = CC.DefaultActionWaitTime / mult
        end
        if type(CC.SettleNodeWaitTime) == "number" then
            CC.SettleNodeWaitTime = CC.SettleNodeWaitTime / mult
        end
        if type(CC.StartBattleBeforeChoreographyDelayTime) == "number" then
            CC.StartBattleBeforeChoreographyDelayTime = CC.StartBattleBeforeChoreographyDelayTime / mult
        end
        if type(CC.FirstRoundEmptyActionResultsAnimationCompleteDelay) == "number" then
            CC.FirstRoundEmptyActionResultsAnimationCompleteDelay = 0.05
        end
        if type(CC.ForceSwitchAnimationCompleteDelay) == "number" then
            CC.ForceSwitchAnimationCompleteDelay = 0.05
        end
        if type(CC.OpeningThrowBallPreDelay) == "number" then
            CC.OpeningThrowBallPreDelay = 0.01
        end
        if type(CC.OpeningThrowBallPostDelay) == "number" then
            CC.OpeningThrowBallPostDelay = 0.01
        end
        
        -- Table wait times
        if type(CC.ActionWaitTimeByType) == "table" then
            for k, v in pairs(CC.ActionWaitTimeByType) do
                if type(v) == "number" then
                    CC.ActionWaitTimeByType[k] = v / mult
                end
            end
        end
        if type(CC.SettleNodeWaitTimeByType) == "table" then
            for k, v in pairs(CC.SettleNodeWaitTimeByType) do
                if type(v) == "number" then
                    CC.SettleNodeWaitTimeByType[k] = v / mult
                end
            end
        end
    end
    
    -----------------------
    -- Part 2: SkillPerformanceCfg
    -----------------------
    local Pet = ScriptFolder:FindFirstChild("Pet", 15)
    if not Pet then
        return
    end
    
    local Cfg = Pet:FindFirstChild("Cfg", 15)
    if not Cfg then
        return
    end
    
    local SkillCfgModule = Cfg:FindFirstChild("SkillPerformanceCfg", 15)
    if not SkillCfgModule then
        return
    end
    
    local success2, SC = pcall(require, SkillCfgModule)
    
    if success2 and type(SC) == "table" then
        local mult = Config.BattleSpeedMult
        local count = 0
        
        for skillId, data in pairs(SC) do
            if type(data) == "table" and type(data.finishWaitTime) == "number" then
                data.finishWaitTime = math.max(50, math.floor(data.finishWaitTime / mult))
                count = count + 1
            end
        end
    end
end)
