-------------------------------------------------
-- Services & net
-------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

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

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function notify(title, content, duration)
    Fluent:Notify({ Title = title, Content = content, Duration = duration or 2 })
end

-------------------------------------------------
-- Boss controller
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

    local ok, err = pcall(function()
        Net.fightStoryBoss:FireServer(id, mode)
    end)
    if not ok then
        notify("Error", tostring(err), 2)
        return
    end

    task.wait(0.5)
    State.alreadyFought[id][mode] = true
end

function BossController.runAuto()
    State.autoRunId += 1
    local runId = State.autoRunId

    task.spawn(function()
        while State.autoEnabled and runId == State.autoRunId do
            local plan = {}
            for _, boss in ipairs(BossData.List) do
                if State.selectedBosses[boss.id] then
                    table.insert(plan, { id=boss.id, modes=State.bossModes[boss.id] })
                end
            end

            if #plan == 0 then
                notify("Info", "No bosses selected", 2)
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
    State.autoEnabled = false
    State.autoRunId += 1
    State.alreadyFought = {}
end

-------------------------------------------------
-- UI
-------------------------------------------------
local Window = Fluent:CreateWindow({
    Title = "Aqua Hub | Anime Card Clash",
    SubTitle = "by Aquane",
    Size = UDim2.fromOffset(550, 400),
    Acrylic = true,
    Theme = "Dark"
})

-- Tab Story Boss
local storyTab = Window:AddTab({ Title = "Story Boss", Icon = "rbxassetid://4483345998" })
storyTab:AddSection("Select Bosses & Difficulties")

for _, b in ipairs(BossData.List) do
    local bossId = b.id
    local label = BossData.Names[bossId] or ("Boss "..bossId)

    -- Toggle chọn boss
    storyTab:AddToggle("Boss_"..bossId, {
        Title = label,
        Default = State.selectedBosses[bossId],
        Callback = function(state)
            State.selectedBosses[bossId] = state
        end
    })

    -- Multi-dropdown difficulty
    storyTab:AddDropdown("Mode_"..bossId, {
        Title = label.." | Difficulties",
        Values = b.modes,
        Default = State.bossModes[bossId],
        Multi = true,
        Callback = function(values)
            State.bossModes[bossId] = values
        end
    })
end

storyTab:AddSection("Auto Fight")
storyTab:AddToggle("AutoFight", {
    Title = "Auto Fight",
    Default = State.autoEnabled,
    Callback = function(state)
        State.autoEnabled = state
        if state then BossController.runAuto() else BossController.stopAuto() end
    end
})

-- Tab Team Setting
local teamTab = Window:AddTab({ Title = "Team Setting", Icon = "rbxassetid://4483345998" })
teamTab:AddSection("Choose Teams for Bosses")
for _, b in ipairs(BossData.List) do
    local bossId = b.id
    local label = BossData.Names[bossId] or ("Boss "..bossId)

    teamTab:AddDropdown("Team_"..bossId, {
        Title = label.." | Choose Team",
        Values = BossData.TeamOptions,
        Default = { State.bossTeams[bossId] },
        Multi = false,
        Callback = function(option)
            State.bossTeams[bossId] = option[1] or "slot_1"
            notify("Team Changed", label.." → "..(option[1] or "slot_1"), 1.5)
        end
    })
end

-- Tab Script Control
local scriptTab = Window:AddTab({ Title = "Script", Icon = "rbxassetid://4483345998" })
scriptTab:AddSection("Script Control")

scriptTab:AddButton("ReloadScript", {
    Title = "Reload Script",
    Callback = function()
        State.autoEnabled = false
        State.autoRunId += 1
        State.alreadyFought = {}
        pcall(function() Fluent:Destroy() end)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/beta.lua"))()
    end
})

scriptTab:AddButton("DestroyScript", {
    Title = "❌ Destroy Script",
    Callback = function()
        State.autoEnabled = false
        State.autoRunId += 1
        State.alreadyFought = {}
        task.wait(0.05)
        pcall(function() if Window then Window:Destroy() end end)
        State = {}
        print("✅ Script destroyed: UI removed and auto stopped.")
    end
})
