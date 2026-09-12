------------------------------------------------------------
-- AUTO FISHING
-- Auto Cast + Auto Shake + Auto Reel
------------------------------------------------------------
repeat
    task.wait()
until game:IsLoaded()
task.wait(5)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer or LocalPlayer.Name ~= "NexustanThan" then
    return
end
local SERVER_HOP_TIME = 2700 -- 45 phút
local PLAYER_HOP_DISTANCE = 100
local ServerHopTriggered = false

local function QuickJoin()

    if ServerHopTriggered then
        return
    end

    ServerHopTriggered = true

    pcall(function()

        local args = {
            "QuickJoin"
        }

        ReplicatedStorage
            :WaitForChild("Events")
            :WaitForChild("TeleportService")
            :FireServer(unpack(args))

    end)

end
task.spawn(function()

    task.wait(SERVER_HOP_TIME)

    if Destroyed then
        return
    end

    QuickJoin()

end)
task.spawn(function()

    while not Destroyed
        and not ServerHopTriggered
    do

        local character =
            LocalPlayer.Character

        local myRoot =
            character
            and character:FindFirstChild(
                "HumanoidRootPart"
            )

        if myRoot then

            for _, player in ipairs(
                Players:GetPlayers()
            ) do

                if player ~= LocalPlayer then

                    local otherCharacter =
                        player.Character

                    local otherRoot =
                        otherCharacter
                        and otherCharacter:FindFirstChild(
                            "HumanoidRootPart"
                        )

                    if otherRoot then

                        local distance =
                            (
                                otherRoot.Position
                                - myRoot.Position
                            ).Magnitude

                        if distance <= PLAYER_HOP_DISTANCE then

                            print(
                                "[SERVER HOP] Player near:",
                                player.Name,
                                "Distance:",
                                math.floor(distance)
                            )

                            QuickJoin()

                            break
                        end
                    end
                end
            end
        end

        task.wait(0.5)
    end

end)

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MouseHeld = false
local Destroyed = false
local Enabled = false
local StartingFish = false
local FishState = "IDLE"

local function CheckMainMenu()

    local MainMenu = PlayerGui:FindFirstChild("Main Menu")

    if not MainMenu then
        return false
    end

    print("[MAIN MENU] Detected")

    local args = {
        "Play"
    }

    game:GetService("ReplicatedStorage")
        :WaitForChild("Events")
        :WaitForChild("MainMenu")
        :FireServer(unpack(args))

    print("[MAIN MENU] Play fired")

    -- CHỜ MAIN MENU BIẾN MẤT
    local StartTime = os.clock()

    while PlayerGui:FindFirstChild("Main Menu")
        and os.clock() - StartTime < 15
    do
        task.wait(0.1)
    end

    print("[MAIN MENU] Finished")

    return true
end

CheckMainMenu()

task.wait(2)
local function TeleportToFishPos()
    local Character = LocalPlayer.Character
    local HRP = Character and Character:FindFirstChild("HumanoidRootPart")

    if HRP then
        HRP.CFrame = CFrame.new(-75, 6, 1239)
    end
end
local function EquipFishingRod()
local args = {
	"Equip",
	"Silverline Rod [Lv. 8/UpgradeBonuses/Double Catch91/Lure Speed37/]"
}
game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("HeldItem"):FireServer(unpack(args))


end
local function StartFishingSetup()

    if not Enabled or Destroyed then
        return
    end

    StartingFish = true

    print("[AUTO FISH] Starting setup...")

    -- TELEPORT
    TeleportToFishPos()

    task.wait(0.5)

    if not Enabled or Destroyed then
        StartingFish = false
        return
    end

    -- EQUIP ROD
    EquipFishingRod()

    -- CHỜ 1s SAU KHI EQUIP
    task.wait(1)

    if not Enabled or Destroyed then
        StartingFish = false
        return
    end

    -- NHẢY 3 LẦN, MỖI LẦN CÁCH 2s
    local Character = LocalPlayer.Character
    local Humanoid =
        Character
        and Character:FindFirstChildOfClass("Humanoid")

    if Humanoid then

        for i = 1, 3 do

            if not Enabled or Destroyed then
                StartingFish = false
                return
            end

            Humanoid.Jump = true

            pcall(function()
                Humanoid:ChangeState(
                    Enum.HumanoidStateType.Jumping
                )
            end)

            if i < 3 then
                task.wait(2)
            end
        end
    end

    if not Enabled or Destroyed then
        StartingFish = false
        return
    end

    -- START FISHING
    FishState = "CAST"

    StartingFish = false

    print("[AUTO FISH] Ready")

