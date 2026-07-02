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
    Title = "Aqua Hub", -- window title
    Icon = "door-open", -- lucide icon or "rbxassetid://" or URL. optional
    Author = "by aquane", -- window subtitle. optional
    Folder = "aquahub",
    ToggleKey = Enum.KeyCode.K, -- key to toggle window. optional
    Size = UDim2.fromOffset(580, 460), -- window size
    MinSize = Vector2.new(560, 350), -- minimal window size
    MaxSize = Vector2.new(850, 560),
    Transparent = true,
    Theme = "Dark",
    Resizable = true, -- the ability to rezize window
    SideBarWidth = 200, -- sidebar (tabs) width
    HideSearchBar = true, -- hide search bar
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

local startId = 14018

for i, name in ipairs(petNames) do
    SummonpetId[name] = startId + (i - 1)
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
local ConfigTab = Window:Tab({
			Title = "Config Usage",
			Icon = "solar:folder-with-files-bold",
			IconColor = Purple,
			IconShape = nil,
			Border = true,
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

-- Utility
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
local ConfigManager = Window.ConfigManager
local ConfigName = "default"

local ConfigNameInput = ConfigTab:Input({
    Title = "Config Name",
    Icon = "file-cog",
    Callback = function(value)
        ConfigName = value
    end,
})

ConfigTab:Space()

local AutoLoadToggle = ConfigTab:Toggle({
    Title = "Enable Auto Load to Selected Config",
    Value = false,
	Flag = "autoloadconfig",
    Callback = function(v)
        Window.CurrentConfig:SetAutoLoad(v)
    end
})

ConfigTab:Space()

local AllConfigs = ConfigManager:AllConfigs()
local DefaultValue = table.find(AllConfigs, ConfigName) and ConfigName or nil
for i, v in next, AllConfigs do
    local MyConfig = ConfigManager:CreateConfig(v)

    if MyConfig.AutoLoad then
        print("Auto loading config:", v)
        MyConfig:Load()
        break
    end
end

local AllConfigsDropdown = ConfigTab:Dropdown({
    Title = "All Configs",
    Desc = "Select existing configs",
    Values = AllConfigs,
    Value = DefaultValue,
    Callback = function(value)
        ConfigName = value
        ConfigNameInput:Set(value)

        AutoLoadToggle:Set(ConfigManager:GetConfig(ConfigName).AutoLoad or false)
    end,
})

ConfigTab:Space()

ConfigTab:Button({
    Title = "Save Config",
    Icon = "",
    Justify = "Center",
    Callback = function()
        Window.CurrentConfig = ConfigManager:Config(ConfigName)
        if Window.CurrentConfig:Save() then
            WindUI:Notify({
                Title = "Config Saved",
                Desc = "Config '" .. ConfigName .. "' saved",
                Icon = "check",
            })
        end

        AllConfigsDropdown:Refresh(ConfigManager:AllConfigs())
    end,
})

ConfigTab:Space()

ConfigTab:Button({
    Title = "Load Config",
    Icon = "",
    Justify = "Center",
    Callback = function()
        Window.CurrentConfig = ConfigManager:CreateConfig(ConfigName)
        if Window.CurrentConfig:Load() then
            WindUI:Notify({
                Title = "Config Loaded",
                Desc = "Config '" .. ConfigName .. "' loaded",
                Icon = "refresh-cw",
            })
        end
    end,
})

ConfigTab:Space()

ConfigTab:Button({
    Title = "Print AutoLoad Configs",
    Icon = "",
    Justify = "Center",
    Callback = function()
        print(HttpService:JSONDecode(ConfigManager:GetAutoLoadConfigs()))
    end,
})
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
        return text and text:find("Shiny:%s*%-%-") ~= nil
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

    -- ⭐ SHINY LOGIC
    if IsShiny() then
        if getgenv().Settings.AutoShiny then
            print("Shiny Found -> Catch Ball:", SelectedShinyBall)
            Catch(SelectedShinyBall)
        else
            print("Shiny Found -> Leaving battle")
            LeaveBattle()
        end
        return
    end

    -- 🟦 NORMAL LOGIC
    if getgenv().Settings.AutoLeave then
        LeaveBattle()
        return
    end

    if getgenv().Settings.AutoCatch then
        Catch(SelectedCatchBall)
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
        and rawget(tbl, "petUid")
        and rawget(tbl, "isSelected") ~= nil then

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
    if not key then return end

    Vim:SendKeyEvent(true,key,false,game)
    task.wait(0.05)
    Vim:SendKeyEvent(false,key,false,game)
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
            StartPP[1] = select(1, GetPP(3))
            StartPP[2] = select(1, GetPP(4))
            StartPP[3] = select(1, GetPP(5))
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

            print("ULT READY -> CAST")

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

            local guiIndex = skillNum + 2
            local currentPP = select(1, GetPP(guiIndex))

            if currentPP and StartPP[skillNum] then

                local used = StartPP[skillNum] - currentPP
                local limit = SkillUses[skillNum]

                if limit == 0 or used < limit then
                    PressSkill(skillNum)
                    break
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
local target

for _, m in ipairs(getloadedmodules()) do
    if m.Name == "CaptureFlowV2Module" then
        target = require(m)
        break
    end
end

if target and target.start then
    target.start = function(data, callback)
        if typeof(callback) == "function" then
            task.defer(callback)
        end
        return 0
    end
end
