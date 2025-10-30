-- ⚔️ GCC Arena Luck Fountain Tracker v5 (Stable: no PATCH)
-- 💠 Refresh theo chu kỳ bằng DELETE + POST (?wait=true)
------------------------------------------------------------
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local WEBHOOK_URL     = getgenv().WebhookURL
local BOT_NAME        = "💠 GCC Arena Bot"
local BOT_AVATAR      = "https://cdn.discordapp.com/icons/1416789228825870428/a_718575158cb8c86bcb4fcf8d6d1e06d5.png"
local EMBED_COLOR     = 0x7A00FF
local EXTEND_COLOR    = 0x00FFCC
local POLL_RETRY      = 1
local REFRESH_SECONDS = getgenv().second  -- chu kỳ refresh countdown (khuyến nghị 30-60s)
------------------------------------------------------------

-- ==== Helpers ====
local function httpReq()
    return (http_request or request or (syn and syn.request) or nil)
end

local function safe(fn)
    local ok, res = pcall(fn)
    if ok then return res end
end

local function parseExpireText(text)
    if not text then return nil end
    local h = tonumber(text:match("(%d+)h")) or 0
    local m = tonumber(text:match("(%d+)m")) or 0
    local s = tonumber(text:match("(%d+)s")) or 0
    local total = h*3600 + m*60 + s
    return { h=h, m=m, s=s, totalSeconds=total, unix=os.time()+total }
end

local function postWebhookAndReturnId(url, payload)
    local req = httpReq()
    if not req then return nil end
    local res = req({
        Url = url .. "?wait=true",  -- bắt buộc để Discord trả body có .id
        Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode(payload)
    })
    if not res or not res.Body then return nil end
    local ok, body = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if ok and body and body.id then return tostring(body.id) end
    return nil
end

local function deleteWebhookMessage(webhookId, webhookToken, messageId)
    local req = httpReq()
    if not req then return false end
    local url = ("https://discord.com/api/webhooks/%s/%s/messages/%s"):format(webhookId, webhookToken, messageId)
    local res = req({ Url=url, Method="DELETE" })
    return res and res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300
end

local function parseWebhookUrl(url)
    if not url then return nil end
    local id, token = url:match("discord.com/api/webhooks/([0-9]+)/([^/%s]+)")
    if id and token then return id, token end
    id, token = url:match("webhooks/([0-9]+)/([^%s]+)")
    return id, token
end

local function formatHMS(seconds)
    if seconds < 0 then seconds = 0 end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02dh %02dm %02ds", h, m, s)
end