end
------------------------------------------------------------
-- CAMERA / FOV
------------------------------------------------------------

local Camera = workspace.CurrentCamera

local NormalFOV = nil

local function SaveNormalFOV()

    if NormalFOV ~= nil then
        return
    end

    Camera = workspace.CurrentCamera

    if Camera then
        NormalFOV = Camera.FieldOfView
    end

end

local function RestoreNormalFOV()

    Camera = workspace.CurrentCamera

    if not Camera or not NormalFOV then
        return
    end

    Camera.FieldOfView = NormalFOV

end
------------------------------------------------------------
-- VIRTUAL INPUT
------------------------------------------------------------

local VirtualInputManager

pcall(function()
    VirtualInputManager =
        game:GetService("VirtualInputManager")
end)


------------------------------------------------------------
-- REEL STATE
------------------------------------------------------------

local ReelRequested = false
local ReelRunning = false

------------------------------------------------------------
-- CAST STATE
------------------------------------------------------------

local CastActive = false
local CastReleased = false
local CastStartTime = 0

------------------------------------------------------------
-- MOUSE POSITION
------------------------------------------------------------

local function GetMousePosition()

    local Camera =
        workspace.CurrentCamera

    if Camera then

        local Viewport =
            Camera.ViewportSize

        return
            math.floor(Viewport.X / 2),
            math.floor(Viewport.Y / 2)

    end

    return 960, 540

end

local MouseX = 0
local MouseY = 0

------------------------------------------------------------
-- MOUSE DOWN
------------------------------------------------------------

local function MouseDown()

    if MouseHeld then
        return
    end

    if not VirtualInputManager then
        return
    end

    MouseHeld = true

    local X, Y =
        GetMousePosition()

    MouseX = X
    MouseY = Y

    VirtualInputManager:SendMouseButtonEvent(
        MouseX,
        MouseY,
        0,
        true,
        game,
        0
    )

end

------------------------------------------------------------
-- MOUSE UP
------------------------------------------------------------

local function MouseUp()

    if not MouseHeld then
        return
    end

    if not VirtualInputManager then
        MouseHeld = false
        return
    end

    MouseHeld = false

    VirtualInputManager:SendMouseButtonEvent(
        MouseX,
        MouseY,
        0,
        false,
        game,
        0
    )

end

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

local SHAKE_DELAY = 0.04

------------------------------------------------------------
-- UI
------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name = "AutoFishingUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

------------------------------------------------------------
-- MAIN
------------------------------------------------------------

local Main = Instance.new("Frame")

Main.Name = "Main"
Main.Size = UDim2.new(0, 210, 0, 65)
Main.Position = UDim2.new(0, 20, 0.5, 30)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner =
    Instance.new("UICorner")

MainCorner.CornerRadius =
    UDim.new(0, 8)

MainCorner.Parent = Main

------------------------------------------------------------
-- TOGGLE
------------------------------------------------------------

local Toggle =
    Instance.new("TextButton")

Toggle.Name = "Toggle"
Toggle.Size = UDim2.new(1, -38, 1, -10)
Toggle.Position = UDim2.new(0, 5, 0, 5)
Toggle.BackgroundColor3 =
    Color3.fromRGB(45, 45, 45)

Toggle.BorderSizePixel = 0

Toggle.TextColor3 =
    Color3.fromRGB(255, 255, 255)

Toggle.TextSize = 16
Toggle.Font = Enum.Font.GothamBold
Toggle.Text = "Auto Fishing: OFF"
Toggle.AutoButtonColor = true
Toggle.Parent = Main

local ToggleCorner =
    Instance.new("UICorner")

ToggleCorner.CornerRadius =
    UDim.new(0, 6)

ToggleCorner.Parent = Toggle

------------------------------------------------------------
-- CLOSE
------------------------------------------------------------

local Close =
    Instance.new("TextButton")

Close.Name = "Close"
Close.Size = UDim2.new(0, 25, 0, 25)
Close.Position = UDim2.new(1, -30, 0, 5)

