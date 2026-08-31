local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- =========================
-- AUTO WALKSPEED
-- =========================

task.spawn(function()
    while true do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            humanoid.WalkSpeed = 70
        end

        task.wait(0.5)
    end
end)


-- =========================
-- TELEPORT UI
-- =========================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IslandTeleportUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 435, 0, 70)
Frame.Position = UDim2.new(0.5, -217, 0, 10)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = Frame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 25)
Title.BackgroundTransparency = 1
Title.Text = "Island Teleport"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.Parent = Frame

local function CreateButton(text, position, teleportPosition)
    local Button = Instance.new("TextButton")

    Button.Size = UDim2.new(0, 95, 0, 30)
    Button.Position = position
    Button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Button.BorderSizePixel = 0
    Button.Text = text
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 14
    Button.Font = Enum.Font.Gotham
    Button.Parent = Frame

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = Button

    Button.MouseButton1Click:Connect(function()
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if root then
            root.CFrame = CFrame.new(teleportPosition)
        end
    end)
end

-- Đảo 1
CreateButton(
    "Đảo 1",
    UDim2.new(0, 10, 0, 32),
    Vector3.new(253, 23, -201)
)

-- Đảo 2
CreateButton(
    "Đảo 2",
    UDim2.new(0, 117, 0, 32),
    Vector3.new(2301, 19, -265)
)

-- Đảo 3
CreateButton(
    "Đảo 3",
    UDim2.new(0, 224, 0, 32),
    Vector3.new(85, 78, -2739)
)

-- Pel
local PelButton = Instance.new("TextButton")

PelButton.Size = UDim2.new(0, 95, 0, 30)
PelButton.Position = UDim2.new(0, 331, 0, 32)
PelButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
PelButton.BorderSizePixel = 0
PelButton.Text = "Pel"
PelButton.TextColor3 = Color3.new(1, 1, 1)
PelButton.TextSize = 14
PelButton.Font = Enum.Font.Gotham
PelButton.Parent = Frame

local PelCorner = Instance.new("UICorner")
PelCorner.CornerRadius = UDim.new(0, 6)
PelCorner.Parent = PelButton

PelButton.MouseButton1Click:Connect(function()
    local target = Players:FindFirstChild("phanquanghai100gb")

    if target and target.Character then
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local myRoot = player.Character
            and player.Character:FindFirstChild("HumanoidRootPart")

        if targetRoot and myRoot then
            myRoot.CFrame = targetRoot.CFrame
        end
    else
        warn("Không tìm thấy player phanquanghai100gb")
    end
end)
