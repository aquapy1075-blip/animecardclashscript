--[[
 ANIME ORIGIN V10.7 | Add Multi-Siege (12-stage round-robin + server cooldown), Siege/Boss/Rift arbiter
  Preserve V10.6 Colosseum 0.25s cadence and Continue fix. No Colo logs.
  Colosseum / Rift Gate / Multi-Boss / Raid / Siege / Settings / Config
 Game source: provided rbxl + prior working V8.2/V5 scripts.
 Original battle/remote validation is handled by the game server.
]]
--[[
  ANIME ORIGIN V8.2 | Rayfield Gen2
  Colosseum: PDF carry + unique blessings / curse memory + Hell/Endless/Cash Out.
  Rift Gate: live event GUI flow (from the user's recorded Rift Gate session).
  UI: Colosseum / Rift Gate / Settings / Config.
  Both AUTO switches are persisted as stable Rayfield Gen2 flags and restored on execution.
  Colosseum entry: WorldsTeleportRequest:FireServer("Colosseum") FIRST,
  then humanoid walks to ColosseumPrompt and activates it.
  Colosseum: original 0.25s action cadence; zero console/file debug overhead.
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
    autoApproachNPC=true,
    useSignalFirst=true,
    inputFallback=true,
    chooseRandomWorldBuff=false,
    pdfStrategy=true,
    maxDraftRerolls=4,
    restartUntilCarry=true, -- PDF carry search is always enabled; no UI option
    allowSupports=true,
    autoBattleSpeed=false,
    poll=.25,
    ackWait=1.8,
    maxSacredBindAttempts=2,
    actionGap=.65,
}
local rng=Random.new()
local state={
    alive=true, enabled=false, window=nil,
    phase='', pending=nil, draftDone={}, picked={}, blocked=false,
    badSupport=false,lastPrompt=0,lastStatus='',lastPhase='',
    clickCount=0,verified=0,lastUnknown=0,delayUntil=0,dice=nil,
    stopFloor=nil,runCount=0,lastSeenWave=0,
    sacredStep=nil,sacredAt=0,sacredPlan=nil,
    carryName=nil,carrySlot=nil,teamNames={},carryHp=nil,carryDmg=nil,
    carryImmunity=false,carryDodge=false,noCarry=false,devilChosen={},
    supportOwned={},supportCount=0,supportPendingNames=nil,
    curseCount=0,curseUnavailable={},sacredChosen={},sacredUnavailable={},
    draftRerolls=0,draftRerollDisabled=false,supportRouteCount={},
    blessingsGiven=0,worldHpCount=0,worldDmgCount=0,noCarryCashout=false,
    transportStage='idle',transportAt=0,transportAttempts=0,transportOrigin=nil,
    transportStatus='Ready',
    reconnectStatus='Monitoring',
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
                if state.enabled and not state.blocked then
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
                if mainState.enabled then
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
                    if mainState.enabled then
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
    AO_Reconnect=true, AO_UI_Theme='Midnight',
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
    -- Colosseum + Rift may BOTH be ON. Rift preempts only at safe
    -- Colosseum boundaries; Boss/Raid remain exclusive with Colosseum.
    if wantColo then wantBoss=false;wantRaid=false;wantSiege=false end
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
        state.transportStatus='Teleporting to Colosseum'
    end
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
    if key=='AO_AutoColosseum' and value==true and not wasOn and state.blocked then
        state.blocked=false;state.blockedReason=nil
        state.pending=nil;state.phase='';state.delayUntil=os.clock()+.5
    end
    -- Colo/Rift coexist. Boss or Raid remain mutually exclusive with Colo.
    if value==true then
        if key=='AO_AutoColosseum' then
            flags.AO_AutoBoss=false
            flags.AO_AutoRaid=false
            flags.AO_AutoSiege=false
        elseif key=='AO_AutoBoss' or key=='AO_AutoRaid' or key=='AO_AutoSiege' then
            flags.AO_AutoColosseum=false
        end
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

local themes={
    Midnight={bg='101522',side='141C2B',panel='1B2536',row='232F43',text='EDF4FF',muted='96AAC5',accent='7C9EFF',line='33445E'},
    Ocean={bg='0D1922',side='112635',panel='173247',row='204159',text='ECFAFF',muted='9BBCCC',accent='53C8E6',line='325267'},
    Violet={bg='171322',side='20192E',panel='2B213C',row='392C50',text='F6EFFF',muted='B8A8D4',accent='BC8AFF',line='534267'},
    Emerald={bg='101C18',side='152B24',panel='1C372D',row='29463A',text='EFFFF4',muted='A0C8B0',accent='60D8A8',line='3E6454'},
    Rose={bg='23171C',side='311D27',panel='3E2633',row='503442',text='FFEFF4',muted='D9A9BC',accent='FF8FB2',line='704859'},
}
local function rgb(hex)
    return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
end
local themeColors={}
local skinned={}
local function color(role)
    return themeColors[role] or Color3.fromRGB(255,255,255)
end
local function skin(obj,property,role)
    skinned[#skinned+1]={obj=obj,property=property,role=role}
    obj[property]=color(role)
    return obj
end
local function make(class,parent,props)
    local obj=Instance.new(class)
    for key,value in pairs(props or {}) do obj[key]=value end
    obj.Parent=parent
    return obj
end
local function corner(obj,size)
    make('UICorner',obj,{CornerRadius=UDim.new(0,size or 9)})
end
local function stroke(obj)
    local s=make('UIStroke',obj,{Thickness=1,Transparency=0.15})
    skin(s,'Color','line')
end
local function newText(parent,label,size,bold)
    local l=make('TextLabel',parent,{
        BackgroundTransparency=1,Text=tostring(label),
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 13,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0,
    })
    skin(l,'TextColor3',bold and 'text' or 'muted')
    return l
end
local function uiButton(parent,caption,size)
    local b=make('TextButton',parent,{
        Text=caption,Size=size or UDim2.fromOffset(135,32),
        BackgroundTransparency=0,BorderSizePixel=0,
        Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=true,
        TextTruncate=Enum.TextTruncate.AtEnd,
    })
    corner(b,8)
    skin(b,'BackgroundColor3','row')
    skin(b,'TextColor3','text')
    return b
end

local root=make('ScreenGui',playerGui,{
    Name='AnimeOriginV10_7_UI',ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9900,
})
state.gui=root
local main=make('Frame',root,{
    Size=UDim2.fromOffset(805,565),Position=UDim2.new(.5,-402,.5,-282),
    BorderSizePixel=0,BackgroundTransparency=0,
})
corner(main,15)
skin(main,'BackgroundColor3','bg')
stroke(main)
local scale=make('UIScale',main,{Scale=1})
local function sizeForDevice()
    local camera=Workspace.CurrentCamera
    if not camera then return end
    local view=camera.ViewportSize
    local n=math.min(1,(view.X-24)/825,(view.Y-24)/585)
    scale.Scale=math.max(.53,n)
    main.Position=UDim2.new(.5,-402*scale.Scale,.5,-282*scale.Scale)
end
sizeForDevice()
if Workspace.CurrentCamera then
    local camera=Workspace.CurrentCamera
    local c=camera:GetPropertyChangedSignal('ViewportSize'):Connect(sizeForDevice)
    state.connections=state.connections or {}
    state.connections[#state.connections+1]=c
end
local header=make('Frame',main,{
    Size=UDim2.new(1,0,0,57),BackgroundTransparency=1,
})
local iconTile=make('Frame',header,{
    Position=UDim2.fromOffset(16,12),Size=UDim2.fromOffset(34,34),BorderSizePixel=0,
})
corner(iconTile,10)
skin(iconTile,'BackgroundColor3','accent')
local monogram=newText(iconTile,'AO',12,true)
monogram.TextColor3=Color3.fromRGB(17,23,37)
monogram.TextXAlignment=Enum.TextXAlignment.Center
monogram.Size=UDim2.fromScale(1,1)
local bigTitle=newText(header,'ANIME ORIGIN',17,true)
bigTitle.Position=UDim2.fromOffset(62,10)
bigTitle.Size=UDim2.fromOffset(250,22)
local smallTitle=newText(header,'Automation Hub  /  V10.7',11,false)
smallTitle.Position=UDim2.fromOffset(63,32)
smallTitle.Size=UDim2.fromOffset(260,16)
local hide=uiButton(header,'—',UDim2.fromOffset(30,28))
hide.Position=UDim2.new(1,-77,0,14)
local dismiss=uiButton(header,'×',UDim2.fromOffset(30,28))
dismiss.Position=UDim2.new(1,-42,0,14)

local sidebar=make('Frame',main,{
    Position=UDim2.fromOffset(0,57),Size=UDim2.new(0,174,1,-57),BorderSizePixel=0,
})
skin(sidebar,'BackgroundColor3','side')
local divider=make('Frame',main,{
    Position=UDim2.fromOffset(173,57),Size=UDim2.new(0,1,1,-57),BorderSizePixel=0,
})
skin(divider,'BackgroundColor3','line')
make('UIListLayout',sidebar,{
    Padding=UDim.new(0,8),FillDirection=Enum.FillDirection.Vertical,
    HorizontalAlignment=Enum.HorizontalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder,
})
make('UIPadding',sidebar,{PaddingTop=UDim.new(0,22)})
local body=make('Frame',main,{
    Position=UDim2.fromOffset(175,57),Size=UDim2.new(1,-175,1,-57),
    BackgroundTransparency=1,ClipsDescendants=true,
})
local selectedTab='Colosseum'
local navButtons={}
local tabPages={}
local tabNames={'Colosseum','Rift Gate','Multi-Boss','Raid','Siege','Settings','Config'}
for i,name in ipairs(tabNames) do
    local tab=uiButton(sidebar,name,UDim2.new(1,-20,0,39))
    tab.LayoutOrder=i
    tab.TextXAlignment=Enum.TextXAlignment.Left
    make('UIPadding',tab,{PaddingLeft=UDim.new(0,14)})
    navButtons[name]=tab
    local page=make('ScrollingFrame',body,{
        Name=name,Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,BorderSizePixel=0,Visible=name==selectedTab,
        CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=4,ScrollBarImageTransparency=.25,
    })
    skin(page,'ScrollBarImageColor3','accent')
    make('UIPadding',page,{
        PaddingTop=UDim.new(0,14),PaddingBottom=UDim.new(0,16),
        PaddingLeft=UDim.new(0,18),PaddingRight=UDim.new(0,19),
    })
    make('UIListLayout',page,{
        Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder,
    })
    tabPages[name]=page
    tab.MouseButton1Click:Connect(function()
        selectedTab=name
        for title,p in pairs(tabPages) do p.Visible=(title==name) end
        repaintControls()
    end)
end
local widgets={}
local statusLabels={}
local orderCounter=0
local function section(tab,label)
    orderCounter=orderCounter+1
    local t=newText(tabPages[tab],label,15,true)
    t.Size=UDim2.new(1,0,0,30)
    t.LayoutOrder=orderCounter
    return t
end
local function row(tab,label)
    orderCounter=orderCounter+1
    local parent=tabPages[tab]
    local r=make('Frame',parent,{
        Size=UDim2.new(1,-2,0,49),BorderSizePixel=0,
        LayoutOrder=orderCounter,
    })
    corner(r,9)
    skin(r,'BackgroundColor3','panel')
    local nameLabel=newText(r,label,13,true)
    nameLabel.Position=UDim2.fromOffset(14,0)
    nameLabel.Size=UDim2.new(1,-221,1,0)
    return r
end
local function addStatus(tab,label,initial)
    local r=row(tab,label)
    local s=newText(r,initial or '--',12,false)
    s.Position=UDim2.new(1,-260,0,0)
    s.Size=UDim2.new(0,246,1,0)
    s.TextXAlignment=Enum.TextXAlignment.Right
    statusLabels[label]=s
    return s
end
local function addToggle(tab,label,key)
    local r=row(tab,label)
    local b=uiButton(r,'OFF',UDim2.fromOffset(94,31))
    b.Position=UDim2.new(1,-109,.5,-15)
    b.MouseButton1Click:Connect(function() setFlag(key,not flags[key]) end)
    widgets[#widgets+1]=function()
        local on=flags[key]==true
        b.Text=on and 'ON  ●' or 'OFF  ○'
        b.BackgroundColor3=on and color('accent') or color('row')
        b.TextColor3=on and color('bg') or color('muted')
    end
    return b
end

local menu=make('Frame',root,{
    Visible=false,Size=UDim2.fromOffset(184,0),BorderSizePixel=0,
    BackgroundTransparency=0,ZIndex=150,
})
corner(menu,10)
skin(menu,'BackgroundColor3','side')
stroke(menu)
local function hideMenu() menu.Visible=false end
local function openMenu(anchor,options,choose)
    for _,child in ipairs(menu:GetChildren()) do
        if child:IsA('GuiButton') then child:Destroy() end
    end
    if #options==0 then options={'(empty)'} end
    local height=#options*35+10
    local position=anchor.AbsolutePosition
    local camera=Workspace.CurrentCamera
    local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
    local top=position.Y+anchor.AbsoluteSize.Y+4
    if top+height>viewport.Y-8 then top=math.max(10,position.Y-height-4) end
    menu.Size=UDim2.fromOffset(184,height)
    menu.Position=UDim2.fromOffset(math.max(5,math.min(position.X,viewport.X-194)),top)
    for i,label in ipairs(options) do
        local choice=uiButton(menu,tostring(label),UDim2.fromOffset(174,31))
        choice.Position=UDim2.fromOffset(5,5+(i-1)*35)
        choice.ZIndex=152
        choice.MouseButton1Click:Connect(function()
            hideMenu()
            choose(i,label)
        end)
    end
    menu.Visible=true
end
local function addDropdown(tab,label,key,choices,indexed)
    local r=row(tab,label)
    local b=uiButton(r,'--  ▾',UDim2.fromOffset(180,31))
    b.Position=UDim2.new(1,-195,.5,-15)
    b.MouseButton1Click:Connect(function()
        if menu.Visible then hideMenu();return end
        openMenu(b,choices,function(index,value)
            setFlag(key,indexed and index or value)
        end)
    end)
    widgets[#widgets+1]=function()
        local v=flags[key]
        if indexed then v=choices[math.clamp(tonumber(v) or 1,1,#choices)] end
        b.Text=tostring(v or '--')..'  ▾'
    end
    return b
end
local function addInput(tab,label,key,placeholder)
    local r=row(tab,label)
    local box=make('TextBox',r,{
        Size=UDim2.fromOffset(180,31),Position=UDim2.new(1,-195,.5,-15),
        BackgroundTransparency=0,BorderSizePixel=0,TextSize=13,
        Font=Enum.Font.GothamMedium,PlaceholderText=placeholder or '',
        ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Center,
    })
    corner(box,8)
    skin(box,'BackgroundColor3','row')
    skin(box,'TextColor3','text')
    skin(box,'PlaceholderColor3','muted')
    box.FocusLost:Connect(function() setFlag(key,box.Text) end)
    widgets[#widgets+1]=function()
        if not box:IsFocused() then box.Text=tostring(flags[key] or '') end
    end
    return box
end
local function addAction(tab,label,caption,callback)
    local r=row(tab,label)
    local b=uiButton(r,caption,UDim2.fromOffset(180,31))
    b.Position=UDim2.new(1,-195,.5,-15)
    b.MouseButton1Click:Connect(callback)
    return b
end
local function paintTheme()
    local raw=themes[flags.AO_UI_Theme] or themes.Midnight
    for role,hex in pairs(raw) do themeColors[role]=rgb(hex) end
    for _,item in ipairs(skinned) do
        if item.obj.Parent then
            pcall(function() item.obj[item.property]=color(item.role) end)
        end
    end
end
repaintControls=function()
    paintTheme()
    for title,b in pairs(navButtons) do
        b.BackgroundColor3=(title==selectedTab) and color('accent') or color('side')
        b.TextColor3=(title==selectedTab) and color('bg') or color('muted')
    end
    for _,fn in ipairs(widgets) do fn() end
end

section('Colosseum','Colosseum')
addToggle('Colosseum','Auto Colosseum','AO_AutoColosseum')
addToggle('Colosseum','Hell Mode','AO_Colo_Hell')
addToggle('Colosseum','Endless Mode','AO_Colo_Endless')
addInput('Colosseum','Stop Floor','AO_Colo_StopFloor','35 or 30-40')
section('Colosseum','Live Status')
local colStatus=addStatus('Colosseum','Colo status','OFF')
local colCarry=addStatus('Colosseum','Carry','--')
local colProgress=addStatus('Colosseum','PB / Curse / Floor','--')

section('Rift Gate','Rift Gate')
addToggle('Rift Gate','Auto Rift','AO_AutoRift')
addToggle('Rift Gate','Walk to NPC','AO_Rift_Walk')
addToggle('Rift Gate','Auto Leave','AO_Rift_Leave')
section('Rift Gate','Live Status')
local riftStatus=addStatus('Rift Gate','Rift status','OFF')
local riftTimer=addStatus('Rift Gate','Next Rift','READY')
local riftClears=addStatus('Rift Gate','Clears','0')

section('Multi-Boss','Multi-Boss')
addToggle('Multi-Boss','Auto Boss','AO_AutoBoss')
local bossStatus=addStatus('Multi-Boss','Boss status','OFF')
for _,b in ipairs(boss.bosses) do
    orderCounter=orderCounter+1
    local r=make('Frame',tabPages['Multi-Boss'],{
        Size=UDim2.new(1,-2,0,51),BorderSizePixel=0,LayoutOrder=orderCounter,
    })
    corner(r,9)
    skin(r,'BackgroundColor3','panel')
    local name=newText(r,b.name,13,true)
    name.Position=UDim2.fromOffset(12,0)
    name.Size=UDim2.fromOffset(117,51)
    local toggle=uiButton(r,'OFF',UDim2.fromOffset(61,29))
    toggle.Position=UDim2.fromOffset(132,11)
    local dropdown=uiButton(r,'Normal ▾',UDim2.fromOffset(136,29))
    dropdown.Position=UDim2.fromOffset(204,11)
    local timer=newText(r,'CHECKING',12,true)
    timer.Position=UDim2.new(1,-140,0,0)
    timer.Size=UDim2.fromOffset(128,51)
    timer.TextXAlignment=Enum.TextXAlignment.Right
    toggle.MouseButton1Click:Connect(function()
        setFlag('AO_Boss_'..b.id,not flags['AO_Boss_'..b.id])
    end)
    dropdown.MouseButton1Click:Connect(function()
        if menu.Visible then hideMenu();return end
        openMenu(dropdown,boss.borders,function(index)
            setFlag('AO_Border_'..b.id,index)
        end)
    end)
    widgets[#widgets+1]=function()
        local on=flags['AO_Boss_'..b.id]==true
        toggle.Text=on and 'ON' or 'OFF'
        toggle.BackgroundColor3=on and color('accent') or color('row')
        toggle.TextColor3=on and color('bg') or color('muted')
        dropdown.Text=boss.borders[math.clamp(tonumber(flags['AO_Border_'..b.id]) or 1,1,6)]..' ▾'
    end
    b.displayCooldown=timer
end
local bossCounts=addStatus('Multi-Boss','Wins / Losses','0 / 0')

section('Raid','Auto Raid')
addToggle('Raid','Auto Raid','AO_AutoRaid')
local raidStatus=addStatus('Raid','Raid status','OFF')
section('Raid','Select Stages')
for _,stage in ipairs(raid.stages) do
    orderCounter=orderCounter+1
    local item=make('Frame',tabPages['Raid'],{
        Size=UDim2.new(1,-2,0,49),BorderSizePixel=0,LayoutOrder=orderCounter,
    })
    corner(item,9)
    skin(item,'BackgroundColor3','panel')
    local label=newText(item,'Stage '..stage.index..' - '..stage.name,13,true)
    label.Position=UDim2.fromOffset(14,0)
    label.Size=UDim2.new(1,-245,1,0)
    local timer=newText(item,'SYNC',12,true)
    timer.Position=UDim2.new(1,-229,0,0)
    timer.Size=UDim2.fromOffset(112,49)
    timer.TextXAlignment=Enum.TextXAlignment.Right
    local toggle=uiButton(item,'OFF',UDim2.fromOffset(94,31))
    toggle.Position=UDim2.new(1,-109,.5,-15)
    local key='AO_Raid_Stage_'..stage.index
    toggle.MouseButton1Click:Connect(function() setFlag(key,not flags[key]) end)
    widgets[#widgets+1]=function()
        local enabled=flags[key]==true
        toggle.Text=enabled and 'ON  ●' or 'OFF  ○'
        toggle.BackgroundColor3=enabled and color('accent') or color('row')
        toggle.TextColor3=enabled and color('bg') or color('muted')
    end
    stage.displayCooldown=timer
end
local raidCounts=addStatus('Raid','Wins / Losses','0 / 0')

section('Siege','Auto Siege — Round Robin')
addToggle('Siege','Auto Siege','AO_AutoSiege')
local siegeStatus=addStatus('Siege','Siege status','OFF')
local siegeCounts=addStatus('Siege','Wins / Losses','0 / 0')
section('Siege','Select multiple stages (1–12)')
for _,stage in ipairs(siege.stages) do
    orderCounter=orderCounter+1
    local item=make('Frame',tabPages['Siege'],{
        Size=UDim2.new(1,-2,0,49),BorderSizePixel=0,LayoutOrder=orderCounter,
    })
    corner(item,9);skin(item,'BackgroundColor3','panel')
    local label=newText(item,string.format('%02d  %s',stage.index,stage.name),12,true)
    label.Position=UDim2.fromOffset(14,0)
    label.Size=UDim2.new(1,-238,1,0)
    local timer=newText(item,'SYNC',12,true)
    timer.Position=UDim2.new(1,-227,0,0)
    timer.Size=UDim2.fromOffset(110,49)
    timer.TextXAlignment=Enum.TextXAlignment.Right
    local toggle=uiButton(item,'OFF',UDim2.fromOffset(91,31))
    toggle.Position=UDim2.new(1,-107,.5,-15)
    local key='AO_Siege_Stage_'..stage.index
    toggle.MouseButton1Click:Connect(function() setFlag(key,not flags[key]) end)
    widgets[#widgets+1]=function()
        local on=flags[key]==true
        toggle.Text=on and 'ON  ●' or 'OFF  ○'
        toggle.BackgroundColor3=on and color('accent') or color('row')
        toggle.TextColor3=on and color('bg') or color('muted')
    end
    stage.displayCooldown=timer
end

section('Settings','Appearance')
addDropdown('Settings','Theme','AO_UI_Theme',{'Midnight','Ocean','Violet','Emerald','Rose'},false)
section('Settings','Connection')
addToggle('Settings','Auto Reconnect','AO_Reconnect')
local reconnectStatus=addStatus('Settings','Reconnect','Monitoring')
addAction('Settings','Reconnect Now','REJOIN',function()
    reconnect.attempts=0
    reconnect.lastTry=-math.huge
    requestReconnect(true)
end)
section('Settings','Session')
addAction('Settings','Stop Script','STOP SCRIPT',function()
    state.stop()
    if env.AnimeOriginV10_7==state then env.AnimeOriginV10_7=nil end
    if root.Parent then root:Destroy() end
end)

section('Config','Profiles')
local configRow=row('Config','Config Name')
local nameInput=make('TextBox',configRow,{
    Size=UDim2.fromOffset(180,31),Position=UDim2.new(1,-195,.5,-15),
    Font=Enum.Font.GothamMedium,TextSize=13,BorderSizePixel=0,
    BackgroundTransparency=0,Text=currentProfile,ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Center,
})
corner(nameInput,8)
skin(nameInput,'BackgroundColor3','row')
skin(nameInput,'TextColor3','text')
local savedDrop
savedDrop=addAction('Config','Saved Config','SELECT  ▾',function()
    if menu.Visible then hideMenu();return end
    loadIndex()
    openMenu(savedDrop,storedNames,function(index,name)
        if name~='(empty)' then
            currentProfile=name
            nameInput.Text=name
            configStatus='Selected: '..name
        end
    end)
end)
addAction('Config','Save','SAVE',function()
    revision=revision+1
    if saveProfile(nameInput.Text) then
        nameInput.Text=currentProfile
        if markCurrentForNextExecute() then
            configStatus='Saved + will Auto Load: '..currentProfile
        end
    end
end)
addAction('Config','Load','LOAD',function()
    revision=revision+1
    if loadProfile(nameInput.Text) then applyFlags();repaintControls() end
end)
addAction('Config','Delete','DELETE',function()
    revision=revision+1
    if deleteProfile(nameInput.Text) then nameInput.Text=currentProfile end
end)
addAction('Config','Set as Auto Load','SET AUTO LOAD',function()
    revision=revision+1
    if setAutoProfile(nameInput.Text) then nameInput.Text=currentProfile end
end)
addAction('Config','Reload Auto Load','RELOAD',function()
    revision=revision+1
    if loadProfile(autoProfile) then
        nameInput.Text=currentProfile
        applyFlags()
        repaintControls()
    end
end)
section('Config','Profile Status')
local configCurrent=addStatus('Config','Auto Load Profile','Default')
local configResult=addStatus('Config','Storage','--')

-- Header drag; hide/minimize never stops an AUTO loop.
local dragging=false
local originMouse,originPosition
header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        originMouse=input.Position
        originPosition=main.Position
    end
end)
local dragMove=UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=input.Position-originMouse
        main.Position=UDim2.new(originPosition.X.Scale,originPosition.X.Offset+delta.X,
            originPosition.Y.Scale,originPosition.Y.Offset+delta.Y)
    end
end)
local dragEnd=UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
local hotkey=UIS.InputBegan:Connect(function(input,used)
    if not used and input.KeyCode==Enum.KeyCode.RightShift and state.alive then
        root.Enabled=not root.Enabled
    end
end)
state.connections=state.connections or {}
for _,conn in ipairs({dragMove,dragEnd,hotkey}) do
    state.connections[#state.connections+1]=conn
end
hide.MouseButton1Click:Connect(function()
    local small=main.Size.Y.Offset<100
    main.Size=UDim2.fromOffset(805,small and 565 or 57)
    sidebar.Visible=small
    divider.Visible=small
    body.Visible=small
    hide.Text=small and '—' or '▢'
end)
dismiss.MouseButton1Click:Connect(function() root.Enabled=false end)
local stopEverything=state.stop
state.stop=function()
    stopEverything()
    for _,conn in ipairs(state.connections or {}) do pcall(function() conn:Disconnect() end) end
end
local function showStatus(widget,value)
    if widget and widget.Parent and widget.Text~=value then widget.Text=value end
end
local overviewLast=0
local function refreshOverview()
    if os.clock()-overviewLast<0.7 then return end
    overviewLast=os.clock()
    if not root.Parent then return end
    local colLabel=state.blocked and ('PAUSED: '..tostring(state.blockedReason or 'Unknown'))
        or (state.enabled and (handoff.active and 'RIFT PRIORITY / Colo suspended'
            or handoff.returning and ('RESUME COLO / '..tostring(state.transportStatus))
            or tostring((state.phase~='' and state.phase) or state.transportStatus or 'ON')) or 'OFF')
    showStatus(colStatus,colLabel)
    showStatus(colCarry,tostring(state.carryName or '--')..'  /  Floor '..tostring(state.lastSeenWave))
    showStatus(colProgress,tostring(state.supportCount)..'/8  /  '..tostring(state.curseCount)..'/3  /  '..tostring(state.stopFloor or cfg.stopSpec))
    showStatus(riftStatus,(rift.state.on and 'ON / ' or 'OFF / ')..tostring(rift.state.status or 'WAITING'))
    showStatus(riftTimer,rift.cooldownText())
    showStatus(riftClears,tostring(rift.state.clears or 0))
    showStatus(bossStatus,(boss.state.running and 'ON / ' or 'OFF / ')..tostring(boss.state.status or '--'))
    showStatus(bossCounts,tostring(boss.state.wins)..' / '..tostring(boss.state.losses))
    showStatus(raidStatus,(raid.state.on and 'ON / ' or 'OFF / ')..tostring(raid.state.status))
    showStatus(raidCounts,tostring(raid.state.wins)..' / '..tostring(raid.state.losses))
    showStatus(siegeStatus,(siege.state.on and 'ON / ' or 'OFF / ')..tostring(siege.state.status))
    showStatus(siegeCounts,tostring(siege.state.wins)..' / '..tostring(siege.state.losses))
    for _,stage in ipairs(siege.stages) do
        local cd=siege.cooldownText(stage)
        showStatus(stage.displayCooldown,cd)
        stage.displayCooldown.TextColor3=cd=='READY' and Color3.fromRGB(104,225,168)
            or cd=='LOCKED' and Color3.fromRGB(245,128,128) or color('muted')
    end
    for _,stage in ipairs(raid.stages) do
        local text=raid.cooldownText(stage)
        showStatus(stage.displayCooldown,text)
        stage.displayCooldown.TextColor3=text=='READY' and Color3.fromRGB(104,225,168)
            or text=='LOCKED' and Color3.fromRGB(245,128,128) or color('muted')
    end
    for _,b in ipairs(boss.bosses) do
        local cd=boss.cooldownText(b)
        showStatus(b.displayCooldown,cd)
        b.displayCooldown.TextColor3=(cd=='READY') and Color3.fromRGB(104,225,168)
            or (cd=='N/A' and Color3.fromRGB(245,128,128) or color('muted'))
    end
    showStatus(reconnectStatus,tostring(state.reconnectStatus or reconnect.status or '--'))
    showStatus(configCurrent,tostring(autoProfile))
    showStatus(configResult,configStatus)
end
repaintControls()
refreshOverview()
local function normalize(v)
    local s = tostring(v or '')
    s = s:gsub('<[^>]*>', '')
    s = s:gsub('%s+', ' ')
    s = s:gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    return s:upper() -- single return, no gsub multiple-value error
end
local function visible(o)
    local node = o
    while node and node ~= playerGui do
        if node:IsA('GuiObject') and not node.Visible then return false end
        if node:IsA('LayerCollector') and not node.Enabled then return false end
        node = node.Parent
    end
    return o ~= nil
end
local function validButton(o)
    if not (o and o:IsA('GuiButton') and o.Active and visible(o)) then return false end
    if o.Name == '__MenuClickShield' or o.Name == 'Close' then return false end
    local sz, pos = o.AbsoluteSize, o.AbsolutePosition
    if sz.X < 16 or sz.Y < 15 then return false end
    local camera = Workspace.CurrentCamera
    if camera then
        local viewport = camera.ViewportSize
        local middle = pos + sz / 2
        if middle.X < 0 or middle.Y < 0 or middle.X > viewport.X or middle.Y > viewport.Y then return false end
    end
    return true
end
-- Only own Text/descendants. Never siblings or inherited parent text.
local function ownLabel(o)
    if o:IsA('TextButton') then
        local s = normalize(o.Text)
        if s ~= '' then return s end
    end
    local labels, seen = {}, {}
    for _, d in ipairs(o:GetDescendants()) do
        if (d:IsA('TextLabel') or d:IsA('TextButton')) and visible(d) then
            local s = normalize(d.Text)
            if s ~= '' and not seen[s] then
                seen[s] = true
                table.insert(labels,s)
            end
        end
    end
    if #labels == 1 then return labels[1] end
    return table.concat(labels, ' / ')
end
-- Guide (pages 1-2, 4-8): choose ONE carry, make other slots supports,
-- concentrate the good People's Blessings on that carry; Dice stats/revive
-- target that exact card. No card quality is inferred from rarity.
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
-- The Devil Play counter is an authoritative UI acknowledgement even when
-- the blessing page stays open after a curse click. Never infer success from
-- firesignal() returning true.
local function readDevilCount(colo)
    if not colo then return nil end
    for _,d in ipairs(colo:GetDescendants()) do
        if (d:IsA('TextLabel') or d:IsA('TextButton')) and visible(d) then
            local n=normalize(d.Text):match('DEVIL PLAY%s*%((%d+)%s*/%s*3%)')
            if n then return tonumber(n) end
        end
    end
    return nil
end
local function ownedSupportCount()
    local n=0
    for _,yes in pairs(state.supportOwned or {}) do if yes then n=n+1 end end
    return math.max(n, state.supportCount or 0)
end
local function confirmBlessingSuccess(p)
    if p.key=='TAKE SUPPORTS' then
        local count=0
        for name,yes in pairs(p.supportBatch or {}) do
            if yes and not state.supportOwned[name] then
                state.supportOwned[name]=true
                count=count+1
            end
        end
        state.supportCount=math.min(8,math.max(state.supportCount or 0,ownedSupportCount()))
        state.supportPendingNames=nil

    end
    local curse=p.key:match('^DEVIL:([A-Z ]+)$')
    if curse then
        state.devilChosen[curse]=true
        state.curseUnavailable[curse]=nil
        state.curseCount=math.min(3, math.max((state.curseCount or 0)+1, p.devilBefore and p.devilBefore+1 or 0))

    end
    local effect=p.key:match('^SACRED:BIND:(.*)$')
    if effect then
        state.sacredChosen[effect]=true
        if effect=='STATUS IMMUNITY' then state.carryImmunity=true end
        if effect=='FIRST-HIT DODGE' then state.carryDodge=true end

    end
end
local function cleanCardName(label)
    local s = normalize(label)
    local cut=s:find(' / ',1,true)
    if cut then s=s:sub(1,cut-1) end
    return s
end
local function cardScore(name)
    name=cleanCardName(name)
    return PDF_CARRIES[name] or 0
end
local function sideScore(name)
    name=cleanCardName(name)
    return PDF_SIDES[name] or 0
end
local function numberFromText(v)
    local t=(tostring(v or ''):gsub(',',''))
    return tonumber(t)
end
local function getFrameLabels(frame)
    local texts={}
    if not frame then return texts end
    for _,v in ipairs(frame:GetDescendants()) do
        if (v:IsA('TextLabel') or v:IsA('TextButton')) and visible(v) then
            local text=normalize(v.Text)
            if text~='' then table.insert(texts,text) end
        end
    end
    return texts
end
-- Find exactly FOUR tall, sibling cards in preparation/Dice pages.
local function getTallCards(colo)
    local groups={}
    if not colo then return {} end
    for _,d in ipairs(colo:GetDescendants()) do
        if d:IsA('GuiButton') and validButton(d) then
            local z=d.AbsoluteSize
            if z.X>=170 and z.X<=290 and z.Y>=210 and z.Y<=650 then
                local parent=d.Parent
                if parent then
                    groups[parent]=groups[parent] or {}
                    table.insert(groups[parent],d)
                end
            end
        end
    end
    local out={}
    for frame,arr in pairs(groups) do
        if #arr==1 then
            local btn=arr[1]
            table.insert(out,{button=btn,parent=frame,x=btn.AbsolutePosition.X,y=btn.AbsolutePosition.Y,
                sizeY=btn.AbsoluteSize.Y,labels=getFrameLabels(frame)})
        end
    end
    if #out<4 then return {} end
    table.sort(out,function(a,b) return a.x<b.x end)
    -- Allow only a quartet sharing the same row (ignore tooltip/other UI).
    for i=1,#out-3 do
        local sub={out[i],out[i+1],out[i+2],out[i+3]}
        local same=true
        for j=2,4 do
            if math.abs(sub[j].y-sub[1].y)>35 or math.abs(sub[j].sizeY-sub[1].sizeY)>65 then same=false end
        end
        if same then
            for k,card in ipairs(sub) do
                card.slot=k
                card.name=state.teamNames[k]
                local joined=table.concat(card.labels,' / ')
                -- Use the *rendered* card names first, not the name from a previous run.
                for _,txt in ipairs(card.labels) do
                    if txt==state.carryName then card.name=txt end
                    for _,candidate in ipairs(state.teamNames) do
                        if txt==candidate then card.name=txt end
                    end
                end
                local current,maxv=joined:match('([%d,]+)%s*/%s*([%d,]+)')
                card.hp=numberFromText(current)
                card.maxHp=numberFromText(maxv)
                card.fallen=(card.hp==0) or joined:find('FALLEN',1,true)~=nil
                card.dmg=numberFromText(joined:match('DMG%s*([%d,]+)'))
            end
            return sub
        end
    end
    return {}
end
local function inspectCarryInTeam(colo)
    local cards=getTallCards(colo)
    for _,card in ipairs(cards) do
        if card.name and state.carryName and card.name==state.carryName then
            state.carrySlot=card.slot
            if card.maxHp then state.carryHp=card.maxHp end
            if card.dmg then state.carryDmg=card.dmg end
            local joined=table.concat(card.labels or {},' ')
            local visibleCount=tonumber(joined:match('(%d+)%s+SUPPORTS'))
            if visibleCount and visibleCount>(state.supportCount or 0) then
                state.supportCount=math.min(8,visibleCount)
            end
            return card
        end
    end
end
local function buttons(root)
    local list = {}
    for _, d in ipairs(root:GetDescendants()) do
        if validButton(d) then
            table.insert(list,{obj=d, text=ownLabel(d)})
        end
    end
    return list
end
local function findExact(list, target)
    target = normalize(target)
    for _, b in ipairs(list) do
        if b.text == target then return b.obj end
    end
end
local function findPattern(list, pattern)
    for _, b in ipairs(list) do
        if b.text:match(pattern) then return b.obj end
    end
end
local function hasText(root, needle)
    local term = normalize(needle)
    for _, d in ipairs(root:GetDescendants()) do
        if (d:IsA('TextLabel') or d:IsA('TextButton')) and visible(d) then
            if normalize(d.Text):find(term,1,true) then return true end
        end
    end
    return false
end
local function sigPart(b)
    -- Style changes on draft cards register when the selection is accepted.
    -- Do not include volatile timers or decorative FX elements.
    local s = tostring(b.BackgroundColor3)..':'..tostring(b.BackgroundTransparency)
    if b:IsA('TextButton') then s = s..':'..tostring(b.TextColor3) end
    for _, d in ipairs(b:GetDescendants()) do
        if d:IsA('UIStroke') then
            s = s..';stroke:'..tostring(d.Color)..':'..tostring(d.Thickness)..':'..tostring(d.Transparency)
        elseif d:IsA('UIGradient') then
            s = s..';gradient:'..tostring(d.Enabled)..':'..tostring(d.Rotation)
        elseif d:IsA('GuiObject') then
            s = s..';gui:'..d.Name..':'..tostring(d.Visible)..':'..tostring(d.BackgroundColor3)
            if d:IsA('ImageLabel') or d:IsA('ImageButton') then
                s=s..':'..tostring(d.ImageColor3)..':'..tostring(d.ImageTransparency)
            end
            if d:IsA('TextLabel') or d:IsA('TextButton') then
                s=s..':'..normalize(d.Text)..':'..tostring(d.TextColor3)
            end
        end
    end
    return s
end
local function phaseSignature(guiRoot, phase, draftRows)
    if phase == 'DRAFT' and draftRows then
        local parts = {}
        for r = 1, 4 do
            for _, b in ipairs(draftRows[r] or {}) do
                table.insert(parts, sigPart(b))
            end
        end
        -- Detect both in-card highlighting and text changes in the draft panel.
        -- Avoid decorative BorderFXComet nodes and volatile animation layers.
        for _, d in ipairs(guiRoot:GetDescendants()) do
            if d:IsA('TextLabel') and visible(d) and d.Parent
                and d.Parent.Name ~= 'FX' then
                local text=normalize(d.Text)
                if text:find('SLOT',1,true) or text:find('SELECTED',1,true)
                    or text:find('PICKED',1,true) or text:find('CHOSEN',1,true) then
                    table.insert(parts,'hint:'..text)
                end
            end
        end
        return table.concat(parts,'|')
    end
    local labels = {}
    for _, b in ipairs(buttons(guiRoot)) do
        if #labels < 90 then table.insert(labels,b.text) end
    end
    return table.concat(labels, '||')
end

local function findDraftRows(colo)
    -- Recorder proved exactly 16 card choices, 4 visual ROWS, each 4 siblings.
    -- Each card is 337x144 at x=304/651/999/1346 and row y=190/352/515/678
    -- at 1920x1080. Check structural grouping & text rather than exact pixels.
    local rows = {}
    for _, group in ipairs(colo:GetDescendants()) do
        if group:IsA('GuiObject') and visible(group) then
            local groupButtons = {}
            for _, child in ipairs(group:GetChildren()) do
                if child:IsA('GuiButton') and validButton(child) then
                    local size = child.AbsoluteSize
                    local t = ownLabel(child)
                    if size.X >= 160 and size.Y >= 85 and size.Y <= 350
                        and t:find(' HP',1,true) and t:find(' DMG',1,true)
                        and not t:find('CASH OUT',1,true) then
                        table.insert(groupButtons,child)
                    end
                end
            end
            if #groupButtons == 4 then
                table.sort(groupButtons,function(a,b) return a.AbsolutePosition.X < b.AbsolutePosition.X end)
                local y = groupButtons[1].AbsolutePosition.Y
                local coherent = true
                for i=2,4 do
                    if math.abs(groupButtons[i].AbsolutePosition.Y-y)>26 then coherent=false end
                end
                if coherent then table.insert(rows,{y=y,options=groupButtons}) end
            end
        end
    end
    table.sort(rows,function(a,b) return a.y<b.y end)
    if #rows ~= 4 then return nil end
    -- no duplicate Y or overlapping rows: fail closed instead of clicking Shop.
    for i=2,4 do if rows[i].y-rows[i-1].y<50 then return nil end end
    return {rows[1].options,rows[2].options,rows[3].options,rows[4].options}
end

local function draftChosenCount(colo)
    if not colo then return nil end
    for _,v in ipairs(colo:GetDescendants()) do
        if (v:IsA('TextLabel') or v:IsA('TextButton')) and visible(v) then
            local n=normalize(v.Text):match('^(%d+)%s*/%s*4 SLOTS CHOSEN$')
            if n then return tonumber(n) end
        end
    end
    return nil
end

local function getDiceOffers(colo)
    local result={}
    for _,v in ipairs(getTallCards(colo)) do
        -- Dice target cards are taller than prep cards (approx 500px in log).
        if v.sizeY>=420 then table.insert(result,v.button) end
    end
    return #result==4 and result or {}
end

local function getPhase(colo, battle)
    -- Restore the V10.4 battle detection verbatim. V10.5's FloorTitle-only
    -- branch could skip hasText() and mistake an active Colosseum fight for
    -- CLOSED, which also allowed Rift to steal control before CONTINUE.
    if battle and battle:IsA('ScreenGui') and battle.Enabled and hasText(battle,'COLOSSEUM') then
        return 'BATTLE', nil
    end
    if not (colo and colo:IsA('ScreenGui') and colo.Enabled) then return 'CLOSED', nil end
    local all = buttons(colo)
    -- Nested boss dialog has an outer TextButton containing all labels. Exact
    -- match must select the INNER FACE MAN OF MEN button, not the outer popup.
    local face = findPattern(all,'^FACE [%w%s%-]+$')
    if face then return 'FACE CHAMPION',face end
    local results = findExact(all,'SEE RESULTS')
    if results then return 'SEE RESULTS',results end
    local back = findExact(all,'BACK TO THE GATES')
    if back then return 'BACK GATES',back end
    local champion = findExact(all,'FIGHT THE CHAMPION')
    if champion then return 'FIGHT CHAMPION',champion end
    local fight = findPattern(all,'^FIGHT WAVE %d+$')
    if fight then return 'FIGHT WAVE',fight end
    local cont = findExact(all,'CONTINUE')
    if cont then return 'CONTINUE',cont end
    local die = findExact(all,'ROLL THE DIE')
    if die then return 'ROLL DIE',die end
    if hasText(colo,'CHOOSE 1 BLESSING') then return 'BLESSING',nil end
    if hasText(colo,'ELITE DICE REWARD') then return 'DICE CHOICE',nil end
    local start = findExact(all,'START THE RUN')
    if start then return 'DRAFT',start end
    local enter = findExact(all,'ENTER THE COLOSSEUM')
    if enter then return 'ENTER',enter end
    return 'UNKNOWN',nil
end

local function initiateInput(button, method)
    if not validButton(button) then return false,'invalid/hidden button' end
    if method == 'signal' then
        if type(firesignal) ~= 'function' then return false,'firesignal unavailable' end
        local ok,err = pcall(function() firesignal(button.MouseButton1Click) end)
        return ok, ok and 'firesignal(MouseButton1Click)' or tostring(err)
    elseif method == 'activated' then
        if type(firesignal) ~= 'function' then return false,'firesignal unavailable' end
        -- Some game UIs listen to Activated rather than MouseButton1Click.
        -- Only use this as a retry AFTER no response to the first signal.
        local ok,err = pcall(function() firesignal(button.Activated) end)
        return ok, ok and 'firesignal(Activated)' or tostring(err)
    end
    local pos = button.AbsolutePosition+button.AbsoluteSize/2
    local inset = Vector2.new(0,0)
    local okInset, offset = pcall(function() return GuiService:GetGuiInset() end)
    if okInset and typeof(offset)=='Vector2' then inset=offset end
    -- Manual input logs show cursor Y about 58px below AbsolutePosition;
    -- account for the game's GUI top inset for VirtualInputManager events.
    pos = pos + inset
    local ok,err = pcall(function()
        VIM:SendMouseButtonEvent(pos.X,pos.Y,0,true,game,0)
        task.wait(.12)
        VIM:SendMouseButtonEvent(pos.X,pos.Y,0,false,game,0)
    end)
    return ok,ok and 'VirtualInput+GuiInset' or tostring(err)
end

local function actionKey(phase, button, extra)
    return phase..'|'..tostring(button)..'|'..tostring(extra or '')
end
local function sendAction(phase, button, key, draftRows)
    if not (button and validButton(button)) then
        
        return
    end
    if state.pending then return end
    if os.clock()<state.delayUntil then return end
    local sig = phaseSignature(playerGui:FindFirstChild('ColosseumGui'),phase,draftRows)
    local method = cfg.useSignalFirst and 'signal' or 'input'
    if method=='signal' and type(firesignal)~='function' then method='input' end
    local ok,detail=initiateInput(button,method)
    if not ok and cfg.inputFallback then
        method='input'
        ok,detail=initiateInput(button,method)
    end
    if not ok then
        coloPause('Input failed '..tostring(phase)..' / '..tostring(key)..': '..tostring(detail))
        return
    end
    state.pending={phase=phase,btn=button,key=key or actionKey(phase,button),
        signature=sig,method=method,since=os.clock(),triedFallback=(method=='input'),triedActivated=false,attempts=1,
        draftRows=draftRows, buttonStyle=sigPart(button), oldText=ownLabel(button),
        devilBefore=(key and key:match('^DEVIL:')) and (readDevilCount(playerGui:FindFirstChild('ColosseumGui')) or state.curseCount) or nil,
        supportBatch=key=='TAKE SUPPORTS' and state.supportPendingNames or nil,
        draftCount=(phase=='DRAFT' and draftChosenCount(playerGui:FindFirstChild('ColosseumGui'))) or nil,
        draftOffers=draftRows and (function()
            local names={}
            for r=1,4 do for _,v in ipairs(draftRows[r] or {}) do
                table.insert(names,cleanCardName(ownLabel(v)))
            end end
            return table.concat(names,'|')
        end)() or nil}
    state.clickCount=state.clickCount+1
    state.delayUntil=os.clock()+cfg.actionGap
    
end

local function resolvePending(colo,phase)
    local p=state.pending
    if not p then return false end
    if phase ~= p.phase then
        if p.phase=='BLESSING' then confirmBlessingSuccess(p) end
        state.verified=state.verified+1
        if p.phase=='DRAFT' then
            state.draftDone[tonumber(p.key:match('row(%d+)')) or 0]=true
        end
        
        state.pending=nil
        return true
    end
    local now=os.clock()
    if p.phase=='BLESSING' and p.key:match('^DEVIL:') then
        local live=readDevilCount(colo)
        local before=p.devilBefore or state.curseCount or 0
        if live and live>before then
            -- Count increment confirms selection even if we remain on the
            -- same screen; V5 missed this and kept clicking the same curse.
            local name=p.key:match('^DEVIL:(.*)$')
            state.devilChosen[name]=true
            state.curseCount=math.min(3,math.max(live,state.curseCount or 0))
            state.pending=nil
            state.verified=state.verified+1
            state.delayUntil=now+0.6
            
            return true
        end
    end
    if p.phase=='ENTER' then
        local mode,wanted=p.key:match('^MODE:([A-Z]+):([A-Z]+)$')
        if mode and colo then
            for _,item in ipairs(buttons(colo)) do
                if item.text:find(mode..': '..wanted,1,true)==1 then
                    state.verified=state.verified+1
                    state.pending=nil
                    
                    return true
                end
            end
        end
    end
    -- The draft stage doesn't change phase when one ROW selection is made.
    local newSig=phaseSignature(colo,phase,p.draftRows)
    if phase=='DRAFT' and p.key=='DRAFT:REROLL' then
        local rows=findDraftRows(colo)
        local names={}
        if rows then for r=1,4 do for _,v in ipairs(rows[r]) do
            table.insert(names,cleanCardName(ownLabel(v)))
        end end end
        if #names==16 and table.concat(names,'|')~=p.draftOffers then
            state.draftRerolls=state.draftRerolls+1
            state.draftDone={}; state.picked={}
            state.pending=nil; state.verified=state.verified+1
            
            return true
        end
    elseif phase=='DRAFT' and p.key:match('^row%d+$')
        and ((p.draftCount and draftChosenCount(colo) and draftChosenCount(colo)>p.draftCount)
             or (p.draftCount==nil and newSig~=p.signature)) then
        local row=tonumber(p.key:match('row(%d+)'))
        if row then state.draftDone[row]=true end
        state.verified=state.verified+1
        state.pending=nil
        
        return true
    end
    if p.phase=='BLESSING' and p.key:find('^SUPPORT_ROUTE:',1,false) then
        if ownLabel(p.btn)~=p.oldText then
            state.pending=nil;state.verified=state.verified+1
            
            return true
        end
        if now-p.since<cfg.ackWait then return true end
    end
    if p.phase=='BLESSING' and p.key:find('^SACRED:STEP:',1,false) then
        if sigPart(p.btn)~=p.buttonStyle or newSig~=p.signature then
            state.pending=nil; state.verified=state.verified+1
            state.sacredStep=state.sacredStep+1
            state.sacredAt=now+.35
            
            return true
        end
        if now-p.since<cfg.ackWait then return true end
    end
    -- Dice has TWO possible steps: first choose REVIVE/HEAL/etc., then
    -- choose one of four card targets. The UI header remains ELITE DICE
    -- REWARD throughout, so a same-phase result is NOT automatically failure.
    if p.phase == 'DICE CHOICE' then
        local dice = state.dice
        if not dice then
            state.pending=nil
            
            return true
        end
        if now-p.since < cfg.ackWait then return true end
        local modeName = p.key:match('^DICE MODE: (.*)$')
        if modeName then
            if modeName == 'REVIVE' or modeName == 'HEAL 25%' or modeName == '+10% STATS' then
                -- Neither button guarantees immediate transition. Select a card.
                state.pending=nil
                dice.awaitingTarget=true
                dice.targetTries={}
                dice.nextAt=now+0.30
                
                return true
            end
            -- KEEP MY TEAM generally finishes immediately.
            -- If still on the reward screen, try input once, then another mode.
            if not p.triedActivated and type(firesignal)=='function' then
                p.triedActivated=true
                local ok,how=initiateInput(p.btn,'activated')
                if ok then
                    p.since=now
                    state.clickCount=state.clickCount+1
                    
                    return true
                end
            end
            if not p.triedFallback and cfg.inputFallback then
                local ok,how=initiateInput(p.btn,'input')
                if ok then
                    p.since=now; p.triedFallback=true
                    state.clickCount=state.clickCount+1
                    
                    return true
                end
            end
            dice.triedModes[modeName]=true
            dice.mode=nil; dice.awaitingTarget=false
            dice.nextAt=now+0.35
            state.pending=nil
            
            return true
        end
        if p.key:find('^DICE TARGET:',1,false) then
            -- A replacement or REVIVE target normally exits the dice page.
            -- A denied target may leave the exact same page; rotate choices.
            if not p.triedActivated and type(firesignal)=='function' then
                p.triedActivated=true
                local ok,how=initiateInput(p.btn,'activated')
                if ok then
                    p.since=now
                    state.clickCount=state.clickCount+1
                    
                    return true
                end
            end
            if not p.triedFallback and cfg.inputFallback then
                local ok,how=initiateInput(p.btn,'input')
                if ok then
                    p.since=now; p.triedFallback=true
                    state.clickCount=state.clickCount+1
                    
                    return true
                end
            end
            dice.triedTargets[p.btn]=true
            local failedMode=dice.mode or 'REPLACE CARD'
            if state.carryName and (failedMode=='+10% STATS' or failedMode=='REVIVE' or failedMode=='HEAL 25%') then
                coloPause('Dice target rejected: '..tostring(failedMode)..' / '..tostring(state.carryName))
                state.pending=nil
                
                return true
            end
            local offers=getDiceOffers(colo)
            local unused=0
            for _,b in ipairs(offers) do
                if not dice.triedTargets[b] then unused=unused+1 end
            end
            if unused==0 then
                dice.triedModes[failedMode]=true
                dice.mode=nil; dice.awaitingTarget=false
                dice.triedTargets={}
                
            else
                
            end
            dice.nextAt=now+0.35
            state.pending=nil
            return true
        end
        -- Safety: unknown dice key should not pause the entire run.
        state.pending=nil
        dice.nextAt=now+0.5
        
        return true
    end
    -- Dice rollout can animate in the same phase; only treat complete when
    -- the roll button disappears and a reward choice appears.
    if p.phase=='ROLL DIE' and not findExact(buttons(colo),'ROLL THE DIE') then
        state.verified=state.verified+1
        state.pending=nil
        
        return true
    end
    if now-p.since<cfg.ackWait then return true end
    if p.phase=='BLESSING' and p.key:match('^DEVIL:') then
        -- Fast, bounded curse acknowledgement: either the Devil counter goes
        -- up or we make ONE real-input fallback, then mark that curse as
        -- unavailable for this entire run. Do NOT spam the same curse.
        if not p.triedFallback and cfg.inputFallback then
            p.triedFallback=true
            local ok,how=initiateInput(p.btn,'input')
            if ok then
                p.since=now
                state.clickCount=state.clickCount+1
                
                return true
            end
        end
        local failed=p.key:match('^DEVIL:(.*)$')
        state.curseUnavailable[failed]=true
        state.blessingTried=state.blessingTried or {}
        state.blessingTried[p.key]=true
        state.pending=nil
        state.delayUntil=now+0.5
        
        return true
    end
    if p.phase=='BLESSING' and p.key:match('^SACRED:BIND:') then
        -- SACRED HARD STOP: V6 retried the same refused BIND indefinitely
        -- because actionForBlessing checked 'SACRED:BIND' while timeout
        -- stored only 'SACRED:BIND:FIRST-HIT DODGE'. Limit to TWO total
        -- clicks, remember failure across the run, then try WORLD STATS NOW.
        local effect=p.key:match('^SACRED:BIND:(.*)$')
        if (p.attempts or 1)<cfg.maxSacredBindAttempts
            and p.method~='input' and cfg.inputFallback then
            p.attempts=(p.attempts or 1)+1
            p.triedFallback=true
            local ok,how=initiateInput(p.btn,'input')
            if ok then
                p.since=now
                state.clickCount=state.clickCount+1
                
                return true
            end
        end
        state.sacredUnavailable[effect]=true
        state.blessingTried=state.blessingTried or {}
        state.blessingTried[p.key]=true
        state.blessingTried['SACRED:BIND']=true
        state.sacredPlan=nil
        state.sacredStep=nil
        state.sacredAt=0
        state.pending=nil
        state.picked.blessing=nil
        state.delayUntil=now+0.35
        
        return true
    end
    if p.phase == 'BLESSING' then
        -- TRY CLICK -> ACTIVATED -> REAL INPUT before trying a different bonus.
        -- A valid client-side signal is NOT proof the server accepted a blessing.
        if not p.triedActivated and type(firesignal)=='function' then
            p.triedActivated=true
            local ok,how=initiateInput(p.btn,'activated')
            if ok then
                p.since=now
                state.clickCount=state.clickCount+1
                
                return true
            end
        end
        if not p.triedFallback and cfg.inputFallback then
            p.triedFallback=true
            local ok,how=initiateInput(p.btn,'input')
            if ok then
                p.since=now
                state.clickCount=state.clickCount+1
                
                return true
            end
        end
        -- No response to this choice. Move to the next WORLD option.
        state.blessingTried=state.blessingTried or {}
        state.blessingTried[p.key]=true
        local failedCurse=p.key:match('^DEVIL:(.*)$')
        if failedCurse then
            state.curseUnavailable[failedCurse]=true
            
        end
        if p.key=='TAKE SUPPORTS' then
            state.badSupport=true
            state.supportPendingNames=nil
        end
        if p.key:find('^SUPPORT_ROUTE:',1,false) then
            state.supportRouteFailed=true
            state.supportPendingNames=nil
        elseif p.key:find('^SACRED:STEP:',1,false) then
            local effect=state.sacredPlan and state.sacredPlan.effect
            if effect then state.sacredUnavailable[effect]=true end
            state.sacredStep=nil
            state.sacredPlan=nil
            state.blessingTried['SACRED:BIND']=true
        end
        state.pending=nil
        state.picked.blessing=nil
        state.delayUntil=now+0.5
        
        return true
    end
    if not p.triedFallback and cfg.inputFallback then
        local ok,how=initiateInput(p.btn,'input')
        if ok then
            p.since=now
            p.triedFallback=true
            state.clickCount=state.clickCount+1
            
            return true
        end
        if p.phase=='BLESSING' and p.key=='TAKE SUPPORTS' then
            state.badSupport=true
            state.pending=nil
            
            return true
        end
    end
    if p.phase=='BLESSING' and p.key=='TAKE SUPPORTS' then
        state.badSupport=true
        state.pending=nil
        
    elseif p.phase=='DRAFT' and p.key=='DRAFT:REROLL' then
        state.pending=nil
        state.draftRerollDisabled=true
        state.delayUntil=now+.4
        
    elseif p.phase=='DRAFT' then
        state.pending=nil
        coloPause('Draft no acknowledgement: '..tostring(p.key))
    else
        state.pending=nil
        coloPause('Action no acknowledgement: '..tostring(p.phase)..' / '..tostring(p.key))
        
    end
    return true
end

local function makeChoice(phase,button,name,draftRows)
    if not button then return end
    sendAction(phase,button,name,draftRows)
end

local function getSacredButtons(colo)
    local all=buttons(colo)
    local bind=findExact(all,'BIND')
    if not bind or not bind.Parent then return nil end
    local parent=bind.Parent
    local effects,targets={},{}
    for _,o in ipairs(parent:GetChildren()) do
        if validButton(o) and o~=bind then
            local t=ownLabel(o)
            if t:find('FIRST-HIT DODGE',1,true)==1 or t:find('SECOND WIND',1,true)==1
                or t:find('OPENING SHIELD',1,true)==1 or t:find('STATUS IMMUNITY',1,true)==1 then
                table.insert(effects,{button=o,text=t})
            end
        elseif o:IsA('Frame') then
            for _,b in ipairs(o:GetChildren()) do
                if validButton(b) and ownLabel(b)~='' then
                    table.insert(targets,{button=b,text=ownLabel(b)})
                end
            end
        end
    end
    return bind,effects,targets
end
local function getSupportRows(colo)
    local take=findExact(buttons(colo),'TAKE SUPPORTS')
    if not take then return nil end
    local section=take.Parent
    local scroll=section and section:FindFirstChildWhichIsA('ScrollingFrame',true)
    if not scroll then return nil end
    local rows={}
    for _,frame in ipairs(scroll:GetChildren()) do
        if frame:IsA('Frame') then
            local target=nil
            for _,v in ipairs(frame:GetChildren()) do
                if validButton(v) and v:IsA('TextButton') then target=v break end
            end
            if target then
                local supportName='UNKNOWN'
                local textLabels={}
                for _,v in ipairs(frame:GetChildren()) do
                    if v:IsA('TextLabel') then table.insert(textLabels,v) end
                end
                table.sort(textLabels,function(a,b) return a.AbsolutePosition.Y<b.AbsolutePosition.Y end)
                if #textLabels>0 then supportName=normalize(textLabels[1].Text) end
                table.insert(rows,{button=target,name=supportName,score=PDF_SUPPORTS[supportName] or 5})
            end
        end
    end
    table.sort(rows,function(a,b) return a.button.AbsolutePosition.Y<b.button.AbsolutePosition.Y end)
    return {take=take,rows=rows}
end
local function scrollTo(button)
    local parent=button.Parent
    while parent and parent~=playerGui do
        if parent:IsA('ScrollingFrame') then
            local y=button.AbsolutePosition.Y
            local top=parent.AbsolutePosition.Y
            local bottom=top+parent.AbsoluteSize.Y
            if y<top+8 or y+button.AbsoluteSize.Y>bottom-8 then
                local shift=(y+button.AbsoluteSize.Y/2)-(top+parent.AbsoluteSize.Y/2)
                parent.CanvasPosition=Vector2.new(parent.CanvasPosition.X,math.max(0,parent.CanvasPosition.Y+shift))
                return false
            end
        end
        parent=parent.Parent
    end
    return true
end
-- Run-wide memory rules from the PDF and the user's latest constraints:
-- 1) Only unique People's supports on the carry, capped at EIGHT.
-- 2) Only three preferred Devil curses: Blinding, Confusion, Fatigue.
--    Remember accepted/failed names across all blessing screens in this run.
-- 3) Then bind Status Immunity and First-Hit Dodge to the carry, once each.
-- 4) World stats are the final fallback, never another unit's supports.
local function actionForBlessing(colo)
    local all=buttons(colo)
    local tried=state.blessingTried or {}
    state.blessingTried=tried
    local observed=readDevilCount(colo)
    if observed then state.curseCount=math.min(3,math.max(state.curseCount or 0,observed)) end
    state.supportCount=math.min(8,ownedSupportCount())

    local support=getSupportRows(colo)
    -- Only select PB when there are genuinely NEW supports available for
    -- carry. Track the four rows as a transaction: commit AFTER TAKE SUPPORTS
    -- leaves the page, never when merely cycling a target label.
    if cfg.allowSupports and support and #support.rows==4
        and state.carryName and state.supportCount<8
        and not state.badSupport and not state.supportRouteFailed
        and not tried['TAKE SUPPORTS'] then
        local staged={}
        local slotsLeft=8-state.supportCount
        local targetName='→ '..state.carryName
        local wants={}
        local hasGood=false
        for i,row in ipairs(support.rows) do
            local name=normalize(row.name)
            local isUnique=(name~='' and name~='UNKNOWN'
                and not state.supportOwned[name] and not staged[name])
            local take=isUnique and slotsLeft>0
            if take then
                staged[name]=true
                slotsLeft=slotsLeft-1
                if row.score>=40 then hasGood=true end
            end
            wants[i]=take and targetName or 'SKIP THIS SUPPORT'
        end
        -- Prioritize PDF support quality, but don't take duplicate PB merely
        -- to fill a slot. If every offered card is old, go to Devil/Sacred.
        if hasGood then
            for i,row in ipairs(support.rows) do
                local current=ownLabel(row.button)
                if current~=wants[i] then
                    state.supportRouteCount[i]=(state.supportRouteCount[i] or 0)+1
                    if state.supportRouteCount[i]>7 then
                        state.supportRouteFailed=true
                        
                        break
                    end
                    if not scrollTo(row.button) then return end
                    makeChoice('BLESSING',row.button,'SUPPORT_ROUTE:'..i)
                    return
                end
            end
            if not state.supportRouteFailed then
                state.supportPendingNames=staged
                makeChoice('BLESSING',support.take,'TAKE SUPPORTS')
                return
            end
        end
    end

    -- The game calls this "Blinding", NOT "Binding". The PDF's
    -- screenshot shows Blinding and the live log confirms this exact label.
    -- DEVIL PLAY (n/3) is read each tick; if n increases without a phase
    -- change, the pending action is still confirmed and memorized.
    if (state.curseCount or 0)<3 then
        local curses={'BLINDING','CONFUSION','FATIGUE'}
        local curseScroll=nil
        -- The scroller belongs to the DEVIL PLAY section, not PB's scroller.
        for _,o in ipairs(colo:GetDescendants()) do
            if o:IsA('ScrollingFrame') then
                for _,b in ipairs(o:GetDescendants()) do
                    if b:IsA('TextButton') and ownLabel(b):find('CONFUSION ',1,true)==1 then
                        curseScroll=o;break
                    end
                end
                if curseScroll then break end
            end
        end
        if curseScroll then
            for _,name in ipairs(curses) do
                if not state.devilChosen[name] and not state.curseUnavailable[name]
                    and not tried['DEVIL:'..name] then
                    local candidate=nil
                    for _,b in ipairs(curseScroll:GetDescendants()) do
                        if b:IsA('GuiButton') and ownLabel(b):find(name..' ',1,true)==1 then
                            candidate=b;break
                        end
                    end
                    if candidate then
                        if not scrollTo(candidate) then return end
                        if validButton(candidate) then
                            makeChoice('BLESSING',candidate,'DEVIL:'..name)
                            return
                        end
                    else
                        state.curseUnavailable[name]=true
                    end
                end
            end
        end
    end

    -- Give only these two Sacred effects to the carry. If both are already
    -- bound, go to World stats. Never bind a fallback to a random support.
    if not tried['SACRED:BIND'] then
        if os.clock()<state.sacredAt then return end
        local bind,effects,targets=getSacredButtons(colo)
        if bind and #effects>0 and #targets>0 and state.carryName then
            if not state.sacredPlan then
                for _,needle in ipairs({'STATUS IMMUNITY','FIRST-HIT DODGE'}) do
                    if not state.sacredChosen[needle] and not state.sacredUnavailable[needle] then
                        for _,e in ipairs(effects) do
                            if e.text:find(needle,1,true)==1 then
                                state.sacredPlan={effect=needle,effectBtn=e.button}
                                state.sacredStep=1
                                break
                            end
                        end
                    end
                    if state.sacredPlan then break end
                end
            end
            local plan=state.sacredPlan
            if plan then
                local targetBtn=nil
                for _,t in ipairs(targets) do
                    if t.text==state.carryName then targetBtn=t.button break end
                end
                if targetBtn then
                    if state.sacredStep==1 then
                        makeChoice('BLESSING',plan.effectBtn,'SACRED:STEP:EFFECT')
                    elseif state.sacredStep==2 then
                        makeChoice('BLESSING',targetBtn,'SACRED:STEP:TARGET')
                    else
                        makeChoice('BLESSING',bind,'SACRED:BIND:'..plan.effect)
                    end
                    return
                else
                    
                end
            end
        end
        tried['SACRED:BIND']=true
    end

    -- Stats only after PB and preferred curses/sacred are not applicable.
    -- HP-heavy carry follows the guide's percentage-based healing advice.
    local hp,dmg=state.carryHp,state.carryDmg
    local preferHp=(not hp or not dmg or dmg>=hp) or state.carryName=='DEATHLESS OUTLAW'
        or state.carryName=='GHOUL HUNGER' or state.carryName=='DEMON VENERABLE'
    local opts=preferHp
        and {{'+15% MAX HP','WORLD:+15% MAX HP'},{'+20% DMG','WORLD:+20% DMG'},
             {'+10% DAMAGE REDUCTION','WORLD:+10% DAMAGE REDUCTION'},
             {'+25% CRIT DMG','WORLD:+25% CRIT DMG'}}
        or {{'+20% DMG','WORLD:+20% DMG'},{'+15% MAX HP','WORLD:+15% MAX HP'},
             {'+10% DAMAGE REDUCTION','WORLD:+10% DAMAGE REDUCTION'},
             {'+25% CRIT DMG','WORLD:+25% CRIT DMG'}}
    for _,v in ipairs(opts) do
        if not tried[v[2]] then
            local btn=findExact(all,v[1])
            if btn then makeChoice('BLESSING',btn,v[2]); return end
            tried[v[2]]=true
        end
    end
    -- No safe choice. Never go back to PB once the carry is full.
    coloPause('Blessing: no safe choice')
    
end
local function actionForDice(colo)
    local dice=state.dice
    if not dice then
        dice={mode=nil,triedModes={},triedTargets={},awaitingTarget=false,nextAt=0}
        state.dice=dice
    end
    if os.clock()<(dice.nextAt or 0) then return end
    local all=buttons(colo)
    local offers=getDiceOffers(colo)
    local named={
        ['REVIVE']=findExact(all,'REVIVE'),
        ['HEAL 25%']=findExact(all,'HEAL 25%'),
        ['+10% STATS']=findExact(all,'+10% STATS'),
        ['KEEP MY TEAM']=findExact(all,'KEEP MY TEAM'),
    }
    if #offers==0 and not named.REVIVE and not named['HEAL 25%']
        and not named['+10% STATS'] and not named['KEEP MY TEAM'] then
        
        return
    end
    local info=getTallCards(colo)
    local targets={}
    for _,card in ipairs(info) do
        if card.sizeY>=420 then table.insert(targets,card) end
    end
    if #targets~=4 then targets={} end
    local carryCard
    for _,card in ipairs(targets) do
        if state.carryName and card.name==state.carryName then carryCard=card;break end
    end
    if not carryCard and state.carrySlot and #targets==4 then
        carryCard=targets[state.carrySlot]
    end
    local carryFallen=carryCard and carryCard.fallen
    local deadSupport
    for _,card in ipairs(targets) do
        if card.fallen and (not carryCard or card.slot~=carryCard.slot) then
            deadSupport=card
            break
        end
    end
    if not dice.mode then
        -- Guide p3 + p8: revive fallen carry, otherwise +10% Stats to carry.
        if carryFallen and named.REVIVE and not dice.triedModes.REVIVE then
            dice.mode='REVIVE'
        elseif named['+10% STATS'] and not dice.triedModes['+10% STATS'] then
            dice.mode='+10% STATS'
        elseif deadSupport and not dice.triedModes['REPLACE CARD'] then
            dice.mode='REPLACE CARD'
        elseif named['HEAL 25%'] and not dice.triedModes['HEAL 25%'] then
            dice.mode='HEAL 25%'
        elseif named['KEEP MY TEAM'] and not dice.triedModes['KEEP MY TEAM'] then
            dice.mode='KEEP MY TEAM'
        else
            coloPause('Dice: no reward mode available')
            return
        end
        dice.awaitingTarget=dice.mode=='REPLACE CARD'
        dice.triedTargets={}
        
    end
    if dice.awaitingTarget then
        if #targets~=4 then return end
        local target
        if dice.mode=='REPLACE CARD' then
            if deadSupport and not dice.triedTargets[deadSupport.button] then
                target=deadSupport
            else
                for _,card in ipairs(targets) do
                    if not dice.triedTargets[card.button] and (not carryCard or card.slot~=carryCard.slot) then
                        target=card break
                    end
                end
            end
        else
            target=carryCard
            if not target and not state.carryName then
                -- Fallback for manually-started run without a tracked PDF carry:
                for _,card in ipairs(targets) do
                    if (dice.mode~='REVIVE' or card.fallen) and
                        (dice.mode=='REVIVE' or not card.fallen) then
                        target=card break
                    end
                end
            end
        end
        if not target then
            if state.carryName then
                coloPause('Dice: cannot find carry target '..tostring(state.carryName))
                
            else
                dice.triedModes[dice.mode]=true
                dice.mode=nil;dice.awaitingTarget=false
                dice.nextAt=os.clock()+.4
            end
            return
        end
        makeChoice('DICE CHOICE',target.button,'DICE TARGET: '..dice.mode)
        return
    end
    local btn=named[dice.mode]
    if not btn then
        dice.triedModes[dice.mode]=true
        dice.mode=nil
        dice.nextAt=os.clock()+.4
        return
    end
    makeChoice('DICE CHOICE',btn,'DICE MODE: '..dice.mode)
end
local function actionForDraft(colo,start)
    local rows=findDraftRows(colo)
    if not rows then
        
        return
    end
    local bestCarry=nil
    for r=1,4 do
        for c=1,4 do
            local b=rows[r][c]
            local name=cleanCardName(ownLabel(b))
            local score=cardScore(name)
            if score>0 and (not bestCarry or score>bestCarry.score) then
                bestCarry={row=r,col=c,name=name,score=score}
            end
        end
    end
    if not bestCarry and not state.draftRerollDisabled
        and state.draftRerolls<cfg.maxDraftRerolls then
        local reroll=findPattern(buttons(colo),'^REROLL ALL %([1-9]%d*%)$')
        if reroll then
            makeChoice('DRAFT',reroll,'DRAFT:REROLL',rows)
            return
        end
        state.draftRerollDisabled=true
    end
    if not state.carryName then
        if bestCarry then
            state.carryName=bestCarry.name
            state.carrySlot=bestCarry.row
            state.noCarry=false
            
        else
            -- Only auto-cashout a no-carry run when PDF restart and rerun
            -- are enabled; never override user stop-floor in an ordinary run.
            state.noCarry=cfg.restartUntilCarry and cfg.autoRerun
            
        end
    end
    for row=1,4 do
        if not state.draftDone[row] then
            if not state.picked[row] or not validButton(state.picked[row]) then
                local chosen,score
                if bestCarry and row==bestCarry.row then
                    chosen=rows[row][bestCarry.col]
                else
                    score=-1
                    for col,b in ipairs(rows[row]) do
                        local name=cleanCardName(ownLabel(b))
                        local value=sideScore(name)
                        if value==0 then value=cardScore(name)*.45 end
                        if value>score then chosen=b;score=value end
                    end
                end
                state.picked[row]=chosen
                state.teamNames[row]=cleanCardName(ownLabel(chosen))
            end
            makeChoice('DRAFT',state.picked[row],'row'..row,rows)
            return
        end
    end
    makeChoice('DRAFT',start,'START THE RUN',rows)
end
local cachedColoPrompt=nil
local cachedPromptUntil=0
local function findPrompt()
    if cachedColoPrompt and cachedColoPrompt.Parent and cachedColoPrompt.Enabled then
        return cachedColoPrompt
    end
    local now=os.clock()
    if now<cachedPromptUntil then return nil end
    cachedPromptUntil=now+0.6
    local p=Workspace:FindFirstChild('ColosseumPrompt',true)
        or Workspace:FindFirstChild('ColosseumTeleportPrompt',true)
    if p and p:IsA('ProximityPrompt') then cachedColoPrompt=p;return p end
    cachedColoPrompt=nil
    return nil
end
local function tryOpenNpc()
    if not cfg.autoApproachNPC or os.clock()-state.lastPrompt<0.8 then return end
    local now=os.clock()
    -- Required order: request world teleport, wait for it to settle,
    -- confirm the Colosseum NPC is reasonably near, THEN start walking.
    if state.transportStage=='idle' then
        local remote=ReplicatedStorage:FindFirstChild('WorldsTeleportRequest')
        if not (remote and remote:IsA('RemoteEvent')) then
            state.transportStatus='Teleport remote missing; staying put'
            state.lastPrompt=now
            return
        end
        local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
        state.transportOrigin=root and root.Position or nil
        local ok=pcall(function() remote:FireServer('Colosseum') end)
        state.lastPrompt=now
        if not ok then
            state.transportStatus='Teleport failed; waiting before retry'
            return
        end
        state.transportStage='waiting'
        state.transportAt=now
        state.transportAttempts=state.transportAttempts+1
        state.transportStatus='Teleport requested; awaiting arrival'
        return
    end
    if state.transportStage=='waiting' then
        if now-state.transportAt<1.8 then return end
        local prompt=findPrompt()
        local char=player.Character
        local root=char and char:FindFirstChild('HumanoidRootPart')
        local par=prompt and prompt.Parent
        local pos=par and (par:IsA('Attachment') and par.WorldPosition
            or (par:IsA('BasePart') and par.Position))
        if prompt and not pos then
            local part=prompt:FindFirstAncestorWhichIsA('BasePart')
            pos=part and part.Position
        end
        local distance=(root and pos) and (pos-root.Position).Magnitude or math.huge
        local moved=(root and state.transportOrigin)
            and (root.Position-state.transportOrigin).Magnitude>15
        if distance<140 and (moved or now-state.transportAt>2.7) then
            state.transportStage='arrived'
            state.transportStatus='At Colosseum; approaching NPC'
        elseif now-state.transportAt>10 then
            if state.transportAttempts<3 then
                state.transportStage='idle'
                state.transportStatus='Teleport not confirmed; retrying'
            else
                state.transportStatus='Teleport not confirmed; AUTO paused'
                coloPause('Teleport to Colosseum not confirmed in 3 attempts')
            end
        end
        return
    end
    if state.transportStage~='arrived' then return end
    if now-state.lastPrompt<1.8 then return end
    state.lastPrompt=now
    local prompt=findPrompt()
    if not prompt or not prompt.Enabled then return end
    local char=player.Character
    local root=char and char:FindFirstChild('HumanoidRootPart')
    local hum=char and char:FindFirstChildOfClass('Humanoid')
    local par=prompt.Parent
    local pos=par:IsA('Attachment') and par.WorldPosition
        or (par:IsA('BasePart') and par.Position)
    if not pos then
        local part=prompt:FindFirstAncestorWhichIsA('BasePart')
        pos=part and part.Position
    end
    if not (root and hum and pos) then return end
    local distance=(pos-root.Position).Magnitude
    if distance>math.max(3,prompt.MaxActivationDistance-1) then
        if distance<180 then hum:MoveTo(pos) end
    elseif type(fireproximityprompt)=='function' then
        pcall(function() fireproximityprompt(prompt) end)
    else
        -- Executor without fireproximityprompt: use the prompt's real keyboard key.
        task.spawn(function()
            local key=prompt.KeyboardKeyCode
            if key==Enum.KeyCode.Unknown then key=Enum.KeyCode.E end
            pcall(function()
                VIM:SendKeyEvent(true,key,false,game)
                task.wait(math.max(0.1,prompt.HoldDuration+0.09))
                VIM:SendKeyEvent(false,key,false,game)
            end)
        end)
    end
end
local function getCurrentMode(colo,mode)
    for _,v in ipairs(buttons(colo)) do
        if v.text:find(mode..': ON',1,true)==1 then return true,v.obj end
        if v.text:find(mode..': OFF',1,true)==1 then return false,v.obj end
    end
    return nil,nil
end
local function setupMode(colo)
    local currentHell,hellButton=getCurrentMode(colo,'HELL')
    if currentHell==nil or not hellButton then
        
        return
    end
    if currentHell~=cfg.wantHell then
        makeChoice('ENTER',hellButton,'MODE:HELL:'..(cfg.wantHell and 'ON' or 'OFF'))
        return
    end
    local currentEndless,endlessButton=getCurrentMode(colo,'ENDLESS')
    if currentEndless==nil or not endlessButton then
        
        return
    end
    if currentEndless~=cfg.wantEndless then
        makeChoice('ENTER',endlessButton,'MODE:ENDLESS:'..(cfg.wantEndless and 'ON' or 'OFF'))
        return
    end
    local enter=findExact(buttons(colo),'ENTER THE COLOSSEUM')
    if enter then makeChoice('ENTER',enter,'ENTER THE COLOSSEUM') end
end

-- CASH OUT becomes available on the NEXT fight preparation screen, after
-- the target wave has finished. E.g. FIGHT WAVE 36 means floors 1..35 cleared.
-- The log shows a real button reading 'Cash out (end run, keep banked rewards)'.
local function maybeCashOut(colo,phase,button)
    if phase~='FIGHT WAVE' and phase~='FIGHT CHAMPION' then return false end
    -- PDF p2: if all rerolls exhausted and no listed carry, cash out at wave 1,
    -- then automatically start a fresh run. Not an early exit for good teams.
    if state.noCarry and cfg.restartUntilCarry and cfg.autoRerun then
        local exit=findPattern(buttons(colo),'^CASH OUT %(')
        if exit then
            
            makeChoice(phase,exit,'PDF:NO_CARRY_CASHOUT')
        else
            coloPause('No-carry cashout button missing')
        end
        return true
    end
    if not (cfg.wantEndless and state.stopFloor) then return false end
    local nextWave=nil
    if phase=='FIGHT WAVE' and button then
        nextWave=tonumber(ownLabel(button):match('^FIGHT WAVE (%d+)$'))
    elseif phase=='FIGHT CHAMPION' then
        -- In Endless, champions occur at 14, 19, 24, 29, ...
        -- The last ordinary FIGHT WAVE number is authoritative.
        if state.lastSeenWave>0 then nextWave=state.lastSeenWave+1 end
    end
    if not nextWave then return false end
    state.lastSeenWave=math.max(state.lastSeenWave,nextWave)
    local cleared=nextWave-1
    if cleared < state.stopFloor then return false end
    local cash=findPattern(buttons(colo),'^CASH OUT %(')
    if cash then
        
        makeChoice(phase,cash,'CASHOUT:'..state.stopFloor)
    else
        -- Missing button: never accidentally start a wave past the chosen stop.
        coloPause('Cashout button missing at floor '..tostring(state.stopFloor))
        
    end
    return true
end



-- Restore the interrupted Colo run without clearing its draft, blessings,
-- carry, picked cards, pending acknowledgements or target floor.
local function handleColoHandoff(current)
    if handoff.requested and not handoff.active and not handoff.returning then
        -- Rift may take control only AFTER Continue / post-battle choices have
        -- been processed. In V10.5, taking ownership on 'CONTINUE' or the
        -- short CLOSED transition froze the visible Continue button.
        -- Do not interrupt live fights, Draft, Blessing or Dice, or an ACK.
        if state.pending then return false end
        local safe=(current=='FIGHT WAVE' or current=='FIGHT CHAMPION'
            or current=='ENTER'
            or (current=='CLOSED' and state.runCount==0))
        if not safe then return false end
        handoff.active=true
        handoff.requested=false
        handoff.startedAt=os.clock()
        handoff.fromPhase=current
        handoff.fromRun=state.runCount
        handoff.fromWave=state.lastSeenWave
        handoff.requireResume=(current~='CLOSED' and current~='ENTER')
        state.transportStatus='Rift priority; Colosseum run held at next-wave menu'
        return true
    end
    if handoff.active then return true end
    if not handoff.returning then return false end
    local now=os.clock()
    if not handoff.returnTeleportSent then
        local remote=ReplicatedStorage:FindFirstChild('WorldsTeleportRequest')
        if not (remote and remote:IsA('RemoteEvent')) then
            coloPause('Cannot return to Colosseum: WorldsTeleportRequest missing')
            return true
        end
        local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
        state.transportOrigin=root and root.Position or nil
        local ok=pcall(function() remote:FireServer('Colosseum') end)
        if not ok then
            coloPause('Return teleport to Colosseum rejected')
            return true
        end
        handoff.returnTeleportSent=true
        handoff.returnAt=now
        state.transportStage='waiting'
        state.transportAt=now
        state.transportAttempts=1
        state.transportStatus='Returning to Colosseum area'
        return true
    end
    if state.transportStage~='arrived' then
        -- Existing Colosseum teleport confirmation/retry logic, reused.
        tryOpenNpc()
        return true
    end
    local colo=playerGui:FindFirstChild('ColosseumGui')
    local battle=playerGui:FindFirstChild('BattleGui2')
    local phase=getPhase(colo,battle)
    if phase=='CLOSED' then
        if now-handoff.returnAt>55 then
            coloPause('Colosseum menu not reopened after Rift; old run state still held')
        else
            tryOpenNpc()
        end
        return true
    end
    if handoff.requireResume then
        -- ENTER is the 'new run' screen. If the game forgot the existing run,
        -- do NOT enter and wipe the run that the user wanted to keep.
        if phase=='ENTER' or (phase=='DRAFT' and handoff.fromPhase~='DRAFT') then
            if now-handoff.returnAt>13 then
                coloPause('Old Colosseum run not restored after Rift; refusing to create a new run')
            end
            return true
        end
    end
    handoff.returning=false
    handoff.returnTeleportSent=false
    state.transportStatus='Colosseum previous run resumed'
    state.delayUntil=now+0.25
    return false
end

task.spawn(function()
    while state.alive do
        if state.enabled and not state.blocked then
            local ok,err=pcall(function()
                if (handoff.active or handoff.returning) and handleColoHandoff(nil) then return end
                local colo=playerGui:FindFirstChild('ColosseumGui')
                local battle=playerGui:FindFirstChild('BattleGui2')
                local phase,button=getPhase(colo,battle)
                if state.stopFloor==nil and state.runCount==0 and phase~='ENTER' and phase~='CLOSED' then
                    state.stopFloor=chooseStopFloor()
                end
                if phase~=state.phase then
                    local prior=state.phase
                    state.phase=phase
                    state.picked={}
                    state.badSupport=false
                    state.blessingTried={}
                    state.sacredStep=nil
                    state.sacredPlan=nil
                    state.sacredAt=0
                    state.supportRouteCount={}
                    state.supportRouteFailed=false
                    if phase=='DICE CHOICE' and prior~='DICE CHOICE' then
                        state.dice={mode=nil,triedModes={},triedTargets={},awaitingTarget=false,nextAt=0}
                    elseif phase~='DICE CHOICE' then
                        state.dice=nil
                    end
                    if phase=='DRAFT' and prior~='DRAFT' then
                        state.draftDone={}
                        state.carryName=nil; state.carrySlot=nil; state.teamNames={}
                        state.carryHp=nil;state.carryDmg=nil
                        state.carryImmunity=false;state.carryDodge=false;state.devilChosen={}
                        state.supportOwned={};state.supportCount=0;state.supportPendingNames=nil
                        state.curseCount=0;state.curseUnavailable={};state.sacredChosen={};state.sacredUnavailable={}
                        state.draftRerolls=0;state.draftRerollDisabled=false
                        state.noCarry=false;state.noCarryCashout=false
                        state.runCount=state.runCount+1
                        state.stopFloor=chooseStopFloor()
                        state.lastSeenWave=0
                    end
                    if phase=='ENTER' and prior~='ENTER' then
                        state.lastSeenWave=0
                        state.transportStage='arrived'
                        state.transportStatus='Colosseum menu opened'
                    end
                    
                end
                if state.pending then
                    resolvePending(colo,phase)
                    return
                end
                if os.clock()<state.delayUntil then return end
                if phase=='FIGHT WAVE' or phase=='FIGHT CHAMPION' then
                    inspectCarryInTeam(colo)
                end
                if (phase=='FIGHT WAVE' or phase=='FIGHT CHAMPION')
                    and maybeCashOut(colo,phase,button) then return end
                if handoff.requested and handleColoHandoff(phase) then return end
                if phase=='BATTLE' then
                    
                elseif phase=='DRAFT' then
                    actionForDraft(colo,button)
                elseif phase=='BLESSING' then
                    actionForBlessing(colo)
                elseif phase=='DICE CHOICE' then
                    actionForDice(colo)
                elseif phase=='ENTER' then
                    if cfg.autoRerun or state.runCount==0 then setupMode(colo) end
                elseif phase=='FIGHT WAVE' or phase=='FIGHT CHAMPION' or phase=='FACE CHAMPION'
                    or phase=='CONTINUE' or phase=='ROLL DIE' or phase=='SEE RESULTS'
                    or phase=='BACK GATES' then
                    makeChoice(phase,button,phase)
                elseif phase=='CLOSED' then
                    if cfg.autoRerun or state.runCount==0 then tryOpenNpc() end
                else
                    -- Unknown view: never guess button clicks.
                    
                end
            end)
            if not ok then
                coloPause('Lua error: '..tostring(err))
            end
        end
        -- Fixed V10.4 0.25s action cadence, unaffected by Rift polling/UI.
        -- A longer sleep is allowed ONLY while Colo is fully suspended/OFF.
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
