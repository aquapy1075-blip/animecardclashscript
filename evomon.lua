if not game:IsLoaded() then
    game.Loaded:Wait()
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:FindFirstChild("HumanoidRootPart")
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
local BattleRemote = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Battle")
local ReqAutoBattle = BattleRemote:FindFirstChild("ReqAutoBattle")

local BattleBindable = ReplicatedStorage:FindFirstChild("Bindable")
    and ReplicatedStorage.Bindable:FindFirstChild("Battle")

local ClientBattleStart = BattleBindable
    and BattleBindable:FindFirstChild("ClientBattleStart")
local window = player.PlayerGui:WaitForChild("UIPrefabs"):WaitForChild("PVPEnterWindow")
local button = window.MainCanvasGroup:WaitForChild("LeadBtn")

window:GetPropertyChangedSignal("Enabled"):Connect(function()
    if window.Enabled then
        pcall(function()
            firesignal(button.MouseButton1Click)
        end)
    end
end)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "Aqua Hub",
    Icon = "door-open",
    Author = "by aquane",
    Folder = "aquahub",
    ToggleKey = Enum.KeyCode.K,
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 200,
    HideSearchBar = true,
    ScrollBarEnabled = false,
})

local catchFrame = player.PlayerGui
    :WaitForChild("UIPrefabs")
    :WaitForChild("BattleCatchPetWindow")
    :WaitForChild("MainCanvasGroup")
    :WaitForChild("SpecialRateFrame")



getgenv().Settings = {
    AutoFarm = false,
    AutoLeave = false,
    AutoCatch = false,
	AutoShiny = false,
    AutoSelectPet = false,
    AutoPressPhim1 = false,
    AutoBoss = false,
	AutoSkill = false,
	AutoUltimate = false,
	AutoRelease = false,
	AutoSummonBoss = false,
	AutoSelectUpgrade = false,
    AutoReplay = false,
	AutoQuest = false,
	AutoSkipAnimation = false,
	AutoCombat = false,
	SpeedMode = false
}
local ReleasePetName = ""
local SelectedSummonPet = nil
local SelectedUpgrade = 1
local SelectedCatchBall = 2000016 -- default: advanced ball
local SelectedShinyBall = 2000018 -- default: primastic

local SkillPriority = {
    "Skill 1",
    "Skill 2",
    "Skill 3"
}
local Priority1 = "Skill 1"
local Priority2 = "Skill 2"
local Priority3 = "Skill 3"
local SkillUses = {
    [1] = 0,
    [2] = 0,
    [3] = 0
}
local BossIds = {
    ["Verdant Valley"] = {10001, 9000001},
    ["Petal Pond"] = {10002, 9000002},
    ["Lava Crag"] = {10004, 9000003},
    ["Amber Acres"] = {10005, 9000004},
    ["Shiver Snows"] = {10008, 9000005},
    ["Raven Ridge"] = {10009, 9000006},
    ["Silent Sands"] = {10011, 9000007},
    ["Crystal Cascade"] = {10012, 9000008},
    ["Canyon Oasis"] = {10014, 9000009},
    ["Murk Wood"] = {10016, 9000010},
    ["Nether Land"] = {10017, 9000011},
    ["Rocky Ridge"] = {10019, 9000012},
    ["Flying Territory"] = {10020, 9000014},
    ["Thunder Cliff"] = {10021, 9000013},
}
local PetIds = {
    Pebble = {18},
    Budling = {34},
	Mopebun = {16},
	Clampip = {31},
	Sparkit = {21},
	Lavite = {52},
	Datubud = {80},
	Mudbud = {85},
	Stardrift = {54},
	Glaclide = {46},
	Glacone = {47},
	Chirpy = {10}, 
	Chirplume = {11},
	Bluebird = {26},
	Tinkog = {74},
	Humding = {13},
	Flutterby = {14},
	Gulpfish = {24},
	Mirefish = {25},
	Frostlet = {60},
	Frostseer = {61},
	Pummpaw = {78}, 
	Pummash = {79},
	Gempillar = {64},
	Gempress = {65},
	Chitmite = {49},
	Chitgladi = {50},
	Vipip = {37},
	Vipour = {38},
	Tarra = {66},
	Tarragon = {67},
	Starloop = {72},
	Starmuse = {73},
	Wispuff = {82},
	Wispshade = {83},
	Fluffet = {44},
	Fluffastar = {45},
	Spikub = {58},
	Spikumane = {59}
}


local petNames = {
    "Bubblade",
    "Blazmane",
    "Leafblade",
    "Pebgolem",
    "Glacitadel",
    "Mopillow",
    "Chirphantom",
    "Volcrest",
    "Pummash",
    "Tinkor",
    "Twirlby",
    "Viparch",
    "Starmuse",
    "Spikumane",
    "Tarragon",
    "Wispshade",
}

