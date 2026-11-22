-- anime duel script
-- WindUI 1.6.66 frontend with the existing Anime Duel controllers.
-- Uses captured DraftAction calls. Auto starts only when enabled in an auto-loaded profile.
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local UIS = game:GetService('UserInputService')
local Workspace = game:GetService('Workspace')
local HttpService = game:GetService('HttpService')
local GuiService = game:GetService('GuiService')
local TeleportService = game:GetService('TeleportService')
local player = Players.LocalPlayer
while not player do task.wait(.1);player=Players.LocalPlayer end
local playerGui = player:WaitForChild('PlayerGui')
local env = getgenv and getgenv() or _G
local previous = env.AnimeDuelScript
if type(previous) == 'table' and type(previous.destroy) == 'function' then
    if previous.worker or (previous.climb and previous.climb.worker) or (previous.story and previous.story.worker) or (previous.dungeon and previous.dungeon.worker) then
        previous.stop()
        local deadline=os.clock()+10
        while previous.worker or (previous.climb and previous.climb.worker) or (previous.story and previous.story.worker) or (previous.dungeon and previous.dungeon.worker) do
            if os.clock()>=deadline then
                previous.status='Old request is still pending; wait for it to finish before upgrading.'
                return
            end
            task.wait(.1)
        end
    end
    previous.destroy()
end
if type(env.CustomAutoDraft) == 'table' and env.CustomAutoDraft.running then
    env.CustomAutoDraft.stop()
    env.CustomAutoDraft.status='Old auto is stopping; run the UI script again when stopped.'
    return
end
local remotes = RS:WaitForChild('Remotes', 15)
assert(remotes, 'Remotes not found')
local action = remotes:WaitForChild('DraftAction', 15)
local event = remotes:WaitForChild('DraftEvent', 15)
assert(action and event, 'DraftAction/DraftEvent not found')
local app = {build='windui-1.6.66-preview',alive=true, enabled=false, worker=false, bosses={}, connections={}, snapshot=nil,
    version=0, resultVersion=0, wins=0, losses=0, clears=0,
    status='Ready — press START', recovery={}, stage=nil, runId=nil,
    config={farm=3, bossFarm=4, delay=.8, timeout=180, theme='Midnight', transparency=15, autoExecuteOnHop=true,antiAfk=true,autoReconnect=true, autoStart=false,savedModeSelection=false,draftEnabled=false,climbEnabled=false,storyEnabled=false,dungeonEnabled=false,pauseForRift=true,sequenceBossDungeon=true,mode='draft', dungeonWalk=false,dungeonDifficulty='Normal',dungeonPath='Balanced',dungeonCashOut=20,dungeonTeam='blonde_commander_rainbow,blue_duo_gold,first_emperor_gold,rose_evil_roku_gold',dungeonReserves='barrier_pirate_rainbow,blue_roku_gold', storyDifficulty='Nightmare', storyInterval=1.5, windowW=805,windowH=565,windowX=.5,windowY=.5, story_purple_forest=false, story_android_games=false, story_hollow_world=false, story_purple_town=false, story_toy_kingdom=true}}
app.climb={enabled=false,worker=false,status='Ready — press START CLIMB'}
app.dungeon={enabled=false,worker=false,status='Ready — press START DUNGEON',version=0,history={},historySeen={}}
app.story={enabled=false,worker=false,status='Ready — press START BOSS',requests=0,cooldowns={},nextAttemptAt=0}
local storyBosses={
    {key='purple_forest',id='purple_forest_boss',name='Water Master',secret=false},
    {key='android_games',id='android_games_boss',name='Perfect Android',secret=false},
    {key='hollow_world',id='hollow_world_boss',name='Moonquoira',secret=false},
    {key='purple_town',id='purple_town_boss',name='Killer Bomb',secret=false},
    {key='toy_kingdom',id='toy_kingdom_boss',name='String Man',secret=false},
    {key='toy_kingdom_secret',id='toy_kingdom_secret',name='Ruffy 4',secret=true},
    {key='clover_capital',id='clover_capital_boss',name='Body Devil',secret=false},
    {key='clover_capital_secret',id='clover_capital_secret',name='Time Sage King',secret=true},
}
-- Read the current game's boss flags; World 6 has five stages, not four.
local function currentStoryCatalog()
    local ok,catalog=pcall(function()
        local shared=RS:FindFirstChild('Shared')
        local module=shared and shared:FindFirstChild('StoryConfig',true)
        if not module then return nil end
        return require(module)
    end)
    if not ok or type(catalog)~='table' or type(catalog.Maps)~='table' then return end
    local list,seen={},{}
    local function add(stage,map)
        if type(stage)~='table' or (stage.Boss~=true and stage.Secret~=true)
            or type(stage.Id)~='string' or seen[stage.Id] then return end
        seen[stage.Id]=true
        table.insert(list,{key=stage.Id:gsub('_boss$',''),id=stage.Id,
            name=stage.Npc or stage.Id,secret=stage.Secret==true,map=map.Name or map.Id})
    end
    for _,map in ipairs(catalog.Maps) do
        if type(map)=='table' then
            for _,stage in ipairs(map.Stages or {}) do add(stage,map) end
            add(map.Secret,map)
        end
    end
    if #list>0 then storyBosses=list end
end
currentStoryCatalog()
for _,boss in ipairs(storyBosses) do
    if app.config['story_'..boss.key]==nil then app.config['story_'..boss.key]=false end
end
local storyDifficulties={'Easy','Medium','Hard','Nightmare'}
local workerContexts=setmetatable({}, {__mode='k'})
local function controller() return workerContexts[coroutine.running()] or app end
env.AnimeDuelScript = app
local render = function() end
local function redraw()
    local ok,err=pcall(render)
    if not ok then app.uiError=tostring(err) else app.uiError=nil end
