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
assert(findButton('START DRAFT') and findButton('STOP'),'start and stop controls')
assert(not app.logs,'no retained log buffer')
assert(findButton('Config'),'Config tab')
findButton('Settings').Activated:Fire()
findButton('Midnight').Activated:Fire()
assert(app.config.theme=='Emerald','theme cycle')
Workspace.CurrentCamera.ViewportSize=Vector2.new(390,844)
Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Fire()
assert(app.Root.Parent==playerGui,'UI owned by PlayerGui')
findButton('START DRAFT').Activated:Fire()
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
app.start('climb');app.start('draft')
assert(app.config.mode=='climb','active worker mode cannot be changed by another Start')
drain()
assert(climbStarts==2 and #climbPicks==2,'restart and offer picks')
assert(app.status=='Stopped',app.status)
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
assert(app.status:find('not confirmed',1,true),app.status)
app.destroy()
''')

missing_stats=climb_fixture.replace("assert(stats[id],'missing card stats');return table.unpack(stats[id])", "error('stats unavailable')")
run_case('Climb never guesses card rankings when stats are unavailable',missing_stats,r'''
local app=env.AnimeDuelScript
app.start('climb');drain()
assert(app.status:find('Cannot score climb card',1,true),app.status)
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
assert(app.status:find('Fewer than four allowed',1,true),app.status)
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
