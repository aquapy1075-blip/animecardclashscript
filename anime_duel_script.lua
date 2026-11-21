-- anime duel script
-- UI adapted from anime_origin_ui.lua (aquapy1075-blip/animecardclashscript).
-- Uses captured DraftAction calls. Auto starts only when enabled in an auto-loaded profile.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local UIS = game:GetService('UserInputService')
local Workspace = game:GetService('Workspace')
local HttpService = game:GetService('HttpService')
local GuiService = game:GetService('GuiService')
local TeleportService = game:GetService('TeleportService')
local player = Players.LocalPlayer
local playerGui = Players.LocalPlayer:WaitForChild('PlayerGui')
local env = getgenv and getgenv() or _G
local previous = env.AnimeDuelScript
if type(previous) == 'table' and type(previous.destroy) == 'function' then
    if previous.worker or (previous.climb and previous.climb.worker) or (previous.story and previous.story.worker) then
        previous.stop()
        local deadline=os.clock()+10
        while previous.worker or (previous.climb and previous.climb.worker) or (previous.story and previous.story.worker) do
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
local app = {build='update4-online-ui-v1',alive=true, enabled=false, worker=false, bosses={}, connections={}, snapshot=nil,
    version=0, resultVersion=0, wins=0, losses=0, clears=0,
    status='Ready — press START', recovery={}, stage=nil, runId=nil,
    config={farm=3, bossFarm=4, delay=.8, timeout=180, theme='Midnight', transparency=15, autoReconnect=true, autoStart=false, mode='draft', storyDifficulty='Nightmare', storyInterval=10, windowW=805,windowH=565,windowX=.5,windowY=.5, story_purple_forest=false, story_android_games=false, story_hollow_world=false, story_purple_town=false, story_toy_kingdom=true}}
app.climb={enabled=false,worker=false,status='Ready — press START CLIMB'}
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
local function setStatus(message)
    local ctx=controller()
    ctx.status=tostring(message)
    if ctx==app.climb then app.climbStatus=ctx.status end
    redraw()
end
-- Named profiles use only executor-local JSON files.
local storage='AnimeDuelScript/'..tostring(player.UserId or 'Local')
local profileDir=storage..'/profiles'
local disk=type(readfile)=='function' and type(writefile)=='function'
app.profiles={current='Default',auto=nil,names={},status=disk and 'Storage ready' or 'File API unavailable'}
app.reconnect={attempts=0,lastTry=-math.huge,status='Monitoring',limit=3,interval=9}
local ranges={windowW={600,1200},windowH={420,1000},windowX={0,1},windowY={0,1},farm={1,20,true},bossFarm={1,20,true},delay={.5,5},timeout={30,600},transparency={0,65}}
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
    if app.worker or app.climb.worker or app.story.worker then storageStatus('Stop active modes before loading a profile');return false end
    name=profileId(name)
    local data=name and readJson(profilePath(name))
    if not data or data.version~=1 or type(data.config)~='table' then
        storageStatus('Profile unavailable or invalid');return false
    end
    local incoming=data.config
    app.config.storyInterval=10 -- Migrate profiles saved with the old 5-second interval.
    for key,range in pairs(ranges) do
        local v=incoming[key]
        if type(v)=='number' and v==v and v>=range[1] and v<=range[2] then
            app.config[key]=range[3] and math.floor(v) or v
        end
    end
    if incoming.mode=='draft' or incoming.mode=='climb' or incoming.mode=='story' then app.config.mode=incoming.mode end
    if table.find(storyDifficulties,incoming.storyDifficulty) then app.config.storyDifficulty=incoming.storyDifficulty end
    for _,boss in ipairs(storyBosses) do
        local key='story_'..boss.key
        if type(incoming[key])=='boolean' then app.config[key]=incoming[key] end
    end
    if themesAllowed[incoming.theme] then app.config.theme=incoming.theme end
    for _,key in ipairs({'autoReconnect','autoStart'}) do
        if type(incoming[key])=='boolean' then app.config[key]=incoming[key] end
    end
    app.profiles.current=name;addName(name);storageStatus('Loaded: '..name)
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
    app.enabled=false;app.climb.enabled=false;app.story.enabled=false
    app.stopReason='Connection lost — auto reconnect requested'
    app.climb.stopReason=app.stopReason;app.story.stopReason=app.stopReason
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
    while app.bosses.world or app.bosses.raid do
        check()
        if not waiting then
            waiting=true
            setStatus('Draft paused — waiting for World/Raid boss death')
        end
        task.wait(.1)
    end
    check()
    if waiting then setStatus('Bosses ended — resuming Draft') end
    return waiting
