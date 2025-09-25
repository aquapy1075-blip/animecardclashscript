-- MoonTracker – Clean Version
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- === Config from getgenv ===
local WebhookConfig = getgenv().WebhookConfig or {}
local WEBHOOK_URL = WebhookConfig.Url or ""
local MoonFilter = WebhookConfig.MoonFilter or {}

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

-- === ScreenGui & Main Frame ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MoonTrackerUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 360, 0, 320)
frame.Position = UDim2.new(0.65, 0, 0.18, 0)
frame.BackgroundColor3 = Color3.fromRGB(28,28,28)
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
frame.ClipsDescendants = true
frame.Visible = true

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 34)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundColor3 = Color3.fromRGB(40,40,40)
title.Text = "  Moon Tracker"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

-- Hide × button
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 28, 0, 28)
hideBtn.Position = UDim2.new(1, -34, 0, 3)
hideBtn.Text = "×"
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 20
hideBtn.TextColor3 = Color3.fromRGB(220,220,220)
hideBtn.BackgroundTransparency = 1
hideBtn.Parent = frame
hideBtn.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
end)

-- Clear Log button
local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0,100,0,28)
clearBtn.Position = UDim2.new(0,8,1,-36)
clearBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
clearBtn.Text = "Clear Log"
clearBtn.Font = Enum.Font.Gotham
clearBtn.TextSize = 14
clearBtn.TextColor3 = Color3.fromRGB(255,255,255)
clearBtn.Parent = frame
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0,6)

clearBtn.MouseButton1Click:Connect(function()
    for _, child in ipairs(logFrame:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    logFrame.CanvasSize = UDim2.new(0,0,0,0)
end)

-- Log frame
local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -12, 1, -80)
logFrame.Position = UDim2.new(0,6,0,40)
logFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 6
logFrame.Parent = frame
local uiList = Instance.new("UIListLayout")
uiList.Parent = logFrame
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0,6)

-- === Mobile toggle button 🌙 ===
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0,50,0,50)
toggleBtn.Position = UDim2.new(0.5,-25,0,10)
toggleBtn.AnchorPoint = Vector2.new(0.5,0)
toggleBtn.Text = "🌙"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 24
toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
toggleBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
toggleBtn.BackgroundTransparency = 0.2
toggleBtn.BorderSizePixel = 0
toggleBtn.ZIndex = 100
toggleBtn.Parent = playerGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,25)

-- Dragging toggle button
local dragging, dragInput, dragStart, startPos
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = toggleBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

toggleBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        toggleBtn.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

toggleBtn.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
end)

-- === Helpers ===
local lastProcessedMoon = nil
local lastSendTime = 0
local SEND_COOLDOWN = 2

local function cleanText(text)
    if not text then return "" end
    local t = text:gsub("<[^>]+>", "")
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    return t
end

local function AddLog(text,color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-10,0,20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(200,200,200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Parent = logFrame
    task.wait()
    logFrame.CanvasSize = UDim2.new(0,0,0,uiList.AbsoluteContentSize.Y + 8)
    logFrame.CanvasPosition = Vector2.new(0, math.max(0, uiList.AbsoluteContentSize.Y - logFrame.AbsoluteSize.Y))
end

local function SendDiscord(moonDisplay,colorDec,rawText)
    local now = os.time()
    if now - lastSendTime < SEND_COOLDOWN then return end
    lastSendTime = now
    if WEBHOOK_URL == "" then return end
    local payload = HttpService:JSONEncode({
        embeds={{title="Moon Cycle Alert",description=("**%s**\n%s"):format(moonDisplay,rawText or ""),color=colorDec or 0xFFFFFF,timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ")}}
    })
    local req = request or http_request or (syn and syn.request)
    if req then
        task.spawn(function()
            pcall(function()
                req({Url=WEBHOOK_URL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload})
            end)
        end)
    end
end

local function detectMoonFromText(text)
    if not text or text == "" then return nil end
    local clean = cleanText(text):lower()
    for k,v in pairs(moonConfigs) do
        if clean:find(k) then
            return k, v.display or k, v.color
        end
    end
    if clean:find("ended") or clean:find("has ended") then
        return "none","No Moon",0x888888
    end
    return nil
end

-- === Chat connection ===
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
        if key == lastProcessedMoon then return end
        lastProcessedMoon = key
        if MoonFilter[key] then
            AddLog(os.date("[%H:%M:%S] ")..displayName,Color3.fromRGB(200,200,200))
            SendDiscord(displayName,colorDec,cleanText(raw))
        end
    end)
else
    warn("Không tìm thấy RBXGeneral channel")
end

print("MoonTracker loaded. Toggle UI = 🌙 button / H key, Clear log = button, Moon filter = getgenv().WebhookConfig.MoonFilter")