end
local function track(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(app.connections, connection)
    return connection
end
app.afk={status='Ready — checks every 60s and on idle',lastInput=-math.huge,sent=0}
local function antiAfkPulse()
    if not app.alive or not app.config.antiAfk or os.clock()-app.afk.lastInput<60 then return end
    app.afk.lastInput=os.clock()
    local camera=Workspace.CurrentCamera
    local cameraFrame=camera and camera.CFrame
    local backend
    local ok=pcall(function()
        local virtual=game:GetService('VirtualUser')
        virtual:CaptureController()
        if type(virtual.Button2Down)=='function' and type(virtual.Button2Up)=='function' and cameraFrame then
            virtual:Button2Down(Vector2.new(0,0),cameraFrame)
            local release=function()virtual:Button2Up(Vector2.new(0,0),cameraFrame)end
            app.afk.release=release
            task.delay(.05,function()
                if app.afk.release==release then pcall(release);app.afk.release=nil end
            end)
            backend='VirtualUser press/release'
        else
            virtual:ClickButton2(Vector2.new(0,0),cameraFrame)
            backend='VirtualUser click'
        end
    end)
    if not ok then
        ok=pcall(function()
            local virtual=game:GetService('VirtualInputManager')
            virtual:SendMouseButtonEvent(0,0,1,true,game,0)
            local release=function()virtual:SendMouseButtonEvent(0,0,1,false,game,0)end
            app.afk.release=release
            task.delay(.05,function()
                if app.afk.release==release then pcall(release);app.afk.release=nil end
            end)
            backend='VirtualInputManager'
        end)
    end
    if ok then
        app.afk.sent=app.afk.sent+1
        app.afk.status='Input sent #'..app.afk.sent..' / '..backend
    else app.afk.status='Input unavailable — executor blocked both Anti-AFK methods' end
    redraw()
end
if player.Idled then track(player.Idled,antiAfkPulse) end
local function antiAfkTick()
    if not app.alive then return end
    antiAfkPulse()
    task.delay(60,antiAfkTick)
end
task.delay(60,antiAfkTick)
app.hop={queued=false,status='Ready'}
if player.OnTeleport then
    track(player.OnTeleport,function(state)
        if not app.alive or not app.config.autoExecuteOnHop then return end
        if state==Enum.TeleportState.Failed then app.hop.queued=false;app.hop.status='Teleport failed';redraw();return end
        if state~=Enum.TeleportState.Started and state~=Enum.TeleportState.InProgress then return end
        if app.hop.queued then return end
        local queue=queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
        if type(queue)~='function' then app.hop.status='Executor has no queue_on_teleport';redraw();return end
        local payload="if not game:IsLoaded() then game.Loaded:Wait() end; loadstring(game:HttpGet('https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/main/anime_duel_windui.lua?v='..os.time()))()"
        local ok=pcall(queue,payload)
        app.hop.queued=ok;app.hop.status=ok and 'Queued for next server' or 'Executor rejected teleport queue'
        redraw()
    end)
end
local function setStatus(message)
    local ctx=controller()
    message=tostring(message)
    if ctx.status==message then return end
    ctx.status=message
    if ctx==app.climb then app.climbStatus=ctx.status end
    redraw()
end
-- Named profiles use only executor-local JSON files.
local storage='AnimeDuelScript/'..tostring(player.UserId or 'Local')
local profileDir=storage..'/profiles'
local disk=type(readfile)=='function' and type(writefile)=='function'
app.profiles={current='Default',auto=nil,names={},status=disk and 'Storage ready' or 'File API unavailable'}
app.reconnect={attempts=0,lastTry=-math.huge,status='Monitoring',limit=3,interval=9}
local ranges={dungeonCashOut={5,20,true},windowW={600,1200},windowH={420,1000},windowX={0,1},windowY={0,1},farm={1,20,true},bossFarm={1,20,true},delay={.5,5},timeout={30,600},transparency={0,65}}
local themesAllowed={Midnight=true,Emerald=true,Violet=true,Light=true,Ocean=true,Rose=true}
local function profileId(name)
    if type(name)~='string' then return nil end
    name=name:match('^%s*(.-)%s*$')
    return #name>=1 and #name<=32 and name:match('^[%w_%-]+$') and name or nil
end
local function storageStatus(message)
    app.profiles.status=message;redraw()
end
local function ensureDirs()
    if type(makefolder)~='function' then return end
    for _,path in ipairs({'AnimeDuelScript',storage,profileDir}) do pcall(makefolder,path) end
end
local function readJson(path)
    if not disk then return nil end
    local ok,data=pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    return ok and type(data)=='table' and data or nil
end
local function writeJson(path,data)
    if not disk then return false end
    ensureDirs()
    return pcall(function() writefile(path,HttpService:JSONEncode(data)) end)
end
local function profilePath(name) return profileDir..'/'..name..'.json' end
local function addName(name)
    if not table.find(app.profiles.names,name) then table.insert(app.profiles.names,name);table.sort(app.profiles.names) end
end
local function configSnapshot()
    local out={}
    for key,value in pairs(app.config) do out[key]=value end
    out.savedModeSelection=true
    if app.config.autoStart and not app.config.savedModeSelection then out[app.config.mode..'Enabled']=true end
    return out
end
function app.saveProfile(name)
    name=profileId(name)
    if not name then storageStatus('Invalid profile name');return false end
    if not writeJson(profilePath(name),{version=1,config=configSnapshot()}) then
        storageStatus(disk and 'Save failed' or 'File API unavailable');return false
    end
    app.profiles.current=name;addName(name)
    local indexed=writeJson(storage..'/index.json',app.profiles.names)
    storageStatus(indexed and ('Saved: '..name) or ('Saved '..name..'; profile index failed'))
    return true
end
function app.loadProfile(name)
    if app.worker or app.climb.worker or app.story.worker or app.dungeon.worker then storageStatus('Stop active modes before loading a profile');return false end
    name=profileId(name)
    local data=name and readJson(profilePath(name))
    if not data or data.version~=1 or type(data.config)~='table' then
        storageStatus('Profile unavailable or invalid');return false
    end
    local incoming=data.config
    if table.find({'Normal','Hard','Nightmare'},incoming.dungeonDifficulty) then app.config.dungeonDifficulty=incoming.dungeonDifficulty end
    if table.find({'Balanced','Loot','Safe'},incoming.dungeonPath) then app.config.dungeonPath=incoming.dungeonPath end
    for _,key in ipairs({'dungeonTeam','dungeonReserves'}) do if type(incoming[key])=='string' then app.config[key]=incoming[key] end end
    app.config.storyInterval=1.5 -- Migrate profiles saved with the old 5-second interval.
    for key,range in pairs(ranges) do
        local v=incoming[key]
        if type(v)=='number' and v==v and v>=range[1] and v<=range[2] then
            app.config[key]=range[3] and math.floor(v) or v
        end
    end
    if incoming.mode=='draft' or incoming.mode=='climb' or incoming.mode=='story' or incoming.mode=='dungeon' then app.config.mode=incoming.mode end
    if table.find(storyDifficulties,incoming.storyDifficulty) then app.config.storyDifficulty=incoming.storyDifficulty end
    for _,boss in ipairs(storyBosses) do
        local key='story_'..boss.key
        if type(incoming[key])=='boolean' then app.config[key]=incoming[key] end
    end
    if themesAllowed[incoming.theme] then app.config.theme=incoming.theme end
    for _,key in ipairs({'autoReconnect','autoStart','antiAfk','autoExecuteOnHop','pauseForRift','sequenceBossDungeon'}) do
        if type(incoming[key])=='boolean' then app.config[key]=incoming[key] end
    end
    local hasModes=false
    for _,mode in ipairs({'draft','climb','story','dungeon'}) do
        local key=mode..'Enabled'
        app.config[key]=incoming[key]==true
        if type(incoming[key])=='boolean' then hasModes=true end
    end
    app.config.savedModeSelection=hasModes
    app.profiles.current=name;addName(name);storageStatus('Loaded: '..name)
    if app.config.autoStart and app.restoreSavedModes then app.restoreSavedModes() end
    return true
end
function app.deleteProfile(name)
    name=profileId(name)
    if not name then storageStatus('Invalid profile name');return false end
    if name==app.profiles.auto then storageStatus('Clear Auto Load before deleting this profile');return false end
    if type(delfile)~='function' then storageStatus('Delete API unavailable');return false end
    local ok=pcall(delfile,profilePath(name))
    if not ok then storageStatus('Delete failed');return false end
    local index=table.find(app.profiles.names,name)
    if index then table.remove(app.profiles.names,index) end
    local indexed=writeJson(storage..'/index.json',app.profiles.names)
    if app.profiles.current==name then app.profiles.current='Default' end
    storageStatus(indexed and ('Deleted: '..name) or ('Deleted '..name..'; profile index failed'))
    return true
end
function app.setAutoProfile(name)
    name=profileId(name)
    if not name then storageStatus('Invalid profile name');return false end
    if not app.saveProfile(name) then return false end
    if not writeJson(storage..'/autoload.json',{profile=name}) then storageStatus('Cannot save Auto Load');return false end
    app.profiles.auto=name;storageStatus('Auto Load: '..name);return true
end
function app.clearAutoProfile()
    if not writeJson(storage..'/autoload.json',{}) then storageStatus('Cannot clear Auto Load');return false end
    app.profiles.auto=nil;storageStatus('Auto Load OFF');return true
end
local index=readJson(storage..'/index.json')
if index then for _,name in ipairs(index) do name=profileId(name);if name then addName(name) end end end
local auto=readJson(storage..'/autoload.json')
local autoName=auto and profileId(auto.profile)
local autoLoaded=false
if autoName then app.profiles.auto=autoName;autoLoaded=app.loadProfile(autoName) end

-- Origin-style connection monitoring. Never treats kicks/moderation as network loss.
local function connectionText()
    local message=''
    pcall(function() message=GuiService:GetErrorMessage() or '' end)
    pcall(function()
        local core=game:GetService('CoreGui')
        local prompts=core:FindFirstChild('RobloxPromptGui')
        local overlay=prompts and prompts:FindFirstChild('promptOverlay')
        local prompt=overlay and overlay:FindFirstChild('ErrorPrompt',true)
        if prompt and prompt.Visible then
            for _,obj in ipairs(prompt:GetDescendants()) do
                if (obj:IsA('TextLabel') or obj:IsA('TextButton')) and obj.Visible then message=message..' '..tostring(obj.Text) end
            end
        end
    end)
    return tostring(message):lower()
end
local function lostConnection(message)
    for _,word in ipairs({'banned','kicked','moderation','error code: 267','error code: 268'}) do
        if message:find(word,1,true) then return false end
    end
    for _,word in ipairs({'disconnected','lost connection','connection lost','connection error','timed out','error code: 277','error code: 279','error code: 266'}) do
        if message:find(word,1,true) then return true end
    end
    return false
end
function app.requestReconnect(force)
    if not app.alive or (not force and not app.config.autoReconnect) then return false end
    local st=app.reconnect
    if st.attempts>=st.limit then st.status='Attempt limit reached';redraw();return false end
    if os.clock()-st.lastTry<st.interval then return false end
    st.attempts=st.attempts+1;st.lastTry=os.clock()
    st.status='Rejoining '..st.attempts..'/'..st.limit
    -- Stop scheduling gameplay; a disconnected session cannot confirm new mutations.
    app.enabled=false;app.climb.enabled=false;app.story.enabled=false;app.dungeon.enabled=false
    app.stopReason='Connection lost — auto reconnect requested'
    app.climb.stopReason=app.stopReason;app.story.stopReason=app.stopReason;app.dungeon.stopReason=app.stopReason
    local ok=pcall(function() TeleportService:Teleport(game.PlaceId,player) end)
    if not ok then st.status='Rejoin unavailable; waiting to retry' end
    redraw();return ok
end
function app.reconnectTick()
    if not app.alive then return end
    if app.config.autoReconnect then
        local message=connectionText()
        if lostConnection(message) then app.requestReconnect(false)
        elseif message=='' then
            app.reconnect.attempts=0;app.reconnect.status='Monitoring'
        else app.reconnect.status='No connection retry for this error' end
    end
    redraw()
end
local function monitorConnection()
    if not app.alive then return end
    app.reconnectTick()
    task.delay(2,monitorConnection)
end

local function accept(value)
    if type(value)=='table' and (type(value.run)=='table'
        or (value.stats~=nil and value.currency~=nil)) then
        app.snapshot=value; app.version=app.version+1
        redraw()
        return true
    end
    return false
end
track(event.OnClientEvent, function(kind, data)
    if kind=='State' then accept(data)
    elseif kind=='Result' and type(data)=='table' then
        app.result=data; app.resultVersion=app.resultVersion+1
        app.resultStateVersion=app.version
    end
end)
local function findRemote(name)
    local ok,value=pcall(function()return remotes:FindFirstChild(name)end)
    return ok and value or nil
end
app.priority={status='Ready',battles={},closed={},closedOrder={},riftRecord=nil,lease=nil,lastPoll=-math.huge}
local riftConfig
local function loadRiftConfig()
    if riftConfig then return riftConfig end
    local ok,value=pcall(function()
        local shared=RS:FindFirstChild('Shared')
        local module=shared and shared:FindFirstChild('RiftConfig',true)
        return module and require(module)
    end)
    if ok and type(value)=='table' and type(value.Status)=='function' then riftConfig=value end
    return riftConfig
end
local function acceptPrioritySnapshot(snapshot)
    if type(snapshot)~='table' then return end
    if type(snapshot.Rifts)=='table' then
        local record=snapshot.Rifts.Visit
        local p=app.priority
        p.riftRecord=record
        if type(record)=='table' then
            local beaten={}
            for id,won in pairs(type(record.Beaten)=='table' and record.Beaten or {}) do if won==true then beaten[#beaten+1]=tostring(id) end end
            table.sort(beaten)
            local signature=tostring(record.Cycle)..'/'..tostring(record.Shift or 0)..'/'..tostring(record.Clear)..'/'..table.concat(beaten,',')
            if p.riftSignature~=signature then p.riftSignature=signature;p.riftProgressAt=os.clock() end
        end
    end
end
local function closePriorityBattle(id)
    if not id then return end
    local p=app.priority
    p.battles[id]=nil
    if not p.closed[id] then
        p.closed[id]=true;p.closedOrder[#p.closedOrder+1]=id
        if #p.closedOrder>128 then p.closed[table.remove(p.closedOrder,1)]=nil end
    end
    if p.lease and p.lease.id==id then p.lease=nil end
end
local battleState=findRemote('BattleState')
local battleEvent=findRemote('BattleEvent')
app.priority.canSequence=battleState~=nil and battleEvent~=nil
if battleState and battleState.OnClientEvent then track(battleState.OnClientEvent,function(data)
    if type(data)~='table' then return end
    local p=app.priority;local lane=tonumber(data.lane) or 1
    local id=type(data.battleId)=='string' and data.battleId or nil
    if data.active==false then
        if id then closePriorityBattle(id)
        else
            local ids={};for key,b in pairs(p.battles) do if b.lane==lane then ids[#ids+1]=key end end
            for _,key in ipairs(ids) do closePriorityBattle(key) end
        end
    elseif data.active==true and id and not p.closed[id] then
        local ids={};for key,b in pairs(p.battles) do if b.lane==lane and key~=id then ids[#ids+1]=key end end
        for _,key in ipairs(ids) do closePriorityBattle(key) end
        local prior=p.battles[id]
        local isRift=data.mode=='rift' or data.source=='rift' or data.rift==true or type(data.rift)=='table' or (prior and prior.rift)
        p.battles[id]={lane=lane,rift=isRift==true}
        if isRift then p.riftProgressAt=os.clock() end
    end
    redraw()
end) end
if battleEvent and battleEvent.OnClientEvent then track(battleEvent.OnClientEvent,function(data)
    if type(data)=='table' and data.type=='BattleEnd' then
        local id=type(data.battleId)=='string' and data.battleId or nil
        if id then closePriorityBattle(id) end
        redraw()
    end
end) end
local function riftPriority()
    if not app.config.pauseForRift then return nil end
    local p=app.priority
    for _,battle in pairs(p.battles) do
        if battle.rift then return 'Paused — native Rift battle is active' end
    end
    local cfg=loadRiftConfig()
    if not cfg then return nil end
    local ok,status=pcall(function()return cfg.Status(Workspace:GetServerTimeNow())end)
    if not ok or type(status)~='table' then return nil end
    if not status.open then p.riftWindow=nil;p.riftWasOpen=false;return nil end
    local window=tostring(status.cycle)..'/'..tostring(status.startedAt)
    if p.riftWindow~=window then
        -- A schedule is only an opportunity to join, never proof of an active Rift.
        p.riftWindow=window
        p.riftEntryUntil=(status.joinable==true or p.riftWasOpen==false) and (os.clock()+12) or os.clock()
    end
    p.riftWasOpen=true
    if os.clock()-p.lastPoll>=5 and not app.requestBusy and app.refreshDungeonCollection then
        p.lastPoll=os.clock();app.refreshDungeonCollection()
    end
    local record=p.riftRecord
    local joined=false
    if type(record)=='table' then
        local valid,value=pcall(function()return cfg.Joined(record,status.cycle)end)
        joined=valid and value==true
    end
    if joined and record.Clear==true then return nil end
    if joined and p.riftProgressAt and os.clock()-p.riftProgressAt<30 then
        return 'Paused — waiting for native Rift progress (idle limit 30s)'
    end
    if os.clock()<(p.riftEntryUntil or 0) then
        return 'Giving native Auto Rift time to join — '..math.ceil(p.riftEntryUntil-os.clock())..'s'
    end
    -- No join or fresh progress: release the autos even if the scheduled window remains open.
    return nil
end

local function readyStoryBoss()
    if not app.story.enabled or os.clock()<app.story.nextAttemptAt then return false end
    for _,boss in ipairs(storyBosses) do
        local difficulty=boss.secret and 'Secret' or app.config.storyDifficulty
        if app.config['story_'..boss.key] and (app.story.cooldowns[boss.id..':'..difficulty] or 0)<=os.clock() then return true end
    end
    return false
end
local function priorityReason()
    local rift=riftPriority()
    if rift then app.priority.status=rift;return rift end
    if app.bosses.world or app.bosses.raid then return 'Paused — waiting for World/Raid boss death' end
    local ctx=controller();local p=app.priority
    if app.config.sequenceBossDungeon and p.canSequence then
        local run=app.dungeon.view and app.dungeon.view.run
        local fighting=run and (run.fighting or (app.dungeon.view and app.dungeon.view.battle))
        if ctx==app.story and (fighting or p.lease or next(p.battles)) then
            p.status='Waiting for the current battle to finish before Story Boss';return p.status
        end
        if ctx==app.dungeon then
            if p.lease or (not fighting and next(p.battles)) then
                p.status='Dungeon paused — waiting for Story/other battle to finish';return p.status
            end
            if not fighting and readyStoryBoss() then p.status='Dungeon yielding to a ready Story Boss';return p.status end
        end
    end
    p.status='Ready — Rift first, then ready Boss, then Dungeon'
    return nil
end

-- Collection data is read from the game's snapshot; Dungeon run cards are never treated as ownership.
app.dungeon.collection={ready=false,status='Loading your collection…',cards={},definitions={},revision=0}
local function loadDungeonDefinitions()
    local c=app.dungeon.collection
    if next(c.definitions) then return true end
    local ok,defs=pcall(function()
        local shared=RS:FindFirstChild('Shared')
        local module=shared and shared:FindFirstChild('CardDefinitions',true)
        return module and require(module)
    end)
    if not ok or type(defs)~='table' then return false end
    c.definitions=defs;return true
end
local function acceptDungeonCollection(snapshot)
    acceptPrioritySnapshot(snapshot)
    if type(snapshot)~='table' then return false end
    local owned=snapshot.Cards or snapshot.cards
    if type(owned)~='table' then return false end
    local c=app.dungeon.collection
    if not loadDungeonDefinitions() then c.status='Card definitions unavailable; refresh when the game has loaded.';redraw();return false end
    local cards={}
    for id,count in pairs(owned) do
        local def=c.definitions[id]
        if type(id)=='string' and type(count)=='number' and count>0 and type(def)=='table' then
            cards[id]={id=id,count=count,name=tostring(def.Name or id),image=tostring(def.Image or ''),
                border=tostring(def.Variant or def.Border or 'Basic'),damage=tonumber(def.Damage) or 0,
                health=tonumber(def.Health) or 0}
        end
    end
    c.cards=cards;c.ready=true;c.revision=c.revision+1
    local count=0;for _ in pairs(cards) do count=count+1 end
    c.status=count..' owned cards · choose 4 team + 2 reserves'
    redraw();return true
end
function app.refreshDungeonCollection()
    local c=app.dungeon.collection
    if c.loading then return end
    local remote=findRemote('GetSnapshot')
    if not remote then c.status='GetSnapshot unavailable; press Refresh once the game loads.';redraw();return end
    c.loading=true;c.status='Loading your collection…';redraw()
    task.spawn(function()
        while app.requestBusy and app.alive do task.wait(.05) end
        if not app.alive then c.loading=false;return end
        app.requestBusy=true
        local ok,snapshot=pcall(function()return remote:InvokeServer()end)
        app.requestBusy=false;c.loading=false
        if not app.alive then return end
        if not ok or not acceptDungeonCollection(snapshot) then
            c.status='Collection not ready; press Refresh to try again.'
        end
        redraw()
    end)
end
local collectionEvent=findRemote('StateChanged')
if collectionEvent and collectionEvent.OnClientEvent then
    track(collectionEvent.OnClientEvent,function(snapshot)acceptDungeonCollection(snapshot)end)
end
function app.getDungeonSlots()
    local slots={}
    for _,key in ipairs({'dungeonTeam','dungeonReserves'}) do
        local count=key=='dungeonTeam' and 4 or 2
        local parts={}
        for part in (tostring(app.config[key])..','):gmatch('(.-),') do parts[#parts+1]=part:match('^%s*(.-)%s*$') end
        for i=1,count do slots[#slots+1]=parts[i] or '' end
    end
    return slots
end
function app.setDungeonSlot(index,id)
    if type(index)~='number' or index%1~=0 or index<1 or index>6 then return false,'Choose a team or reserve slot.' end
    id=id or ''
    local c=app.dungeon.collection
    if id~='' and (not c.ready or not c.cards[id]) then return false,'You do not own this card.' end
    local slots=app.getDungeonSlots()
    for i,selected in ipairs(slots) do if id~='' and selected==id and i~=index then return false,'This card is already in another slot.' end end
    slots[index]=id
    app.config.dungeonTeam=table.concat(slots,',',1,4)
    app.config.dungeonReserves=table.concat(slots,',',5,6)
    redraw();return true
end
function app.listDungeonCards(query,border,sort)
    local list={};query=tostring(query or ''):lower()
    for _,card in pairs(app.dungeon.collection.cards) do
        if (not border or border=='All' or card.border==border)
            and (query=='' or card.name:lower():find(query,1,true) or card.id:lower():find(query,1,true)) then
            list[#list+1]=card
        end
    end
    table.sort(list,function(a,b)
        if sort=='Name' then if a.name~=b.name then return a.name<b.name end
        elseif sort=='Quantity' then if a.count~=b.count then return a.count>b.count end
        else
            local x,y=a.damage+a.health/2,b.damage+b.health/2
            if x~=y then return x>y end
        end
        return a.id<b.id
    end)
    return list
end

local function acceptDungeon(value)
    if type(value)=='table' and type(value.unlocked)=='table' and value.coins~=nil then
        local d=app.dungeon
        local last=value.last
        if type(last)=='table' and last.run~=nil and not d.historySeen[last.run] then
            d.historySeen[last.run]=true
            local timing=d.timing
            if timing and timing.id==last.run then
                local rewards={}
                if last.coins~=nil then rewards[#rewards+1]=tostring(last.coins)..' Shards' end
                for _,field in ipairs({'items','chests'}) do
                    for id,count in pairs(type(last[field])=='table' and last[field] or {}) do
                        if type(count)=='number' and count>0 then rewards[#rewards+1]=tostring(id)..' x'..count end
                    end
                end
                for _,card in ipairs(type(last.cards)=='table' and last.cards or {}) do
                    rewards[#rewards+1]=type(card)=='table' and tostring(card.name or card.card or '?') or tostring(card)
                end
                if last.seal then rewards[#rewards+1]='Third Battle Seal' end
                table.insert(d.history,1,{run=last.run,difficulty=last.diff or timing.difficulty,
                    reason=last.reason or 'ended',cleared=last.cleared or last.room,
                    seconds=math.max(0,os.clock()-timing.at),
                    rewards=#rewards>0 and table.concat(rewards,' · ') or 'No reward data'})
                if #d.history>10 then table.remove(d.history) end
                d.timing=nil
            end
        end
        if type(value.run)=='table' and (not d.timing or d.timing.id~=value.run.id) then
            d.timing={id=value.run.id,at=os.clock(),difficulty=value.run.diff}
        end
        d.view=value;d.version=d.version+1;redraw();return true
    end
    return false
end
local dungeonEvent=findRemote('DungeonEvent')
if dungeonEvent then
    track(dungeonEvent.OnClientEvent,function(kind,data)
        if kind=='State' then acceptDungeon(data)
        elseif kind=='Result' then app.dungeon.result=data end
    end)
end
local function activeRun()
    local run=app.snapshot and app.snapshot.run
    return type(run)=='table' and not run.over and run or nil
end
local function check()
    if not app.alive or not controller().enabled then error('__STOP__', 0) end
end
local function pause(seconds)
    local untilAt=os.clock()+seconds
    while os.clock()<untilAt do check(); task.wait(.1) end
    check()
end
local function waitFor(predicate, seconds)
    local untilAt=os.clock()+seconds
    repeat
        check()
        if predicate() then return true end
        task.wait(.1)
    until os.clock()>=untilAt
    return false
end
local function loadingRejection(reason)
    return type(reason)=='string'
        and reason:lower():find('your data is still loading',1,true)~=nil
end
-- Only confirmed boss lifecycle signals should call this API.
function app.setBossActive(kind, active)
    if kind~='world' and kind~='raid' then return end
    app.bosses[kind]=active==true
    redraw()
end
local function awaitPriority()
    local waiting=false
    while true do
        check()
        local reason=priorityReason()
        if not reason then break end
        waiting=true;setStatus(reason);task.wait(.1)
    end
    if waiting then setStatus('Priority activity ended — resuming') end
    return waiting
end

local function call(name,a,b,remote)
    check()
    if name~='State' then awaitPriority() end
    -- Only one request in flight, while each controller keeps its own lifecycle.
    while true do
        check()
        if name~='State' then awaitPriority() end
        if not app.requestBusy then break end
        task.wait(.05)
    end
    app.requestBusy=true
    local storyRequest=remote and remote==findRemote('StoryFight') and app.config.sequenceBossDungeon and app.priority.canSequence
    if storyRequest then app.priority.lease={requestedAt=os.clock()} end
    local version=app.version
    local values=table.pack(pcall(function()
        if remote then return remote:InvokeServer(name,a) end
        return action:InvokeServer(name,a,b)
    end))
    app.requestBusy=false
    if not values[1] then
        if storyRequest then app.priority.lease=nil end
        check()
        return {ok=false,uncertain=true,reason=tostring(values[2])}
    end
    local rejected=values[2]==false
    local reason=values[3]
    if type(values[2])=='table' and values[2].ok==false then
        rejected=true;reason=values[2].reason or values[2].message
    end
    if rejected then
        if storyRequest then app.priority.lease=nil end
        check()
        return {ok=false,reason=tostring(reason),loading=loadingRejection(reason)}
    end
    if storyRequest then
        for i=2,values.n do
            local data=values[i]
            if type(data)=='table' and data.active==true and type(data.battleId)=='string' then
                if app.priority.closed[data.battleId] then app.priority.lease=nil
                else
                    app.priority.lease={id=data.battleId,requestedAt=os.clock()}
                    app.priority.battles[data.battleId]={lane=tonumber(data.lane) or 1}
                end
                break
            end
        end
    end
    if remote and remote==findRemote('DungeonAction') then
        for i=2,values.n do
            local value=values[i]
            if acceptDungeon(value) or (type(value)=='table' and (acceptDungeon(value.state) or acceptDungeon(value.view))) then break end
        end
    end
    if not remote and app.version==version then
        for i=2,values.n do
            local v=values[i]
            if accept(v) or (type(v)=='table' and accept(v.state)) then break end
        end
    end
    check()
    return {ok=true}
end
local function refresh()
    local last
    for attempt=1,3 do
        last=call('State',nil,nil)
        if last.ok then pause(app.config.delay);return end
        if attempt<3 then
            setStatus('State unavailable — resyncing in '..(attempt*2)..'s')
            pause(attempt*2)
        end
    end
    error('Cannot resync State: '..tostring(last.reason),0)
end
local function packCount(run)
    if not run or type(run.packs)~='table' then return nil end
    local count=0
    for _,n in pairs(run.packs) do count=count+math.max(tonumber(n) or 0,0) end
    return count
end
local function validTeam(run)
    if not run or type(run.team)~='table' or #run.team~=4 then return false end
    local seen={}
    local owned=nil
    if type(run.cards)=='table' then
        owned={}
        for key,card in pairs(run.cards) do
            if type(card)=='string' then owned[card]=true
            elseif type(card)=='table' and type(card.id)=='string' then owned[card.id]=true
            elseif type(key)=='string' and type(card)=='number' and card>0 then owned[key]=true end
        end
    end
    for _,id in ipairs(run.team) do
        if type(id)~='string' or id=='' or seen[id] or (owned and not owned[id]) then return false end
        seen[id]=true
    end
    return true
end
local function prepare()
    local run=activeRun()
    if not run then return end
    local runId=run.id
    if packCount(run)==nil then refresh();run=activeRun() end
    if not run or run.id~=runId then return end
    local count=packCount(run)
    if count and count>0 then
        for attempt=1,3 do
            setStatus('Opening packs ('..tostring(count)..' available), attempt '..attempt..'/3')
            local result=call('Open','all',1)
            if result.ok then pause(app.config.delay);break end
            setStatus('Open skipped/rejected: '..tostring(result.reason))
            -- Read-only resync; do not replay uncertain mutations.
            refresh();run=activeRun()
            if not run or run.id~=runId then return end
            count=packCount(run)
            if not count or count<=0 or result.uncertain or not result.loading or attempt==3 then
                setStatus('Continuing to AutoTeam; Open will be checked after the next fight')
                break
            end
            pause(attempt*2)
        end
    elseif count==0 then
        setStatus('No packs available — skipping Open')
    else
        setStatus('Pack balance unknown — skipping Open until next State')
    end
    for attempt=1,3 do
        setStatus('Selecting Auto Team, attempt '..attempt..'/3')
        local result=call('AutoTeam',nil,nil)
        if result.ok then
            pause(app.config.delay);refresh()
            run=activeRun()
            if not run or run.id~=runId then return end
            if not validTeam(run) then error('AutoTeam did not confirm a valid four-card team.',0) end
            return
        end
        setStatus('AutoTeam rejected: '..tostring(result.reason))
        refresh();run=activeRun()
        if not run or run.id~=runId then return end
        if result.uncertain or not result.loading or attempt==3 then
            if validTeam(run) then
                setStatus('Using the current four-card team confirmed by State')
                return
            end
            error('AutoTeam unavailable and State has no valid four-card team; paused.',0)
        end
        pause(attempt*2)
    end
end
local function nextStage(run)
    local wins=type(run.wins)=='table' and run.wins or {}
    for _,key in ipairs({'easy','medium','hard'}) do
        if (tonumber(wins[key]) or 0)<1 then return key end
    end
    return 'boss'
end
local lower={medium='easy',hard='medium',boss='hard'}
local function fight(target)
    if app.snapshot and app.snapshot.fighting then
        setStatus('Waiting for current fight')
        if not waitFor(function() return app.snapshot and not app.snapshot.fighting end,app.config.timeout) then
            error('Current fight timed out; no additional Fight was sent.',0)
        end
    end
    local version=app.resultVersion
    local beforeFightState=app.version
    setStatus('Fighting '..(target=='boss' and ('boss '..tostring(activeRun() and activeRun().boss)) or target))
    local sent=call('Fight',target,nil)
    if not sent.ok then
        setStatus('Fight response not accepted — checking State before any further action')
        refresh()
        local fighting=app.snapshot and app.snapshot.fighting
        local confirmed=fighting==target or (target=='boss' and type(fighting)=='string' and fighting:match('^boss%d+$'))
        if not confirmed and app.resultVersion<=version then
            error('Fight not confirmed; paused without replaying: '..tostring(sent.reason),0)
        end
    end
    if not waitFor(function() return app.resultVersion>version end,app.config.timeout) then
        error('No Result received; stopped to avoid duplicate Fight.',0)
    end
    local result=app.result
    local key=result.key
    if not (key==target or (target=='boss' and type(key)=='string' and key:match('^boss%d+$'))) then
        error('Unexpected Result: '..tostring(key),0)
    end
    if result.result~='Victory' and result.result~='Defeat' then
        error('Unknown result: '..tostring(result.result),0)
    end
    if result.result=='Victory' then app.wins=app.wins+1 else app.losses=app.losses+1 end
    if result.summary and result.summary.How=='cleared' then app.clears=app.clears+1 end
    setStatus(tostring(result.name or key)..' — '..result.result)
    if not waitFor(function()
        return app.version>beforeFightState and app.snapshot and not app.snapshot.fighting
    end,8) then
        refresh()
        if app.version<=beforeFightState or (app.snapshot and app.snapshot.fighting) then
            error('Post-fight State not confirmed. Press START to resync.',0)
        end
    end
    return result
end
local function runLoop()
    awaitPriority()
    setStatus('Syncing Draft state')
    local initialVersion=app.version
    refresh()
    if not waitFor(function() return app.version>initialVersion end,8) then
        error('State not received. Capture the State RETURN if this repeats.',0)
    end
    if app.snapshot.fighting then
        setStatus('Waiting for existing fight')
        if not waitFor(function() return not app.snapshot.fighting end,app.config.timeout) then
            error('Existing fight timed out.',0)
        end
    end
    local prepared=false
    while controller().enabled do
        check()
        if awaitPriority() then refresh() end
        local run=activeRun()
        if not run then
            app.recovery={}; app.stage=nil; app.runId=nil
            prepared=false
            setStatus('Starting a new run')
            local started=call('Start',{},nil)
            if not started.ok then setStatus('Start response not accepted — resyncing without replay') end
            pause(app.config.delay)
            refresh()
            run=activeRun()
            if not run then error('Start did not confirm an active run.',0) end
        end
        if app.runId~=run.id then
            app.runId=run.id; app.recovery={}; app.stage=nextStage(run)
        end
        if not prepared then prepare();prepared=true end
        if activeRun() then
            local job=app.recovery[#app.recovery]
            local target=job and job.target or app.stage
            local result=fight(target)
            if activeRun() then
                if result.result=='Victory' then
                    if job then
                        job.remaining=job.remaining-1
                        if job.remaining<=0 then table.remove(app.recovery) end
                    elseif app.stage=='easy' then app.stage='medium'
                    elseif app.stage=='medium' then app.stage='hard'
                    elseif app.stage=='hard' then app.stage='boss' end
                else
                    local fallback=lower[target]
                    if fallback then
                        local n=target=='boss' and app.config.bossFarm or app.config.farm
                        table.insert(app.recovery,{target=fallback,remaining=n})
                        setStatus('Recovery: win '..n..' '..fallback..' fights, then retry '..target)
                    else setStatus('Easy lost; retrying with refreshed team') end
                end
                -- Save fight progression before pack/team requests can fail.
                prepare()
            else
                app.recovery={}; app.runId=nil; app.stage=nil
                setStatus('Run ended; restarting')
            end
        end
        pause(app.config.delay)
    end
end
-- Native Auto Climb owns combat. This worker only starts runs and resolves card picks.
local climbConfig=nil
local function loadClimbConfig()
    if climbConfig then return climbConfig end
    local shared=RS:FindFirstChild('Shared')
    local module=shared and shared:FindFirstChild('DraftConfig',true)
    if not module then error('DraftConfig not found; cannot compare climb cards.',0) end
    local ok,config=pcall(require,module)
    if not ok or type(config)~='table' or type(config.ClimbStats)~='function' then
        error('Cannot read DraftConfig.ClimbStats; no card picks were guessed.',0)
    end
    climbConfig=config
    return config
end
local function climbRun()
    local climb=app.snapshot and app.snapshot.climb
    local run=type(climb)=='table' and climb.run
    return type(run)=='table' and not run.over and not run.Over and run or nil
end
local function climbId(run) return run and (run.id or run.Id) end
local function climbTeam(run) return run and (run.team or run.Team) end
local bannedClimbCards={}
for _,base in ipairs({'saiyan_prince','atomic','samurai_lost_man'}) do
    for _,suffix in ipairs({'','_gold','_rainbow','_secret'}) do
        bannedClimbCards[base..suffix]=true
    end
end
local preferredClimbCards={}
for _,base in ipairs({'limitless_sorcerer','curse_king','elf_mage','gone','slime','brother','red_hair'}) do
    for _,suffix in ipairs({'','_gold','_rainbow','_secret'}) do
        preferredClimbCards[base..suffix]=1.25
    end
end
for _,suffix in ipairs({'','_gold','_rainbow','_secret'}) do
    preferredClimbCards['teen_saski'..suffix]=1.5
end
local function rankClimbCards(ids,existingTeam)
    if type(ids)~='table' then error('Climb card list is missing.',0) end
    local ranked,seen={},{}
    local config=loadClimbConfig()
    for _,id in ipairs(ids) do
        if type(id)~='string' or id=='' then error('Unknown climb card format; paused.',0) end
        if not seen[id] and (existingTeam or not bannedClimbCards[id]) then
            if bannedClimbCards[id] then
                -- An old/manual banned card is replaced first when a valid offer arrives.
                seen[id]=true
                table.insert(ranked,{id=id,damage=0,hp=0,score=-math.huge})
                continue
            end
            local ok,damage,hp=pcall(config.ClimbStats,id)
            if not ok or type(damage)~='number' or type(hp)~='number'
                or damage~=damage or hp~=hp or damage<=0 or hp<=0
                or damage==math.huge or hp==math.huge then
                error('Cannot score climb card: '..id,0)
            end
            seen[id]=true
            table.insert(ranked,{id=id,damage=damage,hp=hp,score=(damage+hp/2)*(preferredClimbCards[id] or 1)})
        end
    end
    table.sort(ranked,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        if a.damage~=b.damage then return a.damage>b.damage end
        return a.id<b.id
    end)
    return ranked
end
local function pendingStart(run) return run and (run.start or run.Start) end
local function pendingOffer(run)
    local offer=run and (run.offer or run.Offer)
    if type(offer)~='table' then return nil end
    local cards=offer.cards or offer.Cards
    if type(cards)=='table' then return cards end
    if type(offer[1])=='string' then return offer end
    error('Unknown climb offer format; paused without choosing.',0)
end
local function sameTeam(team,picks)
    if type(team)~='table' or #team~=4 then return false end
    for i,id in ipairs(picks) do if team[i]~=id then return false end end
    return true
end
local function confirmClimb(predicate)
    local deadline=os.clock()+8
    repeat
        check()
        if predicate() then return true end
        refresh()
        if predicate() then return true end
        pause(.4)
    until os.clock()>=deadline
    return false
end
local function climbMutation(name,a,b,confirmed)
    local result=call(name,a,b)
    -- Do not replay: even a lost response may have applied the pick on the server.
    if not confirmClimb(confirmed) then
        error(name..' not confirmed; paused without resending'
            ..(result.ok and '.' or (': '..tostring(result.reason))),0)
    end
end
local function runClimbLoop()
    awaitPriority()
    loadClimbConfig()
    app.climbStatus='Syncing climb state';refresh()
    if type(app.snapshot and app.snapshot.climb)~='table' then
        error('Climb State missing; paused before starting a run.',0)
    end
    while controller().enabled do
        check()
        if awaitPriority() then refresh() end
        local run=climbRun()
        local climb=app.snapshot.climb
        if not run then
            if climb.bossLive then
                app.climbStatus='Waiting for current climb fight to end'
                pause(1);refresh()
            else
                local old=climbId(type(climb.run)=='table' and climb.run or nil)
                app.climbStatus='Starting a new climb';setStatus(app.climbStatus)
                climbMutation('ClimbStart',nil,nil,function()
                    local current=climbRun()
                    return current~=nil and (old==nil or climbId(current)~=old)
                end)
            end
        elseif type(pendingStart(run))=='table' then
            local ranked=rankClimbCards(pendingStart(run))
            if #ranked<4 then error('Fewer than four allowed starting cards; banned cards will not be picked.',0) end
            local picks={ranked[1].id,ranked[2].id,ranked[3].id,ranked[4].id}
            local id=climbId(run)
            app.climbStatus='Choosing the four strongest starting cards';setStatus(app.climbStatus)
            climbMutation('ClimbPickStart',picks,nil,function()
                local current=climbRun()
                return climbId(current)==id and pendingStart(current)==nil and sameTeam(climbTeam(current),picks)
            end)
        elseif pendingOffer(run) then
            local offers=pendingOffer(run)
            local team=climbTeam(run)
            if type(team)~='table' or #team~=4 then error('Climb team must contain four cards.',0) end
            local rankedTeam=rankClimbCards(team,true)
            if #rankedTeam~=4 then error('Climb team has duplicate cards; paused.',0) end
            local rankedOffer=rankClimbCards(offers)
            local weakest=rankedTeam[#rankedTeam]
            local best
            for _,card in ipairs(rankedOffer) do
                if not table.find(team,card.id) then best=card;break end
            end
            local offerIndex,slot=0,nil
            local expected=table.clone(team)
            if best and best.score>weakest.score then
                offerIndex=table.find(offers,best.id);slot=table.find(team,weakest.id)
                expected[slot]=best.id
                app.climbStatus='Replacing '..weakest.id..' with '..best.id
            else app.climbStatus='Keeping team — offer is not stronger' end
            setStatus(app.climbStatus)
            local id=climbId(run)
            climbMutation('ClimbPick',offerIndex,slot,function()
                local current=climbRun()
                return climbId(current)==id and pendingOffer(current)==nil and sameTeam(climbTeam(current),expected)
            end)
        else
            app.climbStatus=climb.auto==false and 'Turn ON Auto Climb in the game to advance floors'
                or (run.paused and 'Climb is paused in the game — resume it to continue'
                or 'Waiting for native Auto Climb / next card offer')
            setStatus(app.climbStatus)
            pause(1);refresh()
        end
        pause(app.config.delay)
    end
end

-- Cooldowns come only from the server's explicit Ready in response.
local function storyCooldownKey(id,difficulty) return id..':'..difficulty end
local function parseStoryCooldown(reason)
    if type(reason)~='string' then return nil end
    local duration=reason:lower():match('^%s*ready in%s+(.+)%s*$')
    if not duration then return nil end
    local seconds,count=0,0
    local seen={}
    for number,unit in duration:gmatch('(%d+)%s*([hms])') do
        if seen[unit] then return nil end
        seen[unit]=true;count=count+1
        seconds=seconds+tonumber(number)*({h=3600,m=60,s=1})[unit]
    end
    local remainder=duration:gsub('%d+%s*[hms]',''):gsub('%s',''):gsub('%.$','')
    if count==0 or remainder~='' or seconds~=seconds or seconds==math.huge then return nil end
    return seconds
end
local function cooldownText(seconds)
    seconds=math.max(0,math.ceil(seconds))
    return string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
end
local function runStoryLoop()
    local remote=remotes:FindFirstChild('StoryFight')
    if not remote then error('StoryFight remote not found.',0) end
    local cursor=0
    while controller().enabled do
        check()
        awaitPriority()
        local selected={}
        for _,boss in ipairs(storyBosses) do
            if app.config['story_'..boss.key] then table.insert(selected,boss) end
        end
        if #selected==0 then
            setStatus('Select at least one Story boss')
        else
            local now=os.clock()
            local difficulty=app.config.storyDifficulty
            local chosen,position,earliest=nil,nil,math.huge
            for offset=1,#selected do
                local index=(cursor+offset-1)%#selected+1
                local boss=selected[index]
                local deadline=app.story.cooldowns[storyCooldownKey(boss.id,boss.secret and 'Secret' or difficulty)] or 0
                earliest=math.min(earliest,deadline)
                if not chosen and deadline<=now then chosen=boss;position=index end
            end
            if not chosen then
                setStatus('All selected bosses on cooldown — next in '..cooldownText(earliest-now))
            elseif now<app.story.nextAttemptAt then
                setStatus('Next Start attempt in '..cooldownText(app.story.nextAttemptAt-now))
            else
                cursor=position
                difficulty=chosen.secret and 'Secret' or difficulty
                setStatus('Requesting '..chosen.name..' / '..difficulty)
                local result=call(chosen.id,difficulty,nil,remote)
                -- Pace from response receipt; includes time waiting for other requests.
                app.story.nextAttemptAt=os.clock()+1.5
                app.story.requests=app.story.requests+1
                if result.uncertain then
                    error('StoryFight response lost; paused without replaying: '..tostring(result.reason),0)
                end
                local key=storyCooldownKey(chosen.id,difficulty)
                if result.ok then
                    app.story.cooldowns[key]=nil
                    setStatus('Start request sent: '..chosen.name..' / '..difficulty)
                else
                    local seconds=parseStoryCooldown(result.reason)
                    if seconds then
                        app.story.cooldowns[key]=os.clock()+seconds
                        setStatus(chosen.name..' cooldown: '..cooldownText(seconds))
                    else
                        if tostring(result.reason):lower():find('slow down',1,true) then app.story.nextAttemptAt=os.clock()+5 end
                        setStatus(chosen.name..': '..tostring(result.reason))
                    end
                end
            end
        end
        pause(.25)
    end
end

local function dungeonVitals(run)
    local sum,alive,lowest=0,0,1
    for _,id in ipairs(run.cards or run.team or {}) do
        local hp=type(run.hp)=='table' and tonumber(run.hp[id])
        if hp and hp>0 then alive=alive+1;sum=sum+hp;lowest=math.min(lowest,hp) end
    end
    return alive,alive>0 and sum/alive or 0,lowest
end
local function dungeonDoor(run,path)
    local alive,average,lowest=dungeonVitals(run)
    local trouble=run.trouble==true or alive<=1 or average<.35
    local recovering=average<.6 or lowest<.35
    local order
    if trouble or (path~='Loot' and (recovering or (path=='Safe' and average<1))) then
        order={'VAULT','RECOVERY','TREASURE','CURSE','ELITE','FORTUNE','EXIT'}
        if trouble then
            local recovery=false
            for _,door in ipairs(run.doors or {}) do if door.kind=='RECOVERY' then recovery=true end end
            if not recovery then for i,door in ipairs(run.doors or {}) do if door.kind=='EXIT' then return i end end end
        end
    elseif path=='Loot' then order={'VAULT','FORTUNE','TREASURE','CURSE','ELITE','RECOVERY','EXIT'}
    elseif path=='Safe' or average<.7 then order={'VAULT','TREASURE','CURSE','ELITE','FORTUNE','RECOVERY','EXIT'}
    else order={'VAULT','TREASURE','FORTUNE','CURSE','ELITE','RECOVERY','EXIT'} end
    for _,kind in ipairs(order) do for i,door in ipairs(run.doors or {}) do if door.kind==kind then return i end end end
    return nil
end
local function dungeonCards(text,count)
    local out,seen={},{}
    for id in tostring(text):gmatch('[%w_]+') do
        if seen[id] then error('Duplicate Dungeon card: '..id,0) end
        seen[id]=true;out[#out+1]=id
    end
    if #out~=count then error('Dungeon requires '..count..' card IDs in this field.',0) end
    return out,seen
end
local function runDungeonLoop()
    local remote=remotes:FindFirstChild('DungeonAction')
    if not remote then error('DungeonAction not found.',0) end
    local waitingSince=nil
    local enteredRun=nil
    local function enterDungeon()
        local started=os.clock()
        while true do
            setStatus('Entering Dungeon')
            local result=call('Enter',nil,nil,remote)
            if result.uncertain then error('Enter response lost; paused without replaying: '..tostring(result.reason),0) end
            if result.ok then pause(1);return end
            if not tostring(result.reason):lower():find('already teleporting',1,true) then
                error('Enter rejected: '..tostring(result.reason),0)
            end
            if os.clock()-started>30 then error('Dungeon teleport has not completed after 30s; paused.',0) end
            setStatus('Server is already teleporting you — waiting to enter Dungeon')
            pause(1.5)
        end
    end
    local function mutate(name,payload,confirmed)
        local before=app.dungeon.version
        local result=call(name,payload,nil,remote)
        if not result.ok and not result.uncertain then
            if name=='Start' and tostring(result.reason):lower():find('already have a run',1,true) then
                setStatus('Existing Dungeon run found — returning and syncing State')
                enterDungeon()
                if not waitFor(function()
                    return app.dungeon.view and type(app.dungeon.view.run)=='table'
                end,12) then
                    error('Entered existing Dungeon but no active run State arrived; paused without sending another Start.',0)
                end
                enteredRun=app.dungeon.view.run.id
                return true
            end
            if name=='Start' and not app.dungeon.view then
                if not waitFor(function()return app.dungeon.view~=nil end,3) then
                    error('Start rejected: '..tostring(result.reason)..'; server did not provide Dungeon State.',0)
                end
            end
            setStatus(name..' rejected: '..tostring(result.reason)..' — move near the guard/door if requested')
            pause(3);return false
        end
        if not waitFor(function()return app.dungeon.version>before and confirmed()end,12) then
            error(name..' not confirmed by Dungeon State; stopped without resending.',0)
        end
        return true
    end
    while controller().enabled do
        check()
        if awaitPriority() then waitingSince=nil;enteredRun=nil end
        local view=app.dungeon.view
        local run=view and view.run
        if not view or type(run)~='table' then
            view=view or {}
            local unlocked=view.unlocked and view.unlocked[app.config.dungeonDifficulty]
            if unlocked and unlocked.ok==false then error(unlocked.why or 'Dungeon difficulty locked.',0) end
            local team,seen=dungeonCards(app.config.dungeonTeam,4)
            local reserves=dungeonCards(app.config.dungeonReserves,2)
            for _,id in ipairs(reserves) do if seen[id] then error('Dungeon team/reserves must be six different cards.',0) end end
            if app.dungeon.collection.ready then
                for _,group in ipairs({team,reserves}) do for _,id in ipairs(group) do
                    if not app.dungeon.collection.cards[id] then error('Dungeon card is no longer owned; update the team in the card picker.',0) end
                end end
            end
            if view.last then setStatus('Dungeon ended — preparing the next run');pause(1) end
            local old=view.last and view.last.run
            setStatus('Starting Dungeon / '..app.config.dungeonDifficulty)
            mutate('Start',{team=team,reserves=reserves,difficulty=app.config.dungeonDifficulty},function()
                local current=app.dungeon.view and app.dungeon.view.run
                return type(current)=='table' and current.id~=old
            end)
            waitingSince=nil
        elseif enteredRun~=run.id and not run.fighting and not view.battle then
            enterDungeon()
            enteredRun=run.id
        elseif run.fighting or view.battle or run.away then
            waitingSince=waitingSince or os.clock()
            setStatus(run.away and 'Waiting for server to recover the previous fight' or ('Fighting room '..tostring(run.room)))
            if os.clock()-waitingSince>app.config.timeout then error('Dungeon fight State timed out; no duplicate Fight was sent.',0) end
            pause(.1)
        else
            waitingSince=nil
            local id,room=run.id,run.room
            if type(room)~='number' then error('Dungeon State is missing its room number.',0) end
            local function current()return app.dungeon.view and app.dungeon.view.run end
            if awaitPriority() then
                enteredRun=nil
                continue
            end
            if run.phase=='fight' then
                setStatus('Starting room '..room)
                mutate('Fight',room,function()
                    local r=current()
                    return not r or r.id~=id or r.fighting==true or r.phase~='fight' or r.room~=room
                end)
            elseif run.phase=='doors' then
                local index=dungeonDoor(run,app.config.dungeonPath)
                if not index then error('Dungeon State has no supported door to choose.',0) end
                setStatus('Choosing '..run.doors[index].kind..' / door '..index)
                mutate('Door',index,function()
                    local r=current();return not r or r.id~=id or r.room~=room or r.phase~='doors'
                end)
            elseif run.phase=='checkpoint' then
                local alive,average=dungeonVitals(run)
                local withdraw=room>=app.config.dungeonCashOut or run.trouble==true or alive<=1 or average<.35
                    or (app.config.dungeonPath=='Safe' and (alive<3 or average<.6))
                local actionName=withdraw and 'CashOut' or 'Continue'
                setStatus(actionName..' at room '..room)
                mutate(actionName,nil,function()
                    local r=current();return not r or r.id~=id or r.phase~='checkpoint'
                end)
            else error('Unknown Dungeon phase: '..tostring(run.phase),0) end
            pause(.1)
        end
    end
end

local function stopController(ctx)
    local mode=ctx==app.climb and 'climb' or (ctx==app.story and 'story' or (ctx==app.dungeon and 'dungeon' or 'draft'))
    app.config[mode..'Enabled']=false;app.config.savedModeSelection=true
    ctx.enabled=false
    ctx.status=ctx.worker and 'Stopping — current server fight continues' or 'Stopped'
end
function app.stop(mode)
    if mode=='draft' then stopController(app)
    elseif mode=='climb' then stopController(app.climb)
    elseif mode=='story' then stopController(app.story)
    elseif mode=='dungeon' then stopController(app.dungeon)
    else stopController(app);stopController(app.climb);stopController(app.story);stopController(app.dungeon) end
    redraw()
end
function app.start(mode)
    if mode~='draft' and mode~='climb' and mode~='story' and mode~='dungeon' then mode=app.config.mode end
    local ctx=mode=='climb' and app.climb or (mode=='story' and app.story or (mode=='dungeon' and app.dungeon or app))
    if not app.alive or ctx.worker then return end
    app.config.mode=mode -- Auto Load preference only; never selects the live worker.
    app.config[mode..'Enabled']=true;app.config.savedModeSelection=true
    ctx.stopReason=nil;ctx.lastError=nil
    ctx.enabled=true;ctx.worker=true
    task.spawn(function()
        local thread=coroutine.running()
        workerContexts[thread]=ctx
        local ok,err=pcall(mode=='climb' and runClimbLoop or (mode=='story' and runStoryLoop or (mode=='dungeon' and runDungeonLoop or runLoop)))
            ctx.enabled=false;ctx.worker=false
        if not ok and tostring(err)~='__STOP__' then
            ctx.lastError=tostring(err)
            setStatus('ERROR: '..ctx.lastError)
        else setStatus(ctx.stopReason or 'Stopped') end
        workerContexts[thread]=nil
    end)
end

function app.restoreSavedModes()
    if not app.config.savedModeSelection then app.start(app.config.mode);return end
    local modes={}
    for _,mode in ipairs({'draft','climb','story','dungeon'}) do modes[mode]=app.config[mode..'Enabled']==true end
    for _,mode in ipairs({'draft','climb','story','dungeon'}) do if modes[mode] then app.start(mode) end end
end

-- WindUI rendering adapter; gameplay controllers are shared with the stable script.
local UILibrary={}
function UILibrary.Create(ctx)
    local WindUI=loadstring(game:HttpGet('https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua'))()
    local app=ctx.app
    local themes={
    Light={bg='F2F5FC',side='E7EDF8',panel='FFFFFF',row='EAF0FA',text='14213A',muted='526781',accent='4264D9',line='D1DBED',selected='DDE8FF',selectedText='173C85',mint='087B72',gold='986014',rose='B33764',violet='7045BC'},
    Midnight={bg='0B0D13',side='10121B',panel='171B28',row='202638',text='F0F4FF',muted='99A9C8',accent='6D8BFF',line='303B58',selected='28476B',selectedText='D9F4FF',mint='62DCC1',gold='F3C276',rose='F28FB4',violet='BAA0FF'},
    Ocean={bg='080F16',side='0C1822',panel='102635',row='17394B',text='ECFAFF',muted='8EBACD',accent='36DBCE',line='255166',selected='164C56',selectedText='CFFFF6',mint='5CE1C2',gold='F4CC84',rose='FF9EBD',violet='B5A5FF'},
    Violet={bg='171322',side='20192E',panel='2B213C',row='392C50',text='F6EFFF',muted='B8A8D4',accent='BC8AFF',line='534267',selected='503D78',selectedText='F4E8FF',mint='70E2CC',gold='F2CA83',rose='FFA0C1',violet='C7A8FF'},
    Emerald={bg='101C18',side='152B24',panel='1C372D',row='29463A',text='EFFFF4',muted='A0C8B0',accent='60D8A8',line='3E6454',selected='235545',selectedText='D2FFEC',mint='79E8BD',gold='F4CE86',rose='FCA3C0',violet='B7ACFF'},
    Rose={bg='23171C',side='311D27',panel='3E2633',row='503442',text='FFEFF4',muted='D9A9BC',accent='FF8FB2',line='704859',selected='64364E',selectedText='FFE2EE',mint='7AE5CE',gold='F5CF92',rose='FFABCD',violet='C8ADFF'},
}
    for name,p in pairs(themes)do
        local function c(hex)return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))end
        WindUI:AddTheme({Name=name,Accent=c(p.accent),Background=c(p.bg),Outline=c(p.line),Text=c(p.text),Placeholder=c(p.muted),Button=c(p.row),Icon=c(p.mint)})
    end
    local window=WindUI:CreateWindow({Title='Anime Duel',Author='aqua · WindUI',Icon='swords',Folder='AnimeDuelWindUI',
        Size=UDim2.fromOffset(app.config.windowW,app.config.windowH),Theme='Dark',Resizable=true,AutoScale=true,
        SideBarWidth=190,ScrollBarEnabled=true,ToggleKey=Enum.KeyCode.RightShift,Acrylic=false})
    local alive=true
    local updating=false
    local function quiet(control,callback)
        control:Lock()
        local ok,err=pcall(callback)
        control:Unlock()
        if not ok then error(err,0)end
    end
    local controls,statuses={},{}
    local function section(tab,title,opened)return tab:Section({Title=title,Opened=opened~=false,Box=true})end
    local function status(tab,title,get)
        local item=tab:Paragraph({Title=title,Desc='—'})
        statuses[#statuses+1]={item=item,get=get,last=nil};return item
    end
    local function toggle(tab,title,key)
        local c=tab:Toggle({Title=title,Value=ctx.flags[key]==true,Callback=function(v)
            if alive and v~=ctx.flags[key] then ctx.setFlag(key,v) end
        end})
        controls[#controls+1]={item=c,key=key,kind='toggle',last=ctx.flags[key]}
    end
    local function dropdown(tab,title,key,values)
        local strings={};for _,v in ipairs(values)do strings[#strings+1]=tostring(v)end
        local c=tab:Dropdown({Title=title,Values=strings,Value=tostring(ctx.flags[key]),SearchBarEnabled=true,Callback=function(v)
            if alive and v~=ctx.flags[key] then ctx.setFlag(key,v) end
        end})
        controls[#controls+1]={item=c,key=key,kind='dropdown',last=ctx.flags[key]}
        return c
    end
    local function input(tab,title,key)
        local c=tab:Input({Title=title,Value=tostring(ctx.flags[key] or ''),Callback=function(v)if alive and tostring(v)~=tostring(ctx.flags[key])then ctx.setFlag(key,v)end end})
        controls[#controls+1]={item=c,key=key,kind='input',last=ctx.flags[key]}
    end
    local function button(tab,title,callback)tab:Button({Title=title,Callback=function()if alive then callback()end end})end
    local overview=window:Tab({Title='Overview',Icon='layout-dashboard'})
    status(overview,'Draft',function()return app.status end)
    status(overview,'Climb',function()return app.climb.status end)
    status(overview,'Story Boss',function()return app.story.status end)
    status(overview,'Dungeon',function()return app.dungeon.status end)
    status(overview,'Priority',function()return app.priority.status end)
    status(overview,'Draft results',function()return app.wins..' wins · '..app.losses..' losses · '..app.clears..' clears'end)
    button(overview,'Stop all script autos',function()app.stop()end)
    local draft=window:Tab({Title='Draft Run',Icon='layers'})
    toggle(draft,'Auto Draft Run','DraftRunning')
    status(draft,'Status',function()return app.status end)
    input(draft,'Recovery wins','farm');input(draft,'Boss recovery wins','bossFarm')
    input(draft,'Action delay (seconds)','delay');input(draft,'Fight timeout (seconds)','timeout')
    status(draft,'Current team',function()local r=app.snapshot and app.snapshot.run;return r and table.concat(r.team or {},', ') or 'No run'end)
    local climb=window:Tab({Title='Draft Climb',Icon='trending-up'})
    toggle(climb,'Auto Climb card picker','ClimbRunning')
    status(climb,'Status',function()return app.climb.status end)
    climb:Paragraph({Title='Native combat',Desc='Enable native Auto Climb in the game. This toggle manages starting and card choices; it does not stop native fights.'})
    local boss=window:Tab({Title='Story Boss',Icon='skull'})
    toggle(boss,'Auto Story Boss','BossRunning')
    dropdown(boss,'Difficulty','storyDifficulty',{'Easy','Medium','Hard','Nightmare'})
    local selected,options,lookup={},{},{}
    for _,b in ipairs(ctx.storyBosses)do local label=b.name..(b.secret and ' [Secret]' or '');options[#options+1]=label;lookup[label]=b;if app.config['story_'..b.key]then selected[#selected+1]=label end end
    local bossChoice=boss:Dropdown({Title='Boss targets',Values=options,Value=selected,Multi=true,AllowNone=true,SearchBarEnabled=true,Callback=function(values)
        if not alive then return end
        for _,b in ipairs(ctx.storyBosses)do app.config['story_'..b.key]=false end
        for _,label in ipairs(values)do local b=lookup[label];if b then app.config['story_'..b.key]=true end end
    end})
    status(boss,'Status',function()return app.story.status end)
    status(boss,'Cooldowns',function()
        local out={};for _,b in ipairs(ctx.storyBosses)do if app.config['story_'..b.key]then
            local seconds=(app.story.cooldowns[ctx.cooldownKey(b.id,b.secret and 'Secret' or app.config.storyDifficulty)]or 0)-os.clock()
            out[#out+1]=b.name..': '..(seconds>0 and ctx.cooldownText(seconds)or 'Ready / no known cooldown')
        end end;return #out>0 and table.concat(out,'\n')or 'No bosses selected'
    end)
    local dungeon=window:Tab({Title='Dungeon',Icon='castle'})
    toggle(dungeon,'Auto Dungeon','DungeonRunning')
    status(dungeon,'Status',function()return app.dungeon.status end)
    status(dungeon,'Room & health',function()
        local r=app.dungeon.view and app.dungeon.view.run;if not r then return 'No active Dungeon'end
        local n,h=ctx.dungeonVitals(r);return 'Room '..r.room..' · '..r.phase..' · '..n..' alive · '..math.floor(h*100+.5)..'% HP'
    end)
    local route=section(dungeon,'Route & priorities',false)
    dropdown(route,'Difficulty','dungeonDifficulty',{'Normal','Hard','Nightmare'})
    dropdown(route,'Path','dungeonPath',{'Balanced','Loot','Safe'})
    dropdown(route,'Cash out at room','dungeonCashOut',{5,10,15,20})
    toggle(route,'Yield to native Rift','pauseForRift');toggle(route,'Prioritize ready Story Boss','sequenceBossDungeon')
    local squad=section(dungeon,'Team · 4 main / 2 reserves',true)
    local slots={};local collectionRevision=-1;local labels,ids={},{};local cardPage=1;local pageCount=1;local lastSlots=nil
    local initialSlots=app.getDungeonSlots()
    for i=1,6 do
        local slot=i
        local initial=initialSlots[i]~='' and ('Selected ['..initialSlots[i]..']')or'Empty'
        if initial~='Empty'then ids[initial]=initialSlots[i]end
        slots[i]=squad:Dropdown({Title=i<=4 and ('Team '..i)or('Reserve '..(i-4)),Values={initial},Value=initial,SearchBarEnabled=true,Callback=function(label)
            if not alive then return end
            local id=ids[label] or ''
            if app.getDungeonSlots()[slot]==id then return end
            local ok,reason=app.setDungeonSlot(slot,id)
            if not ok then WindUI:Notify({Title='Team selection',Content=reason,Duration=4});collectionRevision=-1 end
        end})
    end
    status(squad,'Collection',function()return app.dungeon.collection.status end)
    button(squad,'Refresh owned cards',app.refreshDungeonCollection)
    local gallery=section(dungeon,'Card preview',false)
    local preview=gallery:Paragraph({Title='Choose an owned card',Desc='Search by name, border or ID.'})
    local previewSelect=gallery:Dropdown({Title='Inspect card',Values={'Empty'},Value='Empty',SearchBarEnabled=true,Callback=function(label)
        local card=app.dungeon.collection.cards[ids[label]]
        if card then preview:SetTitle(card.name);preview:SetDesc(card.border..' · x'..card.count..'\nDamage '..card.damage..' · HP '..card.health);preview:SetThumbnail(card.image,80)end
    end})
    local history=section(dungeon,'Last 10 runs',false)
    history:Paragraph({Title='Time tracking',Desc='Time observed this session, including teleporting and pauses for other modes.'})
    for i=1,10 do local index=i;status(history,'Run #'..i,function()
        local r=app.dungeon.history[index];if not r then return '—'end
        return tostring(r.difficulty or '?')..' · '..r.reason..' · '..ctx.cooldownText(r.seconds)..' · '..tostring(r.cleared or '?')..' rooms\n'..r.rewards
    end)end
    local config=window:Tab({Title='Profiles',Icon='save'})
    input(config,'Profile name','ProfileName')
    local profileSelect=config:Dropdown({Title='Saved profiles',Values=ctx.profile.storedNames,SearchBarEnabled=true,Callback=function(v)if type(v)=='string'then ctx.setFlag('ProfileName',v)end end})
    button(config,'Save profile',function()ctx.saveProfile(ctx.flags.ProfileName)end)
    button(config,'Load profile',function()ctx.loadProfile(ctx.flags.ProfileName)end)
    button(config,'Set Auto Load (save current settings)',function()ctx.setAutoProfile(ctx.flags.ProfileName)end)
    button(config,'Clear Auto Load',ctx.clearAutoProfile)
    button(config,'Delete profile',function()ctx.deleteProfile(ctx.flags.ProfileName)end)
    toggle(config,'Auto Start saved modes','autoStart')
    status(config,'Profile storage',function()return app.profiles.status..'\nAuto Load: '..tostring(app.profiles.auto or 'OFF')end)
    local settings=window:Tab({Title='Settings',Icon='settings'})
    toggle(settings,'Anti-AFK','antiAfk');toggle(settings,'Auto reconnect','autoReconnect');toggle(settings,'Auto execute after hop','autoExecuteOnHop')
    status(settings,'Anti-AFK',function()return app.config.antiAfk and app.afk.status or 'OFF'end)
    status(settings,'Reconnect',function()return app.reconnect.status end)
    status(settings,'Teleport execution',function()return app.hop.status end)
    button(settings,'Rejoin current server',ctx.rejoinServer)
    dropdown(settings,'Theme','AO_UI_Theme',{'Midnight','Ocean','Violet','Emerald','Rose','Light'})
    settings:Slider({Title='Transparency',Value={Min=0,Max=65,Default=app.config.transparency},Callback=function(v)if alive then ctx.setFlag('AO_UI_Transparency',v)end end})
    button(settings,'Unload script',function()app.destroy()end)
    button(gallery,'Previous card page',function()cardPage=math.max(1,cardPage-1);collectionRevision=-1;app.ui.Refresh()end)
    button(gallery,'Next card page',function()cardPage=math.min(pageCount,cardPage+1);collectionRevision=-1;app.ui.Refresh()end)
    local pageInfo=gallery:Paragraph({Title='Card pages',Desc='30 cards per page to keep menus responsive.'})
    local lastBoss,lastProfiles,lastTheme,lastTransparency
    local function paint()
        if not alive then return end
        for _,c in ipairs(controls)do local value=ctx.flags[c.key];if value~=c.last then
            c.last=value;if c.kind=='toggle'then c.item:Set(value==true,false)elseif c.kind=='input'then c.item:Set(tostring(value or ''))else quiet(c.item,function()c.item:Select(tostring(value))end)end
        end end
        for _,entry in ipairs(statuses)do local value=tostring(entry.get());if value~=entry.last then entry.last=value;entry.item:SetDesc(value)end end
        local bosses={};for _,label in ipairs(options)do if app.config['story_'..lookup[label].key]then bosses[#bosses+1]=label end end
        local key=table.concat(bosses,'|');if key~=lastBoss then lastBoss=key;quiet(bossChoice,function()bossChoice:Select(bosses)end)end
        local profileKey=table.concat(ctx.profile.storedNames,'|');if profileKey~=lastProfiles then lastProfiles=profileKey;quiet(profileSelect,function()profileSelect:Refresh(ctx.profile.storedNames)end)end
        local owned=app.dungeon.collection
        local revision=owned.revision..'/'..cardPage
        if revision~=collectionRevision then
            collectionRevision=revision;labels={'Empty'};ids={};local byId={}
            local all=app.listDungeonCards('','All','Power')
            pageCount=math.max(1,math.ceil(#all/30));cardPage=math.clamp(cardPage,1,pageCount)
            pageInfo:SetDesc('Page '..cardPage..' / '..pageCount..' · '..#all..' owned cards. Search applies to this page.')
            for _,card in ipairs(all)do
                byId[card.id]=card.name..' · '..card.border..' · x'..card.count..' ['..card.id..']'
            end
            for index=(cardPage-1)*30+1,math.min(#all,cardPage*30)do
                local card=all[index]
                local label=card.name..' · '..card.border..' · x'..card.count..' ['..card.id..']'
                labels[#labels+1]=label;ids[label]=card.id;byId[card.id]=label
            end
            local selectedSlots=app.getDungeonSlots()
            for i,c in ipairs(slots)do
                local id=selectedSlots[i]
                local label=byId[id]
                if id~='' and (not label or not ids[label])then label=label or ('Not owned ['..id..']');labels[#labels+1]=label;ids[label]=id end
                quiet(c,function()c:Refresh(labels);c:Select(label or 'Empty')end)
            end
            quiet(previewSelect,function()previewSelect:Refresh(labels)end)
            lastSlots=app.config.dungeonTeam..'/'..app.config.dungeonReserves
        end
        local slotKey=app.config.dungeonTeam..'/'..app.config.dungeonReserves
        if lastSlots~=slotKey then
            lastSlots=slotKey
            local selected=app.getDungeonSlots()
            for i,c in ipairs(slots)do
                local label='Empty'
                for text,id in pairs(ids)do if id==selected[i]then label=text;break end end
                quiet(c,function()c:Select(label)end)
            end
        end
        if lastTheme~=app.config.theme then lastTheme=app.config.theme;WindUI:SetTheme(lastTheme)end
        if lastTransparency~=app.config.transparency then lastTransparency=app.config.transparency;window:SetBackgroundTransparency(lastTransparency/100)end
    end
    local function refresh()
        if not alive or updating then return end
        updating=true
        local ok,err=pcall(paint)
        updating=false
        if not ok then error(err,0)end
    end
    window:OnDestroy(function()if alive then app.destroy()end end)
    local api={Root=window.UIElements.Main,Window=window,Library=WindUI,Repaint=refresh,Refresh=refresh,
        Notify=function(message,kind,duration)WindUI:Notify({Title=kind or 'Anime Duel',Content=message,Duration=duration or 4})end,
        ClearNotifications=function()end,
        Destroy=function()if not alive then return end;alive=false;window:Destroy()end}
    refresh();overview:Select()
    return api
end

local ui
local uiState={alive=true,connections={},gameIcon='rbxthumb://type=GameIcon&id='..tostring(game.GameId or game.PlaceId)..'&w=150&h=150'}
local uiFlags={}
local profileView={}
local flagKeys={AO_UI_Theme='theme',AO_UI_Transparency='transparency',AO_UI_WindowW='windowW',AO_UI_WindowH='windowH',AO_UI_WindowX='windowX',AO_UI_WindowY='windowY'}
local function syncUI()
    for key,configKey in pairs(flagKeys) do uiFlags[key]=app.config[configKey] end
    for _,key in ipairs({'farm','bossFarm','delay','timeout','autoStart','autoReconnect','antiAfk','autoExecuteOnHop','pauseForRift','sequenceBossDungeon','storyDifficulty','dungeonDifficulty','dungeonPath','dungeonCashOut','dungeonTeam','dungeonReserves'}) do uiFlags[key]=app.config[key] end
    uiFlags.DungeonCollectionRevision=app.dungeon.collection.revision..'/'..app.dungeon.collection.status
    uiFlags.DungeonRunning=app.dungeon.enabled;uiFlags.DraftRunning=app.enabled;uiFlags.ClimbRunning=app.climb.enabled;uiFlags.BossRunning=app.story.enabled
    local selection={}
    for _,boss in ipairs(storyBosses) do selection[#selection+1]=app.config['story_'..boss.key] and '1' or '0' end
    uiFlags.BossSelectionRevision=table.concat(selection)
    profileView.currentProfile=app.profiles.current;profileView.storedNames=app.profiles.names
    if uiFlags.ProfileName==nil then uiFlags.ProfileName=app.profiles.current end
end
local function setUIFlag(key,value)
    uiFlags.InputRevision=(tonumber(uiFlags.InputRevision) or 0)+1
    if key=='ProfileName' then uiFlags.ProfileName=value;return end
    local modes={DraftRunning='draft',ClimbRunning='climb',BossRunning='story',DungeonRunning='dungeon'}
    if modes[key] then if value then app.start(modes[key]) else app.stop(modes[key]) end;return end
    local configKey=flagKeys[key] or key
    local range=ranges[configKey]
    if range then
        local number=tonumber(value)
        if number and number==number and number>=range[1] and number<=range[2] then app.config[configKey]=range[3] and math.floor(number) or number end
    elseif configKey=='dungeonPath' then
        if table.find({'Balanced','Loot','Safe'},value) then app.config.dungeonPath=value end
    elseif configKey=='dungeonDifficulty' then
        if table.find({'Normal','Hard','Nightmare'},value) then app.config.dungeonDifficulty=value end
    elseif configKey=='dungeonTeam' or configKey=='dungeonReserves' then
        app.config[configKey]=tostring(value)
    elseif configKey=='theme' then
        if themesAllowed[value] then app.config.theme=value end
    elseif configKey=='storyDifficulty' then
        if table.find(storyDifficulties,value) then app.config.storyDifficulty=value end
    elseif type(app.config[configKey])=='boolean' and type(value)=='boolean' then app.config[configKey]=value end
    redraw()
end
function app.destroy()
    if not app.alive then return end
    app.stop();app.alive=false;uiState.alive=false
    if app.afk.release then pcall(app.afk.release);app.afk.release=nil end
    if ui then ui.Destroy() end
    for _,connection in ipairs(app.connections) do connection:Disconnect() end
    table.clear(app.connections)
end
uiState.stop=function()app.destroy()end
syncUI()
ui=UILibrary.Create({app=app,state=uiState,profile=profileView,flags=uiFlags,playerGui=playerGui,
    Workspace=Workspace,UIS=UIS,GuiService=GuiService,env=env,setFlag=setUIFlag,
    dungeonVitals=dungeonVitals,storyBosses=storyBosses,cooldownKey=storyCooldownKey,cooldownText=cooldownText,
    saveProfile=function(name)app.saveProfile(name);redraw()end,
    loadProfile=function(name)app.loadProfile(name);redraw()end,
    deleteProfile=function(name)app.deleteProfile(name);redraw()end,
    setAutoProfile=function(name)app.setAutoProfile(name);redraw()end,
    clearAutoProfile=function()app.clearAutoProfile();redraw()end,
    rejoinServer=function()app.requestReconnect(true)end,
    saveAppearance=function()
        for key,configKey in pairs(flagKeys) do if key~='AO_UI_Theme' and key~='AO_UI_Transparency' then app.config[configKey]=uiFlags[key] end end
    end,
})
app.Root=ui.Root;app.ui=ui
render=function()if ui and app.alive then syncUI();ui.Repaint();ui.Refresh()end end
redraw()
setStatus('Ready — WindUI / independent mode controls')
monitorConnection()
app.refreshDungeonCollection()
if autoLoaded and app.config.autoStart then app.restoreSavedModes() end
