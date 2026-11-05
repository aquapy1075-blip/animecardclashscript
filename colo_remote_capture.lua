-- Observe the game's real Colosseum protocol. Does not invoke any remotes.
-- Run once before manually opening Colo and exercising the desired actions.
-- Stop with getgenv().ColoRemoteCapture.stop(); output: colo_remote_capture.json
local env=(getgenv and getgenv()) or _G
local previous=env.ColoRemoteCapture
if previous and previous.active then
    warn('Colo capture already running; use ColoRemoteCapture.stop() first')
    return
end
assert(type(hookmetamethod)=='function' and type(getnamecallmethod)=='function',
    'Capture requires hookmetamethod and getnamecallmethod')
local rs=game:GetService('ReplicatedStorage')
local http=game:GetService('HttpService')
local remote=rs:FindFirstChild('ColosseumRemote',true)
assert(remote and remote:IsA('RemoteFunction'),'ColosseumRemote not found')
local capture={active=true,records={},limit=200,path='colo_remote_capture.json'}
env.ColoRemoteCapture=capture
local function snapshot(value,depth,seen)
    local kind=typeof(value)
    if kind=='nil' then return {type='nil'} end
    if kind=='string' or kind=='boolean' then return value end
    if kind=='number' then
        if value~=value or math.abs(value)==math.huge then return tostring(value) end
        return value
    end
    if kind~='table' then return {type=kind,value=tostring(value)} end
    if seen[value] then return {type='cycle'} end
    if depth>=12 then return {type='depth-limit'} end
    seen[value]=true
    local entries={}
    local count=0
    for key,item in pairs(value) do
        count=count+1
        if count>1000 then
            entries[#entries+1]={truncated=true}
            break
        end
        entries[#entries+1]={key=snapshot(key,depth+1,seen),value=snapshot(item,depth+1,seen)}
    end
    seen[value]=nil
    return {type='table',entries=entries}
end
function capture.save()
    local ok,result=pcall(function() return http:JSONEncode(capture.records) end)
    if not ok then warn('Colo capture encoding failed: '..tostring(result));return false end
    if type(writefile)=='function' then
        local saved,err=pcall(writefile,capture.path,result)
        if saved then print('Colo capture saved: '..capture.path);return true end
        warn('Colo capture write failed: '..tostring(err))
    end
    -- Records also remain available in getgenv().ColoRemoteCapture.records.
    print(result)
    return false
end
function capture.stop()
    capture.active=false
    return capture.save()
end
local old
local function observe(self,...)
    if self~=remote or getnamecallmethod()~='InvokeServer' or not capture.active then
        return old(self,...)
    end
    -- Snapshot before yielding: the UI can mutate argument tables afterwards.
    local record={id=#capture.records+1,time=os.clock(),status='pending'}
    local okArgs,args=pcall(snapshot,table.pack(...),0,{})
    record.arguments=okArgs and args or {captureError=tostring(args)}
    capture.records[#capture.records+1]=record
    if #capture.records>=capture.limit then capture.active=false end
    local result=table.pack(pcall(old,self,...))
    record.status=result[1] and 'returned' or 'error'
    local returns={n=result.n-1}
    for index=2,result.n do returns[index-1]=result[index] end
    local okResult,data=pcall(snapshot,returns,0,{})
    record.result=okResult and data or {captureError=tostring(data)}
    print('Colo capture #'..record.id..': '..record.status)
    if not capture.active then capture.save() end
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
end
old=hookmetamethod(game,'__namecall',type(newcclosure)=='function' and newcclosure(observe) or observe)
print('Colo capture ON. Play Colo manually, then run getgenv().ColoRemoteCapture.stop()')
