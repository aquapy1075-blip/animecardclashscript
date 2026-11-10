-- anime duel script
-- UI adapted from anime_origin_ui.lua (aquapy1075-blip/animecardclashscript).
-- Uses only the DraftAction calls captured by the user. Auto is OFF on load.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local UIS = game:GetService('UserInputService')
local Workspace = game:GetService('Workspace')
local TweenService = game:GetService('TweenService')
local playerGui = Players.LocalPlayer:WaitForChild('PlayerGui')
local env = getgenv and getgenv() or _G
local previous = env.AnimeDuelScript
if type(previous) == 'table' and type(previous.destroy) == 'function' then
    if previous.worker then
        previous.stop()
        warn('[AnimeDuel] Previous worker is stopping; run again after it finishes.')
        return
    end
    previous.destroy()
end
if type(env.CustomAutoDraft) == 'table' and env.CustomAutoDraft.running then
    env.CustomAutoDraft.stop()
    warn('[AnimeDuel] Old console auto is stopping. Run this script again when stopped.')
    return
end
local remotes = RS:WaitForChild('Remotes', 15)
assert(remotes, 'Remotes not found')
local action = remotes:WaitForChild('DraftAction', 15)
local event = remotes:WaitForChild('DraftEvent', 15)
assert(action and event, 'DraftAction/DraftEvent not found')
local app = {alive=true, enabled=false, worker=false, bosses={}, connections={}, snapshot=nil,
    version=0, resultVersion=0, logs={}, wins=0, losses=0, clears=0,
    status='Ready — press START', recovery={}, stage=nil, runId=nil,
    config={farm=3, bossFarm=4, delay=.8, timeout=180, theme='Midnight', transparency=15}}
