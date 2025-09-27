-------------------------------------------------
-- Services & net
-------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Net = {
    fightStoryBoss = ReplicatedStorage
        :WaitForChild("shared/network@eventDefinitions")
        :WaitForChild("fightStoryBoss"),
    setPartySlot = ReplicatedStorage
        :WaitForChild("shared/network@eventDefinitions")
        :WaitForChild("setPartySlot"),
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
    Rayfield:Notify({ Title = title, Content = content, Duration = duration or 2 })
end

local function tbl_contains(t, v)
    for _, x in ipairs(t) do if x == v then return true end end
    return false
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

    local ok, err = pcall(function() Net.fightStoryBoss:FireServer(id, mode) end)
    if not ok then
        notify("Error", tostring(err), 2)
        return
    end

    task.wait(0.5)
    -- wait in battle
    local elapsed = 0
    while elapsed < 180 do
        local popup = false
        for _, gui in ipairs(PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                local ok2, txt = pcall(function() return tostring(gui.Text) end)
                if ok2 and txt then
                    txt = txt:lower()
                    if txt:find("hide battle") or txt:find("show battle") or txt:find("already in battle") then
                        popup = true
                        break
                    end
                end
            end
        end
        if not popup then break end
        task.wait(1)
        elapsed += 1
    end
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
    State.autoRunId += 1
    State.alreadyFought = {}
    State.autoEnabled = false
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
-- Tab: Story Boss
-------------------------------------------------
local storyTab = Window:CreateTab("Story Boss", 4483345998)
storyTab:CreateSection("Select Bosses")

for _, b in ipairs(BossData.List) do
    local bossId = b.id
    local label = BossData.Names[bossId] or ("Boss "..bossId)

    -- Toggle chọn boss
    storyTab:CreateToggle({
        Name = label,
        CurrentValue = State.selectedBosses[bossId] or false,
        Flag = "Boss_"..bossId,
        Callback = function(state)
            State.selectedBosses[bossId] = state
        end
    })
end

-- Auto Fight toggle
storyTab:CreateSection("Fight Boss Selected")
storyTab:CreateToggle({
    Name = "Auto Fight",
    CurrentValue = State.autoEnabled or false,
    Flag = "AutoFight",
    Callback = function(state)
        State.autoEnabled = state
        if State.autoEnabled then
            BossController.runAuto()
        else
            BossController.stopAuto()
        end
    end
})

-- Tab Team Setting
local teamTab = Window:CreateTab("Team Setting", 4483345998)
teamTab:CreateSection("Choose Teams for Bosses")
for _, b in ipairs(BossData.List) do
    local bossId = b.id
    local label = BossData.Names[bossId] or ("Boss "..bossId)

    teamTab:CreateDropdown({
        Name = label.." | Choose Team",
        Options = BossData.TeamOptions,
        CurrentOption = State.bossTeams[bossId] or "slot_1",
        Flag = "Team_"..bossId,
        Callback = function(option)
            State.bossTeams[bossId] = option or "slot_1"
        end
    })
end

-- Tab Script Control
local scriptTab = Window:CreateTab("🔄 Script", 4483345998)
scriptTab:CreateSection("Script Control")
scriptTab:CreateButton({
    Name = "Reload Script",
    Callback = function()
        State.autoEnabled = false
        State.autoRunId += 1
        State.alreadyFought = {}
        if Rayfield then pcall(function() Rayfield:Destroy() end) end
        loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/beta.lua"))()
    end
})
scriptTab:CreateButton({
    Name = "❌ Destroy Script",
    Callback = function()
        State.autoEnabled = false
        State.autoRunId += 1
        State.alreadyFought = {}
        task.wait(0.05)
        pcall(function() if Window and type(Window.Destroy)=="function" then Window:Destroy() end end)
        pcall(function() if Rayfield and type(Rayfield.Destroy)=="function" then Rayfield:Destroy() end end)
        State = {}
        getgenv().StoryBossLoaded = false
        print("✅ Script destroyed: UI removed and auto stopped.")
    end
})

Rayfield:LoadConfiguration()
