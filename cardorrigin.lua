--[[
 ANIME ORIGIN V10.7 | Add Multi-Siege (12-stage round-robin + server cooldown), Siege/Boss/Rift arbiter
  Colosseum: remote state machine; no game UI, NPC, world teleport or replay.
  Colosseum / Rift Gate / Multi-Boss / Raid / Siege / Settings / Config
 Game source: provided rbxl + prior working V8.2/V5 scripts.
 Original battle/remote validation is handled by the game server.
]]
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local GuiService = game:GetService('GuiService')
local TeleportService = game:GetService('TeleportService')
local VIM = game:GetService('VirtualInputManager')
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild('PlayerGui')
local env = (getgenv and getgenv()) or _G
local function loadUILibrary()
    if type(env.AnimeOriginUILibrary)=='table' and env.AnimeOriginUILibrary.Version==1
        and type(env.AnimeOriginUILibrary.Create)=='function' then
        return env.AnimeOriginUILibrary
    end
    assert(type(loadstring)=='function','This executor must support loadstring')
    local ok,library=pcall(function()
        return loadstring(game:HttpGet(
            'https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/main/anime_origin_ui.lua'
        ))()
    end)
    assert(ok,'Cannot load Anime Origin UI from GitHub: '..tostring(library))
    assert(type(library)=='table' and library.Version==1 and type(library.Create)=='function',
        'Incompatible Anime Origin UI library')
    return library
end
local UILibrary=loadUILibrary()

-- Stop any older controllers: running two Colosseum or Rift loops causes collisions.
for _,key in ipairs({
    'AnimeOriginV10_7','AnimeOriginV10_6','AnimeOriginV10_5','AnimeOriginV10_4','AnimeOriginV10_3','AnimeOriginV10_2','AnimeOriginV10_1','AnimeOriginV10','AnimeOriginV9','AnimeOriginRemoteBossTest','AnimeOriginV82','AnimeOriginV81','AnimeOriginV8','AutoColoPDFGen2V7','AutoColoPDFV61','AutoColoPDFV6',
    'AutoColoPDFV5','AutoColoHellV4','AutoColoV32','AutoColoV31',
    'AutoColoV3','AutoColoV2','ColosseumRebuilt','AutoColosseumV1',
    'AutoColosseumV11','ColoController','RiftGateAutoLogV2'
}) do
    local old=env[key]
    if type(old)=='table' then
        old.alive=false; old.enabled=false; old.on=false; old.running=false
        if old.gui then pcall(function() old.gui:Destroy() end) end
        if old.window then pcall(function() old.window:Unload() end) end
        for _,con in ipairs(old.connections or {}) do pcall(function() con:Disconnect() end) end
        if type(old.stop)=='function' then pcall(old.stop) end
    end
end
for _,gui in ipairs(playerGui:GetChildren()) do
    if gui:IsA('ScreenGui') and (
        gui.Name=='AnimeOriginV10_7_UI' or gui.Name=='AnimeOriginV10_6_UI' or gui.Name=='AnimeOriginV10_5_UI' or gui.Name=='AnimeOriginV10_4_UI' or gui.Name=='AnimeOriginV10_3_UI' or gui.Name=='AnimeOriginV10_2_UI' or gui.Name=='AnimeOriginV10_1_UI' or gui.Name=='AnimeOriginV10_UI' or gui.Name=='AnimeOriginV9_UI' or
        gui.Name=='AnimeOriginBossRemoteTest' or
        gui.Name=='RiftGateAutoV2_UI' or
        gui.Name:match('^AutoColosseum.+Controller$')
    ) then pcall(function() gui:Destroy() end) end
end

local cfg={
    autoRerun=true, -- continuous farm while AUTO ON; deliberately no UI toggle
    wantHell=true,
    wantEndless=true,
    stopSpec='30-40',
    remoteColo=true,
    maxDraftRerolls=4,
    restartUntilCarry=true, -- PDF carry search is always enabled; no UI option
    allowSupports=true,
    poll=.25,
}
local rng=Random.new()
local state={
    alive=true, enabled=false, remoteColo=cfg.remoteColo,
    phase='', pending=nil, blocked=false, verified=0,
    stopFloor=nil,runCount=0,lastSeenWave=0,
    carryName=nil,carrySlot=nil,carryHp=nil,carryDmg=nil,
    carryImmunity=false,carryDodge=false,noCarry=false,
    supportCount=0,curseCount=0,sacredChosen={},draftRerolls=0,
    transportStage='idle',transportAt=0,transportAttempts=0,transportOrigin=nil,
    transportStatus='Ready',reconnectStatus='Monitoring',
}
env.AnimeOriginV10_7=state
-- No Colosseum logs, snapshots, copies or file writes.  Errors remain on UI
-- via state.blockedReason, without paying IO/string cost on gameplay ticks.
local function coloPause(reason)
    if state.blocked then return end
    state.blocked=true
    state.blockedReason=tostring(reason or 'Colosseum action could not continue')
end
-- The game controls Colosseum run persistence. We preserve *client* draft,
-- blessing, floor and pending state while Rift owns the controls; never press
-- START NEW RUN on a return where the old server run is not verified.
local handoff={requested=false,active=false,returning=false,requestedAt=0,
    fromPhase=nil,fromRun=0,fromWave=0,requireResume=false,
    returnAt=0,returnTeleportSent=false,startedAt=0,suppressUntil=0}
local function beginColoReturn()
    if not handoff.active or handoff.returning then return end
    handoff.active=false
    handoff.requested=false
    handoff.returning=true
    handoff.returnAt=os.clock()
    handoff.returnTeleportSent=false
    state.transportStage='idle'
    state.transportAt=0
    state.transportAttempts=0
    state.transportOrigin=nil
    state.transportStatus='Returning to interrupted Colosseum run'
end

-- Shared battle arbiter: Rift events have priority over Raid and Boss. The
-- two remote battle engines take turns instead of opening battles together.
local combat={owner=nil,since=0,last='boss'}
local function tryCombat(owner)
    if not state.alive or combat.owner then return false end
    local rs=env.RiftGateAutoLogV2
    if rs and rs.on and rs.runActive then return false end
    combat.owner=owner
    combat.since=os.clock()
    return true
end
local function freeCombat(owner)
    if combat.owner==owner then
        combat.owner=nil
        combat.last=owner
        combat.since=os.clock()
    end
end

-- RIFT GATE | exact live-event flow without its former independent UI.
local function createRiftGateController()
    local Players=game:GetService('Players')
    local Workspace=game:GetService('Workspace')
    local RS=game:GetService('ReplicatedStorage')
    local VIM=game:GetService('VirtualInputManager')
    local player=Players.LocalPlayer
    local pg=player:WaitForChild('PlayerGui')
local cfg = {
    poll = 0.35,
    actionGap = 1.3,
    ackTime = 2.3,
    usePrompt = true,
    autoLeave = true,
    autoOpenChip = true,
    moveToFightNPC = true,
    maxMoveDistance = 85, -- walk only when inside Rift and NPC is nearby
    leaveDelay = 3.0,
    minEntryGap = 15 * 60,  -- no more than one new Rift per rolling 15 minutes
    postClearGap = 10 * 60, -- do not enter a Rift until 10 minutes after clear
}
local s = {
    alive = true, on = false, connections = {},
    phase = 'WAITING', status = 'OFF',
    actions = 0, clears = 0, lastAction = 0, pending = nil,
    rewardAt = 0, clearedAt = 0, isCleared = false, battleFinishedAt = 0,
    lastPrompt = 0, lastWalk = 0, lastSearch = 0, cachedFight = nil,
    eventAttempt = {}, fails = {}, lastEvent = '', lastPhase = '',
    runActive = false, didEnter = false, fightStarted = false,
    lastEntryEpoch = 0, lastClearEpoch = 0,
}
env.RiftGateAutoLogV2 = s

-- Persistent, wall-clock Rift cooldown. Not part of the UI profile: swapping
-- profiles or re-executing the script must NOT reset the run rate limit.
local wallTime = function() return os.time() end
local timerFile = 'AnimeOriginV9/rift_rate_limit.json'
local hsvc = game:GetService('HttpService')
local sharedTimer = env.AnimeOriginRiftRateLimit
if type(sharedTimer)~='table' then sharedTimer={} end
local function validEpoch(value)
    value=tonumber(value) or 0
    if value<0 or value>wallTime()+180 then return 0 end
    return math.floor(value)
end
s.lastEntryEpoch=validEpoch(sharedTimer.lastEntryEpoch)
s.lastClearEpoch=validEpoch(sharedTimer.lastClearEpoch)
if type(readfile)=='function' then
    local ok,json=pcall(readfile,timerFile)
    if ok and type(json)=='string' then
        local decoded,d=pcall(function() return hsvc:JSONDecode(json) end)
        if decoded and type(d)=='table' then
            s.lastEntryEpoch=math.max(s.lastEntryEpoch,validEpoch(d.lastEntryEpoch))
            s.lastClearEpoch=math.max(s.lastClearEpoch,validEpoch(d.lastClearEpoch))
        end
    end
end
local function persistTimers()
    sharedTimer.lastEntryEpoch=s.lastEntryEpoch
    sharedTimer.lastClearEpoch=s.lastClearEpoch
    env.AnimeOriginRiftRateLimit=sharedTimer
    if type(writefile)~='function' then return end
    -- Some executors throw when makefolder is called on an existing folder.
    -- It must never prevent the subsequent writefile.
    if type(makefolder)=='function' then pcall(makefolder,'AnimeOriginV9') end
    pcall(function()
        writefile(timerFile,hsvc:JSONEncode({
            lastEntryEpoch=s.lastEntryEpoch,
            lastClearEpoch=s.lastClearEpoch,
        }))
    end)
end
-- Restore recent clear state to avoid rejoining the old popup on re-execute.
if s.lastClearEpoch>=s.lastEntryEpoch and s.lastClearEpoch>0
    and wallTime()-s.lastClearEpoch<cfg.minEntryGap then
    s.isCleared=true
end
local function secondsUntilNext()
    local now=wallTime()
    local entry=math.max(0,s.lastEntryEpoch+cfg.minEntryGap-now)
    local cleared=math.max(0,s.lastClearEpoch+cfg.postClearGap-now)
    return math.max(entry,cleared),entry,cleared
end
local function clockString(seconds)
    seconds=math.max(0,math.ceil(tonumber(seconds) or 0))
    return string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
end
local function recordEntry()
    s.lastEntryEpoch=wallTime()
    s.runActive=true
    s.didEnter=false
    s.fightStarted=false
    persistTimers()
end
local function recordClear()
    if s.isCleared then return end -- reward and CLEARED GUI may fire together
    -- A stale CLEARED banner after reload is not another victory.
    -- It must never extend the 10-minute lock indefinitely.
    if not s.runActive and s.lastClearEpoch>0
        and s.lastClearEpoch>=s.lastEntryEpoch then
        s.isCleared=true
        return
    end
    s.isCleared=true
    s.runActive=false
    s.lastClearEpoch=wallTime()
    s.clearedAt=os.clock()
    s.clears=s.clears+1
    s.pending=nil
    s.fails={}
    persistTimers()
end