env.AnimeDuelScript = app
local render = function() end
local function track(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(app.connections, connection)
    return connection
end
local function log(text)
    app.status = tostring(text)
    table.insert(app.logs, os.date('%H:%M:%S') .. '  ' .. tostring(text))
    if #app.logs > 100 then table.remove(app.logs, 1) end
    print('[AnimeDuel] ' .. tostring(text))
    render()
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
            log('Draft paused — waiting for World/Raid boss death')
        end
        task.wait(.1)
    end
    check()
    if waiting then log('Bosses ended — resuming Draft') end
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
            log('State unavailable — resyncing in '..(attempt*2)..'s')
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
            log('Opening packs ('..tostring(count)..' available), attempt '..attempt..'/3')
            local result=call('Open','all',1)
            if result.ok then pause(app.config.delay);break end
            log('Open skipped/rejected: '..tostring(result.reason))
            -- Read-only resync; do not replay uncertain mutations.
            refresh();run=activeRun()
            if not run or run.id~=runId then return end
            count=packCount(run)
            if not count or count<=0 or result.uncertain or not result.loading or attempt==3 then
                log('Continuing to AutoTeam; Open will be checked after the next fight')
                break
            end
            pause(attempt*2)
        end
    elseif count==0 then
        log('No packs available — skipping Open')
    else
        log('Pack balance unknown — skipping Open until next State')
    end
    for attempt=1,3 do
        log('Selecting Auto Team, attempt '..attempt..'/3')
        local result=call('AutoTeam',nil,nil)
        if result.ok then
            pause(app.config.delay);refresh()
            run=activeRun()
            if not run or run.id~=runId then return end
            if not validTeam(run) then error('AutoTeam did not confirm a valid four-card team.',0) end
            return
        end
        log('AutoTeam rejected: '..tostring(result.reason))
        refresh();run=activeRun()
        if not run or run.id~=runId then return end
        if result.uncertain or not result.loading or attempt==3 then
            if validTeam(run) then
                log('Using the current four-card team confirmed by State')
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
        log('Waiting for current fight')
        if not waitFor(function() return app.snapshot and not app.snapshot.fighting end,app.config.timeout) then
            error('Current fight timed out; no additional Fight was sent.',0)
        end
    end
    local version=app.resultVersion
    log('Fighting '..(target=='boss' and ('boss '..tostring(activeRun() and activeRun().boss)) or target))
    local sent=call('Fight',target,nil)
    if not sent.ok then
        log('Fight response not accepted — checking State before any further action')
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
    log(tostring(result.name or key)..' — '..result.result)
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
    log('Syncing Draft state')
    local initialVersion=app.version
    refresh()
    if not waitFor(function() return app.version>initialVersion end,8) then
        error('State not received. Capture the State RETURN if this repeats.',0)
    end
    if app.snapshot.fighting then
        log('Waiting for existing fight')
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
            log('Starting a new run')
            local started=call('Start',{},nil)
            if not started.ok then log('Start response not accepted — resyncing without replay') end
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
                        log('Recovery: win '..n..' '..fallback..' fights, then retry '..target)
                    else log('Easy lost; retrying with refreshed team') end
                end
                -- Save fight progression before pack/team requests can fail.
                prepare()
            else
                app.recovery={}; app.runId=nil; app.stage=nil
                log('Run ended; restarting')
            end
        end
        pause(app.config.delay)
    end
end
function app.stop()
    app.enabled=false
    log(app.worker and 'Stopping — current server fight continues' or 'Stopped')
end
function app.start()
    if not app.alive or app.worker then return end
    app.enabled=true; app.worker=true
    task.spawn(function()
        local ok,err=pcall(runLoop)
        app.enabled=false; app.worker=false
        if not ok and tostring(err)~='__STOP__' then
            log('ERROR: '..tostring(err))
        else log('Stopped') end
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
for i,name in ipairs({'Draft','Settings','Logs'}) do
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
track(start.Activated,app.start);track(stop.Activated,app.stop)
local statusLabel=status('Status')
local runLabel=status('Run / Boss / Recovery')
local teamLabel=status('Current team')
local scoreLabel=status('Session results')
local hint=row('Draft','Strategy',76)
local hintText=text(hint,'Easy → Medium → Hard → Boss 1 / 2 / 3\nAfter each fight: Open packs → Auto Team')
hintText.Position=UDim2.fromOffset(12,29);hintText.Size=UDim2.new(1,-24,0,40);hintText.TextWrapped=true
local function numberInput(label,key,low,high)
    local r=row('Settings',label,69)
    local box=make('TextBox',r,{Position=UDim2.fromOffset(12,31),Size=UDim2.new(1,-24,0,29),
        Text=tostring(app.config[key]),ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0})
    corner(box);skin(box,'BackgroundColor3','row');skin(box,'TextColor3','text')
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
local logRow=row('Logs','Session log',300)
local logText=text(logRow,'No actions yet')
logText.Position=UDim2.fromOffset(12,32);logText.Size=UDim2.new(1,-24,1,-40)
logText.TextWrapped=true;logText.TextYAlignment=Enum.TextYAlignment.Top
logText.TextTruncate=Enum.TextTruncate.None;logText.TextSize=11
local copyRow=row('Logs','Copy session log',69)
local copy=button(copyRow,'COPY',UDim2.new(1,-24,0,29));copy.Position=UDim2.fromOffset(12,31)
track(copy.Activated,function()
    if type(setclipboard)=='function' then
        local ok=pcall(setclipboard,table.concat(app.logs,'\n'))
        if ok then log('Log copied') else log('Clipboard unavailable') end
    else log('Clipboard unavailable; read [AnimeDuel] in console') end
end)
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
    start.Text=app.worker and (app.enabled and 'RUNNING' or 'STOPPING') or 'START'
    start.Active=not app.worker
    for name,b in pairs(navButtons) do b.BackgroundColor3=color(name==selected and 'accent' or 'row');b.TextColor3=color(name==selected and 'bg' or 'text') end
    main.BackgroundTransparency=app.config.transparency/100
    local lines={}
    for i=math.max(1,#app.logs-13),#app.logs do table.insert(lines,app.logs[i]) end
    logText.Text=table.concat(lines,'\n')
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
    for i,name in ipairs({'Draft','Settings','Logs'}) do
        local b=navButtons[name]
        b.Position=compact and UDim2.new((i-1)/3,5,0,4) or UDim2.fromOffset(8,12+(i-1)*46)
        b.Size=compact and UDim2.new(1/3,-10,0,36) or UDim2.new(1,-16,0,38)
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
log('Ready — press START. Right Shift / AD hides or shows UI.')
