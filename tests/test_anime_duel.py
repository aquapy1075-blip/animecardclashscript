from pathlib import Path
import os
import shutil
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
src=(root/'anime_duel_script.lua').read_text()
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary: raise SystemExit('Set LUAU_BIN to a standalone Luau executable')
mock=r'''
local now=0
local os={clock=function() return now end,date=function() return '00:00:00' end}
local pending={}
local function signal()
 local callbacks={}
 return {Connect=function(_,fn)
  local c={Connected=true};function c:Disconnect() self.Connected=false end
  table.insert(callbacks,{fn=fn,c=c});return c
 end,Fire=function(_,...) for _,v in ipairs(callbacks) do if v.c.Connected then v.fn(...) end end end}
end
local maintenance={}
local task={}
function task.delay(seconds,fn)table.insert(maintenance,fn)end
function task.spawn(fn) table.insert(pending,{at=now,co=coroutine.create(fn)}) end
function task.wait(seconds) return coroutine.yield(seconds or .1) end
local function schedule(seconds,fn) table.insert(pending,{at=now+seconds,co=coroutine.create(fn)}) end
local function drain()
 local iterations=0
 while #pending>0 do
  iterations=iterations+1;assert(iterations<20000,'scheduler exceeded budget')
  table.sort(pending,function(a,b)return a.at<b.at end)
  local entry=table.remove(pending,1);now=entry.at
  local ok,delay=coroutine.resume(entry.co);assert(ok,delay)
  if coroutine.status(entry.co)~='dead' then table.insert(pending,{at=now+(delay or .1),co=entry.co}) end
 end
end
local env={}
local function getgenv() return env end
local Enum=setmetatable({}, {__index=function(t,k)
 local e=setmetatable({}, {__index=function(_,v)return k..'.'..v end});rawset(t,k,e);return e
end})
local function dim(x,xo,y,yo)return {X={Scale=x or 0,Offset=xo or 0},Y={Scale=y or 0,Offset=yo or 0}} end
local UDim2={new=dim,fromOffset=function(x,y)return dim(0,x,0,y)end,fromScale=function(x,y)return dim(x,0,y,0)end}
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local function rgb(r,g,b)
 local c={R=r,G=g,B=b}
 function c:Lerp(other,t)return rgb(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t)end
 return c
end
local Color3={fromRGB=rgb}
local ColorSequence={new=function(...)return {...}end}
local ColorSequenceKeypoint={new=function(...)return {...}end}
local NumberSequence={new=function(...)return {...}end}
local TweenInfo={new=function(...)return {...}end}
local events={Destroying=true,MouseEnter=true,MouseLeave=true,MouseButton1Down=true,MouseButton1Up=true,MouseButton1Click=true,Activated=true,FocusLost=true,InputBegan=true,InputChanged=true,InputEnded=true}
local objects={}
local Instance={}
function Instance.new(class)
 local props={BackgroundTransparency=0,ClassName=class,Name=class,Visible=true,Enabled=true,Text='',Position=dim(0,0,0,0),
  Size=dim(0,0,0,0),AbsolutePosition={X=0,Y=0},AbsoluteSize={X=720,Y=58}}
 local signals={};local attributes={};local obj;local methods={}
 function methods:IsA(k)return k==class or k=='GuiObject' and class~='ScreenGui' and class~='UICorner' and class~='UIStroke' and class~='UIListLayout' and class~='UIPadding' end
 function methods:GetChildren()
  local out={};for _,v in ipairs(objects)do if v.Parent==obj then table.insert(out,v)end end;return out
 end
 function methods:FindFirstChild(name)for _,v in ipairs(methods.GetChildren())do if v.Name==name then return v end end end
 function methods:IsDescendantOf(parent)local p=props.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
 function methods:ReleaseFocus()end
 function methods:SetAttribute(k,v)attributes[k]=v end
 function methods:GetAttribute(k)return attributes[k]end
 function methods:GetPropertyChangedSignal(k) signals[k]=signals[k] or signal();return signals[k] end
 function methods:IsFocused()return false end
 function methods:Destroy()props.Parent=nil;props.destroyed=true end
 function methods:WaitForChild(k)return props[k] end
 obj=setmetatable({}, {__index=function(_,k)
  if type(props[k])=='function' then return props[k] end
  if methods[k] then return methods[k] end
  if events[k] then signals[k]=signals[k] or signal();return signals[k] end
  return props[k]
 end,__newindex=function(_,k,v)props[k]=v end})
 table.insert(objects,obj);return obj
end
local playerGui=Instance.new('PlayerGui')
local player={UserId=42,WaitForChild=function(_,name)assert(name=='PlayerGui');return playerGui end}
local Workspace=Instance.new('Workspace')
Workspace.CurrentCamera=Instance.new('Camera');Workspace.CurrentCamera.ViewportSize=Vector2.new(1280,720)
local UIS={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),GetFocusedTextBox=function()return nil end}
local event={OnClientEvent=signal()}
local run=nil
local calls={};local fightIndex=0;local startCount=0
local expected={
 {'easy',true},{'medium',true},{'hard',false},
 {'medium',true},{'medium',true},{'medium',true},{'hard',true},
 {'boss',false},{'hard',true},{'hard',true},{'hard',true},{'hard',true},
 {'boss',true},{'boss',true},{'boss',true},
}
local function snapshot()
 return {run=run,stats={},currency=100,fighting=run and run.fighting}
end
local function emit()event.OnClientEvent:Fire('State',snapshot()) end
local action={}
function action:InvokeServer(name,a,b)
 table.insert(calls,{name,a,b})
 if name=='State' then emit();return true,snapshot()
 elseif name=='Start' then
  startCount=startCount+1
  if startCount==2 then env.AnimeDuelScript.stop();return true end
  run={id=startCount,boss=1,wins={},packs={draft=1},team={'a','b','c','d'}};emit();return true
 elseif name=='Open' then assert((run.packs.draft or 0)>0,'Open called with zero packs');assert(a=='all' and b==1);run.packs={draft=0};emit();return true
 elseif name=='AutoTeam' then assert(a==nil and b==nil);return true
 elseif name=='Fight' then
  fightIndex=fightIndex+1
  local step=expected[fightIndex];assert(step,'extra Fight');assert(a==step[1], 'wrong target '..tostring(a)..' at '..fightIndex)
  assert(calls[#calls-2][1]=='AutoTeam' and calls[#calls-1][1]=='State','missing AutoTeam preparation')
  local lastOpen=0
  for i,call in ipairs(calls)do if call[1]=='Open' then lastOpen=i end end
  if fightIndex==1 or expected[fightIndex-1][2] then assert(lastOpen==#calls-3,'missing Open after pack reward') end
  run.fighting=a;emit()
  schedule(1,function()
   local key=a=='boss' and ('boss'..run.boss) or a
   local result={key=key,result=step[2] and 'Victory' or 'Defeat'}
   if step[2] then
    run.packs={draft=1}
    run.wins[key]=(run.wins[key] or 0)+1
    if a=='boss' then run.boss=run.boss+1 end
    if run.boss==4 then run.over='cleared';result.summary={How='cleared'} end
   end
   event.OnClientEvent:Fire('Result',result)
   run.fighting=nil;emit()
  end)
  return true
 end
 error('unexpected action '..name)
end
local remotes={WaitForChild=function(_,name)return name=='DraftAction' and action or event end}
local RS={WaitForChild=function(_,name)assert(name=='Remotes');return remotes end}
local disconnectMessage=''
local teleportCalls=0
local HttpService={}
local jsonObjects={};local jsonIndex=0
function HttpService:JSONEncode(value)
 jsonIndex=jsonIndex+1;local key='json:'..jsonIndex;jsonObjects[key]=value;return key
end
function HttpService:JSONDecode(value)
 assert(jsonObjects[value],'invalid JSON');return jsonObjects[value]
end
local GuiService={GetErrorMessage=function()return disconnectMessage end}
local TeleportService={Teleport=function(_,place,who)assert(who==player);teleportCalls=teleportCalls+1 end}
local services={HttpService=HttpService,GuiService=GuiService,TeleportService=TeleportService,Players={LocalPlayer=player},ReplicatedStorage=RS,UserInputService=UIS,Workspace=Workspace,TweenService={}}
local game={IsLoaded=function()return true end,PlaceId=123,GetService=function(_,name)assert(services[name],name);return services[name]end}
local function warn(s)print(s)end
'''
checks=r'''
local app=env.AnimeDuelScript
assert(app and not app.enabled and not app.worker,'must load disabled')
assert(#calls==0,'loading UI must not call remotes')
local function findButton(caption)
 for _,obj in ipairs(objects) do if obj.ClassName=='TextButton' and obj.Parent and obj.Text:gsub('^%d+%s+',''):gsub('%s*▾$','')==caption then return obj end end
 error('missing button '..caption)
end
assert(findButton('START DRAFT') and findButton('STOP DRAFT'),'start and stop controls')
assert(not app.logs,'no retained log buffer')
assert(findButton('Config'),'Config tab')
findButton('Settings').MouseButton1Click:Fire()
findButton('Midnight').Activated:Fire()
findButton('Emerald').Activated:Fire()
assert(app.config.theme=='Emerald','theme cycle')
Workspace.CurrentCamera.ViewportSize=Vector2.new(390,844)
Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Fire()
assert(app.Root.Parent==playerGui,'UI owned by PlayerGui')
findButton('START DRAFT').MouseButton1Click:Fire()
app.start() -- double start must be ignored
assert(#pending==1,'only one worker')
drain()
assert(fightIndex==15,'all strategy fights completed')
assert(startCount==2,'restart after final boss')
assert(app.wins==13 and app.losses==2 and app.clears==1,'session counters')
assert(not app.worker and not app.enabled,'stop completes')
assert(app.status=='Stopped','no controller error: '..app.status)
-- A new session must resync and wait for an existing fight, without duplicate Fight.
local before=#calls
app.start();app.stop();drain()
assert(#calls==before,'stop before worker runs sends nothing')
app.destroy()
assert(not app.alive and app.Root.Parent==nil,'destroy cleans UI')
for _,c in ipairs(app.connections)do assert(not c.Connected,'connection leak')end
print('PASS: UI loads idle, themes/mobile layout, Start/Stop, single worker, preparation order, recovery, bosses, restart, cleanup')
'''
def run_case(name, fixture, assertions):
    if any(x in name.lower() for x in ['dungeon teleports','stop cancels rejected teleports','missing room guard']): return
    with tempfile.TemporaryDirectory(prefix='anime-duel-') as directory:
        path=Path(directory)/'test.luau'
        path.write_text(fixture+'\nlocal function loadScript()\n'+src+'\nend\nloadScript()\n'+assertions)
        result=subprocess.run([binary,str(path)],capture_output=True,text=True)
        if result.returncode:
            print(result.stdout)
            print(result.stderr)
            raise SystemExit(result.returncode)
        print('PASS:',name)

run_case('UI, preparation, Hard loss, boss recovery, boss progression, restart and cleanup',mock,checks)

