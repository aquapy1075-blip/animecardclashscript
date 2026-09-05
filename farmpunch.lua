------------------------------------------------------------
-- WAIT FOR GAME
------------------------------------------------------------

repeat
    task.wait()
until game:IsLoaded()


------------------------------------------------------------
-- SERVICES
------------------------------------------------------------

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer


------------------------------------------------------------
-- ACCOUNT CHECK
------------------------------------------------------------

if not LocalPlayer or LocalPlayer.Name ~= "NuongNghibao" then
    return
end

local PlayerGui =
    LocalPlayer:WaitForChild("PlayerGui")


------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

local Enabled = true
local Destroyed = false


------------------------------------------------------------
-- TARGET
------------------------------------------------------------

local TARGET_POSITION =
    Vector3.new(252, 22, -201)

-- Player <= 5 studs -> hop ngay
local DANGER_DISTANCE = 5

-- Player <= 200 studs -> bắt đầu theo dõi
local PLAYER_DISTANCE = 200

-- Player > 5 và <= 200 studs trong 60s -> hop
local SERVER_HOP_TIME = 60


------------------------------------------------------------
-- TELEPORT
------------------------------------------------------------

local TELEPORT_DISTANCE = 300

local TELEPORT_COOLDOWN = 2


------------------------------------------------------------
-- TWEEN
------------------------------------------------------------

local TWEEN_SPEED = 100

local AFTER_TELEPORT_DELAY = 0.5

local AFTER_FACE_DELAY = 0.3


------------------------------------------------------------
-- M1
------------------------------------------------------------

local M1_COUNT = 4
local M1_DELAY = 0.35


------------------------------------------------------------
-- F
------------------------------------------------------------

local F_HOLD_TIME = 0.6
local AFTER_F_DELAY = 0.7


------------------------------------------------------------
-- STATE
------------------------------------------------------------

local PlayerDetectedTime = nil

local Teleporting = false
local FHeld = false

local LastTeleport = -math.huge

-- Đang M1 x4 + F
local CombatActive = false

-- Đã đủ điều kiện hop nhưng đang combat
local PendingServerHop = false

-- Player <= 5 studs
local DangerPlayerDetected = false


------------------------------------------------------------
-- CHARACTER
------------------------------------------------------------

local function GetCharacter()

    local Character =
        LocalPlayer.Character

    if not Character then
        return nil, nil, nil
    end

    local Humanoid =
        Character:FindFirstChildOfClass("Humanoid")

    local Root =
        Character:FindFirstChild("HumanoidRootPart")

    return Character, Humanoid, Root
end


------------------------------------------------------------
-- MAIN MENU
------------------------------------------------------------

local function CheckMainMenu()

    local MainMenu =
        PlayerGui:FindFirstChild("Main Menu")

    if not MainMenu then
        return false
    end

    print("[MAIN MENU] Detected")

    local MainMenuRemote =
        ReplicatedStorage
            :WaitForChild("Events")
            :WaitForChild("MainMenu")

    local args = {
        "Play"
    }

    MainMenuRemote:FireServer(unpack(args))

    print("[MAIN MENU] Play fired")

    local StartTime = os.clock()

    while
        PlayerGui:FindFirstChild("Main Menu")
        and os.clock() - StartTime < 15
    do
        task.wait(0.1)
    end

    if PlayerGui:FindFirstChild("Main Menu") then

        print(
            "[MAIN MENU] Still exists after 15s"
        )

    else

        print(
            "[MAIN MENU] Finished"
        )
    end

    return true
end


------------------------------------------------------------
-- CHECK MAIN MENU
------------------------------------------------------------

CheckMainMenu()


------------------------------------------------------------
-- IS AT TARGET
------------------------------------------------------------

local function IsAtTarget()

    local Character, Humanoid, Root =
        GetCharacter()

    if
        not Character
        or not Humanoid
        or not Root
    then
        return false
    end

    if Humanoid.Health <= 0 then
        return false
    end

    return (
        Root.Position - TARGET_POSITION
    ).Magnitude <= 5
end


------------------------------------------------------------
-- GET CLOSEST PLAYER DISTANCE
------------------------------------------------------------

