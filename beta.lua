-------------------------------------------------
-- Services & Net
-------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Load Fluent
pcall(function() if getgenv().Fluent and getgenv().Fluent.Destroy then getgenv().Fluent:Destroy() end end)
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/main/Fluent.lua"))()
getgenv().Fluent = Fluent

local Net = {
    fightStoryBoss = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("fightStoryBoss"),
    setPartySlot = ReplicatedStorage:WaitForChild("shared/network@eventDefinitions"):WaitForChild("setPartySlot"),
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
        {id=308, modes={"medium","hard","extreme"}},
        {id=381, modes={"medium","hard","extreme"}},
        {id=330, modes={"medium","hard","extreme"}},
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

-------------------------------------------------
-- State
-------------------------------------------------
local State = {
    selectedBosses = {},
    bossModes = {},
    bossTeams = {},
    alreadyFought = {},
    autoEnabled = false,
    autoRunId = 0,
}
for _, b in ipairs(BossData.List) do
    State.selectedBosses[b.id] = false
    State.bossModes[b.id] = { b.modes[1] }
    State.bossTeams[b.id] = "slot_1"
end

-------------------------------------------------
-- Utils
-------------------------------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local function notify(title, content, duration)
    Fluent:Notify({ Title = title, Content = content, Duration = duration or 2 })
end

local function isInBattlePopupPresent()
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local ok, txt = pcall(function() return tostring(gui.Text) end)
            if ok and txt then
                txt = txt:lower()
                if txt:find("hide battle") or txt:find("show battle") or txt:find("already in battle") then
                    return true
                end
            end
        end
    end
    return false
end

local function isErrorPopupPresent()
    local keywords = {"on cooldown","need to beat","locked","not unlocked"}
    for _, k in ipairs(keywords) do
        for _, gui in ipairs(PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                local ok, txt = pcall(function() return tostring(gui.Text) end)
                if ok and txt and txt:lower():find(k) then return true end
            end
        end
    end
    return false
end

-------------------------------------------------
-- Boss Controller
-------------------------------------------------
local BossController = {}

function BossController.fightBoss(id, mode, runId)
    if not State.autoEnabled or runId ~= State.autoRunId then return end
    local slot = State.bossTeams[id] or "slot_1"
    pcall(function() Net.setPartySlot:FireServer(slot) end)

    State.alreadyFought[id] = State.alreadyFought[id] or {}
    if State.alreadyFought[id][mode] then return end

    local name = BossData.Names[id] or ("Boss "..id)
    notify("Story Boss", "⚔️ Fighting "..name.." | "..mode.." | "..slot, 2)

    local ok, err = pcall(function() Net.fightStoryBoss:FireServer(id, mode) end)
    if not ok then
        notify("Error", tostring(err), 2)
        return
    end

    task.wait(0.5)
    local elapsed = 0
    while isInBattlePopupPresent() and elapsed < 180 do
        if not State.autoEnabled or runId ~= State.autoRunId then return end
        task.wait(1)
        elapsed += 1
    end
    State.alreadyFought[id][mode] = true

    if isErrorPopupPresent() then
        notify("Cooldown/Error", name.." | "..mode, 3)
        task.wait(3)
    end
end

function BossController.runAuto()
    State.autoRunId += 1
    local runId = State.autoRunId
    task.spawn(function()
        while State.autoEnabled and runId == State.autoRunId do
            local plan = {}
            for _, boss in ipairs(BossData.List) do
                if State.selectedBosses[boss.id] then
                    table.insert(plan, {id=boss.id, modes=State.bossModes[boss.id]})
                end
            end
            if #plan == 0 then
                notify("Info","No bosses selected",2)
                task.wait(2)
            else
                for _, item in ipairs(plan) do
                    for _, mode in ipairs(item.modes) do
                        if not State.autoEnabled or runId ~= State.autoRunId then break end
                        BossController.fightBoss(item.id, mode, runId)
                    end
                end
            end
            State.alreadyFought = {}
            task.wait(2)
        end
    end)
end

function BossController.stopAuto()
    State.autoRunId += 1
    State.alreadyFought = {}
    State.autoEnabled = false
end

-------------------------------------------------
-- UI
-------------------------------------------------
local Window = Fluent:CreateWindow({ Title = "Aqua Hub" })

-- Story Boss Tab
local storyTab = Window:AddTab({ Title = "Story Boss" })
for _, b in ipairs(BossData.List) do
    local bossId = b.id
    local label = BossData.Names[bossId] or ("Boss "..bossId)

    storyTab:AddToggle({
        Title = label,
        Default = State.selectedBosses[bossId],
        Callback = function(state)
            State.selectedBosses[bossId] = state
        end
    })

    storyTab:AddDropdown({
        Title = label.." | Difficulties",
        Options = b.modes,
        Default = State.bossModes[bossId],
        MultiSelect = true,
        Callback = function(options)
            State.bossModes[bossId] = options
        end
    })
end

storyTab:AddToggle({
    Title = "Auto Fight",
    Default = State.autoEnabled,
    Callback = function(state)
        State.autoEnabled = state
        if state then BossController.runAuto() else BossController.stopAuto() end
    end
})

-- Team Setting Tab
local teamTab = Window:AddTab({ Title = "Team Setting" })
for _, b in ipairs(BossData.List) do
    local bossId = b.id
    local label = BossData.Names[bossId] or ("Boss "..bossId)

    teamTab:AddDropdown({
        Title = label.." | Team",
        Options = BossData.TeamOptions,
        Default = { State.bossTeams[bossId] },
        Callback = function(option)
            State.bossTeams[bossId] = option[1] or "slot_1"
            notify("Team Changed", label.." → "..State.bossTeams[bossId],1.5)
        end
    })
end

-- Script Control Tab
local scriptTab = Window:AddTab({ Title = "Script Control" })
scriptTab:AddButton({
    Title = "Reload Script",
    Callback = function()
        State.autoEnabled = false
        State.autoRunId += 1
        State.alreadyFought = {}
        pcall(function() if getgenv().Fluent and getgenv().Fluent.Destroy then getgenv().Fluent:Destroy() end end)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/beta.lua"))()
    end
})
scriptTab:AddButton({
    Title = "Destroy Script",
    Callback = function()
        State.autoEnabled = false
        State.autoRunId += 1
        State.alreadyFought = {}
        pcall(function() if Window.Destroy then Window:Destroy() end end)
        getgenv().Fluent = nil
        print("✅ Script destroyed")
    end
})
