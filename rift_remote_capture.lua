-- Lightweight recorder using the same approach as colo_remote_capture.lua.
-- Only named Rift remotes are watched. No incoming-event listeners, scans in
-- the hook, autosave, UI changes, or extra remote requests.
-- Stop/save: getgenv().AnimeOriginRiftCapture.stop()
local env=(getgenv and getgenv()) or _G
local previous=env.AnimeOriginRiftCapture
if type(previous)=='table' and previous.Version==2 and type(previous.start)=='function' then
    if previous.active then warn('Rift capture already running') else previous.start() end
    return
end
-- Deactivate listeners from the older broad recorder without exporting its log.
if type(previous)=='table' then
    previous.active=false
    for _,connection in ipairs(previous.connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
end
assert(type(hookmetamethod)=='function' and type(getnamecallmethod)=='function',
    'Capture requires hookmetamethod and getnamecallmethod')
local rs=game:GetService('ReplicatedStorage')
local http=game:GetService('HttpService')
local watched={}
local found={}
for _,name in ipairs({
    'RiftGateEnterRequest','RiftGateStartFight','BuildRiftGateBattle',
    'ReportRiftGateVictory','RiftGateLeave','WorldsTeleportRequest',
    'RiftEnterRequest','RiftStartBattle','RiftReportResult','RiftClaimRequest',
    'RiftPurchaseRequest',
}) do
    local remote=rs:FindFirstChild(name,true)
    if remote and (remote:IsA('RemoteFunction') or remote:IsA('RemoteEvent')) then
        watched[remote]={name=name,path=remote:GetFullName()}
        found[#found+1]=name
    end
end
assert(#found>0,'No Rift remotes found')
local capture={Version=2,active=true,records={},pending=0,limit=300,path='rift_remote_capture.json'}
env.AnimeOriginRiftCapture=capture
local function snapshot(value,depth,seen)
    seen.count=(seen.count or 0)+1
    if seen.count>6000 then return {truncated=true,reason='value limit'} end
    local kind=typeof(value)
    if kind=='nil' then return {type='nil'} end
    if kind=='boolean' then return value end
    if kind=='string' then
        if #value>16000 then return {type='string',value=value:sub(1,16000),truncated=true} end
        return value
    end
    if kind=='number' then
        if value~=value or math.abs(value)==math.huge then return tostring(value) end
        return value
    end
    if kind~='table' then return {type=kind,value=tostring(value)} end
    if seen[value] then return {type='cycle'} end
    if depth>=12 then return {type='depth-limit'} end
    seen[value]=true
    local entries={}
    for key,item in pairs(value) do
        if #entries>=500 then entries[#entries+1]={truncated=true};break end
        entries[#entries+1]={key=snapshot(key,depth+1,seen),value=snapshot(item,depth+1,seen)}
    end
    seen[value]=nil
    return {type='table',entries=entries}
end
function capture.export()
    return http:JSONEncode(capture.records)
end
function capture.save()
    local ok,data=pcall(capture.export)
    if not ok then warn('Rift capture encoding failed: '..tostring(data));return false end
    if type(writefile)=='function' then
        local saved,err=pcall(writefile,capture.path,data)
        if saved then print('Rift log saved: '..capture.path);return true end
        warn('Rift log write failed: '..tostring(err))
    end
    warn('No file saved. Copy getgenv().AnimeOriginRiftCapture.export() from the console')
    return false
end
function capture.stop()
    capture.active=false
    if capture.pending>0 then
        warn('Rift request still pending. Wait for it to finish, then call stop() again to save its reply.')
    end
    return capture.save()
end
function capture.start()
    assert(capture.pending==0,'Wait for the pending Rift request before restarting capture')
    capture.records={};capture.active=true
    print('Rift capture ON ('..#found..' remotes). Stop/save: getgenv().AnimeOriginRiftCapture.stop()')
end
local old
local function observe(self,...)
    -- Most game calls exit immediately, exactly like the Colo recorder.
    local target=watched[self]
    if not target or not capture.active then return old(self,...) end
    local method=getnamecallmethod()
    if method~='InvokeServer' and method~='FireServer' then return old(self,...) end
    local record={id=#capture.records+1,time=os.clock(),remote=target.name,
        path=target.path,method=method,status='pending'}
    local okArgs,args=pcall(snapshot,table.pack(...),0,{})
    record.arguments=okArgs and args or {captureError=tostring(args)}
    capture.records[#capture.records+1]=record
    if #capture.records>=capture.limit then
        capture.active=false
        warn('Rift log limit reached. Call getgenv().AnimeOriginRiftCapture.stop() to save.')
    end
    capture.pending=capture.pending+1
    local result=table.pack(pcall(old,self,...))
    capture.pending=capture.pending-1
    record.status=result[1] and (method=='InvokeServer' and 'returned' or 'sent') or 'error'
    local returns={n=result.n-1}
    for index=2,result.n do returns[index-1]=result[index] end
    local okResult,data=pcall(snapshot,returns,0,{})
    record.result=okResult and data or {captureError=tostring(data)}
    print('Rift capture #'..record.id..': '..target.name..' / '..record.status)
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
end
old=hookmetamethod(game,'__namecall',type(newcclosure)=='function' and newcclosure(observe) or observe)
print('Rift capture ON ('..#found..' remotes). Stop/save: getgenv().AnimeOriginRiftCapture.stop()')