Close.BackgroundColor3 =
    Color3.fromRGB(70, 35, 35)

Close.BorderSizePixel = 0

Close.TextColor3 =
    Color3.fromRGB(255, 255, 255)

Close.Text = "X"
Close.TextSize = 14
Close.Font = Enum.Font.GothamBold
Close.Parent = Main

local CloseCorner =
    Instance.new("UICorner")

CloseCorner.CornerRadius =
    UDim.new(0, 6)

CloseCorner.Parent = Close

------------------------------------------------------------
-- UI UPDATE
------------------------------------------------------------

local function UpdateToggle()

    if Destroyed then
        return
    end

    if Enabled then

        Toggle.Text =
            "Auto Fishing: ON"

        Toggle.BackgroundColor3 =
            Color3.fromRGB(35, 100, 50)

    else

        Toggle.Text =
            "Auto Fishing: OFF"

        Toggle.BackgroundColor3 =
            Color3.fromRGB(45, 45, 45)

    end

end

------------------------------------------------------------
-- TOGGLE
------------------------------------------------------------

Toggle.MouseButton1Click:Connect(function()

    if Destroyed then
        return
    end

    Enabled = not Enabled

    if Enabled then
   task.spawn(function()
        StartFishingSetup()
    end)
    else

    StartingFish = false

    NormalFOV = nil

    FishState = "IDLE"

    ReelRequested = false
    ReelRunning = false

    CastActive = false
    CastReleased = false
    CastStartTime = 0

    MouseUp()

end

    UpdateToggle()
    
end)

------------------------------------------------------------
-- CLOSE
------------------------------------------------------------

Close.MouseButton1Click:Connect(function()

    if Destroyed then
        return
    end

    Enabled = false
    Destroyed = true

    FishState = "IDLE"

    ReelRequested = false
    ReelRunning = false

    CastActive = false
    CastReleased = false
    CastStartTime = 0

    MouseUp()

    if ScreenGui then
        ScreenGui:Destroy()
    end

end)

UpdateToggle()
task.spawn(function()

    task.wait(1)

    if not Enabled or Destroyed then
        return
    end

    StartFishingSetup()

end)

------------------------------------------------------------
-- REFERENCES
------------------------------------------------------------

local function GetFishing()

    return PlayerGui:FindFirstChild("Fishing")

end

local function GetQTE()

    return PlayerGui:FindFirstChild(
        "QuickTimeEvents"
    )

end

------------------------------------------------------------
-- GET QTE EVENT
------------------------------------------------------------

local function GetQTEEvent()

    return LocalPlayer:GetAttribute(
        "QTEEvent"
    )

end

------------------------------------------------------------
-- FIND SHAKE
------------------------------------------------------------

local function FindShake()

    local QTE =
        GetQTE()

    if not QTE then
        return nil
    end

    local Button =
        QTE:FindFirstChild("Button")

    if not Button then
        return nil
    end

    local TextLabel =
        Button:FindFirstChild("TextLabel")

    if not TextLabel then
        return nil
    end

    if TextLabel:IsA("TextLabel")
        and TextLabel.Text == "SHAKE"
    then

        return Button

    end

    return nil

end

------------------------------------------------------------
-- CLICK SHAKE
------------------------------------------------------------

local function ClickShake(Button)

    if not Button then
        return
    end

    --------------------------------------------------------
    -- FIRE CONNECTIONS
    --------------------------------------------------------

    if getconnections then

        pcall(function()

            local Connections =
                getconnections(
                    Button.Activated
                )

            for _, Connection in ipairs(
                Connections
            ) do

                if Connection.Function then

                    pcall(
                        Connection.Function
                    )

                end

            end

        end)

        pcall(function()

            local Connections =
                getconnections(
                    Button.MouseButton1Click
                )

            for _, Connection in ipairs(
                Connections
            ) do

                if Connection.Function then

                    pcall(
                        Connection.Function
                    )

                end

            end

        end)

    end

    --------------------------------------------------------
    -- VIRTUAL CLICK
    --------------------------------------------------------

    if VirtualInputManager then

        pcall(function()

            local Position =
                Button.AbsolutePosition

            local Size =
                Button.AbsoluteSize

            local X =
                Position.X + Size.X / 2

            local Y =
                Position.Y + Size.Y / 2

            VirtualInputManager:SendMouseButtonEvent(
                X,
                Y,
                0,
                true,
                game,
                0
            )

            VirtualInputManager:SendMouseButtonEvent(
                X,
                Y,
                0,
                false,
                game,
                0
            )

        end)

    end