local SummonpetId = {}
local ManualSummonId = {}
local startId = 14018

for i, name in ipairs(petNames) do
    SummonpetId[name] = startId + (i - 1)
end


for i, name in ipairs(petNames) do
    ManualSummonId[name] = 18 + (i - 1)
end
local PetOptions = {}
for petName in pairs(PetIds) do 
	table.insert(PetOptions, petName)
end 
table.sort(PetOptions)

local SelectedPets = {}
local TargetConfigIds = {}
local BossOptions = {}
for bossName in pairs(BossIds) do
    table.insert(BossOptions, bossName)
end
table.sort(BossOptions)

local SelectedBoss = nil


local MainTab = Window:Tab({
    Title = "Mobs",
    Icon = "swords"
})

local BossTab = Window:Tab({
    Title = "Bosses",
    Icon = "skull"
})
local SummonTab = Window:Tab({
    Title = "Summon",
    Icon = "egg"
})
local DungeonTab = Window:Tab({
    Title = "Dungeon",
    Icon = "castle"
})

local SkillTab = Window:Tab({
    Title = "Auto Skill",
    Icon = "zap"
})

local MiscTab = Window:Tab({
    Title = "Misc",
    Icon = "settings"
})
local Utility = Window:Tab({
    Title = "Utility",
    Icon = "list"
})
local Config = Window:Tab({
	Title = "Config",
	Icon = "solar:folder-with-files-bold",
})
-- Main
MainTab:Dropdown({
    Title = "Target Pets",
    Values = PetOptions,
    Multi = true,
    Flag = "TargetPets",
    Callback = function(Options)

        SelectedPets = {}
        TargetConfigIds = {}

        for _, petName in ipairs(Options) do
            table.insert(SelectedPets, petName)

            local ids = PetIds[petName]
            if ids then
                for _, id in ipairs(ids) do
                    TargetConfigIds[1000000 + id] = true
                end
            end

            print("Selected:", petName)
        end
    end
})

MainTab:Toggle({
    Title = "Auto Farm Mons",
    Value = false,
    Flag = "AutoFarmMons",
    Callback = function(Value)
        getgenv().Settings.AutoFarm = Value
        print("AutoFarm:", Value)
    end
})

-- Boss
BossTab:Dropdown({
    Title = "Select Boss",
    Values = BossOptions,
    Multi = false,
    Flag = "SelectBoss",
    Callback = function(Boss)
        SelectedBoss = Boss
    end
})

BossTab:Toggle({
    Title = "Auto Boss",
    Value = false,
    Flag = "AutoBoss",
    Callback = function(Value)
        getgenv().Settings.AutoBoss = Value
    end
})

-- Summon
SummonTab:Dropdown({
    Title = "Select Summon Boss",
    Values = petNames,
    Multi = false,
    Flag = "SelectSummonBoss",
    Callback = function(Boss)
        SelectedSummonPet = Boss
    end
})

SummonTab:Toggle({
    Title = "Auto Summon Boss",
    Value = false,
    Flag = "AutoSummonBoss",
    Callback = function(Value)
        getgenv().Settings.AutoSummonBoss = Value
    end
})

-- Dungeon
DungeonTab:Dropdown({
    Title = "Upgrade",
    Values = {
        "Upgrade 1",
        "Upgrade 2",
        "Upgrade 3"
    },
    Multi = false,
    Value = "Upgrade 1",
    Flag = "DungeonUpgrade",
    Callback = function(v)
        SelectedUpgrade = tonumber(v:match("%d")) or 1
    end
})

DungeonTab:Toggle({
    Title = "Auto Select Upgrade",
    Value = false,
    Flag = "AutoSelectUpgrade",
    Callback = function(v)
        getgenv().Settings.AutoSelectUpgrade = v
    end
})

DungeonTab:Toggle({
    Title = "Auto Replay",
    Value = false,
    Flag = "AutoReplay",
    Callback = function(v)
        getgenv().Settings.AutoReplay = v
    end
})

-- Skill
SkillTab:Toggle({
    Title = "Auto Skill",
    Value = false,
    Flag = "AutoSkill",
    Callback = function(v)
        getgenv().Settings.AutoSkill = v
    end
})

SkillTab:Dropdown({
    Title = "Priority 1",
    Values = SkillPriority,
    Value = "Skill 1",
    Flag = "Priority1",
    Callback = function(v)
        Priority1 = v
    end
})

SkillTab:Dropdown({
    Title = "Priority 2",
    Values = SkillPriority,
    Value = "Skill 2",
    Flag = "Priority2",
    Callback = function(v)
        Priority2 = v
    end
})

