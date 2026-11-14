-- Skeleton Raid capture v3: incoming only, no UI, no remote hooks.
local env=(getgenv and getgenv()) or _G
local previous=env.OriginSkeletonCapture
local retained=type(previous)=='table' and previous.records or nil
local retainedTotal=type(previous)=='table' and previous.total or 0
local retainedDropped=type(previous)=='table' and previous.dropped or 0
if type(previous)=='table' and type(previous.stop)=='function' then pcall(previous.stop) end
if type(env.OriginRaidWireTap)=='table' then env.OriginRaidWireTap.sink=nil end
local Http=game:GetService('HttpService')
local state={alive=true,records=retained or {},connections={},total=retainedTotal or 0,dropped=retainedDropped or 0,errors=0,connected=false}
env.OriginSkeletonCapture=state
local function encode(value,depth,seen,budget)
    budget.n=budget.n+1
    if budget.n>1000 then return '<capture node limit>' end
    local kind=typeof(value)
    if kind=='nil' then return '<nil>' end
    if kind=='boolean' then return value end
    if kind=='number' then return value==value and math.abs(value)~=math.huge and value or tostring(value) end
    if kind=='string' then return value:sub(1,1400) end
    if kind=='Instance' then local ok,path=pcall(function() return value:GetFullName() end);return {class=value.ClassName,path=ok and path or value.Name} end
    if kind~='table' then return tostring(value) end
    if seen[value] then return '<cycle>' end
    if depth>=10 then return '<capture depth limit>' end
    seen[value]=true
    local result={};local count=0
    for key,child in pairs(value) do
        count=count+1
        if count>220 or budget.n>1000 then result.__capture_truncated=true;break end
        result[tostring(key)]=encode(child,depth+1,seen,budget)
    end
    seen[value]=nil;return result
end
local function record(direction,remote,args)
    if not state.alive then return end
    state.total=state.total+1
    state.records[#state.records+1]={sequence=state.total,time=os.clock(),direction=direction,remote=remote,args=encode(args,0,{},{n=0})}
    if #state.records>1000 then table.remove(state.records,21);state.dropped=state.dropped+1 end
end
state.stop=function()
    state.alive=false;state.connected=false
    for _,connection in ipairs(state.connections) do connection:Disconnect() end
    state.connections={}
    -- Keep this object and records available for export after stopping.
    return #state.records
end
local function exportText()
    return Http:JSONEncode({version=3,outgoingCaptured=false,recording=state.alive,connected=state.connected,total=state.total,droppedRecords=state.dropped,captureErrors=state.errors,records=state.records})
end
state.save=function()
    if type(writefile)~='function' then return false,'Executor has no writefile API' end
    local ok,err=pcall(function() writefile('SkeletonRaidCapture.json',exportText()) end)
    return ok,ok and 'Saved SkeletonRaidCapture.json in executor workspace' or tostring(err)
end
state.copy=function()
    local ok,text=pcall(exportText)
    if not ok then return false,'JSON export failed: '..tostring(text) end
    if type(setclipboard)=='function' then
        local copied=pcall(setclipboard,text)
        if copied then return true,'Copied '..#state.records..' records' end
    end
    local saved,reason=state.save()
    if saved then return true,reason end
    print(text)
    return true,'Printed to executor console; clipboard/file APIs unavailable'
end
state.clear=function()
    state.records={};state.total=0;state.dropped=0;state.errors=0
end
state.status=function()
    return {recording=state.alive,connected=state.connected,records=#state.records,total=state.total,dropped=state.dropped,errors=state.errors}
end
-- Await remotes in a worker; stop/copy commands exist even if game loading stalls.
task.spawn(function()
    local storage=game:GetService('ReplicatedStorage')
    local shared=storage:WaitForChild('Shared',15)
    local net=shared and shared:WaitForChild('Net',15)
    local folder=net and net:WaitForChild('RemoteObjects',15)
    local remote=folder and folder:WaitForChild('SkeletonRaid',15)
    if not state.alive then return end
    if not remote or not remote:IsA('RemoteEvent') then
        state.alive=false;warn('Skeleton capture: SkeletonRaid RemoteEvent missing')
        return
    end
    state.connections[#state.connections+1]=remote.OnClientEvent:Connect(function(...)
        local args=table.pack(...)
        task.defer(function()
            if state.alive then
                local ok=pcall(record,'IN','SkeletonRaid',args)
                if not ok then state.errors=state.errors+1 end
            end
        end)
    end)
    state.connected=true
    record('MARK','Recorder',{event='started',outgoingCaptured=false,ui=false})
    print('Skeleton capture connected. Stop: getgenv().OriginSkeletonCapture.stop(); copy: getgenv().OriginSkeletonCapture.copy()')
end)
