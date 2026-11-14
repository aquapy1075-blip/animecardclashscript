-- Origin Story - UI adapted from aquapy1075-blip/animecardclashscript/anime_origin_ui.lua
-- Upstream SHA: 543f7f2b12f690f6b6592dcf10d805807fe2c29b
-- Standalone: embeds the adapted Origin UI; no remote code download.
-- Combat tracking uses server BattleEnd events matched to the admitted battleId.
repeat task.wait() until game:IsLoaded()
local Dungeon=(function()
local Dungeon={}
function Dungeon.highest(config,view)
    if type(view)~='table' or type(view.best)~='table' then return nil end
    local highest
    for i,id in ipairs(config.Order) do if config.isUnlocked(view,id) then highest=i end end
    return highest
end
function Dungeon.firstUncleared(config,view,ceiling,start)
    for i=start or 1,ceiling do
        local id=config.Order[i]
        if config.isUnlocked(view,id) and (tonumber(view.best[id]) or 0)<(config.Floors or 100) then return i end
    end
    return nil
end
function Dungeon.event(run,event)
    if type(run)~='table' or type(event)~='table' or event.type~='dungeon' or type(event.run)~='table' then return nil end
    if event.run.id~=run.id or event.run.gate~=run.gate then return nil end
    if event.phase=='cleared' then return 'win' end
    if run.gate=='Red' and event.phase=='floor' and type(event.run.floor)=='number' and event.run.floor>100 then return 'win' end
    -- Losing one heart is not the end of the run; native autoplay continues.
    if event.phase=='down' or event.phase=='fallen' then return 'loss' end
    return nil
end
function Dungeon.next(index,outcome,ceiling)
    if outcome~='win' or index>=ceiling then return nil end
    return index+1
end
local statOrder={'luk','str','vit','agi','sen'}
function Dungeon.priority(value)
    local result,seen={},{}
    if type(value)=='table' then
        for _,id in ipairs(value) do
            if type(id)=='string' then
                id=id:lower()
                for _,known in ipairs(statOrder) do if id==known and not seen[id] then seen[id]=true;result[#result+1]=id end end
            end
        end
    end
    for _,id in ipairs(statOrder) do if not seen[id] then result[#result+1]=id end end
    return result
end
function Dungeon.editPriority(value,index,id)
    local order=Dungeon.priority(value)
    id=type(id)=='string' and id:lower() or ''
    if type(index)~='number' or index<1 or index>5 or index%1~=0 then return order end
    for i,known in ipairs(order) do if known==id then order[index],order[i]=order[i],order[index];break end end
    return order
end
function Dungeon.allocate(config,view,priority)
    local points=type(view)=='table' and view.points
    if type(points)~='table' or type(points.earned)~='number' or points.earned<0 or points.earned%1~=0 then return nil,'Waiting for verified System points' end
    local free=points.earned
    for _,id in ipairs(statOrder) do
        local n=points[id]
        if type(n)~='number' or n<0 or n%1~=0 then return nil,'Waiting for verified System stats' end
        free=free-n
    end
    if free<=0 then return nil,'Waiting for System points' end
    local spend={str=0,vit=0,agi=0,sen=0,luk=0};local total=0
    for _,id in ipairs(Dungeon.priority(priority)) do
        local cap=config.statLimit(view,id)
        if type(cap)~='number' or cap<0 or cap%1~=0 then return nil,'Unknown System stat limit' end
        local amount=math.min(free,math.max(0,cap-points[id]))
        spend[id]=amount;free=free-amount;total=total+amount
    end
    if total==0 then return nil,'Current System limits reached; clear higher gates' end
    return spend
end
return Dungeon

end)()
local AfkRuntime=(function()
local AfkRuntime={}
function AfkRuntime.start(ctx)
    local state,flags=ctx.state,ctx.flags
    local runtime={cpu=false,white=false,stopped=false}
    local function service(name) local ok,s=pcall(function() return ctx.game:GetService(name) end);return ok and s or nil end
    local run=service('RunService');local virtual=service('VirtualUser')
    local overlay;local previousFPS;local previousRendering=true;local renderingChanged=false
    local warned={};local lastIdle=-math.huge
    local function noticeOnce(key,text)
        if warned[key] then return end;warned[key]=true
        if ctx.notice then ctx.notice(text,'warning') end
    end
    if ctx.player.Idled and type(ctx.player.Idled.Connect)=='function' then
        state.connections[#state.connections+1]=ctx.player.Idled:Connect(function()
            if not state.alive or runtime.stopped or not flags.AntiAFK or os.clock()-lastIdle<60 then return end
            lastIdle=os.clock()
            local ok=pcall(function()
                assert(virtual,'VirtualUser unavailable')
                virtual:CaptureController()
                virtual:ClickButton2(Vector2.new(0,0))
            end)
            if not ok then noticeOnce('idle','Anti-AFK input is unavailable in this executor.') end
        end)
    end
    local function createOverlay()
        if overlay then return end
        local gui=Instance.new('ScreenGui');gui.Name='AnimeCardOnlineWhiteScreen';gui.ResetOnSpawn=false
        gui.IgnoreGuiInset=true;gui.DisplayOrder=9899;gui.Enabled=false
        local frame=Instance.new('Frame');frame.Name='WhiteBackground';frame.Size=UDim2.fromScale(1,1)
        frame.BorderSizePixel=0;frame.BackgroundColor3=Color3.new(1,1,1);frame.Active=false;frame.Parent=gui
        local exit=Instance.new('TextButton');exit.Name='ShowGame';exit.Text='Show game'
        exit.Size=UDim2.fromOffset(140,38);exit.Position=UDim2.new(1,-156,1,-54)
        exit.BackgroundColor3=Color3.fromRGB(235,238,245);exit.TextColor3=Color3.fromRGB(25,32,48)
        exit.Font=Enum.Font.GothamMedium;exit.TextSize=14;exit.BorderSizePixel=0;exit.Parent=gui
        local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,10);corner.Parent=exit
        state.connections[#state.connections+1]=exit.Activated:Connect(function()
            if state.alive and not runtime.stopped then ctx.setFlag('WhiteScreen',false) end
        end)
        gui.Parent=ctx.playerGui;overlay=gui
    end
    function runtime.apply()
        if runtime.stopped or not state.alive then return end
        local cpu=flags.SaveCPU==true
        if cpu~=runtime.cpu then
            if cpu then
                previousFPS=60
                if type(getfpscap)=='function' then
                    local ok,value=pcall(getfpscap)
                    if ok and type(value)=='number' and value==value and value>=0 and value<10000 then previousFPS=value end
                end
                if type(setfpscap)=='function' then
                    local ok=pcall(setfpscap,15)
                    if not ok then noticeOnce('fps','Save CPU: executor could not set the FPS cap.') end
                else noticeOnce('fps','Save CPU: FPS cap API unavailable; only script UI refresh is reduced.') end
            elseif type(setfpscap)=='function' and previousFPS~=nil then pcall(setfpscap,previousFPS) end
            runtime.cpu=cpu
        end
        local white=flags.WhiteScreen==true
        if white~=runtime.white then
            if white then
                local ok=pcall(createOverlay)
                if ok and overlay then overlay.Enabled=true else noticeOnce('overlay','White Screen overlay could not be created.') end
                local got,value=pcall(function() return run:Is3dRenderingEnabled() end)
                previousRendering=true
                if got and type(value)=='boolean' then previousRendering=value end
                renderingChanged=pcall(function() run:Set3dRenderingEnabled(false) end)
                if not renderingChanged then noticeOnce('render','White Screen is visible, but disabling 3D rendering is unavailable.') end
            else
                if overlay then overlay.Enabled=false end
                if renderingChanged then pcall(function() run:Set3dRenderingEnabled(previousRendering) end);renderingChanged=false end
            end
            runtime.white=white
        end
    end
    function runtime.stop()
        if runtime.stopped then return end
        runtime.stopped=true
        if runtime.cpu and type(setfpscap)=='function' and previousFPS~=nil then pcall(setfpscap,previousFPS) end
        if renderingChanged then pcall(function() run:Set3dRenderingEnabled(previousRendering) end) end
        renderingChanged=false;runtime.cpu=false;runtime.white=false
        if overlay then pcall(function() overlay:Destroy() end);overlay=nil end
    end
    runtime.apply()
    return runtime
end
return AfkRuntime

end)()
local SessionRuntime=(function()
local SessionRuntime={}
function SessionRuntime.start(ctx)
    local game,player,state,flags,env=ctx.game,ctx.player,ctx.state,ctx.flags,ctx.env
    local runtime={queued=false,attempts=0,busy=false,nextTry=0}
    local pref='OriginStory/autoexec.json'
    local ownedLoader='autoexec/AnimeCardOnline-aquacodex.lua'
    local source='https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/codex/origin-story-ui-draft/origin_story.lua'
    local function service(name) local ok,value=pcall(function() return game:GetService(name) end);return ok and value or nil end
    local http=service('HttpService');local teleport=service('TeleportService');local gui=service('GuiService');local core=service('CoreGui')
    local function connect(signal,callback)
        if signal and type(signal.Connect)=='function' then state.connections[#state.connections+1]=signal:Connect(callback) end
    end
    local function notice(text,kind) if ctx.notice then ctx.notice(text,kind or 'info') end end
    local function queueAPI()
        if type(queue_on_teleport)=='function' then return queue_on_teleport end
        if type(queueonteleport)=='function' then return queueonteleport end
        if type(syn)=='table' and type(syn.queue_on_teleport)=='function' then return syn.queue_on_teleport end
        return nil
    end
    -- Queued jobs cannot always be removed. A persisted OFF switch makes this loader a no-op.
    local boot=([=[
local ok,allowed=pcall(function()
    if type(isfile)=='function' and type(readfile)=='function' and isfile('OriginStory/autoexec.json') then
        return game:GetService('HttpService'):JSONDecode(readfile('OriginStory/autoexec.json')).enabled==true
    end
    return true
end)
if not ok or not allowed then return end
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3)
local session=(getgenv and getgenv()) or _G
if session.AnimeCardOnlineAutoBooting or (session.OriginStory and session.OriginStory.alive and session.OriginStory.serverId==game.JobId) then return end
session.AnimeCardOnlineAutoBooting=true
local success,err=pcall(function() loadstring(game:HttpGet('%s'))() end)
session.AnimeCardOnlineAutoBooting=false
if not success then warn('Anime Card Online autoexec failed: '..tostring(err)) end
]=]):format(source)
    local universe=tonumber(game.GameId);local place=tonumber(game.PlaceId)
    if universe and universe>0 then boot=('if game.GameId~=%d then return end\n'):format(universe)..boot
    elseif place and place>0 then boot=('if game.PlaceId~=%d then return end\n'):format(place)..boot end
    local function syncOwnedLoader()
        if flags.AutoExec then
            if type(isfolder)=='function' and type(writefile)=='function' then
                local ok,exists=pcall(isfolder,'autoexec')
                if ok and exists then local saved=pcall(writefile,ownedLoader,boot);return saved end
            end
        elseif type(isfile)=='function' and type(delfile)=='function' then
            pcall(function() if isfile(ownedLoader) then delfile(ownedLoader) end end)
        end
        return false
    end
    flags.AutoExec=false
    if http and type(http.JSONDecode)=='function' and type(isfile)=='function' and type(readfile)=='function' then
        local ok,value=pcall(function() if isfile(pref) then return http:JSONDecode(readfile(pref)) end end)
        if ok and type(value)=='table' then flags.AutoExec=value.enabled==true end
    end
    function runtime.setAutoExec(value)
        flags.AutoExec=value==true
        local saved=false
        if http and type(http.JSONEncode)=='function' and type(writefile)=='function' then
            saved=pcall(function() if type(makefolder)=='function' then pcall(makefolder,'OriginStory') end;writefile(pref,http:JSONEncode({enabled=flags.AutoExec})) end)
        end
        local installed=syncOwnedLoader()
        if flags.AutoExec then
            if not queueAPI() and not installed then notice('Autoexec: executor has no teleport queue or writable autoexec folder.','warning')
            elseif not saved then notice('Autoexec ON for this session; executor cannot persist the switch.','warning') end
        end
        return saved
    end
    function runtime.queue()
        if not state.alive or not flags.AutoExec or runtime.queued then return false end
        local api=queueAPI();if not api then return false end
        local ok=pcall(api,boot)
        if ok then runtime.queued=true else notice('Executor could not queue autoexec.','warning') end
        return ok
    end
    local function teleportName(value)
        local text=tostring(value);return text:match('([%w_]+)$') or text
    end
    connect(player.OnTeleport,function(phase)
        local name=teleportName(phase)
        if name=='Started' or name=='InProgress' then runtime.queue() end
    end)
    connect(teleport and teleport.TeleportInitFailed,function(who)
        if who==player and runtime.busy then runtime.busy=false end
    end)
    local function disconnected()
        if gui and type(gui.GetErrorMessage)=='function' then
            local ok,message=pcall(function() return gui:GetErrorMessage() end)
            if ok and type(message)=='string' and message:match('%S') then return true end
        end
        if core and type(core.FindFirstChild)=='function' then
            local ok,visible=pcall(function()
                local promptGui=core:FindFirstChild('RobloxPromptGui')
                local overlay=promptGui and promptGui:FindFirstChild('promptOverlay')
                local prompt=overlay and overlay:FindFirstChild('ErrorPrompt')
                return promptGui and promptGui.Enabled~=false and overlay and overlay.Visible~=false and prompt and prompt.Visible==true
            end)
            if ok and visible then return true end
        end
        return false
    end
    function runtime.rejoin()
        if runtime.manualRejoining or not state.alive then return end
        if not teleport then notice('TeleportService unavailable.','error');return end
        runtime.manualRejoining=true
        notice('Rejoining server...','info')
        task.spawn(function()
            local ok,err=pcall(function()
                if type(game.JobId)=='string' and game.JobId~='' then
                    teleport:TeleportToPlaceInstance(game.PlaceId,game.JobId,player)
                else
                    teleport:Teleport(game.PlaceId,player)
                end
            end)
            if not ok then runtime.manualRejoining=false;notice('Rejoin failed: '..tostring(err),'error');return end
            task.delay(20,function() runtime.manualRejoining=false end)
        end)
    end
    local function attemptRejoin()
        runtime.attempts=runtime.attempts+1;runtime.busy=true;runtime.started=os.clock()
        runtime.nextTry=os.clock()+math.min(60,2^runtime.attempts)
        if not teleport or type(teleport.Teleport)~='function' then runtime.busy=false;return end
        -- OnTeleport queues only when Autoexec is enabled. Rejoin itself is always enabled.
        local ok=pcall(function() teleport:Teleport(game.PlaceId,player) end)
        if not ok then runtime.busy=false end
    end
    task.spawn(function()
        while state.alive do
            if disconnected() then
                if not runtime.detected then runtime.detected=os.clock();runtime.nextTry=os.clock()+2 end
                if runtime.busy and os.clock()-(runtime.started or 0)>20 then runtime.busy=false end
                if not runtime.busy and runtime.attempts<6 and os.clock()>=runtime.nextTry then attemptRejoin() end
            else
                runtime.detected=nil;runtime.attempts=0;runtime.busy=false
            end
            task.wait(1)
        end
    end)
    task.spawn(function()
        local market=service('MarketplaceService')
        if not market or type(market.GetProductInfo)~='function' then return end
        local ok,info=pcall(function() return market:GetProductInfo(game.PlaceId) end)
        local id=ok and type(info)=='table' and tonumber(info.IconImageAssetId)
        if state.alive and id and id>0 then state.gameIcon='rbxassetid://'..tostring(id) end
    end)
    syncOwnedLoader()
    return runtime
end
return SessionRuntime

end)()
local ActiveRules=(function()
local ActiveRules={}
ActiveRules.Modes={'Combat start','Low HP','Round'}
local function finite(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function integer(v,default,min,max)
    v=tonumber(v);if not finite(v) then return default end
    return math.max(min,math.min(max,math.floor(v)))
end
local function identity(v) return type(v)=='string' and #v>0 and #v<=160 end
function ActiveRules.cardId(v) return identity(v) and v:match('^[%w_%-]+$')~=nil end
function ActiveRules.rule(value)
    value=type(value)=='table' and value or {}
    local mode=value.mode
    if mode~='Combat start' and mode~='Low HP' and mode~='Round' then mode='Low HP' end
    return {enabled=value.enabled==true,mode=mode,slot=integer(value.slot,0,0,5),hp=integer(value.hp,50,1,99),round=integer(value.round,3,1,999)}
end
function ActiveRules.normalize(value)
    local out={}
    if type(value)=='table' then for id,rule in pairs(value) do if ActiveRules.cardId(id) and type(rule)=='table' then out[id]=ActiveRules.rule(rule) end end end
    return out
end
function ActiveRules.lane(value)
    if value=='Both lanes' then return value end
    return integer(value,1,1,2)
end
function ActiveRules.lanes(value)
    value=ActiveRules.lane(value)
    return value=='Both lanes' and {1,2} or {value}
end
local function copyCard(card)
    if type(card)~='table' then return nil end
    local slot=tonumber(card.slot)
    if not finite(slot) or slot%1~=0 or slot<1 or slot>5 then return nil end
    return {slot=slot,cardId=card.cardId,name=card.name,currentHP=card.currentHP,maxHP=card.maxHP,abilityOff=card.abilityOff}
end
function ActiveRules.new(history)
    history=type(history)=='table' and history or {}
    history.order=type(history.order)=='table' and history.order or {}
    history.marked=type(history.marked)=='table' and history.marked or {}
    history.confirmed=type(history.confirmed)=='table' and history.confirmed or {}
    return {lanes={},closed={},closedOrder={},history=history,known={}}
end
local function close(store,id)
    if store.closed[id] then return end
    store.closed[id]=true;store.closedOrder[#store.closedOrder+1]=id
    if #store.closedOrder>128 then store.closed[table.remove(store.closedOrder,1)]=nil end
end
local function key(entry,id) return entry.lane..':'..#entry.battleId..':'..entry.battleId..':'..id end
function ActiveRules.mark(store,entry,id)
    local k=key(entry,id);local history=store.history
    if history.marked[k] then return end
    history.marked[k]=true;history.order[#history.order+1]=k
    if #history.order>512 then local old=table.remove(history.order,1);history.marked[old]=nil;history.confirmed[old]=nil end
end
function ActiveRules.confirm(store,entry,id)
    ActiveRules.mark(store,entry,id);store.history.confirmed[key(entry,id)]=true
end
function ActiveRules.retryBusy(store,entry,id,response,now)
    if response[1]~=true or response[2]~=false or type(response[3])~='string'
        or response[3]:lower()~='the ability is already resolving' then return false end
    local current=store.lanes[entry.lane]
    if not current or current.battleId~=entry.battleId or store.closed[entry.battleId] or store.history.confirmed[key(entry,id)] then return false end
    local ability=current.abilities[id]
    if not ability or ability.used or ability.queued then return false end
    local retry=current.retries[id] or {count=0,deadline=now+10}
    retry.count=retry.count+1;current.retries[id]=retry
    if retry.count>3 or now>=retry.deadline then return false end
    retry.nextAt=now+math.min(2,.5*2^(retry.count-1))
    local k=key(entry,id);store.history.marked[k]=nil
    for i=#store.history.order,1,-1 do if store.history.order[i]==k then table.remove(store.history.order,i) end end
    return true
end
function ActiveRules.cancelStarts(store)
    for _,entry in pairs(store.lanes) do entry.startReady={} end
end
function ActiveRules.battleData(data)
    if type(data)~='table' then return data end
    if data.lane==nil and identity(data.battleId) and data.battleId:match('^pvp%-') then
        local copy={};for k,v in pairs(data) do copy[k]=v end
        copy.lane=1 -- Same default as the native BattleController._twinAttach.
        return copy
    end
    return data
end
function ActiveRules.snapshot(store,data,now)
    data=ActiveRules.battleData(data)
    if type(data)~='table' or not identity(data.battleId) or (data.lane~=1 and data.lane~=2) then return false end
    local lane=data.lane;local previous=store.lanes[lane]
    if data.active==false then
        close(store,data.battleId)
        if previous and previous.battleId==data.battleId then store.lanes[lane]=nil end
        return true
    end
    if data.active~=true or store.closed[data.battleId] or type(data.player)~='table' or type(data.guestActives)~='table' then return false end
    if previous and previous.battleId~=data.battleId then close(store,previous.battleId) end
    local entry={battleId=data.battleId,lane=lane,round=data.round,updated=now,cards={},abilities={},fresh=data.fresh==true,startReady=previous and previous.battleId==data.battleId and previous.startReady or {},retries=previous and previous.battleId==data.battleId and previous.retries or {}}
    local function add(card) local copy=copyCard(card);if copy then entry.cards[copy.slot]=copy end end
    if type(data.player.hand)=='table' then for _,card in pairs(data.player.hand) do add(card) end end
    add(data.player.active)
    for id,ability in pairs(data.guestActives) do
        if ActiveRules.cardId(id) and type(ability)=='table' then
            entry.abilities[id]={available=ability.available==true and not ability.used and not ability.queued,name=ability.name,id=ability.id,used=ability.used==true,queued=ability.queued==true}
            if ability.used or ability.queued then ActiveRules.confirm(store,entry,id) end
            store.known[id]=ability.name or id
        end
    end
    store.lanes[lane]=entry
    return true
end
function ActiveRules.event(store,event,now)
    event=ActiveRules.battleData(event)
    if type(event)~='table' or not identity(event.battleId) or (event.lane~=1 and event.lane~=2) then return false end
    local entry=store.lanes[event.lane]
    if event.type=='BattleEnd' then
        close(store,event.battleId)
        if entry and entry.battleId==event.battleId then store.lanes[event.lane]=nil end
        return true
    end
    if not entry or entry.battleId~=event.battleId then return false end
    entry.updated=now
    if event.type=='RoundStart' and finite(event.round) then entry.round=event.round end
    if event.side=='player' then
        local card=entry.cards[event.slot]
        if event.type=='GuestActive' and ActiveRules.cardId(event.cardId) then
            ActiveRules.confirm(store,entry,event.cardId)
            if entry.abilities[event.cardId] then entry.abilities[event.cardId].available=false end
        elseif card then
            if event.type=='Death' then card.currentHP=0
            elseif event.type=='Damage' or event.type=='Heal' or event.type=='Stat' or event.type=='Revive' then
                if finite(event.hp) then card.currentHP=event.hp end
                if finite(event.maxHP) then card.maxHP=event.maxHP end
            end
        end
    end
    return true
end
local function alive(card)
    return card and finite(card.currentHP) and finite(card.maxHP) and card.maxHP>0 and card.currentHP>0
end
function ActiveRules.armStarts(entry,rules,now)
    if not entry then return end
    -- Latch every enabled start rule before choosing the first request.
    -- The remaining requests may outlive round 1 while another ability resolves.
    for id,rule in pairs(rules) do
        if not rule.enabled or rule.mode~='Combat start' then entry.startReady[id]=nil
        elseif finite(entry.round) and entry.round<=1 and not entry.startReady[id] then
            local ability=entry.abilities[id]
            if ability and ability.available then
                for _,card in pairs(entry.cards) do
                    if card.cardId==id and alive(card) and not card.abilityOff then entry.startReady[id]=now+10;break end
                end
            end
        end
    end
end
function ActiveRules.candidate(store,lane,rules,now)
    local entry=store.lanes[lane]
    if not entry then return nil,'Waiting for a battle snapshot' end
    if now-entry.updated>8 then return nil,'Waiting for fresh battle data' end
    local ids={};for id,rule in pairs(rules) do if rule.enabled then ids[#ids+1]=id end end;table.sort(ids)
    if #ids==0 then return nil,'Enable a rule for an ability card' end
    ActiveRules.armStarts(entry,rules,now)
    for _,id in ipairs(ids) do
        local rule=rules[id];local ability=entry.abilities[id]
        if ability and ability.available and not store.history.marked[key(entry,id)] and (not entry.retries[id] or now>=entry.retries[id].nextAt) then
            local caster=false
            for _,card in pairs(entry.cards) do if card.cardId==id and alive(card) and not card.abilityOff then caster=true;break end end
            if caster then
                local ready,reason=false,nil
                if rule.mode=='Combat start' then
                    ready=entry.startReady[id]~=nil and now<entry.startReady[id]
                    reason='Combat start'
                elseif rule.mode=='Round' then
                    ready=finite(entry.round) and entry.round>=rule.round;reason='Round '..tostring(entry.round)
                elseif rule.mode=='Low HP' then
                    for slot,card in pairs(entry.cards) do
                        if (rule.slot==0 or rule.slot==slot) and alive(card) and card.currentHP/card.maxHP*100<rule.hp then
                            ready=true;reason=('Slot %d: %.1f%% HP'):format(slot,card.currentHP/card.maxHP*100);break
                        end
                    end
                end
                if ready then return {cardId=id,battleId=entry.battleId,lane=lane},reason,entry end
            end
        end
    end
    return nil,'Watching conditions / ability availability'
end
function ActiveRules.nextCandidate(store,selection,rules,now,preferred)
    local lanes=ActiveRules.lanes(selection)
    if #lanes==2 and preferred==2 then lanes={2,1} end
    local reasons={}
    for _,lane in ipairs(lanes) do
        local payload,reason,entry=ActiveRules.candidate(store,lane,rules,now)
        if payload then return payload,'L'..lane..': '..reason,entry end
        reasons[#reasons+1]='L'..lane..': '..reason
    end
    return nil,table.concat(reasons,' | ')
end
return ActiveRules

end)()
local Story=(function()
-- Story queue: map order, then encounter order, then difficulty order.
local Story = {}
Story.Modes = {'Easy','Medium','Hard','Impossible','Cosmic'}
Story.Worlds = {
    {name='Pirate Shark Park',map='ArlongPark',cards={'Usopp','Nami','Duffy','Zoro','Sanji','Arlong'}},
    {name='Bug Arena',map='CellGames',cards={'SonWarrior','PridefulPrince','AndroidMentor','FutureWarrior','DevouringBug','SonProdigy'}},
    {name='Castle of the Demons',map='CastleOfTheDemons',cards={'SashSickleSiblings','CompassDemon','FrozenLotusDemon','WeepingStoneMonk','SixEyedMoonDemon','FirstDemon'}},
    {name='Diamond Town',map='DiamondTown',cards={'VoidHand','EchoRookie','InkMangaka','DiamondHeart','StarLeader','PeacefulBomber'}},
    {name='Ninja Village',map='NinjaVillage',cards={'RainGod','CrowGenius','WanderingAvenger','TenTailVessel','ValleyLegend','FoxVessel'}},
    {name='Demon Lord Hall',map='DemonLordHall',cards={'HolyKnightCaptain','FlameGeneral','PrimordialButler','DestroyerPrincess','StormDragon','SlimeSovereign'}},
}
function Story.targetOptions(selectedMaps)
    local options={}
    for _,world in ipairs(Story.Worlds) do
        if (selectedMaps or {})[world.map] then
            for i,id in ipairs(world.cards) do
                options[#options+1]=world.name..' / '..id..(i==#world.cards and ' [BOSS]' or '')
            end
        end
    end
    return options
end
function Story.buildQueue(flags)
    local queue={}
    for _,world in ipairs(Story.Worlds) do
        if (flags.StoryMaps or {})[world.map] then
            for index,id in ipairs(world.cards) do
                if (flags.StoryCards or {})[id] then
                    for _,mode in ipairs(Story.Modes) do
                        if ((flags.StoryModes or {})[id] or {})[mode] then
                            queue[#queue+1]={map=world.map,world=world.name,cardId=id,difficulty=mode,boss=index==#world.cards}
                        end
                    end
                end
            end
        end
    end
    return queue
end
function Story.bulkModes(flags,selection,selectedOnly)
    local cards,modes,count={},{},0
    for id,on in pairs(flags.StoryCards or {}) do cards[id]=on end
    for id,set in pairs(flags.StoryModes or {}) do modes[id]=set end
    for _,world in ipairs(Story.Worlds) do
        if (flags.StoryMaps or {})[world.map] then
            for _,id in ipairs(world.cards) do
                if not selectedOnly or cards[id] then
                    local chosen={}
                    for _,mode in ipairs(Story.Modes) do if selection[mode]==true then chosen[mode]=true end end
                    cards[id]=true;modes[id]=chosen;count=count+1
                end
            end
        end
    end
    return cards,modes,count
end
return Story

end)()
local WeatherWebhook=(function()
local WeatherWebhook={}
function WeatherWebhook.url(value)
    if type(value)~='string' then return nil end
    value=value:match('^%s*(.-)%s*$')
    for _,host in ipairs({'discord.com','discordapp.com','canary.discord.com','ptb.discord.com'}) do
        local prefix='https://'..host..'/api/'
        if value:sub(1,#prefix)==prefix then
            local path=value:sub(#prefix+1)
            if path:match('^webhooks/%d+/[%w_%-]+$') or path:match('^v%d+/webhooks/%d+/[%w_%-]+$') then return value end
        end
    end
    return nil
end
function WeatherWebhook.rarest(config)
    local result={};local lowest=math.huge;local total=0
    if type(config)~='table' or type(config.Order)~='table' or type(config.Data)~='table' then return result,0 end
    for _,id in ipairs(config.Order) do
        local def=config.Data[id];local weight=def and def.weight
        if type(weight)=='number' and weight>0 then
            total=total+weight
            if weight<lowest then lowest=weight;result={[id]=true}
            elseif weight==lowest then result[id]=true end
        end
    end
    return result,total>0 and lowest/total or 0
end
function WeatherWebhook.episode(store,server,id,endsAt,now)
    if type(id)~='string' or id=='' or type(endsAt)~='number' or endsAt~=endsAt or endsAt==math.huge or endsAt<=now then
        store[server]=nil;return nil
    end
    local episode=store[server]
    if not episode or episode.id~=id or episode.endsAt<=now then episode={id=id};store[server]=episode end
    -- Extending a running domain is the same occurrence.
    episode.endsAt=endsAt
    return episode
end
local defaultConfig={
    Order={'CaptivatingBeach','CoffinOfDeath','UnyieldingLove','Courtroom','ShrineOfSorrow','InfiniteVoid'},
    Data={
        CaptivatingBeach={name='Horizon of the Captivating Beach',weight=58.4},
        CoffinOfDeath={name='Coffin of Death',weight=30},
        UnyieldingLove={name='Unyielding Love',weight=10},
        Courtroom={name='Judge Courtroom',weight=1},
        ShrineOfSorrow={name='Shrine of Sorrow',weight=.5},
        InfiniteVoid={name='Infinite Void',weight=.1},
        DomainClash={name='Domain Clash',weight=0},
    },
}
function WeatherWebhook.selection(value,legacyClash)
    if type(value)~='table' then return {InfiniteVoid=true,DomainClash=legacyClash~=false or nil} end
    local selected={}
    for id,on in pairs(value) do
        if on==true and type(id)=='string' and #id<=80 and id:match('^[%w_%-]+$') then selected[id]=true end
    end
    return selected
end
function WeatherWebhook.options(config)
    if type(config)~='table' or type(config.Order)~='table' or type(config.Data)~='table' then config=defaultConfig end
    local total=0;local seen={};local order={}
    for _,id in ipairs(config.Order) do
        if type(id)=='string' and type(config.Data[id])=='table' and not seen[id] then
            seen[id]=true;order[#order+1]=id
            local w=config.Data[id].weight
            if type(w)=='number' and w==w and w>0 and w<math.huge then total=total+w end
        end
    end
    local extras={}
    for id,def in pairs(config.Data) do if type(id)=='string' and type(def)=='table' and not seen[id] then extras[#extras+1]=id end end
    table.sort(extras);for _,id in ipairs(extras) do order[#order+1]=id end
    local result={}
    for _,id in ipairs(order) do
        local def=config.Data[id];local w=def.weight
        local chance=seen[id] and type(w)=='number' and w==w and w>0 and w<math.huge and total>0 and w/total*100 or 0
        local text=('%.2f'):format(chance):gsub('0+$',''):gsub('%.$','')..'%'
        local rarity=chance>0 and (text..' random chance') or (text..' random / special event')
        result[#result+1]={id=id,name=def.name or id,chance=chance,reason=rarity,label=(def.name or id)..' · '..text..(chance==0 and ' · special event' or '')}
    end
    return result
end
function WeatherWebhook.target(id,config,selection)
    if type(selection)~='table' or selection[id]~=true then return false end
    for _,option in ipairs(WeatherWebhook.options(config)) do
        if option.id==id then return true,option.reason end
    end
    return false
end
return WeatherWebhook

end)()
local Monitor=(function()
local Monitor={}
local function valid(value)
    return type(value)=='number' and value==value and value>=0 and value~=math.huge
end
function Monitor.new()
    return {bone=nil,war=nil,base=nil,since=nil,updated=nil,source='Waiting for server profile'}
end
function Monitor.bone(model,value,now,source)
    if not valid(value) then return false end
    value=math.floor(value)
    model.bone=value;model.updated=now;model.source=source
    if model.base==nil then model.base=value;model.since=now end
    return true
end
function Monitor.profile(model,data,now)
    if type(data)~='table' or type(data.currency)~='table' then return false end
    local updated=Monitor.bone(model,data.currency.boneTokens,now,'ProfileSync.currency.boneTokens')
    if valid(data.currency.warCoins) then model.war=math.floor(data.currency.warCoins);updated=true end
    return updated
end
function Monitor.raid(model,payload,now)
    if type(payload)=='table' and payload.kind=='Result' and type(payload.data)=='table' then
        return Monitor.bone(model,payload.data.total,now,'SkeletonRaid.Result.data.total')
    end
    return false
end
function Monitor.domain(id,endsAt,by,now,definition)
    if type(id)~='string' or id=='' or not valid(endsAt) or endsAt<=now then return {name='No active domain',remaining=0,boost='--',by='--'} end
    local def=type(definition)=='table' and definition or {}
    local boost='--'
    if type(def.base)=='number' and type(def.pct)=='number' then boost=('+%d luck / +%d%%'):format(def.base,math.floor(def.pct*100+.5)) end
    return {name=def.name or id,id=id,remaining=math.max(0,math.ceil(endsAt-now)),boost=boost,by=type(by)=='string' and by~='' and by or '--'}
end
return Monitor

end)()
local HigherLower=(function()
local HigherLower={}
function HigherLower.choose(run,config)
    if type(run)~='table' or type(run.round)~='number' or run.round<1 or run.round%1~=0 then return nil,'Invalid round' end
    if type(run.a)~='table' or type(run.b)~='table' or type(run.a.key)~='string' or type(run.b.key)~='string' then return nil,'Missing card keys' end
    local left,right=config.entry(run.a.key),config.entry(run.b.key)
    if type(left)~='table' or type(right)~='table' or type(left.total)~='number' or type(right.total)~='number' then return nil,'Unknown card / variant in live stat pool' end
    if run.a.dmg~=nil and run.a.hp~=nil and run.a.dmg+run.a.hp~=left.total then return nil,'Visible stats differ from stat pool' end
    if right.total==left.total then return nil,'Equal stats: no verified higher/lower answer' end
    return right.total>left.total and 'higher' or 'lower',nil,left.total,right.total
end
function HigherLower.advance(run,result)
    if type(result)~='table' then return nil,'Malformed guess response' end
    if result.ended==true then return nil,nil,true end
    if result.correct~=true then return nil,'Server did not confirm a correct guess' end
    if type(result.nextRound)~='number' or result.nextRound%1~=0 or result.nextRound<=run.round
        or type(result.b)~='table' or type(result.next)~='table' then return nil,'Missing / stale next round' end
    return {round=result.nextRound,streak=result.streak,best=result.best,a=result.b,b=result.next}
end
return HigherLower

end)()
local Skills=(function()
local Skills={Data={},Order={}}
Skills.Order[#Skills.Order+1]="Awakening"
Skills.Data["Awakening"]={name="Awakening",maxRank=1,requires={}}
Skills.Order[#Skills.Order+1]="LuckBoost"
Skills.Data["LuckBoost"]={name="Luck Boost",maxRank=1000,requires={Awakening=1}}
Skills.Order[#Skills.Order+1]="SwiftHands"
Skills.Data["SwiftHands"]={name="Swift Hands",maxRank=1500,requires={Awakening=1}}
Skills.Order[#Skills.Order+1]="BorderChance"
Skills.Data["BorderChance"]={name="Border Chance",maxRank=100,requires={Awakening=1}}
Skills.Order[#Skills.Order+1]="BattleSpeed1"
Skills.Data["BattleSpeed1"]={name="Battle Speed I",maxRank=1,requires={Awakening=1}}
Skills.Order[#Skills.Order+1]="FortuneFlow"
Skills.Data["FortuneFlow"]={name="Fortune Flow",maxRank=250,requires={LuckBoost=100}}
Skills.Order[#Skills.Order+1]="CoinAffinity"
Skills.Data["CoinAffinity"]={name="Coin Affinity",maxRank=1000,requires={LuckBoost=50,SwiftHands=200}}
Skills.Order[#Skills.Order+1]="RapidDraw"
Skills.Data["RapidDraw"]={name="Rapid Draw",maxRank=1000,requires={SwiftHands=350}}
Skills.Order[#Skills.Order+1]="BossChance"
Skills.Data["BossChance"]={name="Boss Chance",maxRank=100,requires={BorderChance=25}}
Skills.Order[#Skills.Order+1]="BattleSpeed2"
Skills.Data["BattleSpeed2"]={name="Battle Speed II",maxRank=1,requires={BattleSpeed1=1}}
Skills.Order[#Skills.Order+1]="Windwalker"
Skills.Data["Windwalker"]={name="Windwalker",maxRank=1000,requires={RapidDraw=400,CoinAffinity=300}}
Skills.Order[#Skills.Order+1]="PotionDuration"
Skills.Data["PotionDuration"]={name="Potion Duration",maxRank=100,requires={BossChance=25}}
Skills.Order[#Skills.Order+1]="BattleSpeed3"
Skills.Data["BattleSpeed3"]={name="Battle Speed III",maxRank=1,requires={BattleSpeed2=1}}
Skills.Order[#Skills.Order+1]="ElderAscension"
Skills.Data["ElderAscension"]={name="Elder Ascension",maxRank=1,requires={FortuneFlow=100,Windwalker=400,PotionDuration=100}}
Skills.Order[#Skills.Order+1]="BattleSpeed4"
Skills.Data["BattleSpeed4"]={name="Battle Speed IV",maxRank=1,requires={BattleSpeed3=1}}
Skills.Order[#Skills.Order+1]="TwinBattle"
Skills.Data["TwinBattle"]={name="Twin Battle",maxRank=1,requires={BattleSpeed4=1}}
function Skills.plan(selected,ranks,withPrerequisites)
    local goals={}
    local function requireGoal(id,rank)
        local def=Skills.Data[id]
        if not def then return end
        rank=math.min(rank,def.maxRank)
        if (goals[id] or 0)>=rank then return end
        goals[id]=rank
        if withPrerequisites then
            for need,level in pairs(def.requires) do requireGoal(need,level) end
        end
    end
    for _,id in ipairs(Skills.Order) do
        if selected[id] then requireGoal(id,Skills.Data[id].maxRank) end
    end
    local plan={}
    for _,id in ipairs(Skills.Order) do
        local goal=goals[id]
        if goal and (not ranks or (ranks[id] or 0)<goal) then
            local unlocked=true
            if ranks then
                for need,level in pairs(Skills.Data[id].requires) do
                    if (ranks[need] or 0)<level then unlocked=false end
                end
            end
            if unlocked then plan[#plan+1]={id=id,goal=goal,prerequisite=not selected[id]} end
        end
    end
    return plan,goals
end
return Skills

end)()
local Combat=(function()
-- Server protocol verified from captured StartResponse and BattleEnd messages.
local Combat = {}
function Combat.new()
    return {started=false,ended=false,results={},order={}}
end
function Combat.match(attempt,event)
    if type(event)~='table' or event.type~='BattleEnd' or type(event.won)~='boolean' then return false end
    if not attempt.battleId or event.battleId~=attempt.battleId then return false end
    if event.lane~=nil and attempt.lane~=nil and event.lane~=attempt.lane then return false end
    if event.difficulty~=nil and attempt.difficulty~=nil and event.difficulty~=attempt.difficulty then return false end
    return true
end
function Combat.event(attempt,event)
    if type(event)~='table' or event.type~='BattleEnd' or type(event.battleId)~='string' or type(event.won)~='boolean' then return end
    if attempt.battleId then
        if Combat.match(attempt,event) and not attempt.ended then
            attempt.ended=true;attempt.won=event.won
        end
    else
        -- A fast result may arrive before InvokeServer returns its admission snapshot.
        if not attempt.results[event.battleId] then attempt.order[#attempt.order+1]=event.battleId end
        attempt.results[event.battleId]=event
        if #attempt.order>32 then attempt.results[table.remove(attempt.order,1)]=nil end
    end
end
function Combat.accept(attempt,response,item)
    local snapshot=response[4]
    if response[1]~=true or response[2]~=true or type(snapshot)~='table' then return false end
    local portrait=snapshot.enemy and snapshot.enemy.portrait
    if snapshot.active~=true or snapshot.fresh~=true or type(snapshot.battleId)~='string'
        or type(portrait)~='table' or portrait.cardId~=item.cardId then return false end
    attempt.started=true;attempt.battleId=snapshot.battleId;attempt.lane=snapshot.lane;attempt.difficulty=item.difficulty
    local buffered=attempt.results[attempt.battleId]
    if buffered then Combat.event(attempt,buffered) end
    attempt.results={};attempt.order={}
    return true
end
return Combat

end)()
local Library=(function()
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
    if not TweenService then for key,value in pairs(properties) do obj[key]=value end;return end
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
    local s=make('UIStroke',obj,{Thickness=1,Transparency=0.15})
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
        TextSize=size or 13,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0,
    })
    skin(l,'TextColor3',bold and 'text' or 'muted')
    if bold then gradientText(l) end
    return l
end
local function uiButton(parent,caption,size)
    local b=make('TextButton',parent,{
        Text=caption,Size=size or UDim2.fromOffset(135,32),
        BackgroundTransparency=0,BorderSizePixel=0,
        Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=true,
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
    Name='OriginStoryUI',ResetOnSpawn=false,IgnoreGuiInset=true,
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
local bigTitle=newText(header,'Anime Card Online',17,true)
bigTitle.Position=UDim2.fromOffset(62,10)
bigTitle.Size=UDim2.fromOffset(250,22)
local smallTitle=newText(header,'made by aquacodex',11,false)
smallTitle.Position=UDim2.fromOffset(63,32)
smallTitle.Size=UDim2.fromOffset(260,16)
local sessionBadge=newText(header,'● READY',11,true)
sessionBadge.Position=UDim2.new(1,-190,0,20)
sessionBadge.Size=UDim2.fromOffset(105,20)
local hide=uiButton(header,'—',UDim2.fromOffset(30,28))
hide.Position=UDim2.new(1,-77,0,14)
local dismiss=uiButton(header,'×',UDim2.fromOffset(30,28))
dismiss.Position=UDim2.new(1,-42,0,14)

local sidebar=make('ScrollingFrame',main,{
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
local selectedTab='Story'
local navButtons={}
local tabPages={}
local tabNames={'Monitor','Story','Guess Minigame','Skill Tree','Combat Helper','Dungeon','War Boss','Ranked','Config','Settings'}
for i,name in ipairs(tabNames) do
    local tab=uiButton(sidebar,string.format('%02d   %s',i,name),UDim2.new(1,-20,0,39))
    make('UIGradient',tab,{Rotation=30,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(155,195,240))})
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
        smallTitle.Text='made by aquacodex'
        for title,p in pairs(tabPages) do p.Visible=(title==name) end
        page.Position=UDim2.fromOffset(0,9)
        animate(page,{Position=UDim2.fromOffset(0,0)},.18)
        repaintControls()
    end)
end
local widgets={}
local statusLabels={}
local orderCounter=0
local function section(tab,label)
    orderCounter=orderCounter+1
    local t=newText(tabPages[tab],string.upper(label),12,true)
    t.Size=UDim2.new(1,0,0,30)
    gradientText(t)
    t.LayoutOrder=orderCounter
    local sectionRoles={'violet','mint','gold','rose'}
    gradientText(t)
    return t
end
local function row(tab,label)
    orderCounter=orderCounter+1
    local parent=tabPages[tab]
    local r=make('Frame',parent,{
        Size=UDim2.new(1,-2,0,49),BorderSizePixel=0,
        LayoutOrder=orderCounter,
    })
    corner(r,10)
    skin(r,'BackgroundColor3','panel')
    local glow=make('UIGradient',r,{Rotation=15,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(165,185,225))})
    stroke(r)
    local nameLabel=newText(r,label,13,true)
    nameLabel.Position=UDim2.fromOffset(14,0)
    nameLabel.Size=UDim2.new(1,-221,1,0)
    responsiveRows[r]={label=nameLabel,kind='row'}
    return r
end
local function addStatus(tab,label,initial)
    local r=row(tab,label)
    local s=newText(r,initial or '--',12,false)
    s.Position=UDim2.new(1,-260,0,0)
    s.Size=UDim2.new(0,246,1,0)
    s.TextXAlignment=Enum.TextXAlignment.Right
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
        b.Text=on and 'ON  ●' or 'OFF  ○'
        animate(b,{BackgroundColor3=on and color('accent') or color('row'),
            TextColor3=on and color('bg') or color('muted')},.16)
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
local menuConnections={}
local menuSearch=make('TextBox',menu,{Name='DropdownSearch',Position=UDim2.fromOffset(8,8),
    Size=UDim2.new(1,-16,0,36),Text='',PlaceholderText='Search targets or maps…',ClearTextOnFocus=false,
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
    menu.Visible=false;menuData=nil
    releaseOwnFocus()
    for _,connection in ipairs(menuConnections) do connection:Disconnect() end
    menuConnections={}
    for _,child in ipairs(menuList:GetChildren()) do
        if child:IsA('GuiButton') or child:IsA('TextLabel') then child:Destroy() end
    end
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
            menuConnections[#menuConnections+1]=choice.MouseButton1Click:Connect(function()
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
    menuData={options=options,choose=choose}
    renderMenuOptions()
    menu.Visible=true
    local target=menu.Size
    menu.Size=UDim2.fromOffset(width,math.max(72,height-12))
    animate(menu,{Size=target},.14)
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
    local actionRole=({START='mint',STOP='rose',SAVE='mint',LOAD='violet',DELETE='rose',PREVIEW='gold',['SET AUTO LOAD']='gold'})[caption]
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
            b.BackgroundColor3=(title==selectedTab) and color('accent') or color('side')
            b.TextColor3=(title==selectedTab) and color('bg') or color('muted')
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
section('Ranked','Auto Ranked')
addDropdown('Ranked','Mode','RankedMode',{'Normal','Scaled'})
addToggle('Ranked','Auto Ranked','RankedRunning')
do local rankedLive=addStatus('Ranked','Status','OFF');widgets[#widgets+1]=function() showStatus(rankedLive,state.rankedStatus or 'OFF') end end
section('War Boss','Auto War Boss')
addDropdown('War Boss','Boss','WarBossName',{'Goku','Saitama'})
addToggle('War Boss','Auto War Boss','WarRunning')
local warLive=addStatus('War Boss','Status','OFF')

section('Dungeon','Smart progression')
addToggle('Dungeon','Auto Dungeon','DungeonRunning')
addDropdown('Dungeon','After Dungeon stops','DungeonAfter',{'Stop','Story','War Boss'})
do
    local boss=addDropdown('Dungeon','War Boss target','WarBossName',{'Goku','Saitama'})
    widgets[#widgets+1]=function() boss.Parent.Visible=flags.DungeonAfter=='War Boss' end
end
local dungeonLive=addStatus('Dungeon','Status','OFF')
local dungeonTarget=addStatus('Dungeon','Gate / Floor','--')
section('Dungeon','Auto System')
do
    local toggle=addToggle('Dungeon','Auto spend System points','SystemRunning')
    tooltip(toggle,'Fills each stat to its current unlocked limit in priority order, then moves to the next stat. Uses only earned System points; no reset or purchases.')
end
do
    for i=1,5 do addDropdown('Dungeon','Priority '..i,'SystemPriority'..i,{'LUK','STR','VIT','AGI','SEN'}) end
end
local systemLive=addStatus('Dungeon','System status','OFF')

local activeRuleUI={}
do
    section('Combat Helper','Auto abilities')
    local master=addToggle('Combat Helper','Auto active','ActiveRulesEnabled')
    tooltip(master,'Turn off the game active auto first. Each enabled card uses its own saved condition.')
    local lanes=addDropdown('Combat Helper','Battles','ActiveRuleLane',{1,2,'Both lanes'})
    tooltip(lanes,'Both lanes applies these card rules to both battles. HP and ability uses stay separate per battle.')
    section('Combat Helper','Card settings')
    local pick
    pick=addAction('Combat Helper','Card','SCP3008  ▾',function()
        if menu.Visible then hideMenu();return end
        openMenu(pick,ctx.activeRules.options(),function(_,id) setFlag('ActiveRuleCard',id) end)
    end)
    widgets[#widgets+1]=function() pick.Text=tostring(flags.ActiveRuleCard)..'  ▾' end
    tooltip(pick,'Lists ability cards received from the selected battle(s). Start a battle once if your cards are missing.')
    addToggle('Combat Helper','Use this card','ActiveEditEnabled')
    addDropdown('Combat Helper','Use when','ActiveEditMode',{'Combat start','Low HP','Round'})
    local hpTarget
    hpTarget=addAction('Combat Helper','Watch card','Any living card  ▾',function()
        if menu.Visible then hideMenu();return end
        openMenu(hpTarget,{'Any living card','Slot 1','Slot 2','Slot 3','Slot 4','Slot 5'},function(index)
            setFlag('ActiveEditSlot',index-1)
        end)
    end)
    widgets[#widgets+1]=function()
        local slot=tonumber(flags.ActiveEditSlot) or 0
        hpTarget.Text=(slot==0 and 'Any living card' or ('Slot '..slot))..'  ▾'
    end
    local hpRow=row('Combat Helper','HP below')
    local bar=make('TextButton',hpRow,{Name='ActiveHPSlider',Text='',AutoButtonColor=false,BackgroundTransparency=1,
        Position=UDim2.new(1,-195,.5,-16),Size=UDim2.fromOffset(180,32),BorderSizePixel=0})
    local valueText=newText(bar,'50%',12,true)
    valueText.Position=UDim2.new(1,-38,0,0);valueText.Size=UDim2.new(0,38,1,0)
    local track=make('Frame',bar,{Position=UDim2.new(0,0,.5,-3),Size=UDim2.new(1,-45,0,6),BorderSizePixel=0})
    corner(track,3);skin(track,'BackgroundColor3','row')
    local fill=make('Frame',track,{Size=UDim2.new(.5,0,1,0),BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(255,255,255)})
    corner(fill,3)
    make('UIGradient',fill,{Color=ColorSequence.new(Color3.fromRGB(171,120,245),Color3.fromRGB(75,220,183))})
    local knob=make('Frame',track,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,0),Size=UDim2.fromOffset(14,14),BorderSizePixel=0})
    corner(knob,7);skin(knob,'BackgroundColor3','accent')
    local drag
    local function canDrag()
        return lifecycle.alive and root.Enabled and not window.minimized and selectedTab=='Combat Helper' and flags.ActiveEditMode=='Low HP' and hpRow.Visible
    end
    local function adjust(x)
        if not canDrag() or track.AbsoluteSize.X<=0 then drag=nil;return end
        local ratio=math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        setFlag('ActiveEditHP',math.floor(1+ratio*98+.5))
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            if canDrag() then drag=input;adjust(input.Position.X) end
        end
    end)
    trackUI(UIS.InputChanged:Connect(function(input)
        if drag and (input==drag or input.UserInputType==Enum.UserInputType.MouseMovement) then adjust(input.Position.X) end
    end))
    trackUI(UIS.InputEnded:Connect(function(input) if input==drag then drag=nil end end))
    trackUI(root:GetPropertyChangedSignal('Enabled'):Connect(function() if not root.Enabled then drag=nil end end))
    widgets[#widgets+1]=function()
        local hp=tonumber(flags.ActiveEditHP) or 50;local ratio=(hp-1)/98
        valueText.Text=tostring(hp)..'%';fill.Size=UDim2.new(ratio,0,1,0);knob.Position=UDim2.new(ratio,0,.5,0)
    end
    local roundInput=addInput('Combat Helper','Round','ActiveEditRound','3')
    tooltip(roundInput,'Round mode: use at this round or later, when the ability becomes available.')
    local details=false
    local detailsButton
    detailsButton=addAction('Combat Helper','Battle details','SHOW',function()
        details=not details;detailsButton.Text=details and 'HIDE' or 'SHOW'
        activeRuleUI.last.Parent.Visible=details
        activeRuleUI.hp1.Parent.Visible=details and (flags.ActiveRuleLane==1 or flags.ActiveRuleLane=='Both lanes')
        activeRuleUI.hp2.Parent.Visible=details and (flags.ActiveRuleLane==2 or flags.ActiveRuleLane=='Both lanes')
    end)
    activeRuleUI.last=addStatus('Combat Helper','Last request','--')
    activeRuleUI.hp1=addStatus('Combat Helper','Battle 1 HP / round','Waiting for battle sync')
    activeRuleUI.hp2=addStatus('Combat Helper','Battle 2 HP / round','Waiting for battle sync')
    local editedCard
    widgets[#widgets+1]=function()
        local lowHP=flags.ActiveEditMode=='Low HP'
        hpTarget.Parent.Visible=lowHP;hpRow.Visible=lowHP
        roundInput.Parent.Visible=flags.ActiveEditMode=='Round'
        if not lowHP or editedCard~=flags.ActiveRuleCard then drag=nil end
        editedCard=flags.ActiveRuleCard
        activeRuleUI.last.Parent.Visible=details
        activeRuleUI.hp1.Parent.Visible=details and (flags.ActiveRuleLane==1 or flags.ActiveRuleLane=='Both lanes')
        activeRuleUI.hp2.Parent.Visible=details and (flags.ActiveRuleLane==2 or flags.ActiveRuleLane=='Both lanes')
    end
    tooltip(hpRow,'Low HP mode only. Slot 0 checks any living allied card, including cards in hand. Dead cards do not trigger. Exactly the threshold does not trigger.')
end

section('Monitor','Raid currency')
local monitorBone=addStatus('Monitor','Bone Tokens','Waiting for sync')
section('Monitor','Other currency')
local monitorWar=addStatus('Monitor','War Coins','Waiting for sync')
section('Monitor','Server Domain')
local monitorDomain=addStatus('Monitor','Current Domain','--')
local monitorDomainTime=addStatus('Monitor','Time remaining','--')
local monitorBoost=addStatus('Monitor','Luck boost','--')
local monitorBy=addStatus('Monitor','Opened by','--')

do
section('Monitor','Webhook')
local webhookRow=row('Monitor','Discord webhook URL')
local weatherInput=make('TextBox',webhookRow,{
    Size=UDim2.fromOffset(180,31),Position=UDim2.new(1,-195,.5,-15),
    BackgroundTransparency=0,BorderSizePixel=0,TextSize=12,Font=Enum.Font.Gotham,
    Text=flags.WeatherWebhookURL or '',PlaceholderText='Paste webhook URL',ClearTextOnFocus=false,
})
corner(weatherInput,10);skin(weatherInput,'BackgroundColor3','row');skin(weatherInput,'TextColor3','text');skin(weatherInput,'PlaceholderColor3','muted')
weatherInput.FocusLost:Connect(function()
    if not lifecycle.alive then return end
    local value=weatherInput.Text
    local accepted=ctx.setWeatherURL(value)
    weatherInput.Text=flags.WeatherWebhookURL or ''
    if not accepted then notify('Enter a valid Discord webhook URL.','warning') end
end)
widgets[#widgets+1]=function()
    if not weatherInput:IsFocused() then weatherInput.Text=flags.WeatherWebhookURL or '' end
end
tooltip(weatherInput,'Replace the URL to change destination. Clear the field to remove it. SAVE your Config profile to keep changes.')
addToggle('Monitor','Domain alerts','WeatherWebhookEnabled')
local domainPick
local function domainChoices()
    local labels,ids={},{}
    for _,option in ipairs(ctx.weatherDomainOptions()) do labels[#labels+1]=option.label;ids[option.label]=option.id end
    return labels,ids
end
domainPick=addAction('Monitor','Notify for Domains','SELECT  ▾',function()
    if menu.Visible then hideMenu();return end
    local labels,ids=domainChoices()
    local function selection()
        local selected={}
        for label,id in pairs(ids) do if flags.WeatherWebhookDomains[id] then selected[label]=true end end
        return selected
    end
    openMenu(domainPick,labels,function(_,label)
        local id=ids[label];if not id then return end
        local nextSet={};for key,on in pairs(flags.WeatherWebhookDomains) do if on then nextSet[key]=true end end
        nextSet[id]=not nextSet[id] or nil
        setFlag('WeatherWebhookDomains',nextSet);repaintControls()
    end)
    menuData.multi=true;menuData.selected=selection;renderMenuOptions()
end)
widgets[#widgets+1]=function()
    local count=0
    for _,option in ipairs(ctx.weatherDomainOptions()) do if flags.WeatherWebhookDomains[option.id] then count=count+1 end end
    domainPick.Text=tostring(count)..' selected  ▾'
end
addAction('Monitor','Test webhook','SEND TEST',ctx.testWeatherWebhook)
end

-- Multi-select reuses the Origin UI searchable popup and preserves selections while filtering.
local function multiDropdown(label,options,getSet,onChange,tab)
    local function currentOptions() return type(options)=='function' and options() or options end
    local button
    button=addAction(tab or 'Story',label,'SELECT  ▾',function()
        if menu.Visible then hideMenu();return end
        openMenu(button,currentOptions(),function(_,value)
            local nextSet={}
            for k,v in pairs(getSet()) do nextSet[k]=v end
            nextSet[value]=not nextSet[value] or nil
            onChange(nextSet)
            repaintControls()
        end)
        menuData.multi=true
        menuData.selected=getSet
        renderMenuOptions()
    end)
    widgets[#widgets+1]=function()
        local count=0
        local available=currentOptions()
        for _,value in ipairs(available) do if getSet()[value] then count=count+1 end end
        button.Text=#available==0 and 'Choose maps first' or tostring(count)..' selected  ▾'
    end
    return button
end
local story=ctx.story
local mapLabels,cardLabels={},{ }
local mapLookup,cardLookup={},{ }
for _,w in ipairs(story.Worlds) do
    local label=w.name..' ['..w.map..']'
    mapLabels[#mapLabels+1]=label;mapLookup[label]=w.map
    for i,id in ipairs(w.cards) do
        label=w.name..' / '..id..(i==#w.cards and ' [BOSS]' or '')
        cardLabels[#cardLabels+1]=label;cardLookup[label]=id
    end
end
local function displaySet(lookup,selection)
    local result={}
    for label,id in pairs(lookup) do if selection[id] then result[label]=true end end
    return result
end
local function internalSet(lookup,selection)
    local result={}
    for label in pairs(selection) do if lookup[label] then result[lookup[label]]=true end end
    return result
end
orderCounter=orderCounter+1
local hero=make('Frame',tabPages.Story,{Name='StoryHero',Size=UDim2.new(1,-2,0,106),LayoutOrder=orderCounter,BorderSizePixel=0})
corner(hero,12);stroke(hero)
hero.BackgroundColor3=Color3.fromRGB(255,255,255)
make('UIGradient',hero,{Rotation=15,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(71,43,124)),ColorSequenceKeypoint.new(.6,Color3.fromRGB(26,88,124)),ColorSequenceKeypoint.new(1,Color3.fromRGB(20,111,101))})})
local heroTitle=newText(hero,'STORY AUTOMATION',19,true)
heroTitle.Position=UDim2.fromOffset(18,14);heroTitle.Size=UDim2.new(0,255,0,26)
gradientText(heroTitle,true)
skinned[heroTitle]=nil
local heroSub=newText(hero,'Build your route. Choose each fight. Keep moving forward.',12,false)
heroSub.Position=UDim2.fromOffset(18,44);heroSub.Size=UDim2.new(1,-36,0,20)
heroSub.TextColor3=Color3.fromRGB(179,203,230);skinned[heroSub]=nil
local heroCount=newText(hero,'6 WORLDS   /   36 ENCOUNTERS   /   5 DIFFICULTIES',11,true)
heroCount.Position=UDim2.fromOffset(18,76);heroCount.Size=UDim2.new(1,-36,0,18)
gradientText(heroCount,true);skinned[heroCount]=nil
section('Story','Story selection')
multiDropdown('Maps',mapLabels,function() return displaySet(mapLookup,flags.StoryMaps) end,
    function(value) setFlag('StoryMaps',internalSet(mapLookup,value)) end)
multiDropdown('Mob / Boss',function() return story.targetOptions(flags.StoryMaps) end,function() return displaySet(cardLookup,flags.StoryCards) end,
    function(value) setFlag('StoryCards',internalSet(cardLookup,value)) end)
section('Story','Modes per mob / boss')
do
    local bulkModes={Easy=true}
    multiDropdown('Bulk difficulties',story.Modes,function() return bulkModes end,function(value) bulkModes=value end)
    local function applyBulk(selectedOnly)
        local cards,modes,count=story.bulkModes(flags,bulkModes,selectedOnly)
        if count==0 then notify('Choose maps and targets first.','warning');return end
        setFlag('StoryCards',cards);setFlag('StoryModes',modes)
        notify('Applied difficulties to '..count..' targets. Restart Auto Story if it is running.','success')
    end
    local selected=addAction('Story','Apply to selected mob / boss','APPLY SELECTED',function() applyBulk(true) end)
    tooltip(selected,'Replaces difficulties for selected targets in selected maps. Other targets keep their settings.')
    local all=addAction('Story','Select all mob / boss in chosen maps','APPLY ALL',function() applyBulk(false) end)
    tooltip(all,'Selects every mob and boss in chosen maps, then replaces their difficulties with Bulk difficulties. An empty difficulty selection clears their modes.')
end
-- Each selected target reveals its own difficulty multi-dropdown. Defaults to Easy.
local modeRows={}
for _,w in ipairs(story.Worlds) do
    for i,id in ipairs(w.cards) do
        local button=multiDropdown(id..(i==#w.cards and ' [BOSS]' or ''),story.Modes,
            function() return flags.StoryModes[id] or {} end,
            function(value)
                local nextModes={}
                for k,v in pairs(flags.StoryModes) do nextModes[k]=v end
                nextModes[id]=value;setFlag('StoryModes',nextModes)
            end)
        modeRows[#modeRows+1]={row=button.Parent,id=id,map=w.map}
    end
end
widgets[#widgets+1]=function()
    for _,entry in ipairs(modeRows) do
        entry.row.Visible=flags.StoryMaps[entry.map]==true and flags.StoryCards[entry.id]==true
    end
end
local preview
section('Story','Queue and controls')
addToggle('Story','Repeat whole queue','StoryRepeat')
addAction('Story','Preview ordered queue','PREVIEW',function()
    local queue=story.buildQueue(flags)
    local lines={}
    for i,item in ipairs(queue) do lines[#lines+1]=i..'. '..item.world..' / '..item.cardId..' / '..item.difficulty end
    local text=#lines>0 and table.concat(lines,'\n') or 'Empty queue'
    preview.Text=text
    preview.Size=UDim2.new(1,-4,0,math.max(40,#lines*19+12))
    notify(tostring(#queue)..' fights selected','info')
end)
addToggle('Story','Auto Story','StoryRunning')
local storyStatus=addStatus('Story','Status','Ready')
local storyCurrent=addStatus('Story','Current target','--')
local storyResult=addStatus('Story','Last server result','--')
local storyCount=addStatus('Story','Queue position','0 / 0')
-- Multi-line preview is a dedicated block, not a fixed-height control row.
orderCounter=orderCounter+1
preview=newText(tabPages.Story,'Press PREVIEW to show the ordered queue.',12,false)
preview.LayoutOrder=orderCounter;preview.Size=UDim2.new(1,-4,0,40)
preview.TextWrapped=true;preview.TextTruncate=Enum.TextTruncate.None
preview.TextYAlignment=Enum.TextYAlignment.Top
section('Story','Combat detection')
addStatus('Story','Combat signal','Server battleId / lane')
addStatus('Story','Victory signal','BattleEnd.won (matching battleId)')
addAction('Story','Export received battle payloads','COPY CAPTURE',ctx.exportCapture)
section('Guess Minigame','Automatic stat comparison')
addToggle('Guess Minigame','Auto Guess Minigame','HLRunning')
addToggle('Guess Minigame','Restart after game ends','HLRepeat')
local hlLive=addStatus('Guess Minigame','Status','OFF')
local hlPool=addStatus('Guess Minigame','Live stat entries','Loaded on start')
local hlScore=addStatus('Guess Minigame','Streak','0 / 100')

section('Skill Tree','Auto skill upgrades')
local skillLabels,skillIds={},{}
for _,id in ipairs(Skills.Order) do
    local def=Skills.Data[id]
    local label=def.name..'  /  max '..def.maxRank
    skillLabels[#skillLabels+1]=label;skillIds[label]=id
end
multiDropdown('Skills to upgrade',skillLabels,function()
    return displaySet(skillIds,flags.AutoSkills or {})
end,function(value) setFlag('AutoSkills',internalSet(skillIds,value)) end,'Skill Tree')
addDropdown('Skill Tree','Buy mode','SkillPurchaseMode',{'Purchase','PurchaseMax'})
addToggle('Skill Tree','Auto prerequisites (spends coins)','SkillPrerequisites')
addInput('Skill Tree','Request interval (1–10s)','SkillInterval','2')
addToggle('Skill Tree','Auto Skill Tree','SkillRunning')
local skillLive=addStatus('Skill Tree','Upgrade status','OFF')
section('Skill Tree','Branches from SkillDefinitions')
for _,id in ipairs(Skills.Order) do
    local def=Skills.Data[id]
    local requirements={}
    for _,need in ipairs(Skills.Order) do
        if def.requires[need] then requirements[#requirements+1]=need..' '..def.requires[need] end
    end
    local label=addStatus('Skill Tree',def.name..' / '..def.maxRank,#requirements>0 and table.concat(requirements,' + ') or 'Root skill')
    tooltip(label,def.name..' ['..id..'] — requires: '..(#requirements>0 and table.concat(requirements,', ') or 'none'))
end

section('Config','Profiles')
local profileName=profile.currentProfile
local nameBox=addInput('Config','Profile name','ProfileName','Default')
flags.ProfileName=profile.currentProfile
local savedDrop
savedDrop=addAction('Config','Saved profiles','SELECT  ▾',function()
    openMenu(savedDrop,profile.storedNames,function(_,name)
        flags.ProfileName=name;profile.currentProfile=name;repaintControls()
    end)
end)
addAction('Config','Save profile','SAVE',function() ctx.saveProfile(flags.ProfileName) end)
addAction('Config','Load profile','LOAD',function() ctx.loadProfile(flags.ProfileName) end)
addAction('Config','Delete profile','DELETE',function() ctx.deleteProfile(flags.ProfileName) end)
addAction('Config','Load on next execute','SET AUTO LOAD',function() ctx.setAutoProfile(flags.ProfileName) end)
local configStatus=addStatus('Config','Storage','Ready')
local configAuto=addStatus('Config','Auto Load','None')
section('Settings','Startup')
addToggle('Settings','Autoexec','AutoExec')
addAction('Settings','Rejoin Server','REJOIN',ctx.rejoinServer)
section('Settings','AFK')
addToggle('Settings','Anti-AFK','AntiAFK')
addToggle('Settings','Save CPU (15 FPS)','SaveCPU')
addToggle('Settings','White Screen','WhiteScreen')
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
    Name='OriginStoryToggle',ResetOnSpawn=false,IgnoreGuiInset=true,
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
    elseif not used and input.UserInputType==Enum.UserInputType.MouseButton1 and menu.Visible then
        local point=input.Position;local position=menu.AbsolutePosition;local size=menu.AbsoluteSize
        if point.X<position.X or point.Y<position.Y or point.X>position.X+size.X or point.Y>position.Y+size.Y then hideMenu() end
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
            r.Size=UDim2.new(1,-2,0,entry.kind=='boss' and 104 or entry.kind=='transparency' and 90 or 80)
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
                entry.value.Position=UDim2.fromOffset(12,36);entry.value.Size=UDim2.new(1,-24,0,30)
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
    if state.gameIcon and gameIconImage.Image~=state.gameIcon then gameIconImage.Image=state.gameIcon;touchGameIcon.Image=state.gameIcon end
    if selectedTab=='Monitor' then
        local m=ctx.monitorSnapshot()
        showStatus(monitorBone,m.bone);showStatus(monitorWar,m.war)
        showStatus(monitorDomain,m.domain);showStatus(monitorDomainTime,m.domainTime)
        showStatus(monitorBoost,m.boost);showStatus(monitorBy,m.openedBy)
    end
    showStatus(sessionBadge,state.enabled and 'RUNNING' or 'STANDBY')
    showStatus(storyStatus,state.status or 'Ready')
    showStatus(hlLive,state.hlStatus or 'OFF')
    showStatus(hlPool,state.hlPoolCount and tostring(state.hlPoolCount) or 'Loaded on start')
    showStatus(hlScore,tostring(state.hlStreak or 0)..' / 100')
    showStatus(skillLive,state.skillStatus or 'OFF')
    showStatus(dungeonLive,state.dungeonStatus or 'OFF')
    showStatus(systemLive,state.systemStatus or 'OFF')
    showStatus(warLive,state.warStatus or 'OFF')
    showStatus(dungeonTarget,tostring(state.dungeonGate or '--')..' / '..tostring(state.dungeonFloor or '--'))
    if selectedTab=='Combat Helper' then
        showStatus(activeRuleUI.last,state.activeRuleLast or '--')
        showStatus(activeRuleUI.hp1,ctx.activeRules.preview(1))
        showStatus(activeRuleUI.hp2,ctx.activeRules.preview(2))
    end
    showStatus(storyResult,state.lastResult or '--')
    showStatus(configStatus,profile.status or 'Ready')
    showStatus(configAuto,profile.autoProfile~='' and profile.autoProfile or 'None')
    local current=state.current
    showStatus(storyCurrent,current and (current.cardId..' / '..current.difficulty) or '--')
    showStatus(storyCount,tostring(state.index)..' / '..tostring(#state.queue))
end
repaintControls()
refreshOverview()
return {Repaint=repaintControls,Refresh=refreshOverview,Root=root,Notify=notify,Destroy=destroyUI,ClearNotifications=clearNotifications}
end
return Library

end)()
local env=(getgenv and getgenv()) or _G
local previous=env.OriginStory
-- An InvokeServer cannot be cancelled. Do not create a second controller while one is pending.
if previous and (previous.pending or previous.skillPending or previous.hlPending or previous.hlBusy or previous.activePending or previous.dungeonBusy or previous.dungeonPending or previous.systemBusy or previous.warBusy or previous.warPending) then error('Origin Story: previous request still pending; wait for it to return.') end
if previous and previous.stop then previous.stop() end
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local player=Players.LocalPlayer
while not player do task.wait();player=Players.LocalPlayer end
local net=game:GetService('ReplicatedStorage'):WaitForChild('Shared',15)
assert(net,'Shared not found')
net=net:WaitForChild('Net',15)
assert(net,'Net not found')
net=net:WaitForChild('RemoteObjects',30)
assert(net,'RemoteObjects not found')
local action=net:WaitForChild('BattleAction',15)
assert(action and action:IsA('RemoteFunction'),'BattleAction RemoteFunction not found')
local flags={AO_UI_Theme='Midnight',AO_UI_Transparency=15,StoryMaps={},StoryCards={},StoryModes={},StoryRepeat=false,AutoSkills={},SkillPurchaseMode='Purchase',SkillPrerequisites=false,SkillInterval=2,HLRepeat=false,StoryRunning=false,SkillRunning=false,HLRunning=false,WeatherWebhookURL='',WeatherWebhookEnabled=false,WeatherWebhookDomains={InfiniteVoid=true,DomainClash=true},ActiveRulesEnabled=false,ActiveRuleLane=1,ActiveRuleCard='SCP3008',ActiveRules={},AntiAFK=true,SaveCPU=false,WhiteScreen=false,DungeonRunning=false,DungeonAfter='Stop',RankedRunning=false,RankedMode='Normal',WarRunning=false,WarBossName='Saitama',SystemRunning=false,SystemPriority={'luk','str','vit','agi','sen'}}
for _,w in ipairs(Story.Worlds) do
    for _,id in ipairs(w.cards) do flags.StoryModes[id]={Easy=true} end
end
local state={alive=true,serverId=game.JobId,enabled=false,connections={},status='Ready',index=0,queue={},pending=false,logs={},awaiting=false,runId=0}
-- Keep a verified Story battle across Stop/Start and script re-execution.
state.storyInFlight=previous and (previous.storyInFlight or (previous.attempt and previous.attempt.started and previous.attempt)) or nil
state.warInFlight=previous and previous.warInFlight or nil
env.OriginStory=state
local ui
local afkRuntime
local function message(text,kind)
    state.status=text
    if ui then ui.Notify(text,kind or 'info',4) end
end
local function snapshot(value,depth,seen)
    local t=typeof(value)
    if t=='nil' then return '<nil>' end
    if t=='boolean' or t=='number' then return value end
    if t=='string' then return value:sub(1,1000) end
    if t~='table' then return '<'..t..'>' end
    if depth>=5 or seen[value] then return '<limited>' end
    seen[value]=true
    local result={};local count=0
    for k,v in pairs(value) do
        count=count+1;if count>60 then result['<truncated>']=true;break end
        result[tostring(k)]=snapshot(v,depth+1,seen)
    end
    seen[value]=nil
    return result
end
local function log(source,args)
    state.logs[#state.logs+1]={source=source,time=os.clock(),args=snapshot(args,0,{})}
    if #state.logs>60 then table.remove(state.logs,1) end
end
local function stopRun(reason)
    state.enabled=false;state.runId=state.runId+1
    if ui and ui.ClearNotifications then ui.ClearNotifications() end
    log('QueueStopped',{reason=reason,index=state.index,total=#state.queue,current=state.current})
    if reason then message(reason,'warning') end
end
local battleEvent=net:WaitForChild('BattleEvent',15)
assert(battleEvent and battleEvent:IsA('RemoteEvent'),'BattleEvent RemoteEvent missing')
state.connections[#state.connections+1]=battleEvent.OnClientEvent:Connect(function(event)
    if not state.alive then return end
    local attempt=state.attempt
    local inFlight=state.storyInFlight
    if inFlight and inFlight~=attempt then Combat.event(inFlight,event) end
    if not attempt then return end
    Combat.event(attempt,event)
    if type(event)=='table' and event.type=='BattleEnd' and (not attempt.battleId or event.battleId==attempt.battleId) then
        log('BattleEnd',{battleId=event.battleId,lane=event.lane,difficulty=event.difficulty,won=event.won,matched=Combat.match(attempt,event)})
    end
end)
local function beginRun()
    if state.enabled or state.pending or state.activePending then message('A run/request is already active.','warning');return end
    local queue=Story.buildQueue(flags)
    if #queue==0 then message('Select maps, targets and at least one mode per target.','warning');return end
    if ui and ui.ClearNotifications then ui.ClearNotifications() end
    log('QueueStarted',{total=#queue,repeatQueue=flags.StoryRepeat,entries=queue})
    state.lastResult='--'
    state.queue=queue;state.index=0;state.enabled=true;state.runId=state.runId+1
    local runId=state.runId
    local function active() return state.alive and state.enabled and state.runId==runId end
    local function waitSeconds(seconds)
        local deadline=os.clock()+seconds
        while active() and os.clock()<deadline do task.wait(.1) end
        return active()
    end
    task.spawn(function()
        local i=1
        while active() and i<=#queue do
            local prior=state.storyInFlight
            if prior and not prior.ended then
                state.status='Waiting for previous Story battle to end before switching target'
                log('StorySwitchWaiting',{battleId=prior.battleId,lane=prior.lane,nextCardId=queue[i].cardId})
                local priorDeadline=os.clock()+900
                while active() and not prior.ended and os.clock()<priorDeadline do task.wait(.1) end
                if not active() then break end
                if not prior.ended then stopRun('Previous Story battle has not ended; stopped waiting.');break end
            end
            local activeDeadline=os.clock()+30
            while active() and state.activePending and os.clock()<activeDeadline do task.wait(.1) end
            if not active() then break end
            if state.activePending then stopRun('Ability request still pending; stopped scheduling.');break end
            local item=queue[i]
            local attempt=Combat.new()
            state.index=i;state.current=item;state.attempt=attempt;state.awaiting=true;state.pending=true
            log('StartRequest',{index=i,cardId=item.cardId,difficulty=item.difficulty})
            state.status='Starting '..item.cardId..' / '..item.difficulty
            task.spawn(function()
                local response=table.pack(pcall(function()
                    return action:InvokeServer('StartEncounter',{difficulty=item.difficulty,cardId=item.cardId})
                end))
                state.pending=false;attempt.returned=true;attempt.response=response
                log('StartResponse',response)
                if state.alive and state.attempt==attempt then
                    if Combat.accept(attempt,response,item) then state.storyInFlight=attempt end
                end
            end)
            local startDeadline=os.clock()+30
            while active() and state.pending and os.clock()<startDeadline do task.wait(.1) end
            if not active() then break end
            if state.pending then stopRun('Start request still pending; stopped without sending another request.');break end
            if not attempt.started then
                -- Unknown admission is not a loss. Do not repeatedly start an untracked fight.
                state.attempt=nil;state.awaiting=false
                local response=attempt.response
                if response and response[1]==true and response[2]==false and type(response[3])=='string' then
                    local reason=response[3]:sub(1,240)
                    if reason:lower():find('already in a story battle',1,true) then
                        stopRun('Another Story battle is still running. Wait for it to finish, then turn Auto Story ON again.')
                    else stopRun('Server refused Story start: '..reason) end
                else stopRun('Server did not return a verified Story battle ID; see COPY CAPTURE.') end
                break
            end
            log('StoryAdmitted',{battleId=attempt.battleId,lane=attempt.lane,cardId=item.cardId,difficulty=item.difficulty})
            state.status='Waiting for BattleEnd: '..item.cardId..' / '..item.difficulty
            local endDeadline=os.clock()+900
            while active() and not attempt.ended do
                if os.clock()>endDeadline then stopRun('No matching BattleEnd after 15 minutes; stopped, result unknown.');break end
                task.wait(.1)
            end
            if not active() then break end
            local won=attempt.won
            log('BattleResult',{battleId=attempt.battleId,lane=attempt.lane,index=i,cardId=item.cardId,difficulty=item.difficulty,won=won})
            state.awaiting=false;state.attempt=nil
            if won then
                state.lastResult='WIN: '..item.cardId..' / '..item.difficulty
                state.status=state.lastResult
                i=i+1
                if i>#queue and flags.StoryRepeat then i=1 end
            else
                state.lastResult='LOSS: '..item.cardId..' / '..item.difficulty
                state.status=state.lastResult..' — retrying this entry'
            end
            if not waitSeconds(won and 1 or 3) then break end
        end
        if active() then
            state.enabled=false;state.attempt=nil
            log('QueueCompleted',{total=#queue,last=queue[#queue]})
            message('Completed '..#queue..'/'..#queue..' selected fights. Last: '..queue[#queue].cardId..' / '..queue[#queue].difficulty,'success')
        end
    end)
end
state.stop=function()
    state.alive=false;state.enabled=false;state.skillEnabled=false;state.hlEnabled=false
    for _,c in ipairs(state.connections) do pcall(function() c:Disconnect() end) end
    state.connections={}
    if afkRuntime then afkRuntime.stop() end
    if ui then ui.Destroy() end
end
local function exportCapture()
    local data=HttpService:JSONEncode({note='Local received battle payloads; no network upload',records=state.logs,run={status=state.status,lastResult=state.lastResult,enabled=state.enabled,index=state.index,total=#state.queue,current=state.current}})
    if type(setclipboard)=='function' then setclipboard(data);message('Battle capture copied.','success')
    elseif type(writefile)=='function' then writefile('OriginStory-capture.json',data);message('Saved OriginStory-capture.json','success')
    else print(data);message('Battle capture printed in console.') end
end
state.skillStatus='OFF';state.skillEnabled=false;state.skillPending=false;state.skillRunId=0
local skillRemote=net:FindFirstChild('SkillAction')
local skillRanks,skillRevision=nil,0
local function syncSkills(data)
    if type(data)~='table' or type(data.skills)~='table' then return end
    local nextRanks={}
    for _,id in ipairs(Skills.Order) do
        local value=data.skills[id]
        if value~=nil and (type(value)~='number' or value~=value or value<0 or value>Skills.Data[id].maxRank or value%1~=0) then return end
        nextRanks[id]=value or 0
    end
    skillRanks=nextRanks;skillRevision=skillRevision+1
end
local profileSync=net:FindFirstChild('ProfileSync')
if profileSync and profileSync:IsA('RemoteEvent') then
    state.connections[#state.connections+1]=profileSync.OnClientEvent:Connect(syncSkills)
end
local skillResult=net:FindFirstChild('SkillResult')
if skillResult and skillResult:IsA('RemoteEvent') then
    state.connections[#state.connections+1]=skillResult.OnClientEvent:Connect(function(...)
        if state.skillEnabled then log('SkillResult',table.pack(...)) end
    end)
end
local function stopSkills()
    state.skillEnabled=false;state.skillRunId=state.skillRunId+1;state.skillStatus=state.skillPending and 'Stopping after pending purchase' or 'OFF'
end
local function startSkills()
    if state.skillEnabled or state.skillPending then message('Auto Skill is already active or waiting for a request.','warning');return end
    skillRemote=net:FindFirstChild('SkillAction')
    if not skillRemote or not skillRemote:IsA('RemoteFunction') then message('SkillAction missing.','warning');return end
    local selected={}
    for _,id in ipairs(Skills.Order) do if (flags.AutoSkills or {})[id] then selected[id]=true end end
    if not next(selected) then message('Select at least one skill.','warning');return end
    state.skillEnabled=true;state.skillRunId=state.skillRunId+1;state.skillStatus='Syncing skill ranks'
    local skillRunId=state.skillRunId
    local function activeSkill() return state.alive and state.skillEnabled and state.skillRunId==skillRunId end
    local requestSync=net:FindFirstChild('RequestSync')
    if requestSync and requestSync:IsA('RemoteEvent') then requestSync:FireServer() end
    task.spawn(function()
        local cursor=0
        while activeSkill() do
            local includePrerequisites=flags.SkillPrerequisites==true
            if includePrerequisites and not skillRanks then
                state.skillStatus='Waiting for ProfileSync.skills before buying prerequisites'
                task.wait(1)
            else
                local plan,goals=Skills.plan(selected,skillRanks,includePrerequisites)
                if #plan==0 then
                    local done=skillRanks~=nil
                    if skillRanks then
                        for id,goal in pairs(goals) do if skillRanks[id]<goal then done=false end end
                    end
                    if done then state.skillEnabled=false;state.skillStatus='Selected skills maxed (confirmed ranks)';break end
                    state.skillStatus='Selected skills locked; enable prerequisites or unlock in game'
                    task.wait(3)
                else
                    cursor=cursor%#plan+1
                    local item=plan[cursor]
                    -- Max is used only for selected skills; prerequisite requests stay one rank at a time.
                    local verb=(not item.prerequisite and flags.SkillPurchaseMode=='PurchaseMax') and 'PurchaseMax' or 'Purchase'
                    local before=skillRevision
                    state.skillPending=true;state.skillStatus=verb..': '..Skills.Data[item.id].name
                    log('SkillRequest',{action=verb,id=item.id,rankKnown=skillRanks~=nil,goal=item.goal})
                    local response=table.pack(pcall(function() return skillRemote:InvokeServer(verb,item.id) end))
                    state.skillPending=false
                    log('SkillResponse',response)
                    if not activeSkill() then break end
                    if not response[1] then state.skillEnabled=false;state.skillStatus='Request error; stopped (see COPY CAPTURE)';break end
                    state.skillStatus='Request returned: '..Skills.Data[item.id].name..(skillRanks and ' — checking rank sync' or ' — rank unconfirmed')
                    local waitTime=math.clamp(tonumber(flags.SkillInterval) or 2,1,10)
                    if skillRanks and skillRevision==before then waitTime=math.max(waitTime,5) end
                    local deadline=os.clock()+waitTime
                    while activeSkill() and os.clock()<deadline do task.wait(.1) end
                end
            end
        end
        if not state.skillEnabled and state.skillStatus=='Stopping after pending purchase' then state.skillStatus='OFF' end
    end)
end

state.hlEnabled=false;state.hlPending=false;state.hlBusy=false;state.hlRunId=0;state.hlStatus='OFF';state.hlStreak=0
local hlRemote,hlConfig,hlEventConnection
local function stopHL()
    state.hlEnabled=false;state.hlRunId=state.hlRunId+1
    state.hlStatus=state.hlPending and 'Stopping after pending request' or 'OFF'
end
local function startHL()
    if state.hlEnabled or state.hlPending or state.hlBusy then message('Guess Minigame is already active/pending.','warning');return end
    state.hlBusy=true;state.hlEnabled=true;state.hlRunId=state.hlRunId+1;state.hlStatus='Loading live card stat pool'
    local token=state.hlRunId
    local function activeHL() return state.alive and state.hlEnabled and state.hlRunId==token end
    task.spawn(function()
        local sessionStarted=false
        local function callHL(verb,payload)
            state.hlPending=true
            local response=table.pack(pcall(function() return hlRemote:InvokeServer(verb,payload) end))
            state.hlPending=false
            log('HigherLowerResponse',{action=verb,response=response})
            if not response[1] or response[2]~=true then
                return nil,type(response[3])=='string' and response[3] or 'Server request failed / rejected'
            end
            return response[3]
        end
        local function waitHL(seconds)
            local untilTime=os.clock()+seconds
            while activeHL() and os.clock()<untilTime do task.wait(.1) end
            return activeHL()
        end
        local ok,config=pcall(function()
            local shared=game:GetService('ReplicatedStorage'):WaitForChild('Shared',10)
            local folder=shared and shared:WaitForChild('Config',10)
            local module=folder and folder:WaitForChild('HigherLowerConfig',10)
            assert(module,'HigherLowerConfig missing')
            local data=require(module)
            if type(data.pool)=='function' then state.hlPoolCount=#data.pool() end
            return data
        end)
        if not activeHL() then state.hlBusy=false;return end
        hlRemote=net:FindFirstChild('HigherLowerAction')
        if not ok or type(config)~='table' or type(config.entry)~='function' or not hlRemote or not hlRemote:IsA('RemoteFunction') then
            state.hlEnabled=false;state.hlBusy=false;state.hlStatus='Config or HigherLowerAction unavailable';return
        end
        hlConfig=config
        if not hlEventConnection then
            local event=net:FindFirstChild('HigherLowerEvent')
            if event and event:IsA('RemoteEvent') then
                hlEventConnection=event.OnClientEvent:Connect(function(payload)
                    if state.hlEnabled and type(payload)=='table' and payload.type=='ended' then
                        log('HigherLowerEnded',payload)
                        state.hlEnded=payload
                    end
                end)
                state.connections[#state.connections+1]=hlEventConnection
            end
        end
        repeat
            state.hlEnded=nil;state.hlStreak=0
            local run,err=callHL('start',nil)
            if not activeHL() then sessionStarted=run~=nil;break end
            if type(run)~='table' then state.hlStatus='Start failed: '..tostring(err);break end
            sessionStarted=true
            while activeHL() do
                if state.hlEnded then state.hlStatus='Ended: '..tostring(state.hlEnded.reason or 'server event');sessionStarted=false;break end
                local compared,guess,reason,left,right=pcall(HigherLower.choose,run,hlConfig)
                if not compared then state.hlStatus='Stat lookup failed; stopped';break end
                if not guess then state.hlStatus='Stopped: '..tostring(reason);break end
                state.hlStatus='Round '..run.round..': '..guess..' ('..left..' → '..right..')'
                log('HigherLowerGuess',{round=run.round,a=run.a.key,b=run.b.key,leftTotal=left,rightTotal=right,guess=guess})
                if not waitHL(math.max(1.1,tonumber(hlConfig.GuessGap) or .45)) then break end
                if state.hlEnded then state.hlStatus='Ended: '..tostring(state.hlEnded.reason or 'server event');sessionStarted=false;break end
                local result,errorText=callHL('guess',{guess=guess,round=run.round})
                if not activeHL() then break end
                if not result then state.hlStatus='Guess failed: '..tostring(errorText);break end
                state.hlStreak=tonumber(result.streak) or tonumber(run.streak) or 0
                local nextRun,nextError,ended=HigherLower.advance(run,result)
                if ended then
                    sessionStarted=false
                    state.hlStatus='Ended: '..tostring(result.reason or (result.correct and 'complete' or 'incorrect'))..' / streak '..state.hlStreak
                    break
                end
                if not nextRun then state.hlStatus='Stopped: '..tostring(nextError);break end
                run=nextRun
            end
            if sessionStarted then break end
            if not flags.HLRepeat or not waitHL(2) then break end
        until not activeHL()
        -- Quit only our still-active session; do not overlap its pending guess.
        if sessionStarted then callHL('quit',nil) end
        state.hlBusy=false
        if state.hlRunId==token then state.hlEnabled=false end
        if state.hlStatus=='Stopping after pending request' then state.hlStatus='OFF' end
    end)
end

local tracking=Monitor.new()
local monitorStorage=game:GetService('ReplicatedStorage')
local domainConfig
local lastDomainConfigAttempt=-math.huge
local function getMonitorDomainConfig()
    if domainConfig then return domainConfig end
    if os.clock()-lastDomainConfigAttempt<5 then return nil end
    lastDomainConfigAttempt=os.clock()
    local shared=monitorStorage:FindFirstChild('Shared')
    local folder=shared and shared:FindFirstChild('Config')
    local module=folder and folder:FindFirstChild('DomainConfig')
    if module then local ok,data=pcall(require,module);if ok and type(data)=='table' and type(data.get)=='function' then domainConfig=data end end
    return domainConfig
end
local function monitorProfile(data)
    if not Monitor.profile(tracking,data,os.clock()) then
        local keys={}
        if type(data)=='table' then
            for key in pairs(data) do if #keys>=20 then break end;keys[#keys+1]=tostring(key) end
        end
        if log then log('MonitorSyncShape',{dataType=type(data),keys=keys,currencyType=type(data)=='table' and type(data.currency) or 'missing'}) end
    end
end
local monitorSync=net:FindFirstChild('ProfileSync')
if monitorSync and monitorSync:IsA('RemoteEvent') then
    state.connections[#state.connections+1]=monitorSync.OnClientEvent:Connect(monitorProfile)
end
local monitorRaid=net:FindFirstChild('SkeletonRaid')
if monitorRaid and monitorRaid:IsA('RemoteEvent') then
    state.connections[#state.connections+1]=monitorRaid.OnClientEvent:Connect(function(payload)
        Monitor.raid(tracking,payload,os.clock())
    end)
end
local lastMonitorRequest=-math.huge
local function requestMonitorSync()
    if os.clock()-lastMonitorRequest<5 then return end
    lastMonitorRequest=os.clock()
    local remote=net:FindFirstChild('RequestSync')
    if remote and remote:IsA('RemoteEvent') then remote:FireServer() end
end
local function resetMonitorSession()
    if tracking.bone~=nil then tracking.base=tracking.bone;tracking.since=os.clock() end
end
local monitorCached,monitorCachedAt=nil,-math.huge
local function monitorSnapshot()
    local now=os.clock()
    if monitorCached and now-monitorCachedAt<.5 then return monitorCached end
    local function number(value)
        if value==nil then return 'Waiting for sync' end
        local text=tostring(math.floor(value))
        while true do local result,n=text:gsub('^(-?%d+)(%d%d%d)','%1,%2');text=result;if n==0 then break end end
        return text
    end
    local function timeLeft(seconds)
        return ('%d:%02d'):format(math.floor(seconds/60),seconds%60)
    end
    getMonitorDomainConfig()
    local id=monitorStorage:GetAttribute('DomainId')
    local endsAt=monitorStorage:GetAttribute('DomainEndsAt')
    local by=monitorStorage:GetAttribute('DomainBy')
    local definition
    if domainConfig and type(id)=='string' then local ok,data=pcall(domainConfig.get,id);if ok then definition=data end end
    local domain=Monitor.domain(id,endsAt,by,workspace:GetServerTimeNow(),definition)
    local elapsed=tracking.since and math.max(0,now-tracking.since) or 0
    local delta=tracking.bone and tracking.base and tracking.bone-tracking.base or nil
    monitorCached={
        bone=number(tracking.bone),war=number(tracking.war),
        delta=delta and ((delta>=0 and '+' or '')..number(delta)) or '--',
        rate=delta and elapsed>=60 and ((delta>=0 and '+' or '')..number(delta*3600/elapsed)..' / hour') or 'Available after 60s',
        updated=tracking.updated and math.floor(now-tracking.updated)..'s ago' or 'Waiting for sync',
        domain=domain.name,domainTime=domain.remaining>0 and timeLeft(domain.remaining) or '--',boost=domain.boost,openedBy=domain.by,
    }
    monitorCachedAt=now
    return monitorCached
end

state.webhookStatus='OFF';state.webhookSent=0;state.webhookFailed=0;state.webhookPending=false
if type(env.OriginWeatherAlertEpisodes)~='table' then env.OriginWeatherAlertEpisodes={} end
local weatherEpisodes=env.OriginWeatherAlertEpisodes
local weatherServer=tostring(game.JobId or '')..':'..tostring(game.PlaceId or '')
local lastWebhookSend=-math.huge
local function weatherURL(value)
    return WeatherWebhook.url(value)
end
local function setWeatherURL(value)
    if not state.alive or state.profileLoading then return false end
    local url=weatherURL(value)
    if type(value)=='string' and value:match('^%s*$') then flags.WeatherWebhookURL='';state.webhookStatus='URL cleared';return true end
    if not url then state.webhookStatus='Enter a valid Discord webhook URL';return false end
    flags.WeatherWebhookURL=url;state.webhookStatus='URL saved in session; SAVE profile to persist'
    return true
end
local function weatherDomainOptions()
    return WeatherWebhook.options(getMonitorDomainConfig())
end
local function weatherTransport()
    if type(request)=='function' then return request end
    if type(http_request)=='function' then return http_request end
    if type(syn)=='table' and type(syn.request)=='function' then return syn.request end
    return nil
end
local function sendWeatherWebhook(test,id,endsAt,reason)
    if state.webhookPending then return false,'A webhook request is pending' end
    local url=weatherURL(flags.WeatherWebhookURL)
    if not url then state.webhookStatus='Webhook URL missing/invalid';return false,'not-started' end
    local transport=weatherTransport()
    if not transport then state.webhookStatus='Executor HTTP request API unavailable';return false,'not-started' end
    if os.clock()-lastWebhookSend<5 then return false,'not-started' end
    lastWebhookSend=os.clock();state.webhookPending=true;state.webhookStatus=test and 'Sending test…' or 'Sending Domain alert…'
    local function activeSend()
        return state.alive and not state.profileLoading and flags.WeatherWebhookURL==url and (test or (flags.WeatherWebhookEnabled==true and WeatherWebhook.target(id,getMonitorDomainConfig(),flags.WeatherWebhookDomains)))
    end
    local def
    local config=getMonitorDomainConfig()
    if config and type(config.get)=='function' and id then local ok,value=pcall(config.get,id);if ok then def=value end end
    def=type(def)=='table' and def or {}
    local remaining=type(endsAt)=='number' and math.max(0,math.ceil(endsAt-workspace:GetServerTimeNow())) or 0
    local fields={}
    if not test then
        fields[#fields+1]={name='Rarity',value=tostring(reason or 'Rare domain'),inline=true}
        fields[#fields+1]={name='Remaining',value=('%d:%02d'):format(math.floor(remaining/60),remaining%60),inline=true}
        if type(def.base)=='number' and type(def.pct)=='number' then fields[#fields+1]={name='Luck boost',value=('+%d / +%d%%'):format(def.base,math.floor(def.pct*100+.5)),inline=true} end
        fields[#fields+1]={name='Server',value=tostring(game.JobId or 'unknown'):sub(1,120),inline=false}
    end
    local embed={title=test and 'ACO webhook test' or ('Domain: '..tostring(def.name or id):sub(1,120)),description=test and 'Your weather/Domain webhook is connected.' or 'A selected Domain is active on this server.',color=10188031,fields=fields}
    if not test and type(game.PlaceId)=='number' and type(game.JobId)=='string' and game.JobId~='' then
        embed.url='https://www.roblox.com/games/start?placeId='..game.PlaceId..'&gameInstanceId='..game.JobId
    end
    local encoded,body=pcall(function() return HttpService:JSONEncode({content=test and 'ACO webhook test' or '@everyone',allowed_mentions={parse=test and {} or {'everyone'}},embeds={embed}}) end)
    if not encoded then state.webhookPending=false;state.webhookStatus='Webhook payload encoding failed';return false,'not-started' end
    local success=false
    for attempt=1,3 do
        if not activeSend() then state.webhookStatus='Cancelled';break end
        local ok,response=pcall(transport,{Url=url,Method='POST',Headers={['Content-Type']='application/json'},Body=body})
        local code=ok and type(response)=='table' and tonumber(response.StatusCode or response.Status)
        if code and code>=200 and code<300 then
            success=true;state.webhookSent=state.webhookSent+1;state.webhookStatus=test and 'Test delivered' or 'Domain alert delivered';break
        end
        if code==429 and attempt<3 then
            local retry=5
            if type(response.Body)=='string' then
                local decoded,data=pcall(function() return HttpService:JSONDecode(response.Body) end)
                if decoded and type(data)=='table' then retry=tonumber(data.retry_after) or retry end
            end
            retry=math.clamp(retry,1,30)
            state.webhookStatus='Rate limited; retry '..attempt..'/2'
            local deadline=os.clock()+retry
            while activeSend() and os.clock()<deadline do task.wait(.1) end
        else
            state.webhookFailed=state.webhookFailed+1
            state.webhookStatus=code and ('Delivery failed: HTTP '..code) or 'Transport failed; no automatic retry'
            break
        end
    end
    state.webhookPending=false
    return success,'attempted'
end
local function testWeatherWebhook()
    if state.webhookPending then return end
    task.spawn(function() sendWeatherWebhook(true) end)
end
task.spawn(function()
    while state.alive do
        if flags.WeatherWebhookEnabled and not state.profileLoading then
            local config=getMonitorDomainConfig()
            local id=monitorStorage:GetAttribute('DomainId')
            local endsAt=monitorStorage:GetAttribute('DomainEndsAt')
            local episode=WeatherWebhook.episode(weatherEpisodes,weatherServer,id,endsAt,workspace:GetServerTimeNow())
            if not config then state.webhookStatus='Waiting for DomainConfig'
            elseif not weatherURL(flags.WeatherWebhookURL) then state.webhookStatus='Webhook URL missing/invalid'
            elseif episode then
                local target,reason=WeatherWebhook.target(id,config,flags.WeatherWebhookDomains)
                if target and episode.attemptedURL~=flags.WeatherWebhookURL and not state.webhookPending and os.clock()-lastWebhookSend>=5 then
                    episode.attemptedURL=flags.WeatherWebhookURL
                    local _,outcome=sendWeatherWebhook(false,id,endsAt,reason)
                    if outcome=='not-started' then episode.attemptedURL=nil end
                elseif not target and not state.webhookPending then state.webhookStatus='Watching selected Domains' end
            elseif not state.webhookPending then state.webhookStatus='Watching selected Domains' end
        elseif not state.webhookPending then state.webhookStatus='OFF' end
        task.wait(.5)
    end
end)

local activeRules={}
do
    env.OriginActiveRuleHistory=type(env.OriginActiveRuleHistory)=='table' and env.OriginActiveRuleHistory or {}
    local store=ActiveRules.new(env.OriginActiveRuleHistory)
    state.activeRuleStatus='OFF';state.activeRuleLast='--';state.activePending=false
    local lastRequest=-math.huge
    local preferredLane=1
    function activeRules.syncEditor()
        local id=flags.ActiveRuleCard
        if not ActiveRules.cardId(id) then id='SCP3008';flags.ActiveRuleCard=id end
        flags.ActiveRules=ActiveRules.normalize(flags.ActiveRules)
        local rule=flags.ActiveRules[id] or ActiveRules.rule(nil)
        flags.ActiveEditEnabled=rule.enabled;flags.ActiveEditMode=rule.mode
        flags.ActiveEditSlot=rule.slot;flags.ActiveEditHP=rule.hp;flags.ActiveEditRound=rule.round
    end
    function activeRules.edit(key,value)
        if key=='ActiveRuleCard' then
            if ActiveRules.cardId(value) then flags.ActiveRuleCard=value;activeRules.syncEditor() end
        elseif key=='ActiveRuleLane' then flags.ActiveRuleLane=ActiveRules.lane(value)
        elseif key=='ActiveRulesEnabled' then flags.ActiveRulesEnabled=value==true
        else
            local fields={ActiveEditEnabled='enabled',ActiveEditMode='mode',ActiveEditSlot='slot',ActiveEditHP='hp',ActiveEditRound='round'}
            local field=fields[key]
            if not field then return false end
            local rule=ActiveRules.rule(flags.ActiveRules[flags.ActiveRuleCard]);rule[field]=value
            flags.ActiveRules[flags.ActiveRuleCard]=ActiveRules.rule(rule);activeRules.syncEditor()
        end
        flags.ActiveRulesRevision=(flags.ActiveRulesRevision or 0)+1
        return true
    end
    function activeRules.options()
        local found={};local received=false
        for _,lane in ipairs(ActiveRules.lanes(flags.ActiveRuleLane)) do
            local entry=store.lanes[lane]
            if entry then
                received=true
                for id in pairs(entry.abilities) do found[id]=true end
            end
        end
        if not received then
            found.SCP3008=true
            for id in pairs(store.known) do found[id]=true end
            for id in pairs(flags.ActiveRules) do found[id]=true end
        end
        local ids={};for id in pairs(found) do ids[#ids+1]=id end;table.sort(ids)
        return ids
    end
    function activeRules.preview(lane)
        lane=lane or ActiveRules.lanes(flags.ActiveRuleLane)[1]
        if flags.ActiveRuleLane~='Both lanes' and flags.ActiveRuleLane~=lane then return 'Not selected' end
        local entry=store.lanes[lane]
        if not entry then return 'Waiting for battle sync' end
        local parts={}
        for slot=1,5 do local card=entry.cards[slot]
            if card and type(card.currentHP)=='number' and type(card.maxHP)=='number' and card.maxHP>0 then
                parts[#parts+1]=('S%d %.0f%%'):format(slot,card.currentHP/card.maxHP*100)
            end
        end
        return 'R'..tostring(entry.round or '?')..' | '..table.concat(parts,' / ')
    end
    activeRules.syncEditor()
    local sync=net:FindFirstChild('BattleState')
    if sync and sync:IsA('RemoteEvent') then
        state.connections[#state.connections+1]=sync.OnClientEvent:Connect(function(data)
            if not state.alive then return end
            data=ActiveRules.battleData(data)
            if ActiveRules.snapshot(store,data,os.clock()) then
                if flags.ActiveRulesEnabled and not state.profileLoading and (flags.ActiveRuleLane=='Both lanes' or flags.ActiveRuleLane==data.lane) then
                    ActiveRules.armStarts(store.lanes[data.lane],flags.ActiveRules,os.clock())
                end
                for id in pairs(store.known) do
                    if not flags.ActiveRules[id] then flags.ActiveRules[id]=ActiveRules.rule(nil);flags.ActiveRulesRevision=(flags.ActiveRulesRevision or 0)+1 end
                end
            end
        end)
    else state.activeRuleLast='BattleState remote unavailable' end
    state.connections[#state.connections+1]=battleEvent.OnClientEvent:Connect(function(event)
        if state.alive then ActiveRules.event(store,event,os.clock()) end
    end)
    task.spawn(function()
        while state.alive do
            if flags.ActiveRulesEnabled and not state.profileLoading then
                local payload,reason,entry=ActiveRules.nextCandidate(store,flags.ActiveRuleLane,flags.ActiveRules,os.clock(),preferredLane)
                state.activeRuleStatus=reason
                if payload and not state.activePending and not state.pending and os.clock()-lastRequest>=1 then
                    -- Claim before InvokeServer yields. Do not replay an uncertain/rejected request.
                    ActiveRules.mark(store,entry,payload.cardId)
                    preferredLane=payload.lane==1 and 2 or 1
                    lastRequest=os.clock();state.activePending=true
                    state.activeRuleLast='Requesting L'..payload.lane..' '..payload.cardId..' / '..reason
                    log('ActiveRuleRequest',{payload=payload,reason=reason})
                    local response=table.pack(pcall(function() return action:InvokeServer('GuestActive',payload) end))
                    state.activePending=false
                    log('ActiveRuleResponse',{payload=payload,response=response})
                    if state.alive then
                        local retry=ActiveRules.retryBusy(store,entry,payload.cardId,response,os.clock())
                        if retry then
                            state.activeRuleLast='L'..payload.lane..': ability busy; waiting to retry '..payload.cardId
                            log('ActiveRuleRetry',{payload=payload,reason='the ability is already resolving'})
                        else
                            state.activeRuleLast=response[1] and (response[2]==false and 'Server rejected L'..payload.lane..' '..payload.cardId..'; see capture' or 'Request returned L'..payload.lane..': '..payload.cardId..'; see capture') or ('Request failed L'..payload.lane..': '..payload.cardId..'; no retry this battle')
                        end
                    end
                end
            elseif not state.activePending then
                state.activeRuleStatus='OFF'
                if not flags.ActiveRulesEnabled then ActiveRules.cancelStarts(store) end
            end
            task.wait(.1)
        end
    end)
end

local dungeon={}
do
    local enabled=false;local generation=0;local busy=false;local remote;local config;local owned;local entering;local result;local lastView;local nextCall=0;local requestBusy=false
    state.dungeonStatus='OFF';state.dungeonBusy=false;state.dungeonPending=false
    local nativeUi;local nextNativeProbe=0
    local function ask(verb,payload)
        if not nativeUi and os.clock()>=nextNativeProbe then
            nextNativeProbe=os.clock()+10
            pcall(function()
                local shared=game:GetService('ReplicatedStorage'):FindFirstChild('Shared')
                local uiFolder=shared and shared:FindFirstChild('UI')
                local module=uiFolder and uiFolder:FindFirstChild('GateUI')
                if module then nativeUi=require(module) end
            end)
        end
        local api=type(nativeUi)=='table' and nativeUi.api
        if type(api)=='table' and type(api.call)=='function' then return api.call(verb,payload or {}) end
        return remote:InvokeServer(verb,payload or {})
    end
    local function call(verb,payload,cleanup,system)
        local function allowed() return cleanup or (state.alive and not state.profileLoading and ((system and flags.SystemRunning) or (not system and enabled))) end
        while requestBusy or os.clock()<nextCall do
            if not allowed() then return nil,'Stopped' end
            task.wait(.1)
        end
        if not allowed() then return nil,'Stopped' end
        requestBusy=true;state.dungeonPending=true
        local function finish(ok,reason,view)
            requestBusy=false;state.dungeonPending=false
            return ok,reason,view
        end
        for attempt=1,4 do
            while os.clock()<nextCall do
                if not allowed() then return finish(nil,'Stopped') end
                task.wait(.1)
            end
            if not allowed() then return finish(nil,'Stopped') end
            nextCall=os.clock()+1.5
            log('DungeonRequest',{action=verb,payload=payload,attempt=attempt})
            local response=table.pack(pcall(ask,verb,payload))
            log('DungeonResponse',{action=verb,response=response,attempt=attempt})
            if response[1]~=true then return finish(nil,'Request failed; result unknown') end
            if type(response[4])=='table' then lastView=response[4] end
            if response[2]==true then return finish(true,response[3],response[4]) end
            if response[2]==false and response[3]=='Slow down' and attempt<4 then
                local delay=2^attempt;nextCall=os.clock()+delay
                local status='Server busy; retrying in '..delay..'s'
                if system then state.systemStatus=status else state.dungeonStatus=status end
                log('DungeonRetry',{action=verb,delay=delay,reason='Slow down'})
            else
                local reason=response[3]=='Slow down' and 'Server busy (Slow down); wait a moment, then turn this mode ON again' or tostring(response[3] or 'Server rejected request')
                return finish(nil,reason)
            end
        end
    end
    local eventRemote=net:FindFirstChild('GateEvent')
    if eventRemote and eventRemote:IsA('RemoteEvent') then
        state.connections[#state.connections+1]=eventRemote.OnClientEvent:Connect(function(event)
            if not state.alive or not busy or type(event)~='table' or event.type~='dungeon' then return end
            local run=event.run
            if not owned and entering and type(run)=='table' and run.gate==entering and run.id~=nil then owned={id=run.id,gate=run.gate} end
            local outcome=Dungeon.event(owned,event)
            if outcome and not result then result=outcome;log('DungeonResult',{run=owned,phase=event.phase,result=outcome}) end
            if owned and type(run)=='table' and run.id==owned.id and run.gate==owned.gate then
                state.dungeonFloor=run.floor;state.dungeonGate=run.gate
            end
        end)
    end
    function dungeon.stop()
        enabled=false;generation=generation+1;state.dungeonEnabled=false;flags.DungeonRunning=false
        state.dungeonStatus=busy and 'Stopping; waiting for pending request' or 'OFF'
    end
    function dungeon.start()
        if busy then message('Dungeon worker is still active; wait for it to stop.','warning');return end
        remote=net:FindFirstChild('GateAction')
        if not remote or not remote:IsA('RemoteFunction') or not eventRemote then message('GateAction/GateEvent unavailable in this server.','warning');return end
        local ok,value=pcall(function()
            local shared=game:GetService('ReplicatedStorage'):WaitForChild('Shared',10)
            return require(shared:WaitForChild('Config',10):WaitForChild('GateConfig',10))
        end)
        if not ok or type(value)~='table' or type(value.Order)~='table' or value.Order[1]~='E' or type(value.isUnlocked)~='function' or type(value.window)~='function' then message('Dungeon config unavailable.','warning');return end
        config=value;enabled=true;busy=true;generation=generation+1
        state.dungeonEnabled=true;state.dungeonBusy=true;flags.DungeonRunning=true
        local token=generation
        local function active() return enabled and state.alive and generation==token end
        local function waitFor(seconds)
            local untilTime=os.clock()+seconds
            while active() and os.clock()<untilTime do task.wait(.2) end
            return active()
        end
        task.spawn(function()
            local finishedReason
            local function work()
                local good,reason=call('state')
                if not active() then return end
                if not good then error(reason) end
                if not Dungeon.highest(config,lastView) then error('Missing verified gate unlock data') end
                if type(lastView.dungeon)=='table' or type(lastView.run)=='table' then error('Already in a gate; leave the existing run before starting Smart progression') end
                local ceiling=Dungeon.highest(config,lastView)
                state.dungeonCeiling=config.Order[ceiling]
                local index=Dungeon.firstUncleared(config,lastView,ceiling)
                if not index then finishedReason='completed';state.dungeonStatus='All unlocked gates already cleared';return end
                -- Native auto-hop must not race the script's gate selection. Dungeon AUTO drives floors.
                good,reason=call('auto',{on=false});if not good then error(reason) end
                while active() do
                    local highest=Dungeon.highest(config,lastView)
                    if not highest then error('Gate unlock state missing') end
                    index=math.min(index,highest)
                    local id=config.Order[index]
                    state.dungeonGate=id;state.dungeonStatus='Climbing gate '..id..' / target '..state.dungeonCeiling
                    local open,delay=config.window(id,workspace:GetServerTimeNow())
                    if not open then
                        state.dungeonStatus='Waiting for gate '..id..' to open'
                        if not waitFor(math.min(10,math.max(1,tonumber(delay) or 5))) then break end
                        good,reason=call('state');if not good then error(reason) end
                    else
                        owned=nil;result=nil;entering=id
                        good,reason=call('enter',{gate=id})
                        if not good then owned=nil;entering=nil;error(reason) end
                        local run=lastView and lastView.dungeon
                        if type(run)=='table' and run.id~=nil and run.gate==id then
                            if owned and owned.id~=run.id then owned=nil;entering=nil;error('Dungeon admission/event run IDs disagree') end
                            owned={id=run.id,gate=id};state.dungeonFloor=run.floor
                        end
                        entering=nil
                        if not active() then break end
                        if not owned then error('No verified dungeon run ID returned; stopped without guessing') end
                        if not result then good,reason=call('autoplay',{on=true});if not good then error(reason) end end
                        local deadline=os.clock()+7200
                        local pollAt=os.clock()+8
                        while active() and not result do
                            if os.clock()>deadline then error('No matched dungeon completion after two hours') end
                            if not waitFor(1) then break end
                            if result then break end
                            if os.clock()>=pollAt then
                                good,reason=call('state');if not good then error(reason) end
                                pollAt=os.clock()+8
                                local current=lastView and lastView.dungeon
                                if not result and (type(current)~='table' or current.id~=owned.id) then error('Dungeon run changed/ended without a matched result; stopped') end
                            end
                        end
                        if not active() then break end
                        good,reason=call('autoplay',{on=false});if not good then error(reason) end
                        good,reason=call('leave');if not good then error(reason) end
                        local leaveDeadline=os.clock()+15
                        while active() and lastView and (type(lastView.dungeon)=='table' or type(lastView.run)=='table') and os.clock()<leaveDeadline do
                            if not waitFor(2) then break end
                            good,reason=call('state');if not good then error(reason) end
                        end
                        if not active() then break end
                        if lastView and (type(lastView.dungeon)=='table' or type(lastView.run)=='table') then error('Previous dungeon has not closed; stopped') end
                        good,reason=call('state');if not good then error(reason) end
                        highest=Dungeon.highest(config,lastView);if not highest then error('Missing gate unlock state') end
                        local outcome=result
                        local nextIndex=Dungeon.next(index,outcome,ceiling)
                        if nextIndex then nextIndex=Dungeon.firstUncleared(config,lastView,ceiling,nextIndex) end
                        owned=nil;entering=nil;result=nil
                        if not nextIndex then
                            finishedReason=outcome=='loss' and 'loss' or 'completed'
                            state.dungeonStatus=outcome=='loss' and ('Lost at gate '..id..'; stopped') or ('Completed target gate '..id..'; stopped')
                            break
                        end
                        index=nextIndex
                        if not waitFor(2) then break end
                    end
                end
            end
            local worked,err=pcall(work)
            if owned then call('autoplay',{on=false},true) end
            enabled=false;busy=false;state.dungeonEnabled=false;state.dungeonBusy=false;flags.DungeonRunning=false
            if not worked then state.dungeonStatus=tostring(err):gsub('^.-:%d+:%s*',''):sub(1,250);log('DungeonStopped',{reason=state.dungeonStatus})
            elseif not state.alive or generation~=token then state.dungeonStatus='OFF' end
            if worked and finishedReason and state.alive and generation==token and not state.profileLoading and dungeon.onFinished then dungeon.onFinished(finishedReason) end
        end)
    end
    state.systemStatus='OFF';state.systemBusy=false
    local systemFailed=false
    function dungeon.syncSystemEditor()
        flags.SystemPriority=Dungeon.priority(flags.SystemPriority)
        for i,id in ipairs(flags.SystemPriority) do flags['SystemPriority'..i]=id:upper() end
    end
    function dungeon.editSystemPriority(key,value)
        local index=type(key)=='string' and tonumber(key:match('^SystemPriority([1-5])$'))
        if not index then return false end
        flags.SystemPriority=Dungeon.editPriority(flags.SystemPriority,index,value);dungeon.syncSystemEditor()
        return true
    end
    dungeon.syncSystemEditor()
    task.spawn(function()
        while state.alive do
            if flags.SystemRunning and not state.profileLoading then
                systemFailed=false;state.systemBusy=true
                local worked,err=pcall(function()
                    if not remote then remote=net:FindFirstChild('GateAction') end
                    if not remote or not remote:IsA('RemoteFunction') then error('GateAction unavailable') end
                    if not config then
                        local shared=game:GetService('ReplicatedStorage'):WaitForChild('Shared',10)
                        config=require(shared:WaitForChild('Config',10):WaitForChild('GateConfig',10))
                    end
                    if type(config.statLimit)~='function' then error('System stat limits unavailable') end
                    local ok,reason=call('state',nil,nil,true)
                    if not ok then if not flags.SystemRunning or state.profileLoading or not state.alive then return end;error(reason) end
                    local spend,why=Dungeon.allocate(config,lastView,flags.SystemPriority)
                    if not spend then state.systemStatus=why;return end
                    local before={};local labels={}
                    for id,n in pairs(spend) do before[id]=lastView.points[id];if n>0 then labels[#labels+1]=id:upper()..' +'..n end end
                    table.sort(labels);state.systemStatus='Upgrading '..table.concat(labels,' / ')
                    ok,reason=call('spend',spend,nil,true)
                    if not ok then if not flags.SystemRunning or state.profileLoading or not state.alive then return end;error(reason) end
                    ok,reason=call('state',nil,nil,true);if not ok then error(reason) end
                    for id,n in pairs(spend) do
                        if n>0 and (not lastView or type(lastView.points)~='table' or type(lastView.points[id])~='number' or lastView.points[id]<before[id]+n) then error('System spend not confirmed; stopped without retry') end
                    end
                    state.systemStatus='Confirmed '..table.concat(labels,' / ')
                end)
                state.systemBusy=false
                if not worked then systemFailed=true;flags.SystemRunning=false;state.systemStatus=tostring(err):gsub('^.-:%d+:%s*',''):sub(1,240);log('SystemStopped',{reason=state.systemStatus}) end
            elseif not systemFailed then state.systemStatus='OFF' end
            task.wait(10)
        end
        state.systemBusy=false
    end)

end

local war={}
do
    local running=false;local busy=false;local revision=0;local sequence=0;local latest;local ends={};local endOrder={}
    state.warStatus='OFF';state.warEnabled=false;state.warBusy=false;state.warPending=false
    local function desired() return flags.WarBossName=='Goku' and 'Son' or 'Punch' end
    local function valid(snapshot)
        return type(snapshot)=='table' and snapshot.active==true and type(snapshot.battleId)=='string' and (snapshot.lane==1 or snapshot.lane==2)
            and type(snapshot.teamWar)=='table' and (snapshot.teamWar.kind=='Son' or snapshot.teamWar.kind=='Punch')
    end
    local function track(snapshot)
        if not valid(snapshot) then return end
        sequence=sequence+1;latest={snapshot=snapshot,sequence=sequence}
        local attempt=state.warInFlight
        if attempt and attempt.battleId==snapshot.battleId then attempt.lane=snapshot.lane end
    end
    local stateRemote=net:FindFirstChild('BattleState')
    if stateRemote and stateRemote:IsA('RemoteEvent') then state.connections[#state.connections+1]=stateRemote.OnClientEvent:Connect(function(snapshot) if state.alive then track(snapshot) end end) end
    state.connections[#state.connections+1]=battleEvent.OnClientEvent:Connect(function(event)
        if not state.alive or type(event)~='table' or event.type~='BattleEnd' or type(event.battleId)~='string' then return end
        if not ends[event.battleId] then endOrder[#endOrder+1]=event.battleId end
        ends[event.battleId]=event
        if #endOrder>64 then ends[table.remove(endOrder,1)]=nil end
        if latest and latest.snapshot.battleId==event.battleId and (event.lane==nil or event.lane==latest.snapshot.lane) then latest.ended=true end
        local attempt=state.warInFlight
        if attempt and event.battleId==attempt.battleId and (event.lane==nil or event.lane==attempt.lane) then attempt.ended=true end
    end)
    local function adopt(snapshot)
        local team=player:GetAttribute('WarTeam')
        local expected=desired()
        local bossId=expected=='Son' and 'WarBossSonWarrior' or 'WarBossPunchHero'
        local portrait=type(snapshot)=='table' and snapshot.enemy and snapshot.enemy.portrait
        if not valid(snapshot) or snapshot.teamWar.kind~=expected or snapshot.teamWar.team~=team or type(portrait)~='table' or portrait.cardId~=bossId then return nil end
        local ending=ends[snapshot.battleId]
        return {battleId=snapshot.battleId,lane=snapshot.lane,kind=expected,ended=ending~=nil and (ending.lane==nil or ending.lane==snapshot.lane)}
    end
    function war.stop()
        running=false;revision=revision+1;state.warEnabled=false;flags.WarRunning=false
        state.warStatus=busy and 'Stopping; current fight continues' or 'OFF'
    end
    function war.start()
        if busy then return end
        local team=player:GetAttribute('WarTeam');local expected=desired()
        if team~='Son' and team~='Punch' then state.warStatus='Join a Team War faction in game first';flags.WarRunning=false;return end
        if (team=='Son' and expected~='Punch') or (team=='Punch' and expected~='Son') then
            state.warStatus=team=='Son' and 'Your Goku team can fight Saitama only' or 'Your Saitama team can fight Goku only';flags.WarRunning=false;return
        end
        local remote=net:FindFirstChild('TeamWarAction')
        if not remote or not remote:IsA('RemoteFunction') then state.warStatus='TeamWarAction unavailable';flags.WarRunning=false;return end
        running=true;busy=true;revision=revision+1
        state.warEnabled=true;state.warBusy=true;flags.WarRunning=true
        local token=revision
        local function active() return state.alive and running and revision==token end
        local function waitFor(seconds)
            local untilTime=os.clock()+seconds
            while active() and os.clock()<untilTime do task.wait(.2) end
            return active()
        end
        task.spawn(function()
            local function work()
                while active() do
                    if desired()~=expected then error('Boss selection changed; restart War Boss') end
                    local currentTeam=player:GetAttribute('WarTeam')
                    if currentTeam~=team then error('Team changed; stopped') end
                    local attempt=state.warInFlight
                    if not attempt or attempt.ended or attempt.kind~=expected then
                        attempt=latest and not latest.ended and adopt(latest.snapshot)
                        if attempt and attempt.ended then attempt=nil end
                    end
                    if not attempt then
                        local before=sequence
                        state.warStatus='Starting '..flags.WarBossName
                        local response
                        for retry=1,3 do
                            if not active() then return end
                            state.warPending=true
                            log('WarRequest',{action='fight',boss=flags.WarBossName,attempt=retry})
                            response=table.pack(pcall(function() return remote:InvokeServer('fight') end))
                            state.warPending=false;log('WarResponse',response)
                            if response[1]==true and response[2]==false and response[3]=='Slow down' and retry<3 then
                                state.warStatus='Server busy; waiting to retry'
                                if not waitFor(2^retry) then return end
                            else break end
                        end
                        if response[1]~=true then error('War request failed; result unknown') end
                        if response[2]~=true then error(tostring(response[3] or 'War start rejected')) end
                        if type(response[4])=='table' then attempt=adopt(response[4]) end
                        if not attempt then
                            local deadline=os.clock()+12
                            while state.alive and os.clock()<deadline do
                                if latest and latest.sequence>before then attempt=adopt(latest.snapshot);if attempt then break end end
                                if not active() then break end
                                task.wait(.1)
                            end
                        end
                        if not attempt then error('No matching War battle ID; stopped without repeating the request') end
                    end
                    state.warInFlight=attempt
                    log('WarAdmitted',{battleId=attempt.battleId,lane=attempt.lane,boss=flags.WarBossName})
                    state.warStatus='Farming '..flags.WarBossName..' / lane '..attempt.lane
                    local deadline=os.clock()+1800
                    while active() and not attempt.ended do
                        if os.clock()>deadline then error('No matching War BattleEnd after 30 minutes') end
                        task.wait(.2)
                    end
                    if not active() then break end
                    log('WarCompleted',{battleId=attempt.battleId,lane=attempt.lane})
                    if not waitFor(2) then break end
                end
            end
            local ok,reason=pcall(work)
            running=false;busy=false;state.warEnabled=false;state.warBusy=false;flags.WarRunning=false
            state.warStatus=not ok and tostring(reason):gsub('^.-:%d+:%s*',''):sub(1,240) or 'OFF'
        end)
    end
end

dungeon.onFinished=function(reason)
    log('DungeonHandoff',{reason=reason,mode=flags.DungeonAfter})
    if flags.DungeonAfter=='Story' then beginRun()
    elseif flags.DungeonAfter=='War Boss' then war.start() end
end
local ranked={}
do
    local remote=net:FindFirstChild('RankedAction')
    local events=net:FindFirstChild('RankedEvent')
    local running=false;local pending=false;local phase='idle';local nextAt=0;local battleId
    local function finish(text)
        running=false;state.rankedEnabled=false;flags.RankedRunning=false;state.rankedStatus=text
    end
    if events and events:IsA('RemoteEvent') then
        state.connections[#state.connections+1]=events.OnClientEvent:Connect(function(event)
            if not state.alive or type(event)~='table' then return end
            log('RankedEvent',event)
            if event.kind=='Searching' then phase='searching';state.rankedStatus='Searching'
            elseif event.kind=='MatchFound' then phase='battle';battleId=nil;state.rankedStatus='Match found'
            elseif event.kind=='Result' then phase='idle';battleId=nil;nextAt=os.clock()+5;state.rankedStatus='Match finished'
            elseif event.kind=='Aborted' or event.kind=='SearchStopped' then
                phase='idle';battleId=nil
                if running then finish(tostring(event.reason or 'Search stopped; turn ON to retry')) end
            end
        end)
    end
    local sync=net:FindFirstChild('BattleState')
    if sync then state.connections[#state.connections+1]=sync.OnClientEvent:Connect(function(data)
        if type(data)~='table' or type(data.battleId)~='string' or not data.battleId:match('^pvp%-') then return end
        if data.active==true then phase='battle';battleId=data.battleId;state.rankedStatus='In Ranked battle'
        elseif data.active==false and battleId==data.battleId then phase='idle';battleId=nil;nextAt=os.clock()+5 end
    end) end
    function ranked.stop()
        finish('OFF; current match continues')
        if phase=='searching' and not pending and remote then
            pending=true
            task.spawn(function() pcall(function() remote:InvokeServer('cancel') end);pending=false end)
        end
    end
    function ranked.start()
        if running then return end
        if not remote or not remote:IsA('RemoteFunction') or not events then finish('Ranked remotes unavailable');return end
        running=true;state.rankedEnabled=true;flags.RankedRunning=true
        state.rankedStatus=phase=='idle' and 'Ready to search' or 'Waiting for current search / match'
    end
    task.spawn(function()
        while state.alive do
            if running and not state.profileLoading and not pending and phase=='idle' and os.clock()>=nextAt then
                pending=true;phase='requesting';state.rankedStatus='Starting search'
                local mode=flags.RankedMode=='Scaled' and 'scaled' or 'normal'
                local response=table.pack(pcall(function() return remote:InvokeServer('play',{mode=mode}) end))
                log('RankedResponse',{mode=mode,response=response})
                pending=false
                if not response[1] or response[2]~=true then
                    if phase=='requesting' then phase='idle' end
                    finish(tostring(response[1] and response[3] or 'Request failed; search state unknown'))
                elseif phase=='requesting' then phase='searching';state.rankedStatus='Searching' end
                if not running and phase=='searching' then pcall(function() remote:InvokeServer('cancel') end) end
            end
            task.wait(1)
        end
    end)
end

local sessionRuntime=SessionRuntime.start({game=game,player=player,state=state,flags=flags,env=env,notice=function(text,kind) if ui then ui.Notify(text,kind,5) end end})
local function syncRunFlags()
    flags.StoryRunning=state.enabled==true
    flags.SkillRunning=state.skillEnabled==true
    flags.HLRunning=state.hlEnabled==true
    flags.DungeonRunning=state.dungeonEnabled==true
    flags.WarRunning=state.warEnabled==true
    flags.RankedRunning=state.rankedEnabled==true
end
local function applyRunFlags()
    local storyOn,skillOn,hlOn=flags.StoryRunning,flags.SkillRunning,flags.HLRunning
    if storyOn then beginRun() end
    if skillOn then startSkills() end
    if hlOn then startHL() end
    if flags.DungeonRunning then dungeon.start() end
    if flags.WarRunning then war.start() end
    if flags.RankedRunning then ranked.start() end
    syncRunFlags()
end
local function setFlag(key,value)
    if state.profileLoading then message('Profile is loading; wait for mode transitions.','warning');return end
    if key=='StoryRunning' then
        if value then beginRun() else stopRun('Story stopped; native fight continues.') end
    elseif key=='SkillRunning' then
        if value then startSkills() else stopSkills() end
    elseif key=='HLRunning' then
        if value then startHL() else stopHL() end
    elseif dungeon.editSystemPriority(key,value) then
    elseif key=='RankedRunning' then
        if value then ranked.start() else ranked.stop() end
    elseif key=='WarRunning' then
        if value then war.start() else war.stop() end
    elseif key=='DungeonRunning' then
        if value then dungeon.start() else dungeon.stop() end
    elseif key=='AntiAFK' or key=='SaveCPU' or key=='WhiteScreen' then
        flags[key]=value==true;if afkRuntime then afkRuntime.apply() end
    elseif key=='AutoExec' then sessionRuntime.setAutoExec(value)
    elseif key=='WeatherWebhookDomains' then flags[key]=WeatherWebhook.selection(value)
    elseif activeRules.edit(key,value) then
    else flags[key]=value end
    syncRunFlags()
    if ui then ui.Repaint() end
end
local profile={currentProfile='Default',autoProfile='',storedNames={},status='Ready',revision=0}
local profileDir='OriginStory'
local canFiles=type(readfile)=='function' and type(writefile)=='function' and type(isfile)=='function' and type(makefolder)=='function'
local index={names={},auto=''}
local function validName(name)
    return type(name)=='string' and #name>0 and #name<=48 and name:match('^[%w _%-]+$')~=nil
end
local function path(name) return profileDir..'/'..name..'.json' end
local function writeIndex() writefile(profileDir..'/index.json',HttpService:JSONEncode(index)) end
local function profileMessage(text,kind) profile.status=text;message(text,kind) end
local function loadProfile(name,quiet)
    if state.profileLoading then profileMessage('A profile is already loading.','warning');return false end
    if not canFiles or not validName(name) then profileMessage('File APIs unavailable or invalid profile name.','warning');return false end
    local ok,data=pcall(function() return HttpService:JSONDecode(readfile(path(name))) end)
    if not ok or type(data)~='table' or data.version~=1 or type(data.flags)~='table' then
        profileMessage('Cannot load profile: '..tostring(name),'error');return false
    end
    local nextFlags=data.flags
    state.profileLoading=true
    if state.enabled then stopRun('Loading profile; stopping Story scheduling.') end
    if state.skillEnabled then stopSkills() end
    if state.hlEnabled then stopHL() end
    if state.dungeonEnabled then dungeon.stop() end
    if state.warEnabled then war.stop() end
    if state.rankedEnabled then ranked.stop() end
    local deadline=os.clock()+30
    while state.alive and (state.pending or state.skillPending or state.hlPending or state.hlBusy or state.activePending or state.dungeonBusy or state.dungeonPending or state.systemBusy or state.warBusy or state.warPending
        or (nextFlags.StoryRunning==true and state.attempt and state.attempt.started and not state.attempt.ended)) do
        profile.status='Waiting for current request / battle before loading'
        if os.clock()>deadline then
            state.profileLoading=false;syncRunFlags()
            profileMessage('Still waiting for current battle/request; load again when it ends.','warning');return false
        end
        task.wait(.1)
    end
    if not state.alive then state.profileLoading=false;return false end
    local maps,cards,modes={},{},{}
    for _,world in ipairs(Story.Worlds) do
        if type(nextFlags.StoryMaps)=='table' and nextFlags.StoryMaps[world.map]==true then maps[world.map]=true end
        for _,id in ipairs(world.cards) do
            if type(nextFlags.StoryCards)=='table' and nextFlags.StoryCards[id]==true then cards[id]=true end
            modes[id]={}
            local selection=type(nextFlags.StoryModes)=='table' and nextFlags.StoryModes[id]
            for _,mode in ipairs(Story.Modes) do
                if type(selection)=='table' and selection[mode]==true then modes[id][mode]=true end
            end
        end
    end
    flags.StoryMaps=maps;flags.StoryCards=cards;flags.StoryModes=modes
    flags.StoryRepeat=nextFlags.StoryRepeat==true
    flags.HLRepeat=nextFlags.HLRepeat==true
    flags.AntiAFK=nextFlags.AntiAFK~=false
    flags.SaveCPU=nextFlags.SaveCPU==true
    flags.WhiteScreen=nextFlags.WhiteScreen==true
    flags.ActiveRules=ActiveRules.normalize(nextFlags.ActiveRules)
    flags.ActiveRulesEnabled=nextFlags.ActiveRulesEnabled==true
    flags.ActiveRuleLane=ActiveRules.lane(nextFlags.ActiveRuleLane)
    flags.ActiveRuleCard=ActiveRules.cardId(nextFlags.ActiveRuleCard) and nextFlags.ActiveRuleCard or 'SCP3008'
    activeRules.syncEditor()
    flags.WeatherWebhookURL=weatherURL(nextFlags.WeatherWebhookURL) or ''
    flags.WeatherWebhookEnabled=nextFlags.WeatherWebhookEnabled==true
    flags.WeatherWebhookDomains=WeatherWebhook.selection(nextFlags.WeatherWebhookDomains,nextFlags.WeatherWebhookClash)
    flags.StoryRunning=nextFlags.StoryRunning==true
    flags.SkillRunning=nextFlags.SkillRunning==true
    flags.HLRunning=nextFlags.HLRunning==true
    flags.DungeonRunning=nextFlags.DungeonRunning==true
    flags.DungeonAfter=(nextFlags.DungeonAfter=='Story' or nextFlags.DungeonAfter=='War Boss') and nextFlags.DungeonAfter or 'Stop'
    flags.RankedMode=nextFlags.RankedMode=='Scaled' and 'Scaled' or 'Normal'
    flags.RankedRunning=nextFlags.RankedRunning==true
    flags.WarRunning=nextFlags.WarRunning==true
    flags.WarBossName=nextFlags.WarBossName=='Goku' and 'Goku' or 'Saitama'
    flags.SystemRunning=nextFlags.SystemRunning==true
    flags.SystemPriority=Dungeon.priority(nextFlags.SystemPriority)
    dungeon.syncSystemEditor()
    flags.AutoSkills={}
    for _,id in ipairs(Skills.Order) do if type(nextFlags.AutoSkills)=='table' and nextFlags.AutoSkills[id]==true then flags.AutoSkills[id]=true end end
    flags.SkillPurchaseMode=nextFlags.SkillPurchaseMode=='PurchaseMax' and 'PurchaseMax' or 'Purchase'
    flags.SkillPrerequisites=nextFlags.SkillPrerequisites==true
    flags.SkillInterval=math.clamp(tonumber(nextFlags.SkillInterval) or 2,1,10)
    for key,value in pairs(nextFlags) do
        if type(key)=='string' and key:match('^AO_UI_') and (type(value)=='string' or type(value)=='number') then flags[key]=value end
    end
    profile.currentProfile=name;profile.status='Loaded: '..name
    state.profileLoading=false
    if afkRuntime then afkRuntime.apply() end
    if ui then applyRunFlags();ui.Repaint() else state.restoreModes=true end
    if not quiet then profileMessage(profile.status,'success') end
    return true
end
local function saveProfile(name)
    if state.profileLoading then profileMessage('Wait for profile load to finish.','warning');return end
    syncRunFlags()
    if not canFiles then profileMessage('Executor file APIs unavailable.','warning');return end
    if not validName(name) then profileMessage('Use 1–48 letters, numbers, spaces, _ or -.','warning');return end
    local ok=pcall(function()
        writefile(path(name),HttpService:JSONEncode({version=1,flags=flags}))
        if not table.find(index.names,name) then table.insert(index.names,name);table.sort(index.names) end
        writeIndex()
    end)
    if ok then profile.currentProfile=name;profile.storedNames=index.names;profileMessage('Saved: '..name,'success')
    else profileMessage('Profile save failed.','error') end
end
local function deleteProfile(name)
    if not canFiles or not validName(name) or type(delfile)~='function' then profileMessage('Delete/file APIs unavailable.','warning');return end
    local ok=pcall(function()
        if isfile(path(name)) then delfile(path(name)) end
        for i=#index.names,1,-1 do if index.names[i]==name then table.remove(index.names,i) end end
        if index.auto==name then index.auto='';profile.autoProfile='' end
        writeIndex()
    end)
    if ok then profile.storedNames=index.names;profileMessage('Deleted: '..name,'success') else profileMessage('Delete failed.','error') end
end
local function setAutoProfile(name)
    if not canFiles or not validName(name) or not table.find(index.names,name) then profileMessage('Save this profile first.','warning');return end
    index.auto=name
    local ok=pcall(writeIndex)
    if ok then profile.autoProfile=name;profileMessage('Auto Load: '..name,'success') else profileMessage('Auto Load save failed.','error') end
end
afkRuntime=AfkRuntime.start({game=game,player=player,playerGui=player:WaitForChild('PlayerGui'),state=state,flags=flags,setFlag=setFlag,notice=function(text,kind) if ui then ui.Notify(text,kind,5) end end})
if canFiles then
    local ok=pcall(function()
        if type(isfolder)~='function' or not isfolder(profileDir) then pcall(makefolder,profileDir) end
        if isfile(profileDir..'/index.json') then
            local data=HttpService:JSONDecode(readfile(profileDir..'/index.json'))
            if type(data)=='table' and type(data.names)=='table' then
                for _,name in ipairs(data.names) do if validName(name) then index.names[#index.names+1]=name end end
                if validName(data.auto) then index.auto=data.auto end
            end
        end
    end)
    profile.storedNames=index.names;profile.autoProfile=index.auto
    if ok and index.auto~='' then loadProfile(index.auto,true) end
else profile.status='File APIs unavailable; session only' end

ui=Library.Create({playerGui=player:WaitForChild('PlayerGui'),state=state,flags=flags,
    Workspace=game:GetService('Workspace'),UIS=game:GetService('UserInputService'),env=env,
    activeRules=activeRules,weatherDomainOptions=weatherDomainOptions,
    setWeatherURL=setWeatherURL,testWeatherWebhook=testWeatherWebhook,
    monitorSnapshot=monitorSnapshot,requestMonitorSync=requestMonitorSync,resetMonitorSession=resetMonitorSession,
    startSkills=startSkills,stopSkills=stopSkills,
    profile=profile,saveProfile=saveProfile,loadProfile=loadProfile,deleteProfile=deleteProfile,setAutoProfile=setAutoProfile,
    setFlag=setFlag,story=Story,start=beginRun,pause=function() stopRun('Stopped; current battle continues in game.') end,
    clearBattle=function()
        if state.pending or state.enabled then message('Stop and wait for pending request first.','warning');return end
        state.awaiting=false;message('Previous battle marked ended; ready to start.')
    end,
    exportCapture=exportCapture,
    rejoinServer=sessionRuntime.rejoin,
})
task.spawn(function()
    while state.alive do if not state.profileLoading and not state.restoreModes then syncRunFlags() end;ui.Repaint();ui.Refresh();task.wait(flags.SaveCPU and 1 or .3) end
end)
requestMonitorSync()
message('Ready: server BattleEnd results matched by battleId.')
if state.restoreModes then state.restoreModes=false;applyRunFlags();ui.Repaint() end