SkillTab:Dropdown({
    Title = "Priority 3",
    Values = SkillPriority,
    Value = "Skill 3",
    Flag = "Priority3",
    Callback = function(v)
        Priority3 = v
    end
})

SkillTab:Input({
    Title = "Skill 1 Uses",
    Placeholder = "0 = infinite",
    Flag = "Skill1Uses",
    Callback = function(v)
        SkillUses[1] = tonumber(v) or 0
    end
})

SkillTab:Input({
    Title = "Skill 2 Uses",
    Placeholder = "0 = infinite",
    Flag = "Skill2Uses",
    Callback = function(v)
        SkillUses[2] = tonumber(v) or 0
    end
})

SkillTab:Input({
    Title = "Skill 3 Uses",
    Placeholder = "0 = infinite",
    Flag = "Skill3Uses",
    Callback = function(v)
        SkillUses[3] = tonumber(v) or 0
    end
})

SkillTab:Toggle({
    Title = "Auto Ultimate",
    Value = false,
    Flag = "AutoUltimate",
    Callback = function(v)
        getgenv().Settings.AutoUltimate = v
    end
})

-- Misc
MiscTab:Toggle({
    Title = "Auto Leave",
    Value = false,
    Flag = "AutoLeave",
    Callback = function(Value)
        getgenv().Settings.AutoLeave = Value
    end
})

MiscTab:Toggle({
    Title = "Auto Catch",
    Value = false,
    Flag = "AutoCatch",
    Callback = function(Value)
        getgenv().Settings.AutoCatch = Value
    end
})

MiscTab:Dropdown({
    Title = "Select Catch Ball",
    Values = {
        "Normal Ball",
        "Advanced Ball",
        "King Ball",
        "Primastic Ball"
    },
    Value = "Advanced Ball",
    Flag = "CatchBall",
    Callback = function(v)
        local map = {
            ["Normal Ball"] = 2000015,
            ["Advanced Ball"] = 2000016,
            ["King Ball"] = 2000017,
            ["Primastic Ball"] = 2000018
        }

        SelectedCatchBall = map[v] or 2000016
    end
})

MiscTab:Toggle({
    Title = "Auto Select Pet",
    Value = false,
    Flag = "AutoSelectPet",
    Callback = function(Value)
        getgenv().Settings.AutoSelectPet = Value
    end
})

MiscTab:Toggle({
    Title = "Auto Press 1",
    Value = false,
    Flag = "AutoPressPhim1",
    Callback = function(Value)
        getgenv().Settings.AutoPressPhim1 = Value
    end
})

MiscTab:Toggle({
    Title = "Auto Catch Shiny",
    Value = false,
    Flag = "AutoShiny",
    Callback = function(Value)
        getgenv().Settings.AutoShiny = Value
    end
})

MiscTab:Dropdown({
    Title = "Shiny Catch Ball",
    Values = {
        "Normal Ball",
        "Advanced Ball",
        "King Ball",
        "Primastic Ball"
    },
    Value = "Primastic Ball",
    Flag = "ShinyCatchBall",
    Callback = function(v)
        local map = {
            ["Normal Ball"] = 2000015,
            ["Advanced Ball"] = 2000016,
            ["King Ball"] = 2000017,
            ["Primastic Ball"] = 2000018
        }

        SelectedShinyBall = map[v] or 2000018
    end
})

MiscTab:Input({
    Title = "Release Pet Name",
    Placeholder = "Ex: Pebble",
    Flag = "ReleasePetName",
    Callback = function(text)
        ReleasePetName = text
    end
})

MiscTab:Toggle({
    Title = "Auto Release",
    Value = false,
    Flag = "AutoRelease",
    Callback = function(v)
        getgenv().Settings.AutoRelease = v
    end
})