local function GetClosestPlayerDistance()

    local ClosestDistance = math.huge

    for _, Player in ipairs(
        Players:GetPlayers()
    ) do

        if Player ~= LocalPlayer then

            local Character =
                Player.Character

            if Character then

                local Root =
                    Character:FindFirstChild(
                        "HumanoidRootPart"
                    )

                local Humanoid =
                    Character:FindFirstChildOfClass(
                        "Humanoid"
                    )

                if
                    Root
                    and Humanoid
                    and Humanoid.Health > 0
                then

                    local Distance =
                        (
                            Root.Position
                            - TARGET_POSITION
                        ).Magnitude

                    if Distance < ClosestDistance then
                        ClosestDistance = Distance
                    end
                end
            end
        end
    end

    return ClosestDistance
end


------------------------------------------------------------
-- PLAYER NEAR TARGET
------------------------------------------------------------

local function IsPlayerNearTarget()

    return GetClosestPlayerDistance()
        <= PLAYER_DISTANCE
end


------------------------------------------------------------
-- DANGER PLAYER
-- <= 5 STUDS
------------------------------------------------------------

local function IsDangerPlayerNear()

    return GetClosestPlayerDistance()
        <= DANGER_DISTANCE
end


------------------------------------------------------------
-- GET TRAINING DUMMY
------------------------------------------------------------

local function GetTrainingDummy()

    local Entities =
        workspace:FindFirstChild("Entities")

    if not Entities then

        warn(
            "[TARGET] Entities not found"
        )

        return nil
    end

    local Dummy =
        Entities:FindFirstChild(
            "Training Dummy5"
        )

    if not Dummy then

        warn(
            "[TARGET] Training Dummy5 not found"
        )

        return nil
    end

    return Dummy
end


------------------------------------------------------------
-- GET DUMMY ROOT
------------------------------------------------------------

local function GetDummyRoot(Dummy)

    if not Dummy then
        return nil
    end

    local DummyRoot =
        Dummy:FindFirstChild(
            "HumanoidRootPart"
        )

    if DummyRoot then
        return DummyRoot
    end

    DummyRoot =
        Dummy:FindFirstChildWhichIsA(
            "BasePart",
            true
        )

    return DummyRoot
end


------------------------------------------------------------
-- FACE TRAINING DUMMY
------------------------------------------------------------

local function FaceTrainingDummy()

    if Destroyed or not Enabled then
        return false
    end

    local Character, Humanoid, Root =
        GetCharacter()

    if
        not Character
        or not Humanoid
        or not Root
    then
        return false
    end

    if Humanoid.Health <= 0 then
        return false
    end

    local Dummy =
        GetTrainingDummy()

    if not Dummy then
        return false
    end

    local DummyRoot =
        GetDummyRoot(Dummy)

    if not DummyRoot then

        warn(
            "[TARGET] Training Dummy5 root not found"
        )

        return false
    end

    local CurrentPosition =
        Root.Position

    local LookPosition =
        Vector3.new(
            DummyRoot.Position.X,
            CurrentPosition.Y,
            DummyRoot.Position.Z
        )

    Root.CFrame =
        CFrame.lookAt(
            CurrentPosition,
            LookPosition
        )

    print(
        "[TARGET] Facing Training Dummy5"
    )

    return true
end


------------------------------------------------------------
-- RELEASE F
------------------------------------------------------------

local function ReleaseF()

    if FHeld then

        VIM:SendKeyEvent(
            false,
            Enum.KeyCode.F,
            false,
            game
        )

        FHeld = false
    end
end


------------------------------------------------------------
-- SERVER HOP
------------------------------------------------------------

local function ServerHop()

    if
        Destroyed
        or not Enabled
    then
        return
    end

    --------------------------------------------------------
    -- KHÔNG INTERRUPT COMBAT
    --------------------------------------------------------

    if CombatActive then

        PendingServerHop = true

        print(
            "[SERVER HOP] Pending - combat active"
        )

        return
    end

    PlayerDetectedTime = nil
    PendingServerHop = false

    DangerPlayerDetected = false

    ReleaseF()

    print(
        "[SERVER HOP] QuickJoin"
    )

    local TeleportServiceRemote =
        ReplicatedStorage
            :WaitForChild("Events")
            :WaitForChild("TeleportService")

    local args = {
        "QuickJoin"
    }

    TeleportServiceRemote:FireServer(
        unpack(args)
    )
end


------------------------------------------------------------
-- TELEPORT DIRECT
------------------------------------------------------------