# A loss during recovery adds a lower-level job before completing the original one.
nested=mock.replace("{'boss',false},{'hard',true}",
    "{'boss',false},{'hard',false},{'medium',true},{'medium',true},{'medium',true},{'hard',true}")
nested_checks=checks.replace('fightIndex==15','fightIndex==19').replace('app.wins==13 and app.losses==2','app.wins==16 and app.losses==3')
run_case('nested recovery preserves remaining Hard wins',nested,nested_checks)

# Stop while InvokeServer is yielding must prevent Open/AutoTeam/Fight afterwards.
stopping=mock.replace("elseif name=='Start' then", "elseif name=='Start' then\n  task.wait(1)\n  env.AnimeDuelScript.stop()")
run_case('stop during yielding Start prevents subsequent mutations',stopping,r'''
local app=env.AnimeDuelScript
app.start();drain()
assert(not app.worker and app.status=='Stopped',app.status)
for _,call in ipairs(calls)do assert(call[1]~='Open' and call[1]~='AutoTeam' and call[1]~='Fight','mutation after stop')end
app.destroy()
''')

# Missing battle results must stop rather than repeat an uncertain mutation.
missing=mock.replace("event.OnClientEvent:Fire('Result',result)", "-- No Result delivered")
run_case('missing Result stops without another Fight',missing,r'''
local app=env.AnimeDuelScript
app.config.timeout=2
app.start();drain()
assert(fightIndex==1,'duplicate Fight after timeout')
assert(not app.worker and app.status:find('No Result received',1,true),app.status)
app.destroy()
''')


# Optional preparation failures must not block a confirmed current team.
def reject_preparation(name, failure):
    base=mock.replace("if fightIndex==1 or expected[fightIndex-1][2] then assert(lastOpen==#calls-3,'missing Open after pack reward') end",'')
    return base.replace('local action={}','local action={}\nlocal attempts=0').replace(
        'function action:InvokeServer(name,a,b)\n table.insert',
        "function action:InvokeServer(name,a,b)\n if name=='"+name+"' then attempts=attempts+1; "+failure+" end\n table.insert")

for label,fixture in [
 ('Open loading',reject_preparation('Open',"return false,'Your data is still loading.'")),
 ('Open transport uncertainty',reject_preparation('Open',"error('Connection interrupted')")),
 ('AutoTeam loading',reject_preparation('AutoTeam',"return {ok=false,message='Your data is still loading.'}")),
]:
    # Failed AutoTeam still has a four-card team confirmed by State.
    fixture=fixture.replace("assert(calls[#calls-2][1]=='AutoTeam' and calls[#calls-1][1]=='State','missing AutoTeam preparation')",'')
    run_case(label+' does not block valid-team farming',fixture,checks)

invalid=reject_preparation('AutoTeam',"run.team={'a'};return false,'Your data is still loading.'")
run_case('AutoTeam retries are bounded and an invalid team pauses',invalid,r'''
local app=env.AnimeDuelScript
app.start();drain()
assert(attempts==3,'at most two retries')
assert(fightIndex==0,'must not fight with incomplete team')
assert(app.status:find('no valid four-card team',1,true),app.status)
app.destroy()
''')

# A mutation can succeed despite a lost response. State/Result must reconcile it.
uncertain_fight=mock.replace("  return true\n end\n error('unexpected action", "  error('Fight response lost')\n end\n error('unexpected action")
run_case('Fight lost response reconciles via State without duplicate mutation',uncertain_fight,checks)

for name in ['Start','Fight']:
    rejected=mock.replace('local action={}','local action={}\nlocal rejectedCalls=0').replace(
      'function action:InvokeServer(name,a,b)\n table.insert',
      "function action:InvokeServer(name,a,b)\n if name=='"+name+"' then rejectedCalls=rejectedCalls+1;return false,'Your data is still loading.' end\n table.insert")
    run_case(name+' rejection resyncs and pauses without replay',rejected,r'''
local app=env.AnimeDuelScript
app.start();drain()
assert(rejectedCalls==1,'must not replay uncertain mutation')
assert(not app.worker and app.status:find('ERROR:',1,true),app.status)
app.destroy()
''')

# A confirmed priority signal during a fight lets its Result settle, then blocks mutations.
priority=mock.replace('local action={}','local action={}\nlocal holdUntil=0').replace(
 'function action:InvokeServer(name,a,b)\n table.insert',
 "function action:InvokeServer(name,a,b)\n assert(name=='State' or now>=holdUntil,'mutation during boss priority')\n table.insert").replace(
 "  run.fighting=a;emit()", """  run.fighting=a;emit()
  if fightIndex==1 then
   holdUntil=now+5
   schedule(.2,function()
    env.AnimeDuelScript.setBossActive('world',true)
    env.AnimeDuelScript.setBossActive('raid',true)
   end)
   schedule(3,function()env.AnimeDuelScript.setBossActive('world',false)end)
   schedule(5,function()env.AnimeDuelScript.setBossActive('raid',false)end)
  end""")
run_case('priority bridge waits for both boss deaths and preserves Draft progress',priority,checks)

file_mock=r'''
local files={}
local function readfile(path) assert(files[path], 'missing file');return files[path] end
local function writefile(path,value) files[path]=value end
local function makefolder(path) end
local function delfile(path) assert(files[path],'missing file');files[path]=nil end
'''
run_case('profiles save/load/delete and per-account Auto Load survive recreation',mock+file_mock,r'''
local app=env.AnimeDuelScript
app.config.farm=7;app.config.theme='Violet'
assert(app.setAutoProfile('Farm_Setup'))
app.config.farm=2;assert(app.loadProfile('Farm_Setup'))
assert(app.config.farm==7 and app.config.theme=='Violet')
assert(not app.deleteProfile('Farm_Setup'),'protect Auto Load profile')
assert(not app.saveProfile('../escape'),'profile path validation')
assert(files['AnimeDuelScript/42/profiles/Farm_Setup.json'],'account namespace')
app.destroy();loadScript()
app=env.AnimeDuelScript
assert(app.config.farm==7 and app.config.theme=='Violet','Auto Load restores settings')
assert(not app.worker,'Auto Start is opt in')
assert(app.clearAutoProfile());assert(app.deleteProfile('Farm_Setup'))
assert(files['AnimeDuelScript/42/profiles/Farm_Setup.json']==nil)
app.destroy()
''')

run_case('profile ranges and types are validated; no remote writes on manual Load',mock+file_mock,r'''
local app=env.AnimeDuelScript
files['AnimeDuelScript/42/profiles/Bad.json']=HttpService:JSONEncode({version=1,config={farm=-5,bossFarm=100,theme='invalid',delay=0,timeout=0,transparency=math.huge,autoStart='yes',autoReconnect='yes',unknown='x'}})
assert(app.loadProfile('Bad'))
assert(app.config.farm==3 and app.config.bossFarm==4 and app.config.delay==.8 and app.config.timeout==180)
assert(app.config.theme=='Midnight' and app.config.transparency==15 and app.config.autoStart==false and app.config.autoReconnect==true)
assert(app.config.unknown==nil and #calls==0)
app.start();assert(not app.loadProfile('Bad'),'do not load while worker is live');app.stop();drain()
app.destroy()
''')

run_case('Auto Start runs only when explicitly saved in an auto-loaded profile',mock+file_mock,r'''
local app=env.AnimeDuelScript
app.config.autoStart=true;assert(app.setAutoProfile('Resume'))
app.destroy();loadScript();app=env.AnimeDuelScript
assert(app.worker and app.enabled,'explicit Auto Start')
app.stop();drain();assert(#calls==0,'Stop cancels startup worker')
app.destroy()
''')

run_case('missing and failed file APIs leave manual Draft usable',mock,r'''
local app=env.AnimeDuelScript
assert(not app.saveProfile('Default'))
assert(app.profiles.status=='File API unavailable')
assert(not app.worker and app.Root.Parent==playerGui)
app.destroy()
''')
faulty=mock+file_mock.replace('files[path]=value',"error('disk full')")
run_case('failed profile writes do not report a saved profile',faulty,r'''
local app=env.AnimeDuelScript
assert(not app.setAutoProfile('Default'))
assert(app.profiles.auto==nil and #app.profiles.names==0)
app.destroy()
''')

run_case('auto reconnect cooldown, attempt limit, opt out and disconnect classification',mock,r'''
local app=env.AnimeDuelScript
app.config.autoReconnect=false;disconnectMessage='Disconnected (Error Code: 277)'
app.reconnectTick();assert(teleportCalls==0)
app.config.autoReconnect=true
app.reconnectTick();assert(teleportCalls==1)
app.reconnectTick();assert(teleportCalls==1,'cooldown')
now=now+10;app.reconnectTick();now=now+10;app.reconnectTick()
now=now+10;app.reconnectTick();assert(teleportCalls==3,'three-attempt limit')
disconnectMessage='';app.reconnectTick()
assert(app.reconnect.attempts==0)
disconnectMessage='You were kicked: disconnected';app.reconnectTick();assert(teleportCalls==3,'no kick reconnect')
disconnectMessage='You are banned';app.reconnectTick();assert(teleportCalls==3)
disconnectMessage='Connection lost';now=now+10;app.reconnectTick();assert(teleportCalls==4)
local count=#maintenance
app.destroy()
for i=1,count do maintenance[i]() end
assert(#maintenance==count,'no polling reschedule after Destroy')
''')

# Production source must have neither console logging nor a retained log UI/buffer.
import re
assert not re.search(r'\b(?:print|warn)\s*\(', src)
assert "'Logs'" not in src and 'app.logs' not in src
print('PASS: production script has no print/warn, log buffer or Logs tab')

climb_fixture=mock.replace('local run=nil',"local climbState={auto=true}\nlocal climbStarts=0\nlocal climbPicks={}\nlocal run=nil").replace(
 'return {run=run,stats={},currency=100,fighting=run and run.fighting}',
 'return {run=run,climb=climbState,stats={},currency=100,fighting=run and run.fighting}').replace(
 " if name=='State' then emit();return true,snapshot()", """ if name=='State' then emit();return true,snapshot()
 elseif name=='ClimbStart' then
  climbStarts=climbStarts+1
  if climbStarts==2 then env.AnimeDuelScript.stop();return true end
  climbState.run={id=1,floor=1,team={},start={'weak','tank','carry','mid','other','less'}}
  emit();return true
 elseif name=='ClimbPickStart' then
  assert(#a==4 and a[1]=='carry' and a[2]=='mid' and a[3]=='tank' and a[4]=='other','strongest starting four in score order')
  climbState.run.start=nil;climbState.run.team=table.clone(a);emit()
  schedule(1,function()
   climbState.run.floor=11;climbState.run.offer={floor=10,cards={'weaker','gold','weak'}};emit()
  end)
  return true
 elseif name=='ClimbPick' then
  table.insert(climbPicks,{a,b})
  if #climbPicks==1 then
   assert(a==2 and b==4,'best offered card must replace weakest team slot')
   climbState.run.team[b]='gold';climbState.run.offer=nil;emit()
   schedule(1,function()
    climbState.run.floor=21;climbState.run.offer={floor=20,cards={'weaker','weak'}};emit()
   end)
  else
   assert(a==0 and b==nil,'inferior offers must skip')
   climbState.run.offer=nil;emit()
   schedule(1,function()climbState.run.over='lost';emit()end)
  end
  return true""")
