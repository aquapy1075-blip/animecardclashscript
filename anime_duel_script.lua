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
    if previous.worker then
        previous.stop()
        previous.status='Previous worker is stopping; run again when stopped.'
        return
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
local app = {alive=true, enabled=false, worker=false, bosses={}, connections={}, snapshot=nil,
    version=0, resultVersion=0, wins=0, losses=0, clears=0,
    status='Ready — press START', recovery={}, stage=nil, runId=nil,
    config={farm=3, bossFarm=4, delay=.8, timeout=180, theme='Midnight', transparency=15, autoReconnect=true, autoStart=false, mode='draft'}}
env.AnimeDuelScript = app
local render = function() end
local function track(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(app.connections, connection)
    return connection
end
local function setStatus(message)
    app.status=tostring(message)
    render()
end
-- Named profiles use only executor-local JSON files.
local storage='AnimeDuelScript/'..tostring(player.UserId or 'Local')
local profileDir=storage..'/profiles'
local disk=type(readfile)=='function' and type(writefile)=='function'
app.profiles={current='Default',auto=nil,names={},status=disk and 'Storage ready' or 'File API unavailable'}
app.reconnect={attempts=0,lastTry=-math.huge,status='Monitoring',limit=3,interval=9}
local ranges={farm={1,20,true},bossFarm={1,20,true},delay={.5,5},timeout={30,600},transparency={0,65}}
local themesAllowed={Midnight=true,Emerald=true,Violet=true,Light=true}
local function profileId(name)
    if type(name)~='string' then return nil end
    name=name:match('^%s*(.-)%s*$')
    return #name>=1 and #name<=32 and name:match('^[%w_%-]+$') and name or nil
end
local function storageStatus(message)
    app.profiles.status=message;render()
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
    if app.worker then storageStatus('Stop Draft before loading a profile');return false end
    name=profileId(name)
    local data=name and readJson(profilePath(name))
    if not data or data.version~=1 or type(data.config)~='table' then
        storageStatus('Profile unavailable or invalid');return false
    end
    local incoming=data.config
    for key,range in pairs(ranges) do
        local v=incoming[key]
        if type(v)=='number' and v==v and v>=range[1] and v<=range[2] then
            app.config[key]=range[3] and math.floor(v) or v
        end
    end
    if incoming.mode=='draft' or incoming.mode=='climb' then app.config.mode=incoming.mode end
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
    if st.attempts>=st.limit then st.status='Attempt limit reached';render();return false end
    if os.clock()-st.lastTry<st.interval then return false end
    st.attempts=st.attempts+1;st.lastTry=os.clock()
    st.status='Rejoining '..st.attempts..'/'..st.limit
    -- Stop scheduling gameplay; a disconnected session cannot confirm new mutations.
    app.enabled=false
    local ok=pcall(function() TeleportService:Teleport(game.PlaceId,player) end)
    if not ok then st.status='Rejoin unavailable; waiting to retry' end
    render();return ok
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
    render()
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
        render()
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
    if not app.alive or not app.enabled then error('__STOP__', 0) end
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
    render()
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
local function call(name,a,b)
    check()
    if name~='State' then awaitPriority() end
    local version=app.version
    local values=table.pack(pcall(function() return action:InvokeServer(name,a,b) end))
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
    if app.version==version then
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
        for _,card in pairs(run.cards) do
            if type(card)=='table' and type(card.id)=='string' then owned[card.id]=true end
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
        return app.version>(app.resultStateVersion or 0) and app.snapshot and not app.snapshot.fighting
    end,8) then
        local stateVersion=app.version
        refresh()
        if app.version<=stateVersion or (app.snapshot and app.snapshot.fighting) then
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
    while app.enabled do
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
for _,base in ipairs({'saiyan_prince','atomic'}) do
    for _,suffix in ipairs({'','_gold','_rainbow','_secret'}) do
        bannedClimbCards[base..suffix]=true
    end
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
            table.insert(ranked,{id=id,damage=damage,hp=hp,score=damage+hp/2})
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
    while app.enabled do
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

function app.stop()
    app.enabled=false
    setStatus(app.worker and 'Stopping — current server fight continues' or 'Stopped')
