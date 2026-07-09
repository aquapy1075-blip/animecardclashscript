-- ============================================
-- SPEED MODE - TỰ ĐỘNG BẬT KHI CHẠY
-- ============================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CẤU HÌNH
getgenv().SpeedMode = true
getgenv().BattlePlaybackSpeed = 20

-- HÀM GỌI CALLBACK
local function callLastCallback(...)
    local args = {...}
    for i = #args, 1, -1 do
        if typeof(args[i]) == "function" then
            task.defer(args[i])
            return true
        end
    end
end

-- HOOK MODULE
local function hook(moduleName, funcName, replace)
    for _, m in ipairs(getloadedmodules()) do
        if m.Name == moduleName then
            local mod = require(m)
            if type(mod) == "table" and type(mod[funcName]) == "function" then
                local old = mod[funcName]
                mod[funcName] = replace(old)
                print("✅ Hooked:", moduleName, funcName)
            end
        end
    end
end

-- SKIP ANIMATION
hook("BattleChoreoStartModule", "executePreEnterBattleEffect", function(old)
    return function(...)
        if getgenv().SpeedMode then
            callLastCallback(...)
            return 0
        end
        return old(...)
    end
end)

hook("BattleStartWindowController", "playStartAnimation", function(old)
    return function(...)
        if getgenv().SpeedMode then
            callLastCallback(...)
            return 0
        end
        return old(...)
    end
end)

hook("BattleStartWindowController", "playEndAnimation", function(old)
    return function(...)
        if getgenv().SpeedMode then
            callLastCallback(...)
            return 0
        end
        return old(...)
    end
end)

-- SKIP PET ATTACK ANIMATION
local AnimationConst
pcall(function()
    AnimationConst = require(ReplicatedStorage.Script.Animation.Basic.AnimationConst)
end)

local CommonAttackState = AnimationConst and AnimationConst.AnimationState and AnimationConst.AnimationState.commonAttack

for _, m in ipairs(getloadedmodules()) do
    if m.Name == "PetAnimationController" then
        local mod = require(m)
        if type(mod) == "table" and type(mod.changeState) == "function" then
            local old = mod.changeState
            mod.changeState = function(uid, state, model, ...)
                if getgenv().SpeedMode and state == CommonAttackState then
                    return
                end
                return old(uid, state, model, ...)
            end
            print("✅ Hooked PetAnimationController")
        end
        break
    end
end

-- TĂNG TỐC SKILL
local ctrl
for _, obj in ipairs(getgc(true)) do
    if type(obj) == "table" and type(rawget(obj, "getBattlePlaybackSpeed")) == "function" then
        ctrl = obj
        break
    end
end

if ctrl then
    local oldGetSpeed = ctrl.getBattlePlaybackSpeed
    ctrl.getBattlePlaybackSpeed = function(...)
        if getgenv().SpeedMode then
            return getgenv().BattlePlaybackSpeed or 20
        end
        return oldGetSpeed(...)
    end
    print("✅ Speed set to " .. (getgenv().BattlePlaybackSpeed or 20) .. "x")
end

-- SKIP CAPTURE ANIMATION
for _, m in ipairs(getloadedmodules()) do
    if m.Name == "CaptureFlowV2Module" then
        local mod = require(m)
        if mod and mod.start then
            mod.start = function(data, callback)
                if typeof(callback) == "function" then
                    task.defer(callback)
                end
                return 0
            end
            print("✅ Skip capture animation")
        end
        break
    end
end

print("🚀 SPEED MODE ACTIVATED!")