local function DirectTeleport()

    if
        Destroyed
        or not Enabled
        or Teleporting
    then
        return false
    end

    if
        os.clock() - LastTeleport
        < TELEPORT_COOLDOWN
    then
        return false
    end

    local Character, Humanoid, Root =
        GetCharacter()

    if
        not Character
        or not Humanoid
        or not Root
    then
        return false
    end

    if Humanoid.Health <= 0 then
        return false
    end

    local Distance =
        (
            Root.Position
            - TARGET_POSITION
        ).Magnitude

    if Distance <= 5 then
        return false
    end

    Teleporting = true
    LastTeleport = os.clock()

    print(
        "[SAFE] Distance:",
        math.floor(Distance),
        "-> DIRECT TELEPORT"
    )

    Root.CFrame =
        CFrame.new(
            TARGET_POSITION
        )

    task.wait(
        AFTER_TELEPORT_DELAY
    )

    if
        Destroyed
        or not Enabled
    then

        Teleporting = false

        return false
    end

    if not IsAtTarget() then

        Teleporting = false

        return false
    end

    FaceTrainingDummy()

    task.wait(
        AFTER_FACE_DELAY
    )

    Teleporting = false

    print(
        "[SAFE] Direct teleport finished"
    )

    return true
end


------------------------------------------------------------
-- TWEEN TO TARGET
------------------------------------------------------------

local function TweenToTarget()

    if
        Teleporting
        or Destroyed
        or not Enabled
    then
        return false
    end

    if
        os.clock() - LastTeleport
        < TELEPORT_COOLDOWN
    then
        return false
    end

    --------------------------------------------------------
    -- PLAYER ĐANG GẦN -> KHÔNG TWEEN
    --------------------------------------------------------

    if IsPlayerNearTarget() then
        return false
    end

    local Character, Humanoid, Root =
        GetCharacter()

    if
        not Character
        or not Humanoid
        or not Root
    then
        return false
    end

    if Humanoid.Health <= 0 then
        return false
    end

    local Distance =
        (
            Root.Position
            - TARGET_POSITION
        ).Magnitude

    if Distance <= 5 then
        return false
    end

    --------------------------------------------------------
    -- XA > 300 -> DIRECT TELEPORT
    --------------------------------------------------------

    if Distance > TELEPORT_DISTANCE then

        return DirectTeleport()
    end

    --------------------------------------------------------
    -- 5 -> 300 -> TWEEN
    --------------------------------------------------------

    Teleporting = true
    LastTeleport = os.clock()

    print(
        "[SAFE] Tweening to target | Distance:",
        math.floor(Distance)
    )

    local TweenTime =
        math.max(
            Distance / TWEEN_SPEED,
            0.1
        )

    local Tween =
        TweenService:Create(
            Root,
            TweenInfo.new(
                TweenTime,
                Enum.EasingStyle.Linear,
                Enum.EasingDirection.Out
            ),
            {
                CFrame =
                    CFrame.new(
                        TARGET_POSITION
                    )
            }
        )

    Tween:Play()

    while
        Tween.PlaybackState
        == Enum.PlaybackState.Playing
    do

        if
            Destroyed
            or not Enabled
        then

            Tween:Cancel()
            Teleporting = false

            return false
        end

        ----------------------------------------------------
        -- PLAYER <= 5
        -- STOP TWEEN + HOP
        ----------------------------------------------------

        if IsDangerPlayerNear() then

            print(
                "[SAFE] DANGER PLAYER <= 5 STUDS"
            )

            Tween:Cancel()

            Teleporting = false

            ServerHop()

            return false
        end

        ----------------------------------------------------
        -- PLAYER <= 200
        -- STOP TWEEN
        ----------------------------------------------------

        if IsPlayerNearTarget() then

            print(
                "[SAFE] Player appeared - cancel tween"
            )

            Tween:Cancel()

            Teleporting = false

            return false
        end

        local CurrentCharacter,
            CurrentHumanoid,
            CurrentRoot =
            GetCharacter()

        if
            not CurrentCharacter
            or not CurrentHumanoid
            or not CurrentRoot
            or CurrentHumanoid.Health <= 0
        then

            Tween:Cancel()

            Teleporting = false

            return false
        end

        task.wait(0.05)
    end

    if
        Tween.PlaybackState
        ~= Enum.PlaybackState.Completed
    then

        Teleporting = false

        return false
    end

    task.wait(
        AFTER_TELEPORT_DELAY
    )

    if
        Destroyed
        or not Enabled
    then

        Teleporting = false

        return false
    end

    if not IsAtTarget() then

        Teleporting = false

        return false
    end

    --------------------------------------------------------
    -- CHECK DANGER SAU KHI TỚI
    --------------------------------------------------------

    if IsDangerPlayerNear() then

        Teleporting = false

        ServerHop()

        return false
    end

    if not FaceTrainingDummy() then

        Teleporting = false

        return false
    end

    task.wait(
        AFTER_FACE_DELAY
    )

    Teleporting = false

    print(
        "[SAFE] Tween sequence finished"
    )

    return true
