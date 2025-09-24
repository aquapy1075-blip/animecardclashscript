local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- === Cấu hình webhook ===
local WEBHOOK_URL = "https://discord.com/api/webhooks/1331282303523229716/SJmxqepB1DRd8Yuua5P6Tmc-fMJqcxHsolVaH6BYpwdCdn7BzDPvBad6a8A0otb9T2xn"
local SEND_COOLDOWN = 2 -- giây tối thiểu giữa 2 request tới Discord

-- === Âm thanh cho Inferno Moon ===
local SOUND_ID_INFERNO = "rbxassetid://6144653794" -- Brook - Binks' Sake (One Piece)
local function PlayInfernoSound()
    local sound = Instance.new("Sound")
    sound.SoundId = SOUND_ID_INFERNO
    sound.Volume = 2
    sound.Looped = false
    sound.Parent = workspace
    sound:Play()

    -- Dừng và xóa sau 15s
    task.delay(15, function()
        if sound and sound.IsPlaying then
            sound:Stop()
        end
        if sound then
            sound:Destroy()
        end
    end)
end

-- === Bảng tên & màu moon ===
local moonConfigs = {
    ["wolf moon"]     = { display = "Wolf Moon",    color = 0xCCCCFF },
    ["full moon"]     = { display = "Full Moon",    color = 0xFFFF00 },
    ["snow moon"]     = { display = "Snow Moon",    color = 0x81D4FA },
    ["blood moon"]    = { display = "Blood Moon",   color = 0xFF4444 },
    ["harvest moon"]  = { display = "Harvest Moon", color = 0xFFA500 },
    ["blue moon"]     = { display = "Blue Moon",    color = 0x448AFF },
    ["eclipse moon"]  = { display = "Eclipse Moon", color = 0x6A0DAD },
    ["monarch moon"]  = { display = "Monarch Moon", color = 0xFFD700 },
    ["tsukuyomi"]     = { display = "Tsukuyomi",    color = 0x00BFFF },
    ["inferno moon"]  = { display = "Inferno Moon", color = 0xFF5555 },
}

-- === UI tạo sẵn ===
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

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 34)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(40,40,40)
title.Text = "  🌙 Moon Tracker"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

-- Hide/Show button
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 28, 0, 28)
hideBtn.Position = UDim2.new(1, -34, 0, 3)
hideBtn.Text = "×"
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 20
hideBtn.TextColor3 = Color3.fromRGB(220,220,220)
hideBtn.BackgroundTransparency = 1
hideBtn.Parent = frame

-- Clear log button
local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0, 100, 0, 28)
clearBtn.Position = UDim2.new(0, 8, 1, -36)
clearBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
clearBtn.Text = "Clear Log"
clearBtn.Font = Enum.Font.Gotham
clearBtn.TextSize = 14
clearBtn.TextColor3 = Color3.fromRGB(255,255,255)
clearBtn.Parent = frame
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0,6)

-- Toggle inferno-only
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 200, 0, 28)
toggleBtn.Position = UDim2.new(0, 120, 1, -36)
toggleBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
toggleBtn.Text = "Discord: ALL 🌍"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
toggleBtn.Parent = frame
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,6)

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -12, 1, -80)
logFrame.Position = UDim2.new(0, 6, 0, 40)
logFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 6
logFrame.Parent = frame

local uiList = Instance.new("UIListLayout")
uiList.Parent = logFrame
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0,6)

-- === biến trạng thái ===
local infernoOnly = false
local lastProcessedMoon = nil
local lastSendTime = 0

-- Toggle, Clear handlers
toggleBtn.MouseButton1Click:Connect(function()
    infernoOnly = not infernoOnly
    if infernoOnly then
        toggleBtn.Text = "Discord: INFERNO 🔥"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(120,40,40)
    else
        toggleBtn.Text = "Discord: ALL 🌍"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    end
end)

clearBtn.MouseButton1Click:Connect(function()
    for i, child in ipairs(logFrame:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    logFrame.CanvasSize = UDim2.new(0,0,0,0)
    lastProcessedMoon = nil
end)

hideBtn.MouseButton1Click:Connect(function()
    screenGui.Enabled = not screenGui.Enabled
end)

-- Dragging UI
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- Toggle UI bằng phím H
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.H then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- Hàm thêm log UI
local function AddLog(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 20)
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

-- === Hàm escape UTF-8 để Discord không lỗi font ===
local function escapeUTF8(s)
    if not s then return "" end
    return s:gsub("[\0-\127\194-\244][\128-\191]*", function(c)
        return c
    end)
end

-- Gửi Discord embed chuẩn UTF-8
local function SendDiscord(moonDisplay, colorDec, rawText)
    local now = os.time()
    if now - lastSendTime < SEND_COOLDOWN then
        return
    end
    lastSendTime = now

    local embed = {
        title = "🌙 Moon Cycle Alert",
        description = escapeUTF8(("**%s**\n%s"):format(moonDisplay, rawText or "")),
        color = colorDec or 0xFFFFFF,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = HttpService:JSONEncode({ embeds = { embed } })

    local req = request or http_request or (syn and syn.request)
    if not req then return end

    task.spawn(function()
        pcall(function()
            req({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json; charset=utf-8" },
                Body = payload
            })
        end)
    end)
end

-- Detect moon từ chat
local function detectMoonFromText(text)
    if not text or text == "" then return nil end
    local clean = text:gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = clean:lower()

    for k, v in pairs(moonConfigs) do
        if lower:find(k) then
            return k, v.display or k, v.color
        end
    end

    if lower:find("ended") or lower:find("has ended") then
        return "none", "No Moon", 0x888888
    end

    return nil
end

local channel = nil
pcall(function()
    if TextChatService and TextChatService.TextChannels then
        channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
    end
end)

if channel then
    channel.MessageReceived:Connect(function(msg)
        local raw = (msg.Text or "")
        local key, displayName, colorDec = detectMoonFromText(raw)
        if not key then return end

        if key == lastProcessedMoon then return end
        lastProcessedMoon = key

        local timeStr = os.date("[%H:%M:%S] ")
        AddLog(timeStr .. displayName, Color3.fromRGB(200,200,200))

        if infernoOnly then
            if key == "inferno moon" then
                SendDiscord(displayName, colorDec, raw)
                PlayInfernoSound() -- 🔊 phát nhạc
            end
        else
            SendDiscord(displayName, colorDec, raw)
            if key == "inferno moon" then
                PlayInfernoSound() -- 🔊 phát nhạc
            end
        end
    end)
else
    warn("Không tìm thấy RBXGeneral channel")
end

print("MoonTracker loaded. Toggle UI = H, Toggle Discord mode = nút trong UI")
