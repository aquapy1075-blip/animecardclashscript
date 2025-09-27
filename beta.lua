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
    State.bossModes[b.id] = {b.modes[1]}
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

    -- set team
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

    notify("No Response", name.." | "..mode.." no response", 2)
    State.alreadyFought[id][mode] = true
end

function BossController.runAuto()
    State.autoRunId += 1
    local runId = State.autoRunId

    task.spawn(function()
        while State.autoEnabled and runId == State.autoRunId do
            -- build plan
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

-------------------------------------------------
-- Tab: Story Boss
-------------------------------------------------
local storyTab = Window:CreateTab("Story Boss", 4483345998)
storyTab:CreateSection("Select Bosses & Difficulty")

for _, b in ipairs(BossData.List) do
    local label = BossData.Names[b.id] or ("Boss "..b.id)

    -- chọn boss
    storyTab:CreateToggle({
        Name = label,
        CurrentValue = false,
        Flag = "Boss_"..b.id,
        Callback = function(state)
            State.selectedBosses[b.id] = state
        end
    })

    -- chọn độ khó
    storyTab:CreateDropdown({
        Name = label.." | Difficulties",
        Options = b.modes,
        CurrentOption = {b.modes[1]},
        MultiDropdown = true,
        Flag = "Mode_"..b.id,
        Callback = function(options)
            local selected = option[1]
            State.bossModes[b.id] = options
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
-- Tab: Team Setting
-------------------------------------------------
local teamTab = Window:CreateTab("Team Setting", 4483345998)
teamTab:CreateSection("Choose Teams for Bosses")

for _, b in ipairs(BossData.List) do
    local label = BossData.Names[b.id] or ("Boss "..b.id)
    teamTab:CreateDropdown({
        Name = label.." | Choose Team",
        Options = BossData.TeamOptions,
        CurrentOption = {"slot_1"},
        Flag = "Team_"..b.id,
        Callback = function(option)
            local selected = option[1]
            State.bossTeams[b.id] = selected
        end
    })
end

-------------------------------------------------
-- Tab mới: Script Control
-------------------------------------------------
local scriptTab = Window:CreateTab("🔄 Script", 4483345998) 

scriptTab:CreateSection("Script Control")
scriptTab:CreateButton({
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
        loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/refs/heads/main/beta.lua"))()
    end
})
scriptTab:CreateButton({
    Name = "❌ Destroy Script",
    Callback = function()
        -- 1) Stop auto và force các coroutine thoát
        if State then
            State.autoEnabled = false
            State.autoRunId = (State.autoRunId or 0) + 1
            State.alreadyFought = {}
        end

        -- nhẹ để các coroutine kịp check điều kiện và exit
        task.wait(0.05)

        -- 2) Destroy UI an toàn (pcall cho chắc)
        pcall(function()
            if Window and type(Window.Destroy) == "function" then
                Window:Destroy()
            end
        end)
        pcall(function()
            if Rayfield and type(Rayfield.Destroy) == "function" then
                Rayfield:Destroy()
            end
        end)

        -- 3) Reset nội dung State nhưng KHÔNG gán hẳn = nil (tránh lỗi ở coroutine)
        if State then
            State.autoEnabled = false
            State.autoRunId = 0
            State.selectedBosses = {}
            State.bossModes = {}
            State.bossTeams = {}
            State.alreadyFought = {}
        end

        -- 4) Clear flag toàn cục để reload sạch
        pcall(function() getgenv().StoryBossLoaded = false end)

        print("✅ Script destroyed: UI removed and auto stopped.")
    end
})


-------------------------------------------------
-- Load config sau cùng
-------------------------------------------------
Rayfield:LoadConfiguration()

