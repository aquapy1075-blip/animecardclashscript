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
	AutoShinyPrimBall = false,
    AutoShinyKingBall = false,
	AutoShinyNormalBall = false,
    AutoSelectPet = false,
    AutoPressPhim1 = false,
    AutoBoss = false,
	AutoSkill = false,
	AutoUltimate = false,
	AutoRelease = false,
	AutoSummonBoss = false,
	AutoSelectUpgrade = false,
    AutoReplay = false,
}
local ReleasePetName = ""
local SelectedSummonPet = nil
local SelectedUpgrade = 1


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
MainTab:Dropdown({
    Title = "Target Pets",
    Values = PetOptions,
    Multi = true,
    Flag = "TargetPets",
    Callback = function(Options)
        SelectedPets = {}
        for _, petName in ipairs(Options) do
            table.insert(SelectedPets, petName)
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
DungeonTab:Dropdown({
    Title = "Upgrade",
    Values = {
        "Upgrade 1",
        "Upgrade 2",
        "Upgrade 3"
    },
    Multi = false,
    Value = "Upgrade 1",
    Callback = function(v)
        SelectedUpgrade = tonumber(v:match("%d")) or 1
    end
})

DungeonTab:Toggle({
    Title = "Auto Select Upgrade",
    Value = false,
    Callback = function(v)
        getgenv().Settings.AutoSelectUpgrade = v
    end
})

DungeonTab:Toggle({
    Title = "Auto Replay",
    Value = false,
    Callback = function(v)
        getgenv().Settings.AutoReplay = v
    end
})


SkillTab:Toggle({
    Title = "Auto Skill",
    Value = false,
    Callback = function(v)
        getgenv().Settings.AutoSkill = v
    end
})

SkillTab:Dropdown({
    Title = "Priority 1",
    Values = SkillPriority,
    Value = "Skill 1",
    Callback = function(v)
        Priority1 = v
    end
})

SkillTab:Dropdown({
    Title = "Priority 2",
    Values = SkillPriority,
    Value = "Skill 2",
    Callback = function(v)
        Priority2 = v
    end
})

SkillTab:Dropdown({
    Title = "Priority 3",
    Values = SkillPriority,
    Value = "Skill 3",
    Callback = function(v)
        Priority3 = v
    end
})

SkillTab:Input({
    Title = "Skill 1 Uses",
    Placeholder = "0 = infinite",
    Callback = function(v)
        SkillUses[1] = tonumber(v) or 0
    end
})

SkillTab:Input({
    Title = "Skill 2 Uses",
    Placeholder = "0 = infinite",
    Callback = function(v)
        SkillUses[2] = tonumber(v) or 0
    end
})

SkillTab:Input({
    Title = "Skill 3 Uses",
    Placeholder = "0 = infinite",
    Callback = function(v)
        SkillUses[3] = tonumber(v) or 0
    end
})
SkillTab:Toggle({
    Title = "Auto Ultimate",
    Value = false,
    Callback = function(v)
        getgenv().Settings.AutoUltimate = v
    end
})
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
    Title = "Auto Shiny Prim Ball",
    Value = false,
    Flag = "AutoShinyPrimBall",
    Callback = function(Value)
        getgenv().Settings.AutoShinyPrimBall = Value
    end
})
MiscTab:Toggle({
    Title = "Auto Shiny King Ball",
    Value = false,
    Flag = "AutoShinyKingBall",
    Callback = function(Value)
        getgenv().Settings.AutoShinyKingBall = Value
    end
})
MiscTab:Toggle({
    Title = "Auto Shiny Use Normal Ball",
    Value = false,
    Flag = "AutoShinyNormalBall",
    Callback = function(Value)
        getgenv().Settings.AutoShinyNormalBall = Value
    end
})
MiscTab:Input({
    Title = "Release Pet Name",
    Placeholder = "Ex: Pebble",
    Callback = function(text)
        ReleasePetName = text
    end
})
MiscTab:Toggle({
    Title = "Auto Release",
    Value = false,
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
            root.CFrame = hrp.CFrame + Vector3.new(0,3,0)
        end
    end
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


    if IsShiny() then

    if getgenv().Settings.AutoShinyPrimBall then
        print("Shiny Found -> Catch Prim Ball")
        Catch(2000018)

    elseif getgenv().Settings.AutoShinyKingBall then
        print("Shiny Found -> Catch King Ball")
        Catch(2000017)

    elseif getgenv().Settings.AutoShinyNormalBall then
        print("Shiny Found -> Catch Normal Ball")
        Catch(2000016)
    end
else

    if getgenv().Settings.AutoLeave then
        LeaveBattle()

    elseif getgenv().Settings.AutoCatch then
        Catch(2000016)
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


local function GetRandomPetUID()
    local candidates = {}

    for _, petName in ipairs(SelectedPets) do
        local ids = PetIds[petName]

        if ids then
            for _, id in ipairs(ids) do
                local configId = 1000000 + id

                for _, tbl in ipairs(getgc(true)) do
                    if type(tbl) == "table"
                    and rawget(tbl, "configId") == configId
                    and rawget(tbl, "areaId") ~= nil
                    and rawget(tbl, "uid") ~= nil then

                        table.insert(candidates, tbl.uid)
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        return nil
    end

    return candidates[math.random(#candidates)]
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
    while task.wait(3) do

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
local function AutoReleasePet()

    for _, tbl in pairs(getgc(true)) do
        if type(tbl) == "table" then

            local uid = rawget(tbl, "uuid")
            local name = rawget(tbl, "name") or rawget(tbl, "petName")
            local level = rawget(tbl, "level")
            local locked = rawget(tbl, "locked")

            if uid
                and name == ReleasePetName
                and level == 1
                and locked == false
                and not released[uid] then

                released[uid] = true

                print("Release:", name, uid)

                ReplicatedStorage.Remote.Pet.ReqRemovePets:InvokeServer({
                    uid
                })

                task.wait(0.2)
            end
        end
    end
end

task.spawn(function()
    while task.wait(2) do
        if getgenv().Settings.AutoRelease then
            AutoReleasePet()
        end
    end
end)