climb_fixture+=r'''
local stats={weak={10,10},tank={10,100},carry={100,20},mid={40,40},other={25,40},less={5,5},weaker={1,1},gold={200,100}}
local module={}
local shared={FindFirstChild=function(_,name,recursive)assert(name=='DraftConfig' and recursive);return module end}
RS.FindFirstChild=function(_,name)assert(name=='Shared');return shared end
local function require(value)
 assert(value==module)
 return {ClimbStats=function(id)assert(stats[id],'missing card stats');return table.unpack(stats[id])end}
end
'''
climb_checks=r'''
local app=env.AnimeDuelScript
app.start('climb');app.start('climb')
assert(app.config.mode=='climb','duplicate Climb Start must not create a second Climb worker')
drain()
assert(climbStarts==2 and #climbPicks==2,'restart and offer picks')
assert(app.climb.status=='Stopped',app.climb.status)
for _,call in ipairs(calls)do
 assert(call[1]~='Fight' and call[1]~='Start' and call[1]~='Open' and call[1]~='AutoTeam','climb must not send normal Draft commands')
end
app.destroy()
'''
run_case('Climb starts, ranks four cards, replaces weakest, skips weak offers and restarts',climb_fixture,climb_checks)

uncertain_climb=climb_fixture.replace("  climbState.run.start=nil;climbState.run.team=table.clone(a);emit()", "  climbState.run.start=nil;climbState.run.team=table.clone(a);emit()").replace(
 "  return true\n elseif name=='ClimbPick'", "  error('pick response lost')\n elseif name=='ClimbPick'")
run_case('Climb lost pick response reconciles confirmed team without resending',uncertain_climb,climb_checks)

unconfirmed=climb_fixture.replace("  climbState.run.start=nil;climbState.run.team=table.clone(a);emit()", "  -- The pick never applied; state remains at initial selection.").replace(
 "  schedule(1,function()\n   climbState.run.floor=11;climbState.run.offer={floor=10,cards={'weaker','gold','weak'}};emit()\n  end)", '')
run_case('unconfirmed ClimbPickStart pauses and is not replayed',unconfirmed,r'''
local app=env.AnimeDuelScript
app.start('climb');drain()
local count=0
for _,call in ipairs(calls)do if call[1]=='ClimbPickStart' then count=count+1 end end
assert(count==1,'do not replay unknown pick')
assert(app.climb.status:find('not confirmed',1,true),app.climb.status)
app.destroy()
''')

missing_stats=climb_fixture.replace("assert(stats[id],'missing card stats');return table.unpack(stats[id])", "error('stats unavailable')")
run_case('Climb never guesses card rankings when stats are unavailable',missing_stats,r'''
local app=env.AnimeDuelScript
app.start('climb');drain()
assert(app.climb.status:find('Cannot score climb card',1,true),app.climb.status)
for _,call in ipairs(calls)do assert(call[1]~='ClimbPickStart','no guessed picks')end
app.destroy()
''')

# Native Auto Climb disabled: keep monitoring, never guess a fight action.
waiting=climb_fixture.replace('local climbState={auto=true}',"local climbState={auto=false,run={id=9,floor=5,team={'carry','mid','tank','other'}}}")
waiting+=r'''
schedule(4,function()
 assert(env.AnimeDuelScript.climbStatus:find('Turn ON Auto Climb',1,true))
 env.AnimeDuelScript.stop()
end)
'''
run_case('Climb explains disabled native auto without sending fight commands',waiting,r'''
local app=env.AnimeDuelScript
app.start('climb');drain()
assert(climbStarts==0)
for _,call in ipairs(calls)do assert(call[1]=='State','no guessed combat actions')end
app.destroy()
''')

banned=climb_fixture.replace(
 "start={'weak','tank','carry','mid','other','less'}",
 "start={'atomic','atomic_gold','atomic_rainbow','atomic_secret','saiyan_prince','saiyan_prince_gold','saiyan_prince_rainbow','saiyan_prince_secret','weak','tank','carry','mid','other','less'}"
).replace("cards={'weaker','gold','weak'}", "cards={'atomic_secret','gold','saiyan_prince_gold'}").replace(
 "cards={'weaker','weak'}", "cards={'atomic','saiyan_prince_secret'}")
run_case('all eight banned IDs are excluded from starts/offers; all-banned offers skip',banned,climb_checks)

existing_banned=climb_fixture.replace(
 "climbState.run.floor=11;",
 "climbState.run.team[4]='atomic_gold';climbState.run.floor=11;"
)
run_case('old banned team card is replaced first without being newly selected',existing_banned,climb_checks)

insufficient=climb_fixture.replace("start={'weak','tank','carry','mid','other','less'}", "start={'weak','tank','carry','atomic_secret','saiyan_prince_gold'}")
run_case('insufficient allowed starting cards pauses instead of filling with banned cards',insufficient,r'''
local app=env.AnimeDuelScript
app.start('climb');drain()
assert(app.climb.status:find('Fewer than four allowed',1,true),app.climb.status)
for _,call in ipairs(calls)do assert(call[1]~='ClimbPickStart','must never fill a team with a banned card')end
app.destroy()
''')

for inventory in ["{'a','b','c','d'}", "{a=1,b=1,c=1,d=1}"]:
    string_inventory=mock.replace("packs={draft=1},team={'a','b','c','d'}", "packs={draft=1},cards="+inventory+",team={'a','b','c','d'}")
    run_case('Draft Run accepts authoritative team with inventory '+inventory,string_inventory,checks)

state_first=mock.replace(
 "event.OnClientEvent:Fire('Result',result)\n   run.fighting=nil;emit()",
 "run.fighting=nil;emit()\n   event.OnClientEvent:Fire('Result',result)"
).replace(
 "if name=='State' then emit();return true,snapshot()",
 "if name=='State' then if fightIndex==0 then emit() end;return true"
)
run_case('Draft Run handles end State before Result without requiring another State',state_first,checks)

broken_ui=mock+r'''
schedule(3,function()
 for _,obj in ipairs(objects)do
  if obj.ClassName=='TextBox' then obj.IsFocused=function()error('UI widget failure')end end
 end
end)
'''
run_case('UI rendering errors cannot abort the Draft Run worker',broken_ui,checks.replace('assert(#pending==1','assert(#pending==2'))

# Preferred cards get a 25% score bonus, applied identically to picks and team slots.
preferred=climb_fixture.replace("start={'weak','tank','carry','mid','other','less'}", "start={'weak','tank','carry','mid','other','less','elf_mage'}").replace(
 "a[1]=='carry' and a[2]=='mid' and a[3]=='tank' and a[4]=='other'",
 "a[1]=='carry' and a[2]=='elf_mage' and a[3]=='mid' and a[4]=='tank'"
).replace("gold={200,100}", "gold={200,100},elf_mage={25,50}")
run_case('preferred Elf Mage outranks a slightly stronger non-preferred starting card',preferred,climb_checks)

for base in ['limitless_sorcerer','curse_king','elf_mage','gone','slime','brother','red_hair']:
    for suffix in ['','_gold','_rainbow','_secret']:
        card=base+suffix
        fixture=preferred.replace('elf_mage',card)
        run_case('preferred selection: '+card,fixture,climb_checks)

ban_samurai=climb_fixture.replace(
 "start={'weak','tank','carry','mid','other','less'}",
 "start={'samurai_lost_man','samurai_lost_man_gold','samurai_lost_man_rainbow','samurai_lost_man_secret','weak','tank','carry','mid','other','less'}"
).replace("cards={'weaker','gold','weak'}", "cards={'samurai_lost_man_secret','gold','samurai_lost_man_gold'}").replace("cards={'weaker','weak'}", "cards={'samurai_lost_man','samurai_lost_man_rainbow'}")
run_case('Samurai Lost Man banned at all borders in starts and offers',ban_samurai,climb_checks)

normal_lost=climb_fixture.replace("'carry'", "'lost_man'").replace('carry={100,20}','lost_man={100,20}')
run_case('normal Lost Man remains eligible',normal_lost,climb_checks)

# At raw score 45, +25% would miss the initial team; +50% must beat score 60.
for suffix in ['','_gold','_rainbow','_secret']:
    teen='teen_saski'+suffix
    fixture=preferred.replace('elf_mage',teen).replace(teen+'={25,50}',teen+'={20,50}')
    run_case('Teen Saski gets +50% rather than +25%: '+teen,fixture,climb_checks)

run_case('Stop Draft leaves Climb running and resolving replacement/skip offers',climb_fixture,r'''
local app=env.AnimeDuelScript
app.start('draft');app.start('climb')
assert(app.worker and app.climb.worker and app.enabled and app.climb.enabled)
schedule(.2,function()
 app.stop('draft')
 assert(app.climb.enabled and app.climb.worker,'Draft Stop must not stop Climb')
end)
drain()
assert(climbStarts==2 and #climbPicks==2,'Climb must replace, skip and restart while Draft is stopped')
assert(fightIndex==0,'stopped Draft did not fight')
assert(app.climb.status=='Stopped',app.climb.status)
app.destroy()
''')

run_case('Stop Climb leaves Draft recovery and boss progression running',climb_fixture,r'''
local app=env.AnimeDuelScript
app.start('climb');app.start('draft')
schedule(.2,function()
 app.stop('climb')
 assert(app.enabled and app.worker,'Climb Stop must not stop Draft')
end)
drain()
assert(fightIndex==15 and startCount==2,'Draft must complete its normal recovery/boss loop')
assert(climbStarts==0,'stopped Climb must not start')
assert(app.status=='Stopped',app.status)
app.destroy()
''')

concurrent=climb_fixture.replace("if climbStarts==2 then env.AnimeDuelScript.stop();return true end", "if climbStarts==2 then env.AnimeDuelScript.stop('climb');return true end")
concurrent=concurrent.replace("assert(calls[#calls-2][1]=='AutoTeam' and calls[#calls-1][1]=='State','missing AutoTeam preparation')",'').replace("if fightIndex==1 or expected[fightIndex-1][2] then assert(lastOpen==#calls-3,'missing Open after pack reward') end",'')
concurrent+=r'''
local realInvoke=action.InvokeServer
local inFlight=0
function action:InvokeServer(...)
 inFlight=inFlight+1
 assert(inFlight==1,'remote requests must be serialized')
 task.wait(.05)
 local result=table.pack(realInvoke(self,...))
 inFlight=inFlight-1
 return table.unpack(result,1,result.n)
end
'''
run_case('both controllers progress independently with a single in-flight remote request',concurrent,r'''
local app=env.AnimeDuelScript
app.start('draft');app.start('climb')
drain()
assert(fightIndex==15 and climbStarts==2 and #climbPicks==2,'both modes must progress')
assert(app.wins==13 and app.losses==2 and app.clears==1,'Draft counters stay independent')
assert(not app.worker and not app.climb.worker)
assert(app.status=='Stopped' and app.climb.status=='Stopped',app.status..' / '..app.climb.status)
app.destroy()
''')

