-------------------------------------------------
-- Auto Exploration Script
-------------------------------------------------

-- Load config (file đặt cùng thư mục)
pcall(function()
    loadfile("ExplorationConfig.lua")()
end)

-- Nếu config chưa có thì tạo mặc định
if getgenv().AutoExploration == nil then getgenv().AutoExploration = true end
if getgenv().ExplorationCards == nil then getgenv().ExplorationCards = {} end

-------------------------------------------------
-- Data + Services
-------------------------------------------------
local ExplorationData = {
    Modes = {
        "easy", "medium", "hard", "extreme", "nightmare",
        "celestial", "mythical", "transcendent", "eternal", "abyss"
    }
}

local rs = game:GetService("ReplicatedStorage")
local events = rs:WaitForChild("shared/network@eventDefinitions")

-------------------------------------------------
-- Functions
-------------------------------------------------
local function prepareCards(cards)
    if not cards or type(cards) ~= "table" then return nil end
    local prepared = {}
    for _, c in ipairs(cards) do
        if type(c) == "string" and c ~= "" then
            table.insert(prepared, c)
        end
        if #prepared >= 4 then break end
    end
    if #prepared < 3 then return nil end
    return prepared
end

local function claimExploration(mode)
    local args = { mode }
    events:WaitForChild("claimExploration"):FireServer(unpack(args))
   
end

local function startExploration(mode, cards)
    local args = { mode, cards }
    events:WaitForChild("startExploration"):FireServer(unpack(args))
    
end

-------------------------------------------------
-- Auto Loop (60s mặc định)
-------------------------------------------------
task.spawn(function()
    while true do
        if getgenv().AutoExploration then
            for _, mode in ipairs(ExplorationData.Modes) do
                if not getgenv().AutoExploration then break end

                local cards = prepareCards(getgenv().ExplorationCards[mode])
                if cards then
                    pcall(function() claimExploration(mode) end)
                    task.wait(0.7)
                    pcall(function() startExploration(mode, cards) end)
                    task.wait(2)
                end
            end

            -- chờ 60 giây rồi lặp lại
            for i = 1, 60 do
                if not getgenv().AutoExploration then break end
                task.wait(1)
            end
        else
            task.wait(1)
        end
    end
end)
