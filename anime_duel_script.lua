-- anime duel script
-- Embeds the actual Anime Card Online UI library with Anime Duel bindings.
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
local app = {build='studio-v18-native-clean',alive=true, enabled=false, worker=false, bosses={}, connections={}, snapshot=nil,
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
        local payload="if not game:IsLoaded() then game.Loaded:Wait() end; loadstring(game:HttpGet('https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/main/anime_duel_script.lua?v='..os.time()))()"
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

-- Exact embedded Online UI library, upstream 831eaf86123661bbb2bad7d26605bde614a47262.
-- Only product sections, labels and bindings differ. Online gameplay is never executed.
local UILibrary=(function()
-- Anime Origin UI library. Rendering only; gameplay stays in cardorrigin.lua.
local Library={Version=1}
function Library.Create(ctx)
local profile=ctx.profile
local repaintControls=function() end
local playerGui=ctx.playerGui
local state=ctx.state
if type(state.__animeUiDestroy)=='function' then state.__animeUiDestroy() end
local flags=ctx.flags
local cfg=ctx.cfg
local Workspace=ctx.Workspace
local env=ctx.env
local UIS=ctx.UIS
local GuiService=ctx.GuiService
local rift=ctx.rift
local boss=ctx.boss
local raid=ctx.raid
local siege=ctx.siege
local reconnect=ctx.reconnect
local handoff=ctx.handoff
local setFlag=ctx.setFlag
local applyFlags=ctx.applyFlags
local requestReconnect=ctx.requestReconnect
local loadIndex=ctx.loadIndex
local saveProfile=ctx.saveProfile
local loadProfile=ctx.loadProfile
local deleteProfile=ctx.deleteProfile
local setAutoProfile=ctx.setAutoProfile
local markCurrentForNextExecute=ctx.markCurrentForNextExecute
local saveAppearance=ctx.saveAppearance or function() end
local lifecycle={alive=true,connections={},tweens=setmetatable({}, {__mode='k'})}
local TweenService=ctx.TweenService
if not TweenService then pcall(function() TweenService=game:GetService('TweenService') end) end
local function trackUI(connection)
    lifecycle.connections[connection]=true
    state.connections=state.connections or {}
    state.connections[#state.connections+1]=connection
    return connection
end
local function disconnectUI(connection)
    if not connection then return end
    pcall(function() connection:Disconnect() end)
    lifecycle.connections[connection]=nil
    for index=#(state.connections or {}),1,-1 do
        if state.connections[index]==connection then table.remove(state.connections,index) end
    end
end
local function animate(obj,properties,duration)
    if not lifecycle.alive or not obj.Parent then return end
    local previous=lifecycle.tweens[obj]
    if previous then previous:Cancel() end
    if not TweenService or type(TweenService.Create)~='function' then for key,value in pairs(properties) do obj[key]=value end;return end
    local tween=TweenService:Create(obj,TweenInfo.new(duration or .16,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),properties)
    lifecycle.tweens[obj]=tween
    local connection
    connection=tween.Completed:Connect(function()
        connection:Disconnect()
        if lifecycle.tweens[obj]==tween then lifecycle.tweens[obj]=nil end
    end)
    tween:Play()
end
local window={width=805,height=565,x=.5,y=.5,compact=false,minimized=false,visible=true}
local applyResponsiveLayout=function() end
local cancelInteraction=function() end
local notify=function() end
local tooltip=function() end
local responsiveRows={}
local themes={
    Light={bg='F2F5FC',side='E7EDF8',panel='FFFFFF',row='EAF0FA',text='14213A',muted='526781',accent='4264D9',line='D1DBED',selected='DDE8FF',selectedText='173C85',mint='087B72',gold='986014',rose='B33764',violet='7045BC'},
    Midnight={bg='0B0D13',side='10121B',panel='171B28',row='202638',text='F0F4FF',muted='99A9C8',accent='6D8BFF',line='303B58',selected='28476B',selectedText='D9F4FF',mint='62DCC1',gold='F3C276',rose='F28FB4',violet='BAA0FF'},
    Ocean={bg='080F16',side='0C1822',panel='102635',row='17394B',text='ECFAFF',muted='8EBACD',accent='36DBCE',line='255166',selected='164C56',selectedText='CFFFF6',mint='5CE1C2',gold='F4CC84',rose='FF9EBD',violet='B5A5FF'},
    Violet={bg='171322',side='20192E',panel='2B213C',row='392C50',text='F6EFFF',muted='B8A8D4',accent='BC8AFF',line='534267',selected='503D78',selectedText='F4E8FF',mint='70E2CC',gold='F2CA83',rose='FFA0C1',violet='C7A8FF'},
    Emerald={bg='101C18',side='152B24',panel='1C372D',row='29463A',text='EFFFF4',muted='A0C8B0',accent='60D8A8',line='3E6454',selected='235545',selectedText='D2FFEC',mint='79E8BD',gold='F4CE86',rose='FCA3C0',violet='B7ACFF'},
    Rose={bg='23171C',side='311D27',panel='3E2633',row='503442',text='FFEFF4',muted='D9A9BC',accent='FF8FB2',line='704859',selected='64364E',selectedText='FFE2EE',mint='7AE5CE',gold='F5CF92',rose='FFABCD',violet='C8ADFF'},
}
-- Keep theme accents while using the same clear, neutral surface hierarchy.
for name,palette in pairs(themes)do
    if name~='Light'then
        palette.bg='101014';palette.side='15151B';palette.panel='1B1B23';palette.row='24242F'
        palette.line='41414F';palette.text='F4F4F8';palette.muted='B0B0C0'
        palette.selected='30303E';palette.selectedText='FFFFFF'
    end
end
local function rgb(hex)
    return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
end
local themeColors={}
local skinned=setmetatable({}, {__mode='k'})
local surfaces=setmetatable({}, {__mode='k'})
local transparency=-1
local updateTransparencyLabel=function() end
local function transparencyValue()
    local value=tonumber(flags.AO_UI_Transparency) or 15
    if value~=value then value=15 end
    return math.clamp(value,0,65)/100
end
local function applyTransparency()
    local value=transparencyValue()
    if value==transparency then return end
    transparency=value
    for obj,base in pairs(surfaces) do
        if obj.Parent then obj.BackgroundTransparency=base+(1-base)*value end
    end
    updateTransparencyLabel(value)
end
local function color(role)
    if role=='carry' then return rgb(flags.AO_UI_Theme=='Light' and '9B6500' or 'FFD479') end
    if role=='support' then return rgb(flags.AO_UI_Theme=='Light' and '087B72' or '6AE3CC') end
    return themeColors[role] or Color3.fromRGB(255,255,255)
end
local function skin(obj,property,role)
    skinned[obj]=skinned[obj] or {}
    skinned[obj][property]=role
    obj[property]=color(role)
    return obj
end
local function make(class,parent,props)
    local obj=Instance.new(class)
    for key,value in pairs(props or {}) do obj[key]=value end
    obj.Parent=parent
    if obj:IsA('GuiObject') then obj.Selectable=false end
    if obj:IsA('GuiObject') and obj.BackgroundTransparency<1 then
        local base=obj.BackgroundTransparency
        surfaces[obj]=base
        obj.BackgroundTransparency=base+(1-base)*transparencyValue()
    end
    return obj
end
local function corner(obj,size)
    make('UICorner',obj,{CornerRadius=UDim.new(0,size or 9)})
end
local function stroke(obj)
    local s=make('UIStroke',obj,{Thickness=1,Transparency=0.65})
    skin(s,'Color','line')
end
local textGradients=setmetatable({}, {__mode='k'})
local function gradientText(label,bright)
    if skinned[label] then skinned[label].TextColor3=nil end
    label.TextColor3=Color3.fromRGB(255,255,255)
    local gradient=label:FindFirstChild('OriginTextGradient')
    if not gradient then gradient=make('UIGradient',label,{Name='OriginTextGradient',Rotation=0}) end
    local palette=themes[flags.AO_UI_Theme] or themes.Midnight
    local accent=rgb(palette.accent);local ink=rgb(palette.text);local mint=rgb(palette.mint)
    local tones={'violet','rose','gold','accent'}
    local sum=0;for i=1,#label.Text do sum=sum+label.Text:byte(i) end
    accent=rgb(palette[tones[sum%4+1]])
    local light=flags.AO_UI_Theme=='Light'
    if bright and light then
        local white=Color3.fromRGB(255,255,255)
        accent=accent:Lerp(white,.5);ink=white;mint=mint:Lerp(white,.55)
    end
    gradient.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,accent:Lerp(ink,light and not bright and .15 or .3)),
        ColorSequenceKeypoint.new(.5,accent:Lerp(ink,.55)),
        ColorSequenceKeypoint.new(1,mint),
    })
    textGradients[label]={bright=bright}
end

local function newText(parent,label,size,bold)
    local l=make('TextLabel',parent,{
        BackgroundTransparency=1,Text=tostring(label),
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=bold and ((size or 14)>=22 and 24 or ((size or 14)>=16 and 18 or 14)) or 13,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0,
    })
    skin(l,'TextColor3',bold and 'text' or 'muted')
    if bold and (size or 13)>=16 then gradientText(l) end
    return l
