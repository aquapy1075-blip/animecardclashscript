from pathlib import Path
import os
import shutil
import subprocess
import tempfile
src=(Path(__file__).resolve().parents[1]/'anime_origin_ui.lua').read_text()
mock=r'''
local now=10
local os={clock=function() return now end}
local objects={}
local writes=0
local function signal()
 local callbacks={}
 return {Connect=function(_,fn)
  local connection={Connected=true}
  function connection:Disconnect() self.Connected=false end
  callbacks[#callbacks+1]={fn=fn,connection=connection}
  return connection
 end,Fire=function(_,...) for _,c in ipairs(callbacks) do if c.connection.Connected then c.fn(...) end end end}
end
local Enum=setmetatable({}, {__index=function(self,key)
 local kind=setmetatable({}, {__index=function(_,name) return key..'.'..name end})
 rawset(self,key,kind);return kind
end})
local function dim(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end
local UDim2={new=dim,fromOffset=function(x,y) return dim(0,x,0,y) end,fromScale=function(x,y) return dim(x,0,y,0) end}
local UDim={new=function(s,o) return {Scale=s,Offset=o} end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Color3={fromRGB=function(r,g,b) return string.format('%d,%d,%d',r,g,b) end}
local NumberSequence={new=function(a,b) return {a,b} end}
local events={InputBegan=true,InputChanged=true,InputEnded=true,MouseButton1Click=true,MouseEnter=true,MouseLeave=true,MouseButton1Down=true,MouseButton1Up=true,FocusLost=true,Destroying=true}
local pending={}
local function delay(seconds,fn) pending[#pending+1]={at=now+seconds,fn=fn} end
local function advance(seconds)
 now+=seconds
 local ready={}
 for index=#pending,1,-1 do
  if pending[index].at<=now then ready[#ready+1]=table.remove(pending,index).fn end
 end
 for index=#ready,1,-1 do ready[index]() end
end
local task={delay=delay}
local TweenInfo={new=function(duration) return {duration=duration} end}
local tweenCount=0
local TweenService={Create=function(_,obj,info,properties)
 tweenCount+=1
 local complete=signal();local finished=false
 return {Completed=complete,Play=function()
  for key,value in pairs(properties) do obj[key]=value end
  delay(info.duration,function() if not finished then finished=true;complete:Fire('Completed') end end)
 end,Cancel=function() if not finished then finished=true;complete:Fire('Cancelled') end end}
end}
local focused=nil
local Instance={}
function Instance.new(class)
 local props={BackgroundTransparency=0,Text='',Enabled=true,Visible=true,Name=class,
 AbsolutePosition={X=0,Y=0},AbsoluteSize={X=170,Y=32},Position=dim(0,0,0,0),Size=dim(0,0,0,0),GroupTransparency=0}
 local children={};local signals={};local obj
 local methods={}
 function methods:IsA(kind) return kind==class or kind=='GuiObject' and (class=='Frame' or class=='CanvasGroup' or class=='TextLabel' or class=='TextButton' or class=='TextBox' or class=='ScrollingFrame') or kind=='GuiButton' and class=='TextButton' end
 function methods:GetChildren() local list={} for _,v in ipairs(children) do if v.Parent==obj then list[#list+1]=v end end return list end
 function methods:FindFirstChildWhichIsA(kind) for _,child in ipairs(children) do if child:IsA(kind) then return child end end end
 function methods:IsFocused() return focused==obj end
 function methods:ReleaseFocus() if focused==obj then focused=nil end end
 function methods:IsDescendantOf(parent) local node=props.Parent while type(node)=='table' do if node==parent then return true end node=node.Parent end return false end
 function methods:Destroy()
  if props.destroyed then return end
  props.destroyed=true
  if signals.Destroying then signals.Destroying:Fire() end
  for _,child in ipairs(methods.GetChildren()) do child:Destroy() end
  props.Parent=nil
 end
 function methods:GetPropertyChangedSignal(key) signals[key]=signals[key] or signal();return signals[key] end
 obj=setmetatable({}, {__index=function(_,key)
  if methods[key] then return methods[key] end
  if key=='_children' then return children end
  if events[key] then signals[key]=signals[key] or signal();return signals[key] end
  return props[key]
 end,__newindex=function(_,key,value)
  writes+=1;local old=props[key];props[key]=value
  if old~=value and signals[key] then signals[key]:Fire() end
  if key=='Parent' and type(value)=='table' and value._children then table.insert(value._children,obj) end
 end})
 objects[#objects+1]=obj
 return obj
end
local noop=function() end
local UIS={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),GetFocusedTextBox=function() return focused end}
local GuiService={SelectedObject='old selection',GuiNavigationEnabled=true,AutoSelectGuiEnabled=true}
local state={alive=true,enabled=true,phase='DRAFT',lastSeenWave=0,supportCount=0,curseCount=0,
 connections={},stop=function() stateStopped=true end}
local flags={AO_UI_Theme='Midnight',AO_UI_Transparency=15,AO_AutoColosseum=true}
local profile={currentProfile='Default',autoProfile='Default',storedNames={'Default'},configStatus='Ready',revision=0}
local calls={boss=0,raid=0,siege=0}
local function mode(key)
 return {bosses={},stages={},state={on=true,running=true,wins=0,losses=0,clears=0,status='Ready'},
 cooldownText=function() calls[key]=(calls[key] or 0)+1;return 'READY' end}
end
local boss,raid,siege,rift=mode('boss'),mode('raid'),mode('siege'),mode('rift')
-- Representative rows exercise dropdowns, stage switches and cooldown text.
boss.bosses={{id='test',name='Test Boss'}};boss.borders={'Normal','Gold','Rainbow','Uni','Astral','Origin'}
raid.stages={{index=1,name='Test Raid'}};siege.stages={{index=1,name='Test Siege'}}
flags.AO_Border_test=1
local parent=Instance.new('Folder');parent.Parent=true
local camera={ViewportSize={X=1280,Y=800},GetPropertyChangedSignal=function() return signal() end}
local cameraSignals={}
local workspaceSignals={}
local workspace={CurrentCamera=camera,GetPropertyChangedSignal=function(_,key) workspaceSignals[key]=workspaceSignals[key] or signal();return workspaceSignals[key] end}
camera.GetPropertyChangedSignal=function(_,key) cameraSignals[key]=cameraSignals[key] or signal();return cameraSignals[key] end
local ctx={TweenService=TweenService,Delay=delay,saveAppearance=function() profile.geometrySaved=true end,state=state,flags=flags,cfg={stopSpec='30-40'},profile=profile,playerGui=parent,
 Workspace=workspace,UIS=UIS,GuiService=GuiService,env={},boss=boss,raid=raid,siege=siege,rift=rift,
 reconnect={status='Ready'},handoff={},applyFlags=noop,requestReconnect=noop,loadIndex=noop,
 saveProfile=function(name) profile.currentProfile=name;return true end,
 loadProfile=function() profile.currentProfile='Loaded';flags.AO_UI_Theme='Ocean';flags.AO_UI_Transparency=35;return true end,
 deleteProfile=noop,setAutoProfile=noop,markCurrentForNextExecute=function() return true end}
local ui
ctx.setFlag=function(key,value) flags[key]=value;if ui then ui.Repaint() end end
'''
checks=r'''
local nativeButton=Instance.new('TextButton');nativeButton.Parent=parent
nativeButton.Text='Native game';nativeButton.Visible=true;nativeButton.Selectable=true;nativeButton.BackgroundTransparency=.4
ui=Library.Create(ctx)
assert(GuiService.SelectedObject==nil and GuiService.GuiNavigationEnabled==false and GuiService.AutoSelectGuiEnabled==false,'reset stuck keyboard GUI navigation')
assert(nativeButton.Visible and nativeButton.Selectable and nativeButton.BackgroundTransparency==.4,'native buttons remain unchanged')
assert(ui.Root.Parent==parent and #state.connections>=6)
local function find(predicate)
 for _,obj in ipairs(objects) do if obj.Parent and predicate(obj) then return obj end end
 error('widget missing')
end
local function button(text) return find(function(o) return o:IsA('TextButton') and o.Text==text end) end
local main=find(function(o) return o.Name=='Window' end)
assert(math.abs(main.BackgroundTransparency-.15)<.001,'default transparency')
local before=writes;ui.Repaint();assert(writes==before,'unchanged repaint must not write GUI properties')
flags.AO_UI_Transparency=50;ui.Repaint();assert(main.BackgroundTransparency==.5,'background transparency')
local label=find(function(o) return o:IsA('TextLabel') and o.Text=='Transparency' end)
assert(label.BackgroundTransparency==1,'text surface stays transparent')
local slider=find(function(o) return o.Name=='TransparencySlider' end)
local input={UserInputType=Enum.UserInputType.Touch,Position={X=170,Y=0}}
slider.InputBegan:Fire(input);assert(flags.AO_UI_Transparency==65,'touch slider reaches max')
input.Position.X=0;UIS.InputChanged:Fire(input);assert(flags.AO_UI_Transparency==0,'touch slider reaches min')
UIS.InputEnded:Fire(input);input.Position.X=170;UIS.InputChanged:Fire(input)
assert(flags.AO_UI_Transparency==0,'released slider stops changing')
profile.autoProfile='NewProfile';profile.configStatus='Fresh status';now+=1;ui.Refresh()
assert(find(function(o) return o.Text=='NewProfile' end),'live profile state')
assert(calls.boss==0 and calls.raid==0 and calls.siege==0,'hidden tabs skip cooldown scans')
button('04   Raid').MouseButton1Click:Fire();now+=1;ui.Refresh()
assert(calls.raid==1 and calls.boss==0 and calls.siege==0,'only active tab scans cooldowns')
ui.Root.Enabled=false;now+=1;local before=writes;ui.Refresh();assert(before==writes,'hidden window does no GUI writes')
ui.Root.Enabled=true
button('LOAD').MouseButton1Click:Fire();assert(profile.currentProfile=='Loaded' and main.BackgroundTransparency==.35,'profile callbacks and saved appearance')
ui.Root.Enabled=true
UIS.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift},false);advance(.2)
assert(not ui.Root.Enabled and state.enabled,'Right Shift hides UI without stopping auto')
UIS.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift},false);advance(.2)
assert(ui.Root.Enabled and state.enabled,'Right Shift shows UI')
button('×').MouseButton1Click:Fire();advance(.2);assert(not ui.Root.Enabled)
UIS.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift},false);advance(.2)
assert(ui.Root.Enabled,'Right Shift reopens dismissed UI')
print('PASS: Right Shift hide/show, reopen after close, automation unchanged')
state.worldBuffs={hpPct=.15,dmgPct=.2,dr=.1,critDmg=.25}
state.worldBuffDelta={hpPct=0,dmgPct=.1,dr=0,critDmg=0};state.worldBuffWave=7
now+=1;ui.Refresh()
local worldLabel=find(function(o) return o:IsA('TextLabel') and o.Text:find('Total: HP +15%',1,true) end)
assert(worldLabel.Text:find('DMG +20%',1,true) and worldLabel.Text:find('DR +10%',1,true)
 and worldLabel.Text:find('Crit DMG +25%',1,true),'all world totals')
assert(worldLabel.Text:find('Wave 7: DMG +10%',1,true),'latest wave gain')
state.worldBuffDelta={};state.worldBuffWave=8;now+=1;ui.Refresh()
assert(worldLabel.Text:find('Wave 8: No World buff',1,true),'wave without World blessing')
state.worldBuffDelta=nil;now+=1;ui.Refresh()
assert(worldLabel.Text:find('Wave 8: --',1,true),'resumed history is unknown')
print('PASS: World Blessing totals, latest wave gain, no-buff wave, resumed unknown history')


-- Mode rows are removed and the team is rendered with semantic roles.
for _,obj in ipairs(objects) do
 if obj.Parent and obj:IsA('TextLabel') then assert(obj.Text~='Mode' and obj.Text~='Carry','obsolete status row') end
end
state.teamCards={{name='Random fighter',role='normal'},{name='Deathless Outlaw',role='carry'},
 {name='Useless Goddess',role='support'},{name='Idol',role='support',dead=true}}
now+=1;ui.Refresh()
local carryName=find(function(o) return o.Text=='Deathless Outlaw' end)
local supportName=find(function(o) return o.Text=='Useless Goddess' end)
local randomName=find(function(o) return o.Text=='Random fighter' end)
assert(carryName.TextColor3~=supportName.TextColor3 and supportName.TextColor3~=randomName.TextColor3)
assert(find(function(o) return o.Text=='02  CARRY' end) and find(function(o) return o.Text=='04  SUPPORT  ·  DOWN' end))
-- Search must preserve source option indices after filtering.
local themeDrop=button('Ocean  ▾')
themeDrop.MouseButton1Click:Fire()
local search=find(function(o) return o.Name=='DropdownSearch' end)
search.Text='Light';button('Light').MouseButton1Click:Fire()
assert(flags.AO_UI_Theme=='Light','filtered dropdown selects the original value')
assert(randomName.TextColor3~=carryName.TextColor3,'Light theme retains role distinction')
-- Profile geometry loads at runtime and dragging cannot lose the window.
flags.AO_UI_WindowW=900;flags.AO_UI_WindowH=620;flags.AO_UI_WindowX=.9;flags.AO_UI_WindowY=.8
ui.Repaint();assert(main.Size.X.Offset==900 and main.Size.Y.Offset==620)
local header=find(function(o) return o.Parent==main and o.Size and o.Size.Y.Offset==57 end)
header.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=0,Y=0}})
UIS.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position={X=5000,Y=5000}})
assert(main.Position.X.Offset+main.Size.X.Offset<=1280 and main.Position.Y.Offset+main.Size.Y.Offset<=800)
UIS.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1})
assert(profile.geometrySaved and flags.AO_UI_WindowX==1 and flags.AO_UI_WindowY==1)
local handle=find(function(o) return o.Name=='ResizeHandle' end)
handle.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=0,Y=0}})
UIS.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position={X=-100,Y=-50}})
UIS.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1})
assert(flags.AO_UI_WindowW==800 and flags.AO_UI_WindowH==570)
-- Camera replacement disconnects the old viewport listener; phone layout stays in bounds.
local oldCameraSignal=cameraSignals.ViewportSize
local replacementSignal=signal()
workspace.CurrentCamera={ViewportSize={X=390,Y=844},GetPropertyChangedSignal=function() return replacementSignal end}
local count=#state.connections
workspaceSignals.CurrentCamera:Fire()
assert(#state.connections==count,'camera replacement does not grow connections')
assert(main.Size.X.Offset==374 and main.Size.Y.Offset<=828)
local cards=find(function(o) return o.Text=='Cards' end).Parent
assert(cards.Size.Y.Offset==286,'phone cards use one column')
local mobileX=main.Position.X.Offset
camera.ViewportSize={X=50,Y=50};oldCameraSignal:Fire()
assert(main.Size.X.Offset==374 and main.Position.X.Offset==mobileX,'old camera is disconnected')
-- Hiding during a touch drag releases the slider and closes its overlays.
local touch={UserInputType=Enum.UserInputType.Touch,Position={X=20,Y=0}}
slider.InputBegan:Fire(touch)
ui.Root.Enabled=false
local value=flags.AO_UI_Transparency;touch.Position.X=170;UIS.InputChanged:Fire(touch)
assert(flags.AO_UI_Transparency==value)
ui.Root.Enabled=true
-- Drain earlier profile feedback, then verify queue order independently.
for index=1,3 do ui.Refresh();advance(15);advance(1) end
-- Toasts queue while hidden and drain in order when visible.
ui.Root.Enabled=false
ui.Notify('First notification','success',1);ui.Notify('Second notification','warning',1)
ui.Root.Enabled=true;now+=1;ui.Refresh()
assert(find(function(o) return o.Text=='First notification' end))
advance(1.1);advance(.2)
assert(find(function(o) return o.Text=='Second notification' end))
advance(1.1);advance(.2)
-- Destructive UI actions require confirmation; X and Right Shift remain non-destructive.
button('STOP SCRIPT').MouseButton1Click:Fire()
local confirm=find(function(o) return o.Name=='StopConfirmation' end)
assert(confirm.Visible and not stateStopped)
button('CANCEL').MouseButton1Click:Fire();assert(not confirm.Visible)
assert(tweenCount>0,'TweenService used for transitions')
print('PASS: Cards roles, no Mode rows, Light theme, searchable dropdown, drag/resize/profile geometry, camera replacement, phone layout, canceled touch, toast queue, stop confirmation')

local before=#state.connections
local tracked=table.clone(state.connections)
state.stop();assert(stateStopped)
assert(ui.Root.Parent==nil,'stop destroys owned UI')
advance(20);advance(1)
assert(ui.Root.Parent==nil and nativeButton.Parent==parent,'delayed effects cannot resurrect UI or destroy game buttons')
assert(GuiService.GuiNavigationEnabled and GuiService.AutoSelectGuiEnabled,'restore navigation settings on stop')
for _,c in ipairs(tracked) do assert(not c.Connected,'external connections disconnected') end
print('PASS: UI creation, unchanged repaint, transparency, touch slider, live profiles, visible-tab refresh, hidden idle, profile load, cleanup ('..before..' connections)')
local originalStop=state.__animeUiStopBase
local second=Library.Create(ctx)
local previousRoot=second.Root
local count=#state.connections
local third=Library.Create(ctx)
assert(previousRoot.Parent==nil and #state.connections==count,'Create on the same state replaces old UI without leaking global listeners')
assert(state.__animeUiStopBase==originalStop,'recreation does not chain stop wrappers')
third.Destroy();third.Destroy()
assert(#state.connections==0 and third.Root.Parent==nil,'Destroy is idempotent')
print('PASS: repeated Create compatibility, no stop-wrapper chain, idempotent Destroy')
local oldContext=table.clone(ctx)
oldContext.state={alive=true,enabled=false,phase='',lastSeenWave=0,supportCount=0,curseCount=0,carryName='Legacy carry',carrySlot=2,stop=noop}
oldContext.flags={AO_UI_Theme='Midnight',AO_UI_Transparency=15}
oldContext.saveAppearance=nil;oldContext.TweenService=nil;oldContext.Delay=nil;oldContext.GuiService=nil
local legacy=Library.Create(oldContext)
assert(type(legacy.Repaint)=='function' and type(legacy.Refresh)=='function' and legacy.Root.Parent==parent and Library.Version==1)
legacy.Repaint();legacy.Refresh();legacy.Destroy()
print('PASS: old Create(ctx), Version=1 and Repaint/Refresh/Root contract without new fields')


'''
main=(Path(__file__).resolve().parents[1]/'cardorrigin.lua').read_text()
loader=main[main.index('local function loadUILibrary()'):main.index('local UILibrary=loadUILibrary()')]
loader_mock=r'''
local env={}
local requests=0
local source='return {Version=1,Create=function() end}'
local game={HttpGet=function(_,url)
    assert(url=='https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/main/anime_origin_ui.lua')
    requests+=1
    if source==false then error('network unavailable') end
    return source
end}
'''
loader_checks=r'''
assert(loadUILibrary().Version==1 and requests==1,'download and execute GitHub library')
env.AnimeOriginUILibrary={Version=1,Create=function() end}
assert(loadUILibrary()==env.AnimeOriginUILibrary and requests==1,'injected library bypass')
env.AnimeOriginUILibrary=nil
source='not valid Lua!';assert(not pcall(loadUILibrary),'reject invalid source')
source='return {Version=2}';assert(not pcall(loadUILibrary),'reject incompatible API')
source=false;local ok,err=pcall(loadUILibrary)
assert(not ok and tostring(err):find('Cannot load Anime Origin UI from GitHub',1,true),'clear network error')
print('PASS: GitHub loader, URL, injected override, syntax/API rejection, network error')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:
    raise SystemExit('Set LUAU_BIN to the Luau executable or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='anime-ui-test-') as directory:
    script=Path(directory)/'ui.spec.luau'
    script.write_text(mock+'\nlocal function loadLibrary()\n'+src+'\nend\nlocal Library=loadLibrary()\n'+checks)
    subprocess.run([binary,str(script)],check=True)

    script.write_text(loader_mock+loader+loader_checks)
    subprocess.run([binary,str(script)],check=True)
