-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

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

-- === UI chính ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RedzMoonAutoUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- ScreenGui riêng cho nút toggle
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "ToggleUI"
toggleGui.ResetOnSpawn = false
toggleGui.Parent = playerGui

-- Nút toggle UI cho mobile
local toggleBtnMobile = Instance.new("TextButton")
toggleBtnMobile.Size = UDim2.new(0, 40, 0, 40)
toggleBtnMobile.AnchorPoint = Vector2.new(1, 0.5)
toggleBtnMobile.Position = UDim2.new(1, -50, 0, 50 + 40/2)
toggleBtnMobile.Text = "☰"
toggleBtnMobile.Font = Enum.Font.GothamBold
toggleBtnMobile.TextSize = 24
toggleBtnMobile.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtnMobile.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
toggleBtnMobile.Parent = toggleGui -- ✅ quan trọng
Instance.new("UICorner", toggleBtnMobile).CornerRadius = UDim.new(0, 8)

-- Kết nối nút toggle chỉ bật/tắt screenGui
toggleBtnMobile.MouseButton1Click:Connect(function()
    screenGui.Enabled = not screenGui.Enabled
end)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,420,0,400)
frame.Position = UDim2.new(0.55,0,0.2,0)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)

-- Header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,40)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundColor3 = Color3.fromRGB(35,35,35)
title.Text = "  Moon Tracker Tool"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0,10)

-- Hide/Show
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0,28,0,28)
hideBtn.Position = UDim2.new(1,-34,0,6)
hideBtn.Text = "×"
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 20
hideBtn.TextColor3 = Color3.fromRGB(220,220,220)
hideBtn.BackgroundTransparency = 1
hideBtn.Parent = frame

hideBtn.MouseButton1Click:Connect(function()
    screenGui.Enabled = not screenGui.Enabled
end)

-- Tab buttons container
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1,0,0,36)
tabFrame.Position = UDim2.new(0,0,0,40)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = frame

local function createTabButton(name,posX)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,120,0,30)
    btn.Position = UDim2.new(0,posX,0,3)
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.BackgroundColor3 = Color3.fromRGB(150,0,0)
    btn.Parent = tabFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    return btn
end

local moonTabBtn = createTabButton("Moon Tracker",10)
local bossTabBtn = createTabButton("Auto Boss",150)
local webhookTabBtn = createTabButton("Webhook",290)

-- Panels
local panelMoon = Instance.new("Frame")
panelMoon.Size = UDim2.new(1,-20,1,-80)
panelMoon.Position = UDim2.new(0,10,0,80)
panelMoon.BackgroundColor3 = Color3.fromRGB(30,30,30)
panelMoon.Parent = frame
Instance.new("UICorner", panelMoon).CornerRadius = UDim.new(0,8)

local panelBoss = panelMoon:Clone()
panelBoss.Parent = frame
panelBoss.BackgroundColor3 = Color3.fromRGB(30,30,30)

local panelWebhook = panelMoon:Clone()
panelWebhook.Parent = frame
panelWebhook.BackgroundColor3 = Color3.fromRGB(30,30,30)

panelBoss.Visible = false
panelWebhook.Visible = false

-- === Moon Tracker panel contents ===
local moonLogFrame = Instance.new("ScrollingFrame")
moonLogFrame.Size = UDim2.new(1,-12,1,-20)
moonLogFrame.Position = UDim2.new(0,6,0,6)
moonLogFrame.BackgroundTransparency = 1
moonLogFrame.BorderSizePixel = 0
moonLogFrame.ScrollBarThickness = 6
moonLogFrame.Parent = panelMoon

local moonList = Instance.new("UIListLayout")
moonList.Parent = moonLogFrame
moonList.SortOrder = Enum.SortOrder.LayoutOrder
moonList.Padding = UDim.new(0,6)

local toggleInfernoBtn = Instance.new("TextButton")
toggleInfernoBtn.Size = UDim2.new(0,160,0,28)
toggleInfernoBtn.Position = UDim2.new(0,10,1,-34)
toggleInfernoBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
toggleInfernoBtn.Text = "Discord: ALL"
toggleInfernoBtn.Font = Enum.Font.GothamBold
toggleInfernoBtn.TextSize = 14
toggleInfernoBtn.TextColor3 = Color3.fromRGB(255,255,255)
toggleInfernoBtn.Parent = panelMoon
Instance.new("UICorner", toggleInfernoBtn).CornerRadius = UDim.new(0,6)

toggleInfernoBtn.MouseButton1Click:Connect(function()
    infernoOnly = not infernoOnly
    if infernoOnly then
        toggleInfernoBtn.Text = "Discord: INFERNO"
        toggleInfernoBtn.BackgroundColor3 = Color3.fromRGB(120,40,40)
    else
        toggleInfernoBtn.Text = "Discord: ALL"
        toggleInfernoBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    end
end)

-- === Auto Boss panel contents ===
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(0,180,0,36)
autoBtn.Position = UDim2.new(0.5,-90,0,10)
autoBtn.Text = "⚔️ Auto Boss: OFF"
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 16
autoBtn.TextColor3 = Color3.fromRGB(255,255,255)
autoBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
autoBtn.Parent = panelBoss
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0,6)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1,-20,0,28)
statusLabel.Position = UDim2.new(0,10,0,60)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
statusLabel.TextSize = 16
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Parent = panelBoss

