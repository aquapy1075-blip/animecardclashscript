-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- === Boss list & names ===
local bossList = {
    {id=308,modes={"medium","hard","extreme"}},
    {id=381,modes={"medium","hard","extreme"}},
    {id=330,modes={"medium","hard","extreme"}},
    {id=355,modes={"normal","medium","hard","extreme"}},
    {id=458,modes={"normal","medium","hard","extreme"}},
    {id=348,modes={"normal","medium","hard","extreme"}},
    {id=322,modes={"normal"}},
    {id=300,modes={"normal"}},
    {id=366,modes={"normal"}},
    {id=343,modes={"normal"}},
}

local bossNames = {
    [308] = "Naruto",
    [381] = "Frieza",
    [330] = "Sukuna",
    [355] = "Titan",
    [458] = "Muzan",
    [348] = "Big Mom",
    [322] = "Sungjinwoo",
    [300] = "Cid",
    [366] = "Celestial Sovereign",
    [343] = "Dead King"
}

local networkEvent = game:GetService("ReplicatedStorage"):WaitForChild("shared/network@eventDefinitions"):WaitForChild("fightStoryBoss")
local alreadyFought = {}

-- === Moon configs ===
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

local lastProcessedMoon = nil
local infernoOnly = false

-- === UI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MoonTrackerUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 380, 0, 360)
frame.Position = UDim2.new(0.6,0,0.15,0)
frame.BackgroundColor3 = Color3.fromRGB(28,28,28)
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,36)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundColor3 = Color3.fromRGB(40,40,40)
title.Text = "  Moon Tracker + Auto Boss"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0,10)

-- Hide/Show
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0,28,0,28)
hideBtn.Position = UDim2.new(1,-34,0,4)
hideBtn.Text = "×"
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 20
hideBtn.TextColor3 = Color3.fromRGB(220,220,220)
hideBtn.BackgroundTransparency = 1
hideBtn.Parent = frame

-- Log frame
local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1,-12,0,180)
logFrame.Position = UDim2.new(0,6,0,42)
logFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 6
logFrame.Parent = frame

local uiList = Instance.new("UIListLayout")
uiList.Parent = logFrame
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0,6)

-- Clear Log button
local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0,100,0,28)
clearBtn.Position = UDim2.new(0,10,0,230)
clearBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
clearBtn.Text = "Clear Log"
clearBtn.Font = Enum.Font.Gotham
clearBtn.TextSize = 14
clearBtn.TextColor3 = Color3.fromRGB(255,255,255)
clearBtn.Parent = frame
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0,6)

-- Inferno Only toggle
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0,160,0,28)
toggleBtn.Position = UDim2.new(0,120,0,230)
toggleBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
toggleBtn.Text = "Discord: ALL"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
toggleBtn.Parent = frame
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,6)

-- Webhook input box
local webhookBox = Instance.new("TextBox")
webhookBox.Size = UDim2.new(1,-20,0,28)
webhookBox.Position = UDim2.new(0,10,0,270)
webhookBox.PlaceholderText = "Enter Discord Webhook URL here"
webhookBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
webhookBox.TextColor3 = Color3.fromRGB(255,255,255)
webhookBox.TextSize = 14
webhookBox.Font = Enum.Font.Gotham
webhookBox.ClearTextOnFocus = false
webhookBox.Parent = frame
Instance.new("UICorner", webhookBox).CornerRadius = UDim.new(0,6)

-- Auto Boss toggle button
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(0,180,0,36)
autoBtn.Position = UDim2.new(0.5,-90,1,-60)
autoBtn.Text = "⚔️ Auto Boss: OFF"
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 16
autoBtn.TextColor3 = Color3.fromRGB(255,255,255)
autoBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
autoBtn.Parent = frame
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0,6)

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1,-20,0,28)
statusLabel.Position = UDim2.new(0,10,1,-90)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
statusLabel.TextScaled = false
statusLabel.TextSize = 16
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Parent = frame

-- Dragging UI
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
end
title.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then dragging=false end
        end)
    end