end


------------------------------------------------------------
-- PREPARE TARGET
------------------------------------------------------------

local function PrepareTarget()

    if
        Destroyed
        or not Enabled
    then
        return false
    end

    --------------------------------------------------------
    -- ĐÃ Ở TARGET
    --------------------------------------------------------

    if IsAtTarget() then

        ----------------------------------------------------
        -- PLAYER <= 5 -> HOP
        ----------------------------------------------------

        if IsDangerPlayerNear() then

            ServerHop()

            return false
        end

        ----------------------------------------------------
        -- PLAYER > 5 -> VẪN COMBAT
        ----------------------------------------------------

        if not FaceTrainingDummy() then
            return false
        end

        task.wait(
            AFTER_FACE_DELAY
        )

        return true
    end

    --------------------------------------------------------
    -- CHƯA Ở TARGET
    --------------------------------------------------------

    if IsDangerPlayerNear() then

        ServerHop()

        return false
    end

    --------------------------------------------------------
    -- PLAYER <= 200 -> KHÔNG TWEEN
    --------------------------------------------------------

    if IsPlayerNearTarget() then
        return false
    end

    --------------------------------------------------------
    -- > 300 -> TELE
    -- <= 300 -> TWEEN
    --------------------------------------------------------

    return TweenToTarget()
end


------------------------------------------------------------
-- M1
------------------------------------------------------------

local function M1()

    if
        not Enabled
        or Destroyed
    then
        return false
    end

    if not IsAtTarget() then
        return false
    end

    VIM:SendMouseButtonEvent(
        0,
        0,
        0,
        true,
        game,
        0
    )

    VIM:SendMouseButtonEvent(
        0,
        0,
        0,
        false,
        game,
        0
    )

    return true
end


------------------------------------------------------------
-- HOLD F
------------------------------------------------------------

local function HoldF()

    if
        not Enabled
        or Destroyed
    then
        return false
    end

    if not IsAtTarget() then
        return false
    end

    FHeld = true

    VIM:SendKeyEvent(
        true,
        Enum.KeyCode.F,
        false,
        game
    )

    local StartTime =
        os.clock()

    while
        Enabled
        and not Destroyed
        and os.clock() - StartTime < F_HOLD_TIME
    do

        if not IsAtTarget() then
            break
        end

        task.wait(0.05)
    end

    ReleaseF()

    return true
end


------------------------------------------------------------
-- PLAYER / SAFE CHECK LOOP
------------------------------------------------------------

task.spawn(function()

    while not Destroyed do

        if Enabled then

            local ClosestDistance =
                GetClosestPlayerDistance()

            ------------------------------------------------
            -- NO PLAYER
            ------------------------------------------------

            if ClosestDistance == math.huge then

                PlayerDetectedTime = nil
                PendingServerHop = false
                DangerPlayerDetected = false

                ------------------------------------------------
                -- TWEEN / TELEPORT
                ------------------------------------------------

                if
                    not IsAtTarget()
                    and not Teleporting
                    and not CombatActive
                then

                    TweenToTarget()
                end

            ------------------------------------------------
            -- DANGER <= 5
            ------------------------------------------------

            elseif ClosestDistance <= DANGER_DISTANCE then

                if not DangerPlayerDetected then

                    DangerPlayerDetected = true

                    print(
                        "[DANGER] Player <= 5 studs"
                    )
                end

                ------------------------------------------------
                -- COMBAT ĐANG CHẠY
                -- ĐỢI COMBO XONG
                ------------------------------------------------

                if CombatActive then

                    PendingServerHop = true

                    print(
                        "[DANGER] Waiting for combat to finish"
                    )

                else

                    ------------------------------------------------
                    -- KHÔNG COMBAT -> HOP NGAY
                    ------------------------------------------------

                    ServerHop()
                end

            ------------------------------------------------
            -- PLAYER > 5 VÀ <= 200
            ------------------------------------------------

            elseif ClosestDistance <= PLAYER_DISTANCE then

                DangerPlayerDetected = false

                if not PlayerDetectedTime then

                    PlayerDetectedTime =
                        os.clock()

                    print(
                        "[SAFE] Player detected | Distance:",
                        math.floor(ClosestDistance)
                    )
                end

                local WaitTime =
                    os.clock()
                    - PlayerDetectedTime

                ------------------------------------------------
                -- ĐỦ 60S
                ------------------------------------------------

                if WaitTime >= SERVER_HOP_TIME then

                    if CombatActive then

                        PendingServerHop = true

                        print(
                            "[SERVER HOP] 60s reached - waiting for combat"
                        )

                    else

                        ServerHop()
                    end
                end

            ------------------------------------------------
            -- PLAYER > 200
            ------------------------------------------------

            else

                PlayerDetectedTime = nil
                PendingServerHop = false
                DangerPlayerDetected = false

                ------------------------------------------------
                -- CHO PHÉP TỚI TARGET
                ------------------------------------------------

                if
                    not IsAtTarget()
                    and not Teleporting
                    and not CombatActive
                then

                    TweenToTarget()
                end
            end

        else

            PlayerDetectedTime = nil
            PendingServerHop = false
            DangerPlayerDetected = false
        end

        task.wait(0.2)
    end
end)


