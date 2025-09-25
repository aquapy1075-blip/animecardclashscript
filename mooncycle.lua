-- === Script ===
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local config = getgenv().WebhookConfig or {}
local WEBHOOK_URL = config.Url or ""
local MONITOR_MOON = config.Moon or "inferno moon"

if WEBHOOK_URL == "" then
    warn("Webhook chưa được cấu hình trong getgenv().WebhookConfig.Url")
end

-- Moon definitions
local moonConfigs = {
    ["full moon"]     = { display = "Full Moon",    color = 0xFFFF00 },
    ["snow moon"]     = { display = "Snow Moon",    color = 0x81D4FA },
    ["blood moon"]    = { display = "Blood Moon",   color = 0xFF4444 },
    ["harvest moon"]  = { display = "Harvest Moon", color = 0xFFA500 },
    ["blue moon"]     = { display = "Blue Moon",    color = 0x448AFF },
    ["eclipse moon"]  = { display = "Eclipse Moon", color = 0x6A0DAD },
    ["monarch moon"]  = { display = "Monarch Moon", color = 0xFFD700 },
    ["tsukuyomi"]     = { display = "Tsukuyomi",    color = 0x00BFFF },
    ["inferno moon"]  = { display = "Inferno Moon", color = 0xFF5555 },
    ["wolf moon"]     = { display = "Wolf Moon",    color = 0xCCCCFF },
}

-- Helper
local function cleanText(text)
    if not text then return "" end
    local t = text:gsub("<[^>]+>", ""):gsub("^%s+",""):gsub("%s+$","")
    return t
end

local function SendDiscordMultiple(moonDisplay, colorDec, rawText)
    local req = request or http_request or (syn and syn.request)
    if not req or WEBHOOK_URL == "" then return end

    local payload = HttpService:JSONEncode({
        embeds = {{
            title = "Moon Cycle Alert",
            description = ("**%s**\n%s"):format(moonDisplay, rawText or ""),
            color = colorDec or 0xFFFFFF,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    })

    task.spawn(function()
        for i = 1, 3 do
            pcall(function()
                req({
                    Url = WEBHOOK_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = payload
                })
            end)
            task.wait(1)
        end
    end)
end

local function detectMoonFromText(text)
    if not text or text == "" then return nil end
    local clean = cleanText(text):lower()
    for k, v in pairs(moonConfigs) do
        if clean:find(k) then
            return k, v.display or k, v.color
        end
    end
    if clean:find("ended") or clean:find("has ended") then
        return "none", "No Moon", 0x888888
    end
    return nil
end

-- Connect chat
local channel = nil
pcall(function()
    if TextChatService and TextChatService.TextChannels then
        channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
    end
end)

if channel then
    channel.MessageReceived:Connect(function(msg)
        local raw = msg.Text or ""
        local key, displayName, colorDec = detectMoonFromText(raw)
        if not key then return end

        -- Chỉ báo Discord nếu đúng moon đã cấu hình
        local keyLower = key:lower():gsub("^%s+",""):gsub("%s+$","")
        local monitorLower = MONITOR_MOON:lower():gsub("^%s+",""):gsub("%s+$","")
        if keyLower == monitorLower then
            SendDiscordMultiple(displayName, colorDec, cleanText(raw))
        end
    end)
else
    warn("Không tìm thấy RBXGeneral channel")
end

print("MoonTracker loaded. Monitoring moon: " .. MONITOR_MOON)