end
local function call(name,a,b,remote)
    check()
    if name~='State' then awaitPriority() end
    -- Only one request in flight, while each controller keeps its own lifecycle.
    while app.requestBusy do check();task.wait(.05) end
    check()
    app.requestBusy=true
    local version=app.version
    local values=table.pack(pcall(function()
        if remote then return remote:InvokeServer(name,a) end
        return action:InvokeServer(name,a,b)
    end))
    app.requestBusy=false
    check()
    if not values[1] then
        return {ok=false,uncertain=true,reason=tostring(values[2])}
    end
    local rejected=values[2]==false
    local reason=values[3]
    if type(values[2])=='table' and values[2].ok==false then
        rejected=true;reason=values[2].reason or values[2].message
    end
    if rejected then return {ok=false,reason=tostring(reason),loading=loadingRejection(reason)} end
    if not remote and app.version==version then
        for i=2,values.n do
            local v=values[i]
            if accept(v) or (type(v)=='table' and accept(v.state)) then break end
        end
    end
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
                app.story.nextAttemptAt=os.clock()+10
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
                    else setStatus(chosen.name..': '..tostring(result.reason)) end
                end
            end
        end
        pause(1)
    end
end

local function stopController(ctx)
    ctx.enabled=false
    ctx.status=ctx.worker and 'Stopping — current server fight continues' or 'Stopped'
end
function app.stop(mode)
    if mode=='draft' then stopController(app)
    elseif mode=='climb' then stopController(app.climb)
    elseif mode=='story' then stopController(app.story)
    else stopController(app);stopController(app.climb);stopController(app.story) end
    redraw()
end
function app.start(mode)
    if mode~='draft' and mode~='climb' and mode~='story' then mode=app.config.mode end
    local ctx=mode=='climb' and app.climb or (mode=='story' and app.story or app)
    if not app.alive or ctx.worker then return end
    app.config.mode=mode -- Auto Load preference only; never selects the live worker.
    ctx.stopReason=nil;ctx.lastError=nil
    ctx.enabled=true;ctx.worker=true
    task.spawn(function()
        local thread=coroutine.running()
        workerContexts[thread]=ctx
        local ok,err=pcall(mode=='climb' and runClimbLoop or (mode=='story' and runStoryLoop or runLoop))
        ctx.enabled=false;ctx.worker=false
        if not ok and tostring(err)~='__STOP__' then
            ctx.lastError=tostring(err)
            setStatus('ERROR: '..ctx.lastError)
        else setStatus(ctx.stopReason or 'Stopped') end
        workerContexts[thread]=nil
    end)
end

-- Online UI reference: anime-card-online/anime_card_online.lua @831eaf8.
local palettes={
    Light={bg='F2F5FC',side='E7EDF8',panel='FFFFFF',row='EAF0FA',text='14213A',muted='526781',accent='4264D9',line='D1DBED',selected='DDE8FF',selectedText='173C85',mint='087B72',gold='986014',rose='B33764',violet='7045BC'},
    Midnight={bg='0B0D13',side='10121B',panel='171B28',row='202638',text='F0F4FF',muted='99A9C8',accent='6D8BFF',line='303B58',selected='28476B',selectedText='D9F4FF',mint='62DCC1',gold='F3C276',rose='F28FB4',violet='BAA0FF'},
    Ocean={bg='080F16',side='0C1822',panel='102635',row='17394B',text='ECFAFF',muted='8EBACD',accent='36DBCE',line='255166',selected='164C56',selectedText='CFFFF6',mint='5CE1C2',gold='F4CC84',rose='FF9EBD',violet='B5A5FF'},
    Violet={bg='171322',side='20192E',panel='2B213C',row='392C50',text='F6EFFF',muted='B8A8D4',accent='BC8AFF',line='534267',selected='503D78',selectedText='F4E8FF',mint='70E2CC',gold='F2CA83',rose='FFA0C1',violet='C7A8FF'},
    Emerald={bg='101C18',side='152B24',panel='1C372D',row='29463A',text='EFFFF4',muted='A0C8B0',accent='60D8A8',line='3E6454',selected='235545',selectedText='D2FFEC',mint='79E8BD',gold='F4CE86',rose='FCA3C0',violet='B7ACFF'},
    Rose={bg='23171C',side='311D27',panel='3E2633',row='503442',text='FFEFF4',muted='D9A9BC',accent='FF8FB2',line='704859',selected='64364E',selectedText='FFE2EE',mint='7AE5CE',gold='F5CF92',rose='FFABCD',violet='C8ADFF'},
}
local skins={}
local surfaces=setmetatable({}, {__mode='k'})
local tweens=setmetatable({}, {__mode='k'})
local TweenService
pcall(function() TweenService=game:GetService('TweenService') end)
if TweenService and type(TweenService.Create)~='function' then TweenService=nil end
local function animate(obj,properties)
    if not app.alive or not obj.Parent then return end
    if tweens[obj] then tweens[obj]:Cancel();tweens[obj]=nil end
    if not TweenService then for key,value in pairs(properties) do obj[key]=value end;return end
    local tween=TweenService:Create(obj,TweenInfo.new(.16,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),properties)
    tweens[obj]=tween;tween:Play()