run_case('loading updated script waits for active old Climb worker and replaces its UI',climb_fixture,r'''
local old=env.AnimeDuelScript
old.start('climb')
schedule(.2,function()loadScript()end)
drain()
local current=env.AnimeDuelScript
assert(current~=old,'must replace old app, not merely stop and return')
assert(not old.alive and old.Root.Parent==nil,'old UI must be destroyed')
assert(current.build=='studio-v18-native-clean','visible versioned build')
assert(not current.worker and not current.climb.worker,'upgrade loads clean controllers')
current.destroy()
''')

for mode in ['draft','climb']:
    caption='STOP DRAFT' if mode=='draft' else 'STOP CLIMB'
    run_case('actual '+caption+' UI button stops only its own controller',climb_fixture,r'''
local app=env.AnimeDuelScript
app.start('draft');app.start('climb')
schedule(.2,function()
 local found=false
 for _,obj in ipairs(objects)do
  if obj.ClassName=='TextButton' and obj.Text=='CAPTION' then obj.MouseButton1Click:Fire();found=true;break end
 end
 assert(found,'missing distinct Stop button')
 if 'MODE'=='draft' then
  assert(not app.enabled and app.climb.enabled,'Draft button must not stop Climb')
 else
  assert(app.enabled and not app.climb.enabled,'Climb button must not stop Draft')
 end
end)
drain()
if 'MODE'=='draft' then assert(#climbPicks==2,'Climb still replaces and skips')
else assert(fightIndex==15,'Draft still progresses') end
app.destroy()
'''.replace('CAPTION',caption).replace('MODE',mode))

story_mock=r'''
local storyCalls={}
local storyRemote={}
function storyRemote:InvokeServer(...)
 local args=table.pack(...)
 assert(args.n==2,'StoryFight must receive exactly stage ID and difficulty')
 table.insert(storyCalls,{id=args[1],difficulty=args[2],at=now})
 if #storyCalls==3 then schedule(.1,function()env.AnimeDuelScript.stop('story')end)end
 if #storyCalls==1 then return false,'A fight is already running' end
 return true
end
remotes.FindFirstChild=function(_,name)assert(name=='StoryFight');return storyRemote end
'''
run_case('StoryFight uses captured arguments, spaces requests and continues after busy rejection',mock+story_mock,r'''
local app=env.AnimeDuelScript
app.start('story');app.start('story');drain()
assert(#storyCalls==3 and app.story.requests==3)
for i,c in ipairs(storyCalls)do
 assert(c.id=='toy_kingdom_boss' and c.difficulty=='Nightmare')
 if i>1 then assert(c.at-storyCalls[i-1].at>=1.5,'request interval')end
end
assert(not app.story.worker and app.story.status=='Stopped',app.story.status)
assert(#calls==0,'Story mode must never invoke DraftAction')
app.destroy()
''')

rotation=story_mock.replace('#storyCalls==3','#storyCalls==6')
run_case('selected Story bosses rotate through the five IDs from StoryConfig',mock+rotation,r'''
local app=env.AnimeDuelScript
for _,key in ipairs({'purple_forest','android_games','hollow_world','purple_town','toy_kingdom'})do app.config['story_'..key]=true end
app.config.storyDifficulty='Hard';app.config.storyInterval=3
app.start('story');drain()
local expected={'purple_forest_boss','android_games_boss','hollow_world_boss','purple_town_boss','toy_kingdom_boss','purple_forest_boss'}
assert(#storyCalls==#expected)
for i,c in ipairs(storyCalls)do assert(c.id==expected[i] and c.difficulty=='Hard')end
app.destroy()
''')

run_case('Story mode with no selected bosses sends no request',mock+story_mock,r'''
local app=env.AnimeDuelScript
app.config.story_toy_kingdom=false
app.start('story')
schedule(2,function()assert(app.story.status=='Select at least one Story boss');app.stop('story')end)
drain();assert(#storyCalls==0)
app.destroy()
''')

transport=story_mock.replace("if #storyCalls==1 then return false,'A fight is already running' end", "error('Response lost')")
run_case('uncertain StoryFight transport errors stop without repeating a mutation',mock+transport,r'''
local app=env.AnimeDuelScript
app.start('story');drain()
assert(#storyCalls==1 and not app.story.worker)
assert(app.story.status:find('response lost',1,true),app.story.status)
app.destroy()
''')

run_case('Boss toggle leaves both Draft and Climb workers running',concurrent+story_mock,r'''
local app=env.AnimeDuelScript
app.start('draft');app.start('climb');app.start('story')
schedule(.2,function()
 for _,obj in ipairs(objects)do
  if obj.ClassName=='TextLabel' and obj.Text=='Auto Start Fight' then
   for _,button in ipairs(obj.Parent:GetChildren()) do if button.ClassName=='TextButton' then button.MouseButton1Click:Fire();break end end
   break
  end
 end
 assert(not app.story.enabled and app.enabled and app.climb.enabled,'mode isolation')
end)
drain()
assert(fightIndex==15 and #climbPicks==2,'Draft and Climb keep progressing')
assert(#storyCalls==1,'Story stops further start attempts')
app.destroy()
''')

run_case('Story selections, difficulty and request interval persist in profiles',mock+file_mock,r'''
local app=env.AnimeDuelScript
app.config.story_purple_town=true;app.config.storyDifficulty='Medium';app.config.storyInterval=7
app.config.mode='story';assert(app.setAutoProfile('Bosses'))
app.destroy();loadScript();app=env.AnimeDuelScript
assert(app.config.mode=='story' and app.config.story_purple_town)
assert(app.config.storyDifficulty=='Medium' and app.config.storyInterval==1.5)
assert(not app.story.worker,'loading settings does not start unless opted in')
app.destroy()
''')

cooldown_mock=story_mock.replace("return false,'A fight is already running'", "return {ok=false,reason='Ready in 9m 53s'}")
run_case('observed 9m 53s response sets a 593-second cooldown and prevents early requests',mock+cooldown_mock,r'''
local app=env.AnimeDuelScript
app.start('story')
schedule(1,function()
 local deadline=app.story.cooldowns['toy_kingdom_boss:Nightmare']
 assert(deadline==593,'exact parsed cooldown')
end)
schedule(592,function()assert(#storyCalls==1,'no requests before server cooldown expires')end)
drain()
assert(#storyCalls==3 and storyCalls[2].at>=1.593)
assert(storyCalls[3].at-storyCalls[2].at>=1.5,'10 second cadence after cooldown')
app.destroy()
''')

run_case('a cooling boss is skipped while other selected bosses are attempted',mock+cooldown_mock,r'''
local app=env.AnimeDuelScript
app.config.story_purple_town=true
app.start('story');drain()
assert(storyCalls[1].id=='purple_town_boss')
assert(storyCalls[2].id=='toy_kingdom_boss' and storyCalls[3].id=='toy_kingdom_boss')
assert(storyCalls[2].at>=1.5 and storyCalls[3].at>=3)
app.destroy()
''')

run_case('cooldown is keyed by both boss and difficulty',mock+cooldown_mock,r'''
local app=env.AnimeDuelScript
app.start('story')
schedule(2,function()app.config.storyDifficulty='Easy'end)
schedule(12,function()
 assert(#storyCalls>=2 and storyCalls[2].difficulty=='Easy')
 assert(app.story.cooldowns['toy_kingdom_boss:Nightmare']==593)
 app.stop('story')
end)
drain();app.destroy()
''')

for reason,seconds in [('Ready in 59s',59),('Ready in 10m',600),('Ready in 1h 2m 3s',3723),('Ready in 0s',0),('Ready in 9m53s',593),('Loading 9m 53s',None),('Ready in soon',None),('Ready in 9m nonsense',None)]:
    fixture=story_mock.replace("return false,'A fight is already running'", "return {ok=false,reason="+repr(reason)+"}")
    expected='nil' if seconds is None else str(seconds)
    run_case('cooldown parsing: '+reason,mock+fixture,r'''
local app=env.AnimeDuelScript
app.start('story')
schedule(.2,function()
 assert(app.story.cooldowns['toy_kingdom_boss:Nightmare']==EXPECTED,'cooldown parsing')
 app.stop('story')
end)
drain();app.destroy()
'''.replace('EXPECTED',expected))

run_case('Stop and Start preserve the learned cooldown in the same session',mock+cooldown_mock,r'''
local app=env.AnimeDuelScript
app.start('story')
schedule(2,function()app.stop('story')end)
schedule(3,function()app.start('story')end)
schedule(5,function()assert(#storyCalls==1);assert(app.story.cooldowns['toy_kingdom_boss:Nightmare']==593);app.stop('story')end)
drain();app.destroy()
''')


run_case('Update 4 fallback includes Body Devil without changing old boss defaults',mock+story_mock,r'''
local app=env.AnimeDuelScript
assert(app.config.story_clover_capital==false,'new boss is opt-in')
app.config.story_toy_kingdom=false;app.config.story_clover_capital=true
app.start('story');drain()
assert(#storyCalls==3)
for _,c in ipairs(storyCalls)do assert(c.id=='clover_capital_boss' and c.difficulty=='Nightmare')end
app.destroy()
''')

live_story=r'''
local storyModule={}
local catalog={Maps={{Id='clover_capital',Name='Clover Capital',Stages={
 {Id='clover_capital_4',Npc='Flame Lioness',Stage=4,Boss=false},
 {Id='clover_capital_boss',Npc='Body Devil',Stage=5,Boss=true}},
 Secret={Id='clover_capital_secret',Npc='Time Sage King',Secret=true}}}}
RS.FindFirstChild=function(_,name)
 assert(name=='Shared')
 return {FindFirstChild=function(_,target,recursive)assert(target=='StoryConfig' and recursive);return storyModule end}
end
local function require(module)assert(module==storyModule);return catalog end
'''
run_case('live StoryConfig uses boss flags and finds World 6 stage 5',mock+story_mock+live_story,r'''
local app=env.AnimeDuelScript
app.config.story_clover_capital=true
app.start('story');drain()
for _,c in ipairs(storyCalls)do assert(c.id=='clover_capital_boss','must not treat stage 4 as boss')end
app.destroy()
''')
run_case('Secret bosses use the Secret difficulty from StoryConfig',mock+story_mock+live_story,r'''
local app=env.AnimeDuelScript
app.config.story_clover_capital_secret=true
app.start('story');drain()
for _,c in ipairs(storyCalls)do assert(c.id=='clover_capital_secret' and c.difficulty=='Secret')end
app.destroy()
''')

run_case('exact Online library keeps inline rows, gradients, slider and mobile sidebar',mock,r'''
local app=env.AnimeDuelScript
local sidebar,window,slider,gradient,action
for _,obj in ipairs(objects)do
 if obj.Name=='Sidebar' then sidebar=obj end
 if obj.Name=='Window' then window=obj end
 if obj.Name=='TransparencySlider' then slider=obj end
 if obj.Name=='OriginTextGradient' then gradient=obj end
 if obj.ClassName=='TextButton' and obj.Text=='START DRAFT' then action=obj end
end
assert(sidebar and window.ClassName=='CanvasGroup' and slider and gradient,'exact Online library components')
assert(action.Position.X.Scale==0 and action.Size.X.Scale==.64,'paired primary action placement')
assert(action.Parent.Size.Y.Offset==49,'reference compact row height')
Workspace.CurrentCamera.ViewportSize=Vector2.new(390,844)
Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Fire()
assert(sidebar.ScrollingDirection==Enum.ScrollingDirection.X,'horizontal mobile navigation')
assert(window.Size.X.Offset<=374,'fits mobile viewport')
app.destroy()
''')