------------------------------------------------------------
-- MAIN M1 + F LOOP
------------------------------------------------------------

task.spawn(function()

    while not Destroyed do

        if not Enabled then

            task.wait(0.1)

            continue
        end

        ----------------------------------------------------
        -- PREPARE TARGET
        ----------------------------------------------------

        if not PrepareTarget() then

            task.wait(0.1)

            continue
        end

        ----------------------------------------------------
        -- CHECK TARGET
        ----------------------------------------------------

        if
            not Enabled
            or Destroyed
            or not IsAtTarget()
        then

            task.wait(0.1)

            continue
        end

        ----------------------------------------------------
        -- BẮT ĐẦU COMBAT
        ----------------------------------------------------

        CombatActive = true

        local CompletedM1 = true

        ----------------------------------------------------
        -- M1 x4
        ----------------------------------------------------

        for i = 1, M1_COUNT do

            if
                not Enabled
                or Destroyed
            then

                CompletedM1 = false

                break
            end

            if not IsAtTarget() then

                CompletedM1 = false

                break
            end

            if not M1() then

                CompletedM1 = false

                break
            end

            if i < M1_COUNT then

                task.wait(
                    M1_DELAY
                )
            end
        end

        ----------------------------------------------------
        -- F
        ----------------------------------------------------

        if
            CompletedM1
            and Enabled
            and not Destroyed
            and IsAtTarget()
        then

            HoldF()

            if
                Enabled
                and not Destroyed
            then

                task.wait(
                    AFTER_F_DELAY
                )
            end
        end

        ----------------------------------------------------
        -- COMBAT END
        ----------------------------------------------------

        CombatActive = false

        ----------------------------------------------------
        -- KIỂM TRA PLAYER SAU COMBAT
        ----------------------------------------------------

        if
            Enabled
            and not Destroyed
        then

            local ClosestDistance =
                GetClosestPlayerDistance()

            ------------------------------------------------
            -- <= 5 -> HOP NGAY
            ------------------------------------------------

            if
                ClosestDistance
                <= DANGER_DISTANCE
            then

                print(
                    "[SERVER HOP] Player <= 5 after combat"
                )

                ServerHop()

            ------------------------------------------------
            -- PENDING 60S
            ------------------------------------------------

            elseif
                PendingServerHop
                and ClosestDistance
                    <= PLAYER_DISTANCE
            then

                print(
                    "[SERVER HOP] Pending condition reached - QuickJoin"
                )

                ServerHop()

            else

                PendingServerHop = false

                if
                    ClosestDistance
                    > PLAYER_DISTANCE
                then

                    PlayerDetectedTime = nil
                end
            end
        end
    end
end)


------------------------------------------------------------
-- UI
------------------------------------------------------------

local ScreenGui =
    Instance.new("ScreenGui")

ScreenGui.Name =
    "M1F_UI"

ScreenGui.ResetOnSpawn =
    false

ScreenGui.ZIndexBehavior =
    Enum.ZIndexBehavior.Sibling

ScreenGui.Parent =
    CoreGui


------------------------------------------------------------
-- MAIN BUTTON
------------------------------------------------------------

local Button =
    Instance.new("TextButton")

Button.Name =
    "Toggle"

Button.Size =
    UDim2.new(
        0,
        160,
        0,
        45
    )

Button.Position =
    UDim2.new(
        0.5,
        -80,
        0.1,
        0
    )

Button.BackgroundColor3 =
    Color3.fromRGB(
        40,
        150,
        70
    )