end
local function color(role)
    local hex=palettes[app.config.theme][role]
    return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
end
local function make(class,parent,props)
    local obj=Instance.new(class)
    for k,v in pairs(props or {}) do obj[k]=v end
    if obj:IsA('GuiObject') then
        obj.Selectable=false
        if obj.BackgroundTransparency<1 then surfaces[obj]=obj.BackgroundTransparency end
    end
    obj.Parent=parent
    return obj
end
local function skin(obj,property,role)
    table.insert(skins,{obj,property,role});obj[property]=color(role)
end
local function corner(obj) make('UICorner',obj,{CornerRadius=UDim.new(0,10)}) end
local function panel(parent,props)
    local obj=make('Frame',parent,props);corner(obj);skin(obj,'BackgroundColor3','panel')
    local outline=make('UIStroke',obj,{Thickness=1,Transparency=.2});skin(outline,'Color','line')
    return obj
end
local function text(parent,value,bold)
    local obj=make('TextLabel',parent,{Text=value,BackgroundTransparency=1,BorderSizePixel=0,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
    skin(obj,'TextColor3',bold and 'text' or 'muted');return obj
end
local function button(parent,value,size)
    local obj=make('TextButton',parent,{Text=value,Size=size or UDim2.fromOffset(100,32),
        BorderSizePixel=0,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=true})
    corner(obj);skin(obj,'BackgroundColor3','row');skin(obj,'TextColor3','text')
    local outline=make('UIStroke',obj,{Thickness=1,Transparency=1});skin(outline,'Color','accent')
    if obj.MouseEnter then track(obj.MouseEnter,function() animate(outline,{Transparency=.4}) end) end
    if obj.MouseLeave then track(obj.MouseLeave,function() animate(outline,{Transparency=1}) end) end
    return obj
end
local root=make('ScreenGui',playerGui,{Name='AnimeDuelScript',ResetOnSpawn=false,
    DisplayOrder=100,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
app.Root=root
local closeDropdown=function() end
local main=make('CanvasGroup',root,{Name='Window',Position=UDim2.new(.5,-402,.5,-282),Size=UDim2.fromOffset(805,565),BorderSizePixel=0,GroupTransparency=0,Active=false,ZIndex=2})
corner(main);skin(main,'BackgroundColor3','bg')
local mainOutline=make('UIStroke',main,{Thickness=1,Transparency=.15});skin(mainOutline,'Color','line')
local shadow=make('Frame',root,{Name='WindowShadow',BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=.78,BorderSizePixel=0,Active=false,ZIndex=1})
corner(shadow);surfaces[shadow]=nil
local accent=make('Frame',main,{Position=UDim2.fromOffset(18,0),Size=UDim2.new(1,-36,0,2),BorderSizePixel=0});skin(accent,'BackgroundColor3','accent')
make('UIGradient',accent,{Rotation=0})
local header=make('Frame',main,{Size=UDim2.new(1,0,0,58),BackgroundTransparency=1})
local icon=panel(header,{Position=UDim2.fromOffset(16,12),Size=UDim2.fromOffset(34,34),BorderSizePixel=0});skin(icon,'BackgroundColor3','accent')
local monogram=text(icon,'AD',true);monogram.Size=UDim2.fromScale(1,1);monogram.TextXAlignment=Enum.TextXAlignment.Center;skin(monogram,'TextColor3','bg')
local title=text(header,'ANIME CARD DUEL',true)
title.TextSize=17;title.Position=UDim2.fromOffset(62,10);title.Size=UDim2.new(1,-260,0,23)
local subtitle=text(header,'UPDATE 4 · made by aquacodex',false)
subtitle.TextSize=11;subtitle.Position=UDim2.fromOffset(63,33);subtitle.Size=UDim2.new(1,-160,0,17)
local badge=text(header,'READY',true);badge.Position=UDim2.new(1,-180,0,18);badge.Size=UDim2.fromOffset(95,22)
local minimize=button(header,'—',UDim2.fromOffset(30,28));minimize.Position=UDim2.new(1,-76,0,15)
local hide=button(header,'×',UDim2.fromOffset(30,28));hide.Position=UDim2.new(1,-40,0,15)
local restore=button(root,'AD',UDim2.fromOffset(44,38));restore.Position=UDim2.fromOffset(10,110)
local nav=make('ScrollingFrame',main,{Name='Sidebar',Position=UDim2.fromOffset(0,58),Size=UDim2.new(0,174,1,-58),BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
skin(nav,'BackgroundColor3','side')
local navLayout=make('UIListLayout',nav,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,FillDirection=Enum.FillDirection.Vertical,HorizontalAlignment=Enum.HorizontalAlignment.Center})
local navPadding=make('UIPadding',nav,{PaddingTop=UDim.new(0,18),PaddingLeft=UDim.new(0,0)})
local body=make('Frame',main,{Position=UDim2.fromOffset(175,58),Size=UDim2.new(1,-175,1,-58),BackgroundTransparency=1,ClipsDescendants=true})
local pages,navButtons={},{}
local selected='Monitor'
local tabNames={'Monitor','Draft','Climb','Boss','Settings','Config'}
for i,name in ipairs(tabNames) do
    local b=button(nav,name,UDim2.new(1,-20,0,39));b.LayoutOrder=i
    b.TextXAlignment=Enum.TextXAlignment.Left
    make('UIPadding',b,{PaddingLeft=UDim.new(0,14)})
    make('UIGradient',b,{Rotation=30})
    navButtons[name]=b
    local page=make('ScrollingFrame',body,{Name=name,Size=UDim2.fromScale(1,1),Visible=name==selected,
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
    skin(page,'ScrollBarImageColor3','accent')
    make('UIPadding',page,{PaddingTop=UDim.new(0,14),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,18),PaddingRight=UDim.new(0,19)})
    make('UIListLayout',page,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
    pages[name]=page
    track(b.Activated,function()
        selected=name
        for key,p in pairs(pages) do p.Visible=key==name end
        page.Position=UDim2.fromOffset(0,7);animate(page,{Position=UDim2.fromOffset(0,0)})
        redraw()
    end)
end
local order=0
local function row(page,label,height)
    order=order+1
    local r=panel(pages[page],{Size=UDim2.new(1,-2,0,height or 58),BorderSizePixel=0,LayoutOrder=order})
    local l=text(r,label,true);l.Position=UDim2.fromOffset(12,7);l.Size=UDim2.new(1,-24,0,19)
    return r
end
local function status(label)
    local r=row('Draft',label,61)
    local l=text(r,'--');l.Position=UDim2.fromOffset(12,30);l.Size=UDim2.new(1,-24,0,22)
    return l
end
local monitorLabels={}
for _,name in ipairs({'Draft Run','Draft Climb','Story Boss'}) do
    local r=row('Monitor',name,94)
    local label=text(r,'Ready');label.Position=UDim2.fromOffset(12,31);label.Size=UDim2.new(1,-24,0,52)
    label.TextWrapped=true;label.TextTruncate=Enum.TextTruncate.None;monitorLabels[name]=label
end
local updateRow=row('Monitor','Update 4 compatibility',105)
local updateText=text(updateRow,'Clover Capital / Body Devil and Secret bosses. Live StoryConfig catalog. Draft priorities and bans retained. Independent controls for each mode.')
updateText.Position=UDim2.fromOffset(12,31);updateText.Size=UDim2.new(1,-24,0,68);updateText.TextWrapped=true;updateText.TextTruncate=Enum.TextTruncate.None
local controls=row('Draft','Automation',69)
local start=button(controls,'START',UDim2.new(.5,-18,0,30));start.Position=UDim2.fromOffset(12,31)
local stop=button(controls,'STOP DRAFT',UDim2.new(.5,-18,0,30));stop.Position=UDim2.new(.5,6,0,31)
track(start.Activated,function() app.start('draft') end);track(stop.Activated,function() app.stop('draft') end)
local statusLabel=status('Status')
statusLabel.Parent.Size=UDim2.new(1,-2,0,112)
statusLabel.Size=UDim2.new(1,-24,0,76)
statusLabel.TextWrapped=true;statusLabel.TextTruncate=Enum.TextTruncate.None
statusLabel.TextYAlignment=Enum.TextYAlignment.Top
local runLabel=status('Run / Boss / Recovery')
local teamLabel=status('Current team')
local scoreLabel=status('Session results')
local hint=row('Draft','Strategy',76)
local hintText=text(hint,'Easy → Medium → Hard → Boss 1 / 2 / 3\nAfter each fight: Open packs → Auto Team')
hintText.Position=UDim2.fromOffset(12,29);hintText.Size=UDim2.new(1,-24,0,40);hintText.TextWrapped=true
local climbControls=row('Climb','Auto Draft Climb',69)
local climbStart=button(climbControls,'START CLIMB',UDim2.new(.5,-18,0,30));climbStart.Position=UDim2.fromOffset(12,31)
local climbStop=button(climbControls,'STOP CLIMB',UDim2.new(.5,-18,0,30));climbStop.Position=UDim2.new(.5,6,0,31)
track(climbStart.Activated,function() app.start('climb') end)
track(climbStop.Activated,function() app.stop('climb') end)
local function climbStatusRow(label)
    local r=row('Climb',label,76)
    local l=text(r,'--');l.Position=UDim2.fromOffset(12,29);l.Size=UDim2.new(1,-24,0,40);l.TextWrapped=true
    return l
end
local climbStatusLabel=climbStatusRow('Climb status')
local climbProgressLabel=climbStatusRow('Run / Floor')
local climbTeamLabel=climbStatusRow('Climb team')
local climbInfo=climbStatusRow('How it works')
climbInfo.Text='Saiyan Prince, Atomic and Samurai Lost Man are banned. Teen Saski receives +50% selection score; other preferred cards +25%. Enable native Auto Climb. Draft and Climb have separate Start/Stop controls. Climb STOP only stops this picker; native Auto Climb stays enabled.'
local configInputs={}
local paintedTheme=nil
local function numberInput(label,key,low,high)
    local r=row('Settings',label,69)
    local box=make('TextBox',r,{Position=UDim2.fromOffset(12,31),Size=UDim2.new(1,-24,0,29),
        Text=tostring(app.config[key]),ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0})
    corner(box);skin(box,'BackgroundColor3','row');skin(box,'TextColor3','text')
    configInputs[key]=box
    track(box.FocusLost,function()
        local n=tonumber(box.Text)
        if n and n==n and n>=low and n<=high then
            app.config[key]=(key=='farm' or key=='bossFarm') and math.floor(n) or n
        end
        box.Text=tostring(app.config[key])
        redraw()
    end)
end
numberInput('Farm wins after a farm loss (1–20)','farm',1,20)
numberInput('Hard wins after a boss loss (1–20)','bossFarm',1,20)
numberInput('Action delay, seconds (0.5–5)','delay',.5,5)
numberInput('Fight timeout, seconds (30–600)','timeout',30,600)
local themeRow=row('Settings','Theme',69)
local themeButton=button(themeRow,'Midnight',UDim2.new(1,-24,0,29));themeButton.Position=UDim2.fromOffset(12,31)
local themeNames={'Midnight','Emerald','Violet','Light','Ocean','Rose'}
track(themeButton.Activated,function()
    local i=table.find(themeNames,app.config.theme) or 1
    app.config.theme=themeNames[i%#themeNames+1];themeButton.Text=app.config.theme
    for _,entry in ipairs(skins) do entry[1][entry[2]]=color(entry[3]) end
    redraw()
end)
numberInput('Window transparency % (0–65)','transparency',0,65)
local bossControls=row('Boss','Auto Story Boss',69)
local bossStart=button(bossControls,'START BOSS',UDim2.new(.5,-18,0,30));bossStart.Position=UDim2.fromOffset(12,31)
local bossStop=button(bossControls,'STOP BOSS',UDim2.new(.5,-18,0,30));bossStop.Position=UDim2.new(.5,6,0,31)
track(bossStart.Activated,function() app.start('story') end)
track(bossStop.Activated,function() app.stop('story') end)
local bossStatusRow=row('Boss','Story Boss status',110)
local bossStatusLabel=text(bossStatusRow,'Ready');bossStatusLabel.Position=UDim2.fromOffset(12,29);bossStatusLabel.Size=UDim2.new(1,-24,0,76)
bossStatusLabel.TextWrapped=true;bossStatusLabel.TextTruncate=Enum.TextTruncate.None
local difficultyRow=row('Boss','Difficulty · Secret bosses use Secret',69)
local difficultyButton=button(difficultyRow,app.config.storyDifficulty,UDim2.new(1,-24,0,29));difficultyButton.Position=UDim2.fromOffset(12,31)
local dropdownDismiss=make('TextButton',root,{Name='DropdownDismiss',Visible=false,Size=UDim2.fromScale(1,1),Text='',BackgroundTransparency=1,BorderSizePixel=0,Active=true,ZIndex=149})
local dropdown=panel(root,{Name='DifficultyDropdown',Visible=false,Size=UDim2.fromOffset(240,220),BorderSizePixel=0,ZIndex=150})
local dropdownSearch=make('TextBox',dropdown,{Name='DropdownSearch',Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,0,34),Text='',PlaceholderText='Search difficulty…',ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0,ZIndex=151})
corner(dropdownSearch);skin(dropdownSearch,'BackgroundColor3','row');skin(dropdownSearch,'TextColor3','text');skin(dropdownSearch,'PlaceholderColor3','muted')
local dropdownList=make('ScrollingFrame',dropdown,{Position=UDim2.fromOffset(8,50),Size=UDim2.new(1,-16,1,-58),BackgroundTransparency=1,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,BorderSizePixel=0,ZIndex=151})
make('UIListLayout',dropdownList,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local dropdownOptions={}
closeDropdown=function() dropdown.Visible=false;dropdownDismiss.Visible=false end
for i,difficulty in ipairs(storyDifficulties) do
    local b=button(dropdownList,difficulty,UDim2.new(1,0,0,32));b.LayoutOrder=i;b.ZIndex=152
    dropdownOptions[difficulty]=b
    track(b.Activated,function() app.config.storyDifficulty=difficulty;closeDropdown();redraw() end)
end
track(dropdownSearch:GetPropertyChangedSignal('Text'),function()
    local query=dropdownSearch.Text:lower()
    for name,b in pairs(dropdownOptions) do b.Visible=query=='' or name:lower():find(query,1,true)~=nil end
end)
track(dropdownDismiss.Activated,closeDropdown)
track(difficultyButton.Activated,function()
    if dropdown.Visible then closeDropdown();return end
    local view=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
    dropdown.Position=UDim2.fromOffset(math.clamp(difficultyButton.AbsolutePosition.X,8,math.max(8,view.X-248)),
        math.clamp(difficultyButton.AbsolutePosition.Y+difficultyButton.AbsoluteSize.Y+6,8,math.max(8,view.Y-228)))
    dropdownSearch.Text=''
    for _,b in pairs(dropdownOptions) do b.Visible=true end
    dropdown.Visible=true;dropdownDismiss.Visible=true
end)
local bossToggles={}
local bossRows={}
local filterRow=row('Boss','Search boss / world',69)
local bossSearch=make('TextBox',filterRow,{Name='BossSearch',Position=UDim2.fromOffset(12,31),Size=UDim2.new(1,-24,0,29),Text='',PlaceholderText='Type a boss or world name…',ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0})
corner(bossSearch);skin(bossSearch,'BackgroundColor3','row');skin(bossSearch,'TextColor3','text');skin(bossSearch,'PlaceholderColor3','muted')
track(bossSearch:GetPropertyChangedSignal('Text'),function()
    local query=bossSearch.Text:lower()
    for _,entry in ipairs(bossRows) do entry.row.Visible=query=='' or entry.search:find(query,1,true)~=nil end
end)
for _,boss in ipairs(storyBosses) do
    local r=row('Boss',boss.name..(boss.secret and ' · SECRET' or ''),69)
    table.insert(bossRows,{row=r,search=(boss.name..' '..boss.id..' '..(boss.map or '')):lower()})
    local b=button(r,'',UDim2.new(1,-24,0,29));b.Position=UDim2.fromOffset(12,31)
    local key='story_'..boss.key;bossToggles[key]=b
    track(b.Activated,function() app.config[key]=not app.config[key];redraw() end)
end
local bossHelpRow=row('Boss','Start Fight only',110)
local bossHelp=text(bossHelpRow,'Start attempts are spaced 10s apart. Server cooldowns are tracked per boss and difficulty. Secret bosses use Secret. STOP BOSS stops requests; the current fight continues.')
bossHelp.Position=UDim2.fromOffset(12,29);bossHelp.Size=UDim2.new(1,-24,0,76);bossHelp.TextWrapped=true
local function settingToggle(label,key)
    local r=row('Settings',label,69)
    local b=button(r,'',UDim2.new(1,-24,0,29));b.Position=UDim2.fromOffset(12,31)
    track(b.Activated,function() app.config[key]=not app.config[key];redraw() end)
    return b
end
local reconnectToggle=settingToggle('Auto reconnect on connection loss','autoReconnect')
local autoStartToggle=settingToggle('Start selected mode when profile is auto-loaded','autoStart')
local reconnectRow=row('Settings','Connection',69)
local reconnectLabel=text(reconnectRow,'Monitoring');reconnectLabel.Position=UDim2.fromOffset(12,31);reconnectLabel.Size=UDim2.new(1,-24,0,29)
local rejoinRow=row('Settings','Rejoin this place',69)
local rejoin=button(rejoinRow,'REJOIN',UDim2.new(1,-24,0,29));rejoin.Position=UDim2.fromOffset(12,31)
track(rejoin.Activated,function() app.requestReconnect(true) end)
local unloadRow=row('Settings','Unload UI and stop controllers',69)
local unload=button(unloadRow,'STOP SCRIPT',UDim2.new(1,-24,0,29));unload.Position=UDim2.fromOffset(12,31)
track(unload.Activated,function() app.destroy() end)
local profileRow=row('Config','Profile name (letters, digits, _ or -)',69)
local profileBox=make('TextBox',profileRow,{Position=UDim2.fromOffset(12,31),Size=UDim2.new(1,-24,0,29),Text=app.profiles.current,
    ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0})
corner(profileBox);skin(profileBox,'BackgroundColor3','row');skin(profileBox,'TextColor3','text')
for _,entry in ipairs({{'Save settings','SAVE','saveProfile'},{'Load settings (stop active modes first)','LOAD','loadProfile'},
    {'Delete profile','DELETE','deleteProfile'},{'Save and use on next execution','SET AUTO LOAD','setAutoProfile'},
    {'Disable automatic profile loading','CLEAR AUTO LOAD','clearAutoProfile'}}) do
    local r=row('Config',entry[1],69)
    local b=button(r,entry[2],UDim2.new(1,-24,0,29));b.Position=UDim2.fromOffset(12,31)
    local method=entry[3]
    track(b.Activated,function() app[method](profileBox.Text) end)
end
local configRow=row('Config','Storage / active profile',84)
local configLabel=text(configRow,'');configLabel.Position=UDim2.fromOffset(12,29);configLabel.Size=UDim2.new(1,-24,0,48);configLabel.TextWrapped=true
local savedRow=row('Config','Saved profiles',76)
local savedLabel=text(savedRow,'Default');savedLabel.Position=UDim2.fromOffset(12,29);savedLabel.Size=UDim2.new(1,-24,0,40);savedLabel.TextWrapped=true
local paintedGeometry=nil
render=function()
    if not app.alive then return end
    if paintedTheme~=app.config.theme then
        paintedTheme=app.config.theme
        for _,entry in ipairs(skins) do entry[1][entry[2]]=color(entry[3]) end
    end
    local geometry=table.concat({app.config.windowW,app.config.windowH,app.config.windowX,app.config.windowY},':')
    if app.applyLayout and paintedGeometry~=geometry then paintedGeometry=geometry;app.applyLayout() end
    statusLabel.Text=(app.bosses.world or app.bosses.raid) and 'Boss priority — waiting for boss death' or app.status
    local run=app.snapshot and app.snapshot.run
    local job=app.recovery[#app.recovery]
    runLabel.Text=type(run)=='table' and ('#'..tostring(run.id)..' / Boss '..tostring(run.boss)
        ..(run.over and (' / '..tostring(run.over)) or '')
        ..(job and (' / '..job.target..' ×'..job.remaining) or '')) or 'No active run'
    teamLabel.Text=type(run)=='table' and type(run.team)=='table' and table.concat(run.team,' / ') or '--'
    scoreLabel.Text=app.wins..' wins / '..app.losses..' losses / '..app.clears..' clears'
    start.Active=not app.worker
    start.Text=app.worker and (app.enabled and 'RUNNING' or 'STOPPING') or 'START DRAFT'
    climbStart.Text=app.climb.worker and (app.climb.enabled and 'RUNNING' or 'STOPPING') or 'START CLIMB'
    climbStart.Active=not app.climb.worker
    local climb=app.snapshot and app.snapshot.climb
    local cr=type(climb)=='table' and climb.run
    climbStatusLabel.Text=app.climb.status
    bossStatusLabel.Text=app.story.status
    bossStart.Text=app.story.worker and (app.story.enabled and 'RUNNING' or 'STOPPING') or 'START BOSS'
    bossStart.Active=not app.story.worker
    difficultyButton.Text=app.config.storyDifficulty
    for _,boss in ipairs(storyBosses) do
        local key='story_'..boss.key
        local remaining=(app.story.cooldowns[storyCooldownKey(boss.id,boss.secret and 'Secret' or app.config.storyDifficulty)] or 0)-os.clock()
        bossToggles[key].Text=(app.config[key] and 'ON' or 'OFF')..(remaining>0 and (' · '..cooldownText(remaining)) or '')
    end
    climbProgressLabel.Text=type(cr)=='table' and ('#'..tostring(climbId(cr))..' / Floor '..tostring(cr.floor or cr.Floor)..' / '..tostring(cr.over or cr.Over or 'active')) or 'No climb running'
    local ct=climbTeam(cr)
    climbTeamLabel.Text=type(ct)=='table' and table.concat(ct,' / ') or '--'
    for name,b in pairs(navButtons) do b.BackgroundColor3=color(name==selected and 'selected' or 'side');b.TextColor3=color(name==selected and 'selectedText' or 'muted') end
    local opacity=app.config.transparency/100
    for obj,base in pairs(surfaces) do if obj.Parent then obj.BackgroundTransparency=base+(1-base)*opacity end end
    local running=(app.enabled and 1 or 0)+(app.climb.enabled and 1 or 0)+(app.story.enabled and 1 or 0)
    badge.Text=running>0 and (running..' ACTIVE') or 'READY'
    monitorLabels['Draft Run'].Text=app.status
    monitorLabels['Draft Climb'].Text=app.climb.status
    monitorLabels['Story Boss'].Text=app.story.status
    reconnectToggle.Text=app.config.autoReconnect and 'ON' or 'OFF'
    autoStartToggle.Text=app.config.autoStart and 'ON' or 'OFF'
    reconnectLabel.Text=app.config.autoReconnect and app.reconnect.status or 'OFF'
    configLabel.Text=app.profiles.status..' / '..app.profiles.current..' / Auto: '..(app.profiles.auto or 'OFF')
    savedLabel.Text=table.concat(app.profiles.names,', ')
    for key,box in pairs(configInputs) do if not box:IsFocused() then box.Text=tostring(app.config[key]) end end
    themeButton.Text=app.config.theme
end
local minimized=false
local compact=false
local drag=nil
local resizeHandle=button(main,'◢',UDim2.fromOffset(22,22));resizeHandle.Position=UDim2.new(1,-24,1,-24)
local function layout()
    local camera=Workspace.CurrentCamera
    local view=camera and camera.ViewportSize or Vector2.new(1280,720)
    compact=view.X<680
    local w=math.min(app.config.windowW,math.max(240,view.X-16))
    local h=math.min(app.config.windowH,math.max(260,view.Y-16))
    main.Size=UDim2.fromOffset(w,minimized and 58 or h)
    main.Position=UDim2.fromOffset(math.max(8,view.X-w-16)*app.config.windowX+8,
        math.max(8,view.Y-(minimized and 58 or h)-16)*app.config.windowY+8)
    shadow.Position=UDim2.fromOffset(main.Position.X.Offset+4,main.Position.Y.Offset+7)
    shadow.Size=main.Size;shadow.Visible=main.Visible
    nav.Position=UDim2.fromOffset(0,58)
    nav.Size=compact and UDim2.new(1,0,0,48) or UDim2.new(0,174,1,-58)
    nav.AutomaticCanvasSize=compact and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
    nav.ScrollingDirection=compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
    navLayout.FillDirection=compact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    navLayout.HorizontalAlignment=compact and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
    navPadding.PaddingTop=UDim.new(0,compact and 5 or 18);navPadding.PaddingLeft=UDim.new(0,compact and 10 or 0)
    body.Position=UDim2.fromOffset(compact and 0 or 175,compact and 106 or 58)
    body.Size=compact and UDim2.new(1,0,1,-106) or UDim2.new(1,-175,1,-58)
    nav.Visible=not minimized;body.Visible=not minimized;badge.Visible=not compact
    title.Size=UDim2.new(1,compact and -150 or -260,0,23)
    resizeHandle.Visible=not minimized and not compact
    for _,name in ipairs(tabNames) do
        navButtons[name].Size=compact and UDim2.fromOffset(120,38) or UDim2.new(1,-20,0,39)
    end
end
app.applyLayout=layout
local function positionConfig()
    local view=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
    app.config.windowX=math.clamp((main.Position.X.Offset-8)/math.max(1,view.X-main.Size.X.Offset-16),0,1)
    app.config.windowY=math.clamp((main.Position.Y.Offset-8)/math.max(1,view.Y-main.Size.Y.Offset-16),0,1)
end
local cameraConnection
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if Workspace.CurrentCamera then cameraConnection=track(Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'),layout) end
    closeDropdown();drag=nil;layout()
end
local function visible(show)
    closeDropdown()
    main.Visible=show;shadow.Visible=show;drag=nil
    if not show then
        local focused=UIS:GetFocusedTextBox()
        if focused and focused:IsDescendantOf(root) then focused:ReleaseFocus() end
    end
end
track(Workspace:GetPropertyChangedSignal('CurrentCamera'),bindCamera)
track(minimize.Activated,function() closeDropdown();minimized=not minimized;layout() end)
track(hide.Activated,function() visible(false) end)
track(restore.Activated,function() visible(not main.Visible) end)
track(UIS.InputBegan,function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightShift then visible(not main.Visible) end
end)
track(header.InputBegan,function(input)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    if input.Position.X-header.AbsolutePosition.X>=header.AbsoluteSize.X-85 then return end
    drag={input=input,at=input.Position,position=main.Position}
end)
track(resizeHandle.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        drag={input=input,at=input.Position,size=main.Size,resize=true}
    end
end)
track(UIS.InputChanged,function(input)
    if not drag or not main.Visible then return end
    if input.UserInputType==Enum.UserInputType.MouseMovement or input==drag.input then
        local delta=input.Position-drag.at
        if drag.resize then
            app.config.windowW=math.clamp(drag.size.X.Offset+delta.X,600,1200)
            app.config.windowH=math.clamp(drag.size.Y.Offset+delta.Y,420,1000)
            layout()
        else
            main.Position=UDim2.fromOffset(drag.position.X.Offset+delta.X,drag.position.Y.Offset+delta.Y)
            shadow.Position=UDim2.fromOffset(main.Position.X.Offset+4,main.Position.Y.Offset+7)
        end
    end
end)
track(UIS.InputEnded,function(input)
    if drag and (input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then
        positionConfig();drag=nil;layout()
    end
end)
function app.destroy()
    app.stop();app.alive=false
    for _,connection in ipairs(app.connections) do connection:Disconnect() end
    table.clear(app.connections)
    for _,tween in pairs(tweens) do tween:Cancel() end
    root:Destroy()
end
bindCamera()
layout();redraw()
setStatus('Update 4 ready — choose a mode. Right Shift / AD hides or shows UI.')
monitorConnection()
if autoLoaded and app.config.autoStart then app.start() end

