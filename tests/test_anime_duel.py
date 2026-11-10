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
local task={}
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
local player={WaitForChild=function(_,name)assert(name=='PlayerGui');return playerGui end}
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
local services={Players={LocalPlayer=player},ReplicatedStorage=RS,UserInputService=UIS,Workspace=Workspace,TweenService={}}
local game={GetService=function(_,name)assert(services[name],name);return services[name]end}
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

# Every observed action can explicitly reject while the profile is loading.
loading=mock.replace('local action={}','local action={}\nlocal rejectedOnce={};local rejectedAt={}').replace(
 "function action:InvokeServer(name,a,b)\n table.insert", """function action:InvokeServer(name,a,b)
 if not rejectedOnce[name] then
  rejectedOnce[name]=true;rejectedAt[name]=now
  return false,'Your data is still loading.'
 end
 assert(now-rejectedAt[name]>=2,'loading retry must wait')
 table.insert"""
)
run_case('loading rejection retries State/Start/Open/AutoTeam/Fight and resumes strategy',loading,checks)

table_loading=mock.replace('local action={}','local action={}\nlocal rejectedOnce={}').replace(
 "function action:InvokeServer(name,a,b)\n table.insert", """function action:InvokeServer(name,a,b)
 if not rejectedOnce[name] then
  rejectedOnce[name]=true
  return {ok=false,message='Your data is still loading.'}
 end
 table.insert"""
)
run_case('table-shaped loading rejection retries correctly',table_loading,checks)

persistent=mock.replace('local action={}','local action={}\nlocal openAttempts=0').replace(
 "function action:InvokeServer(name,a,b)\n table.insert", """function action:InvokeServer(name,a,b)
 if name=='Open' then
  openAttempts=openAttempts+1
  return false,'Your data is still loading.'
 end
 table.insert"""
)
run_case('persistent loading stops after a bounded wait',persistent,r'''
local app=env.AnimeDuelScript
app.start();drain()
assert(not app.worker and not app.enabled,'worker must stop')
assert(app.status:find('data still loading after 45s',1,true),app.status)
assert(openAttempts>1 and openAttempts<20,'bounded retries')
assert(fightIndex==0,'no fight before successful preparation')
app.destroy()
''')

stop_loading=mock.replace('local action={}','local action={}\nlocal openAttempts=0').replace(
 "function action:InvokeServer(name,a,b)\n table.insert", """function action:InvokeServer(name,a,b)
 if name=='Open' then
  openAttempts=openAttempts+1
  schedule(.5,function()env.AnimeDuelScript.stop()end)
  return false,'Your data is still loading.'
 end
 table.insert"""
)
run_case('Stop interrupts loading backoff without another attempt',stop_loading,r'''
local app=env.AnimeDuelScript
app.start();drain()
assert(openAttempts==1 and fightIndex==0,'no mutation after Stop')
assert(app.status=='Stopped' and not app.worker,app.status)
app.destroy()
''')

for label,rejection in [
    ('non-loading rejection',"return false,'Not allowed'"),
    ('uncertain transport failure',"error('Connection interrupted')"),
]:
    fixture=mock.replace('local action={}','local action={}\nlocal openAttempts=0').replace(
        "function action:InvokeServer(name,a,b)\n table.insert",
        "function action:InvokeServer(name,a,b)\n if name=='Open' then openAttempts=openAttempts+1;"+rejection+" end\n table.insert"
    )
    run_case(label+' is not replayed',fixture,r'''
local app=env.AnimeDuelScript
app.start();drain()
assert(openAttempts==1 and fightIndex==0,'unexpected retry')
assert(app.status:find('ERROR:',1,true) and not app.worker,app.status)
app.destroy()
''')

resume=mock.replace('local run=nil',"local run={id=5,boss=1,wins={},packs={draft=1},team={'a','b','c','d'}}").replace(
 "elseif name=='Fight' then\n  fightIndex", """elseif name=='Fight' then
  local opens=0
  for _,call in ipairs(calls)do if call[1]=='Open' then opens=opens+1 end end
  assert(opens==1,'resumed run must prepare only once')
  return false,'End of resume test'
 elseif name=='UnusedFight' then
  fightIndex"""
)
run_case('existing run prepares once on startup',resume,r'''
local app=env.AnimeDuelScript
app.start();drain()
assert(app.status:find('End of resume test',1,true),app.status)
app.destroy()
''')

empty_resume=resume.replace('packs={draft=1}', 'packs={draft=0,big=0,elite=0}').replace("assert(opens==1,'resumed run must prepare only once')", "assert(opens==0,'empty pack balance must skip Open')")
run_case('empty resumed run skips Open but still selects AutoTeam',empty_resume,r'''
local app=env.AnimeDuelScript
app.start();drain()
assert(app.status:find('End of resume test',1,true),app.status)
local teams=0
for _,call in ipairs(calls)do if call[1]=='AutoTeam' then teams=teams+1 end end
assert(teams==1,'AutoTeam must still run without packs')
app.destroy()
''')