Button.BorderSizePixel =
    0

Button.Text =
    "M1 + F: ON"

Button.TextColor3 =
    Color3.new(
        1,
        1,
        1
    )

Button.TextSize =
    18

Button.Font =
    Enum.Font.GothamBold

Button.Parent =
    ScreenGui


------------------------------------------------------------
-- CORNER
------------------------------------------------------------

local Corner =
    Instance.new("UICorner")

Corner.CornerRadius =
    UDim.new(
        0,
        8
    )

Corner.Parent =
    Button


------------------------------------------------------------
-- CLOSE BUTTON
------------------------------------------------------------

local CloseButton =
    Instance.new("TextButton")

CloseButton.Name =
    "Close"

CloseButton.Size =
    UDim2.new(
        0,
        24,
        0,
        24
    )

CloseButton.Position =
    UDim2.new(
        1,
        -27,
        0,
        3
    )

CloseButton.BackgroundColor3 =
    Color3.fromRGB(
        120,
        30,
        30
    )

CloseButton.BorderSizePixel =
    0

CloseButton.Text =
    "X"

CloseButton.TextColor3 =
    Color3.new(
        1,
        1,
        1
    )

CloseButton.TextSize =
    14

CloseButton.Font =
    Enum.Font.GothamBold

CloseButton.Parent =
    Button


------------------------------------------------------------
-- CLOSE CORNER
------------------------------------------------------------

local CloseCorner =
    Instance.new("UICorner")

CloseCorner.CornerRadius =
    UDim.new(
        1,
        0
    )

CloseCorner.Parent =
    CloseButton


------------------------------------------------------------
-- UPDATE UI
------------------------------------------------------------

local function UpdateUI()

    if Enabled then

        Button.Text =
            "M1 + F: ON"

        Button.BackgroundColor3 =
            Color3.fromRGB(
                40,
                150,
                70
            )

    else

        Button.Text =
            "M1 + F: OFF"

        Button.BackgroundColor3 =
            Color3.fromRGB(
                170,
                50,
                50
            )
    end
end


------------------------------------------------------------
-- TOGGLE
------------------------------------------------------------

Button.MouseButton1Click:Connect(function()

    if Destroyed then
        return
    end

    Enabled = not Enabled

    if not Enabled then

        PlayerDetectedTime = nil
        PendingServerHop = false
        DangerPlayerDetected = false

        ReleaseF()
    end

    UpdateUI()
end)


------------------------------------------------------------
-- CLOSE
------------------------------------------------------------

CloseButton.MouseButton1Click:Connect(function()

    Destroyed = true
    Enabled = false

    PlayerDetectedTime = nil
    PendingServerHop = false
    DangerPlayerDetected = false
    CombatActive = false

    ReleaseF()

    if ScreenGui then
        ScreenGui:Destroy()
    end
end)


------------------------------------------------------------
-- CHARACTER RESPAWN
------------------------------------------------------------

LocalPlayer.CharacterAdded:Connect(function()

    PlayerDetectedTime = nil
    PendingServerHop = false
    DangerPlayerDetected = false

    Teleporting = false
    CombatActive = false

    LastTeleport = -math.huge

    ReleaseF()

    task.wait(1)

    if
        Enabled
        and not Destroyed
        and not IsDangerPlayerNear()
        and not IsPlayerNearTarget()
    then

        TweenToTarget()
    end
end)


------------------------------------------------------------
-- INITIAL UI
------------------------------------------------------------

UpdateUI()


------------------------------------------------------------
-- DEBUG
------------------------------------------------------------

print("--------------------------------------")
print("[M1 + F] Loaded")
print("[M1 + F] Account:", LocalPlayer.Name)
print("[M1 + F] Status: ON")
print("[TARGET]", TARGET_POSITION)
print("[DANGER DISTANCE]", DANGER_DISTANCE)
print("[PLAYER DISTANCE]", PLAYER_DISTANCE)
print("[SERVER HOP TIME]", SERVER_HOP_TIME)
print("[DIRECT TELEPORT DISTANCE]", TELEPORT_DISTANCE)
print("[TWEEN SPEED]", TWEEN_SPEED)
print("[M1 COUNT]", M1_COUNT)
print("[M1 DELAY]", M1_DELAY)
print("[F HOLD]", F_HOLD_TIME)
print("[F AFTER DELAY]", AFTER_F_DELAY)
print("[COMBAT PROTECTION] ON")
print("--------------------------------------")