local function tnow() return os.clock() end
local function trim(x)
    return tostring(x or ''):gsub('<[^>]*>', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end
local function upper(x) return trim(x):upper() end
local function has(x, y) return x:find(y, 1, true) ~= nil end
local function shown(obj)
    local v = obj
    while v and v ~= pg do
        if v:IsA('GuiObject') and not v.Visible then return false end
        if v:IsA('LayerCollector') and not v.Enabled then return false end
        v = v.Parent
    end
    return v == pg
end
-- Legacy recorder output disabled in Anime Origin.
local function log(_message) end
local function findAlert()
    local g = pg:FindFirstChild('RiftGateAlertGui')
    if g and g:IsA('ScreenGui') and g.Enabled then return g end
    return nil
end
local function visibleContains(root, text)
    if not root then return false end
    for _, d in ipairs(root:GetDescendants()) do
        if (d:IsA('TextLabel') or d:IsA('TextButton')) and shown(d) then
            if has(upper(d.Text), text) then return true end
        end
    end
    return false
end
local function visibleNamed(root, name)
    local o = root and root:FindFirstChild(name, true)
    if o and shown(o) then return o end
    return nil
end
local function buttonInside(o)
    if not o then return nil end
    if o:IsA('GuiButton') and shown(o) then return o end
    for _, c in ipairs(o:GetDescendants()) do
        if c:IsA('GuiButton') and shown(c) and c.Active then return c end
    end
    return nil
end
local function popupTeleportButton(alert)
    local popup = visibleNamed(alert, 'RiftPopup')
    if not popup or not visibleContains(popup, 'TAKE ME THERE') then return nil end
    -- In manual log the real button is RiftPopup.Frame[#5].TextButton[#1].
    -- It has no own text; sibling TextLabel says TAKE ME THERE.
    local frames = {}
    for _, c in ipairs(popup:GetChildren()) do
        if c.Name == 'Frame' and c:IsA('GuiObject') then frames[#frames+1] = c end
    end
    for _, frame in ipairs(frames) do
        if visibleContains(frame, 'TAKE ME THERE') then
            local b = buttonInside(frame)
            if b then return b end
        end
    end
    if #frames >= 5 then
        local b = buttonInside(frames[5])
        if b then return b end
    end
    return nil
end
local function chipButton(alert)
    local chip = visibleNamed(alert, 'RiftChip')
    if chip and chip:IsA('GuiButton') and chip.Active then return chip end
    return nil
end
local function leaveButton(alert)
    local bar = visibleNamed(alert, 'InRiftBar')
    if not bar or not visibleContains(bar, 'LEAVE RIFT') then return nil end
    -- Exact manual GUI structure: InRiftBar.Frame.Frame.TextButton.
    local frame = bar:FindFirstChild('Frame')
    local frame2 = frame and frame:FindFirstChild('Frame')
    if frame2 then return buttonInside(frame2) end
    return buttonInside(bar)
end
local function inGate(alert)
    return visibleNamed(alert, 'InRiftBar') ~= nil and visibleContains(alert, 'LEAVE RIFT')
end
local function battleActive()
    local g = pg:FindFirstChild('BattleGui2')
    local r = g and g:FindFirstChild('BattleRoot', true)
    if r and shown(r) and r.AbsoluteSize.X > 250 and r.AbsoluteSize.Y > 160 then
        return true
    end
    return false
end
local function clearText(alert)
    return visibleContains(alert, 'RIFT CLEARED')
end
local function findPrompt(name)
    local q = s.cachedFight
    if name == 'RiftFightPrompt' and q and q.Parent and q.Enabled then return q end
    -- Common location from the captured log, other Rift bosses may be named differently.
    local npc = Workspace:FindFirstChild('Sung Jin-woo')
    if npc then
        local p = npc:FindFirstChild(name, true)
        if p and p:IsA('ProximityPrompt') and p.Enabled then return p end
    end
    local p = Workspace:FindFirstChild(name, true)
    if p and p:IsA('ProximityPrompt') and p.Enabled then
        if name == 'RiftFightPrompt' then s.cachedFight = p end
        return p
    end
    return nil
end
local function promptDistance(p)
    local char = player.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root or not p or not p.Parent then return math.huge, nil, nil end
    local host = p.Parent
    local pos
    if host:IsA('Attachment') then pos = host.WorldPosition
    elseif host:IsA('BasePart') then pos = host.Position
    elseif host:IsA('Model') then
        local pp = host.PrimaryPart or host:FindFirstChildWhichIsA('BasePart')
        if pp then pos = pp.Position end
    end
    if not pos then return math.huge, nil, root end
    return (root.Position-pos).Magnitude, pos, root
end
local function firePrompt(p)
    if not p or not p.Enabled then return false, 'Prompt unavailable' end
    local distance = promptDistance(p)
    local maxD = p.MaxActivationDistance or 10
    if distance > maxD + 1.5 then return false, 'too far '..math.floor(distance) end
    if type(fireproximityprompt) == 'function' then
        local ok, err = pcall(function() fireproximityprompt(p) end)
        if ok then return true, 'fireproximityprompt' end
        
    end
    local hold = math.max(0.1, p.HoldDuration + 0.08)
    local ok, err = pcall(function()
        local key = p.KeyboardKeyCode
        if key == Enum.KeyCode.Unknown then key = Enum.KeyCode.E end
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(hold)
        VIM:SendKeyEvent(false, key, false, game)
    end)
    return ok, ok and 'VirtualInput E' or tostring(err)
end
local function mouseClick(btn)
    local p,z = btn.AbsolutePosition,btn.AbsoluteSize
    local x,y = p.X + z.X/2, p.Y + z.Y/2
    local ok, err = pcall(function()
        VIM:SendMouseButtonEvent(x,y,0,true,game,0)
        task.wait(0.11)
        VIM:SendMouseButtonEvent(x,y,0,false,game,0)
    end)
    if ok then return true,'VirtualInput' end
    return false,tostring(err)
end
local function signalClick(btn, event)
    if type(firesignal) ~= 'function' then return false,'firesignal missing' end
    local ok,err = pcall(function()
        if event == 'Activated' then firesignal(btn.Activated)
        else firesignal(btn.MouseButton1Click) end
    end)
    return ok,ok and ('firesignal '..event) or tostring(err)
end
local function clickAttempt(btn, n)
    if not btn or not btn.Parent or not shown(btn) then return false,'button no longer visible' end
    if n == 1 then
        local ok,what = signalClick(btn,'Activated')
        if ok then return ok,what end
        return mouseClick(btn)
    elseif n == 2 then
        return mouseClick(btn)
    else
        return signalClick(btn,'MouseButton1Click')
    end
end
local function phase()
    local alert = findAlert()
    if battleActive() then return 'BATTLE',alert,nil end
    if alert and clearText(alert) then return 'CLEARED',alert,nil end
    if alert and inGate(alert) then return 'INSIDE',alert,leaveButton(alert) end
    if alert then
        local b = popupTeleportButton(alert)
        if b then return 'TAKE_ME_THERE',alert,b end
        local chip = chipButton(alert)
        if chip then return 'RIFT_CHIP',alert,chip end
    end
    return 'WAITING',alert,nil
end
local function expectDone(action)
    local p = phase()
    if action == 'TAKE_ME_THERE' then return p == 'INSIDE' or p == 'BATTLE' or p == 'CLEARED' end
    if action == 'RIFT_CHIP' then return p == 'TAKE_ME_THERE' or p == 'INSIDE' end
    if action == 'LEAVE' then return not (findAlert() and inGate(findAlert())) end
    if action == 'FIGHT' then return p == 'BATTLE' or p == 'CLEARED' or s.rewardAt > s.lastAction end
    if action == 'LEAVE_PROMPT' then return not (findAlert() and inGate(findAlert())) end
    return false
end
local function schedule(action, btn)
    if not s.on or s.pending then return end
    if tnow()-s.lastAction < cfg.actionGap then return end
    local n = (s.fails[action] or 0)+1
    if n > 3 then
        s.status = 'NEED MANUAL: '..action
        
        s.fails[action] = 99
        return
    end
    local ok,method
    if action == 'FIGHT' or action == 'LEAVE_PROMPT' then
        ok,method = firePrompt(btn)
    else
        ok,method = clickAttempt(btn,n)
    end
    if not ok then

        s.fails[action] = n
        s.lastAction=tnow()
        return
    end
    s.actions=s.actions+1
    s.lastAction=tnow()
    s.pending={action=action,at=tnow(),attempt=n,method=method}
    s.status='Sent '..action..' via '..method

end
local function checkPending()
    local q=s.pending
    if not q then return end
    if expectDone(q.action) then
        if q.action=='FIGHT' then s.fightStarted=true end
        if q.action=='TAKE_ME_THERE' then s.didEnter=true end
        s.fails[q.action]=nil
        s.pending=nil
        return
    end
    local waitTime = (q.action == 'FIGHT') and 3.2 or cfg.ackTime
    if tnow()-q.at >= waitTime then

        s.fails[q.action]=q.attempt
        s.pending=nil
    end
end
local function walkToFight(prompt)
    if not cfg.moveToFightNPC or not prompt or not prompt.Enabled then return end
    if tnow()-s.lastWalk < 2.5 then return end
    local d,pos = promptDistance(prompt)
    if not pos or d > cfg.maxMoveDistance or d < prompt.MaxActivationDistance then return end
    local char=player.Character
    local humanoid=char and char:FindFirstChildWhichIsA('Humanoid')
    if humanoid then
        s.lastWalk=tnow()
        humanoid:MoveTo(pos)
        s.status='Walking to Rift NPC ('..math.floor(d)..' studs)'
    end
end
local function startNewEvent()
    s.isCleared=false
    s.clearedAt=0
    s.runActive=false
    s.didEnter=false
    s.fightStarted=false
    s.rewardAt=0
    s.battleFinishedAt=0
    s.fails={}
    s.pending=nil
    
end


    local function connect(signal, callback)
        local con=signal:Connect(callback)
        s.connections[#s.connections+1]=con
        return con
    end
    local remotes=RS:FindFirstChild('EventRemotes')
    local reward=remotes and remotes:FindFirstChild('RiftGateReward')
    if reward and reward:IsA('RemoteEvent') then
        connect(reward.OnClientEvent,function(data)
            if not s.alive then return end
            s.rewardAt=tnow()
            recordClear()
            local remaining=secondsUntilNext()
            s.status='Rift cleared. Next in '..clockString(remaining)
        end)
    end
    local lastPhase=''
    task.spawn(function()
        while s.alive and state.alive do
            local ok=pcall(function()
                if not s.on then s.phase='WAITING';s.status='AUTO OFF';return end
                local p,alert,btn=phase()
                s.phase=p
                if p~=lastPhase then
                    if lastPhase=='BATTLE' and (s.runActive or s.didEnter) then
                        s.battleFinishedAt=tnow()
                        s.fightStarted=true -- don't re-prompt a finished battle
                    end
                    lastPhase=p
                end
                if alert and clearText(alert) then recordClear() end
                checkPending()
                if not s.on or s.pending then return end

                local remaining,entryWait,clearWait=secondsUntilNext()
                -- Request preemption only when a fresh Rift can actually be
                -- entered (or an already-entered Rift must be finished).
                -- During a Colosseum wave BattleGui2 is owned by Colo, so
                -- do not take it away until that battle UI has completed.
                local eligible=(not s.isCleared and remaining<=0
                    and (p=='TAKE_ME_THERE' or p=='RIFT_CHIP' or p=='INSIDE'))
                    or s.runActive
                    or (s.isCleared and alert and inGate(alert))
                    or (p=='INSIDE' and s.lastEntryEpoch>s.lastClearEpoch)
                if state.enabled and not state.blocked and not state.remoteColo then
                    if handoff.returning then
                        s.status='Colosseum resuming; Rift standing by'
                        return
                    end
                    if not handoff.active then
                        -- An unresponsive Rift popup must not keep stealing
                        -- the Colo next-wave screen every tick.
                        if tnow()<handoff.suppressUntil then
                            handoff.requested=false
                            s.status='Rift entry retry deferred; Colo farming normally'
                        elseif eligible and p~='BATTLE' then
                            handoff.requested=true
                            handoff.requestedAt=tnow()
                            s.status='Rift ready: waiting for safe Colo boundary'
                        else
                            handoff.requested=false
                        end
                        return
                    end
                else
                    handoff.requested=false
                    if handoff.active and not handoff.returning then
                        -- Colosseum was disabled manually while Rift was up.
                        -- Do not force a return if its AUTO switch is OFF.
                        handoff.active=false
                    end
                end
                if handoff.active and s.isCleared and s.clearedAt>0
                    and tnow()-s.clearedAt>22 then
                    -- Emergency release if Rift's Leave button vanished after
                    -- clear. Returning uses the normal Colosseum world remote.
                    beginColoReturn()
                    s.status='Rift cleared; returning to Colosseum'
                    return
                end
                if handoff.active and not (alert and inGate(alert)) and
                    (s.isCleared or ((s.runActive or s.didEnter) and s.fightStarted and s.battleFinishedAt>0
                        and p~='BATTLE')) then
                    if not s.isCleared then
                        -- Loss / no reward: close this admission. Otherwise
                        -- runActive=true would request Rift again forever.
                        s.runActive=false
                        s.pending=nil
                        s.fightStarted=false
                        s.battleFinishedAt=0
                    end
                    beginColoReturn()
                    s.status='Rift finished; back to Colosseum'
                    return
                end
                if handoff.active and not s.isCleared and not s.didEnter
                    and p~='BATTLE' and p~='INSIDE'
                    and (tnow()-handoff.startedAt>35
                        or s.fails.TAKE_ME_THERE==99
                        or s.fails.RIFT_CHIP==99) then
                    -- V10.5 could freeze Colo indefinitely on an unclickable
                    -- Rift popup. Close only this failed admission and pause
                    -- preemption for 60s. Wall-clock 15min limit is untouched.
                    s.runActive=false
                    s.pending=nil
                    s.fightStarted=false
                    handoff.suppressUntil=tnow()+60
                    beginColoReturn()
                    s.status='Rift entry not acknowledged; returning to Colo'
                    return
                end
                if handoff.active and s.runActive and not s.isCleared
                    and s.battleFinishedAt>0 and tnow()-s.battleFinishedAt>45 then
                    s.runActive=false
                    s.fightStarted=false
                    s.battleFinishedAt=0
                    s.pending=nil
                    beginColoReturn()
                    s.status='Rift no result / leave missing; returning to Colo'
                    return
                end
                if p=='BATTLE' then
                    s.status='Battle in progress'
                    return
                end
                if s.isCleared then
                    -- On a cleared gate we may only LEAVE. Never reset
                    -- isCleared merely because the old TAKE ME THERE popup
                    -- reappears: that caused the V9 join/leave loop.
                    if (cfg.autoLeave or (state.enabled and handoff.active)) and alert and inGate(alert)
                        and tnow()-s.clearedAt>=cfg.leaveDelay then
                        local exit=findPrompt('RiftLeavePrompt')
                        if exit then
                            local d=promptDistance(exit)
                            if d<=exit.MaxActivationDistance+1.5 then
                                schedule('LEAVE_PROMPT',exit)
                            elseif leaveButton(alert) then
                                schedule('LEAVE',leaveButton(alert))
                            end
                        elseif leaveButton(alert) then
                            schedule('LEAVE',leaveButton(alert))
                        end
                    end
                    if remaining>0 or (alert and inGate(alert)) then
                        s.status='Cleared / cooldown '..clockString(remaining)
                        return
                    end
                    -- Cooldown is over and we're outside: only a fresh
                    -- popup/chip may start a new run. Never rejoin immediately.
                    if p~='TAKE_ME_THERE' and p~='RIFT_CHIP' then
                        s.status='Ready for next Rift event'
                        return
                    end
                    startNewEvent()
                end
                -- One gate entry per 15 minutes, plus 10 minutes post-clear.
                -- Keep the current admitted run usable so that retries of
                -- its first click or its existing fight are not blocked.
                if (p=='TAKE_ME_THERE' or p=='RIFT_CHIP') then
                    if s.didEnter then
                        -- This Rift was already entered. During the 15-minute
                        -- lock never click its old popup; after the lock,
                        -- allow a fresh event (including after a failed run).
                        if remaining>0 then
                            s.status='Rift already entered / next '..clockString(remaining)
                            return
                        end
                        startNewEvent()
                    end
                    if not s.runActive and remaining>0 then
                        s.status='Next Rift in '..clockString(remaining)
                        return
                    end
                end
                if (p=='TAKE_ME_THERE' or p=='RIFT_CHIP' or p=='INSIDE')
                    and not s.runActive and combat.owner then
                    s.status='Waiting for '..tostring(combat.owner)..' battle'
                    return
                end
                if p=='TAKE_ME_THERE' then
                    if not s.runActive then
                        -- Record the entry on the first attempt. Failed click
                        -- retries are allowed for THIS admission only.
                        startNewEvent()
                        recordEntry()
                    end
                    schedule('TAKE_ME_THERE',btn)
                elseif p=='RIFT_CHIP' and cfg.autoOpenChip then
                    if not s.runActive then startNewEvent() end
                    schedule('RIFT_CHIP',btn)
                elseif p=='INSIDE' then
                    if not s.runActive then
                        -- Resume an in-progress run after re-execution;
                        -- do not silently start a NEW fight during cooldown.
                        if s.lastEntryEpoch>s.lastClearEpoch
                            and s.lastEntryEpoch>0 then
                            s.runActive=true
                            s.didEnter=true
                        elseif remaining==0 then
                            recordEntry()
                            s.didEnter=true
                        else
                            s.status='Rift cooldown '..clockString(remaining)
                            return
                        end
                    else
                        s.didEnter=true
                    end
                    if s.fightStarted or (s.battleFinishedAt>0) then
                        if s.battleFinishedAt>0 and tnow()-s.battleFinishedAt>=16
                            and (cfg.autoLeave or (state.enabled and handoff.active)) and not s.isCleared then
                            local exit=findPrompt('RiftLeavePrompt')
                            local exitButton=leaveButton(alert)
                            local distance=exit and promptDistance(exit) or math.huge
                            if exit and distance<=exit.MaxActivationDistance+1.5 then
                                schedule('LEAVE_PROMPT',exit)
                            elseif exitButton then
                                schedule('LEAVE',exitButton)
                            end
                            s.status='Rift fight ended; leaving after no reward'
                        else
                            s.status='Waiting for Rift result / reward'
                        end
                        return
                    end
                    local fight=findPrompt('RiftFightPrompt')
                    if fight then
                        local d=promptDistance(fight)
                        if d<=(fight.MaxActivationDistance or 12)+1.5 then
                            schedule('FIGHT',fight)
                        else
                            walkToFight(fight)
                        end
                    else
                        s.status='Waiting for Rift NPC'
                    end
                else
                    s.status=remaining>0 and ('Next Rift in '..clockString(remaining))
                        or 'Waiting for Rift Gate event'
                end
            end)
            if not ok then
                s.status='Paused: Rift state error'
                s.on=false
            end
            local cool=s.on and not s.runActive and not s.pending
                and not handoff.active and secondsUntilNext()>0
            task.wait(not s.on and 1.0 or (cool and 1.25 or cfg.poll))
        end
    end)
    return {
        state=s,
        enable=function(on)
            s.on=(on==true)
            if not s.on then s.pending=nil end
            s.status=s.on and 'Monitoring Rift event' or 'AUTO OFF'
        end,
        setWalk=function(on) cfg.moveToFightNPC=(on==true) end,
        setLeave=function(on) cfg.autoLeave=(on==true) end,
        cooldownText=function()
            local remaining=secondsUntilNext()
            return remaining>0 and clockString(remaining) or 'READY'
        end,
        stop=function()
            s.alive=false;s.on=false
            for _,con in ipairs(s.connections) do pcall(function() con:Disconnect() end) end
        end,
    }
end
local rift=createRiftGateController()

-- Auto reconnect is best effort. Roblox may reject TeleportService calls once
-- the network session is completely dead; no executor can guarantee a rejoin.
local reconnect={enabled=true,attempts=0,lastTry=-math.huge,limit=3,interval=9,
    status='Monitoring',lastReason='',connections={}}
local function disconnectionText()
    local message=''
    pcall(function() message=GuiService:GetErrorMessage() or '' end)
    local core
    pcall(function() core=game:GetService('CoreGui') end)
    if core then
        local ok,prompt=pcall(function()
            local root=core:FindFirstChild('RobloxPromptGui')
            local overlay=root and root:FindFirstChild('promptOverlay')
            return overlay and overlay:FindFirstChild('ErrorPrompt',true)
        end)
        if ok and prompt and prompt.Visible then
            local lines={}
            for _,desc in ipairs(prompt:GetDescendants()) do
                if (desc:IsA('TextLabel') or desc:IsA('TextButton')) and desc.Visible then
                    local t=tostring(desc.Text or '')
                    if t~='' then lines[#lines+1]=t end
                end
            end
            if #lines>0 then message=message..' '..table.concat(lines,' ') end
        end
    end
    return tostring(message):lower()
end
local function isLostConnection(message)
    if message=='' then return false end
    -- Only connectivity failures. Don't auto-return after a kick / ban / moderation.
    if message:find('banned',1,true) or message:find('kicked',1,true)
       or message:find('moderation',1,true) then return false end
    return message:find('disconnected',1,true)~=nil
        or message:find('lost connection',1,true)~=nil
        or message:find('connection error',1,true)~=nil
        or message:find('connection lost',1,true)~=nil
        or message:find('timed out',1,true)~=nil
        or message:find('error code: 277',1,true)~=nil
        or message:find('error code: 279',1,true)~=nil
        or message:find('error code: 266',1,true)~=nil
end
local function tryNativeReconnect()
    -- Some Roblox versions expose a native Reconnect/Rejoin action on the
    -- disconnect prompt. Try that before making a TeleportService request.
    local core
    pcall(function() core=game:GetService('CoreGui') end)
    if not core then return false end
    local root=core:FindFirstChild('RobloxPromptGui')
    local overlay=root and root:FindFirstChild('promptOverlay')
    local prompt=overlay and overlay:FindFirstChild('ErrorPrompt',true)
    if not prompt then return false end
    for _,item in ipairs(prompt:GetDescendants()) do
        if item:IsA('GuiButton') and item.Visible then
            local label=(item:IsA('TextButton') and item.Text or item.Name):lower()
            if label:find('reconnect',1,true) or label:find('rejoin',1,true) then
                local ok=pcall(function() item:Activate() end)
                if not ok and type(firesignal)=='function' then
                    ok=pcall(function() firesignal(item.MouseButton1Click) end)
                end
                if ok then return true end
            end
        end
    end
    return false
end
local function requestReconnect(force)
    if not state.alive then return false end
    if not force and not reconnect.enabled then return false end
    if reconnect.attempts>=reconnect.limit then
        reconnect.status='Limit reached'
        return false
    end
    local now=os.clock()
    if now-reconnect.lastTry<reconnect.interval then return false end
    reconnect.lastTry=now
    reconnect.attempts=reconnect.attempts+1
    reconnect.status='Rejoin '..reconnect.attempts..'/'..reconnect.limit
    if tryNativeReconnect() then
        reconnect.status='Native reconnect requested'
        return true
    end
    -- This requests a new server of the same Roblox place, not a game remote.
    local ok=pcall(function()
        TeleportService:Teleport(game.PlaceId,player)
    end)
    if not ok then reconnect.status='Rejoin unavailable; retry later' end
    return ok
end
local function watchReconnect()
    task.spawn(function()
        while state.alive do
            local msg=disconnectionText()
            if reconnect.enabled and isLostConnection(msg) then
                reconnect.lastReason=msg
                requestReconnect(false)
            elseif not isLostConnection(msg) then
                reconnect.attempts=0
                if reconnect.enabled then reconnect.status='Monitoring' end
            end
            state.reconnectStatus=reconnect.enabled and reconnect.status or 'OFF'
            task.wait(2)
        end
    end)
end
local function stopReconnect()
    reconnect.enabled=false
    for _,c in ipairs(reconnect.connections) do pcall(function() c:Disconnect() end) end
end
watchReconnect()
state.stop=function()
    state.alive=false;state.enabled=false;state.pending=nil
    stopReconnect()
    rift.stop()
end

local function chooseStopFloor()
    local spec=tostring(cfg.stopSpec or ''):gsub('%s+','')
    if spec=='' then return nil end
    local a,b=spec:match('^(%d+)%-(%d+)$')
    if a and b then
        a,b=tonumber(a),tonumber(b)
        if a>b then a,b=b,a end
        if a>=1 and b<=9999 then return rng:NextInteger(a,b) end
        return nil
    end
    local exact=spec:match('^(%d+)$')
    if exact then
        local n=tonumber(exact)
        if n>=1 and n<=9999 then return n end
    end
    return nil
end
local function validStopSpec(value)
    local s=tostring(value or ''):gsub('%s+','')
    if s=='' then return true end
    local a,b=s:match('^(%d+)%-(%d+)$')
    if a and b then
        a,b=tonumber(a),tonumber(b)
        return a>=1 and b>=1 and a<=9999 and b<=9999
    end
    local n=s:match('^(%d+)$')
    return n~=nil and tonumber(n)>=1 and tonumber(n)<=9999
end
local function applyFloorSpec(value)
    local clean=tostring(value or ''):gsub('^%s+',''):gsub('%s+$','')
    if not validStopSpec(clean) then return false end
    cfg.stopSpec=clean
    -- Applies to the current run immediately, including a new random target.
    state.stopFloor=chooseStopFloor()
    return true
end

-- Multi-Boss remote engine: preserved from the V5 prototype, independent of UI.
local function createBossController(mainState)
    local state={running=false,stopped=false,epoch=0,wins=0,losses=0,
        nativeAttempts={},status='AUTO OFF'}
    local borders={'Normal','Calamity','Umbral','Astral','Paradox','Origin'}
    local borderKeys={'Normal','Gold','Rainbow','Uni','Astral','Origin'}
    local bosses={
        {name='Sung Jinwoo',id='queen',build='BuildNamiBattle',selected=false,border=1},
        {name='Gojo',id='gojo',build='BuildGojoBattle',selected=true,border=1},
        {name='Makima',id='makima',build='BuildMakimaBattle',selected=false,border=1},
        {name='Miku',id='miku',build='BuildMikuBattle',selected=false,border=1},
        {name='Ishtar',id='ishtar',build='BuildIshtarBattle',selected=false,border=1},
        {name='Kurumi',id='kurumi',build='BuildKurumiBattle',selected=true,border=1},
        {name='Klein',id='klein',build='BuildKleinBattle',selected=true,border=1},
    }
    -- Sung Jinwoo/queen mapping remains unconfirmed; server responses are authoritative.
    local function debugLog(tag,message)
        print('[ANIME ORIGIN / BOSS] '..os.date('%H:%M:%S')..' | '..tostring(tag)..' | '..tostring(message):sub(1,280))
    end
    local function readable(v)
        if type(v)~='table' then return tostring(v) end
        local items={}
        for k,value in pairs(v) do
            if #items>=8 then break end
            items[#items+1]=tostring(k)..'='..tostring(value)
        end
        return '{'..table.concat(items,', ')..'}'
    end
    local function notify(msg)
        msg=tostring(msg)
        if state.status~=msg then
            state.status=msg
            debugLog('STATUS',msg)
        end
    end
local function getRemote(name,class)
    local folder=ReplicatedStorage:FindFirstChild("EventRemotes")
    local obj=folder and folder:FindFirstChild(name)
    return (obj and obj:IsA(class)) and obj or nil
end

local COOLDOWN_POLL_SECONDS=20
local PROGRESS_POLL_SECONDS=90
local function fmtSeconds(value)
    local sec=math.max(0,math.ceil(value))
    if sec>=3600 then return string.format('%dh %02dm',math.floor(sec/3600),math.floor(sec%3600/60)) end
    return string.format('%02d:%02d',math.floor(sec/60),sec%60)
end
local function pollCooldown(b)
    if state.stopped or b.cdPolling then return end
    b.cdPolling=true
    local epoch=b.cdEpoch or 0
    local selectedIndex=b.border
    local now=os.clock()
    local cdRemote=getRemote('GetBossCooldown','RemoteFunction')
    if not cdRemote then
        b.cdState='error'
        b.cdNextPoll=now+COOLDOWN_POLL_SECONDS
        b.cdPolling=false
        if not b.cdWarned then debugLog('CD','GetBossCooldown remote missing') b.cdWarned=true end
        return
    end
    b.cdWarned=false

    -- Match runBoss's progress fallback so UI shows the *actual* border to
    -- be farmed when a selected higher border is still locked.
    local effectiveIndex=selectedIndex
    local progress=getRemote('GetBossBorderProgress','RemoteFunction')
    if progress then
        if not b.cdProgressAt or now>=b.cdProgressAt then
            local ok,level=pcall(function() return progress:InvokeServer(b.id) end)
            if ok and type(level)=='number' then
                b.cdUnlocked=math.clamp(math.floor(level),1,#borders)
            else
                b.cdUnlocked=1
                debugLog('CD','Progress unavailable for '..b.name..'; using Normal')
            end
            b.cdProgressAt=os.clock()+PROGRESS_POLL_SECONDS
        end
        effectiveIndex=math.min(selectedIndex,b.cdUnlocked or 1)
    end
    local actualKey=borderKeys[effectiveIndex]
    local ok,seconds=pcall(function()
        return cdRemote:InvokeServer(b.id,actualKey)
    end)
    b.cdPolling=false
    if state.stopped or not mainState.alive then return end
    if epoch~=(b.cdEpoch or 0) or b.border~=selectedIndex then
        -- Dropdown changed while InvokeServer was running: never display stale time.
        b.cdNextPoll=0
        return
    end
    b.cdActualIndex=effectiveIndex
    b.cdActualKey=actualKey
    b.cdNextPoll=os.clock()+COOLDOWN_POLL_SECONDS
    if not ok then
        b.cdState='error'
        b.cdUntil=nil
        debugLog('CD',b.name..' / '..borders[effectiveIndex]..' request failed: '..tostring(seconds))
        return
    end
    b.cdState='ok'
    -- In the game's BossPanel, nonnumeric and <=0 responses mean READY.
    local timeLeft=type(seconds)=='number' and math.max(0,seconds) or 0
    b.cdUntil=os.clock()+timeLeft
    local stateKey=(timeLeft>0 and 'COOLDOWN' or 'READY')..':'..actualKey
    if stateKey~=b.cdLastLogged then
        b.cdLastLogged=stateKey
        debugLog('CD',b.name..' / '..borders[effectiveIndex]..' = '..(timeLeft>0 and fmtSeconds(timeLeft) or 'READY'))
    end
end


    task.spawn(function()
        while mainState.alive and not state.stopped do
            local now=os.clock()
            for _,b in ipairs(bosses) do
                if not b.cdPolling and now>=(b.cdNextPoll or 0) then
                    b.cdNextPoll=now+COOLDOWN_POLL_SECONDS
                    task.spawn(pollCooldown,b)
                end
            end
            task.wait(1)
        end
    end)

local router,queue
local function modulesReady()
    if router and queue then return true end
    local r=ReplicatedStorage:FindFirstChild("BattleRouter")
    local q=ReplicatedStorage:FindFirstChild("AutoBattleQueue")
    if not r or not q then
        debugLog('MODULE', 'Missing '..(not r and 'BattleRouter ' or '')..(not q and 'AutoBattleQueue' or ''))
        return false
    end
    local ok,a,b=pcall(function() return require(r),require(q) end)
    if ok and type(a)=="table" and type(b)=="table"
       and type(a.pickSlot)=="function" and type(a.playDummy)=="function"
       and type(a.ready)=="function" and type(b.acquire)=="function" then
        router,queue=a,b
        debugLog('MODULE','BattleRouter + AutoBattleQueue loaded')
        return true
    end
    debugLog('MODULE','require failure: '..(ok and 'missing API methods' or tostring(a)))
    return false
end

-- Native BossPanel uses SetAutoBossFight:FireServer(bossId, nil) to turn
-- off its own single-boss auto, then clears ActiveAutoBossId on the player.
-- V3 only detected this state and waited forever. V4 performs that same
-- handoff before it starts multi-boss scheduling.
local function nativeAutoRunning()
    local attr=player:GetAttribute("ActiveAutoBossId")
    local current=type(attr)=="string" and attr~="" and attr or nil
    local check=getRemote("GetAutoBossFight","RemoteFunction")
    if check then
        -- Prefer server state, since the attribute is only client UI state.
        for _,b in ipairs(bosses) do
            local ok,value=pcall(function() return check:InvokeServer(b.id) end)
            if ok and type(value)=="string" and value~="" then
                return b.id,value,"server"
            end
        end
    end
    if current then return current,nil,"attribute" end
    return nil,nil,"none"
end

local function disableNativeAuto(id)
    if not id then return false end
    local stopRemote=getRemote("SetAutoBossFight","RemoteEvent")
    if not stopRemote then
        debugLog('HANDOFF','SetAutoBossFight missing; cannot stop game auto for '..tostring(id))
        return false
    end
    local ok,err=pcall(function()
        -- Matches BossPanel u3988(nil): nil means disable (NOT false / "Off").
        stopRemote:FireServer(id,nil)
    end)
    debugLog('HANDOFF','SetAutoBossFight:FireServer('..id..',nil) ok='..tostring(ok)..' '..tostring(err or ''))
    if ok and player:GetAttribute("ActiveAutoBossId")==id then
        -- Trigger stock BossPanel attribute listener so its local auto loop stops.
        pcall(function() player:SetAttribute("ActiveAutoBossId",nil) end)
    end
    return ok
end

local function runBoss(b)
    if not state.running then return end
    local cooldown=getRemote("GetBossCooldown","RemoteFunction")
    local builder=getRemote(b.build,"RemoteFunction")
    local reward=getRemote("ReportBossVictory","RemoteEvent")
    if not cooldown or not builder or not reward then
        debugLog('REMOTE',b.name..' missing '..(not cooldown and 'GetBossCooldown ' or '')..(not builder and b.build..' ' or '')..(not reward and 'ReportBossVictory' or ''))
        notify("Missing boss remote: "..b.build)
        b.nextTry=os.clock()+30
        return
    end
    local chosen=borders[b.border]
    local effectiveIndex=b.border
    debugLog('BOSS',b.name..' id='..b.id..' builder='..b.build..' selected='..chosen..' key='..borderKeys[b.border])
    local progress=getRemote("GetBossBorderProgress","RemoteFunction")
    if progress then
        local ok,level=pcall(function() return progress:InvokeServer(b.id) end)
        debugLog('PROGRESS',b.name..' ok='..tostring(ok)..' level='..readable(level))
        if ok and type(level)=="number" then
            effectiveIndex=math.min(b.border,math.clamp(math.floor(level),1,#borders))
        else
            -- Match stock BossPanel: assume only Normal unlocked when progress unknown.
            effectiveIndex=1
            debugLog('PROGRESS',b.name..' invalid unlock value; fallback to Normal')
        end
    end
    local actual=borders[effectiveIndex]
    local actualKey=borderKeys[effectiveIndex]
    debugLog('BORDER',b.name..' '..chosen..' -> '..actual..' / internal='..actualKey)
    if actual~=chosen then
        notify(b.name.." / "..chosen.." locked; using "..actual)
    end

    local okCd,seconds=pcall(function() return cooldown:InvokeServer(b.id,actualKey) end)
    debugLog('COOLDOWN',b.name..' ok='..tostring(okCd)..' '..readable(seconds))
    if not okCd then
        notify(b.name.." / cooldown request failed")
        b.nextTry=os.clock()+30
        return
    end
    if okCd and type(seconds)~='number' then
        -- Stock BossPanel treats nil/non-numeric cooldown as ready, not blocked.
        debugLog('COOLDOWN',b.name..' non-numeric response; using original game behavior (ready)')
    end
    if type(seconds)=="number" and seconds>1 then
        b.cdState='ok'
        b.cdUntil=os.clock()+seconds
        b.nextTry=os.clock()+math.max(5,seconds)
        notify(b.name.." / cooldown "..math.ceil(seconds).."s")
        return
    end
    if not state.running then return end

    if not router.ready() then
        notify("Battle UI not ready; waiting")
        b.nextTry=os.clock()+8
        return
    end
    local slot=router.pickSlot()
    if not slot then
        notify("Battle slot busy; waiting")
        b.nextTry=os.clock()+8
        return
    end
    notify("Preparing "..b.name.." / "..actual)
    debugLog('QUEUE',b.name..' acquiring battle slot')
    local unlock=queue.acquire()
    debugLog('QUEUE',b.name..' acquired')
    if not state.running then unlock(); return end
    slot=router.pickSlot()
    if not slot or not router.ready() then
        unlock()
        b.nextTry=os.clock()+8
        return
    end
    debugLog('BUILD',b.name..' :InvokeServer('..actualKey..',slot2='..tostring(slot==2)..')')
    local okBuild,data=pcall(function()
        return builder:InvokeServer(actualKey,slot==2)
    end)
    debugLog('BUILD',b.name..' ok='..tostring(okBuild)..' response='..readable(data))
    if not okBuild or type(data)~="table" or data.ok~=true then
        unlock()
        local reason=type(data)=="table" and tostring(data.reason or data.error or "not ready") or "remote rejected"
        notify(b.name.." / "..reason)
        if type(data)=='table' and type(data.cooldown)=='number' and data.cooldown>0 then
            b.cdState='ok'
            b.cdUntil=os.clock()+data.cooldown
        end
        b.nextTry=os.clock()+math.max(15, tonumber(type(data)=="table" and data.cooldown) or 30)
        return
    end

    local complete=Instance.new("BindableEvent")
    local finished=false
    local finalWin=nil
    local function finish(won)
        if finished then return end
        finished=true
        finalWin=won
        debugLog('RESULT',b.name..' / '..actual..' won='..tostring(won))
        if won==true then
            state.wins=state.wins+1
            -- Same order as BossPanel: report only AFTER genuine battle victory.
            local okReward,errReward=pcall(function() reward:FireServer(b.id,actualKey) end)
            debugLog('REWARD',b.name..' id='..b.id..' borderKey='..actualKey..' fireOK='..tostring(okReward)..' '..tostring(errReward or ''))
            b.cdNextPoll=os.clock()+2 -- refresh verified server timer after reward
            b.cdProgressAt=0   -- a victory may unlock the next border
        elseif won==false then
            state.losses=state.losses+1
        end
        complete:Fire()
    end
    debugLog('BATTLE',b.name..' starting playDummy slot='..tostring(slot))
    local okPlay,started,reason=pcall(function()
        return router.playDummy({
            party=data.party,enemies=data.enemies,title=b.name,
            startHidden=true,onDone=finish,
        },slot)
    end)
    unlock()
    debugLog('BATTLE',b.name..' launchOK='..tostring(okPlay)..' started='..tostring(started)..' reason='..tostring(reason))
    if not okPlay or not started then
        finished=true
        complete:Destroy()
        notify(b.name.." / battle launch failed: "..tostring(reason or started))
        b.nextTry=os.clock()+20
        return
    end
    notify("FIGHTING  "..b.name.." / "..actual)
    task.delay(240,function()
        if not finished then
            debugLog('TIMEOUT',b.name..' no onDone for 240s')
            finish(nil)
        end
    end)
    if not finished then complete.Event:Wait() end
    complete:Destroy()
    -- Recheck the actual server cooldown instead of assuming a fixed 150s.
    b.nextTry=os.clock()+(finalWin==true and 4 or 30)
    if state.running then
        notify(b.name..(finalWin==true and " / WIN" or finalWin==false and " / LOSS" or " / interrupted"))
    end
end


    local function enable(on)
        on=on==true
        if state.stopped or state.running==on then return end
        state.running=on
        state.epoch=state.epoch+1
        if not on then
            notify('AUTO OFF')
            debugLog('AUTO','OFF')
            return
        end
        notify('AUTO ON / checking battle modules')
        state.nativeAttempts={}
    local token=state.epoch
    task.spawn(function()
        local lastNativeCheck=-1e9
        local nativeId=nil
        while state.running and not state.stopped and token==state.epoch do
            if not modulesReady() then
                notify("AUTO ON  /  waiting for BattleRouter + AutoBattleQueue")
                task.wait(4)
            else
                -- Native auto handoff must run even while a native battle
                -- occupies the battle UI; otherwise the manager may never
                -- reach the check that frees the slot.
                if os.clock()-lastNativeCheck>=20 then
                    local border,source
                    nativeId,border,source=nativeAutoRunning()
                    if nativeId then
                        debugLog('NATIVE','active id='..nativeId..' border='..tostring(border)..' source='..source)
                    else
                        debugLog('NATIVE','game Auto Boss=none')
                    end
                    lastNativeCheck=os.clock()
                end
                if nativeId then
                    local attempts=state.nativeAttempts[nativeId] or 0
                    if attempts<3 then
                        state.nativeAttempts[nativeId]=attempts+1
                        notify("AUTO ON  /  stopping native Auto Boss: "..nativeId)
                        debugLog('HANDOFF','attempt '..tostring(attempts+1)..'/3 for '..nativeId)
                        local sent=disableNativeAuto(nativeId)
                        if sent then
                            task.wait(1.5) -- allow server to process the remote
                        else
                            task.wait(2)
                        end
                        -- Always verify; successful FireServer alone does NOT
                        -- prove the server disabled native Auto Boss.
                        local verifyId,verifyBorder,source=nativeAutoRunning()
                        if verifyId==nil then
                            debugLog('HANDOFF','confirmed native Auto Boss OFF; multi-boss can start')
                            notify('AUTO ON  /  native auto stopped; starting multi-boss')
                        elseif verifyId==nativeId then
                            debugLog('HANDOFF','still active '..nativeId..' / '..tostring(verifyBorder)..' ('..source..')')
                            notify('AUTO ON  /  waiting for native auto to stop: '..nativeId)
                        else
                            debugLog('HANDOFF','native selection changed '..nativeId..' -> '..verifyId)
                        end
                        nativeId=verifyId
                        lastNativeCheck=os.clock()
                    else
                        notify('AUTO ON  /  native Auto Boss still ON: '..nativeId..' (3/3 attempts)')
                        -- Continue observing, but do not spam SetAutoBossFight.
                        task.wait(5)
                    end
                elseif not router.ready() then
                    notify("AUTO ON  /  waiting for battle UI")
                    task.wait(4)
                else
                    local any=false
                    for _,b in ipairs(bosses) do
                        if not state.running or state.stopped or token~=state.epoch then break end
                        if b.selected then
                            any=true
                            if (b.nextTry or 0)<=os.clock() then
                                -- Run at most one battle across Raid and Boss.
                                local raidEnabled=mainState.raidRequested==true
                                local honorRaid=raidEnabled and combat.last=='boss'
                                    and os.clock()-(combat.since or 0)<8
                                local honorSiege=mainState.siegeRequested==true and combat.last=='boss'
                                    and os.clock()-(combat.since or 0)<8
                                if not honorRaid and not honorSiege and tryCombat('boss') then
                                    local ok,err=pcall(runBoss,b)
                                    freeCombat('boss')
                                    if not ok then
                                        debugLog('ERROR',b.name..' '..tostring(err))
                                        notify(b.name.." / error: "..tostring(err):sub(1,110))
                                        b.nextTry=os.clock()+30
                                    end
                                end
                            end
                        end
                    end
                    if not any then notify("AUTO ON  /  select at least one boss") end
                    task.wait(3)
                end
            end
        end
    end)
    end
    local function setBorder(id,index)
        index=math.clamp(math.floor(tonumber(index) or 1),1,6)
        for _,b in ipairs(bosses) do
            if b.id==id then
                if b.border~=index then
                    b.border=index
                    b.nextTry=0
                    b.cdEpoch=(b.cdEpoch or 0)+1
                    b.cdState='checking'
                    b.cdUntil=nil
                    b.cdNextPoll=0
                    b.cdProgressAt=0
                    debugLog('BORDER',b.name..' -> '..borders[index]..' / key '..borderKeys[index])
                end
                return
            end
        end
    end
    local function selectBoss(id,selected)
        for _,b in ipairs(bosses) do
            if b.id==id then
                if b.selected~=(selected==true) then
                    b.selected=selected==true
                    b.nextTry=0
                end
                return
            end
        end
    end
    local function cooldownText(b)
        if b.cdState=='error' then return 'N/A' end
        if b.cdState=='checking' or not b.cdUntil then return 'CHECKING' end
        local remain=math.max(0,b.cdUntil-os.clock())
        return remain>0 and fmtSeconds(remain) or 'READY'
    end
    local function stop()
        enable(false)
        state.stopped=true
    end
    return {state=state,bosses=bosses,borders=borders,borderKeys=borderKeys,
        enable=enable,setBorder=setBorder,selectBoss=selectBoss,
        cooldownText=cooldownText,stop=stop}
end
local boss=createBossController(state)
-- Raid V10.2: verified LIVE UI flow with fast loss/timeout from 2026-11-04 recorder.
-- All gameplay starts from the REAL GUI. No RaidStartBattle / RaidReportResult calls.
-- Only passive RaidStateSync and optional RaidStateRequest for cooldowns.
-- Workspace["raid boss"].Torso.CenterPromptAttachment.RaidPrompt
-- PlayerGui.RaidBossUI.Backdrop.Canvas.Path.NodeN.Button
-- PlayerGui.RaidBossUI.Backdrop.Canvas.Dock.Panel.Enter
-- PlayerGui.RaidResultBanner.Shade (dismiss after confirmed result)
local function createRaidController(mainState)
    local st={on=false,alive=true,epoch=0,status='AUTO OFF',wins=0,losses=0,
        cursor=1,lastServerState=nil,stageRetry={},lossStreak={},activeStage=nil,
        connections={},lastRequestAt=-math.huge,lastTeleportAt=-math.huge,
        lastMoveAt=-math.huge,requestedOnce=false}
    local stages={
        {index=1,name='Return from Death',enabled=true},
        {index=2,name='Pride Monster',enabled=false},
        {index=3,name='Wrath Monster',enabled=false},
        {index=4,name='Gluttony Monster',enabled=false},
        {index=5,name='Greed Monster',enabled=false},
    }
    local function trace(tag,message)
        print('[ANIME ORIGIN / RAID UI] '..os.date('%H:%M:%S')..' | '..tag..' | '..tostring(message):sub(1,270))
    end
    local function setStatus(message)
        message=tostring(message)
        if st.status~=message then st.status=message;trace('STATUS',message) end
    end
    local function live(node)
        if not node or not node.Parent then return false end
        local p=node
        while p and p~=playerGui do
            if p:IsA('GuiObject') and not p.Visible then return false end
            if p:IsA('ScreenGui') and not p.Enabled then return false end
            p=p.Parent
        end
        return p==playerGui
    end
    local function child(parent,name)
        return parent and parent:FindFirstChild(name) or nil
    end
    local function chain(parent,...)
        for _,name in ipairs({...}) do
            parent=child(parent,name)
            if not parent then return nil end
        end
        return parent
    end
    local function readLabel(node)
        return node and (node:IsA('TextLabel') or node:IsA('TextButton')) and tostring(node.Text) or ''
    end
    local function raidGui()
        local gui=child(playerGui,'RaidBossUI')
        local canvas=chain(gui,'Backdrop','Canvas')
        if canvas and live(canvas) then return gui,canvas end
        return nil,nil
    end
    local function raidBanner()
        local gui=child(playerGui,'RaidResultBanner')
        local shade=child(gui,'Shade')
        if not (shade and shade:IsA('GuiButton') and live(shade)) then return nil end
        local title=chain(shade,'Banner','Content','Title')
        local kicker=chain(shade,'Banner','Kicker','TextLabel')
        return shade,readLabel(title):upper(),readLabel(kicker):upper()
    end
    local function stagePanel(canvas)
        local panel=chain(canvas,'Dock','Panel')
        local label=chain(panel,'StageTag','TextLabel')
        local stageName=chain(panel,'Info','StageName')
        return panel,readLabel(label):upper(),readLabel(stageName):upper()
    end
    local function onStage(canvas,stage)
        local _,tag,name=stagePanel(canvas)
        return tag:find('STAGE%s*0?'..tostring(stage.index)..'%f[%D]')~=nil
            and name:find(stage.name:upper(),1,true)~=nil
    end
    local function click(btn,mode)
        if not (btn and btn:IsA('GuiButton') and live(btn)) then return false,'not visible' end
        if mode~='mouse' and type(firesignal)=='function' then
            local ok=pcall(function() firesignal(btn.Activated) end)
            if ok then return true,'Activated' end
            ok=pcall(function() firesignal(btn.MouseButton1Click) end)
            if ok then return true,'MouseButton1Click' end
        end
        -- Physical GUI click fallback, only after prior click was not acknowledged.
        local position,size=btn.AbsolutePosition,btn.AbsoluteSize
        local x,y=position.X+size.X/2,position.Y+size.Y/2
        local ok,err=pcall(function()
            VIM:SendMouseButtonEvent(x,y,0,true,game,0)
            task.wait(.09)
            VIM:SendMouseButtonEvent(x,y,0,false,game,0)
        end)
        return ok,ok and 'VirtualInput' or tostring(err)
    end
    local function incoming(data)
        if type(data)~='table' then return end
        st.lastServerState=data
        -- Server cooldowns are ABSOLUTE os.time() / Unix epoch timestamps.
        -- E.g. the captured stage 2 win at 10:52:51 set 10:55:51 (+180s).
        if type(data.Cooldowns)=='table' then
            for _,stage in ipairs(stages) do
                local untilEpoch=tonumber(data.Cooldowns[stage.index] or data.Cooldowns[tostring(stage.index)])
                if untilEpoch then stage.untilEpoch=untilEpoch
                else stage.untilEpoch=0 end
            end
        end
    end
    local sync=child(ReplicatedStorage,'RaidStateSync')
    if sync and sync:IsA('RemoteEvent') then
        st.connections[#st.connections+1]=sync.OnClientEvent:Connect(incoming)
    end
    local function requestState()
        if os.clock()-st.lastRequestAt<35 then return end
        local remote=child(ReplicatedStorage,'RaidStateRequest')
        if remote and remote:IsA('RemoteEvent') then
            st.lastRequestAt=os.clock()
            pcall(function() remote:FireServer() end)
        end
    end
    local function cooldown(stage)
        if st.lastServerState and tonumber(st.lastServerState.Unlocked)
            and stage.index>tonumber(st.lastServerState.Unlocked) then return math.huge end
        return math.max(0,(stage.untilEpoch or 0)-os.time())
    end
    local function cooldownText(stage)
        local seconds=cooldown(stage)
        if seconds==math.huge then return 'LOCKED' end
        if not st.lastServerState then return 'SYNC' end
        if seconds<=0 then return 'READY' end
        local minutes=math.floor(seconds/60)
        return string.format('%02d:%02d',minutes,seconds%60)
    end
    local function findRaidPrompt()
        local npc=Workspace:FindFirstChild('raid boss')
        local found=npc and npc:FindFirstChild('RaidPrompt',true)
        if found and found:IsA('ProximityPrompt') then return found end
        local alt=Workspace:FindFirstChild('RaidPrompt',true)
        if alt and alt:IsA('ProximityPrompt') then return alt end
        return nil
    end
    local function promptLocation(prompt)
        if not (prompt and prompt.Parent and player.Character) then return nil end
        local root=player.Character:FindFirstChild('HumanoidRootPart')
        if not root then return nil end
        local host=prompt.Parent
        local pos
        if host:IsA('Attachment') then pos=host.WorldPosition
        elseif host:IsA('BasePart') then pos=host.Position
        end
        if not pos then return nil end
        return (root.Position-pos).Magnitude,pos
    end
    local function openPrompt(prompt)
        if not prompt or not prompt.Enabled then return false end
        if type(fireproximityprompt)=='function' then
            local ok=pcall(function() fireproximityprompt(prompt) end)
            if ok then return true end
        end
        -- Optional fallback when the executor lacks fireproximityprompt.
        local key=prompt.KeyboardKeyCode
        if key==Enum.KeyCode.Unknown then key=Enum.KeyCode.E end
        local ok=pcall(function()
            VIM:SendKeyEvent(true,key,false,game)
            task.wait(math.max(.1,prompt.HoldDuration+.08))
            VIM:SendKeyEvent(false,key,false,game)
        end)
        return ok
    end
    local function approachRaid(token)
        local started=os.clock()
        local promptAttempts=0
        while st.on and st.epoch==token and mainState.alive and os.clock()-started<34 do
            local gui,canvas=raidGui()
            if canvas then return canvas end
            local prompt=findRaidPrompt()
            local distance,pos=promptLocation(prompt)
            if distance and prompt and prompt.Enabled and distance<=prompt.MaxActivationDistance+1 then
                if promptAttempts>=3 then
                    setStatus('Raid NPC did not open (3 attempts)')
                    return nil
                end
                promptAttempts=promptAttempts+1
                setStatus('Opening Raid NPC '..promptAttempts..'/3')
                if openPrompt(prompt) then
                    trace('PROMPT','Triggered RaidPrompt attempt '..promptAttempts)
                    task.wait(1.1)
                    local _,nextCanvas=raidGui()
                    if nextCanvas then return nextCanvas end
                end
            elseif distance and pos and distance<200 then
                local hum=player.Character and player.Character:FindFirstChildWhichIsA('Humanoid')
                if hum and os.clock()-st.lastMoveAt>2.2 then
                    st.lastMoveAt=os.clock()
                    hum:MoveTo(pos)
                    setStatus('Walking to Raid NPC')
                end
            elseif os.clock()-st.lastTeleportAt>24 then
                local req=child(ReplicatedStorage,'WorldsTeleportRequest')
                if req and req:IsA('RemoteEvent') then
                    st.lastTeleportAt=os.clock()
                    local ok=pcall(function() req:FireServer('raid boss') end)
                    trace('TELEPORT','WorldsTeleportRequest("raid boss") = '..tostring(ok))
                    setStatus('Teleporting to Raid')
                    task.wait(1.8)
                else
                    setStatus('Raid teleport remote unavailable')
                end
            end
            task.wait(.55)
        end
        return nil
    end
    local function waitForSelected(stage,token)
        local _,canvas=raidGui()
        if not canvas then return false end
        if onStage(canvas,stage) then return true end
        local node=chain(canvas,'Path','Node'..tostring(stage.index),'Button')
        if not node then trace('SELECT','Missing Node'..stage.index);return false end
        for attempt=1,2 do
            if not st.on or token~=st.epoch then return false end
            setStatus('Stage '..stage.index..' / selecting ('..attempt..'/2)')
            local ok,method=click(node,attempt==2 and 'mouse' or 'signal')
            trace('SELECT','Stage '..stage.index..' via '..tostring(method)..' ok='..tostring(ok))
            local waitUntil=os.clock()+1.25
            while os.clock()<waitUntil and st.on and token==st.epoch do
                local _,nowCanvas=raidGui()
                if nowCanvas and onStage(nowCanvas,stage) then return true end
                task.wait(.13)
            end
        end
        return false
    end
    local function battleTitle()
        local gui=child(playerGui,'BattleGui2')
        local title=chain(gui,'BattleRoot','FloorTitle')
        if title and live(title) then return readLabel(title):upper() end
        return ''
    end
    local function serverProgress(stage)
        local data=st.lastServerState
        if type(data)~='table' then return nil,nil,nil end
        local idx=stage.index
        return tonumber(type(data.Steps)=='table' and (data.Steps[idx] or data.Steps[tostring(idx)]) or nil),
            tonumber(type(data.Shards)=='table' and (data.Shards[idx] or data.Shards[tostring(idx)]) or nil),
            tonumber(data.Souls)
    end
    local function waitForResult(stage,token,beforeSteps,beforeShards,beforeSouls)
        -- The server owns rewards. Detect both success AND defeat promptly;
        -- V10.1 could wait 155s on a loss when its banner was missed.
        local started=os.clock()
        local sawBattle=false
        local battleClosedAt=nil
        local clearedAt=nil
        while st.on and token==st.epoch and mainState.alive and os.clock()-started<100 do
            local shade,title,kicker=raidBanner()
            -- The Kicker is e.g. STAGE 02 // PRIDE MONSTER; sometimes it
            -- has not populated during the first rendered frame.
            local bannerStage=tonumber(tostring(kicker):match('STAGE%s*0*(%d+)'))
            if shade and (not bannerStage or bannerStage==stage.index) then
                local outcome
                if title:find('CLEARED',1,true) or title:find('VICTORY',1,true) then
                    outcome='WIN'
                elseif title:find('FAILED',1,true) or title:find('DEFEAT',1,true)
                    or title:find('LOST',1,true) or title:find('LOSE',1,true) then
                    outcome='LOSS'
                end
                if outcome then
                    trace('BANNER','Stage '..stage.index..' '..outcome..' ('..title..')')
                    -- Dismiss the actual banner and then return to rotation.
                    for i=1,2 do
                        click(shade,i==2 and 'mouse' or 'signal')
                        task.wait(.3)
                        if not raidBanner() then break end
                    end
                    return outcome
                end
            end
            local titleText=battleTitle()
            if titleText:find('RAID',1,true) then
                sawBattle=true
                battleClosedAt=nil
                setStatus('Fighting Stage '..stage.index)
            elseif sawBattle and not battleClosedAt then
                battleClosedAt=os.clock()
                trace('BATTLE_END','Stage '..stage.index..' battle UI closed; checking result')
            end
            local steps,shards,souls=serverProgress(stage)
            local progressed=(beforeSteps and steps and steps>beforeSteps)
                or (beforeShards and shards and shards>beforeShards)
                or (beforeSouls and souls and souls>beforeSouls and (stage.untilEpoch or 0)>os.time())
            if progressed and not clearedAt then
                clearedAt=os.clock()
                trace('SYNC','Stage '..stage.index..' rewards/progress advanced')
            end
            -- If the game closed battle and authoritative progress advanced,
            -- the banner may have been skipped by another UI transition.
            if clearedAt and battleClosedAt and os.clock()-battleClosedAt>1.5 then
                return 'WIN'
            end
            -- If battle is gone, its GUI returned to Raid selection and no
            -- reward was recorded, treat as defeat after a small grace window.
            -- This avoids the old 155-second delay on an unrecognized loss.
            if battleClosedAt and not clearedAt then
                local elapsed=os.clock()-battleClosedAt
                local _,canvas=raidGui()
                -- The Workspace NPC exists even DURING battles; only its
                -- visible ProximityPrompt GUI proves we returned to lobby.
                local promptLabel=chain(child(playerGui,'ProximityPrompts'),
                    'Prompt','Frame','TextFrame','ObjectText')
                local promptVisible=promptLabel and live(promptLabel)
                    and readLabel(promptLabel):upper():find('RAID BOSS',1,true)~=nil
                -- 5.5s if Raid/lobby UI returned; 10s conservative fallback
                -- if the game hid its prompt. Never confuse NPC existence
                -- with proof that the fight ended.
                if (elapsed>5.5 and (canvas or promptVisible or shade)) or elapsed>10 then
                    trace('FAST_LOSS','Stage '..stage.index..' no reward '..string.format('%.1fs',elapsed)..' after battle ended')
                    if shade then
                        click(shade,'signal')
                        task.wait(.2)
                    end
                    return 'LOSS'
                end
            end
            task.wait(.28)
        end
        return nil
    end
    local function runStage(stage,token)
        st.activeStage=stage.index
        local function finish(waitSeconds,reason)
            st.stageRetry[stage.index]=os.clock()+math.max(tonumber(waitSeconds) or 30,5)
            setStatus('Stage '..stage.index..' / '..reason)
            st.activeStage=nil
        end
        if cooldown(stage)>0 then finish(8,'Cooldown');return end
        if battleTitle()~='' then finish(10,'Battle busy');return end
        local canvas=approachRaid(token)
        if not canvas then finish(22,'NPC/UI unavailable');return end
        if not waitForSelected(stage,token) then finish(50,'Stage selection rejected');return end
        if not st.on or token~=st.epoch then st.activeStage=nil;return end
        local _,confirmCanvas=raidGui()
        if not confirmCanvas or not onStage(confirmCanvas,stage) then
            finish(30,'Stage selection changed');return
        end
        local panel=chain(confirmCanvas,'Dock','Panel')
        local enter=child(panel,'Enter')
        if not (enter and enter:IsA('GuiButton') and live(enter)) then
            finish(60,'START BATTLE button missing');return
        end
        local beforeSteps,beforeShards,beforeSouls=serverProgress(stage)
        local launched=false
        for attempt=1,2 do
            if not st.on or token~=st.epoch then st.activeStage=nil;return end
            setStatus('Stage '..stage.index..' / START ('..attempt..'/2)')
            local ok,method=click(enter,attempt==2 and 'mouse' or 'signal')
            trace('START','stage='..stage.index..' '..tostring(method)..' ok='..tostring(ok))
            local untilTime=os.clock()+3.2
            while os.clock()<untilTime do
                if not st.on or token~=st.epoch then st.activeStage=nil;return end
                if battleTitle():find('RAID',1,true) then launched=true;break end
                local shade=raidBanner()
                if shade then launched=true;break end
                task.wait(.16)
            end
            if launched then break end
            local _,currentCanvas=raidGui()
            if not currentCanvas or not onStage(currentCanvas,stage) then
                -- UI closed unexpectedly: do not send another START.
                launched=true
                break
            end
        end
        if not launched then finish(65,'START BATTLE no response');return end
        local result=waitForResult(stage,token,beforeSteps,beforeShards,beforeSouls)
        if result=='WIN' then
            st.wins=st.wins+1
            st.lossStreak[stage.index]=0
            -- Captured successes have 180-second server cooldowns per stage.
            -- Use the actual RaidStateSync.Cooldowns timestamp if present.
            local remaining=cooldown(stage)
            if remaining==0 then stage.untilEpoch=os.time()+180 end
            st.stageRetry[stage.index]=os.clock()+math.max(10,cooldown(stage))
            setStatus('Stage '..stage.index..' / CLEARED')
            trace('WIN','Stage '..stage.index..' / next '..cooldownText(stage))
        elseif result=='LOSS' then
            st.losses=st.losses+1
            local losses=(st.lossStreak[stage.index] or 0)+1
            st.lossStreak[stage.index]=losses
            -- Retry or rotate in 6/10/14 seconds rather than 75 seconds.
            -- After three failures cap at 14 seconds to avoid remote spam.
            local gap=math.min(6+4*(losses-1),14)
            finish(math.max(gap,cooldown(stage)),'LOSS / retry in '..gap..'s')
        else
            -- Unknown result: short backoff, without inventing a victory.
            finish(18,'Result not confirmed')
            trace('TIMEOUT','Stage '..stage.index..' awaiting verified outcome')
        end
        st.activeStage=nil
        requestState()
    end
    local function nextStage()
        for offset=0,#stages-1 do
            local idx=(st.cursor+offset-1)%#stages+1
            local stage=stages[idx]
            if stage.enabled and cooldown(stage)==0
                and (st.stageRetry[idx] or 0)<=os.clock() then
                st.cursor=idx%#stages+1
                return stage
            end
        end
        return nil
    end
    local function enable(on)
        on=(on==true)
        if st.on==on or not st.alive then return end
        st.on=on;st.epoch=st.epoch+1
        if not on then setStatus('AUTO OFF');return end
        setStatus('AUTO ON / stage rotation')
        local token=st.epoch
        task.spawn(function()
            while st.alive and mainState.alive and st.on and token==st.epoch do
                requestState()
                if mainState.enabled and not mainState.remoteColo then
                    setStatus('Waiting for Colosseum')
                elseif not st.lastServerState then
                    setStatus('Waiting for RaidStateSync / opening Raid NPC')
                    -- The live recorder shows the server sends RaidStateSync
                    -- when RaidPrompt opens the RaidBossUI. RequestState may
                    -- not cause a sync by itself: open the real UI first.
                    if tryCombat('raid') then
                        local ok,err=pcall(approachRaid,token)
                        freeCombat('raid')
                        if not ok then trace('OPEN_ERROR',tostring(err)) end
                    end
                else
                    local stage=nextStage()
                    if not stage then
                        setStatus('Selected stages: locked / cooldown / wait')
                    else
                        local honorBoss=mainState.bossRequested==true
                            and combat.last=='raid' and os.clock()-combat.since<8
                        local honorSiege=mainState.siegeRequested==true
                            and combat.last=='raid' and os.clock()-combat.since<8
                        if not honorBoss and not honorSiege and tryCombat('raid') then
                            local ok,err=pcall(runStage,stage,token)
                            freeCombat('raid')
                            if not ok then
                                trace('ERROR',tostring(err))
                                st.activeStage=nil
                                st.stageRetry[stage.index]=os.clock()+70
                                setStatus('Stage '..stage.index..' / controller error')
                            end
                        end
                    end
                end
                task.wait(1.1)
            end
        end)
    end
    local function selectStage(index,on)
        local stage=stages[tonumber(index) or 0]
        if stage then
            stage.enabled=on==true
            if stage.enabled then st.stageRetry[stage.index]=0 end
        end
    end
    local function stop()
        enable(false)
        st.alive=false
        for _,connection in ipairs(st.connections) do pcall(function() connection:Disconnect() end) end
    end
    return {state=st,stages=stages,enable=enable,selectStage=selectStage,
        cooldownText=cooldownText,stop=stop}
end
local raid=createRaidController(state)
-- SIEGE V10.7: source-verified 12-stage dungeon mechanics, no NPC/UI scanning.
-- The native game's "Auto Dungeon Stage" holds ONE stage in a private client variable.
-- Sending SetAutoDungeonStage for rotation does not update that variable reliably.
-- We therefore use the same battle RPCs and BattleRouter as DungeonScreen,
-- but own the round-robin, cooldowns and shared combat lock ourselves.
local function createSiegeController(mainState)
    local remoteFolder=ReplicatedStorage:FindFirstChild('EventRemotes')
    local stageNames={
        'The Outer Fog', 'Awakened Seer', 'Twilight Trials',
        'Abyssal Corridors', 'Mythical Blight', 'The True Guardians Of Hell',
        'Umbral Requiem', 'Cinderfall Throne', 'Genesis Of The End',
        'Starfall Sanctum', 'Throne Of The First Light', 'Origin Of All Things',
    }
    local st={on=false,alive=true,epoch=0,status='OFF',wins=0,losses=0,
        cursor=1,activeStage=nil,stages={},cooldownUntil={},retryUntil={},
        progressReady=false,highestCleared=0,nextProgressAt=0,nextCooldownAt=0,
        rotation=nil,nextRotationAt=0,modules={},nativeChecked=false,
        lastError='',lastFightAt=0,nativeNextCheck=0,nativeStage=0,randomPool=nil}
    for i,name in ipairs(stageNames) do
        st.stages[i]={index=i,name=name,enabled=i==1}
    end
    local function say(msg)
        msg=tostring(msg)
        if st.status~=msg then st.status=msg end
    end
    local function trace(label,msg)
        print('[ANIME ORIGIN / SIEGE] '..os.date('%H:%M:%S')..' | '..label..' | '..tostring(msg):sub(1,230))
    end
    local function rf(name)
        remoteFolder=remoteFolder or ReplicatedStorage:FindFirstChild('EventRemotes')
        local o=remoteFolder and remoteFolder:FindFirstChild(name)
        return o and o:IsA('RemoteFunction') and o or nil
    end
    local function serverGet(name,...)
        local o=rf(name)
        if not o then return false,'missing '..name end
        return pcall(function(...) return o:InvokeServer(...) end,...)
    end
    local function initModules()
        if st.modules.router and st.modules.queue and st.modules.cards then return true end
        local ok,router,queue,cards,images,base=pcall(function()
            local db=ReplicatedStorage:FindFirstChild('GameDatabase')
            return require(ReplicatedStorage:WaitForChild('BattleRouter',4)),
                require(ReplicatedStorage:WaitForChild('AutoBattleQueue',4)),
                require(db:WaitForChild('CardDatabase',4)),
                require(ReplicatedStorage:WaitForChild('CardImages',4)),
                require(db:WaitForChild('CardBaseStats',4))
        end)
        if not ok or type(router)~='table' or type(queue)~='table'
            or type(cards)~='table' or type(base)~='table' then
            say('Waiting for Siege battle modules')
            return false
        end
        st.modules={router=router,queue=queue,cards=cards,images=images,base=base}
        return true
    end
    local function pollProgress(force)
        if not force and os.clock()<st.nextProgressAt then return end
        st.nextProgressAt=os.clock()+75
        local ok,data=serverGet('GetDungeonProgress')
        if ok and type(data)=='table' and tonumber(data.highestCleared) then
            st.progressReady=true
            st.highestCleared=math.clamp(math.floor(tonumber(data.highestCleared)),0,12)
        else
            st.lastError='Progress: '..tostring(type(data)=='table' and data.error or data)
        end
    end
    local function pollCooldowns(force)
        if not force and os.clock()<st.nextCooldownAt then return end
        st.nextCooldownAt=os.clock()+18
        local ok,data=serverGet('GetDungeonCooldown')
        if ok and type(data)=='table' then
            for i=1,12 do
                local rem=tonumber(data[i] or data[tostring(i)])
                if rem then
                    st.cooldownUntil[i]=os.clock()+math.max(0,rem)
                elseif st.cooldownUntil[i] and os.clock()>st.cooldownUntil[i] then
                    st.cooldownUntil[i]=nil
                end
            end
        else
            st.lastError='Cooldown: '..tostring(data)
        end
    end
    local function pollRotation(force)
        if not force and os.clock()<st.nextRotationAt then return end
        st.nextRotationAt=os.clock()+600
        local ok,data=serverGet('GetDungeonRotation')
        if ok and type(data)=='table' and type(data.board)=='table' then
            st.rotation=data.board
        end
    end
    local function remaining(i)
        return math.max(0,(st.cooldownUntil[i] or 0)-os.clock())
    end
    local function cooldownText(stage)
        local i=stage.index
        if st.progressReady and i>st.highestCleared+1 then return 'LOCKED' end
        local t=remaining(i)
        if t>0 then
            t=math.ceil(t)
            return string.format('%d:%02d',math.floor(t/60),t%60)
        end
        if os.clock() < (st.retryUntil[i] or 0) then
            local secs=math.ceil(st.retryUntil[i]-os.clock())
            return 'RETRY '..secs..'s'
        end
        return st.progressReady and 'READY' or 'SYNC'
    end
    local function chooseStage()
        local n=#st.stages
        for offset=0,n-1 do
            local i=(st.cursor+offset-1)%n+1
            local stage=st.stages[i]
            if stage.enabled and st.progressReady and i<=st.highestCleared+1
                and remaining(i)<=0 and os.clock()>=(st.retryUntil[i] or 0) then
                st.cursor=i%n+1
                return stage
            end
        end
        return nil
    end
    local function riftMustGoFirst()
        local rs=rift and rift.state
        if not rs or not rs.on then return false end
        -- Rift's runActive may remain true after a loss and Leave.  Trust
        -- the current phase + fresh eligibility, not the stale flag alone.
        local phase=tostring(rs.phase or '')
        if phase=='INSIDE' or phase=='BATTLE' then return true end
        if phase=='TAKE_ME_THERE' or phase=='RIFT_CHIP' then
            return rift.cooldownText()=='READY'
        end
        return false
    end
    local function randomSiegeEnemyId()
        if not st.randomPool then
            local m=st.modules
            local excluded={}
            local db=ReplicatedStorage:FindFirstChild('GameDatabase')
            for _,moduleName in ipairs({'BossDatabase','WeatherDatabase','TowerCardDatabase'}) do
                local source=db and db:FindFirstChild(moduleName)
                if source then
                    local ok,mod=pcall(require,source)
                    local all=ok and mod and mod['All'..moduleName:gsub('Database','CardIds')]
                    if type(all)=='function' then
                        local success,ids=pcall(all)
                        if success and type(ids)=='table' then
                            for id,value in pairs(ids) do if value then excluded[tonumber(id) or id]=true end end
                        end
                    end
                end
            end
            local pool={}
            if type(m.cards.Cards)=='table' then
                for id,card in pairs(m.cards.Cards) do
                    local numeric=tonumber(id)
                    if numeric and type(card)=='table' and card.Rarity~='Custom'
                        and not card.IsDev and not card.IsEvolved and not excluded[numeric] then
                        local ok,implemented=pcall(m.cards.IsImplemented,card)
                        if ok and implemented then pool[#pool+1]=numeric end
                    end
                end
            end
            st.randomPool=pool
        end
        local pool=st.randomPool
        return #pool>0 and pool[math.random(1,#pool)] or nil
    end
    local function makeEnemy(stage,i,serverIds)
        local m=st.modules
        local baselines={{300,600},{450,750},{600,900},{750,1050}}
        local fixed={
            {6,21,34,79},{32,31,33,18},{29,30,28,2},
            {26,27,17,52},{35,10,9,205},{265,4,14,1},
        }
        local stageId=stage.index
        local index=(stageId-1)
        local scalar=stageId==6 and .85 or 1
        local base=baselines[i]
        local attack=math.round(math.min(300000,base[1]*1.7240541740171793^index)*.5*scalar)
        local maxHp=math.round(math.min(600000,base[2]*1.780872815829204^index)*.5*scalar)
        local id=tonumber(type(serverIds)=='table' and (serverIds[i] or serverIds[tostring(i)]))
            or (fixed[stageId] and fixed[stageId][i])
            or randomSiegeEnemyId() -- same random fallback as native DungeonScreen
        if not id then return nil,'No valid Siege enemy card ID for stage '..stageId end
        local card=m.cards.GetCard(id)
        if not card then return nil,'Unknown Siege enemy ID '..tostring(id) end
        local image
        pcall(function() image=m.images.GetImage(id) end)
        local e={CardID=id,Border='Normal',Disabled=0,Dead=false,
            Name=card.Name or 'Siege Enemy',Rarity=card.Rarity,image=image,
            MaxHP=maxHp,HP=maxHp,DMG=attack}
        local rotate=st.rotation and (st.rotation[stageId] or st.rotation[tostring(stageId)])
        if type(rotate)=='table' then
            local elements=rotate.elements
            local debuffs=rotate.debuffs
            if type(elements)=='table' and elements[1] then
                e.Element=elements[(i-1)%2+1] or elements[1]
                e.Border='Origin'
            end
            if type(debuffs)=='table' then
                e.DebuffEffects={}
                for j=1,2 do
                    if debuffs[j] then
                        e.DebuffEffects[#e.DebuffEffects+1]={
                            event='OnHit',chance=.45,name=debuffs[j],
                        }
                    end
                end
            end
        end
        return e,nil
    end
    local function fetchParty()
        local m=st.modules
        local ok,decks=serverGet('GetActiveDecks')
        local deckId=ok and type(decks)=='table' and tonumber(decks.dungeon) or 16
        if not deckId or deckId<16 or deckId>20 then deckId=16 end
        local got,raw=serverGet('GetParty',deckId)
        if not got or type(raw)~='table' then return nil,'Siege party unavailable' end
        local punchOk,punched=serverGet('GetPackPunched')
        if not punchOk or type(punched)~='table' then punched={} end
        local result={}
        for i=1,4 do
            local entry=raw[i]
            local cardId=type(entry)=='table' and (entry.CardID or entry.id or entry.cardID)
                or type(entry)=='number' and entry or nil
            local border=type(entry)=='table' and (entry.Border or entry.border) or 'Normal'
            cardId=tonumber(cardId)
            if cardId then
                local card=m.cards.GetCard(cardId)
                if card then
                    local hp,dmg=m.base.Compute(card,border or 'Normal')
                    local factor=punched[tostring(cardId)] and 1.05 or 1
                    hp=math.max(1,math.round(hp*factor));dmg=math.max(1,math.round(dmg*factor))
                    local image
                    pcall(function() image=m.images.GetImage(cardId) end)
                    result[#result+1]={Dodge=0,Counter=0,Steal=0,StealDuration=2,
                        StealMaxPerFloor=2,Lifesteal=0,Defense=0,Dead=false,
                        CardID=cardId,Border=border or 'Normal',Name=card.Name,
                        Rarity=card.Rarity,image=image,MaxHP=hp,HP=hp,DMG=dmg}
                end
            end
        end
        return result,nil
    end
    local function tryStage(stage,epoch)
        if not st.on or epoch~=st.epoch then return end
        st.activeStage=stage.index
        local title='Stage '..stage.index..' / '..stage.name
        local m=st.modules
        local router,queue=m.router,m.queue
        if not router.ready() then
            st.activeStage=nil;return
        end
        local slot=router.pickSlot()
        if not slot then
            say('Waiting for a free battle slot');st.activeStage=nil;return
        end
        local build=rf('StartDungeonStage')
        local claim=rf('ClaimDungeonReward')
        if not build or not claim then
            say('Missing Siege remote: StartDungeonStage / ClaimDungeonReward')
            st.retryUntil[stage.index]=os.clock()+35
            st.activeStage=nil;return
        end
        say('Starting '..title)
        trace('START',title..' slot='..slot)
        local release=queue.acquire()
        local success,result=pcall(function()
            return build:InvokeServer(stage.index,nil,slot==2)
        end)
        if not success or type(result)~='table' or result.ok~=true then
            pcall(release)
            local errorText=type(result)=='table' and (result.error or result.reason) or result
            if type(result)=='table' and result.error=='cooldown' then
                st.cooldownUntil[stage.index]=os.clock()+math.max(1,tonumber(result.remaining) or 165)
            end
            st.retryUntil[stage.index]=os.clock()+15
            say(title..' / denied: '..tostring(errorText):sub(1,65))
            trace('DENIED',title..' '..tostring(errorText))
            st.activeStage=nil
            return
        end
        local enemies={}
        for i=1,4 do
            local enemy,err=makeEnemy(stage,i,result.enemyIds)
            if not enemy then
                pcall(release)
                st.retryUntil[stage.index]=os.clock()+35
                say(title..' / '..tostring(err))
                trace('ENEMY',tostring(err))
                st.activeStage=nil
                return
            end
            enemies[i]=enemy
        end
        local party=(type(result.party)=='table' and #result.party>0) and result.party or nil
        if not party then
            local fallback,errorText=fetchParty()
            if not fallback or #fallback==0 then
                pcall(release)
                st.retryUntil[stage.index]=os.clock()+35
                say(title..' / '..tostring(errorText or 'empty Siege deck'))
                st.activeStage=nil
                return
            end
            party=fallback
            if type(result.relics)=='table' then
                local db=ReplicatedStorage:FindFirstChild('GameDatabase')
                local mod=db and db:FindFirstChild('RelicCombat')
                if mod then
                    local relOk,rel=pcall(require,mod)
                    if relOk and type(rel)=='table' and type(rel.applyPack)=='function' then
                        for _,unit in ipairs(party) do
                            local pack=result.relics[tostring(unit.CardID)..'|'..tostring(unit.Border or 'Normal')]
                            pcall(rel.applyPack,unit,pack)
                        end
                    end
                end
            end
        end
        local finishEvent=Instance.new('BindableEvent')
        local completed=false
        local victory=nil
        local function done(won)
            if completed then return end
            completed=true
            victory=won
            finishEvent:Fire()
        end
        local okPlay,started,reason=pcall(function()
            return router.playDummy({party=party,enemies=enemies,
                title='SIEGE — '..string.upper(stage.name),startHidden=true,onDone=done},slot)
        end)
        pcall(release)
        if not okPlay or not started then
            completed=true
            finishEvent:Destroy()
            st.retryUntil[stage.index]=os.clock()+30
            trace('PLAY_ERROR',title..' '..tostring(reason or started))
            say(title..' / battle launch failed')
            st.activeStage=nil
            return
        end
        say('FIGHTING '..title)
        task.delay(200,function()
            if not completed then done(nil) end
        end)
        if not completed then finishEvent.Event:Wait() end
        finishEvent:Destroy()
        if victory==true then
            -- A local battle victory does NOT imply the server granted reward.
            local rewardOk,reward=pcall(function() return claim:InvokeServer(stage.index) end)
            local confirmed=rewardOk and type(reward)=='table'
                and reward.error==nil
            if rewardOk and type(reward)=='table' then
                local cd=tonumber(reward.cooldown or (reward.error=='cooldown' and reward.remaining))
                if cd and cd>0 then st.cooldownUntil[stage.index]=os.clock()+cd end
                if tonumber(reward.highestCleared) then
                    st.highestCleared=math.clamp(math.floor(reward.highestCleared),0,12)
                    st.progressReady=true
                end
                trace('REWARD',title..' '..tostring(reward.error or 'confirmed')..' cd='..tostring(cd))
            else
                trace('REWARD_ERROR',title..' '..tostring(reward))
            end
            if confirmed then
                st.wins=st.wins+1
                say(title..' / WIN + server reward')
            else
                say(title..' / victory, reward NOT confirmed')
            end
            st.retryUntil[stage.index]=os.clock()+(confirmed and 6 or 22)
            st.nextCooldownAt=0
            st.nextProgressAt=0
        elseif victory==false then
            st.losses=st.losses+1
            st.retryUntil[stage.index]=os.clock()+10
            say(title..' / LOSS — next selected stage')
            trace('LOSS',title)
        else
            st.retryUntil[stage.index]=os.clock()+35
            say(title..' / interrupted or result missing')
            trace('TIMEOUT',title)
        end
        st.activeStage=nil
        st.lastFightAt=os.clock()
    end
    local function enable(on)
        on=on==true
        if not st.alive or st.on==on then return end
        st.on=on
        st.epoch=st.epoch+1
        if not on then say('AUTO OFF');return end
        say('Auto Siege ON / initializing')
        local token=st.epoch
        task.spawn(function()
            while st.alive and st.on and mainState.alive and token==st.epoch do
                local ok,err=pcall(function()
                    if not initModules() then return end
                    if not st.progressReady or os.clock()>=st.nextProgressAt then pollProgress() end
                    if os.clock()>=st.nextCooldownAt then pollCooldowns() end
                    if os.clock()>=st.nextRotationAt then pollRotation() end
                    if not st.progressReady then say('Waiting for Siege progress');return end
                    if os.clock()>=st.nativeNextCheck then
                        st.nativeNextCheck=os.clock()+30
                        local nOk,n=serverGet('GetAutoDungeonStage')
                        if nOk and tonumber(n) then st.nativeStage=tonumber(n) end
                    end
                    if st.nativeStage and st.nativeStage>=1 then
                        say('Turn OFF game-native Siege Auto-Stage '..st.nativeStage..' first')
                        return
                    end
                    if mainState.enabled and not mainState.remoteColo then
                        say('Waiting for Colosseum (exclusive)')
                        return
                    end
                    if riftMustGoFirst() then
                        say('Rift priority / Siege waiting')
                        return
                    end
                    if combat.owner then
                        say('Waiting for '..combat.owner..' battle')
                        return
                    end
                    if (mainState.bossRequested or mainState.raidRequested)
                        and combat.last=='siege' and os.clock()-(combat.since or 0)<8 then
                        say('Giving Boss/Raid next battle turn')
                        return
                    end
                    if not st.modules.router.ready() then
                        say('Waiting for battle UI')
                        return
                    end
                    local stage=chooseStage()
                    if not stage then
                        local selected=0
                        for _,row in ipairs(st.stages) do if row.enabled then selected=selected+1 end end
                        say(selected==0 and 'Select at least one Siege stage'
                            or 'All selected stages locked / cooldown / retry')
                        return
                    end
                    if tryCombat('siege') then
                        local battleOk,battleErr=pcall(tryStage,stage,token)
                        freeCombat('siege')
                        if not battleOk then
                            trace('ERROR',tostring(battleErr))
                            st.retryUntil[stage.index]=os.clock()+30
                            st.activeStage=nil
                            say('Siege error / stage '..stage.index)
                        end
                    end
                end)
                if not ok then
                    trace('LOOP_ERROR',tostring(err))
                    say('Siege loop paused: '..tostring(err):sub(1,80))
                end
                task.wait(st.activeStage and .6 or 1.3)
            end
        end)
    end
    local function selectStage(index,on)
        index=tonumber(index)
        local row=index and st.stages[index]
        if row then
            row.enabled=on==true
            if row.enabled then st.retryUntil[index]=0 end
        end
    end
    local function stop()
        enable(false);st.alive=false
    end
    return {state=st,stages=st.stages,enable=enable,selectStage=selectStage,
        cooldownText=cooldownText,stop=stop}
end
local siege=createSiegeController(state)
local priorStop=state.stop
state.stop=function()
    boss.stop()
    raid.stop()
    siege.stop()
    priorStop()
end

-- Anime Origin private JSON config store (no Rayfield / remote UI library).
local HttpService=game:GetService('HttpService')
local UIS=game:GetService('UserInputService')
local STORAGE='AnimeOriginV9'
local CONFIG_DIR=STORAGE..'/profiles'
local AUTO_FILE=STORAGE..'/auto_load.txt'
local INDEX_FILE=STORAGE..'/profiles.json'
local disk=(type(readfile)=='function' and type(writefile)=='function')
local configStatus=disk and 'Storage ready' or 'File API unavailable'
local currentProfile='Default'
local autoProfile='Default'
local storedNames={'Default'}
local flags={
    AO_AutoColosseum=false, AO_AutoRift=false, AO_AutoBoss=false, AO_AutoRaid=false, AO_AutoSiege=false,
    AO_Colo_Hell=true, AO_Colo_Endless=true, AO_Colo_StopFloor='30-40',
    AO_Rift_Walk=true, AO_Rift_Leave=true,
    AO_Reconnect=true, AO_UI_Theme='Midnight', AO_UI_Transparency=15,
}
for _,b in ipairs(boss.bosses) do
    flags['AO_Boss_'..b.id]=b.selected
    flags['AO_Border_'..b.id]=b.border
end
for _,stage in ipairs(raid.stages) do
    flags['AO_Raid_Stage_'..stage.index]=stage.enabled
end
for _,stage in ipairs(siege.stages) do
    flags['AO_Siege_Stage_'..stage.index]=stage.enabled
end
local function ensureDirs()
    if not disk then return end
    if type(makefolder)=='function' then
        pcall(makefolder,STORAGE)
        pcall(makefolder,CONFIG_DIR)
    end
end
local function readDisk(path)
    if not disk then return nil end
    local ok,result=pcall(readfile,path)
    return ok and result or nil
end
local function writeDisk(path,contents)
    if not disk then return false end
    ensureDirs()
    return pcall(writefile,path,contents)
end
local function profileId(value)
    value=tostring(value or ''):gsub('^%s+',''):gsub('%s+$','')
    if #value<1 or #value>32 or not value:match('^[%w_%-]+$') then return nil end
    return value
end
local function profileFile(name) return CONFIG_DIR..'/'..name..'.json' end
local function uniqueNames(names)
    local result,seen={},{}
    for _,name in ipairs(names) do
        if profileId(name) and not seen[name] then
            seen[name]=true
            result[#result+1]=name
        end
    end
    table.sort(result)
    return result
end
local function readJson(path)
    local data=readDisk(path)
    if not data then return nil end
    local ok,obj=pcall(function() return HttpService:JSONDecode(data) end)
    return ok and type(obj)=='table' and obj or nil
end
local function saveIndex()
    storedNames=uniqueNames(storedNames)
    writeDisk(INDEX_FILE,HttpService:JSONEncode(storedNames))
end
local function loadIndex()
    local arr=readJson(INDEX_FILE)
    if arr then
        for _,name in ipairs(arr) do storedNames[#storedNames+1]=name end
    end
    if type(listfiles)=='function' then
        local ok,paths=pcall(listfiles,CONFIG_DIR)
        if ok and type(paths)=='table' then
            for _,path in ipairs(paths) do
                local name=tostring(path):gsub('\\','/'):match('/([%w_%-]+)%.json$')
                if name then storedNames[#storedNames+1]=name end
            end
        end
    end
    storedNames=uniqueNames(storedNames)
end
local function snapshot()
    local result={}
    for k,v in pairs(flags) do result[k]=v end
    return result
end
local function saveProfile(name)
    name=profileId(name)
    if not name then configStatus='Invalid name: letters, digits, _ or -';return false end
    local data=HttpService:JSONEncode({version=102,flags=snapshot()})
    local ok=writeDisk(profileFile(name),data)
    if ok then
        currentProfile=name
        storedNames[#storedNames+1]=name
        saveIndex()
        configStatus='Saved: '..name
    else
        configStatus='Save failed (check executor file API)'
    end
    return ok
end
local function loadProfile(name)
    name=profileId(name)
    if not name then configStatus='Invalid profile';return false end
    local obj=readJson(profileFile(name))
    if not obj or type(obj.flags)~='table' then
        configStatus='Cannot read: '..name
        return false
    end
    for key,defaultValue in pairs(flags) do
        local value=obj.flags[key]
        if type(value)==type(defaultValue) then flags[key]=value end
    end
    currentProfile=name
    configStatus='Loaded: '..name
    return true
end
local function deleteProfile(name)
    name=profileId(name)
    if not name then return false end
    if name==autoProfile then
        configStatus='Cannot delete the active Auto Load profile'
        return false
    end
    if type(delfile)~='function' then
        configStatus='Executor has no delfile'
        return false
    end
    local ok=pcall(delfile,profileFile(name))
    if ok then
        local keep={}
        for _,value in ipairs(storedNames) do
            if value~=name then keep[#keep+1]=value end
        end
        storedNames=keep
        saveIndex()
        currentProfile='Default'
        configStatus='Deleted: '..name
    else
        configStatus='Delete failed: '..name
    end
    return ok
end
local function setAutoProfile(name)
    name=profileId(name)
    if not name or not saveProfile(name) then return false end
    if writeDisk(AUTO_FILE,name) then
        autoProfile=name
        configStatus='Auto Load: '..name
        return true
    end
    configStatus='Unable to write Auto Load marker'
    return false
end
-- Persist the current active profile as the profile to load next time.
-- Previously SAVE stored settings in a profile but autoLoad could still
-- point at an older profile, making AUTO Boss/Rift appear OFF on relaunch.
local function markCurrentForNextExecute()
    if not disk then return false end
    if writeDisk(AUTO_FILE,currentProfile) then
        autoProfile=currentProfile
        return true
    end
    configStatus='Saved profile, but Auto Load marker could not be updated'
    return false
end
loadIndex()
do
    local marker=readDisk(AUTO_FILE)
    if marker then
        marker=profileId(marker:gsub('%s+',''))
        if marker then autoProfile=marker end
    end
    if readDisk(profileFile(autoProfile)) then loadProfile(autoProfile) end
end
local revision=0
local function deferAutoSave()
    revision=revision+1
    local token=revision
    task.delay(0.9,function()
        if token==revision and state.alive then saveProfile(currentProfile) end
    end)
end
local function applyFlags()
    local alpha=tonumber(flags.AO_UI_Transparency) or 15
    if alpha~=alpha then alpha=15 end
    flags.AO_UI_Transparency=math.clamp(math.floor(alpha+.5),0,65)
    cfg.wantHell=flags.AO_Colo_Hell==true
    cfg.wantEndless=flags.AO_Colo_Endless==true
    if cfg.stopSpec~=flags.AO_Colo_StopFloor then
        if not applyFloorSpec(flags.AO_Colo_StopFloor) then
            flags.AO_Colo_StopFloor=cfg.stopSpec
        end
    end
    rift.setWalk(flags.AO_Rift_Walk)
    rift.setLeave(flags.AO_Rift_Leave)
    reconnect.enabled=flags.AO_Reconnect==true
    if not reconnect.enabled then reconnect.status='OFF' end
    for _,b in ipairs(boss.bosses) do
        boss.selectBoss(b.id,flags['AO_Boss_'..b.id])
        boss.setBorder(b.id,flags['AO_Border_'..b.id])
    end
    for _,stage in ipairs(raid.stages) do
        raid.selectStage(stage.index,flags['AO_Raid_Stage_'..stage.index])
    end
    for _,stage in ipairs(siege.stages) do
        siege.selectStage(stage.index,flags['AO_Siege_Stage_'..stage.index])
    end
    local wantColo=flags.AO_AutoColosseum==true
    local wantRift=flags.AO_AutoRift==true
    local wantBoss=flags.AO_AutoBoss==true
    local wantRaid=flags.AO_AutoRaid==true
    local wantSiege=flags.AO_AutoSiege==true
    -- Remote Colo owns no battle UI and can run alongside other modes.
    flags.AO_AutoColosseum=wantColo
    flags.AO_AutoRift=wantRift
    flags.AO_AutoBoss=wantBoss
    flags.AO_AutoRaid=wantRaid
    flags.AO_AutoSiege=wantSiege
    state.raidRequested=wantRaid
    state.bossRequested=wantBoss
    state.siegeRequested=wantSiege
    if wantColo and not state.enabled then
        state.transportStage='idle'
        state.transportAt=0
        state.transportAttempts=0
        state.transportOrigin=nil
        state.transportStatus='Connecting to ColosseumRemote'
    end
    if wantColo and not state.enabled then state.remoteNeedsSync=true end
    state.enabled=wantColo and not state.blocked
    if not state.enabled then
        state.pending=nil
        handoff.requested=false
        handoff.active=false
        handoff.returning=false
    elseif not wantRift then
        -- Turning Rift OFF during its preemption should return to Colo.
        if handoff.active then beginColoReturn() end
        handoff.requested=false
    end
    rift.enable(wantRift)
    boss.enable(wantBoss)
    raid.enable(wantRaid)
    siege.enable(wantSiege)
end
local repaintControls=function() end
local function setFlag(key,value)
    if flags[key]==nil then return end
    local wasOn=flags[key]==true
    flags[key]=value
    if key=='AO_UI_Transparency' then
        local alpha=tonumber(value) or 15
        if alpha~=alpha then alpha=15 end
        flags[key]=math.clamp(math.floor(alpha+.5),0,65)
        repaintControls()
        deferAutoSave()
        return
    end
    if key=='AO_AutoColosseum' and value==true and not wasOn and state.blocked then
        state.blocked=false;state.blockedReason=nil
        state.pending=nil;state.phase='';state.delayUntil=os.clock()+.5
    end
    if key=='AO_Colo_StopFloor' and not validStopSpec(value) then
        flags[key]=cfg.stopSpec
        configStatus='Stop Floor must be 35 or 30-40'
    end
    applyFlags()
    repaintControls()
    if key=='AO_AutoColosseum' or key=='AO_AutoRift'
        or key=='AO_AutoBoss' or key=='AO_AutoRaid' or key=='AO_AutoSiege' then
        -- Do not wait for the 0.9s debouncer for AUTO modes. Persist both
        -- the actual flags AND profile chosen for next execution now.
        revision=revision+1
        if saveProfile(currentProfile) then
            markCurrentForNextExecute()
            configStatus='AUTO saved + restored on execute: '..currentProfile
        end
    else
        deferAutoSave()
    end
end
applyFlags()
print('[ANIME ORIGIN / CONFIG] Loaded profile='..tostring(currentProfile)
    ..' autoLoad='..tostring(autoProfile)
    ..' | Colo='..tostring(flags.AO_AutoColosseum)
    ..' Rift='..tostring(flags.AO_AutoRift)
    ..' Boss='..tostring(flags.AO_AutoBoss)
    ..' Raid='..tostring(flags.AO_AutoRaid)
    ..' Siege='..tostring(flags.AO_AutoSiege))

local uiProfile=setmetatable({}, {
    __index=function(_,key)
        if key=='autoProfile' then return autoProfile end
        if key=='configStatus' then return configStatus end
        if key=='currentProfile' then return currentProfile end
        if key=='revision' then return revision end
        if key=='storedNames' then return storedNames end
    end,
    __newindex=function(_,key,value)
        if key=='autoProfile' then autoProfile=value;return end
        if key=='configStatus' then configStatus=value;return end
        if key=='currentProfile' then currentProfile=value;return end
        if key=='revision' then revision=value;return end
        if key=='storedNames' then storedNames=value;return end
        error('Unknown UI profile field: '..tostring(key))
    end,
})
local ui=UILibrary.Create({
    profile=uiProfile,
    playerGui=playerGui,
    state=state,
    flags=flags,
    cfg=cfg,
    Workspace=Workspace,
    env=env,
    UIS=UIS,
    rift=rift,
    boss=boss,
    raid=raid,
    siege=siege,
    reconnect=reconnect,
    handoff=handoff,
    setFlag=setFlag,
    applyFlags=applyFlags,
    requestReconnect=requestReconnect,
    loadIndex=loadIndex,
    saveProfile=saveProfile,
    loadProfile=loadProfile,
    deleteProfile=deleteProfile,
    setAutoProfile=setAutoProfile,
    markCurrentForNextExecute=markCurrentForNextExecute,
})
repaintControls=ui.Repaint
local refreshOverview=ui.Refresh
local function normalize(v)
    local s = tostring(v or '')
    s = s:gsub('<[^>]*>', '')
    s = s:gsub('%s+', ' ')
    s = s:gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    return s:upper() -- single return, no gsub multiple-value error
end
-- Shared strategy data used by the remote Colosseum controller.
local PDF_CARRIES = {
    ['DEATHLESS OUTLAW']=100,
    ['DEMON VENERABLE']=99,
    ['FIRE SOLDIER (EVOLVED)']=98,
    ['GHOUL HUNGER']=93,
    ['FLAME PILLAR']=91,
    ['TOWER KING']=88,
}
local PDF_SIDES = {
    ['SORCERER SUPREME']=100, ['HOLLOW HARVESTER']=85,
    ['SNIPER MAGE']=80, ['USELESS GODDESS (MUTATED)']=78,
    ['USELESS GODDESS']=58,
}
local PDF_SUPPORTS = {
    ['SENZU BEAN']=100, ['POTARA EARRINGS']=96,
    ['CURSED TOOL: PLAYFUL CLOUD']=88, ['LOG']=80,
    ['VIVRE CARD']=70, ['STAND ARROW']=55,
    ['AKATSUKI CLOUD CLOAK']=44, ['SUBSTITUTE SHINIGAMI BADGE']=42,
    ['DUEL DISK']=40,
}
-- Remote protocol verified against the user's 70-call Colosseum capture.
-- No NPC prompts, world teleports, GUI reads, or replay playback in this engine.
local function createRemoteColo()
    local engine={run=nil,synced=false,nextAt=0,busy=false,
        replayPending=false,blessingRejected={},diceRejected={},resync=true}
    local phaseNames={draft='DRAFT',ready='FIGHT WAVE',blessing='BLESSING',
        dice='ROLL DIE',diceCard='DICE CHOICE'}
    local function rank(card)
        return PDF_CARRIES[normalize(card.name)] or 0
    end
    local function carry(run)
        local best,bestScore=nil,-math.huge
        for slot,card in ipairs(run.team or {}) do
            local priority=rank(card)
            local score=priority>0 and priority*1e9
                or (tonumber(card.dmg) or 0)*10+(tonumber(card.maxHP) or 0)
            if score>bestScore then best,bestScore=slot,score end
        end
        return best,best and run.team[best]
    end
    local worldStats={'hpPct','dmgPct','dr','critDmg'}
    local function copyWorld(world)
        if type(world)~='table' then return nil end
        local copy={}
        for _,key in ipairs(worldStats) do copy[key]=tonumber(world[key]) or 0 end
        return copy
    end
    local function observeWorld(action,result)
        local current=copyWorld(result.run and result.run.world)
        if action=='lobby' or action=='start' then
            -- A resumed run provides totals, but no history of its last reward.
            engine.worldSnapshot=current
            state.worldBuffs=current
            state.worldBuffWave=action=='lobby' and result.run
                and math.max(0,(tonumber(result.run.wave) or 1)-1) or nil
            state.worldBuffDelta=nil
            return
        end
        if action=='fight' then
            state.worldBuffWave=tonumber(result.wave)
                or (engine.run and tonumber(engine.run.wave))
            state.worldBuffDelta={hpPct=0,dmgPct=0,dr=0,critDmg=0}
        end
        if current then
            if engine.worldSnapshot and state.worldBuffDelta then
                for _,key in ipairs(worldStats) do
                    state.worldBuffDelta[key]=state.worldBuffDelta[key]
                        +current[key]-engine.worldSnapshot[key]
                end
            end
            engine.worldSnapshot=current
            state.worldBuffs=current
        end
    end
    local function updateRun(run)
        engine.run=run
        if not run then return end
        state.phase=phaseNames[run.phase] or tostring(run.phase)
        state.lastSeenWave=math.max(0,(tonumber(run.wave) or 1)-1)
        local slot,card=carry(run)
        state.carrySlot=slot
        state.noCarry=card~=nil and rank(card)==0 and cfg.restartUntilCarry and cfg.autoRerun
        state.carryName=card and card.name or nil
        state.carryHp=card and card.hp or nil
        state.carryDmg=card and card.dmg or nil
        state.supportCount=card and (tonumber(card.supportCount) or #(card.supports or {})) or 0
        state.curseCount=#(run.devil or {})
        state.carryImmunity=false
        state.carryDodge=false
        state.sacredChosen={}
        for _,effect in ipairs(card and card.sacred or {}) do
            if effect.id=='immune' then
                state.carryImmunity=true
                state.sacredChosen['STATUS IMMUNITY']=true
            elseif effect.id=='dodge' then
                state.carryDodge=true
                state.sacredChosen['FIRST-HIT DODGE']=true
            end
        end
        if state.stopFloor==nil then state.stopFloor=chooseStopFloor() end
    end
    local function invoke(action,payload)
        local remote=ReplicatedStorage:FindFirstChild('ColosseumRemote',true)
        if not (remote and remote:IsA('RemoteFunction')) then
            coloPause('ColosseumRemote missing; no teleport/NPC fallback')
            return nil
        end
        engine.busy=true
        local ok,result=pcall(function()
            if action=='replayDone' then return remote:InvokeServer(action) end
            return remote:InvokeServer(action,payload)
        end)
        engine.busy=false
        engine.nextAt=os.clock()+cfg.poll
        -- A yielding response must not restart a stopped controller.
        if not state.alive then return nil end
        if not ok or type(result)~='table' then
            -- Mutation may have reached the server: resync rather than replay it.
            coloPause('Remote '..action..' response uncertain: '..tostring(result)..'; toggle AUTO to resync')
            engine.resync=true
            return nil
        end
        if result.ok~=true then
            local retry=tonumber(result.retryIn)
            state.transportStatus=tostring(result.reason or ('Remote '..action..' rejected'))
            if retry and retry==retry and retry>=0 and retry<math.huge then
                engine.nextAt=os.clock()+math.max(cfg.poll,retry)
                return nil
            end
            if action=='blessing' or action=='diceChoose' then return result end
            coloPause('Remote '..action..': '..state.transportStatus)
            return nil
        end
        state.verified=state.verified+1
        state.transportStatus='Remote: '..action
        observeWorld(action,result)
        if result.run~=nil then updateRun(result.run)
        elseif action=='lobby' or action=='forfeit' or result.summary then updateRun(nil) end
        if action=='start' then
            state.runCount=state.runCount+1
            state.draftRerolls=0
            state.stopFloor=chooseStopFloor()
        end
        if action=='fight' and result.summary then engine.replayPending=true end
        return result
    end
    local function draft(run)
        local rows=run.draft and run.draft.rows
        if type(rows)~='table' or #rows~=4 then
            coloPause('Remote draft: expected four offer rows');return
        end
        -- Preserve the original strategy: one best carry across all rows,
        -- then PDF_SIDES (or 45% of carry rank) for every other row.
        local bestCarry=nil
        for row,offers in ipairs(rows) do
            for index,card in ipairs(offers) do
                local score=rank(card)
                if score>0 and (not bestCarry or score>bestCarry.score) then
                    bestCarry={row=row,index=index,score=score}
                end
            end
        end
        local rerollsLeft=tonumber(run.rerollsLeft) or 0
        if not bestCarry and rerollsLeft>0 and state.draftRerolls<cfg.maxDraftRerolls then
            local result=invoke('reroll')
            if result and result.ok then state.draftRerolls=state.draftRerolls+1 end
            return
        end
        local picks={}
        for row,offers in ipairs(rows) do
            local pick,score=nil,-1
            if bestCarry and row==bestCarry.row then
                pick=bestCarry.index
            else
                for index,card in ipairs(offers) do
                    local value=PDF_SIDES[normalize(card.name)] or 0
                    if value==0 then value=rank(card)*.45 end
                    if value>score then pick,score=index,value end
                end
            end
            if not pick then coloPause('Remote draft: empty offer row');return end
            picks[row]=pick
        end
        -- Commit the draft first, just like START THE RUN in the original.
        -- No-carry runs are ended only after the server confirms ready/wave 1.
        invoke('draft',{picks=picks})
    end
    local function blessing(run)
        local slot,card=carry(run)
        if not card then coloPause('Remote blessing: team missing');return end
        local key=tostring(run.wave)
        engine.blessingRejected[key]=engine.blessingRejected[key] or {}
        local rejected=engine.blessingRejected[key]
        local candidates={}
        local offers=run.offer and run.offer.peoples or {}
        local count=tonumber(card.supportCount) or #(card.supports or {})
        -- ColosseumConfig: MAX_SUPPORTS_PER_CARD=4, SKILL_SUPPORT_CAP=8.
        -- Captured expanded teams retain supportMax=4 even at supportCount=8.
        local expanded=run.skill and (tonumber(run.skill.supportExpand) or 0)>0
        local capacity=expanded and 8 or (tonumber(card.supportMax) or 4)
        local owned={}
        for _,support in ipairs(card.supports or {}) do owned[normalize(support.name)]=true end
        if cfg.allowSupports and #offers>0 and count<capacity then
            local assign,staged={},{}
            local left=capacity-count
            local take,hasGood=0,false
            for index,support in ipairs(offers) do
                local name=normalize(support.name)
                if name~='' and not owned[name] and not staged[name] and left>0 then
                    assign[index]=slot
                    staged[name]=true;left=left-1;take=take+1
                    if (PDF_SUPPORTS[name] or 0)>=40 then hasGood=true end
                else
                    -- Skip sentinel is not present in the supplied capture.
                    -- Do not guess its protocol: only submit fully observed
                    -- assignment shapes; mixed batches fall through safely.
                    assign[index]=false
                end
            end
            if take==#offers and hasGood then
                candidates[#candidates+1]={key='peoples',payload={cat='peoples',assign=assign}}
            end
        end
        -- Restore the original priority after People's Blessing: three
        -- distinct preferred curses, then Sacred, then World stats.
        local devilOwned={}
        for _,curse in ipairs(run.devil or {}) do devilOwned[normalize(curse)]=true end
        if #(run.devil or {})<3 then
            for _,curse in ipairs({'Blinding','Confusion','Fatigue'}) do
                if not devilOwned[normalize(curse)] then
                    candidates[#candidates+1]={key='devil:'..curse,payload={cat='devil',opt=curse}}
                end
            end
        end
        local sacredOwned={}
        for _,effect in ipairs(card.sacred or {}) do sacredOwned[effect.id]=true end
        -- Both effects bind to the ranked carry slot. Re-read the server's
        -- sacred list after every success instead of marking a sent request.
        for _,effect in ipairs({'immune','dodge'}) do
            if not sacredOwned[effect] then
                candidates[#candidates+1]={key='sacred:'..effect,
                    payload={cat='sacred',opt=effect,slot=slot}}
            end
        end
        local name=normalize(card.name)
        local hp,dmg=tonumber(card.hp),tonumber(card.dmg)
        local preferHp=not hp or not dmg or dmg>=hp or name=='DEATHLESS OUTLAW'
            or name=='GHOUL HUNGER' or name=='DEMON VENERABLE'
        for _,opt in ipairs(preferHp and {'hp','dmg','dr','crit'} or {'dmg','hp','dr','crit'}) do
            candidates[#candidates+1]={key='world:'..opt,payload={cat='world',opt=opt}}
        end
        for _,candidate in ipairs(candidates) do
            if not rejected[candidate.key] then
                local result=invoke('blessing',candidate.payload)
                if result and result.ok==false then rejected[candidate.key]=true end
                return
            end
        end
        coloPause('Remote blessing: observed choices rejected; '..tostring(state.transportStatus))
    end
    local function dice(run)
        local slot,card=carry(run)
        if not card then coloPause('Remote dice: team missing');return end
        local key=tostring(run.wave)
        engine.diceRejected[key]=engine.diceRejected[key] or {}
        local rejected=engine.diceRejected[key]
        if not card.dead and (tonumber(card.hp) or 0)>0 and not rejected.buff then
            local result=invoke('diceChoose',{target=slot,bonus='buff'})
            if result and result.ok==false then rejected.buff=true end
            return
        end
        -- Replacement uses the captured {slot=...} protocol. Preserve the
        -- carry unless it is dead; otherwise replace the weakest other slot.
        local target=slot
        if not card.dead and (tonumber(card.hp) or 0)>0 then
            local weakest=math.huge
            for index,other in ipairs(run.team) do
                local score=(other.dead and -1e12 or 0)+rank(other)*1e6+(tonumber(other.dmg) or 0)
                if index~=slot and not rejected[index] and score<weakest then target,weakest=index,score end
            end
        end
        if rejected[target] then coloPause('Remote dice: observed choices rejected');return end
        local result=invoke('diceChoose',{slot=target})
        if result and result.ok==false then rejected[target]=true end
    end
    function engine.tick()
        if engine.busy or os.clock()<engine.nextAt then return end
        if handoff.active then return end
        if handoff.returning then
            handoff.returning=false;handoff.requireResume=false
            engine.resync=true
        end
        if engine.replayPending then
            local result=invoke('replayDone')
            if result and result.ok then engine.replayPending=false;engine.resync=true end
            return
        end
        if state.remoteNeedsSync then engine.resync=true;state.remoteNeedsSync=false end
        if engine.resync or not engine.synced then
            local result=invoke('lobby')
            if result and result.ok then engine.synced=true;engine.resync=false end
            return
        end
        local run=engine.run
        if handoff.requested and (not run or run.phase=='ready') then
            handoff.active=true;handoff.requested=false;handoff.startedAt=os.clock()
            handoff.fromPhase=state.phase;handoff.fromRun=state.runCount
            handoff.fromWave=state.lastSeenWave;handoff.requireResume=run~=nil
            state.transportStatus='Remote run paused for Rift'
            return
        end
        if not run then
            engine.blessingRejected={};engine.diceRejected={}
            state.phase='ENTER'
            if cfg.autoRerun or state.runCount==0 then
                invoke('start',{hell=cfg.wantHell,endless=cfg.wantEndless})
            end
        elseif run.phase=='draft' then draft(run)
        elseif run.phase=='blessing' then blessing(run)
        elseif run.phase=='dice' then invoke('dice')
        elseif run.phase=='diceCard' then dice(run)
        elseif run.phase=='ready' then
            if state.noCarry and cfg.restartUntilCarry and cfg.autoRerun
                and tonumber(run.wave)==1 then
                state.transportStatus='No PDF carry after rerolls; ending wave-1 run'
                invoke('forfeit')
            elseif cfg.wantEndless and state.stopFloor and state.lastSeenWave>=state.stopFloor then
                -- The supplied capture proves forfeit returns earned rewards;
                -- it does not contain a separate cashout command.
                invoke('forfeit')
            else invoke('fight') end
        else
            coloPause('Remote phase not present in capture: '..tostring(run.phase))
        end
    end
    return engine
end
local remoteColo=createRemoteColo()

task.spawn(function()
    while state.alive do
        if state.enabled and not state.blocked then
            local ok,err=pcall(remoteColo.tick)
            if not ok then
                coloPause('Lua error: '..tostring(err))
            end
        end
        -- Keep the remote cadence while AUTO is active.
        task.wait((state.enabled and not handoff.active and not handoff.returning)
            and cfg.poll or 0.60)
    end
end)
task.spawn(function()
    while state.alive do
        refreshOverview()
        task.wait(0.8)
    end
end)