end
local function uiButton(parent,caption,size)
    local b=make('TextButton',parent,{
        Text=caption,Size=size or UDim2.fromOffset(135,32),
        BackgroundTransparency=0,BorderSizePixel=0,
        Font=Enum.Font.GothamMedium,TextSize=14,AutoButtonColor=true,
        TextTruncate=Enum.TextTruncate.AtEnd,
    })
    corner(b,10)
    skin(b,'BackgroundColor3','row')
    skin(b,'TextColor3','text')
    local outline=make('UIStroke',b,{Thickness=1,Transparency=1})
    skin(outline,'Color','accent')
    b.MouseEnter:Connect(function() animate(outline,{Transparency=.45},.12) end)
    b.MouseLeave:Connect(function() animate(outline,{Transparency=1},.16) end)
    b.MouseButton1Down:Connect(function() animate(outline,{Transparency=.1},.07) end)
    b.MouseButton1Up:Connect(function() animate(outline,{Transparency=.45},.1) end)
    return b
end

local root=make('ScreenGui',playerGui,{
    Name='AnimeDuelScript',ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9900,
})
state.gui=root
local main=make('CanvasGroup',root,{
    Name='Window',GroupTransparency=0,Active=false,
    Size=UDim2.fromOffset(805,565),Position=UDim2.new(.5,-402,.5,-282),
    BorderSizePixel=0,BackgroundTransparency=0,
})
local shadow=make('Frame',root,{Name='WindowShadow',BorderSizePixel=0,Active=false,
    BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=.78,ZIndex=1})
corner(shadow,20)
main.ZIndex=2
corner(main,16)
skin(main,'BackgroundColor3','bg')
stroke(main)
local accentLine=make('Frame',main,{
    Position=UDim2.fromOffset(18,0),Size=UDim2.new(1,-36,0,2),BorderSizePixel=0,
})
skin(accentLine,'BackgroundColor3','accent')
accentLine.Size=UDim2.new(1,-36,0,3)
make('UIGradient',accentLine,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(112,93,255)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(62,159,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(46,229,199))})})
local scale=make('UIScale',main,{Scale=1})
local function viewport()
    local camera=Workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local function readGeometry()
    local function number(key,fallback,low,high)
        local value=tonumber(flags[key])
        if not value or value~=value or value==math.huge or value==-math.huge then return fallback end
        return math.clamp(value,low,high)
    end
    window.width=number('AO_UI_WindowW',805,600,1200)
    window.height=number('AO_UI_WindowH',565,420,1000)
    window.x=number('AO_UI_WindowX',.5,0,1)
    window.y=number('AO_UI_WindowY',.5,0,1)
    if tonumber(flags.AO_UI_WindowX)==-1 then window.x=.5 end
    if tonumber(flags.AO_UI_WindowY)==-1 then window.y=.5 end
end
local function sizeForDevice()
    local view=viewport()
    window.compact=view.X<680
    local width=window.compact and math.min(window.width,math.max(240,view.X-16)) or window.width
    local height=window.compact and math.min(window.height,math.max(260,view.Y-16)) or window.height
    window.shownWidth=width;window.shownHeight=height
    scale.Scale=math.min(1,math.max(.01,(view.X-16)/width),math.max(.01,(view.Y-16)/height))
    local actualHeight=window.minimized and 57 or height
    main.Size=UDim2.fromOffset(width,actualHeight)
    main.Position=UDim2.fromOffset(math.max(0,view.X-width*scale.Scale)*window.x,
        math.max(0,view.Y-actualHeight*scale.Scale)*window.y)
    shadow.Position=UDim2.fromOffset(main.Position.X.Offset+4,main.Position.Y.Offset+7)
    shadow.Size=UDim2.fromOffset(width*scale.Scale,actualHeight*scale.Scale)
    applyResponsiveLayout()
    if window.reflowOverlays then window.reflowOverlays() end
end
local function saveGeometry()
    flags.AO_UI_WindowW=window.width;flags.AO_UI_WindowH=window.height
    flags.AO_UI_WindowX=window.x;flags.AO_UI_WindowY=window.y
    saveAppearance()
end
local cameraConnection
local function bindCamera()
    disconnectUI(cameraConnection)
    local camera=Workspace.CurrentCamera
    cameraConnection=camera and trackUI(camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
        cancelInteraction();sizeForDevice()
    end)) or nil
    cancelInteraction();sizeForDevice()
end
readGeometry()
bindCamera()
trackUI(Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(bindCamera))
local header=make('Frame',main,{
    Size=UDim2.new(1,0,0,57),BackgroundTransparency=1,
})
local headerRule=make('Frame',header,{Position=UDim2.new(0,16,1,-1),Size=UDim2.new(1,-32,0,1),
    BackgroundTransparency=.5,BorderSizePixel=0})
skin(headerRule,'BackgroundColor3','line')
local iconTile=make('Frame',header,{
    Position=UDim2.fromOffset(16,12),Size=UDim2.fromOffset(34,34),BorderSizePixel=0,
})
corner(iconTile,10)
skin(iconTile,'BackgroundColor3','accent')
local gameIconImage=make('ImageLabel',iconTile,{Name='GameIcon',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=state.gameIcon or '',ScaleType=Enum.ScaleType.Crop})
corner(gameIconImage,10)
local bigTitle=newText(header,'ANIME DUEL',19,true)
bigTitle.Position=UDim2.fromOffset(62,10)
bigTitle.Size=UDim2.fromOffset(250,22)
local smallTitle=newText(header,'AQUA  /  NATIVE EDITION  /  v18',11,false)
smallTitle.Position=UDim2.fromOffset(63,32)
smallTitle.Size=UDim2.fromOffset(260,16)
local sessionBadge=newText(header,'● READY',11,true)
sessionBadge.Position=UDim2.new(1,-190,0,20)
sessionBadge.Size=UDim2.fromOffset(105,20)
local hide=uiButton(header,'—',UDim2.fromOffset(30,28))
hide.Position=UDim2.new(1,-77,0,14)
local dismiss=uiButton(header,'×',UDim2.fromOffset(30,28))
dismiss.Position=UDim2.new(1,-42,0,14)

local sidebar=make('ScrollingFrame',main,{Name='Sidebar',
    CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=0,BackgroundTransparency=0,
    Position=UDim2.fromOffset(0,57),Size=UDim2.new(0,174,1,-57),BorderSizePixel=0,
})
skin(sidebar,'BackgroundColor3','side')
local divider=make('Frame',main,{
    Position=UDim2.fromOffset(173,57),Size=UDim2.new(0,1,1,-57),BorderSizePixel=0,
})
skin(divider,'BackgroundColor3','line')
local navLayout=make('UIListLayout',sidebar,{
    Padding=UDim.new(0,8),FillDirection=Enum.FillDirection.Vertical,
    HorizontalAlignment=Enum.HorizontalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder,
})
local navPadding=make('UIPadding',sidebar,{PaddingTop=UDim.new(0,22)})
local body=make('Frame',main,{
    Position=UDim2.fromOffset(175,57),Size=UDim2.new(1,-175,1,-57),
    BackgroundTransparency=1,ClipsDescendants=true,
})
local selectedTab='Monitor'
local navButtons={}
local tabPages={}
local tabNames={'Monitor','Draft','Climb','Boss','Dungeon','Config','Settings'}
for i,name in ipairs(tabNames) do
    local tab=uiButton(sidebar,name,UDim2.new(1,-20,0,39))
    tab.Name='Nav'..name;tab.TextSize=15;tab.Font=Enum.Font.GothamMedium
    local marker=make('Frame',tab,{Name='SelectedMarker',Position=UDim2.new(0,0,.2,0),Size=UDim2.new(0,3,.6,0),BorderSizePixel=0,Visible=false})
    corner(marker,2);skin(marker,'BackgroundColor3','accent')
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
        smallTitle.Text='AQUA  /  NATIVE EDITION  /  v18'
        for title,p in pairs(tabPages) do p.Visible=(title==name) end
        page.Position=UDim2.fromOffset(0,9)
        animate(page,{Position=UDim2.fromOffset(0,0)},.18)
        repaintControls()
    end)
end
local widgets={}
local statusLabels={}
local orderCounter=0
local dungeonUI={groups={},buttons={},active='Overview',current=nil}
local function contentParent(tab)
    return tab=='Dungeon' and dungeonUI.current or tabPages[tab]
end
local function section(tab,label)
    orderCounter=orderCounter+1
    local t=newText(contentParent(tab),string.upper(label),15,true)
    t.Size=UDim2.new(1,0,0,36)
    gradientText(t)
    t.LayoutOrder=orderCounter
    t.TextSize=14
    t.TextTruncate=Enum.TextTruncate.None
    return t
end
local function row(tab,label)
    orderCounter=orderCounter+1
    local parent=contentParent(tab)
    local r=make('Frame',parent,{
        Size=UDim2.new(1,-2,0,49),BorderSizePixel=0,
        LayoutOrder=orderCounter,
    })
    corner(r,10)
    skin(r,'BackgroundColor3','panel')
    -- Flat neutral rows keep small text crisp.
    stroke(r)
    local nameLabel=newText(r,label,13,true)
    nameLabel.Position=UDim2.fromOffset(14,0)
    nameLabel.Size=UDim2.new(1,-221,1,0)
    responsiveRows[r]={label=nameLabel,kind='row'}
    return r