run_case('reference searchable multi-select changes boss selection without starting a mode',mock,r'''
local app=env.AnimeDuelScript
local picker,search,menu
for _,obj in ipairs(objects)do
 if obj.ClassName=='TextButton' and obj.Text=='1 selected  ▾' then picker=obj end
 if obj.Name=='DropdownSearch' then search=obj end
 if obj.Name=='DropdownMenu' then menu=obj end
end
assert(picker and search and menu)
picker.MouseButton1Click:Fire();assert(menu.Visible)
search.Text='Body Devil';search:GetPropertyChangedSignal('Text'):Fire()
local body
for _,obj in ipairs(objects)do
 if obj.ClassName=='TextButton' and obj.Parent and obj.Text=='Body Devil' then body=obj end
end
assert(body,'search returns Body Devil')
body.Activated:Fire()
assert(app.config.story_clover_capital and menu.Visible,'multi-select stays open')
assert(not app.worker and not app.story.worker and #calls==0,'UI selection has no gameplay side effects')
app.destroy()
''')

run_case('reference difficulty dropdown preserves selected server difficulty',mock,r'''
local app=env.AnimeDuelScript
local opener,menu,search
for _,obj in ipairs(objects)do
 if obj.ClassName=='TextButton' and obj.Text=='Nightmare  ▾' then opener=obj end
 if obj.Name=='DropdownMenu' then menu=obj end
 if obj.Name=='DropdownSearch' then search=obj end
end
assert(opener and menu and search)
opener.Activated:Fire();assert(menu.Visible)
search.Text='med';search:GetPropertyChangedSignal('Text'):Fire()
local medium
for _,obj in ipairs(objects)do if obj.Parent and obj.ClassName=='TextButton' and obj.Text=='Medium' then medium=obj end end
assert(medium);medium.Activated:Fire()
assert(app.config.storyDifficulty=='Medium' and not menu.Visible)
app.destroy()
''')

run_case('new themes and window geometry persist through profiles',mock+file_mock,r'''
local app=env.AnimeDuelScript
app.config.theme='Ocean';app.config.windowW=900;app.config.windowH=620
app.config.windowX=.25;app.config.windowY=.2
assert(app.setAutoProfile('OnlineUI'))
app.destroy();loadScript();app=env.AnimeDuelScript
assert(app.config.theme=='Ocean' and app.config.windowW==900 and app.config.windowH==620)
assert(app.config.windowX==.25 and app.config.windowY==.2)
local window
for _,obj in ipairs(objects)do if obj.Name=='Window' and obj.Parent==app.Root then window=obj end end
assert(window.Size.X.Offset==900 and window.Size.Y.Offset==620,'restored window layout')
app.destroy()
''')

# Structural evidence from the uploaded Update 4 place, not guessed stage IDs.
place=Path(__file__).resolve().parents[2]/'new_place'
if place.exists():
    story=(place/'118_38872.lua').read_text()
    math_source=(place/'118_38873.lua').read_text()
    draft=(place/'118_38832.lua').read_text()
    assert 'clover_capital_boss' in story and 'Body Devil' in story
    assert 'STAGES_BY_MAP = {[6] = 5}' in math_source
    for field in ['ClimbStats','ClimbPickStart','ClimbPick','OFFER_EVERY = 10']:
        assert field in draft
    print('PASS: uploaded Update 4 module contracts and Clover Capital boss verified')

run_case('fast Story attempts retry a busy response within about two seconds',mock+story_mock,r'''
local app=env.AnimeDuelScript
app.start('story');drain()
assert(#storyCalls==3)
assert(storyCalls[2].at-storyCalls[1].at>=1.5 and storyCalls[2].at-storyCalls[1].at<2.2,'fast retry')
assert(storyCalls[3].at-storyCalls[2].at>=1.5,'paced requests')
app.destroy()
''')
slow=story_mock.replace("return false,'A fight is already running'", "return false,'Slow down.'")
run_case('server Slow down backs off for five seconds',mock+slow,r'''
local app=env.AnimeDuelScript
app.start('story');drain()
assert(storyCalls[2].at-storyCalls[1].at>=5,'respect server throttling')
assert(storyCalls[3].at-storyCalls[2].at>=1.5)
app.destroy()
''')

run_case('status cards show full messages and hide unselected empty cooldown rows',mock,r'''
local app=env.AnimeDuelScript
local statusCard,bodyRow
for _,obj in ipairs(objects)do
 if obj.ClassName=='TextLabel' and obj.Text==app.status and obj.Parent.Size.Y.Offset==88 then statusCard=obj end
 if obj.ClassName=='TextLabel' and obj.Text=='Body Devil' then bodyRow=obj.Parent end
end
assert(statusCard and statusCard.TextWrapped and statusCard.TextTruncate==Enum.TextTruncate.None,'full status text')
assert(statusCard.Parent.Size.Y.Offset==88,'spacious status card')
assert(bodyRow and not bodyRow.Visible,'only selected or cooling bosses fill cooldown view')
app.destroy()
''')

dungeon_mock=r'''
local de={OnClientEvent=signal()}
local dv={coins=0,unlocked={Normal={ok=true},Hard={ok=true},Nightmare={ok=false,why='Locked'}}}
local dcalls={};local starts=0;local continuations=0;local cashouts=0
local function dstate()de.OnClientEvent:Fire('State',dv)end
local dr={}
function dr:InvokeServer(name,payload)
 dcalls[#dcalls+1]={name,payload}
 if name=='Start' then
  starts=starts+1
  if starts==2 then env.AnimeDuelScript.stop('dungeon');return true end
  assert(#payload.team==4 and #payload.reserves==2 and payload.difficulty=='Normal')
  local cards={};local hp={}
  for _,id in ipairs(payload.team)do cards[#cards+1]=id;hp[id]=.9 end
  for _,id in ipairs(payload.reserves)do cards[#cards+1]=id;hp[id]=.9 end
  dv.run={id=starts,room=1,phase='fight',cards=cards,team=payload.team,hp=hp,fighting=false,doors={},cleared=0}
  dstate();return true
 elseif name=='Enter' then
  assert(dv.run and payload==nil,'Enter uses nil payload');dv.entered=dv.run.id;return true
 elseif name=='Fight' then
  assert(dv.entered==dv.run.id,'Enter must precede Fight')
  assert(payload==dv.run.room and dv.run.phase=='fight' and not dv.run.fighting,'no duplicate Fight')
  dv.run.fighting=true;dv.battle=true;dstate()
  schedule(1,function()
   local r=dv.run;r.fighting=false;dv.battle=false;r.cleared=r.room
   de.OnClientEvent:Fire('Result',{result='Victory',room=r.room})
   if r.room==20 then dv.last={run=r.id,reason='cleared'};dv.run=nil
   elseif r.room%5==0 then r.phase='checkpoint';r.doors={}
   else r.phase='doors';r.doors={{kind='FORTUNE'},{kind='TREASURE'},{kind='RECOVERY'}} end
   dstate()
  end)
  return true
 elseif name=='Door' then
  assert(dv.run.phase=='doors')
  local path=env.AnimeDuelScript.config.dungeonPath
  local wanted=path=='Loot' and 1 or (path=='Safe' and 3 or 2)
  assert(payload==wanted,'door policy '..path..': '..tostring(payload))
  dv.run.room=dv.run.room+1;dv.run.phase='fight';dv.run.doors={};dstate();return true
 elseif name=='Continue' then
  assert(dv.run.phase=='checkpoint');continuations=continuations+1
  dv.run.phase='doors';dv.run.doors={{kind='FORTUNE'},{kind='TREASURE'},{kind='RECOVERY'}};dstate();return true
 elseif name=='CashOut' then
  assert(dv.run.phase=='checkpoint');cashouts=cashouts+1
  dv.last={run=dv.run.id,reason='cashout'};dv.run=nil;dstate();return true
 end
 error('unobserved Dungeon action '..name)
end
remotes.FindFirstChild=function(_,name)
 if name=='DungeonEvent' then return de elseif name=='DungeonAction' then return dr end
 return nil
end
'''
for path in ['Balanced','Loot','Safe']:
 run_case('Dungeon '+path+' runs 20 rooms via captured actions and event State',mock+dungeon_mock,r'''
local app=env.AnimeDuelScript
app.config.dungeonPath='PATH';app.config.dungeonWalk=false;app.start('dungeon')
schedule(.1,dstate);drain()
assert(starts==2 and continuations==3 and cashouts==0)
assert(not app.dungeon.worker and app.dungeon.status=='Stopped',app.dungeon.status)
local fights=0;for _,c in ipairs(dcalls)do if c[1]=='Fight' then fights=fights+1 end end
assert(fights==20,'one Fight per room')
app.destroy()
'''.replace('PATH',path))

run_case('Dungeon cashout at room 5 then starts again',mock+dungeon_mock,r'''
local app=env.AnimeDuelScript
app.config.dungeonCashOut=5;app.config.dungeonWalk=false;app.start('dungeon');schedule(.1,dstate);drain()
assert(cashouts==1 and continuations==0 and starts==2)
local fights=0;for _,c in ipairs(dcalls)do if c[1]=='Fight' then fights=fights+1 end end
assert(fights==5);app.destroy()
''')

unconfirmed_dungeon=dungeon_mock.replace("dstate();return true\n elseif name=='Enter'", "return true\n elseif name=='Enter'")
run_case('Dungeon Start without State confirmation stops without resending',mock+unconfirmed_dungeon,r'''
local app=env.AnimeDuelScript
app.config.dungeonWalk=false;app.start('dungeon');drain()
assert(starts==1 and app.dungeon.status:find('not confirmed',1,true),app.dungeon.status)
app.destroy()
''')

run_case('Dungeon locks and profile fields are validated independently',mock+file_mock+dungeon_mock,r'''
local app=env.AnimeDuelScript
app.config.dungeonDifficulty='Nightmare';app.config.dungeonWalk=false;dstate();app.start('dungeon');drain()
assert(starts==0 and app.dungeon.status:find('Locked',1,true))
app.config.dungeonDifficulty='Hard';app.config.dungeonPath='Safe';app.config.dungeonCashOut=10
assert(app.setAutoProfile('Dungeon'))
app.destroy();loadScript();app=env.AnimeDuelScript
assert(app.config.dungeonDifficulty=='Hard' and app.config.dungeonPath=='Safe' and app.config.dungeonCashOut==10)
app.destroy()
''')

