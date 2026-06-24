local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
local player = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "Aqua Hub", -- window title
    Icon = "door-open", -- lucide icon or "rbxassetid://" or URL. optional
    Author = "by aquane", -- window subtitle. optional
    Folder = "aquahub",
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
    AutoBoss = false
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
    ["Flying Territory"] = {10020, 9000013},
    ["Thunder Cliff"] = {10021, 9000014},
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
	Tinkog = {84},
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

local MiscTab = Window:Tab({
    Title = "Misc",
    Icon = "settings"
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
        print("Selected Boss:", Boss)
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
local function LeaveBattle()
    ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
        actionType = 8
    })
end

local function IsShiny()
    local success, result = pcall(function()
        local text = player.PlayerGui
            .UIPrefabs
            .BattleCatchPetWindow
            .MainCanvasGroup
            .SpecialRateFrame
            .ShinyInfoFrame
            .ShinyPityText
            .Text
        print(text)
        return text and text:find("%-%-")
    end)

    return success and result
end


catchFrame:GetPropertyChangedSignal("Visible"):Connect(function()

    if not catchFrame.Visible then
        return
    end

    task.wait(0.1)

    if IsShiny() then
		if getgenv().Settings.AutoShinyPrimBall then
           print("Shiny Found -> Catch")
           ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
            sourcePos = 1,
            targetPos = 1,
            actionType = 5,
            itemId = 2000018
        })
	   elseif getgenv().Settings.AutoShinyKingBall then
				print("Shiny Found -> Catch")
           ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
            sourcePos = 1,
            targetPos = 1,
            actionType = 5,
            itemId = 2000017
        })
		elseif getgenv().Settings.AutoShinyNormalBall then
				print("Shiny Found -> Catch")
           ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
            sourcePos = 1,
            targetPos = 1,
            actionType = 5,
            itemId = 2000016
        })
		end
   
    else
        if getgenv().Settings.AutoLeave then
		      print("Not Shiny -> Leave")
              LeaveBattle()
        elseif getgenv().Settings.AutoCatch then
             print("Not Shiny -> Catch")
        ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
        sourcePos = 1,
        targetPos = 1,
        actionType = 5,
        itemId = 2000016
    })

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

    if mainBattle and mainBattle.Enabled then
        return true
    end

    if mainCatchPet and mainCatchPet.Enabled then
        return true
    end

    return false
end

local Vim = game:GetService("VirtualInputManager")

local function PressE()
    Vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    Vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end
local function PressPhim1()
    Vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
    task.wait(0.05)
    Vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
end
local listpet = player.PlayerGui.UIPrefabs.BattlePetWindow.MainCanvasGroup.PetScrollView 
task.spawn(function()
    while task.wait(0.1) do
        if  getgenv().Settings.AutoSelectPet and listpet.Visible and not InBattle() then
                    PressE()
        end
        task.wait(0.1)
        if  getgenv().Settings.AutoPressPhim1 then
                    PressPhim1()
        end
    end
end)


local function TeleportTo(pos)
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid then return end

    -- teleport tới gần mob (dùng pos, KHÔNG dùng target)
    root.CFrame = CFrame.new(pos + Vector3.new(5, 0, 0))

    task.wait(0.1)

    -- đi vòng nhẹ quanh mob
    humanoid:MoveTo(root.Position + Vector3.new(3, 0, 0))
    task.wait(0.3)

    humanoid:MoveTo(root.Position + Vector3.new(-3, 0, 0))
    task.wait(0.3)

    -- tiến vào mob
    humanoid:MoveTo(pos)
end
local function IsSelectedPet(petId)
    for _, petName in pairs(SelectedPets) do
        local ids = PetIds[petName]
        if ids then
            for _, id in ipairs(ids) do
                if id == petId then
                    return true
                end
            end
        end
    end
    return false
end
local function GetNearestPet()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if not root then
        return
    end

    local nearest
    local nearestDistance = math.huge

    local cache = workspace.RuntimeCache.RuntimeCacheServer.CreatureModelCache

    for _, pet in ipairs(cache:GetDescendants()) do

        if pet:IsA("Model") then

            local petId = tonumber(pet.Name:match("_(%d+)$"))

            if petId and IsSelectedPet(petId) then

                local part =
                    pet.PrimaryPart
                    or pet:FindFirstChild("HumanoidRootPart")
                    or pet:FindFirstChildWhichIsA("BasePart")

                if part then

                    local distance =
                        (root.Position - part.Position).Magnitude

                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearest = part
                    end
                end
            end
        end
    end

   if nearest then
   else
    print("No pet found")
end

return nearest
end

task.spawn(function()
    while task.wait(0.5) do

        if not getgenv().Settings.AutoFarm then
            continue
        end
        if getgenv().Settings.AutoBoss then
            continue
        end
        if InBattle() then
            continue
        end

        local target = GetNearestPet()

        if target then
            TeleportTo(target.Position)
			
        else
        end
		task.wait(1.5)
    end
end)


local function GetSelectedPetUID()
    for _, tbl in pairs(getgc(true)) do
        if type(tbl) == "table"
        and rawget(tbl, "petUid")
        and rawget(tbl, "isSelected") == true then
            return tbl.petUid
        end
    end
end

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

        local uid = GetSelectedPetUID()

        if not uid then
            continue
        end

        local bossData = BossIds[SelectedBoss]

        if bossData then
            ReplicatedStorage.Remote.Battle.ReqEnterNpcBattle:FireServer(
                bossData[1],
                bossData[2],
                uid
            )
        end
    end
end)