end
local function addStatus(tab,label,initial)
    local r=row(tab,label)
    r.Size=UDim2.new(1,-2,0,88)
    local heading=responsiveRows[r].label
    heading.Position=UDim2.fromOffset(16,10);heading.Size=UDim2.new(1,-32,0,19)
    local accent=make('Frame',r,{Position=UDim2.fromOffset(0,14),Size=UDim2.new(0,3,1,-28),BorderSizePixel=0})
    corner(accent,2);skin(accent,'BackgroundColor3','accent')
    local s=newText(r,initial or '--',13,false)
    s.Position=UDim2.fromOffset(16,35);s.Size=UDim2.new(1,-32,0,43)
    s.TextXAlignment=Enum.TextXAlignment.Left;s.TextYAlignment=Enum.TextYAlignment.Top
    s.TextWrapped=true;s.TextTruncate=Enum.TextTruncate.None
    skin(s,'TextColor3','text')
    tooltip(s,function() return s.Text end)
    statusLabels[label]=s
    responsiveRows[r].kind='status';responsiveRows[r].value=s
    return s
end
local function addToggle(tab,label,key)
    local r=row(tab,label)
    local b=uiButton(r,'OFF',UDim2.fromOffset(94,31))
    b.Position=UDim2.new(1,-109,.5,-15)
    b.MouseButton1Click:Connect(function() setFlag(key,not flags[key]) end)
    widgets[#widgets+1]=function()
        local on=flags[key]==true
        b.Text=on and 'ON' or 'OFF'
        animate(b,{BackgroundColor3=on and color('accent') or color('row'),
            TextColor3=on and color('bg') or color('text')},.16)
    end
    return b
end

local function modeActions(tab,mode,startCaption,stopCaption)
    orderCounter=orderCounter+1
    local bar=make('Frame',contentParent(tab),{Name=mode..'ActionBar',LayoutOrder=orderCounter,BackgroundTransparency=1,Size=UDim2.new(1,-2,0,49)})
    local start=uiButton(bar,startCaption,UDim2.new(.64,-4,1,0));start.Position=UDim2.fromOffset(0,0)
    skin(start,'BackgroundColor3','accent');skin(start,'TextColor3','bg')
    local stop=uiButton(bar,stopCaption,UDim2.new(.36,-4,1,0));stop.Position=UDim2.new(.64,4,0,0)
    skin(stop,'TextColor3','rose')
    trackUI(start.MouseButton1Click:Connect(function()ctx.app.start(mode)end))
    trackUI(stop.MouseButton1Click:Connect(function()ctx.app.stop(mode)end))
end

local menuDismiss=make('TextButton',root,{
    Name='DropdownDismiss',Visible=false,Size=UDim2.fromScale(1,1),
    Position=UDim2.fromScale(0,0),Text='',AutoButtonColor=false,
    BackgroundTransparency=1,BorderSizePixel=0,Active=true,ZIndex=149,
})
local menu=make('Frame',root,{
    Name='DropdownMenu',Visible=false,Size=UDim2.fromOffset(184,0),BorderSizePixel=0,
    BackgroundTransparency=0,ZIndex=150,
})
corner(menu,10)
skin(menu,'BackgroundColor3','side')
stroke(menu)
local menuConnections={}
local menuSearch=make('TextBox',menu,{Name='DropdownSearch',Position=UDim2.fromOffset(8,8),
    Size=UDim2.new(1,-96,0,36),Text='',PlaceholderText='Search targets or maps…',ClearTextOnFocus=false,
    Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0,ZIndex=152})
corner(menuSearch,8);skin(menuSearch,'BackgroundColor3','row');skin(menuSearch,'TextColor3','text')
skin(menuSearch,'PlaceholderColor3','muted')
local menuList=make('ScrollingFrame',menu,{Name='DropdownOptions',Position=UDim2.fromOffset(6,50),
    Size=UDim2.new(1,-12,1,-56),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=151,
    CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3})
skin(menuList,'ScrollBarImageColor3','accent')
make('UIListLayout',menuList,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local menuData=nil
local function releaseOwnFocus()
    pcall(function()
        local focused=UIS:GetFocusedTextBox()
        if focused and focused:IsDescendantOf(root) then focused:ReleaseFocus() end
    end)
end
local function hideMenu()
    menu.Visible=false;menuDismiss.Visible=false;menuData=nil
    releaseOwnFocus()
    for _,connection in ipairs(menuConnections) do connection:Disconnect() end
    menuConnections={}
    for _,child in ipairs(menuList:GetChildren()) do
        if child:IsA('GuiButton') or child:IsA('TextLabel') then child:Destroy() end
    end
end
do
    menuDismiss.Activated:Connect(hideMenu)
    local close=uiButton(menu,'Close',UDim2.fromOffset(72,36))
    close.Name='CloseDropdown';close.Position=UDim2.new(1,-80,0,8);close.ZIndex=153
    close.Activated:Connect(hideMenu)
end
local function paintOption(option,label,checked)
    option.Text=label
    skin(option,'BackgroundColor3',checked and 'selected' or 'row')
    skin(option,'TextColor3',checked and 'selectedText' or 'text')
end
local function renderMenuOptions()
    if not menuData then return end
    for _,connection in ipairs(menuConnections) do connection:Disconnect() end
    menuConnections={}
    for _,child in ipairs(menuList:GetChildren()) do
        if child:IsA('GuiButton') or child:IsA('TextLabel') then child:Destroy() end
    end
    local scrollBefore=menuList.CanvasPosition
    local query=tostring(menuSearch.Text):lower()
    local count=0
    for index,label in ipairs(menuData.options) do
        if tostring(label):lower():find(query,1,true) then
            count=count+1
            local selected=menuData.multi and menuData.selected and menuData.selected()[label]
            local caption=tostring(label)
            local choice=uiButton(menuList,caption,UDim2.new(1,-4,0,38))
            choice.LayoutOrder=index;choice.ZIndex=152;choice:SetAttribute('ChoiceLabel',tostring(label))
            choice.TextXAlignment=Enum.TextXAlignment.Left
            make('UIPadding',choice,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
            if menuData.multi then paintOption(choice,tostring(label),selected) end
            local callback=menuData.choose
            local indexValue,labelValue=index,label
            menuConnections[#menuConnections+1]=choice.Activated:Connect(function()
                local data=menuData
                if data and data.multi then
                    callback(indexValue,labelValue)
                    for _,option in ipairs(menuList:GetChildren()) do
                        if option:IsA('TextButton') then
                            local label=option:GetAttribute('ChoiceLabel')
                            if label then
                                local checked=data.selected()[label]
                                paintOption(option,label,checked)
                            end
                        end
                    end
                else hideMenu();callback(indexValue,labelValue) end
            end)
        end
    end
    if count==0 then
        local empty=newText(menuList,'No matching options',12,false)
        empty.Size=UDim2.new(1,-8,0,38);empty.ZIndex=152
    end
    menuList.CanvasPosition=scrollBefore
end
menuSearch:GetPropertyChangedSignal('Text'):Connect(function() menuList.CanvasPosition=Vector2.new(0,0);renderMenuOptions() end)
local function openMenu(anchor,options,choose)
    hideMenu()
    local view=viewport()
    local width=math.min(420,view.X-24)
    local height=math.min(math.max(110,#options*43+60),420,view.Y-24)
    local position=anchor.AbsolutePosition
    local top=position.Y+anchor.AbsoluteSize.Y+6
    if top+height>view.Y-8 then top=position.Y-height-6 end
    menu.Size=UDim2.fromOffset(width,height)
    menu.Position=UDim2.fromOffset(math.clamp(position.X,8,math.max(8,view.X-width-8)),
        math.clamp(top,8,math.max(8,view.Y-height-8)))
    menuList.CanvasPosition=Vector2.new(0,0)
    menuSearch.Text=''
    menuData={options=options,choose=choose,anchor=anchor}
    renderMenuOptions()
    menuDismiss.Visible=true;menu.Visible=true
    local target=menu.Size
    menu.Size=UDim2.fromOffset(width,math.max(72,height-12))
    animate(menu,{Size=target},.14)
end
local function addDropdown(tab,label,key,choices,indexed)
    local r=row(tab,label)
    local b=uiButton(r,'--  ▾',UDim2.fromOffset(180,31))
    b.Position=UDim2.new(1,-195,.5,-15)
    b.Activated:Connect(function()
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
    corner(box,10)
    skin(box,'BackgroundColor3','row')
    skin(box,'TextColor3','text')
    skin(box,'PlaceholderColor3','muted')
    box.FocusLost:Connect(function() if lifecycle.alive then setFlag(key,box.Text) end end)
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
    local actionRole=({START='mint',STOP='rose',['START DRAFT']='mint',['STOP DRAFT']='rose',['START CLIMB']='mint',['STOP CLIMB']='rose',['START BOSS']='mint',['STOP BOSS']='rose',SAVE='mint',LOAD='violet',DELETE='rose',PREVIEW='gold',['SET AUTO LOAD']='gold'})[caption]
    if actionRole then
        skin(b,'BackgroundColor3','selected')
        skin(b,'TextColor3',actionRole)
        local edge=make('UIStroke',b,{Thickness=1,Transparency=.5})
        skin(edge,'Color',actionRole)
    end
    return b
end
local paintedTheme=nil
local paintedTab=nil
local paintedFlags={}
local function paintTheme()
    local theme=themes[flags.AO_UI_Theme] and flags.AO_UI_Theme or 'Midnight'
    if theme==paintedTheme then return false end
    paintedTheme=theme
    for role,hex in pairs(themes[theme]) do themeColors[role]=rgb(hex) end
    for label,entry in pairs(textGradients) do if label.Parent then gradientText(label,entry.bright) end end
    for obj,properties in pairs(skinned) do
        local tween=lifecycle.tweens[obj]
        if tween then tween:Cancel();lifecycle.tweens[obj]=nil end
        if obj.Parent then
            for property,role in pairs(properties) do obj[property]=color(role) end
        end
    end
    return true
end
repaintControls=function()
    if not lifecycle.alive then return end
    local themeChanged=paintTheme()
    local dirty=themeChanged
    for key,value in pairs(flags) do
        if key~='AO_UI_Transparency' and paintedFlags[key]~=value then dirty=true end
        paintedFlags[key]=value
    end
    if themeChanged or paintedTab~=selectedTab then
        paintedTab=selectedTab
        for title,b in pairs(navButtons) do
            b.BackgroundColor3=(title==selectedTab) and color('selected') or color('panel')
            b.TextColor3=(title==selectedTab) and color('selectedText') or color('text')
            local marker=b:FindFirstChild('SelectedMarker');if marker then marker.Visible=title==selectedTab end
        end
    end
    local geometryChanged=false
    for _,key in ipairs({'AO_UI_WindowW','AO_UI_WindowH','AO_UI_WindowX','AO_UI_WindowY'}) do
        if window[key]~=flags[key] then geometryChanged=true;window[key]=flags[key] end
    end
    if geometryChanged then readGeometry();cancelInteraction();sizeForDevice() end
    applyTransparency()
    if dirty then for _,fn in ipairs(widgets) do fn() end end
end

local delay=ctx.Delay or function(seconds,callback) task.delay(seconds,callback) end
local tooltipBox=make('TextLabel',root,{Name='Tooltip',Visible=false,Size=UDim2.fromOffset(240,54),
    BackgroundTransparency=.06,BorderSizePixel=0,ZIndex=220,TextWrapped=true,
    TextSize=12,Font=Enum.Font.Gotham,Text='',TextXAlignment=Enum.TextXAlignment.Left})
corner(tooltipBox,10);skin(tooltipBox,'BackgroundColor3','side');skin(tooltipBox,'TextColor3','text')
make('UIPadding',tooltipBox,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
tooltip=function(obj,text)
    local held=false
    local function show()
        if not lifecycle.alive or not root.Enabled or not obj.Parent then return end
        local view=viewport();local position=obj.AbsolutePosition
        tooltipBox.Text=type(text)=='function' and text() or text
        tooltipBox.Position=UDim2.fromOffset(math.clamp(position.X,6,math.max(6,view.X-246)),
            math.clamp(position.Y+obj.AbsoluteSize.Y+7,6,math.max(6,view.Y-60)))
        tooltipBox.Visible=true
    end
    obj.MouseEnter:Connect(show)
    obj.MouseLeave:Connect(function() tooltipBox.Visible=false end)
    obj.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch then
            held=true;delay(.5,function() if held then show() end end)
        end
    end)
    obj.InputEnded:Connect(function() held=false;tooltipBox.Visible=false end)
end
local toast={queue={},active=false,generation=0}
local toastBox=make('Frame',root,{Name='Toast',Visible=false,Size=UDim2.fromOffset(300,84),
    BorderSizePixel=0,ZIndex=210})
corner(toastBox,12);stroke(toastBox);skin(toastBox,'BackgroundColor3','side')
local toastBar=make('Frame',toastBox,{Size=UDim2.new(0,3,1,-20),Position=UDim2.fromOffset(0,10),BorderSizePixel=0,ZIndex=211})
local toastTitle=newText(toastBox,'',12,true);toastTitle.Position=UDim2.fromOffset(15,12)
toastTitle.Size=UDim2.new(1,-30,0,18);toastTitle.ZIndex=211
local toastMessage=newText(toastBox,'',12,false);toastMessage.Position=UDim2.fromOffset(15,34)
toastMessage.Size=UDim2.new(1,-30,0,40);toastMessage.TextWrapped=true;toastMessage.ZIndex=211
local function pumpToast()
    if not lifecycle.alive or toast.active or not root.Enabled or #toast.queue==0 then return end
    while #toast.queue>0 and os.clock()-(toast.queue[1].createdAt or os.clock())>6 do table.remove(toast.queue,1) end
    if #toast.queue==0 then return end
    local item=table.remove(toast.queue,1)
    toast.item=item
    toast.active=true;toast.generation=toast.generation+1
    local generation=toast.generation
    local tint={info='8BAFFF',success='4ACBA7',warning='E3B658',error='ED8193'}
    toastTitle.Text=string.upper(item.kind);toastBar.BackgroundColor3=rgb(tint[item.kind] or tint.info)
    toastMessage.Text=item.message
    local view=viewport();local width=math.min(320,view.X-24)
    toastBox.Size=UDim2.fromOffset(width,84)
    toastBox.Position=UDim2.fromOffset(view.X-width-12,view.Y+10);toastBox.Visible=true
    animate(toastBox,{Position=UDim2.fromOffset(view.X-width-12,view.Y-96)},.2)
    delay(item.duration,function()
        if not lifecycle.alive or generation~=toast.generation then return end
        animate(toastBox,{Position=UDim2.fromOffset(view.X-width-12,view.Y+10)},.16)
        delay(.17,function()
            if not lifecycle.alive or generation~=toast.generation then return end
            toastBox.Visible=false;toast.active=false;toast.item=nil;pumpToast()
        end)
    end)
end
notify=function(message,kind,duration)
    if not lifecycle.alive then return end
    if kind~='success' and kind~='warning' and kind~='error' then kind='info' end
    duration=tonumber(duration) or 3
    if duration~=duration then duration=3 end
    if #toast.queue>=8 then table.remove(toast.queue,1) end
    toast.queue[#toast.queue+1]={createdAt=os.clock(),message=tostring(message),kind=kind or 'info',
        duration=math.clamp(duration,1,10)}
    pumpToast()
end
window.reflowOverlays=function()
    local view=viewport()
    if menu.Visible then
        local width=math.min(menu.Size.X.Offset,view.X-16)
        local height=math.min(menu.Size.Y.Offset,view.Y-16)
        animate(menu,{Size=UDim2.fromOffset(width,height),Position=UDim2.fromOffset(
            math.clamp(menu.Position.X.Offset,8,math.max(8,view.X-width-8)),
            math.clamp(menu.Position.Y.Offset,8,math.max(8,view.Y-height-8)))},.1)
    end
    tooltipBox.Visible=false
end
local function suspendOverlays()
    hideMenu();tooltipBox.Visible=false
    toast.queue={}
    if toast.active then
        toast.item=nil
        toast.generation=toast.generation+1;toast.active=false;toastBox.Visible=false
    end
end

local function clearNotifications()
    toast.generation=toast.generation+1
    toast.queue={};toast.active=false;toast.item=nil
    toastBox.Visible=false
end
do
    local descriptions={Monitor='Everything in view. Every run under control.',Draft='Build a stronger team. Climb through the bosses.',Climb='Smart card choices for your next milestone.',Boss='Your targets. Their cooldowns. One control center.',Dungeon='Build your squad. Choose your route. Collect the rewards.',Config='Your setup, ready for the next session.',Settings='Make this workspace feel like yours.'}
    for _,tab in ipairs(tabNames) do
        local hero=make('Frame',tabPages[tab],{Name=tab..'Hero',LayoutOrder=-20,Size=UDim2.new(1,-2,0,110),BorderSizePixel=0})
        corner(hero,12);stroke(hero)
        hero.BackgroundColor3=Color3.fromRGB(255,255,255)
        make('UIGradient',hero,{Rotation=15,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(71,43,124)),ColorSequenceKeypoint.new(.6,Color3.fromRGB(26,88,124)),ColorSequenceKeypoint.new(1,Color3.fromRGB(20,111,101))})})
        local kicker=newText(hero,'A Q U A   /   A U T O M A T I O N',10,false)
        kicker.TextColor3=Color3.fromRGB(172,216,240);skinned[kicker]=nil
        kicker.Position=UDim2.fromOffset(18,12);kicker.Size=UDim2.new(1,-36,0,16)
        local title=newText(hero,tab=='Dungeon' and 'Dungeon expedition' or (tab=='Monitor' and 'Your command center' or tab),26,true)
        gradientText(title,true)
        title.Position=UDim2.fromOffset(18,33);title.Size=UDim2.new(1,-36,0,34)
        local subtitle=newText(hero,descriptions[tab],12,false)
        subtitle.TextColor3=Color3.fromRGB(187,213,235);skinned[subtitle]=nil
        subtitle.Position=UDim2.fromOffset(18,74);subtitle.Size=UDim2.new(1,-36,0,28);subtitle.TextWrapped=true
    end
end
section('Monitor','Live control center')
local draftStatus=addStatus('Monitor','Draft Run','Ready')
local climbStatus=addStatus('Monitor','Draft Climb','Ready')
local bossStatus=addStatus('Monitor','Story Boss','Ready')
local scoreStatus=addStatus('Monitor','Draft wins / losses / clears','0 / 0 / 0')
local requestStatus=addStatus('Monitor','Story start requests','0')
section('Draft','Auto Draft Run')
addToggle('Draft','Auto Draft','DraftRunning')
modeActions('Draft','draft','START DRAFT','STOP DRAFT')
local draftLive=addStatus('Draft','Status','Ready')
local draftRun=addStatus('Draft','Run / boss','--')
local draftRecovery=addStatus('Draft','Recovery','--')
local draftTeam=addStatus('Draft','Team','--')
section('Draft','Recovery settings')
addInput('Draft','Farm wins after loss','farm','3')
addInput('Draft','Hard wins after boss loss','bossFarm','4')
addInput('Draft','Action delay (seconds)','delay','0.8')
addInput('Draft','Fight timeout (seconds)','timeout','180')
section('Climb','Auto Draft Climb')
addToggle('Climb','Auto pick / restart','ClimbRunning')
modeActions('Climb','climb','START CLIMB','STOP CLIMB')
local climbLive=addStatus('Climb','Status','Ready')
local climbProgress=addStatus('Climb','Run / floor','--')
local climbTeam=addStatus('Climb','Team','--')
addStatus('Climb','Blocked at every border','Saiyan Prince / Atomic / Samurai Lost Man')
addStatus('Climb','Teen Saski priority','+50%')
addStatus('Climb','Other preferred cards','+25%')
local nativeHint=addStatus('Climb','Combat','Enable native Auto Climb in the game')
tooltip(nativeHint,'STOP CLIMB only stops this picker. The native game may continue advancing floors.')
section('Boss','Boss control center')
local selectedBosses
selectedBosses=addAction('Boss','Bosses','SELECT  ▾',function()
    if menu.Visible then hideMenu();return end
    local options={}
    for _,boss in ipairs(ctx.storyBosses) do options[#options+1]=boss.name..(boss.secret and ' [SECRET]' or '') end
    local function selected()
        local out={}
        for i,boss in ipairs(ctx.storyBosses) do if ctx.app.config['story_'..boss.key] then out[options[i]]=true end end
        return out
    end
    openMenu(selectedBosses,options,function(index)
        local key='story_'..ctx.storyBosses[index].key
        ctx.app.config[key]=not ctx.app.config[key]
        flags.BossSelectionRevision=(tonumber(flags.BossSelectionRevision) or 0)+1
        repaintControls()
    end)
    menuData.multi=true;menuData.selected=selected;renderMenuOptions()
end)
widgets[#widgets+1]=function()
    local count=0
    for _,boss in ipairs(ctx.storyBosses) do if ctx.app.config['story_'..boss.key] then count=count+1 end end
    selectedBosses.Text=count..' selected  ▾'
end
addDropdown('Boss','Difficulty','storyDifficulty',{'Easy','Medium','Hard','Nightmare'})
addToggle('Boss','Auto Start Fight','BossRunning')
-- Story Boss is controlled only by its Auto toggle.
local bossLive=addStatus('Boss','Status','Ready')
local bossSummary=addStatus('Boss','Selected targets','--')
addStatus('Boss','Attempt interval','1.5s / server cooldowns respected')
section('Boss','Learned server cooldowns')
local cooldownLabels={}
for _,boss in ipairs(ctx.storyBosses) do
    cooldownLabels[boss.id]=addStatus('Boss',boss.name..(boss.secret and ' [SECRET]' or ''),'--')
end
do
    local tabs={'Overview','Team','Cards','History','Settings'}
    local navigation=make('Frame',tabPages.Dungeon,{Name='DungeonNavigation',LayoutOrder=-10,Size=UDim2.new(1,-2,0,42),BackgroundTransparency=1})
    for i,name in ipairs(tabs) do
        local panel=make('Frame',tabPages.Dungeon,{Name='DungeonGroup'..name,LayoutOrder=i,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=name=='Overview'})
        make('UIListLayout',panel,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
        dungeonUI.groups[name]=panel
        local button=uiButton(navigation,name,UDim2.new(.2,-5,1,0));button.Name='DungeonNav'..name
        button.Position=UDim2.new((i-1)*.2,0,0,0);button.TextSize=13
        dungeonUI.buttons[name]=button
        trackUI(button.Activated:Connect(function()
            dungeonUI.active=name
            for key,group in pairs(dungeonUI.groups) do group.Visible=key==name end
            for key,control in pairs(dungeonUI.buttons) do skin(control,'BackgroundColor3',key==name and 'selected' or 'row') end
            tabPages.Dungeon.CanvasPosition=Vector2.new(0,0)
        end))
    end
    widgets[#widgets+1]=function()
        for key,button in pairs(dungeonUI.buttons) do skin(button,'BackgroundColor3',key==dungeonUI.active and 'selected' or 'row') end
    end
end
dungeonUI.current=dungeonUI.groups.Overview
section('Dungeon','Expedition control')
addToggle('Dungeon','Auto Dungeon','DungeonRunning')
-- Auto Dungeon is controlled only by its toggle.
local dungeonLive=addStatus('Dungeon','Status','Ready — Start requests the server directly')
local dungeonProgress=addStatus('Dungeon','Room / phase','--')
local dungeonHealth=addStatus('Dungeon','Alive / average HP','--')
dungeonUI.current=dungeonUI.groups.Settings
section('Dungeon','Route & difficulty')
addDropdown('Dungeon','Difficulty','dungeonDifficulty',{'Normal','Hard','Nightmare'})
local pathButton
pathButton=addAction('Dungeon','Path','Balanced  ▾',function()
    openMenu(pathButton,{'Balanced','Most Loot','Safest'},function(index)
        setFlag('dungeonPath',({'Balanced','Loot','Safe'})[index])
    end)
end)
widgets[#widgets+1]=function()pathButton.Text=({Balanced='Balanced',Loot='Most Loot',Safe='Safest'})[flags.dungeonPath]..'  ▾'end
addDropdown('Dungeon','Cash out at room','dungeonCashOut',{5,10,15,20})
do
    local app=ctx.app
    local picker={query='',border='All',sort='Power',page=1,active=1,revision=nil,tiles={},slots={}}
    dungeonUI.current=dungeonUI.groups.Cards
    local collectionStatus=addStatus('Dungeon','Collection','Loading your collection…')
    local function panel(name,height)
        orderCounter=orderCounter+1
        return make('Frame',contentParent('Dungeon'),{Name=name,LayoutOrder=orderCounter,Size=UDim2.new(1,-2,0,height),BackgroundTransparency=1,BorderSizePixel=0})
    end
    local function grid(parent,height)
        make('UIGridLayout',parent,{CellSize=UDim2.new(1/3,-6,0,height),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder})
    end
    local function tile(parent,name,index)
        local b=make('TextButton',parent,{Name=name,Text='',LayoutOrder=index,AutoButtonColor=false,BorderSizePixel=0})
        corner(b,10);skin(b,'BackgroundColor3','row')
        local ring=make('UIStroke',b,{Thickness=1,Color=Color3.fromRGB(110,120,145),Transparency=.15})
        local image=make('ImageLabel',b,{Name='CardArt',BackgroundTransparency=1,Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(42,56),ScaleType=Enum.ScaleType.Fit,Image=''})
        local title=newText(b,'',11,true);title.Name='CardName';title.Position=UDim2.new(0,55,0,8);title.Size=UDim2.new(1,-61,0,55);title.TextWrapped=true
        local detail=newText(b,'',10,false);detail.Name='CardDetail';detail.Position=UDim2.fromOffset(8,70);detail.Size=UDim2.new(1,-16,0,42);detail.TextWrapped=true
        skin(title,'TextColor3','text');skin(detail,'TextColor3','muted')
        return {button=b,image=image,title=title,detail=detail,ring=ring}
    end
    local function paintRing(t,border,selected)
        local colors={Basic=Color3.fromRGB(126,142,168),Grey=Color3.fromRGB(126,142,168),Gold=Color3.fromRGB(255,203,92),Rainbow=Color3.fromRGB(86,228,225),Secret=Color3.fromRGB(208,124,255)}
        t.ring.Color=colors[border] or colors.Basic;t.ring.Thickness=selected and 2 or 1
    end
    dungeonUI.current=dungeonUI.groups.Team
    section('Dungeon','01 / Main squad     02 / Reserves')
    local slotPanel=panel('DungeonTeamSlots',248);grid(slotPanel,120)
    local refreshPicker
    for i=1,6 do
        local index=i
        local t=tile(slotPanel,'DungeonSlot'..i,i);picker.slots[i]=t
        trackUI(t.button.Activated:Connect(function()picker.active=index;picker.revision=nil;refreshPicker()end))
    end
    addAction('Dungeon','Selected slot','CLEAR SLOT',function()
        app.setDungeonSlot(picker.active,nil);picker.revision=nil;refreshPicker()
    end)
    dungeonUI.current=dungeonUI.groups.Cards
    section('Dungeon','Your collection')
    addAction('Dungeon','Owned cards','REFRESH COLLECTION',function()app.refreshDungeonCollection()end)
    local searchRow=row('Dungeon','Find a card')
    local search=make('TextBox',searchRow,{Name='DungeonCardSearch',Text='',PlaceholderText='Search card name…',ClearTextOnFocus=false,
        Position=UDim2.new(1,-210,.5,-17),Size=UDim2.fromOffset(196,34),BorderSizePixel=0,Font=Enum.Font.Gotham,TextSize=12})
    corner(search,8);skin(search,'BackgroundColor3','row');skin(search,'TextColor3','text');skin(search,'PlaceholderColor3','muted')
    trackUI(search:GetPropertyChangedSignal('Text'):Connect(function()picker.query=search.Text;picker.page=1;picker.revision=nil;refreshPicker()end))
    local borderButton,sortButton
    borderButton=addAction('Dungeon','Border filter','All  ▾',function()
        openMenu(borderButton,{'All','Basic','Gold','Rainbow','Secret'},function(_,value)
            picker.border=value;picker.page=1;picker.revision=nil;refreshPicker()
        end)
    end)
    sortButton=addAction('Dungeon','Sort cards','Power  ▾',function()
        openMenu(sortButton,{'Power','Name','Quantity'},function(_,value)
            picker.sort=value;picker.page=1;picker.revision=nil;refreshPicker()
        end)
    end)
    local pageStatus=addStatus('Dungeon','Available cards','--')
    local listPanel=panel('DungeonOwnedCards',504);grid(listPanel,120)
    for i=1,12 do
        local t=tile(listPanel,'DungeonOwnedCard'..i,i);picker.tiles[i]=t
        trackUI(t.button.Activated:Connect(function()
            if not t.card then return end
            local slots=app.getDungeonSlots();local index=table.find(slots,t.card.id)
            if index then app.setDungeonSlot(index,nil);picker.active=index
            else
                local ok,reason=app.setDungeonSlot(picker.active,t.card.id)
                if not ok then notify(reason,'warning');return end
                slots=app.getDungeonSlots()
                for n,id in ipairs(slots) do if id=='' then picker.active=n;break end end
            end
            picker.revision=nil;refreshPicker()
        end))
    end
    addAction('Dungeon','Previous page','PREVIOUS',function()picker.page=math.max(1,picker.page-1);picker.revision=nil;refreshPicker()end)
    addAction('Dungeon','Next page','NEXT',function()picker.page=picker.page+1;picker.revision=nil;refreshPicker()end)
    refreshPicker=function()
        local c=app.dungeon.collection
        collectionStatus.Text=c.status
        local revision=c.revision..'/'..app.config.dungeonTeam..'/'..app.config.dungeonReserves..'/'..picker.query..'/'..picker.border..'/'..picker.sort..'/'..picker.page..'/'..picker.active
        if picker.revision==revision then return end
        picker.revision=revision
        local slots=app.getDungeonSlots()
        for i,t in ipairs(picker.slots) do
            local id=slots[i];local card=c.cards[id];local def=c.definitions[id]
            local name=card and card.name or (def and def.Name) or (id~='' and id or 'Empty')
            t.title.TextSize=13
            t.title.Text=name;t.image.Image=card and card.image or (def and def.Image) or ''
            t.detail.Text=(i<=4 and ('TEAM '..i) or ('RESERVE '..(i-4)))..(i==picker.active and ' · SELECTED' or '')..(id~='' and c.ready and not card and '\nNot owned' or '')
            paintRing(t,card and card.border or (def and def.Variant),i==picker.active)
            skin(t.button,'BackgroundColor3',i==picker.active and 'selected' or 'row')
        end
        local cards=app.listDungeonCards(picker.query,picker.border,picker.sort)
        local pages=math.max(1,math.ceil(#cards/12));picker.page=math.clamp(picker.page,1,pages)
        borderButton.Text=picker.border..'  ▾';sortButton.Text=picker.sort..'  ▾'
        pageStatus.Text=#cards..' cards · page '..picker.page..' / '..pages..'\nClick a card to equip; click it again to remove.'
        local visible=0
        for i,t in ipairs(picker.tiles) do
            local card=cards[(picker.page-1)*12+i];t.card=card;t.button.Visible=card~=nil
            if card then
                visible=visible+1;local slot=table.find(slots,card.id)
                t.title.Text=card.name;t.image.Image=card.image
                t.detail.Text=card.border..' · x'..card.count..'\n'..(slot and (slot<=4 and 'TEAM '..slot or 'RESERVE '..(slot-4)) or ('DMG '..card.damage..' · HP '..card.health))
                paintRing(t,card.border,slot~=nil)
                skin(t.button,'BackgroundColor3',slot and 'selected' or 'row')
            end
        end
        listPanel.Visible=visible>0;listPanel.Size=UDim2.new(1,-2,0,math.ceil(visible/3)*128)
    end
    widgets[#widgets+1]=refreshPicker
    refreshPicker()
end

dungeonUI.current=dungeonUI.groups.Settings
section('Dungeon','Automation & priorities')
addToggle('Dungeon','Pause autos for native Rift','pauseForRift')
addToggle('Dungeon','Prioritize ready Story Boss','sequenceBossDungeon')
local priorityLive=addStatus('Dungeon','Battle priority','Ready')
addStatus('Dungeon','Checkpoint policy','Withdraw when in trouble; Safest also banks early when injured')
addStatus('Dungeon','Movement','No automatic teleport between rooms. Enter still returns you to the run.')
dungeonUI.current=dungeonUI.groups.History
section('Dungeon','Last 10 runs · time tracked this session')
local dungeonHistory={}
for i=1,10 do dungeonHistory[i]=addStatus('Dungeon','Run #'..i,i==1 and 'No completed runs yet' or '--') end
section('Config','Profiles')
local nameBox=addInput('Config','Profile name','ProfileName','Default')
local savedDrop
savedDrop=addAction('Config','Saved profiles','SELECT  ▾',function()
    openMenu(savedDrop,profile.storedNames,function(_,name)
        flags.ProfileName=name;repaintControls()
    end)
end)
addAction('Config','Save profile','SAVE',function() ctx.saveProfile(flags.ProfileName) end)
addAction('Config','Load profile','LOAD',function() ctx.loadProfile(flags.ProfileName) end)
addAction('Config','Delete profile','DELETE',function() ctx.deleteProfile(flags.ProfileName) end)
addAction('Config','Load on next execute','SET AUTO LOAD',function() ctx.setAutoProfile(flags.ProfileName) end)
addAction('Config','Disable Auto Load','CLEAR AUTO LOAD',ctx.clearAutoProfile)
local configStatus=addStatus('Config','Storage','Ready')
local configAuto=addStatus('Config','Auto Load','None')
local configModes=addStatus('Config','Saved mode preferences','--')
section('Settings','AFK protection')
addToggle('Settings','Anti-AFK','antiAfk')
local afkStatus=addStatus('Settings','Anti-AFK status','Ready')
section('Settings','Startup and connection')
addToggle('Settings','Auto Start saved modes','autoStart')
addToggle('Settings','Auto reconnect','autoReconnect')
addToggle('Settings','Auto execute after hop','autoExecuteOnHop')
local hopStatus=addStatus('Settings','Teleport execution','Ready')
addAction('Settings','Rejoin server','REJOIN',ctx.rejoinServer)
local reconnectStatus=addStatus('Settings','Connection','Monitoring')
section('Settings','Appearance')
addDropdown('Settings','Theme','AO_UI_Theme',{'Midnight','Ocean','Violet','Emerald','Rose','Light'})
local transparencyRow=row('Settings','Transparency')
responsiveRows[transparencyRow].kind='transparency'
local transparencyText=newText(transparencyRow,'15%',12,true)
transparencyText.Position=UDim2.new(1,-60,0,0)
transparencyText.Size=UDim2.new(0,46,1,0)
transparencyText.TextXAlignment=Enum.TextXAlignment.Right
local slider=make('TextButton',transparencyRow,{
    Name='TransparencySlider',Text='',AutoButtonColor=false,
    BackgroundTransparency=1,Position=UDim2.new(1,-245,.5,-16),
    Size=UDim2.fromOffset(170,32),BorderSizePixel=0,
})
local track=make('Frame',slider,{
    Position=UDim2.new(0,0,.5,-3),Size=UDim2.new(1,0,0,6),BorderSizePixel=0,
})
corner(track,3);skin(track,'BackgroundColor3','row')
local fill=make('Frame',track,{Size=UDim2.new(15/65,0,1,0),BorderSizePixel=0})
corner(fill,3);fill.BackgroundColor3=Color3.fromRGB(255,255,255)
make('UIGradient',fill,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(177,126,245)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(98,180,252)),ColorSequenceKeypoint.new(1,Color3.fromRGB(77,217,181))})})
local knob=make('Frame',slider,{
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(15/65,0,.5,0),
    Size=UDim2.fromOffset(14,14),BorderSizePixel=0,
})
corner(knob,7);skin(knob,'BackgroundColor3','accent')
updateTransparencyLabel=function(value)
    local ratio=value/.65
    transparencyText.Text=tostring(math.floor(value*100+.5))..'%'
    fill.Size=UDim2.new(ratio,0,1,0)
    knob.Position=UDim2.new(ratio,0,.5,0)
end
local sliderInput=nil
local function adjustTransparency(x)
    if slider.AbsoluteSize.X<=0 then return end
    local ratio=math.clamp((x-slider.AbsolutePosition.X)/slider.AbsoluteSize.X,0,1)
    local value=math.floor(ratio*65+.5)
    if value~=flags.AO_UI_Transparency then setFlag('AO_UI_Transparency',value) end
end
slider.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
        sliderInput=input
        adjustTransparency(input.Position.X)
    end
end)

addAction('Settings','Unload script and UI','UNLOAD',function() state.stop() end)

-- Responsive window interaction: all coordinates are clamped to the viewport.
local dragging=false
local resizing=false
local originMouse,originPosition,dragTouch
local resizeOrigin,resizeWidth,resizeHeight
local resizeHandle=uiButton(main,'◢',UDim2.fromOffset(30,30))
resizeHandle.Name='ResizeHandle';resizeHandle.Position=UDim2.new(1,-32,1,-32)
resizeHandle.ZIndex=20;resizeHandle.BackgroundTransparency=1
surfaces[resizeHandle]=nil
local function pointer(input)
    return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
end
cancelInteraction=function()
    dragging=false;resizing=false;dragTouch=nil;sliderInput=nil
end
local function movedPosition(x,y)
    local view=viewport()
    local width=main.Size.X.Offset*scale.Scale
    local height=main.Size.Y.Offset*scale.Scale
    local maxX=math.max(0,view.X-width);local maxY=math.max(0,view.Y-height)
    window.x=maxX>0 and math.clamp(x,0,maxX)/maxX or 0
    window.y=maxY>0 and math.clamp(y,0,maxY)/maxY or 0
    sizeForDevice()
end
header.InputBegan:Connect(function(input)
    if pointer(input) then
        dragging=true;resizing=false
        dragTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
        originMouse=input.Position;originPosition=main.Position
    end
end)
resizeHandle.InputBegan:Connect(function(input)
    if pointer(input) and not window.minimized then
        resizing=true;dragging=false
        dragTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
        resizeOrigin=input.Position;resizeWidth=window.width;resizeHeight=window.height
    end
end)
local dragMove=trackUI(UIS.InputChanged:Connect(function(input)
    if not root.Enabled then cancelInteraction();return end
    if sliderInput and (input==sliderInput or input.UserInputType==Enum.UserInputType.MouseMovement) then
        adjustTransparency(input.Position.X)
    elseif (dragging or resizing) and (input==dragTouch or input.UserInputType==Enum.UserInputType.MouseMovement) then
        if dragging then
            movedPosition(originPosition.X.Offset+input.Position.X-originMouse.X,
                originPosition.Y.Offset+input.Position.Y-originMouse.Y)
        else
            window.width=math.clamp(resizeWidth+(input.Position.X-resizeOrigin.X)/scale.Scale,600,1200)
            window.height=math.clamp(resizeHeight+(input.Position.Y-resizeOrigin.Y)/scale.Scale,420,1000)
            sizeForDevice()
        end
    end
end))
local dragEnd=trackUI(UIS.InputEnded:Connect(function(input)
    if input==sliderInput then sliderInput=nil end
    if input==dragTouch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        if (dragging or resizing) and not window.minimized then saveGeometry() end
        dragging=false;resizing=false;dragTouch=nil
    end
end))
local function setWindowVisible(show)
    window.visibilityRevision=(window.visibilityRevision or 0)+1
    local token=window.visibilityRevision
    window.visible=show
    cancelInteraction();suspendOverlays();
    if show then
        root.Enabled=true;shadow.Visible=true;sizeForDevice()
        local target=main.Position
        main.GroupTransparency=1
        main.Position=UDim2.fromOffset(target.X.Offset,target.Y.Offset+12)
        animate(main,{GroupTransparency=0,Position=target},.18)
        pumpToast()
    else
        releaseOwnFocus()
        animate(main,{GroupTransparency=1},.15)
        delay(.16,function()
            if not lifecycle.alive or token~=window.visibilityRevision then return end
            root.Enabled=false;shadow.Visible=false;main.GroupTransparency=0
        end)
    end
end
local touchRoot=make('ScreenGui',playerGui,{
    Name='AnimeDuelScriptToggle',ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9901,Enabled=UIS.TouchEnabled==true,
})
local touchToggle=uiButton(touchRoot,'',UDim2.fromOffset(46,40))
touchToggle.Name='TouchWindowToggle'
local touchGameIcon=make('ImageLabel',touchToggle,{Name='GameIcon',BackgroundTransparency=1,Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),Image=state.gameIcon or '',ScaleType=Enum.ScaleType.Crop})
corner(touchGameIcon,8)
touchToggle.Position=UDim2.new(1,-54,0,54)
touchToggle.MouseButton1Click:Connect(function()
    if lifecycle.alive then setWindowVisible(not window.visible) end
end)
local hotkey=trackUI(UIS.InputBegan:Connect(function(input,used)
    if not used and input.KeyCode==Enum.KeyCode.RightShift and state.alive then
        setWindowVisible(not window.visible)
    elseif menu.Visible and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
        local point=input.Position
        local function contains(object)
            if not object then return false end
            local position,size=object.AbsolutePosition,object.AbsoluteSize
            return point.X>=position.X and point.Y>=position.Y and point.X<=position.X+size.X and point.Y<=position.Y+size.Y
        end
        -- The anchor's own Activated handler closes it; do not close then reopen on the same tap.
        if not contains(menu) and not contains(menuData and menuData.anchor) then hideMenu() end
    end
end))
trackUI(root:GetPropertyChangedSignal('Enabled'):Connect(function()
    if window.visible~=root.Enabled then
        window.visibilityRevision=(window.visibilityRevision or 0)+1
        window.visible=root.Enabled
        local tween=lifecycle.tweens[main]
        if tween then tween:Cancel();lifecycle.tweens[main]=nil end
        main.GroupTransparency=0
    end
    if not root.Enabled then cancelInteraction();suspendOverlays(); end
    shadow.Visible=root.Enabled
end))
hide.MouseButton1Click:Connect(function()
    cancelInteraction();suspendOverlays();
    local position=main.Position
    window.minimized=not window.minimized
    local height=window.minimized and 57 or window.shownHeight
    local view=viewport()
    window.y=math.clamp(position.Y.Offset/math.max(1,view.Y-height*scale.Scale),0,1)
    sizeForDevice()
    local target=main.Size
    main.Size=UDim2.fromOffset(window.shownWidth,window.minimized and height+12 or height-12)
    animate(main,{Size=target},.18)
    hide.Text=window.minimized and '▢' or '—'
end)
dismiss.MouseButton1Click:Connect(function() setWindowVisible(false) end)
tooltip(hide,'Minimize the window. Automation keeps running.')
tooltip(dismiss,'Hide this window. Press Right Shift to show it again.')
tooltip(resizeHandle,'Drag to resize. Size and position are saved with the profile.')
local stopWrapper
local function destroyUI(removeRoot)
    if not lifecycle.alive then return end
    lifecycle.alive=false;toast.generation=toast.generation+1;toast.queue={}
    cancelInteraction();suspendOverlays()
    for connection in pairs(lifecycle.connections) do disconnectUI(connection) end
    for obj,tween in pairs(lifecycle.tweens) do tween:Cancel();lifecycle.tweens[obj]=nil end
    if touchRoot.Parent then touchRoot:Destroy() end
    if state.gui==root then state.gui=nil end
    if state.__animeUiDestroy==destroyUI then state.__animeUiDestroy=nil end
    if state.stop==stopWrapper then state.stop=state.__animeUiStopBase end
    if removeRoot~=false and root.Parent then root:Destroy() end
end
trackUI(root.Destroying:Connect(function() destroyUI(false) end))
local stopEverything=state.__animeUiStopBase or state.stop
state.__animeUiStopBase=stopEverything
state.__animeUiDestroy=destroyUI
stopWrapper=function()
    stopEverything()
    destroyUI(true)
end
state.stop=stopWrapper
-- Capture desktop geometry once; compact layouts never overwrite that baseline.
for r,entry in pairs(responsiveRows) do
    entry.height=r.Size.Y.Offset
    entry.children={}
    for _,obj in ipairs(r:GetChildren()) do
        if obj:IsA('GuiObject') then
            entry.children[obj]={Position=obj.Position,Size=obj.Size,TextXAlignment=obj:IsA('TextLabel') and obj.TextXAlignment or nil}
        end
    end
end
applyResponsiveLayout=function()
    local compact=window.compact
    local width=window.shownWidth
    sidebar.Position=UDim2.fromOffset(0,57)
    sidebar.Size=compact and UDim2.new(1,0,0,48) or UDim2.new(0,174,1,-57)
    sidebar.AutomaticCanvasSize=compact and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
    sidebar.ScrollingDirection=compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
    navLayout.FillDirection=compact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    navLayout.HorizontalAlignment=compact and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
    navPadding.PaddingTop=UDim.new(0,compact and 5 or 22)
    navPadding.PaddingLeft=UDim.new(0,compact and 10 or 0)
    for _,button in pairs(navButtons) do button.Size=compact and UDim2.fromOffset(145,38) or UDim2.new(1,-20,0,39) end
    body.Position=compact and UDim2.fromOffset(0,105) or UDim2.fromOffset(175,57)
    body.Size=compact and UDim2.new(1,0,1,-105) or UDim2.new(1,-175,1,-57)
    sidebar.Visible=not window.minimized;body.Visible=not window.minimized
    divider.Visible=not compact and not window.minimized
    sessionBadge.Visible=not compact
    bigTitle.Size=UDim2.new(1,-150,0,22)
    smallTitle.Size=UDim2.new(1,-150,0,16)
    resizeHandle.Visible=not window.minimized and not compact
    for r,entry in pairs(responsiveRows) do
        if not compact then
            r.Size=UDim2.new(1,-2,0,entry.height)
            for obj,properties in pairs(entry.children) do
                obj.Position=properties.Position;obj.Size=properties.Size
                if properties.TextXAlignment then obj.TextXAlignment=properties.TextXAlignment end
            end
        else
            local contentWidth=width-40
            r.Size=UDim2.new(1,-2,0,entry.kind=='status' and 96 or entry.kind=='boss' and 104 or entry.kind=='transparency' and 90 or 80)
            entry.label.Position=UDim2.fromOffset(12,8)
            entry.label.Size=UDim2.new(1,-24,0,22)
            if entry.kind=='boss' then
                entry.label.Size=UDim2.new(1,-130,0,28)
                entry.timer.Position=UDim2.new(1,-112,0,8);entry.timer.Size=UDim2.fromOffset(100,28)
                entry.toggle.Position=UDim2.fromOffset(12,51);entry.toggle.Size=UDim2.fromOffset(84,38)
                entry.dropdown.Position=UDim2.fromOffset(108,51);entry.dropdown.Size=UDim2.new(1,-120,0,38)
            elseif entry.kind=='stage' then
                entry.timer.Position=UDim2.fromOffset(12,40);entry.timer.Size=UDim2.new(1,-130,0,30)
                entry.timer.TextXAlignment=Enum.TextXAlignment.Left
                entry.toggle.Position=UDim2.new(1,-106,0,36);entry.toggle.Size=UDim2.fromOffset(94,38)
            elseif entry.kind=='transparency' then
                transparencyText.Position=UDim2.new(1,-60,0,8);transparencyText.Size=UDim2.fromOffset(46,22)
                slider.Position=UDim2.fromOffset(14,36);slider.Size=UDim2.new(1,-28,0,38)
            elseif entry.kind=='status' then
                entry.value.Position=UDim2.fromOffset(12,36);entry.value.Size=UDim2.new(1,-24,0,50)
                entry.value.TextXAlignment=Enum.TextXAlignment.Left
            else
                for obj in pairs(entry.children) do
                    if obj:IsA('GuiButton') or obj:IsA('TextBox') then
                        local w=math.min(200,math.max(100,contentWidth-24))
                        obj.Position=UDim2.new(1,-w-12,0,36);obj.Size=UDim2.fromOffset(w,36)
                    end
                end
            end
        end
    end
end
sizeForDevice()
local function showStatus(widget,value)
    if widget and widget.Parent and widget.Text~=value then widget.Text=value end
end
local function refreshOverview()
    if not lifecycle.alive or not root.Enabled or window.minimized then return end
    pumpToast()
    local app=ctx.app
    local running=(app.enabled and 1 or 0)+(app.climb.enabled and 1 or 0)+(app.story.enabled and 1 or 0)+(app.dungeon.enabled and 1 or 0)
    showStatus(sessionBadge,running>0 and (running..' ACTIVE') or 'STANDBY')
    showStatus(draftStatus,app.status);showStatus(draftLive,app.status)
    showStatus(climbStatus,app.climb.status);showStatus(climbLive,app.climb.status)
    showStatus(bossStatus,app.story.status);showStatus(bossLive,app.story.status)
    for _,entry in ipairs({{draftStatus,app.enabled},{draftLive,app.enabled},{climbStatus,app.climb.enabled},{climbLive,app.climb.enabled},{bossStatus,app.story.enabled},{bossLive,app.story.enabled}}) do
        local value=entry[1].Text
        skin(entry[1],'TextColor3',value:find('ERROR:',1,true) and 'rose' or (entry[2] and 'mint' or 'muted'))
    end
    showStatus(scoreStatus,app.wins..' / '..app.losses..' / '..app.clears)
    showStatus(requestStatus,tostring(app.story.requests))
    local run=app.snapshot and app.snapshot.run
    showStatus(draftRun,type(run)=='table' and ('#'..tostring(run.id)..' / Boss '..tostring(run.boss)) or '--')
    showStatus(draftTeam,type(run)=='table' and type(run.team)=='table' and table.concat(run.team,' / ') or '--')
    local recovery=app.recovery[#app.recovery]
    showStatus(draftRecovery,recovery and (recovery.target..' / '..recovery.remaining..' wins left') or '--')
    local climb=app.snapshot and app.snapshot.climb
    local cr=type(climb)=='table' and climb.run
    showStatus(climbProgress,type(cr)=='table' and ('#'..tostring(cr.id or cr.Id)..' / Floor '..tostring(cr.floor or cr.Floor)) or '--')
    local team=type(cr)=='table' and (cr.team or cr.Team)
    showStatus(climbTeam,type(team)=='table' and table.concat(team,' / ') or '--')
    local selectedCount,readyCount,coolingCount=0,0,0
    for _,boss in ipairs(ctx.storyBosses) do
        local remaining=(app.story.cooldowns[ctx.cooldownKey(boss.id,boss.secret and 'Secret' or app.config.storyDifficulty)] or 0)-os.clock()
        local selected=app.config['story_'..boss.key]
        cooldownLabels[boss.id].Parent.Visible=selected or remaining>0
        if selected then
            selectedCount=selectedCount+1
            if remaining>0 then coolingCount=coolingCount+1 else readyCount=readyCount+1 end
        end
        showStatus(cooldownLabels[boss.id],remaining>0 and ctx.cooldownText(remaining) or 'No known cooldown')
    end
    showStatus(bossSummary,selectedCount..' selected  ·  '..readyCount..' no known CD  ·  '..coolingCount..' cooling')
    showStatus(priorityLive,ctx.app.priority.status)
    showStatus(dungeonLive,app.dungeon.status)
    local dr=app.dungeon.view and app.dungeon.view.run
    showStatus(dungeonProgress,dr and ('Room '..tostring(dr.room)..' / '..tostring(dr.phase)) or 'No active Dungeon')
    if dr then local alive,average=ctx.dungeonVitals(dr);showStatus(dungeonHealth,alive..' alive / '..math.floor(average*100+.5)..'% HP') else showStatus(dungeonHealth,'--') end
    for i,label in ipairs(dungeonHistory) do
        local item=app.dungeon.history[i]
        label.Parent.Visible=item~=nil or i==1
        if item then
            local seconds=math.floor(item.seconds)
            local lines=math.max(2,math.ceil(#item.rewards/math.max(20,math.floor(label.AbsoluteSize.X/7)))+1)
            label.Parent.Size=UDim2.new(1,-2,0,50+lines*18)
            label.Size=UDim2.new(1,-32,0,lines*18)
            showStatus(label,tostring(item.difficulty or '?')..' · '..tostring(item.reason)..' · '..string.format('%02d:%02d',math.floor(seconds/60),seconds%60)..' · '..tostring(item.cleared or '?')..' rooms\n'..item.rewards)
        else showStatus(label,'No completed runs yet') end
    end
    showStatus(configStatus,app.profiles.status)
    showStatus(configAuto,app.profiles.auto or 'OFF')
    local preferences={}
    for _,mode in ipairs({'draft','climb','story','dungeon'}) do preferences[#preferences+1]=mode..': '..(app.config[mode..'Enabled'] and 'ON' or 'OFF') end
    showStatus(configModes,table.concat(preferences,' · '))
    showStatus(hopStatus,app.config.autoExecuteOnHop and app.hop.status or 'OFF')
    showStatus(afkStatus,app.config.antiAfk and app.afk.status or 'OFF')
    showStatus(reconnectStatus,app.config.autoReconnect and app.reconnect.status or 'OFF')
end
do
    local ok,service=pcall(function()return game:GetService('RunService')end)
    if ok and service and service.Heartbeat then
        local elapsed=0
        trackUI(service.Heartbeat:Connect(function(dt)
            elapsed=elapsed+(tonumber(dt) or 0)
            if elapsed<.08 then return end
            elapsed=0
            if not lifecycle.alive or not root.Enabled or window.minimized then return end
            local phase=os.clock()*.35
            for label in pairs(textGradients) do
                if label.Parent then
                    local gradient=label:FindFirstChild('OriginTextGradient')
                    if gradient then
                        gradient.Offset=Vector2.new(math.sin(phase)*.28,0)
                        gradient.Rotation=math.sin(phase*.6)*16
                    end
                end
            end
        end))
    end
end
repaintControls()
refreshOverview()
return {Repaint=repaintControls,Refresh=refreshOverview,Root=root,Notify=notify,Destroy=destroyUI,ClearNotifications=clearNotifications}
end
return Library

end)()
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
setStatus('Ready — Native UI / independent mode controls')
monitorConnection()
app.refreshDungeonCollection()
if autoLoaded and app.config.autoStart then app.restoreSavedModes() end
