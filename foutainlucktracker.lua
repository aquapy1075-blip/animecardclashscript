-- ⚔️ GCC Arena Luck Fountain Tracker v6 (stable, accurate extend time)
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
local REFRESH_SECONDS = getgenv().second or 15  -- có thể đặt 5, 10, 15...
------------------------------------------------------------

local function httpReq() return (http_request or request or (syn and syn.request) or nil) end
local function safe(fn) local ok,r=pcall(fn) if ok then return r end end

local function parseExpireText(text)
    if not text then return nil end
    local h = tonumber(text:match("(%d+)h")) or 0
    local m = tonumber(text:match("(%d+)m")) or 0
    local s = tonumber(text:match("(%d+)s")) or 0
    local total = h*3600 + m*60 + s
    return { h=h,m=m,s=s,totalSeconds=total,unix=os.time()+total }
end

local function postWebhookAndReturnId(url, payload)
    local req = httpReq(); if not req then return nil end
    local res = req({ Url=url.."?wait=true", Method="POST",
        Headers={["Content-Type"]="application/json"},
        Body=HttpService:JSONEncode(payload) })
    if not res or not res.Body then return nil end
    local ok,b=pcall(function()return HttpService:JSONDecode(res.Body)end)
    if ok and b and b.id then return tostring(b.id) end
    return nil
end

local function deleteWebhookMessage(id, token, msg)
    local req=httpReq(); if not req then return end
    req({Url=("https://discord.com/api/webhooks/%s/%s/messages/%s"):format(id,token,msg),Method="DELETE"})
end

local function parseWebhookUrl(url)
    if not url then return nil end
    local i,t=url:match("discord.com/api/webhooks/([0-9]+)/([^/%s]+)")
    if i and t then return i,t end
    i,t=url:match("webhooks/([0-9]+)/([^%s]+)")
    return i,t
end

local function formatHMS(sec)
    if sec<0 then sec=0 end
    local h=math.floor(sec/3600)
    local m=math.floor((sec%3600)/60)
    local s=sec%60
    return string.format("%02dh %02dm %02ds",h,m,s)
end

local function sendExtendAlert(playerName, addedMinutes, newExpireUnix)
    local embed={
        title="⏫ Luck Fountain Extended!",
        color=EXTEND_COLOR,
        fields={{
            name="🍀 "..playerName,
            value=string.format("🕒 +%d minutes • expire in %s",
                addedMinutes,
                string.format("<t:%d:R>", newExpireUnix)),
            inline=false}},
        timestamp=os.date("!%Y-%m-%dT%H:%M:%S.000Z")
    }
    local req=httpReq()
    if req then
        req({
            Url=WEBHOOK_URL, Method="POST",
            Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode({username=BOT_NAME,avatar_url=BOT_AVATAR,embeds={embed}})
        })
    end
end

------------------------------------------------------------
task.spawn(function()
    local fountainGui=LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("react"):WaitForChild("fountain")
    local totalLuckPath=fountainGui.fountain:GetChildren()[4]["3"]["2"]["2"]:GetChildren()[3]["2"]["3"]
    local entitiesParent=fountainGui.fountain:GetChildren()[4]["3"]["3"]["1"]

    while not (totalLuckPath and totalLuckPath.Parent and entitiesParent and entitiesParent.Parent) do
        task.wait(POLL_RETRY)
    end

    local webhookId,webhookToken=parseWebhookUrl(WEBHOOK_URL)
    local messageId=nil
    local prevExpireUnix={}

    local function postCountdown(playerName, expireUnix)
        local remain=expireUnix-os.time()
        local embed={
            title="⚔️ **GCC Arena — Luck Fountain Countdown**",
            description=string.format("🍀 Buff active: %s",playerName),
            color=EMBED_COLOR,
            fields={{name="⏳Expire In",value=formatHMS(remain),inline=false}},
            footer={text="Update every "..REFRESH_SECONDS.."s (no PATCH)",icon_url=BOT_AVATAR},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%S.000Z")
        }
        messageId=postWebhookAndReturnId(WEBHOOK_URL,{username=BOT_NAME,avatar_url=BOT_AVATAR,embeds={embed}})
        return messageId
    end

    -- tìm người đầu tiên có timer
    for _,entity in ipairs(entitiesParent:GetChildren()) do
        local expireLabel=safe(function() return entity:GetChildren()[7]["3"] end)
        if expireLabel and expireLabel:IsA("TextLabel") then
            local info=parseExpireText(expireLabel.Text)
            if info then
                local name=safe(function() return entity:GetChildren()[6]["2"].Text end) or entity.Name
                prevExpireUnix[name]=info.unix
                messageId=postCountdown(name,info.unix)
                print("[Webhook] ✅ Countdown start for",name,"msgId:",messageId)

                -- extend listener
                expireLabel:GetPropertyChangedSignal("Text"):Connect(function()
                    local newInfo=parseExpireText(expireLabel.Text)
                    if not newInfo then return end
                    local oldUnix=prevExpireUnix[name] or 0
                    local newUnix=os.time()+newInfo.totalSeconds
                    local deltaSec=newUnix-oldUnix
                    if deltaSec>=55 then
                        local addMin=math.floor((deltaSec+30)/60)
                        sendExtendAlert(name,addMin,newUnix)
                        prevExpireUnix[name]=newUnix
                        if messageId then deleteWebhookMessage(webhookId,webhookToken,messageId) end
                        messageId=postCountdown(name,newUnix)
                        print(string.format("[Webhook] 🔄 %s extended +%dmin, reset countdown",name,addMin))
                    end
                end)

                -- refresh loop
                task.spawn(function()
                    while true do
                        task.wait(REFRESH_SECONDS)
                        local remain=prevExpireUnix[name]-os.time()
                        if remain<0 then remain=0 end
                        if messageId then deleteWebhookMessage(webhookId,webhookToken,messageId) end
                        messageId=postCountdown(name,prevExpireUnix[name])
                        if remain==0 then
                            print("[Webhook] ⏳ Countdown ended for",name)
                            break
                        end
                    end
                end)
                break
            end
        end
    end
end)