end)
title.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseMovement then dragInput=input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input==dragInput and dragging then update(input) end
end)
UserInputService.InputBegan:Connect(function(input,gpe)
    if not gpe and input.KeyCode==Enum.KeyCode.H then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- Clear log handler
clearBtn.MouseButton1Click:Connect(function()
    for _,child in ipairs(logFrame:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    lastProcessedMoon = nil
end)

-- Toggle inferno only
toggleBtn.MouseButton1Click:Connect(function()
    infernoOnly = not infernoOnly
    if infernoOnly then
        toggleBtn.Text = "Discord: INFERNO"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(120,40,40)
    else
        toggleBtn.Text = "Discord: ALL"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    end
end)

-- === Functions ===
local function cleanText(text)
    if not text then return "" end
    local t = text:gsub("<[^>]+>",""):gsub("^%s+",""):gsub("%s+$","")
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

local lastSendTime = 0
local SEND_COOLDOWN = 2

local function SendDiscord(titleText,colorDec,desc)
    local webhookUrl = webhookBox.Text
    if not webhookUrl or webhookUrl == "" then return end
    if os.time() - lastSendTime < SEND_COOLDOWN then return end
    lastSendTime = os.time()

    local payload = HttpService:JSONEncode({
        embeds={{title=titleText,description=desc or "",color=colorDec or 0xFFFFFF,timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ")}}
    })
    local req = request or http_request or (syn and syn.request)
    if req then
        task.spawn(function()
            pcall(function()
                req({Url=webhookUrl,Method="POST",Headers={["Content-Type"]="application/json"},Body=payload})
            end)
        end)
    end
end

-- Detect moon
local function detectMoonFromText(text)
    if not text or text=="" then return nil end
    local clean = cleanText(text):lower()
    for k,v in pairs(moonConfigs) do
        if clean:find(k) then
            return k,v.display,v.color
        end
    end
    if clean:find("ended") or clean:find("has ended") then
        return "none","No Moon",0x888888
    end
    return nil
end

-- Moon chat listener
local channel = nil
pcall(function()
    if TextChatService and TextChatService.TextChannels then
        channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
    end
end)
if channel then
    channel.MessageReceived:Connect(function(msg)
        local raw = msg.Text or ""
        local key,displayName,colorDec = detectMoonFromText(raw)
        if not key then return end
        if key==lastProcessedMoon then return end
        lastProcessedMoon = key

        AddLog(os.date("[%H:%M:%S] ")..displayName,Color3.fromRGB(200,200,200))

        if infernoOnly then
            if key=="inferno moon" then
                SendDiscord(displayName,colorDec,cleanText(raw))
            end
        else
            SendDiscord(displayName,colorDec,cleanText(raw))
        end
    end)
end

-- === Auto Boss ===
local autoBossEnabled = false

local function isBattleFinished()
    for _,gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextLabel") and (string.find(gui.Text,"Victory") or string.find(gui.Text,"Defeat")) then
            return true
        end
    end
    return false
end

local function fightBoss(id,mode)
    local bossName = bossNames[id] or ("Boss "..id)
    alreadyFought[id] = alreadyFought[id] or {}
    if alreadyFought[id][mode] then
        statusLabel.Text = "⏭️ "..bossName.." | Mode "..mode.." already done, skipping"
        return false
    end

    statusLabel.Text = "⚔️ Fighting "..bossName.." | Mode "..mode.."..."
    local success,err = pcall(function() networkEvent:FireServer(id,mode) end)
    if not success then
        statusLabel.Text = "❌ Error "..bossName.." | Mode "..mode
        return false
    end

    local timer=0
    local timeout=1.5
    repeat wait(0.5) timer=timer+0.5 until isBattleFinished() or timer>=timeout

    if timer>=timeout then
        statusLabel.Text = "⏱️ "..bossName.." | Mode "..mode.." on cooldown, skipping"
        return false
    else
        statusLabel.Text = "✅ "..bossName.." | Mode "..mode.." finished!"
        alreadyFought[id][mode]=true
        return true
    end
end

local function runAutoBossCycle()
    spawn(function()
        while autoBossEnabled do
            statusLabel.Text = "⚔️ Auto Boss: Running..."
            local completedThisCycle=0

            for _,boss in ipairs(bossList) do
                for _,mode in ipairs(boss.modes) do
                    local fought=fightBoss(boss.id,mode)
                    if fought then completedThisCycle=completedThisCycle+1 end
                end
            end

            -- Send Discord if any boss actually fought
            if completedThisCycle>0 then
                SendDiscord("Auto Boss Cycle Complete",0x00FF00,
                    ("All bosses completed! Fought %d bosses this cycle."):format(completedThisCycle)
                )
            end

            statusLabel.Text="✅ Auto Boss: Cycle complete. Next run in 60 minutes."
            for i=1,3600 do
                if not autoBossEnabled then break end
                wait(1)
            end
        end
        statusLabel.Text=""
    end)
end

autoBtn.MouseButton1Click:Connect(function()
    autoBossEnabled = not autoBossEnabled
    if autoBossEnabled then
        autoBtn.Text="⚔️ Auto Boss: ON"
        autoBtn.BackgroundColor3=Color3.fromRGB(50,200,50)
        runAutoBossCycle()
    else
        autoBtn.Text="⚔️ Auto Boss: OFF"
        autoBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
    end
end)

print("MoonTracker + Auto Boss loaded. Toggle UI=H, Auto Boss toggle in UI, Webhook input available.")