end

------------------------------------------------------------
-- AUTO SHAKE
------------------------------------------------------------

local function HandleShake()

    local Button =
        FindShake()

    if not Button then
        return false
    end

    ClickShake(Button)

    return true

end

------------------------------------------------------------
-- IS CASTING
------------------------------------------------------------

local function IsCasting()

    return GetQTEEvent() ==
        "Timed Release"

end

------------------------------------------------------------
-- IS REELING
------------------------------------------------------------

local function IsReeling()

    return GetQTEEvent() ==
        "Reel Fish"

end

------------------------------------------------------------
-- FIND CAST AMOUNT
--
-- RUNTIME:
--
-- Workspace
--   Entities
--     PlayerName
--       HumanoidRootPart
--         Fishing Bar
--           Frame
--             Amount
------------------------------------------------------------

local function FindCastAmount()

    local Entities =
        workspace:FindFirstChild("Entities")

    if not Entities then
        return nil
    end

    local Entity =
        Entities:FindFirstChild(
            LocalPlayer.Name
        )

    if not Entity then
        return nil
    end

    local PrimaryPart =
        Entity:FindFirstChild(
            "HumanoidRootPart"
        )

    if not PrimaryPart then
        return nil
    end

    local FishingBar =
        PrimaryPart:FindFirstChild(
            "Fishing Bar"
        )

    if not FishingBar then
        return nil
    end

    local Frame =
        FishingBar:FindFirstChild(
            "Frame"
        )

    if not Frame then
        return nil
    end

    return Frame:FindFirstChild(
        "Amount"
    )

end

------------------------------------------------------------
-- CAST SETTINGS
------------------------------------------------------------

local CAST_POWER = 0.99
local CAST_TIMEOUT = 3.0

------------------------------------------------------------
-- START CAST
------------------------------------------------------------

local function StartCast()

    if CastActive then
        return
    end

    --------------------------------------------------------
    -- KHÔNG CAST KHI REEL
    --------------------------------------------------------

    if IsReeling()
        or ReelRequested
        or ReelRunning
    then
        return
    end

    --------------------------------------------------------
    -- START
    --------------------------------------------------------

    CastActive = true
    CastReleased = false
    CastStartTime = os.clock()
    SaveNormalFOV()
    MouseDown()

    print("[CAST INPUT]")

end

------------------------------------------------------------
-- UPDATE CAST
------------------------------------------------------------

local function UpdateCast()

    if not CastActive then
        return false
    end

    --------------------------------------------------------
    -- REEL PRIORITY
    --------------------------------------------------------

    if IsReeling()
        or ReelRequested
        or ReelRunning
    then

        MouseUp()

        CastActive = false
        CastReleased = false
        CastStartTime = 0

        return false

    end

    --------------------------------------------------------
    -- ĐÃ RELEASE
    -- Chờ Timed Release biến mất
    --------------------------------------------------------

    if CastReleased then

        if not IsCasting() then

            CastActive = false
            CastReleased = false
            CastStartTime = 0

            print("[CAST RESET]")

        end

        return false

    end

    --------------------------------------------------------
    -- TIMEOUT
    --------------------------------------------------------

    if os.clock() - CastStartTime >=
        CAST_TIMEOUT
    then

        MouseUp()
            RestoreNormalFOV()

        CastActive = false
        CastReleased = false
        CastStartTime = 0

        print("[CAST TIMEOUT]")

        return false

    end

    --------------------------------------------------------
    -- CHƯA CÓ TIMED RELEASE
    --------------------------------------------------------

    if not IsCasting() then
        return false
    end

    --------------------------------------------------------
    -- FIND AMOUNT
    --------------------------------------------------------

    local Amount =
        FindCastAmount()

    if not Amount then
        return false
    end

    --------------------------------------------------------
    -- READ POWER
    --------------------------------------------------------

    local Power =
        Amount.Size.Y.Scale

    --------------------------------------------------------
    -- RELEASE
    --------------------------------------------------------

    if Power >= CAST_POWER then

        MouseUp()
          RestoreNormalFOV()

        CastReleased = true

        print(
            "[CAST RELEASE] Power =",
            Power
        )

        return true

    end

    return false