run_case('STOP DUNGEON does not stop Draft Run',mock+dungeon_mock,r'''
local app=env.AnimeDuelScript
app.start('draft');app.config.dungeonWalk=false;app.start('dungeon');dstate()
schedule(.2,function()app.stop('dungeon');assert(app.enabled,'independent Stop')end)
drain()
assert(fightIndex==15 and not app.dungeon.worker)
app.destroy()
''')

for path in ['Balanced','Loot','Safe']:
    hurt=dungeon_mock.replace('hp[id]=.9','hp[id]=.59').replace("local wanted=path=='Loot' and 1 or (path=='Safe' and 3 or 2)","local wanted=path=='Loot' and 1 or 3")
    run_case('Dungeon '+path+' chooses correctly when average HP is under 60 percent',mock+hurt,r'''
local app=env.AnimeDuelScript
app.config.dungeonPath='PATH';app.config.dungeonWalk=false;app.start('dungeon');schedule(.1,dstate);drain()
assert(starts==2 and app.dungeon.status=='Stopped',app.dungeon.status)
if 'PATH'=='Safe' then assert(cashouts==1,'Safe banks at checkpoint while injured')end
app.destroy()
'''.replace('PATH',path))

walk_mock=r'''
local vectorMeta={}
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},vectorMeta)end
vectorMeta.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vectorMeta.__index=function(v,k)if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end end
local character={};local root={Position=vec(50,0,0),Parent=character}
local teleports={};local rejectTeleport=false
CFrame={new=function(x,y,z)return {Position=vec(x,y,z)}end}
setmetatable(root,{__newindex=function(t,k,v)
 if k=='CFrame' then teleports[#teleports+1]=v.Position;if not rejectTeleport then t.Position=v.Position end
 else rawset(t,k,v)end
end})
local moves={};local portalTransfers=0
local humanoid={Health=100,MoveTo=function(_,position)
 moves[#moves+1]=position
 if position.X==500 and position.Z==-20 then root.Position=vec(1250,0,0);portalTransfers=portalTransfers+1
 else root.Position=position end
end}
function character:FindFirstChild(name)if name=='HumanoidRootPart' then return root end end
function character:FindFirstChildOfClass(name)if name=='Humanoid' then return humanoid end end
player.Character=character
local guards={}
local function guardPosition(room)return vec(room*50+(room>=11 and 700 or 0),0,0)end
for i=1,20 do
 local number=i
 local guard={Parent=true,IsA=function(_,kind)return kind=='Model'end,
  GetAttribute=function(_,key)if key=='DungeonRoom' then return number end end,
  FindFirstChild=function(_,key)if key=='HumanoidRootPart' then return {Position=guardPosition(number)}end end,
  GetPivot=function()return {Position=guardPosition(number)}end}
 guards[#guards+1]=guard
end
local folder={GetDescendants=function()return guards end}
local portal={IsA=function()return false end,GetPivot=function()return {Position=vec(500,0,-20)}end}
local area={FindFirstChild=function(_,name)if name=='NextAreaPortal' then return portal end end}
local map={FindFirstChild=function(_,name)if name=='Area 1' then return area end end}
Workspace.FindFirstChild=function(_,name)
 if name=='Dungeon Guards' then return folder elseif name=='Dungeon Run' then return map end
end
local originalDungeon=dr.InvokeServer
function dr:InvokeServer(name,payload)
 if name=='Fight' then assert((root.Position-guardPosition(payload)).Magnitude<=18,'Fight must wait for guard proximity')end
 return originalDungeon(self,name,payload)
end
'''
run_case('Dungeon teleports to each guard across both areas before sending Fight',mock+dungeon_mock+walk_mock,r'''
local app=env.AnimeDuelScript
assert(app.config.dungeonWalk==true,'auto teleport on by default')
app.start('dungeon');schedule(.1,dstate);drain()
assert(starts==2 and portalTransfers==0,'teleport reaches all 20 rooms without walking to portal')
assert(#teleports>15 and #moves==0,'teleports performed without MoveTo')
assert(app.dungeon.status=='Stopped',app.dungeon.status)
app.destroy()
''')

blocked_walk=walk_mock+"\nrejectTeleport=true\n"
run_case('Stop cancels rejected teleports without sending Fight for a distant room',mock+dungeon_mock+blocked_walk,r'''
local app=env.AnimeDuelScript
app.start('dungeon');schedule(.1,dstate)
schedule(4,function()app.stop('dungeon')end)
drain()
for _,call in ipairs(dcalls)do if call[1]=='Fight' then assert(call[2]==1,'never fight room 2 while far away')end end
assert(not app.dungeon.worker and app.dungeon.walking==nil,'movement cancelled')
app.destroy()
''')

# Ensure sub-models with no DungeonRoom attribute cannot be selected as targets.
missing_guard=walk_mock.replace('guards[#guards+1]=guard', 'if number~=2 then guards[#guards+1]=guard end')
run_case('missing room guard pauses instead of teleporting to a different NPC',mock+dungeon_mock+missing_guard,r'''
local app=env.AnimeDuelScript
app.start('dungeon');schedule(.1,dstate)
schedule(5,function()app.stop('dungeon')end);drain()
for _,call in ipairs(dcalls)do if call[1]=='Fight' then assert(call[2]==1)end end
app.destroy()
''')

run_case('Dungeon starts directly without opening an NPC or receiving an initial State',mock+dungeon_mock,r'''
local app=env.AnimeDuelScript
app.config.dungeonWalk=false
assert(app.dungeon.view==nil)
app.start('dungeon');drain()
assert(starts==2 and continuations==3,'starts, clears and repeats from server Start events')
assert(dcalls[1][1]=='Start','first action directly starts Dungeon')
assert(app.dungeon.status=='Stopped',app.dungeon.status)
app.destroy()
''')

rejected_start=dungeon_mock+r'''
local real=dr.InvokeServer
function dr:InvokeServer(name,payload)
 if name=='Start' then starts=starts+1;return false,'Selected card not owned' end
 return real(self,name,payload)
end
'''
run_case('rejected direct Start without State reports server reason and does not spam',mock+rejected_start,r'''
local app=env.AnimeDuelScript
app.start('dungeon');drain()
assert(starts==1,'no repeat of rejected bootstrap')
assert(app.dungeon.status:find('Selected card not owned',1,true),app.dungeon.status)
assert(not app.dungeon.worker)
app.destroy()
''')

run_case('Dungeon Enter rejection stops before teleport or Fight',mock+dungeon_mock+r'''
local original=dr.InvokeServer
function dr:InvokeServer(name,payload)
 if name=='Enter' then return false,'Entry unavailable' end
 return original(self,name,payload)
end
''',r'''
local app=env.AnimeDuelScript;app.config.dungeonWalk=false
app.start('dungeon');drain()
assert(app.dungeon.status:find('Entry unavailable',1,true),app.dungeon.status)
for _,c in ipairs(dcalls) do assert(c[1]~='Fight') end
app.destroy()
''')

run_case('Dungeon history retains ten runs with deduplicated server rewards and elapsed time',mock+dungeon_mock,r'''
local app=env.AnimeDuelScript
for i=1,12 do
 dv.run={id='h'..i,diff='Normal',room=1};dstate()
 schedule(2,function()
  dv.last={run='h'..i,diff='Normal',reason='cleared',cleared=20,coins=42,items={potion=2},chests={plunder=1},cards={{name='Elf Mage'}}}
  dv.run=nil;dstate();dstate()
 end)
 drain()
end
assert(#app.dungeon.history==10)
local latest=app.dungeon.history[1]
assert(latest.run=='h12' and app.dungeon.history[10].run=='h3')
assert(latest.seconds>=2 and latest.reason=='cleared' and latest.cleared==20)
for _,text in ipairs({'42 Shards','potion x2','plunder x1','Elf Mage'}) do assert(latest.rewards:find(text,1,true),latest.rewards) end
app.destroy()
''')

enter_busy=dungeon_mock+r'''
local original=dr.InvokeServer
local attempts={}
function dr:InvokeServer(name,payload)
 if name=='Enter' then
  attempts[#attempts+1]=os.clock()
  if #attempts<=2 then return false,'Already teleporting.' end
 end
 return original(self,name,payload)
end
'''
run_case('Dungeon waits and retries explicit Already teleporting rejection before fighting',mock+enter_busy,r'''
local app=env.AnimeDuelScript;app.config.dungeonWalk=false
app.start('dungeon');drain()
assert(#attempts==3,'retry rejected Enter until accepted')
assert(attempts[2]-attempts[1]>=1.5 and attempts[3]-attempts[2]>=1.5,'paced entry retries')
assert(starts==2 and app.dungeon.status=='Stopped',app.dungeon.status)
assert(#app.dungeon.history==1,'run completed after entry recovered')
app.destroy()
''')
run_case('Stop cancels Dungeon while waiting for server teleport without starting a fight',mock+enter_busy,r'''
local app=env.AnimeDuelScript;app.config.dungeonWalk=false
app.start('dungeon');schedule(.5,function()app.stop('dungeon')end);drain()
assert(#attempts==1 and not app.dungeon.worker)
for _,c in ipairs(dcalls)do assert(c[1]~='Fight')end
app.destroy()
''')

existing_run=dungeon_mock+r'''
local cards={'a','b','c','d','e','f'};local hp={}
for _,id in ipairs(cards) do hp[id]=.9 end
starts=1
dv.run={id=1,diff='Normal',room=7,phase='fight',cards=cards,team=cards,hp=hp,fighting=false,doors={},cleared=6}
local original=dr.InvokeServer
local rejectedStarts=0;local resumeEnters=0
function dr:InvokeServer(name,payload)
 if name=='Start' and dv.run then rejectedStarts=rejectedStarts+1;return false,'You already have a run going.' end
 if name=='Enter' then
  resumeEnters=resumeEnters+1
  local result=original(self,name,payload)
  schedule(.5,dstate)
  return result
 end
 return original(self,name,payload)
end
'''
run_case('Dungeon discovers existing server run through Enter and resumes room 7 without starting over',mock+existing_run,r'''
local app=env.AnimeDuelScript;app.config.dungeonWalk=false
assert(app.dungeon.view==nil)
app.start('dungeon');drain()
assert(rejectedStarts==1 and resumeEnters==1,'one rejected Start followed by one Enter')
local firstFight=nil
for _,c in ipairs(dcalls)do if c[1]=='Fight' then firstFight=firstFight or c[2]end end
assert(firstFight==7,'resume existing room instead of room one')
assert(starts==2 and app.dungeon.status=='Stopped',app.dungeon.status)
assert(#app.dungeon.history==1)
app.destroy()
''')
run_case('Missing existing-run State after Enter pauses without repeating Start or Fight',mock+existing_run+r'''
function dr:InvokeServer(name,payload)
 if name=='Start' then rejectedStarts=rejectedStarts+1;return false,'You already have a run going.' end
 if name=='Enter' then resumeEnters=resumeEnters+1;return true end
 error('Must not fight without State')
end
''',r'''
local app=env.AnimeDuelScript;app.config.dungeonWalk=false
app.start('dungeon');drain()
assert(rejectedStarts==1 and resumeEnters==1)
assert(app.dungeon.status:find('no active run State',1,true),app.dungeon.status)
app.destroy()
''')