-- === Webhook panel contents ===
local webhookBox = Instance.new("Discord Webhook URL")
webhookBox.Size = UDim2.new(1,-20,0,28)
webhookBox.Position = UDim2.new(0,10,0,10)
webhookBox.PlaceholderText = "Enter Discord Webhook URL"
webhookBox.TextWrapped = true        
webhookBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
webhookBox.TextColor3 = Color3.fromRGB(255,255,255)
webhookBox.TextSize = 14
webhookBox.Font = Enum.Font.Gotham
webhookBox.ClearTextOnFocus = false
webhookBox.Parent = panelWebhook
Instance.new("UICorner", webhookBox).CornerRadius = UDim.new(0,6)

-- === Tab switching ===
local function switchTab(tab)
    panelMoon.Visible=false
    panelBoss.Visible=false
    panelWebhook.Visible=false
    if tab=="moon" then panelMoon.Visible=true
    elseif tab=="boss" then panelBoss.Visible=true
    elseif tab=="webhook" then panelWebhook.Visible=true
    end
end

moonTabBtn.MouseButton1Click:Connect(function() switchTab("moon") end)
bossTabBtn.MouseButton1Click:Connect(function() switchTab("boss") end)
webhookTabBtn.MouseButton1Click:Connect(function() switchTab("webhook") end)

switchTab("moon") -- default

-- === Moon tracker logic ===
local function cleanText(text)
    if not text then return "" end
    return text:gsub("<[^>]+>",""):gsub("^%s+",""):gsub("%s+$","")
end

local lastSendTime = 0
local SEND_COOLDOWN = 2

local function AddMoonLog(text,color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-10,0,20)
    lbl.BackgroundTransparency = 1
    lbl.Text=text
    lbl.TextColor3=color or Color3.fromRGB(200,200,200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Parent = moonLogFrame
    task.wait()
    moonLogFrame.CanvasSize=UDim2.new(0,0,0,moonList.AbsoluteContentSize.Y+8)
    moonLogFrame.CanvasPosition=Vector2.new(0,math.max(0,moonList.AbsoluteContentSize.Y-moonLogFrame.AbsoluteSize.Y))
end

local function SendDiscord(title,color,desc)
    local webhookURL = webhookBox.Text
    if webhookURL=="" then return end
    if os.time()-lastSendTime<SEND_COOLDOWN then return end
    lastSendTime=os.time()
    local payload = HttpService:JSONEncode({
        embeds={{title=title,description=desc,color=color,timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ")}}
    })
    local req = request or http_request or (syn and syn.request)
    if req then
        task.spawn(function()
            pcall(function()
                req({Url=webhookURL,Method="POST",Headers={["Content-Type"]="application/json"},Body=payload})
            end)
        end)
    end
end

local function detectMoonFromText(text)
    if not text or text=="" then return nil end
    local clean=cleanText(text):lower()
    for k,v in pairs(moonConfigs) do
        if clean:find(k) then return k,v.display,v.color end
    end
    if clean:find("ended") or clean:find("has ended") then return "none","No Moon",0x888888 end
    return nil
end

-- Listen chat
local channel=nil
pcall(function() if TextChatService and TextChatService.TextChannels then channel=TextChatService.TextChannels:FindFirstChild("RBXGeneral") end end)
if channel then
    channel.MessageReceived:Connect(function(msg)
        local raw=msg.Text or ""
        local key,displayName,colorDec=detectMoonFromText(raw)
        if not key then return end
        if key==lastProcessedMoon then return end
        lastProcessedMoon=key
        AddMoonLog(os.date("[%H:%M:%S] ")..displayName,Color3.fromRGB(200,200,200))
        if infernoOnly then
            if key=="inferno moon" then SendDiscord(displayName,colorDec,cleanText(raw)) end
        else
            SendDiscord(displayName,colorDec,cleanText(raw))
        end
    end)
end

-- === Auto Boss logic ===
local autoBossEnabled=false

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
    alreadyFought[id]=alreadyFought[id] or {}
    if alreadyFought[id][mode] then
        statusLabel.Text="⏭️ "..bossName.." | Mode "..mode.." already done, skipping"
        return false
    end
    statusLabel.Text="⚔️ Fighting "..bossName.." | Mode "..mode.."..."
    local success,err = pcall(function() networkEvent:FireServer(id,mode) end)
    if not success then
        statusLabel.Text="❌ Error "..bossName.." | Mode "..mode
        return false
    end
    local timer=0
    local timeout=1.5
    repeat wait(0.5) timer=timer+0.5 until isBattleFinished() or timer>=timeout
    if timer>=timeout then
        statusLabel.Text="⏱️ "..bossName.." | Mode "..mode.." on cooldown, skipping"
        return false
    else
        statusLabel.Text="✅ "..bossName.." | Mode "..mode.." finished!"
        alreadyFought[id][mode]=true
        return true
    end
end

local function runAutoBossCycle()
    spawn(function()
        while autoBossEnabled do
            statusLabel.Text="⚔️ Auto Boss: Running..."
            local completedThisCycle=0
            for _,boss in ipairs(bossList) do
                for _,mode in ipairs(boss.modes) do
                    local fought=fightBoss(boss.id,mode)
                    if fought then completedThisCycle=completedThisCycle+1 end
                end
            end
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

-- Dragging
local dragging,dragInput,dragStart,startPos
local function update(input)
    local delta=input.Position-dragStart
    frame.Position=UDim2.new(
        startPos.X.Scale,startPos.X.Offset+delta.X,
        startPos.Y.Scale,startPos.Y.Offset+delta.Y
    )
end

title.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragStart=input.Position
        startPos=frame.Position
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

-- Toggle UI bằng phím H
UserInputService.InputBegan:Connect(function(input,gpe)
    if not gpe and input.KeyCode==Enum.KeyCode.H then
        screenGui.Enabled=not screenGui.Enabled
    end
end)

print("Redz-style MoonTracker + AutoBoss + Webhook loaded.")