end
function app.start(mode)
    if not app.alive or app.worker then return end
    if mode=='draft' or mode=='climb' then app.config.mode=mode end
    app.enabled=true; app.worker=true
    task.spawn(function()
        local ok,err=pcall(app.config.mode=='climb' and runClimbLoop or runLoop)
        app.enabled=false; app.worker=false
        if not ok and tostring(err)~='__STOP__' then
            setStatus('ERROR: '..tostring(err))
        else setStatus('Stopped') end
    end)
end

-- Origin UI styling: same palettes, Gotham typography, rounded panels and tab layout.
local palettes={
    Midnight={bg='0D1320',side='101A2B',panel='172338',row='22334D',text='EFF5FF',muted='96ABC8',accent='8BAFFF',line='2B405D'},
    Emerald={bg='101C18',side='152B24',panel='1C372D',row='29463A',text='EFFFF4',muted='A0C8B0',accent='60D8A8',line='3E6454'},
    Violet={bg='171322',side='20192E',panel='2B213C',row='392C50',text='F6EFFF',muted='B8A8D4',accent='BC8AFF',line='534267'},
    Light={bg='F2F5FC',side='E7EDF8',panel='FFFFFF',row='EAF0FA',text='14213A',muted='526781',accent='4264D9',line='D1DBED'},
}
local skins={}
local function color(role)
    local hex=palettes[app.config.theme][role]
    return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
end
local function make(class,parent,props)
    local obj=Instance.new(class)
    for k,v in pairs(props or {}) do obj[k]=v end
    if obj:IsA('GuiObject') then obj.Selectable=false end
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
    return obj
