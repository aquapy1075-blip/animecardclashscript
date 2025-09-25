-- MoonTracker rút gọn – Discord alerts

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- === Cấu hình từ getgenv ===
-- Chỉ cần chỉnh WEBHOOK_URL và MoonName mà bạn muốn theo dõi
getgenv().WebhookConfig = getgenv().WebhookConfig or {}
local WEBHOOK_URL = getgenv().WebhookConfig.Url or ""
local MONITOR_MOON = getgenv().WebhookConfig.Moon or "inferno moon"

if WEBHOOK_URL == "" then
    warn("Webhook chưa được cấu hình trong getgenv().WebhookConfig.Url")
end

-- === Moon definitions ===
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

-- === Hàm loại bỏ tag HTML / Roblox ===
local function cleanText(text)
    if not text then return "" end
    local t = text:gsub("<[^>]+>", "")
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    return t
end

-- === Gửi 3 lần về Discord mỗi lần cách 1 giây ===
local function SendDiscordMultiple(moonDisplay, colorDec, rawText)
    if WEBHOOK_URL == "" then return end
    local req = request or http_request or (syn and syn.request)
    if not req then return end

    task.spawn(function()
        for i = 1, 3 do
            pcall(function()
                local payload = HttpService:JSONEncode({
                    embeds = {{
                        title = "Moon Cycle Alert",
                        description = ("**%s**\n%s"):format(moonDisplay, rawText or ""),
                        color = colorDec or 0xFFFFFF,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                    }}
                })
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

-- === Detect moon từ chat ===
local function detectMoonFromText(text)
    if not text or text == "" then return nil end
    local clean = cleanText(text):lower()
    for k, v in pairs(moonConfigs) do
        if clean:find(k) then
            return k, v.display or k, v.color
        end
    end
    return nil
end

-- === Kết nối với RBXGeneral chat ===
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
        if key == MONITOR_MOON then
            SendDiscordMultiple(displayName, colorDec, cleanText(raw))
        end
    end)
else
    warn("Không tìm thấy RBXGeneral channel")
end

print("MoonTracker loaded. Monitoring moon:", MONITOR_MOON)
