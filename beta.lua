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
    notify("Story Boss", "⚔️ Fighting "..name.." | "..mode.." | "..(slot or "slot_1"), 2)

    local ok, err = pcall(function()
        Net.fightStoryBoss:FireServer(id, mode)
    end)
    if not ok then
        notify("Error", tostring(err), 2)
        return
    end

    task.wait(0.5)

    if isInBattlePopupPresent() then
        local elapsed = 0
        while isInBattlePopupPresent() and elapsed < 180 do
            if not State.autoEnabled or runId ~= State.autoRunId then return end
            task.wait(1)
            elapsed = elapsed + 1
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

    notify("No Response", name.." | "..mode.." no response", 2)
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
-- Tab: Story Boss (boss toggles + per-boss mode toggles hidden)
-------------------------------------------------
local storyTab = Window:CreateTab("Story Boss", 4483345998)
storyTab:CreateSection("Select Bosses & Difficulties")

-- helper nhỏ
local function tbl_contains(t, v)
    if not t then return false end
    for _, x in ipairs(t) do if x == v then return true end end
    return false
end

-- store per-boss mode-toggle objects so we can show/hide and set values
local BossModeUI = {}

for _, b in ipairs(BossData.List) do
    local bossId = b.id
    local label = BossData.Names[bossId] or ("Boss "..bossId)

    -- Toggle chọn boss
    storyTab:CreateToggle({
        Name = label,
        CurrentValue = State.selectedBosses[bossId] or false,
        Flag = "Boss_"..bossId,
        Callback = (function(id)
            return function(state)
                State.selectedBosses[id] = state

                -- show/hide mode widgets (use colon :SetVisible to pass self)
                if BossModeUI[id] then
                    for _, widget in ipairs(BossModeUI[id].widgets) do
                        if type(widget.SetVisible) == "function" then
                            pcall(function() widget:SetVisible(state) end)
                        end
                    end
                end

                -- nếu tắt boss thì clear modes và uncheck toggles (pcall cho an toàn)
                if not state and BossModeUI[id] then
                    State.bossModes[id] = {}
                    for _, tgl in ipairs(BossModeUI[id].toggles) do
                        if type(tgl.Set) == "function" then
                            pcall(function() tgl:Set(false) end)
                        end
                    end
                end
            end
        end)(bossId)
    })

    -- create a small "modes" section header (hidden by default)
    local widgets = {}
    local toggles = {}

    local sec = storyTab:CreateSection("  → "..label.." Modes")
    if sec and type(sec.SetVisible) == "function" then
        pcall(function() sec:SetVisible(State.selectedBosses[bossId] or false) end)
        table.insert(widgets, sec)
    end

    -- create toggles for each mode (hidden by default)
    for _, mode in ipairs(b.modes) do
        local flag = "Mode_"..bossId.."_"..mode -- unique flag
        local cur = tbl_contains(State.bossModes[bossId], mode)
        local tgl = storyTab:CreateToggle({
            Name = "     "..mode,
            CurrentValue = cur,
            Flag = flag,
            Callback = (function(id, md)
                return function(state)
                    State.bossModes[id] = State.bossModes[id] or {}
                    if state then
                        if not tbl_contains(State.bossModes[id], md) then
                            table.insert(State.bossModes[id], md)
                        end
                    else
                        for i, v in ipairs(State.bossModes[id]) do
                            if v == md then table.remove(State.bossModes[id], i); break end
                        end
                    end
                end
            end)(bossId, mode)
        })
        if tgl and type(tgl.SetVisible) == "function" then
            pcall(function() tgl:SetVisible(State.selectedBosses[bossId] or false) end)
            table.insert(widgets, tgl)
        end
        table.insert(toggles, tgl)
    end

    BossModeUI[bossId] = { widgets = widgets, toggles = toggles }
end

-- Auto Fight toggle (kept at bottom)
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



-------------------------------------------------
-- Tab: Team Setting
-------------------------------------------------
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
        Callback = (function(id, lbl) return function(option)
            State.bossTeams[id] = option or "slot_1"
            notify("Team Changed", lbl.." → "..(option or "slot_1"), 1.5)
        end end)(bossId, label)
    })
end

-------------------------------------------------
-- Tab: Script Control
-------------------------------------------------
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
        if Rayfield then pcall(function() Rayfield:Destroy() end) end
        loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/beta.lua"))()
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
        pcall(function() if Window and type(Window.Destroy)=="function" then Window:Destroy() end end)
        pcall(function() if Rayfield and type(Rayfield.Destroy)=="function" then Rayfield:Destroy() end end)
        State = {}
        getgenv().StoryBossLoaded = false
        print("✅ Script destroyed: UI removed and auto stopped.")
    end
})

-------------------------------------------------
-- Load config
-------------------------------------------------
Rayfield:LoadConfiguration()
