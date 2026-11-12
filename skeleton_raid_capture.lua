-- Passive Skeleton Raid protocol recorder. Does not send gameplay requests.
local env=(getgenv and getgenv()) or _G
if env.OriginSkeletonCapture then env.OriginSkeletonCapture.stop() end
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local player=Players.LocalPlayer
local shared=game:GetService('ReplicatedStorage'):WaitForChild('Shared')
local remotes=shared:WaitForChild('Net'):WaitForChild('RemoteObjects')
local state={alive=true,records={},connections={},dropped=0,total=0}
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
local gui=Instance.new('ScreenGui');gui.Name='SkeletonRaidCapture';gui.ResetOnSpawn=false;gui.DisplayOrder=10000;gui.Parent=player:WaitForChild('PlayerGui')
local panel=Instance.new('Frame');panel.Size=UDim2.fromOffset(300,225);panel.Position=UDim2.fromOffset(12,70);panel.BackgroundColor3=Color3.fromRGB(19,23,36);panel.BorderSizePixel=0;panel.Parent=gui
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=panel
local function label(text,y,height)
    local l=Instance.new('TextLabel');l.Size=UDim2.new(1,-24,0,height or 24);l.Position=UDim2.fromOffset(12,y);l.BackgroundTransparency=1;l.Text=text;l.TextColor3=Color3.fromRGB(189,230,255);l.Font=Enum.Font.GothamBold;l.TextSize=12;l.TextWrapped=true;l.Parent=panel;return l
end
label('SKELETON RAID · CAPTURE',10)
local status=label('Starting recorder…',38,36)
local notice=label('Play one raid manually, then COPY LOG.',78,30)
local function record(direction,remote,args)
    if not state.alive then return end
    state.total=state.total+1
    state.records[#state.records+1]={sequence=state.total,time=os.clock(),direction=direction,remote=remote,args=encode(args,0,{},{n=0})}
    if #state.records>1000 then table.remove(state.records,21);state.dropped=state.dropped+1 end
    status.Text=state.total..' records · '..direction..' '..remote
end
local wire=env.OriginRaidWireTap
local function sink(direction,remote,args)
    if remote:IsDescendantOf(remotes) then record(direction,remote.Name,args) end
end
local hookAvailable=type(hookmetamethod)=='function' and type(getnamecallmethod)=='function'
if not wire and hookAvailable then
    wire={sink=nil};local original
    local closure=newcclosure or function(fn) return fn end
    local ok,err=pcall(function()
        original=hookmetamethod(game,'__namecall',closure(function(self,...)
            local method=getnamecallmethod()
            local listener=wire.sink
            if not listener or typeof(self)~='Instance' or (method~='FireServer' and method~='InvokeServer') then return original(self,...) end
            pcall(listener,'OUT:'..method,self,table.pack(...))
            if method=='InvokeServer' then
                local returns=table.pack(original(self,...))
                if wire.sink==listener then pcall(listener,'RETURN',self,returns) end
                return table.unpack(returns,1,returns.n)
            end
            return original(self,...)
        end))
    end)
    if ok then env.OriginRaidWireTap=wire else wire=nil end
end
if wire then wire.sink=sink else notice.Text='Outgoing capture unavailable on this executor; incoming only.' end
local watched={}
local function watch(remote)
    if watched[remote] or not remote:IsA('RemoteEvent') then return end
    if remote.Name~='SkeletonRaid' and remote.Name~='Raid' and remote.Name~='CreateOrJoinParty' then return end
    watched[remote]=true
    state.connections[#state.connections+1]=remote.OnClientEvent:Connect(function(...) record('IN',remote.Name,table.pack(...)) end)
end
for _,remote in ipairs(remotes:GetChildren()) do watch(remote) end
state.connections[#state.connections+1]=remotes.ChildAdded:Connect(watch)
state.stop=function()
    if not state.alive then return end
    state.alive=false
    if wire and wire.sink==sink then wire.sink=nil end
    for _,connection in ipairs(state.connections) do connection:Disconnect() end
    gui:Destroy()
    if env.OriginSkeletonCapture==state then env.OriginSkeletonCapture=nil end
end
local function button(text,x,y,callback)
    local b=Instance.new('TextButton');b.Size=UDim2.fromOffset(132,36);b.Position=UDim2.fromOffset(x,y);b.BackgroundColor3=Color3.fromRGB(60,78,128);b.TextColor3=Color3.fromRGB(240,248,255);b.Font=Enum.Font.GothamBold;b.TextSize=12;b.Text=text;b.BorderSizePixel=0;b.Parent=panel
    local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=b;b.Activated:Connect(callback)
end
button('COPY LOG',12,116,function()
    local ok,text=pcall(function() return Http:JSONEncode({version=1,outgoingCaptured=wire~=nil,droppedRecords=state.dropped,total=state.total,records=state.records}) end)
    if not ok then status.Text='JSON export failed';return end
    if type(setclipboard)=='function' and pcall(setclipboard,text) then status.Text='Copied! Paste log into chat.'
    elseif type(writefile)=='function' and pcall(writefile,'SkeletonRaidCapture.json',text) then status.Text='Saved SkeletonRaidCapture.json'
    else print(text);status.Text='Log printed in console.' end
end)
button('CLEAR LOG',156,116,function() state.records={};state.total=0;state.dropped=0;record('MARK','Recorder',{event='cleared'}) end)
button('MARK WIN',12,164,function() record('MARK','Manual',{result='WIN'}) end)
button('STOP',156,164,state.stop)
record('MARK','Recorder',{event='started',outgoingCaptured=wire~=nil})