end

------------------------------------------------------------
-- GET REEL OBJECTS
------------------------------------------------------------

local function GetReelObjects()

    local Fishing =
        GetFishing()

    if not Fishing then
        return nil
    end

    local MainFrame =
        Fishing:FindFirstChild("Main")

    if not MainFrame then
        return nil
    end

    local Fish =
        MainFrame:FindFirstChild("Fish")

    local Move =
        MainFrame:FindFirstChild("Move")

    if not Fish
        or not Move
    then

        return nil

    end

    local ProgressBar =
        Fishing:FindFirstChild(
            "Progress Bar"
        )

    local Bar

    if ProgressBar then

        Bar =
            ProgressBar:FindFirstChild(
                "Bar"
            )

    end

    return
        Fishing,
        MainFrame,
        Fish,
        Move,
        Bar

end

------------------------------------------------------------
-- GET FISH RANGE
------------------------------------------------------------

local function GetFishRange(
    MainFrame,
    Fish
)

    local MainWidth =
        MainFrame.AbsoluteSize.X

    local FishWidth =
        Fish.AbsoluteSize.X

    if MainWidth <= 0
        or FishWidth <= 0
    then

        return nil

    end

    local FishScale =
        FishWidth / MainWidth

    local FishX =
        Fish.Position.X.Scale

    local FishLeft =
        FishX *
        (1 - FishScale)

    local FishRight =
        FishLeft +
        FishScale

    return
        FishLeft,
        FishRight,
        FishScale

end

------------------------------------------------------------
-- GET MOVE RANGE
------------------------------------------------------------

local function GetMoveRange(Move)

    local Size =
        Move.Size.X.Scale

    local Position =
        Move.Position.X.Scale

    local MoveLeft =
        Position *
        (1 - Size)

    local MoveRight =
        MoveLeft +
        Size

    return
        MoveLeft,
        MoveRight,
        Size

end

------------------------------------------------------------
-- AUTO REEL SETTINGS
------------------------------------------------------------

local PREDICTION_TIME = 0.10

local CENTER_ZONE = 0.025

local CONTROL_GAIN = 7.0
local VELOCITY_GAIN = 0.10
local MOVE_BRAKE_GAIN = 1.5

local HOLD_THRESHOLD = 0.025
local RELEASE_THRESHOLD = -0.025

local MIN_HOLD_TIME = 0.12
local MIN_RELEASE_TIME = 0.08

------------------------------------------------------------
-- AUTO REEL
------------------------------------------------------------

