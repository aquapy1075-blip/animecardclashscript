local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
local player = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "EvoMon",
    Icon = 114289527320220,
    LoadingTitle = "AquaHub",
    LoadingSubtitle = "by Thanh",
    ShowText = "AquaHub",
    Theme = "Ocean",
    ToggleUIKeybind = "K",

    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Evomon",
        FileName = "evomonfile"
    }
})

local catchFrame = player.PlayerGui
    :WaitForChild("UIPrefabs")
    :WaitForChild("BattleCatchPetWindow")
    :WaitForChild("MainCanvasGroup")
    :WaitForChild("SpecialRateFrame")


local MainTab = Window:CreateTab("AutoFarmMob", 4483362458)

getgenv().Settings = {
    AutoFarm = false,
    AutoLeave = false,
    AutoCatch = false,
    AutoShiny = false,
	AutoShinyNormalBall = false,
    AutoSelectPet = false,
    AutoPressPhim1 = false,
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
MainTab:CreateDropdown({
    Name = "Target Pets",
    Options = PetOptions,
    CurrentOption = {},
    MultipleOptions = true,
    Callback = function(Options)
        SelectedPets = Options
        for _, pet in pairs(Options) do
            print("Selected:", pet)
        end
    end
})



MainTab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = false,

    Callback = function(Value)
        getgenv().Settings.AutoFarm = Value
        print("AutoFarm:", Value)
    end
})

MainTab:CreateToggle({
    Name = "Auto Shiny",
    CurrentValue = false,
    Callback = function(Value)
        getgenv().Settings.AutoShiny = Value
    end
})
MainTab:CreateToggle({
    Name = "Auto Shiny Use Normal Ball",
    CurrentValue = false,
    Callback = function(Value)
        getgenv().Settings.AutoShinyNormalBall = Value
    end
})

MainTab:CreateToggle({
    Name = "Auto Leave",
    CurrentValue = false,

    Callback = function(Value)
        getgenv().Settings.AutoLeave = Value
    end
})
MainTab:CreateToggle({
    Name = "Auto Catch",
    CurrentValue = false,
    Callback = function(Value)
        getgenv().Settings.AutoCatch = Value
    end
})
MainTab:CreateToggle({
    Name = "Auto Select Pet",
    CurrentValue = false,   Callback = function(Value)
        getgenv().Settings.AutoSelectPet = Value
    end
})
MainTab:CreateToggle({
    Name = "Auto Press 1",
    CurrentValue = false,   Callback = function(Value)
        getgenv().Settings.AutoPressPhim1 = Value
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
		if getgenv().Settings.AutoShiny then
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
        if  getgenv().Settings.AutoSelectPet and listpet.Visible then
                    PressE()
        end
        task.wait(0.1)
        if  getgenv().Settings.AutoPressPhim1 then
                    PressPhim1()
        end
    end
end)
local function InBattle()
    local mainBattle = player.PlayerGui.UIPrefabs.MainBattleWindow

    if mainBattle and mainBattle.Enabled then
        return true
    end

    if catchFrame.Visible then
        return true
    end

    return false
end

local function TeleportTo(pos)
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")

    if root then
        root.CFrame = CFrame.new(pos)

        task.wait(0.05)

        root.CFrame = root.CFrame + Vector3.new(0.1, 0, 0)
    end
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
    print("Found pet:", nearest.Parent.Name, "Distance:", nearestDistance)
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

        print("AutoFarm Running")

        if InBattle() then
            print("In Battle")
            continue
        end

        local target = GetNearestPet()

        if target then
            print("Teleporting to:", target.Parent.Name)
            TeleportTo(target.Position)
        else
            print("Target nil")
        end
    end
end)
