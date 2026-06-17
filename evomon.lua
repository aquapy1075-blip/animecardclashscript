local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local MainTab = Window:CreateTab("AutoFarmMob", 4483362458)

getgenv().Settings = {
    AutoFarm = false,
    AutoLeave = false,
    AutoCatch = false,
    AutoShiny = false,
}

local PetSpawns = {
	Chirpy = {86, 89},
	Mopebun = {17, 21},
    Lavite = {43, 47},
    Datubud = {54, 58},
    Mudbud = {59, 63},
    Stardrift = {71, 75},
    Glaclide = {76, 80},
    Gulpfish = {114, 118},
	Froslet = {119, 123},
	Pummpaw = {132, 135}
}

local SelectedPet = "Mopebun"

MainTab:CreateDropdown({
    Name = "Target Pet",
    Options = {"Mopebun", "Lavite", "Datubud", "Mudbud", "Stardrift", "Glaclide", "Chirpy", "Gulpfish", "Froslet", "Pummpaw" },
    CurrentOption = {SelectedPet},
    MultipleOptions = false,
    Callback = function(Options)
        SelectedPet = typeof(Options) == "table" and Options[1] or Options
        print("Selected Pet:", SelectedPet)
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
        print("AutoShiny:", Value)
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

local catchFrame = player.PlayerGui
    :WaitForChild("UIPrefabs")
    :WaitForChild("BattleCatchPetWindow")
    :WaitForChild("MainCanvasGroup")
    :WaitForChild("SpecialRateFrame")

catchFrame:GetPropertyChangedSignal("Visible"):Connect(function()

    if not catchFrame.Visible then
        return
    end

    task.wait(0.1)

    if IsShiny() and getgenv().Settings.AutoShiny then

        print("Shiny Found -> Catch")

        ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
            sourcePos = 1,
            targetPos = 1,
            actionType = 5,
            itemId = 2000017
        })

    else
        if getgenv().Settings.AutoLeave then

      print("Not Shiny -> Leave")

    ReplicatedStorage.Remote.Battle.ReqOperateBattle:InvokeServer({
        actionType = 8
    })

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

task.spawn(function()

    while task.wait(0.5) do

        if not getgenv().Settings.AutoFarm then
            continue
        end

        local range = PetSpawns[SelectedPet]

        if not range then
            warn("No range found for:", SelectedPet)
            continue
        end

        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if not humanoid then
            continue
        end

        for i = range[1], range[2] do

            if not getgenv().Settings.AutoFarm then
                break
            end

            local spawnPoint = workspace.RefreshPoints.Monster
                :FindFirstChild("MonsterSpawn" .. i)

            if spawnPoint then
                humanoid:MoveTo(spawnPoint.Position)
                 task.wait(1)
            end
        end

        task.wait(0.5)
    end
end)