local function AutoReel()

    local Fishing
    local MainFrame
    local Fish
    local Move
    local Bar

    --------------------------------------------------------
    -- GET GUI
    --------------------------------------------------------

    while Enabled
        and not Destroyed
        and IsReeling()
    do

        Fishing,
        MainFrame,
        Fish,
        Move,
        Bar =
            GetReelObjects()

        if Fishing
            and MainFrame
            and Fish
            and Move
        then

            break

        end

        RunService.RenderStepped:Wait()

    end

    --------------------------------------------------------
    -- NO GUI
    --------------------------------------------------------

    if not Fishing
        or not MainFrame
        or not Fish
        or not Move
    then

        MouseUp()

        return

    end

    --------------------------------------------------------
    -- REEL START
    --------------------------------------------------------

    if not MouseHeld then
        MouseDown()
    end

    --------------------------------------------------------
    -- STATE
    --------------------------------------------------------

    local Holding = true

    local StateStart =
        os.clock()

    local LastFishCenter = nil
    local LastMoveCenter = nil

    local FishVelocity = 0
    local MoveVelocity = 0

    --------------------------------------------------------
    -- SET HOLDING
    --------------------------------------------------------

    local function SetHolding(NewState)

        if NewState == Holding then
            return
        end

        Holding =
            NewState

        StateStart =
            os.clock()

        if Holding then
            MouseDown()
        else
            MouseUp()
        end

    end

    --------------------------------------------------------
    -- REEL LOOP
    --------------------------------------------------------

    while Enabled
        and not Destroyed
        and IsReeling()
    do

        ----------------------------------------------------
        -- OBJECT CHECK
        ----------------------------------------------------

        if not Fishing.Parent
            or not MainFrame.Parent
            or not Fish.Parent
            or not Move.Parent
        then

            MouseUp()

            return

        end

        ----------------------------------------------------
        -- WAIT FRAME
        ----------------------------------------------------

        local dt =
            RunService.RenderStepped:Wait()

        dt =
            math.max(
                dt,
                1 / 240
            )

        ----------------------------------------------------
        -- FISH RANGE
        ----------------------------------------------------

        local FishLeft,
            FishRight,
            FishScale =
            GetFishRange(
                MainFrame,
                Fish
            )

        if not FishLeft then
            continue
        end

        ----------------------------------------------------
        -- MOVE RANGE
        ----------------------------------------------------

        local MoveLeft,
            MoveRight,
            MoveSize =
            GetMoveRange(
                Move
            )

        ----------------------------------------------------
        -- CENTER
        ----------------------------------------------------

        local FishCenter =
            (FishLeft + FishRight) / 2

        local MoveCenter =
            (MoveLeft + MoveRight) / 2

        ----------------------------------------------------
        -- VELOCITY
        ----------------------------------------------------

        if LastFishCenter ~= nil then

            local RawFishVelocity =
                (
                    FishCenter
                    - LastFishCenter
                ) / dt

            FishVelocity =
                FishVelocity * 0.65
                + RawFishVelocity * 0.35

        end

        if LastMoveCenter ~= nil then

            local RawMoveVelocity =
                (
                    MoveCenter
                    - LastMoveCenter
                ) / dt

            MoveVelocity =
                MoveVelocity * 0.60
                + RawMoveVelocity * 0.40

        end

        LastFishCenter =
            FishCenter

        LastMoveCenter =
            MoveCenter

        ----------------------------------------------------
        -- PREDICT
        ----------------------------------------------------

        local PredictedFishCenter =
            FishCenter
            + (
                FishVelocity
                * PREDICTION_TIME
            )

        PredictedFishCenter =
            math.clamp(
                PredictedFishCenter,
                -0.05,
                1.05
            )

        ----------------------------------------------------
        -- ERROR
        ----------------------------------------------------

        local Error =
            PredictedFishCenter
            - MoveCenter

        if math.abs(Error) <
            CENTER_ZONE
        then

            Error = 0

        end

        ----------------------------------------------------
        -- CONTROL
        ----------------------------------------------------

        local Control =
            (
                Error
                * CONTROL_GAIN
            )
            + (
                FishVelocity
                * VELOCITY_GAIN
            )
            - (
                MoveVelocity
                * MOVE_BRAKE_GAIN
            )

        ----------------------------------------------------
        -- EDGE DANGER
        ----------------------------------------------------

        local EdgeDanger = 0

        if FishLeft < 0.07 then

            EdgeDanger =
                math.clamp(
                    (0.07 - FishLeft)
                    / 0.07,
                    0,
                    1
                )

            Control =
                Control
                - (
                    EdgeDanger
                    * 1.5
                )

        elseif FishRight > 0.93 then

            EdgeDanger =
                math.clamp(
                    (FishRight - 0.93)
                    / 0.07,
                    0,
                    1
                )

            Control =
                Control
                + (
                    EdgeDanger
                    * 1.5
                )

        end

        ----------------------------------------------------
        -- STATE TIME
        ----------------------------------------------------

        local StateTime =
            os.clock()
            - StateStart

        ----------------------------------------------------
        -- DECISION
        ----------------------------------------------------

        if Holding then

            if StateTime >= MIN_HOLD_TIME
                and Control <
                    RELEASE_THRESHOLD
            then

                SetHolding(false)

            end

        else

            if StateTime >= MIN_RELEASE_TIME
                and Control >
                    HOLD_THRESHOLD
            then

                SetHolding(true)

            end

        end

        ----------------------------------------------------
        -- PROGRESS
        ----------------------------------------------------

        if Bar then

            local Progress =
                Bar.Size.X.Scale

            ------------------------------------------------
            -- SUCCESS
            ------------------------------------------------

            if Progress >= 0.995 then

                MouseUp()

                return

            end

            ------------------------------------------------
            -- FAIL
            ------------------------------------------------

            if Progress <= 0.001 then

                MouseUp()

                return

            end

        end

    end

    --------------------------------------------------------
    -- SAFETY
    --------------------------------------------------------

    MouseUp()

