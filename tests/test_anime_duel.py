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
local Color3={fromRGB=function(r,g,b)return tostring(r)..','..g..','..b end}
local events={Activated=true,FocusLost=true,InputBegan=true,InputChanged=true,InputEnded=true}
local objects={}
local Instance={}
function Instance.new(class)
 local props={ClassName=class,Name=class,Visible=true,Enabled=true,Text='',Position=dim(0,0,0,0),
  Size=dim(0,0,0,0),AbsolutePosition={X=0,Y=0},AbsoluteSize={X=720,Y=58}}
 local signals={};local obj;local methods={}
 function methods:IsA(k)return k==class or k=='GuiObject' and class~='ScreenGui' and class~='UICorner' and class~='UIStroke' and class~='UIListLayout' and class~='UIPadding' end
 function methods:GetPropertyChangedSignal(k) signals[k]=signals[k] or signal();return signals[k] end
 function methods:IsFocused()return false end
 function methods:Destroy()props.Parent=nil;props.destroyed=true end
 function methods:WaitForChild(k)return props[k] end
 obj=setmetatable({}, {__index=function(_,k)
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
local UIS={InputBegan=signal(),InputChanged=signal(),InputEnded=signal()}
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
local game={PlaceId=123,GetService=function(_,name)assert(services[name],name);return services[name]end}
local function warn(s)print(s)end
'''
checks=r'''
local app=env.AnimeDuelScript
assert(app and not app.enabled and not app.worker,'must load disabled')
assert(#calls==0,'loading UI must not call remotes')
local function findButton(caption)
 for _,obj in ipairs(objects) do if obj.ClassName=='TextButton' and obj.Text==caption then return obj end end
 error('missing button '..caption)
end
assert(findButton('START') and findButton('STOP'),'start and stop controls')
assert(not app.logs,'no retained log buffer')
assert(findButton('Config'),'Config tab')
findButton('Settings').Activated:Fire()
findButton('Midnight').Activated:Fire()
assert(app.config.theme=='Emerald','theme cycle')
Workspace.CurrentCamera.ViewportSize=Vector2.new(390,844)
Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Fire()
assert(app.Root.Parent==playerGui,'UI owned by PlayerGui')
findButton('START').Activated:Fire()
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
