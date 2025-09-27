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
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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
    local errorKeywords = {"on cooldown", "need to beat", "locked", "not unlocked"}
    for _, k in ipairs(errorKeywords) do if hasPopupContaining(k) then return true end end
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
-- Boss controller
-------------------------------------------------
local BossController = {}

function BossController.fightBoss(id, mode, runId)
    if not State.autoEnabled or runId ~= State.autoRunId then return end

    -- set team for this boss
    Net.setPartySlot:FireServer(State.bossTeams[id] or "slot_1")

    State.alreadyFought[id] = State.alreadyFought[id] or {}
    if State.alreadyFought[id][mode] then return end
    local name = BossData.Names[id] or ("Boss "..id)
    notify("Story Boss", "⚔️ Fighting "..name.." | "..mode, 2)

    local ok, err = pcall(function()
        Net.fightStoryBoss:FireServer(id, mode)
    end)
    if not ok then
        notify("Error", tostring(err), 2)
        return
    end

    task.wait(0.5)

    -- wait if in battle
    if isInBattlePopupPresent() then
        local elapsed = 0
        while isInBattlePopupPresent() and elapsed < 180 do
            if not State.autoEnabled or runId ~= State.autoRunId then return end
            task.wait(1)
            elapsed += 1
        end
        State.alreadyFought[id][mode] = true
        return
    end

    if isErrorPopupPresent() then
        notify("Cooldown", name.." | "..mode.." cooldown/error", 3)
        State.alreadyFought[id][mode] = true
        task.wait(3)
        return
    end

    if isInBattlePopupPresent() then
        local elapsed = 0
        while isInBattlePopupPresent() and elapsed < 40 do
            if not State.autoEnabled or runId ~= State.autoRunId then return end
            task.wait(1)
            elapsed += 1
        end
        if didBattleEndAsWinOrLoss() then
            notify("Finished", name.." | "..mode.." done!", 2)
        else
            notify("Skipped", name.." | "..mode.." skipped", 2)
        end
        State.alreadyFought[id][mode] = true
        return
    end

    notify("No Response", name.." | "..mode.." no response", 2)
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
                    table.insert(plan, { id=boss.id, modes=table.clone(boss.modes) })
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
                    if not State.autoEnabled or runId ~= State.autoRunId then break end
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

    -- choose team
    storyTab:CreateDropdown({
        Name = label.." | Choose Team",
        Options = BossData.TeamOptions,
        CurrentOption = {"slot_1"},
        Flag = "Team_"..b.id,
        Callback = function(option)
            State.bossTeams[b.id] = option
            notify("Team Changed", label.." → "..option, 2)
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

-------------------------------------------------
-- Tab mới: Script Control
-------------------------------------------------
local reloadTab = Window:CreateTab("🔄 Script", 4483345998) 
reloadTab:CreateSection("Script Control")

reloadTab:CreateButton({
    Name = "Reload Script",
    Callback = function()
        -- dừng auto cũ + reset state
        if State then
            State.autoEnabled = false
            State.autoRunId += 1
            State.alreadyFought = {}
        end

        -- hủy UI cũ
        if Rayfield then
            pcall(function() Rayfield:Destroy() end)
        end

        -- tải lại script
        loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/storyboss.lua"))()
    end
})

-------------------------------------------------
-- Load config sau cùng
-------------------------------------------------
Rayfield:LoadConfiguration()