local function FindNpc22()
    local cache = workspace.RuntimeCache.RuntimeCacheServer.CreatureModelCache

    for _, obj in ipairs(cache:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "Npc22" then
            return obj
        end
    end
end
Utility:Button({
    Title = "Teleport To Travelling Merchant",
    Callback = function()
        local npc = FindNpc22()

        if not npc then
            warn("Npc22 not found")
            return
        end

        local root = game.Players.LocalPlayer.Character
            and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

        local hrp = npc:FindFirstChild("HumanoidRootPart")

        if root and hrp then
            root.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
        end
    end
})

Utility:Toggle({
    Title = "Auto Quest",
    Value = false,
    Flag = "AutoQuest",
    Callback = function(v)
        getgenv().Settings.AutoQuest = v
    end
})
Utility:Toggle({
    Title = "Enable Auto Combat",
    Value = false,
    Flag = "AutoCombat",
    Callback = function(v)
        getgenv().Settings.AutoCombat = v

        if v then
            if InBattle then
                if InBattle() then
                    task.wait(0.3)
                    EnableAutoCombat()
                end
            end
        else
            if ReqAutoBattle then
                pcall(function()
                    ReqAutoBattle:InvokeServer(false)
                end)
                print("Auto Combat disabled")
            end
        end
    end
})
Utility:Toggle({
    Title = "Speed Mode",
    Value = false,
    Flag = "SpeedMode",
    Callback = function(v)
        getgenv().Settings.SpeedMode = v
        print("Speed Mode:", v)
    end
})

local ConfigManager = Window.ConfigManager
local ConfigName = "default"
local Configs = ConfigManager:AllConfigs()

local ConfigDropdown = Config:Dropdown({
    Title = "Select Config",
    Desc = "Select your configuration",
    Values = Configs,
    Value = "",
    Callback = function(option) 
        SelectedConfig = option
    end
})
Config:Button({
    Title = "Overwrite Config",
    Desc = "Overwrite selected config",
    Locked = false,
    Callback = function()
        local MyConfig = ConfigManager:CreateConfig(SelectedConfig)
        MyConfig:Save()
    end
})
Config:Button({
    Title = "Load Config",
    Desc = "Loads selected config",
    Locked = false,
    Callback = function()
        local MyConfig = ConfigManager:CreateConfig(SelectedConfig)
        MyConfig:Load()
    end
})

function ConfigManager:SetExclusiveAutoLoad(targetName)
    local HttpService = game:GetService("HttpService")

    for _, name in ipairs(ConfigManager:AllConfigs()) do
        local path = ConfigManager.Path .. name .. ".json"

        if isfile(path) then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(readfile(path))
            end)

            if ok and type(data) == "table" then
                data.__autoload = (name == targetName)

                writefile(path, HttpService:JSONEncode(data))
            end
        end

        local cfg = ConfigManager.Configs[name]
        if type(cfg) == "table" then
            cfg.AutoLoad = (name == targetName)
        end
    end

    print("Exclusive AutoLoad set:", targetName)
end
Config:Button({
    Title = "Set as Auto Load Config",
    Desc = "Auto loads the selected config next time",
    Locked = false,
    Callback = function()
        ConfigManager:SetExclusiveAutoLoad(SelectedConfig)
end
})
Config:Input({
    Title = "Enter config name",
    Desc = "Enter configuration name",
    Value = "Default",
    InputIcon = "bird",
    Type = "Input", -- or "Textarea"
    Placeholder = "Enter text...",
    Callback = function(input)
        ConfigName = input
    end
})
Config:Button({
    Title = "Save Config",
    Desc = "Saves your settings as config name",
    Locked = false,
    Callback = function()
        local MyConfig = ConfigManager:CreateConfig(ConfigName)
        MyConfig:Save()
        table.insert(Configs, MyConfig)
        ConfigDropdown:Refresh(Configs)
    end
})
for i, v in next, Configs do
    local MyConfig = ConfigManager:CreateConfig(v)
    if MyConfig.AutoLoad then
        MyConfig:Load()
    end
end
local function LeaveBattle()
    ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
        actionType = 8
    })
end


local Vim = game:GetService("VirtualInputManager")

local function PressE()
    Vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    Vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end
local function PressPhim1()
    Vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
    task.wait(0.1)
    Vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
end
local listpet = player.PlayerGui.UIPrefabs.BattlePetWindow.MainCanvasGroup.PetScrollView 
task.spawn(function()
    while task.wait(0.2) do
        if  getgenv().Settings.AutoSelectPet and listpet.Visible and not InBattle() then
                    PressE()
        end
        task.wait(0.2)
        if  getgenv().Settings.AutoPressPhim1 then
                    PressPhim1()
        end
    end
end)


local function IsShiny()
    local success, result = pcall(function()
        local label = player.PlayerGui.UIPrefabs
            .BattleCatchPetWindow
            .MainCanvasGroup
            .SpecialRateFrame
            .ShinyInfoFrame
            .CurBallShinyChanceText

        local text = label.ContentText
        -- Kiểm tra nếu text KHÔNG chứa "2%"
		print(text)
        return text and not text:find("2%%") 
    end)

    return success and result
end

local function Catch(ballId)
    ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
        sourcePos = 1,
        targetPos = 1,
        actionType = 5,
        itemId = ballId
    })
end

catchFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    if not catchFrame.Visible then
        return
    end

    task.wait(0.1)

    -- ⭐ SHINY LOGIC - ƯU TIÊN HÀNG ĐẦU
    if IsShiny() then
        if getgenv().Settings.AutoShiny then
            print("Shiny Found -> Catch Ball:", SelectedShinyBall)
            while catchFrame.Visible do 
                Catch(SelectedShinyBall)
                task.wait(0.25)
            end
        else
            print("Shiny Found -> Leaving battle")
            if getgenv().Settings.AutoLeave then 
                LeaveBattle() 
            end
        end
        return -- THOÁT NGAY, KHÔNG XÉT NORMAL LOGIC
    end

    -- 🟦 NORMAL LOGIC - CHỈ CHẠY KHI KHÔNG PHẢI SHINY
    -- (Vì nếu là shiny đã return ở trên rồi)
    
    if getgenv().Settings.AutoLeave then
        LeaveBattle()
        return
    end

    if getgenv().Settings.AutoCatch then
        while catchFrame.Visible do 
            Catch(SelectedCatchBall)
            task.wait(0.15)
        end
    end
end)
local function InBattle()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return false end

    local ui = pg:FindFirstChild("UIPrefabs")
    if not ui then return false end

    local mainBattle = ui:FindFirstChild("MainBattleWindow")
    local mainCatchPet = ui:FindFirstChild("BattleCatchPetWindow")
    local entercombat = ui.PVPEnterWindow
    if mainBattle and mainBattle.Enabled then
        return true
    end
    if entercombat and entercombat.Enabled then
		return true
	end
    if mainCatchPet and mainCatchPet.Enabled then
        return true
    end

    return false
end

local MobList
local badUIDs = {}

local function IsMob(v)
    return type(v) == "table"
        and rawget(v, "uid") ~= nil
        and rawget(v, "configId") ~= nil
        and rawget(v, "areaId") ~= nil
end

local function FindMobList()
    local bestList
    local bestValid = 0
    local bestTotal = 0

    for _, tbl in ipairs(getgc(true)) do
        if type(tbl) == "table" then
            local total = 0
            local valid = 0

            for _, v in pairs(tbl) do
                total += 1
                if total > 1000 then
                    break
                end

                if IsMob(v)
                and rawget(v, "aliveState") == 1
                and rawget(v, "_isDestroyed") == false then
                    valid += 1
                end
            end

            if total >= 50
            and total <= 1000
            and valid >= 20
            and valid > bestValid then
                bestList = tbl
                bestValid = valid
                bestTotal = total
            end
        end
    end

  if bestList then
    print("MobList found:", bestTotal, "valid:", bestValid)
    return bestList
end
    warn("MobList not found")
    return nil
end
MobList = FindMobList()

local function GetRandomPetUID()
    if not MobList then
        MobList = FindMobList()
        if not MobList then
            return nil
        end
    end

    local candidates = {}

    for _, mob in pairs(MobList) do
        if IsMob(mob) then
            local configId = rawget(mob, "configId")
            local uid = rawget(mob, "uid")
            local aliveState = rawget(mob, "aliveState")

           if TargetConfigIds[configId]