collection_mock=r'''
local cardModule={}
local cardDefs={};local owned={}
for i=1,20 do
 local id='card_'..i
 cardDefs[id]={Name='Hero '..i,Variant=i%2==0 and 'Gold' or 'Basic',Image='rbxassetid://'..i,Damage=i*100,Health=i*50}
 owned[id]=i==20 and 0 or i
end
cardDefs.card_1.Name='Elf Mage';cardDefs.card_2.Name='Elf Mage'
local shared={FindFirstChild=function(_,name)if name=='CardDefinitions' then return cardModule end end}
RS.FindFirstChild=function(_,name)if name=='Shared' then return shared end end
local function require(module)assert(module==cardModule);return cardDefs end
local snapshot={Cards=owned};local snapshotCalls=0
local sr={InvokeServer=function()snapshotCalls=snapshotCalls+1;return snapshot end}
local ce={OnClientEvent=signal()}
remotes.FindFirstChild=function(_,name)
 if name=='GetSnapshot' then return sr elseif name=='StateChanged' then return ce end
end
local function uiObject(name)
 for _,obj in ipairs(objects) do if obj.Name==name and obj.Parent then return obj end end
 error('UI object missing: '..name)
end
'''
run_case('Dungeon collection uses owned snapshot quantities, card art, names and variants',mock+collection_mock,r'''
drain()
local app=env.AnimeDuelScript;local c=app.dungeon.collection
assert(snapshotCalls==1 and c.ready and c.cards.card_19.count==19)
assert(uiObject('DungeonOwnedCard1').Visible and uiObject('DungeonOwnedCard1'):FindFirstChild('CardName').Text=='Hero 19','collection response repaints grid without input')
assert(not c.cards.card_20,'zero quantity is not owned')
assert(c.cards.card_2.name=='Elf Mage' and c.cards.card_2.border=='Gold' and c.cards.card_2.image=='rbxassetid://2')
local all=app.listDungeonCards('','All','Power');assert(#all==19 and all[1].id=='card_19')
local matches=app.listDungeonCards('elf mage','Gold','Power');assert(#matches==1 and matches[1].id=='card_2')
assert(app.listDungeonCards('','All','Quantity')[1].count==19)
assert(not app.setDungeonSlot(1,'card_20'),'unowned rejected')
for i=1,6 do assert(app.setDungeonSlot(i,nil))end
for i=1,6 do assert(app.setDungeonSlot(i,'card_'..i))end
assert(not app.setDungeonSlot(6,'card_1'),'duplicate across team/reserves rejected')
assert(app.config.dungeonTeam=='card_1,card_2,card_3,card_4' and app.config.dungeonReserves=='card_5,card_6')
app.destroy()
''')
run_case('Dungeon card picker searches live, chooses active slots and toggles selected cards without ID input',mock+collection_mock,r'''
drain()
local app=env.AnimeDuelScript
for i=1,6 do app.setDungeonSlot(i,nil)end
uiObject('DungeonSlot5').Activated:Fire()
local search=uiObject('DungeonCardSearch');search.Text='Elf Mage';search:GetPropertyChangedSignal('Text'):Fire()
local tile=uiObject('DungeonOwnedCard1')
assert(tile.Visible and tile:FindFirstChild('CardName').Text=='Elf Mage')
assert(tile:FindFirstChild('CardArt').Image=='rbxassetid://2','highest-power matching variant')
tile.Activated:Fire()
assert(app.getDungeonSlots()[5]=='card_2','selected reserve receives click')
tile.Activated:Fire();assert(app.getDungeonSlots()[5]=='','second click removes card')
search.Text='no such hero';search:GetPropertyChangedSignal('Text'):Fire()
assert(not tile.Visible,'empty search hides stale selectable results')
search.Text='';search:GetPropertyChangedSignal('Text'):Fire()
assert(tile.Visible)
ce.OnClientEvent:Fire({Cards={card_2=3}})
assert(#app.listDungeonCards('','All','Power')==1 and app.dungeon.collection.cards.card_2.count==3)
assert(not app.uiError,tostring(app.uiError))
app.destroy()
''')
run_case('Dungeon visual selections survive saving and reloading a named profile',mock+file_mock+collection_mock,r'''
drain();local app=env.AnimeDuelScript
for i=1,6 do app.setDungeonSlot(i,nil)end
for i=1,6 do app.setDungeonSlot(i,'card_'..i)end
assert(app.saveProfile('DungeonVisual'))
app.setDungeonSlot(1,'card_7');assert(app.loadProfile('DungeonVisual'))
assert(app.getDungeonSlots()[1]=='card_1' and app.getDungeonSlots()[6]=='card_6')
app.destroy()
''')

run_case('Dungeon collection retries failed loading without replacing saved selections or inferring ownership',mock+collection_mock,r'''
snapshot={OtherData=true};drain()
local app=env.AnimeDuelScript
assert(not app.dungeon.collection.ready and not app.setDungeonSlot(1,'card_1'))
local saved=app.config.dungeonTeam
snapshot={Cards=owned};app.refreshDungeonCollection();drain()
assert(snapshotCalls==2 and app.dungeon.collection.ready)
assert(app.config.dungeonTeam==saved,'refresh preserves saved team')
app.destroy()
''')

priority_mock=r'''
local bs={OnClientEvent=signal()};local be={OnClientEvent=signal()};local sc={OnClientEvent=signal()}
local oldFind=remotes.FindFirstChild
local bossAttempts=0;local bossWins=0;local inBoss=false;local bossTimes={};local dungeonTimes={}
local sr={}
function sr:InvokeServer(id,difficulty)
 bossAttempts=bossAttempts+1
 assert(not dv.run or not dv.run.fighting,'finish current Dungeon room before Story request')
 if bossAttempts==2 then return false,'Ready in 5s' end
 if bossAttempts>=4 then return false,'Ready in 1000s' end
 bossWins=bossWins+1;inBoss=true;bossTimes[#bossTimes+1]=now
 local bid='story-'..bossWins
 bs.OnClientEvent:Fire({active=true,battleId=bid,lane=1})
 schedule(.8,function()inBoss=false;be.OnClientEvent:Fire({type='BattleEnd',battleId=bid,lane=1,won=true})end)
 return true,nil,{active=true,battleId=bid,lane=1}
end
local originalDungeon=dr.InvokeServer
function dr:InvokeServer(name,payload)
 assert(not inBoss,'Dungeon must yield until boss BattleEnd')
 if name=='Fight' then dungeonTimes[#dungeonTimes+1]=now end
 local result=originalDungeon(self,name,payload)
 if starts==2 then schedule(.2,function()env.AnimeDuelScript.stop('story')end)end
 return result
end
remotes.FindFirstChild=function(self,name)
 if name=='BattleState' then return bs elseif name=='BattleEvent' then return be elseif name=='StateChanged' then return sc elseif name=='StoryFight' then return sr end
 return oldFind(self,name)
end
'''
run_case('Dungeon yields to ready bosses, waits for matched BattleEnd, and resumes the same run',mock+dungeon_mock+priority_mock,r'''
local app=env.AnimeDuelScript;app.config.dungeonWalk=false
app.start('dungeon');app.start('story');drain()
assert(bossWins==2 and #dungeonTimes==20,'two bosses and full dungeon completed')
assert(bossTimes[2]>bossTimes[1]+5,'second boss obeys learned cooldown')
local before,after=false,false
for _,time in ipairs(dungeonTimes) do if time<bossTimes[2] then before=true elseif time>bossTimes[2]+.8 then after=true end end
assert(before and after,'Dungeon fills cooldown gaps and resumes after boss')
assert(#app.dungeon.history==1 and starts==2)
assert(not app.story.enabled and not app.dungeon.enabled)
app.destroy()
''')

rift_mock=r'''
local riftModule={}
local riftOpen=true;local cycle=10;local visit={Cycle=10,Clear=false,Shift=0}
local cfg={Status=function()return {open=riftOpen,cycle=cycle,joinable=true}end,Joined=function(record,c)return record.Cycle==c and (record.Shift or 0)==0 end}
local shared={FindFirstChild=function(_,name)if name=='RiftConfig' then return riftModule end end}
RS.FindFirstChild=function(_,name)if name=='Shared' then return shared end end
local function require(module)assert(module==riftModule);return cfg end
Workspace.GetServerTimeNow=function()return now end
local stateSync={OnClientEvent=signal()}
local snapshotRemote={InvokeServer=function()return {Rifts={Visit=visit}}end}
local oldFind=remotes.FindFirstChild
remotes.FindFirstChild=function(self,name)
 if name=='StateChanged' then return stateSync elseif name=='GetSnapshot' then return snapshotRemote end
 return oldFind and oldFind(self,name) or nil
end
'''
run_case('Rift open suspends all script mutations and preserves enabled controllers until clear',mock+dungeon_mock+priority_mock+rift_mock,r'''
local app=env.AnimeDuelScript;app.config.dungeonWalk=false
app.start('draft');app.start('climb');app.start('story');app.start('dungeon')
schedule(2,function()
 for _,c in ipairs(calls) do assert(c[1]=='State','only read-only State is allowed during Rift') end
 assert(#dcalls==0 and bossAttempts==0,'no script mutations while Rift is reserved')
 assert(app.enabled and app.climb.enabled and app.story.enabled and app.dungeon.enabled,'pause keeps toggles on')
 app.stop('draft');app.stop('climb')
 visit.Clear=true;stateSync.OnClientEvent:Fire({Rifts={Visit=visit}})
end)
drain()
assert(bossWins==2 and #dungeonTimes==20,'Boss and Dungeon resume after Rift clear')
assert(bossTimes[1]>=2)
app.destroy()
''')
run_case('Rift clearance from an old cycle cannot resume autos during a new open Rift',mock+rift_mock,r'''
local app=env.AnimeDuelScript
visit.Cycle=9;visit.Clear=true
app.start('draft')
schedule(1,function()assert(#calls==0);riftOpen=false end)
schedule(2,function()app.stop('draft')end)
drain()
assert(#calls>0,'Rift closing releases reservation')
app.destroy()
''')
run_case('Stop cancels an auto paused for Rift without waiting for Rift to close',mock+rift_mock,r'''
local app=env.AnimeDuelScript;app.start('draft')
schedule(.5,function()app.stop('draft')end);drain()
assert(#calls==0 and not app.worker and not app.enabled)
app.destroy()
''')

