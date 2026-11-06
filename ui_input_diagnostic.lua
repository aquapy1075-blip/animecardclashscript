-- Read-only UI/input diagnostics. No hooks, remotes, focus changes or UI writes.
-- Run BEFORE the main script in a fresh game session. Save after reproducing:
-- getgenv().AnimeOriginUIDiagnostic.stop()
local env=(getgenv and getgenv()) or _G
local old=env.AnimeOriginUIDiagnostic
if type(old)=='table' and type(old.stop)=='function' then pcall(old.stop) end
local players=game:GetService('Players')
local pg=players.LocalPlayer:WaitForChild('PlayerGui')
local http=game:GetService('HttpService')
local input=game:GetService('UserInputService')
local guiService=game:GetService('GuiService')
local diagnostic={active=true,records={},connections={},path='anime_origin_ui_diagnostic.json',limit=250}
env.AnimeOriginUIDiagnostic=diagnostic
local function property(object,key)
    local ok,value=pcall(function() return object[key] end)
    if ok and (type(value)=='boolean' or type(value)=='number' or type(value)=='string') then return value end
end
local function path(object)
    local ok,value=pcall(function() return object and object:GetFullName() end)
    return ok and value or nil
end
local function record(kind,data)
    if not diagnostic.active or #diagnostic.records>=diagnostic.limit then return end
    diagnostic.records[#diagnostic.records+1]={time=os.clock(),kind=kind,data=data}
end
local function attach(signal,callback)
    if #diagnostic.connections>=180 then return end
    diagnostic.connections[#diagnostic.connections+1]=signal:Connect(function(...)
        if diagnostic.active then pcall(callback,...) end
    end)
end
local function info(object)
    local data={path=path(object),class=object.ClassName}
    for _,key in ipairs({'Enabled','Visible','Active','Modal','DisplayOrder','ZIndex'}) do data[key]=property(object,key) end
    return data
end
local tracked=setmetatable({}, {__mode='k'})
local function watch(object,key)
    attach(object:GetPropertyChangedSignal(key),function() record('property',info(object)) end)
end
local function watchGui(gui)
    if tracked[gui] or not gui:IsA('ScreenGui') then return end
    tracked[gui]=true
    record('screen',info(gui));watch(gui,'Enabled')
    for _,child in ipairs(gui:GetChildren()) do
        if child:IsA('GuiObject') then watch(child,'Visible') end
    end
end
function diagnostic.mark(label)
    local screens={}
    for _,gui in ipairs(pg:GetChildren()) do
        if gui:IsA('ScreenGui') then
            local data=info(gui);data.children={}
            for _,child in ipairs(gui:GetChildren()) do
                if child:IsA('GuiObject') and #data.children<30 then data.children[#data.children+1]=info(child) end
            end
            screens[#screens+1]=data
        end
    end
    local focused=nil
    pcall(function() focused=input:GetFocusedTextBox() end)
    record('snapshot',{label=tostring(label or 'manual'):sub(1,100),screens=screens,
        selected=path(guiService.SelectedObject),focused=path(focused),
        touch=property(input,'TouchEnabled'),modal=property(input,'ModalEnabled'),
        navigation=property(guiService,'GuiNavigationEnabled'),autoSelect=property(guiService,'AutoSelectGuiEnabled')})
end
function diagnostic.save()
    local ok,data=pcall(function() return http:JSONEncode(diagnostic.records) end)
    if not ok then warn('UI diagnostic encoding failed');return false end
    if type(writefile)=='function' then
        local saved=pcall(writefile,diagnostic.path,data)
        if saved then print('Saved '..diagnostic.path);return true end
    end
    warn('File API unavailable. Records remain in getgenv().AnimeOriginUIDiagnostic.records')
    return false
end
function diagnostic.stop()
    if diagnostic.active then diagnostic.mark('stop') end
    diagnostic.active=false
    for _,connection in ipairs(diagnostic.connections) do pcall(function() connection:Disconnect() end) end
    diagnostic.connections={}
    return diagnostic.save()
end
for _,gui in ipairs(pg:GetChildren()) do watchGui(gui) end
attach(pg.ChildAdded,function(gui) watchGui(gui);record('added',info(gui)) end)
attach(pg.ChildRemoved,function(gui) record('removed',info(gui)) end)
attach(input:GetPropertyChangedSignal('ModalEnabled'),function() record('input-modal',{value=property(input,'ModalEnabled')}) end)
attach(guiService:GetPropertyChangedSignal('SelectedObject'),function() record('selection',{path=path(guiService.SelectedObject)}) end)
local lastTouch=-math.huge
attach(input.InputBegan,function(event,processed)
    if event.UserInputType==Enum.UserInputType.Touch and os.clock()-lastTouch>1 then
        lastTouch=os.clock();record('touch',{processed=processed})
    end
end)
diagnostic.mark('before main script')
print('UI diagnostic ON. Run main script, reproduce the issue, then getgenv().AnimeOriginUIDiagnostic.stop()')