and uid
and aliveState == 1
and rawget(mob, "_isDestroyed") == false
and not badUIDs[uid] then
    candidates[#candidates + 1] = mob
end
        end
    end

    if #candidates == 0 then
        badUIDs = {}
        MobList = FindMobList()
        return nil
    end

    local mob = candidates[math.random(#candidates)]
    return mob.uid
end

task.spawn(function()
    while task.wait(1) do
        if not getgenv().Settings.AutoFarm then
            continue
        end

        if getgenv().Settings.AutoBoss then
            continue
        end

        if InBattle() then
            continue
        end

        local uid = GetRandomPetUID()

        if uid then
            badUIDs[uid] = true
            ReplicatedStorage.Remote.Battle.ReqEnterPetBattle:FireServer(uid)
        end

        task.wait(3)
    end
end)
local function HasSummonMonster()
    local cache = workspace.RuntimeCache.RuntimeCacheServer.CreatureModelCache

    for _, model in pairs(cache:GetChildren()) do
        for _, child in pairs(model:GetChildren()) do
            if child.Name:find("Summon") then
                return true
            end
        end
    end

    return false
end
local function ManualSummon(monsterId)
    return ReplicatedStorage.Remote.SummonMonster.ReqManualSummonMonster:InvokeServer(30, monsterId)
end
task.spawn(function()
    while task.wait(1.5) do
        if not getgenv().Settings.AutoSummonBoss then
            continue
        end

        if not SelectedSummonPet then
            continue
        end

        if HasSummonMonster() then
            continue
        end

        local monsterId = ManualSummonId[SelectedSummonPet]

        if monsterId then
            local ok, result = pcall(function()
                return ManualSummon(monsterId)
            end)

            print("Auto summon:", SelectedSummonPet, monsterId, ok, result)
        end
    end
end)
local function SummonPet(petId)
    local args = {
        petId,
        13000006
    }

    
     ReplicatedStorage.Remote.Battle.ReqEnterNpcBattle:FireServer(unpack(args))
end

task.spawn(function()
    while task.wait(4) do
       if not getgenv().Settings.AutoSummonBoss or not SelectedSummonPet or InBattle() or window.Enabled then
            continue
       end
        local petId = SummonpetId[SelectedSummonPet]
        if not petId then
            warn("Invalid pet selected")
            continue
        end

        SummonPet(petId)
    end
end)


local SelectedPetTable
local SelectedPetUID

local function FindSelectedPet()
    for _, tbl in ipairs(getgc(true)) do
        if type(tbl) == "table"
        and rawget(tbl, "petUid") ~= nil 
        and rawget(tbl, "isSelected") ~= nil 
		and rawget(tbl, "level") ~= nil then

            if tbl.isSelected then
                SelectedPetTable = tbl
                SelectedPetUID = tbl.petUid
                print("Found:", SelectedPetUID)
                return true
            end
        end
    end

    SelectedPetTable = nil
    SelectedPetUID = nil
    return false
end
task.spawn(function()

    while true do
        task.wait(1)

        if not getgenv().Settings.AutoBoss then
            continue
        end

        -- Chưa có pet thì scan
        if not SelectedPetTable then
            FindSelectedPet()
            continue
        end

        -- Nếu pet cũ vẫn đang selected thì không làm gì cả
        if SelectedPetTable.isSelected then
            continue
        end

        -- Pet cũ bị bỏ chọn -> scan lại
        print("Selected changed, rescanning...")
        FindSelectedPet()
    end

end)

task.spawn(function()
    while task.wait(1.5) do

        if not getgenv().Settings.AutoBoss then
            continue
        end

        if InBattle() then
            continue
        end

        if not SelectedBoss then
            continue
        end
        local bossData = BossIds[SelectedBoss]

        if bossData then
            ReplicatedStorage.Remote.Battle.ReqEnterNpcBattle:FireServer(
                10009,
                bossData[2],
                SelectedPetUID
            )
        end
    end
end)

local BuffWindow = player.PlayerGui.UIPrefabs.BuffGainSelectWindow

BuffWindow:GetPropertyChangedSignal("Enabled"):Connect(function()

    if not BuffWindow.Enabled then
        return
    end

    if not getgenv().Settings.AutoSelectUpgrade then
        return
    end

    task.wait(2.75)

    local index = SelectedUpgrade + 2 -- 1->3, 2->4, 3->5
    local btn = BuffWindow:GetChildren()[index]

    if btn then
        firesignal(btn.MouseButton1Click)
        print("Selected Upgrade:", SelectedUpgrade)
    end
end)
local DungeonResultWindow = player.PlayerGui.UIPrefabs.DungeonResultWindow

DungeonResultWindow:GetPropertyChangedSignal("Enabled"):Connect(function()

    if not DungeonResultWindow.Enabled then
        return
    end

    if not getgenv().Settings.AutoReplay then
        return
    end

    task.wait(3)

    local button = DungeonResultWindow.MainCanvasGroup
        .BtnsCanvasGroup
        .ReplayButtonFrame
        .ReplayButton

    firesignal(button.MouseButton1Click)

    print("Replay clicked")
end)

local function GetPP(skillIndex)

    local text = player.PlayerGui.UIPrefabs.MainBattleWindow
        .MainCanvasGroup
        .PetSkillFrame
        .PetNormalSkillScrollView
        :GetChildren()[skillIndex]
        .ItemFrame
        .SkillButton
        .PPFrame
        .SkillPPText
        .ContentText

    local current, max = text:match("(%d+)%s*/%s*(%d+)")

    return tonumber(current), tonumber(max)
end
local function PressSkill(skillNumber)

    local keyMap = {
        [1] = Enum.KeyCode.One,
        [2] = Enum.KeyCode.Two,
        [3] = Enum.KeyCode.Three,
        [4] = Enum.KeyCode.Four
    }

    local key = keyMap[skillNumber]
    if not key then
        warn("[PressSkill] invalid skillNumber:", skillNumber)
        return
    end


    Vim:SendKeyEvent(true, key, false, game)
    task.wait(0.05)
    Vim:SendKeyEvent(false, key, false, game)
end

local function UltimateReady()
    local text = player.PlayerGui.UIPrefabs.MainBattleWindow.MainCanvasGroup.PetSkillFrame.UltimateSkillButton.UltimatePPFrame.UltimateEnergyNeedText.ContentText
    local current, max = text:match("(%d+)%s*/%s*(%d+)")
    current = tonumber(current)
    max = tonumber(max)
    if not current or not max then
        return false
    end
    return current >= max
end

local BattleWindow = player.PlayerGui.UIPrefabs.MainBattleWindow

local StartPP = {}
local LastBattleState = false

local function SkillNameToNumber(name)
    return tonumber(name:match("%d"))
end

local LastUltimateEnergy = 0

task.spawn(function()

    while task.wait(0.3) do

        local battleState = BattleWindow.Enabled

       if battleState and not LastBattleState then
             task.wait(1)
 
         StartPP[1] = select(2, GetPP(3))
         StartPP[2] = select(2, GetPP(4))
         StartPP[3] = select(2, GetPP(5))

end

        LastBattleState = battleState

        if not battleState then
            continue
        end

        if not getgenv().Settings.AutoSkill then
            continue
        end

        if not BattleWindow.Enabled then
            continue
        end

        if getgenv().Settings.AutoUltimate and UltimateReady() then
            for i = 1,20 do
                if not UltimateReady() then
                    break
                end

                PressSkill(4)
                task.wait(0.1)
            end

            continue
        end

        local Priorities = {
            SkillNameToNumber(Priority1),
            SkillNameToNumber(Priority2),
            SkillNameToNumber(Priority3)
        }

for _, skillNum in ipairs(Priorities) do
    if skillNum then        local guiIndex = skillNum + 2
        local currentPP, maxPP = GetPP(guiIndex)

        if currentPP and maxPP then
            if not StartPP[skillNum]
            or StartPP[skillNum] < currentPP
            or StartPP[skillNum] > maxPP then
                StartPP[skillNum] = maxPP
            end

            local used = StartPP[skillNum] - currentPP
            local limit = SkillUses[skillNum] or 0

            

            if currentPP > 0 and (limit == 0 or used < limit) then
                PressSkill(skillNum)
                break
            end
        end
    end
end
    end

end)

local released = {}
local Root

for _, tbl in ipairs(getgc(true)) do
    if type(tbl) == "table" and rawget(tbl, "PetStorage") then
        Root = tbl
        break
    end
end

assert(Root, "Root not found")

local PetList = Root.PetStorage.playerPetData.petList

local function AutoReleasePet()
    for uid in pairs(released) do
        if not PetList[uid] then
            released[uid] = nil
        end
    end

    for uid, pet in pairs(PetList) do
        if not released[uid]
        and pet.level == 1
        and pet.locked == false
        and (pet.name == ReleasePetName or pet.petName == ReleasePetName) then

            released[uid] = true
            ReplicatedStorage.Remote.Pet.ReqRemovePets:InvokeServer({uid})

            task.wait(0.2)
        end
    end
end

task.spawn(function()
    while task.wait(3) do
        if getgenv().Settings.AutoRelease then
            AutoReleasePet()
        end
    end
end)

local function AutoQuest()
    pcall(function()
        game:GetService("ReplicatedStorage")
            .Remote.Task.ReqCompleteTask:InvokeServer(7001101)
		 game:GetService("ReplicatedStorage")
            .Remote.Task.ReqCompleteTask:InvokeServer(7001031)
		  game:GetService("ReplicatedStorage")
            .Remote.Dialogue.ReqReceiveDialogueTask:InvokeServer(200035, 7001031)
          game:GetService("ReplicatedStorage")
            .Remote.Dialogue.ReqReceiveDialogueTask:InvokeServer(200042, 7001101)
		  game:GetService("ReplicatedStorage")
            .Remote.Task.ReqCompleteTask:InvokeServer(8000082)
		  game:GetService("ReplicatedStorage")
            .Remote.Task.ReqCompleteTask:InvokeServer(8000081)
    end)
end

task.spawn(function()
    while task.wait(7) do
        if getgenv().Settings.AutoQuest then
            AutoQuest()
        end
    end
end)

-- ============================================
-- SPEED MODE HOOKS (AN TOÀN)
-- ============================================

local function callLastCallback(...)
    local args = {...}
    for i = #args, 1, -1 do
        if typeof(args[i]) == "function" then
            task.defer(args[i])
            return true
        end
    end
end

local function hook(moduleName, funcName, replace)
    for _, m in ipairs(getloadedmodules()) do
        if m.Name == moduleName then
            local success, mod = pcall(require, m)
            if success and type(mod) == "table" and type(mod[funcName]) == "function" then
                mod[funcName] = replace(mod[funcName])
            end
        end
    end
end

-- Skip enter combat
hook("BattleChoreoStartModule", "executePreEnterBattleEffect", function(old)
    return function(...)
        if getgenv().Settings.SpeedMode then
            callLastCallback(...)
            return 0
        end
        return old(...)
    end
end)

hook("BattleStartWindowController", "playStartAnimation", function(old)
    return function(...)
        if getgenv().Settings.SpeedMode then
            callLastCallback(...)
            return 0
        end
        return old(...)
    end
end)

hook("BattleStartWindowController", "playEndAnimation", function(old)
    return function(...)
        if getgenv().Settings.SpeedMode then
            callLastCallback(...)
            return 0
        end
        return old(...)
    end
end)

-- Skip enemy pet commonAttack lúc vào combat
local AnimationConst
pcall(function()
    AnimationConst = require(ReplicatedStorage.Script.Animation.Basic.AnimationConst)
end)

local CommonAttackState = AnimationConst
    and AnimationConst.AnimationState
    and AnimationConst.AnimationState.commonAttack

for _, m in ipairs(getloadedmodules()) do
    if m.Name == "PetAnimationController" then
        local success, mod = pcall(require, m)
        if success and type(mod) == "table" and type(mod.changeState) == "function" then
            local old = mod.changeState
            mod.changeState = function(uid, state, model, ...)
                if getgenv().Settings.SpeedMode and state == CommonAttackState then
                    return
                end
                return old(uid, state, model, ...)
            end
        end
        break
    end
end

-- Combat skill animation speed
local ctrl
for _, obj in ipairs(getgc(true)) do
    if type(obj) == "table" and type(rawget(obj, "getBattlePlaybackSpeed")) == "function" then
        ctrl = obj
        break
    end
end

if ctrl then
    local oldGetSpeed = ctrl.getBattlePlaybackSpeed
    ctrl.getBattlePlaybackSpeed = function(...)
        if getgenv().Settings.SpeedMode then
            return 50
        end
        return oldGetSpeed(...)
    end
end

-- Skip capture
local target
for _, m in ipairs(getloadedmodules()) do
    if m.Name == "CaptureFlowV2Module" then
        local success, mod = pcall(require, m)
        if success and mod then
            target = mod
            break
        end
    end
end

if target and target.start then
    local oldStart = target.start
    target.start = function(data, callback)
        if getgenv().Settings.SpeedMode then
            if typeof(callback) == "function" then
                task.defer(callback)
            end
            return 0
        end
        return oldStart(data, callback)
    end
end

-- ============================================
-- TEST 1: SKILL PERFORMANCE WAIT (OK)
-- ============================================
local function zeroSkillPerformanceWait()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Script = ReplicatedStorage:FindFirstChild("Script")
    if Script then
        local Pet = Script:FindFirstChild("Pet")
        if Pet then
            local Cfg = Pet:FindFirstChild("Cfg")
            if Cfg then
                local SkillPerformanceCfg = Cfg:FindFirstChild("SkillPerformanceCfg")
                if SkillPerformanceCfg then
                    local success, mod = pcall(require, SkillPerformanceCfg)
                    if success and type(mod) == "table" then
                        for skillId, config in pairs(mod) do
                            if type(config) == "table" and type(config.finishWaitTime) == "number" then
                                config.finishWaitTime = 0
                            end
                        end
                        return true
                    end
                end
            end
        end
    end
    return false
end
zeroSkillPerformanceWait()

-- SKIP CAMERA ZOOM VÀO PET
for _, m in ipairs(getloadedmodules()) do
    if m.Name == "BattleSceneController" then
        local success, mod = pcall(require, m)
        if success and type(mod) == "table" then
            if type(mod.playBattleStartIntroPullBackCamera) == "function" then
                local old = mod.playBattleStartIntroPullBackCamera
                mod.playBattleStartIntroPullBackCamera = function(battleData)
                    if getgenv().Settings.SpeedMode then
                        return 0
                    end
                    return old(battleData)
                end
                print("[+] Hooked: playBattleStartIntroPullBackCamera")
            end
        end
        break
    end
end

-- ============================================
-- TEST 4: BROADCAST (OK)
-- ============================================
for _, m in ipairs(getloadedmodules()) do
    if m.Name == "BattleChoreoStatusUiModule" then
        local success, mod = pcall(require, m)
        if success and type(mod) == "table" then
            if type(mod.executeBroadcastBattleAction) == "function" then
                local old = mod.executeBroadcastBattleAction
                mod.executeBroadcastBattleAction = function(actions, callback)
                    if getgenv().Settings.SpeedMode then
                        if callback then
                            task.defer(callback)
                        end
                        return 0
                    end
                    return old(actions, callback)
                end
            end
        end
        break
    end
end

-- ============================================
-- AUTO COMBAT
-- ============================================
local function EnableAutoCombat()
    if not ReqAutoBattle then
        return
    end
    pcall(function()
        ReqAutoBattle:InvokeServer(true)
    end)
end

if ClientBattleStart then
    ClientBattleStart.Event:Connect(function()
        task.wait(0.5)
        if not getgenv().Settings.AutoCombat then
            return
        end
        EnableAutoCombat()
    end)
end