end
local root=make('ScreenGui',playerGui,{Name='AnimeDuelScript',ResetOnSpawn=false,
    DisplayOrder=100,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
app.Root=root
local main=panel(root,{Name='Window',Position=UDim2.new(.5,-360,.5,-260),Size=UDim2.fromOffset(720,520),BorderSizePixel=0})
skin(main,'BackgroundColor3','bg')
local header=make('Frame',main,{Size=UDim2.new(1,0,0,58),BackgroundTransparency=1})
local title=text(header,'ANIME DUEL SCRIPT',true)
title.TextSize=17;title.Position=UDim2.fromOffset(18,11);title.Size=UDim2.new(1,-110,0,23)
local subtitle=text(header,'DRAFT CONTROL CENTER',false)
subtitle.TextSize=10;subtitle.Position=UDim2.fromOffset(19,35);subtitle.Size=UDim2.new(1,-110,0,16)
local minimize=button(header,'—',UDim2.fromOffset(30,28));minimize.Position=UDim2.new(1,-76,0,15)
local hide=button(header,'×',UDim2.fromOffset(30,28));hide.Position=UDim2.new(1,-40,0,15)
local restore=button(root,'AD',UDim2.fromOffset(44,38));restore.Position=UDim2.fromOffset(10,110)
local nav=make('Frame',main,{Position=UDim2.fromOffset(0,58),Size=UDim2.new(0,140,1,-58),BorderSizePixel=0})
skin(nav,'BackgroundColor3','side')
local body=make('Frame',main,{Position=UDim2.fromOffset(140,58),Size=UDim2.new(1,-140,1,-58),BackgroundTransparency=1})
local pages,navButtons={},{}
local selected='Draft'
for i,name in ipairs({'Draft','Climb','Settings','Config'}) do
    local b=button(nav,name,UDim2.new(1,-16,0,38));b.Position=UDim2.fromOffset(8,12+(i-1)*46)
    navButtons[name]=b
    local page=make('ScrollingFrame',body,{Name=name,Size=UDim2.fromScale(1,1),Visible=name==selected,
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
    make('UIPadding',page,{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
    make('UIListLayout',page,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
    pages[name]=page
    track(b.Activated,function()
        selected=name
        for key,p in pairs(pages) do p.Visible=key==name end
        render()
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
local controls=row('Draft','Automation',69)
local start=button(controls,'START',UDim2.new(.5,-18,0,30));start.Position=UDim2.fromOffset(12,31)
local stop=button(controls,'STOP',UDim2.new(.5,-18,0,30));stop.Position=UDim2.new(.5,6,0,31)
track(start.Activated,function() app.start('draft') end);track(stop.Activated,app.stop)
local statusLabel=status('Status')
local runLabel=status('Run / Boss / Recovery')
local teamLabel=status('Current team')
local scoreLabel=status('Session results')
local hint=row('Draft','Strategy',76)
local hintText=text(hint,'Easy → Medium → Hard → Boss 1 / 2 / 3\nAfter each fight: Open packs → Auto Team')
hintText.Position=UDim2.fromOffset(12,29);hintText.Size=UDim2.new(1,-24,0,40);hintText.TextWrapped=true
local climbControls=row('Climb','Auto Draft Climb',69)
local climbStart=button(climbControls,'START CLIMB',UDim2.new(.5,-18,0,30));climbStart.Position=UDim2.fromOffset(12,31)
local climbStop=button(climbControls,'STOP',UDim2.new(.5,-18,0,30));climbStop.Position=UDim2.new(.5,6,0,31)
track(climbStart.Activated,function() app.start('climb') end)
track(climbStop.Activated,app.stop)
local function climbStatusRow(label)
    local r=row('Climb',label,76)
    local l=text(r,'--');l.Position=UDim2.fromOffset(12,29);l.Size=UDim2.new(1,-24,0,40);l.TextWrapped=true
    return l
end
local climbStatusLabel=climbStatusRow('Climb status')
local climbProgressLabel=climbStatusRow('Run / Floor')
local climbTeamLabel=climbStatusRow('Climb team')
local climbInfo=climbStatusRow('How it works')
climbInfo.Text='Saiyan Prince and Atomic are banned at every border. Enable native Auto Climb. STOP only stops this picker; disable native Auto Climb before switching to Draft.'
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
        render()
    end)
end
numberInput('Farm wins after a farm loss (1–20)','farm',1,20)
numberInput('Hard wins after a boss loss (1–20)','bossFarm',1,20)
numberInput('Action delay, seconds (0.5–5)','delay',.5,5)
numberInput('Fight timeout, seconds (30–600)','timeout',30,600)
local themeRow=row('Settings','Theme',69)
local themeButton=button(themeRow,'Midnight',UDim2.new(1,-24,0,29));themeButton.Position=UDim2.fromOffset(12,31)
local themeNames={'Midnight','Emerald','Violet','Light'}
track(themeButton.Activated,function()
    local i=table.find(themeNames,app.config.theme) or 1
    app.config.theme=themeNames[i%#themeNames+1];themeButton.Text=app.config.theme
    for _,entry in ipairs(skins) do entry[1][entry[2]]=color(entry[3]) end
    render()
end)
numberInput('Window transparency % (0–65)','transparency',0,65)
local function settingToggle(label,key)
    local r=row('Settings',label,69)
    local b=button(r,'',UDim2.new(1,-24,0,29));b.Position=UDim2.fromOffset(12,31)
    track(b.Activated,function() app.config[key]=not app.config[key];render() end)
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
for _,entry in ipairs({{'Save settings','SAVE','saveProfile'},{'Load settings (stop Draft first)','LOAD','loadProfile'},
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
render=function()
    if not app.alive then return end
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
    climbStart.Text=app.worker and (app.enabled and 'RUNNING' or 'STOPPING') or 'START CLIMB'
    climbStart.Active=not app.worker
    local climb=app.snapshot and app.snapshot.climb
    local cr=type(climb)=='table' and climb.run
    climbStatusLabel.Text=app.config.mode=='climb' and (app.climbStatus or app.status) or 'Climb standby — current mode: Draft'
    if app.config.mode=='climb' and not app.enabled then climbStatusLabel.Text=app.status end
    climbProgressLabel.Text=type(cr)=='table' and ('#'..tostring(climbId(cr))..' / Floor '..tostring(cr.floor or cr.Floor)..' / '..tostring(cr.over or cr.Over or 'active')) or 'No climb running'
    local ct=climbTeam(cr)
    climbTeamLabel.Text=type(ct)=='table' and table.concat(ct,' / ') or '--'
    for name,b in pairs(navButtons) do b.BackgroundColor3=color(name==selected and 'accent' or 'row');b.TextColor3=color(name==selected and 'bg' or 'text') end
    main.BackgroundTransparency=app.config.transparency/100
    reconnectToggle.Text=app.config.autoReconnect and 'ON' or 'OFF'
    autoStartToggle.Text=app.config.autoStart and 'ON' or 'OFF'
    reconnectLabel.Text=app.config.autoReconnect and app.reconnect.status or 'OFF'
    configLabel.Text=app.profiles.status..' / '..app.profiles.current..' / Auto: '..(app.profiles.auto or 'OFF')
    savedLabel.Text=table.concat(app.profiles.names,', ')
    for key,box in pairs(configInputs) do if not box:IsFocused() then box.Text=tostring(app.config[key]) end end
    themeButton.Text=app.config.theme
    if paintedTheme~=app.config.theme then
        paintedTheme=app.config.theme
        for _,entry in ipairs(skins) do entry[1][entry[2]]=color(entry[3]) end
    end
end
local minimized=false
local compact=false
local drag=nil
local function layout()
    local camera=Workspace.CurrentCamera
    local view=camera and camera.ViewportSize or Vector2.new(1280,720)
    compact=view.X<620
    local w=math.min(720,math.max(240,view.X-16))
    local h=math.min(520,math.max(220,view.Y-16))
    main.Size=UDim2.fromOffset(w,minimized and 58 or h)
    local x=math.clamp(main.Position.X.Offset,8,math.max(8,view.X-w-8))
    local y=math.clamp(main.Position.Y.Offset,8,math.max(8,view.Y-(minimized and 58 or h)-8))
    main.Position=UDim2.fromOffset(x,y)
    nav.Position=UDim2.fromOffset(0,58)
    nav.Size=compact and UDim2.new(1,0,0,46) or UDim2.new(0,140,1,-58)
    body.Position=UDim2.fromOffset(compact and 0 or 140,compact and 104 or 58)
    body.Size=compact and UDim2.new(1,0,1,-104) or UDim2.new(1,-140,1,-58)
    nav.Visible=not minimized;body.Visible=not minimized
    for i,name in ipairs({'Draft','Climb','Settings','Config'}) do
        local b=navButtons[name]
        b.Position=compact and UDim2.new((i-1)/4,5,0,4) or UDim2.fromOffset(8,12+(i-1)*46)
        b.Size=compact and UDim2.new(1/4,-10,0,36) or UDim2.new(1,-16,0,38)
    end
end
local cameraConnection
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if Workspace.CurrentCamera then cameraConnection=track(Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'),layout) end
    drag=nil;layout()
end
track(Workspace:GetPropertyChangedSignal('CurrentCamera'),bindCamera)
track(minimize.Activated,function() minimized=not minimized;layout() end)
track(hide.Activated,function() main.Visible=false;drag=nil end)
track(restore.Activated,function() main.Visible=not main.Visible;drag=nil end)
track(UIS.InputBegan,function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightShift then main.Visible=not main.Visible;drag=nil end
end)
track(header.InputBegan,function(input)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    local x=input.Position.X-header.AbsolutePosition.X
    if x>=header.AbsoluteSize.X-85 then return end
    drag={input=input,at=input.Position,position=main.Position}
end)
track(UIS.InputChanged,function(input)
    if not drag or not main.Visible then return end
    if input.UserInputType==Enum.UserInputType.MouseMovement or input==drag.input then
        local delta=input.Position-drag.at
        main.Position=UDim2.fromOffset(drag.position.X.Offset+delta.X,drag.position.Y.Offset+delta.Y)
    end
end)
track(UIS.InputEnded,function(input)
    if drag and (input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then drag=nil;layout() end
end)
function app.destroy()
    app.stop();app.alive=false
    for _,connection in ipairs(app.connections) do connection:Disconnect() end
    table.clear(app.connections)
    root:Destroy()
end
bindCamera()
local view=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
main.Position=UDim2.fromOffset(math.max(8,(view.X-main.Size.X.Offset)/2),math.max(8,(view.Y-main.Size.Y.Offset)/2))
layout();render()
setStatus('Ready — press START. Right Shift / AD hides or shows UI.')
monitorConnection()
if autoLoaded and app.config.autoStart then app.start() end
