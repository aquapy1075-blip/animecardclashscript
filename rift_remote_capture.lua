-- Manual Rift protocol recorder. Observes reliable remotes; sends no requests.
-- Stop/save: getgenv().AnimeOriginRiftCapture.stop()
-- File: rift_remote_capture.json, inside the executor workspace.
local env=(getgenv and getgenv()) or _G
local previous=env.AnimeOriginRiftCapture
if type(previous)=='table' and previous.Version==1 and type(previous.start)=='function' then
    if previous.active then warn('Rift capture is already running') else previous.start() end
    return
end
assert(type(hookmetamethod)=='function' and type(getnamecallmethod)=='function',
    'Rift capture requires hookmetamethod and getnamecallmethod')
local rs=game:GetService('ReplicatedStorage')
local workspace=game:GetService('Workspace')
local http=game:GetService('HttpService')
local capture={Version=1,active=false,path='rift_remote_capture.json',records={},
    connections={},maxRecords=1500,maxBytes=6*1024*1024,bytes=0,pending=0}
env.AnimeOriginRiftCapture=capture
local seen=setmetatable({}, {__mode='k'})
local function pathOf(obj)
    local ok,path=pcall(obj.GetFullName,obj)
    return ok and path or tostring(obj)
end
local function excluded(path)
    return path:find('DefaultChatSystemChatEvents',1,true)~=nil
        or path:find('TextChatService.',1,true)~=nil
end
local function snapshot(value,depth,visited)
    visited.__values=(visited.__values or 0)+1
    if visited.__values>12000 then return {truncated=true,reason='value limit'} end
    local kind=typeof(value)
    if kind=='nil' then return {type='nil'} end
    if kind=='boolean' then return value end
    if kind=='number' then
        return value==value and math.abs(value)<math.huge and value or tostring(value)
    end
    if kind=='string' then
        if #value>16000 then return {type='string',value=value:sub(1,16000),truncated=true,length=#value} end
        return value
    end
    if kind=='Instance' then return {type=kind,class=value.ClassName,path=pathOf(value)} end
    if kind~='table' then return {type=kind,value=tostring(value)} end
    if visited[value] then return {type='cycle'} end
    if depth>=12 then return {type='table',truncated=true,reason='depth limit'} end
    visited[value]=true
    local entries={}
    for key,item in pairs(value) do
        if #entries>=500 then
            entries[#entries+1]={truncated=true,reason='entry limit'}
            break
        end
        entries[#entries+1]={key=snapshot(key,depth+1,visited),value=snapshot(item,depth+1,visited)}
    end
    visited[value]=nil
    return {type='table',entries=entries}
end
local function packSnapshot(...)
    local ok,value=pcall(snapshot,table.pack(...),0,{})
    return ok and value or {captureError=tostring(value)}
end
function capture.export()
    return http:JSONEncode({version=1,kind='rift_remote_capture',startedAt=capture.startedAt,
        records=capture.records,pending=capture.pending,limitReason=capture.limitReason,
        scope='All outgoing reliable remotes; incoming RemoteEvents in ReplicatedStorage/Workspace; chat omitted'})
end
function capture.save()
    local ok,data=pcall(capture.export)
    if not ok then warn('Rift capture export failed: '..tostring(data));return false end
    if type(writefile)=='function' then
        local saved,err=pcall(writefile,capture.path,data)
        if saved then return true end
        warn('Rift capture file write failed: '..tostring(err))
    end
    return false
end
local function disconnect()
    for _,connection in ipairs(capture.connections) do pcall(function() connection:Disconnect() end) end
    capture.connections={}
    seen=setmetatable({}, {__mode='k'})
end
function capture.stop(reason)
    capture.active=false
    if reason then capture.limitReason=reason end
    disconnect()
    if capture.save() then
        print('Rift log saved: '..capture.path..' ('..#capture.records..' records)')
    else
        warn('No log file saved. Copy getgenv().AnimeOriginRiftCapture.export() from the console')
    end
    if capture.pending>0 then warn('Rift capture has pending requests; their replies will be saved when they return') end
end
local saving=false
local function autosave()
    if saving then return end
    saving=true
    task.defer(function() saving=false;capture.save() end)
end
local function add(record)
    if not capture.active then return false end
    local ok,encoded=pcall(function() return http:JSONEncode(record) end)
    local size=ok and #encoded or 0
    if #capture.records>=capture.maxRecords or capture.bytes+size>capture.maxBytes then
        capture.stop('Capture limit reached; finish this recording and start a new one if needed')
        return false
    end
    record.id=#capture.records+1
    capture.records[#capture.records+1]=record
    capture.bytes=capture.bytes+size
    if #capture.records%25==0 then autosave() end
    return true
end
local function attach(obj)
    if not capture.active or seen[obj] or not obj:IsA('RemoteEvent') then return end
    local path=pathOf(obj)
    if excluded(path) then return end
    seen[obj]=true
    capture.connections[#capture.connections+1]=obj.OnClientEvent:Connect(function(...)
        add({direction='server_to_client',remote=pathOf(obj),method='OnClientEvent',
            time=os.clock()-capture.startedClock,arguments=packSnapshot(...)})
    end)
end
function capture.start()
    assert(capture.pending==0,'Wait for pending requests to finish before starting another recording')
    disconnect()
    capture.records={};capture.bytes=0;capture.limitReason=nil
    capture.startedAt=os.time();capture.startedClock=os.clock();capture.active=true
    for _,root in ipairs({rs,workspace}) do
        capture.connections[#capture.connections+1]=root.DescendantAdded:Connect(attach)
        for _,obj in ipairs(root:GetDescendants()) do attach(obj) end
    end
    print('Rift capture ON. Play one Rift manually; then run getgenv().AnimeOriginRiftCapture.stop()')
end
local old
local function observe(self,...)
    local method=getnamecallmethod()
    if not capture.active or (method~='InvokeServer' and method~='FireServer')
        or typeof(self)~='Instance' then return old(self,...) end
    local isRemote=self.IsA(self,'RemoteFunction') or self.IsA(self,'RemoteEvent')
    local path=isRemote and pathOf(self)
    if not path or excluded(path) then return old(self,...) end
    local record={direction='client_to_server',remote=path,method=method,
        time=os.clock()-capture.startedClock,status='pending',arguments=packSnapshot(...)}
    if not add(record) then return old(self,...) end
    capture.pending=capture.pending+1
    local result=table.pack(pcall(old,self,...))
    capture.pending=capture.pending-1
    record.status=result[1] and (method=='InvokeServer' and 'returned' or 'sent') or 'error'
    record.duration=os.clock()-capture.startedClock-record.time
    local returns={n=result.n-1}
    for index=2,result.n do returns[index-1]=result[index] end
    local ok,data=pcall(snapshot,returns,0,{})
    record.result=ok and data or {captureError=tostring(data)}
    -- Include returned data in the size bound; replies may be much larger than requests.
    local encodedOK,encoded=pcall(function() return http:JSONEncode(record.result) end)
    if encodedOK then capture.bytes=capture.bytes+#encoded end
    if capture.active and capture.bytes>capture.maxBytes then capture.stop('Reply exceeded capture size limit') end
    if not capture.active then autosave() end
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
end
old=hookmetamethod(game,'__namecall',type(newcclosure)=='function' and newcclosure(observe) or observe)
capture.start()
