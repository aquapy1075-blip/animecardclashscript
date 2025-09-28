-------------------------------------------------
-- Services & Net
-------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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
    bossTeams = {},
    alreadyFought = {},
    autoEnabled = false,
    autoRunId = 0,
}

for id in pairs(BossData.Names) do
    State.selectedBosses[id] = false
    State.bossTeams[id] = "slot_1"
end

-------------------------------------------------
-- Utils
-------------------------------------------------
local function notify(title, content, duration)
    Rayfield:Notify({ Title = title, Content = content, Duration = duration or 2 })
end

local function hasPopupContaining(keyword)
    if not keyword or keyword == "" then return false end
    local kw = keyword:lower()
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local ok, txt = pcall(function() return tostring(gui.Text) end)
            if ok and txt and txt ~= "" and string.find(txt:lower(), kw, 1, true) then
                return true
            end
        end
    end
    return false
end

local function isErrorPopupPresent()
    local errorKeywords = {"need to beat", "locked", "not unlocked", "on cooldown"}
    for _, k in ipairs(errorKeywords) do 
        if hasPopupContaining(k) then return true end 
    end
    if hasPopupContaining("error") and not hasPopupContaining("already in battle") then return true end
    return false
end

local function isInBattlePopupPresent()
    return hasPopupContaining("hide battle")
        or hasPopupContaining("show battle")
        or hasPopupContaining("already in battle")
end

local function didBattleEndAsWinOrLoss()
    return hasPopupContaining("victory")
        or hasPopupContaining("defeat")
        or isErrorPopupPresent()
end

-------------------------------------------------
-- Boss Controller
-------------------------------------------------
local BossController = {}

function BossController.fightBoss(id, mode, runId)
    if not State.autoEnabled or runId ~= State.autoRunId then return end

    -- set team cho boss
    Net.setPartySlot:FireServer(State.bossTeams[id] or "slot_1")

    local name = BossData.Names[id] or ("Boss "..id)
    notify("Story Boss", "⚔️ Fighting "..name.." | "..mode, 2)

    local ok, err = pcall(function()
        Net.fightStoryBoss:FireServer(id, mode)
    end)
    if not ok then
        notify("Error", tostring(err), 2)
        State.alreadyFought[id] = State.alreadyFought[id] or {}
        State.alreadyFought[id][mode] = true
        return
    end

    task.wait(0.5)

    -- chờ popup battle xuất hiện
    local battleElapsed = 0
    while not isInBattlePopupPresent() and battleElapsed < 3 do
        if not State.autoEnabled or runId ~= State.autoRunId then return end
        task.wait(1)
        battleElapsed += 1
    end

    -- nếu vẫn không thấy popup, thông báo no response
    if not isInBattlePopupPresent() then
        notify("No Response", name.." | "..mode.." no response", 2)
        State.alreadyFought[id] = State.alreadyFought[id] or {}
        State.alreadyFought[id][mode] = true
        return
    end

    -- đợi battle kết thúc
    local elapsed = 0
    while isInBattlePopupPresent() and elapsed < 180 do
        if not State.autoEnabled or runId ~= State.autoRunId then return end
        task.wait(1)
        elapsed += 1
    end

    -- check kết quả
    if didBattleEndAsWinOrLoss() then
        notify("Finished", name.." | "..mode.." done!", 2)
    elseif isErrorPopupPresent() then
        notify("Cooldown/Error", name.." | "..mode, 3)
    else
        notify("Skipped", name.." | "..mode.." skipped", 2)
    end

    State.alreadyFought[id] = State.alreadyFought[id] or {}
    State.alreadyFought[id][mode] = true
end


function BossController.runAuto()
    State.autoRunId += 1
    local runId = State.autoRunId

    task.spawn(function()
        while State.autoEnabled and runId == State.autoRunId do
            -- build plan from selected bosses
            local plan = {}
                for _, boss in ipairs(BossData.List) do
    if State.selectedBosses[boss.id] then
        local modesToFight = {}
        for _, mode in ipairs(boss.modes) do
            if not (State.alreadyFought[boss.id] and State.alreadyFought[boss.id][mode]) then
                table.insert(modesToFight, mode)
            end
        end
        if #modesToFight > 0 then
            table.insert(plan, {id=boss.id, modes=modesToFight})
        end
    end
end

            if #plan == 0 then
                notify("Info", "All selected bosses are on cooldown or done", 2)
                State.autoEnabled = false
                 break
            else
                for _, item in ipairs(plan) do
                    for _, mode in ipairs(item.modes) do
                        if not State.autoEnabled or runId ~= State.autoRunId then break end
                        BossController.fightBoss(item.id, mode, runId)
                    end
                    if not State.autoEnabled or runId ~= State.autoRunId then break end
                end
            end

              --State.alreadyFought = {}
            task.wait(2)
        end
    end)
end

function BossController.stopAuto()
    State.autoRunId += 1
    State.alreadyFought = {}
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

-- Story Boss Tab
local storyTab = Window:CreateTab("Story Boss", 4483345998)
storyTab:CreateSection("Chọn Boss")

for _, b in ipairs(BossData.List) do
    local label = BossData.Names[b.id] or ("Boss "..b.id)

    -- select boss
    storyTab:CreateToggle({
        Name = label,
        CurrentValue = false,
        Flag = "Boss_"..b.id,
        Callback = function(state)
            State.selectedBosses[b.id] = state
            notify("Boss Select", (state and "✔ " or "✖ ")..label, 1.5)
        end
    })
end

storyTab:CreateSection("Fight Boss Selected")
storyTab:CreateToggle({
    Name = "Auto Fight",
    CurrentValue = false,
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

-- Team Select Tab
local teamTab = Window:CreateTab("Team Select", 4483345998)
teamTab:CreateSection("Select Team for Each Boss")
for _, b in ipairs(BossData.List) do
    local label = BossData.Names[b.id] or ("Boss "..b.id)
    teamTab:CreateDropdown({
        Name = label.." | Choose Team",
        Options = BossData.TeamOptions,
        CurrentOption = {"slot_1"},
        Flag = "Team_"..b.id,
        Callback = function(option)
            local selected = option[1] or "slot_1"
            State.bossTeams[b.id] = selected
            notify("Team Changed", label.." → "..selected, 2)
        end
    })
end

-- Script Control Tab
local scriptTab = Window:CreateTab("🔄 Script", 4483345998)
scriptTab:CreateSection("Script Control")
scriptTab:CreateButton({
    Name = "Reload Script",
    Callback = function()
        if State then
            State.autoEnabled = false
            State.autoRunId += 1
            State.alreadyFought = {}
        end
        if Rayfield then
            pcall(function() Rayfield:Destroy() end)
        end
        loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/storyboss.lua"))()
    end
})
scriptTab:CreateButton({
    Name = "❌ Destroy Script",
    Callback = function()
        if State then
            State.autoEnabled = false
            State.autoRunId += 1
            State.alreadyFought = {}
        end
        task.wait(0.05)
        pcall(function() if Window and type(Window.Destroy) == "function" then Window:Destroy() end end)
        pcall(function() if Rayfield and type(Rayfield.Destroy) == "function" then Rayfield:Destroy() end end)
        if State then
            State.autoEnabled = false
            State.autoRunId = 0
            State.selectedBosses = {}
            State.bossTeams = {}
            State.alreadyFought = {}
        end
        pcall(function() getgenv().StoryBossLoaded = false end)
        print("✅ Script destroyed: UI removed and auto stopped.")
    end
})

-- Load config
Rayfield:LoadConfiguration()