local function sendExtendAlert(playerName, plusSeconds)
    local embed = {
        title = "⏫ Luck Fountain Extended!",
        color = EXTEND_COLOR,
        fields = {
            { name = "🍀 " .. playerName, value = string.format("🕒 +%d phút", math.floor(plusSeconds/60)), inline = false }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
    }
    local req = httpReq()
    if req then
        req({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({ username=BOT_NAME, avatar_url=BOT_AVATAR, embeds={embed} })
        })
    end
end

-- ==== MAIN ====
task.spawn(function()
    -- Wait for GUI
    local fountainGui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("react"):WaitForChild("fountain")
    local totalLuckPath = fountainGui.fountain:GetChildren()[4]["3"]["2"]["2"]:GetChildren()[3]["2"]["3"]
    local entitiesParent = fountainGui.fountain:GetChildren()[4]["3"]["3"]["1"]

    while not (totalLuckPath and totalLuckPath.Parent and entitiesParent and entitiesParent.Parent) do
        task.wait(POLL_RETRY)
    end

    local webhookId, webhookToken = parseWebhookUrl(WEBHOOK_URL)
    local messageId = nil

    -- lấy entity đầu tiên có timer (bạn có thể mở rộng multi player sau)
    local targetEntity, targetName, expireUnix, lastTotalSeconds

    for _, entity in ipairs(entitiesParent:GetChildren()) do
        local expireLabel = safe(function() return entity:GetChildren()[7]["3"] end)
        if expireLabel and expireLabel:IsA("TextLabel") then
            local info = parseExpireText(expireLabel.Text)
            if info and info.totalSeconds > 0 then
                targetEntity = entity
                targetName   = safe(function() return entity:GetChildren()[6]["2"].Text end) or entity.Name
                expireUnix   = info.unix
                lastTotalSeconds = info.totalSeconds

                -- gửi đồng hồ lần đầu
                local embed = {
                    title = "⚔️ **GCC Arena — Luck Fountain Countdown**",
                    description = string.format("🍀 Buff active: %s", targetName),
                    color = EMBED_COLOR,
                    fields = {
                        { name="⏳ Expire In: ", value=formatHMS(expireUnix - os.time()), inline=false }
                    },
                    footer = { text="Update every "..REFRESH_SECONDS.."s ", icon_url=BOT_AVATAR },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
                }
                messageId = postWebhookAndReturnId(WEBHOOK_URL, { username=BOT_NAME, avatar_url=BOT_AVATAR, embeds={embed} })
                if not messageId then
                    warn("[Webhook] ❌ POST đầu tiên thất bại (thiếu ?wait=true hoặc executor chặn).")
                else
                    print("[Webhook] ✅ Countdown started for", targetName, "messageId:", messageId)
                end

                -- lắng nghe extend
                expireLabel:GetPropertyChangedSignal("Text"):Connect(function()
                    local newInfo = parseExpireText(expireLabel.Text)
                    if not newInfo then return end
                    local delta = newInfo.totalSeconds - (lastTotalSeconds or 0)
                    if delta > 60 then
                        -- báo extended
                        sendExtendAlert(targetName, delta)
                        -- cập nhật số liệu mới
                        lastTotalSeconds = newInfo.totalSeconds
                        expireUnix = os.time() + newInfo.totalSeconds
                        -- xoá tin cũ và gửi tin mới ngay
                        if messageId then
                            deleteWebhookMessage(webhookId, webhookToken, messageId)
                            messageId = nil
                        end
                        local embedNew = {
                            title = "⚔️ **GCC Arena — Luck Fountain Countdown**",
                            description = string.format("🍀 %s extended ", targetName),
                            color = EMBED_COLOR,
                            fields = {
                                { name="⏳Expire In: ", value=formatHMS(expireUnix - os.time()), inline=false }
                            },
                            footer = { text="Update every "..REFRESH_SECONDS.."s", icon_url=BOT_AVATAR },
                            timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
                        }
                        messageId = postWebhookAndReturnId(WEBHOOK_URL, { username=BOT_NAME, avatar_url=BOT_AVATAR, embeds={embedNew} })
                        print("[Webhook] 🔄 New countdown message after extend. ID:", messageId or "nil")
                    end
                end)

                break
            end
        end
    end

    if not targetEntity then
        warn("[LuckWatcher] ⚠️ Không tìm thấy entity nào có timer.")
        return
    end

    -- Vòng refresh: MỖI REFRESH_SECONDS → DELETE + POST
    while true do
        task.wait(REFRESH_SECONDS)

        local remain = expireUnix - os.time()
        if remain < 0 then remain = 0 end

        local embedUpd = {
            title = "⚔️ **GCC Arena — Luck Fountain Countdown**",
            description = string.format("🍀 Buff active: %s", targetName),
            color = EMBED_COLOR,
            fields = {
                { name="⏳Expire In", value=formatHMS(remain), inline=false }
            },
            footer = { text="Update every "..REFRESH_SECONDS.."s", icon_url=BOT_AVATAR },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
        }

        -- xoá cũ (nếu có), rồi post mới
        if messageId then
            deleteWebhookMessage(webhookId, webhookToken, messageId)
            messageId = nil
        end
        messageId = postWebhookAndReturnId(WEBHOOK_URL, { username=BOT_NAME, avatar_url=BOT_AVATAR, embeds={embedUpd} })
        -- nếu POST không trả id, lần sau vẫn cố gắng post tiếp; không sao cả

        if remain == 0 then
            print("[Webhook] ⏳ Countdown ended.")
            break
        end
    end
end)