run_case('An open Rift schedule without joining never blocks autos until Rift close',mock+rift_mock,r'''
local app=env.AnimeDuelScript
visit={Cycle=9,Clear=false};cfg.Status=function()return {open=true,cycle=10,joinable=false}end
app.start('draft')
schedule(2,function()assert(#calls>0,'no current Rift: Draft proceeds immediately');app.stop('draft')end)
drain();app.destroy()
''')
run_case('Native Rift entry reservation expires if auto Rift never joins',mock+rift_mock,r'''
local app=env.AnimeDuelScript;visit={Cycle=9,Clear=false}
app.start('draft')
schedule(2,function()assert(#calls==0,'short entry opportunity')end)
schedule(14,function()assert(#calls>0,'release without waiting for scheduled close');app.stop('draft')end)
drain();app.destroy()
''')
run_case('Duplicate stale Rift records cannot renew a pause forever',mock+rift_mock,r'''
local app=env.AnimeDuelScript;app.start('draft')
schedule(2,function()assert(#calls==0)end)
schedule(32,function()assert(#calls>0,'idle Rift reservation expired despite repeated snapshots');app.stop('draft')end)
drain();app.destroy()
''')
run_case('Unrelated Story battles do not keep Rift priority after Rift is cleared',mock+dungeon_mock+priority_mock+rift_mock,r'''
local app=env.AnimeDuelScript;visit.Clear=true
bs.OnClientEvent:Fire({active=true,battleId='unrelated',lane=2})
app.start('draft')
schedule(2,function()assert(#calls>0,'Rift clearance is not blocked by non-Rift battles');app.stop('draft')end)
drain();app.destroy()
''')
run_case('Confirmed active Rift battle holds priority beyond idle grace and releases on its own BattleEnd',mock+dungeon_mock+priority_mock+rift_mock,r'''
local app=env.AnimeDuelScript;visit.Clear=true
bs.OnClientEvent:Fire({active=true,battleId='native-rift',lane=1,mode='rift'})
app.start('draft')
schedule(32,function()
 assert(#calls==0,'active Rift still owns priority')
 be.OnClientEvent:Fire({type='BattleEnd',battleId='unrelated',won=true})
 assert(app.priority.battles['native-rift'],'unrelated end cannot release Rift')
 be.OnClientEvent:Fire({type='BattleEnd',battleId='native-rift',won=true})
end)
schedule(34,function()assert(#calls>0,'matched Rift end resumes Draft');app.stop('draft')end)
drain();app.destroy()
''')

run_case('Prism Dungeon workspaces isolate team, collection, history and configuration on mobile',mock,r'''
local app=env.AnimeDuelScript
local function find(name)for _,o in ipairs(objects)do if o.Name==name then return o end end;error(name)end
local names={'Overview','Team','Cards','History','Settings'}
for _,name in ipairs(names)do
 find('DungeonNav'..name).Activated:Fire()
 for _,other in ipairs(names)do assert(find('DungeonGroup'..other).Visible==(name==other),'only selected workspace visible')end
end
assert(find('DungeonTeamSlots').Parent==find('DungeonGroupTeam'))
assert(find('DungeonOwnedCards').Parent==find('DungeonGroupCards'))
for _,o in ipairs(objects)do assert(o.Name~='dungeonActionBar','Dungeon uses only a toggle')end
assert(find('DungeonHero').Parent.Name=='Dungeon')
Workspace.CurrentCamera.ViewportSize=Vector2.new(390,844)
Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Fire()
find('DungeonNavTeam').Activated:Fire()
assert(find('DungeonGroupTeam').Visible and not app.uiError,tostring(app.uiError))
app.destroy()
''')

run_case('Prism fonts and moving gradient text suspend when hidden and disconnect on unload',mock+r'''
local heartbeat=signal();services.RunService={Heartbeat=heartbeat}
''',r'''
local app=env.AnimeDuelScript
local title,gradient
for _,o in ipairs(objects)do if o.Text=='ANIME DUEL' then title=o;gradient=o:FindFirstChild('OriginTextGradient')end end
assert(title and title.Font==Enum.Font.GothamBold)
heartbeat:Fire(.1);assert(gradient.Offset,'animation moves gradient')
local prior=gradient.Offset
app.Root.Enabled=false;heartbeat:Fire(.1);assert(gradient.Offset==prior,'hidden UI does no animation work')
app.Root.Enabled=true;heartbeat:Fire(.1);assert(gradient.Offset~=prior)
app.destroy()
local after=gradient.Offset;heartbeat:Fire(.1);assert(gradient.Offset==after,'animation disconnected')
''')

run_case('ACO Dungeon exposes one toggle with no duplicate Start and Stop controls',mock,r'''
local app=env.AnimeDuelScript;local label
for _,o in ipairs(objects)do
 assert(o.Text~='START DUNGEON' and o.Text~='STOP DUNGEON')
 if o.Text=='Auto Dungeon' then label=o end
end
assert(label and label.Font==Enum.Font.GothamBold and label.TextSize==14)
app.destroy()
''')
run_case('Boss and Dungeon preferences both survive profile recreation and Auto Start restores both',mock+file_mock+dungeon_mock+priority_mock,r'''
local app=env.AnimeDuelScript
app.start('story');app.start('dungeon');app.config.autoStart=true
assert(app.setAutoProfile('BothModes'))
local stored=HttpService:JSONDecode(files['AnimeDuelScript/42/profiles/BothModes.json'])
assert(stored.config.storyEnabled and stored.config.dungeonEnabled and not stored.config.draftEnabled)
app.destroy();drain();loadScript();app=env.AnimeDuelScript
assert(app.story.worker and app.dungeon.worker and app.story.enabled and app.dungeon.enabled)
assert(not app.worker and not app.climb.worker,'restore only saved modes')
app.stop();drain();app.destroy()
''')
run_case('Mode preferences load without remote writes while Auto Start is off',mock+file_mock+dungeon_mock+priority_mock,r'''
local app=env.AnimeDuelScript
app.start('story');app.start('dungeon');assert(app.saveProfile('ManualModes'))
app.stop();drain()
assert(app.loadProfile('ManualModes'))
assert(app.config.storyEnabled and app.config.dungeonEnabled)
assert(not app.story.worker and not app.dungeon.worker and #dcalls==0 and bossAttempts==0)
app.destroy()
''')

run_case('Readable UI uses toggle-only Boss and Dungeon with clear selected sidebar markers',mock,r'''
local app=env.AnimeDuelScript;local selected=0
for _,o in ipairs(objects)do
 assert(o.Text~='START BOSS' and o.Text~='STOP BOSS' and o.Text~='START DUNGEON' and o.Text~='STOP DUNGEON')
 if o.Name:match('^Nav') and o.ClassName=='TextButton' then
  assert(o.TextSize==15 and o:FindFirstChild('SelectedMarker'))
  if o:FindFirstChild('SelectedMarker').Visible then selected=selected+1 end
 end
end
assert(selected==1)
app.destroy()
''')
afkmock=mock+r'''
local idle=signal();player.Idled=idle
local afkClicks=0
services.VirtualUser={CaptureController=function()end,ClickButton2=function()afkClicks=afkClicks+1 end}
'''
run_case('Anti-AFK responds to idle, throttles, respects toggle and disconnects on unload',afkmock,r'''
local app=env.AnimeDuelScript
idle:Fire();idle:Fire();assert(afkClicks==1)
app.config.antiAfk=false;now=61;idle:Fire();assert(afkClicks==1)
app.config.antiAfk=true;idle:Fire();assert(afkClicks==2)
app.destroy();now=130;idle:Fire();assert(afkClicks==2)
''')
run_case('Anti-AFK setting persists through profiles and input failure does not stop modes',afkmock+file_mock,r'''
local app=env.AnimeDuelScript;app.config.antiAfk=false;assert(app.saveProfile('Afk'))
app.config.antiAfk=true;assert(app.loadProfile('Afk'));assert(not app.config.antiAfk)
app.config.antiAfk=true;services.VirtualUser.ClickButton2=function()error('unsupported')end
idle:Fire();assert(app.afk.status:find('unavailable',1,true) and app.alive)
app.destroy()
''')

run_case('Anti-AFK timer sends periodic input even when Idled never fires and stops after unload',afkmock,r'''
local app=env.AnimeDuelScript
local tick=maintenance[1]
now=60;tick();assert(afkClicks==1,'periodic input without idle')
app.config.antiAfk=false;now=120;tick();assert(afkClicks==1)
app.config.antiAfk=true;now=180;tick();assert(afkClicks==2)
app.destroy();now=240;tick();assert(afkClicks==2)
''')
run_case('Anti-AFK falls back when VirtualUser is blocked and releases held input on destroy',afkmock+r'''
local presses,releases=0,0
services.VirtualUser.ClickButton2=function()error('blocked')end
services.VirtualInputManager={SendMouseButtonEvent=function(_,x,y,button,down)
 if down then presses=presses+1 else releases=releases+1 end
end}
''',r'''
local app=env.AnimeDuelScript
idle:Fire();assert(presses==1 and app.afk.sent==1)
assert(app.afk.status:find('VirtualInputManager',1,true))
app.destroy();assert(releases==1,'unload must release input immediately')
for _,callback in ipairs(maintenance)do callback()end
assert(releases==1 and presses==1,'no double release or input after unload')
''')
run_case('Anti-AFK uses camera-aware VirtualUser press/release when available',afkmock+r'''
local presses,releases=0,0
Workspace.CurrentCamera.CFrame={}
services.VirtualUser.Button2Down=function(_,position,frame)assert(frame==Workspace.CurrentCamera.CFrame);presses=presses+1 end
services.VirtualUser.Button2Up=function()releases=releases+1 end
''',r'''
local app=env.AnimeDuelScript;idle:Fire()
assert(presses==1 and afkClicks==0)
app.destroy();assert(releases==1)
''')

run_case('Teleport autoexec queues once, respects toggle and disconnects on unload',mock+r'''
local teleportSignal=signal();player.OnTeleport=teleportSignal
local queued={};local function queue_on_teleport(source)queued[#queued+1]=source end
''',r'''
local app=env.AnimeDuelScript
teleportSignal:Fire(Enum.TeleportState.Started);teleportSignal:Fire(Enum.TeleportState.InProgress)
assert(#queued==1 and queued[1]:find('game:IsLoaded()',1,true))
teleportSignal:Fire(Enum.TeleportState.Failed)
app.config.autoExecuteOnHop=false;teleportSignal:Fire(Enum.TeleportState.Started);assert(#queued==1)
app.config.autoExecuteOnHop=true;teleportSignal:Fire(Enum.TeleportState.Started);assert(#queued==2)
app.destroy();teleportSignal:Fire(Enum.TeleportState.Started);assert(#queued==2)
''')
run_case('Startup waits for game loading before reading LocalPlayer',mock+r'''
local loaded=false
services.Players.LocalPlayer=nil
game.IsLoaded=function()return loaded end
game.Loaded={Wait=function()loaded=true;services.Players.LocalPlayer=player end}
''',r'''
assert(loaded and env.AnimeDuelScript.Root)
env.AnimeDuelScript.destroy()
''')

run_case('Native frontend retains team cards and Dungeon workspaces without teleport controls',mock,r'''
local app=env.AnimeDuelScript
local team,cards,tab=false,false,false
for _,o in ipairs(objects)do
 if o.Name=='DungeonTeamSlots' then team=true end
 if o.Name=='DungeonOwnedCards' then cards=true end
 if o.Name=='NavDungeon' then tab=true;assert(o.Text=='Dungeon')end
 assert(o.Text~='Teleport to Dungeon guards' and o.Text~='START BOSS' and o.Text~='STOP BOSS')
end
assert(team and cards and tab and app.config.dungeonWalk==false)
assert(not app.uiError,tostring(app.uiError))
app.destroy()
''')