end

------------------------------------------------------------
-- QTE EVENT
------------------------------------------------------------

LocalPlayer:GetAttributeChangedSignal(
    "QTEEvent"
):Connect(function()

    local Event =
        GetQTEEvent()

    --------------------------------------------------------
    -- REEL
    --------------------------------------------------------

    if Event == "Reel Fish" then

        if Enabled
            and not Destroyed
        then
                    RestoreNormalFOV()

            ------------------------------------------------
            -- STOP CAST
            ------------------------------------------------

            CastActive = false
            CastReleased = false
            CastStartTime = 0

            MouseUp()

            ------------------------------------------------
            -- REEL STATE
            ------------------------------------------------

            FishState = "REEL"

            ReelRequested = true

            ------------------------------------------------
            -- M1 NGAY
            ------------------------------------------------

            MouseDown()

        end

        return

    end

    --------------------------------------------------------
    -- SHAKE
    --------------------------------------------------------

    if Event ~= "Timed Release" then

        if FindShake() then

            if FishState == "CAST"
                or FishState == "IDLE"
            then

                FishState = "SHAKE"

            end

        end

    end

end)

------------------------------------------------------------
-- MAIN AUTO FISH LOOP
------------------------------------------------------------

task.spawn(function()

    while not Destroyed do

        ----------------------------------------------------
        -- OFF
        ----------------------------------------------------

       if not Enabled then

    FishState = "IDLE"

    MouseUp()

    task.wait(0.15)

    continue

end

if StartingFish then

    MouseUp()

    task.wait(0.05)

    continue

end
        ----------------------------------------------------
        -- REEL
        ----------------------------------------------------

        if FishState == "REEL"
            or ReelRequested
            or IsReeling()
        then

            if not ReelRunning then

                ReelRunning = true

                FishState = "REEL"

                print("[REEL START]")

                AutoReel()

                ------------------------------------------------
                -- REEL DONE
                ------------------------------------------------

                MouseUp()

                ReelRunning = false
                ReelRequested = false

                ------------------------------------------------
                -- RESET CAST
                ------------------------------------------------

                CastActive = false
                CastReleased = false
                CastStartTime = 0

                ------------------------------------------------
                -- NEXT CAST
                ------------------------------------------------

                if Enabled
                    and not Destroyed
                then

                    FishState = "CAST"

                    print(
                        "[REEL DONE] -> CAST"
                    )

                else

                    FishState = "IDLE"

                end

            end

            task.wait(0.001)

            continue

        end

        ----------------------------------------------------
        -- SHAKE
        ----------------------------------------------------

        local ShakeButton =
            FindShake()

        if ShakeButton then

            FishState = "SHAKE"

            MouseUp()

            HandleShake()

            task.wait(
                SHAKE_DELAY
            )

            continue

        end

        ----------------------------------------------------
        -- CAST UPDATE
        ----------------------------------------------------

        if CastActive then

            FishState = "CAST"

            UpdateCast()

            task.wait(0.002)

            continue

        end

        ----------------------------------------------------
        -- START CAST
        ----------------------------------------------------

        FishState = "CAST"

        StartCast()

        task.wait(0.002)

    end

    --------------------------------------------------------
    -- FINAL SAFETY
    --------------------------------------------------------

    MouseUp()

end)

------------------------------------------------------------
-- CHARACTER RESPAWN
------------------------------------------------------------

LocalPlayer.CharacterAdded:Connect(function()

    FishState = "IDLE"

    ReelRequested = false
    ReelRunning = false

    CastActive = false
    CastReleased = false
    CastStartTime = 0

    MouseUp()

end)

------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------

task.spawn(function()

    while not Destroyed do

        if not LocalPlayer.Parent then

            Enabled = false

            FishState = "IDLE"

            ReelRequested = false
            ReelRunning = false

            CastActive = false
            CastReleased = false
            CastStartTime = 0

            MouseUp()

            break

        end

        task.wait(1)

    end

end)

------------------------------------------------------------
-- LOADED
------------------------------------------------------------
task.spawn(function()

    task.wait(1)

    if Destroyed then
        return
    end

    Enabled = true
    UpdateToggle()

    StartFishingSetup()

end)
print("[Auto Fishing] Loaded")
