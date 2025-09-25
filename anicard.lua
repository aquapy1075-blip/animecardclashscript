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

-- === ScreenGui ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RedzMoonAutoUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- === ScreenGui cho nút toggle ===
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "ToggleUI"
toggleGui.ResetOnSpawn = false
toggleGui.Parent = playerGui

-- === Nút toggle mobile ===
local toggleBtnMobile = Instance.new("TextButton")
toggleBtnMobile.Size = UDim2.new(0, 40, 0, 40)
toggleBtnMobile.AnchorPoint = Vector2.new(1, 0.5)
toggleBtnMobile.Position = UDim2.new(1, -50, 0, 50 + 40/2)
toggleBtnMobile.Text = "☰"
toggleBtnMobile.Font = Enum.Font.GothamBold
toggleBtnMobile.TextSize = 24
toggleBtnMobile.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtnMobile.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
toggleBtnMobile.Parent = toggleGui
Instance.new("UICorner", toggleBtnMobile).CornerRadius = UDim.new(0, 8)

-- === Container chính (mainFrame) ===
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0,420,0,400)
mainFrame.Position = UDim2.new(0.55,0,0.2,0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,10)

-- Header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,40)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundColor3 = Color3.fromRGB(35,35,35)
title.Text = "  Moon Tracker Tool"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0,10)

-- Hide/Show nút ×
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0,28,0,28)
hideBtn.Position = UDim2.new(1,-34,0,6)
hideBtn.Text = "×"
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 20
hideBtn.TextColor3 = Color3.fromRGB(220,220,220)
hideBtn.BackgroundTransparency = 1
hideBtn.Parent = mainFrame

-- Toggle mainFrame thay vì toàn bộ screenGui
toggleBtnMobile.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)
hideBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Tab buttons container
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1,0,0,36)
tabFrame.Position = UDim2.new(0,0,0,40)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = mainFrame

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
panelMoon.Parent = mainFrame
Instance.new("UICorner", panelMoon).CornerRadius = UDim.new(0,8)

local panelBoss = panelMoon:Clone()
panelBoss.Parent = mainFrame
panelBoss.BackgroundColor3 = Color3.fromRGB(30,30,30)

local panelWebhook = panelMoon:Clone()
panelWebhook.Parent = mainFrame
panelWebhook.BackgroundColor3 = Color3.fromRGB(30,30,30)

panelBoss.Visible = false
panelWebhook.Visible = false

-- Moon Tracker contents
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

-- Toggle Inferno button
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

-- Auto Boss contents
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

-- Webhook contents
local webhookBox = Instance.new("TextBox")
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

-- Tab switching
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

-- === Các logic khác giữ nguyên ===
-- (Moon tracker, Auto Boss logic, webhook sending, dragging, H toggle)
-- Bạn có thể copy phần logic từ script gốc, không cần thay đổi.

print("Redz-style MoonTracker + AutoBoss + Webhook loaded.")
