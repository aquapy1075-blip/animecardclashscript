"""Run real yielding remote/queue helpers and actual Boss/Siege launch paths with a deterministic scheduler."""
from pathlib import Path
import os, shutil, subprocess, tempfile
main=(Path(__file__).resolve().parents[1]/'cardorrigin.lua').read_text()
helper=main[main.index('local pendingRemotes='):main.index('-- Stop any older controllers:')]
boss=main[main.index('local function runBoss(b,token)'):main.index('    local function setRunning(on)')]
siege=main[main.index('    local function tryStage(stage,epoch)'):main.index('    local function enable(on)', main.index('    local function tryStage(stage,epoch)'))]
colo=main[main.index('    local function invoke(action,payload)'):main.index('    local function arrangeTeam(run)')]
mock=r'''
local now=0
local os={clock=function() return now end}
local scheduled={}
local task={}
local function resume(co,...)
 local ok,wait=coroutine.resume(co,...);assert(ok,wait)
 if coroutine.status(co)~='dead' then scheduled[#scheduled+1]={co=co,at=now+(wait or .01)} end
end
function task.spawn(fn,...) local co=coroutine.create(fn);resume(co,...);return co end
function task.wait(seconds) return coroutine.yield(seconds or .01) end
function task.delay(seconds,fn) scheduled[#scheduled+1]={co=coroutine.create(fn),at=now+seconds} end
local function advance(seconds)
 local target=now+seconds
 while true do
  local best
  for i,v in ipairs(scheduled) do if v.at<=target and (not best or v.at<scheduled[best].at) then best=i end end
  if not best then break end
  local item=table.remove(scheduled,best);now=item.at;resume(item.co)
 end
 now=target
end
local Instance={new=function() return {Fire=function() end,Destroy=function() end} end}
local env={}
local alive=true
local function current() return alive end
'''
checks=r'''
-- Timeout releases the caller, but pending guard prevents replay until real server response.
local calls=0
local remote={InvokeServer=function() calls+=1;task.wait(30);return 'late',42 end}
local result
local first
 task.spawn(function() first=table.pack(awaitRemote(remote,current)) end)
advance(20.1)
assert(first and first[1]==false and first[2]:find('timed out'))
local second=table.pack(awaitRemote(remote,current));assert(second[1]==false and calls==1,'no duplicate pending RPC')
advance(10)
assert(pendingRemotes[remote]==nil and first[1]==false,'late server response cannot change completed caller')
-- Preserve nil arguments and multiple return values.
remote.InvokeServer=function(_,a,b,c) assert(a==1 and b==nil and c==3);return nil,42 end
local ok,a,b=awaitRemote(remote,current,1,nil,3);assert(ok and a==nil and b==42)
-- OFF while waiting ignores successful stale response.
remote.InvokeServer=function() task.wait(1);return {ok=true} end
local cancelled
 task.spawn(function() cancelled=table.pack(awaitRemote(remote,current)) end)
alive=false;advance(.1);assert(cancelled and not cancelled[1]);advance(1);alive=true
-- A queue acquired after cancellation releases itself.
local released=0
local queue={acquire=function() task.wait(2);return function() released+=1 end end}
local acquired='unset'
 task.spawn(function() acquired=acquireQueue(queue,current) end)
alive=false;advance(.1);assert(acquired==nil);advance(2);assert(released==1);alive=true
-- Actual Boss launch: stopping during Build response must never call playDummy or report victory.
local mainState={alive=true}
local state={running=true,stopped=false,epoch=1,wins=0,losses=0}
local b={name='Boss',id='test',border=1,build='Build'}
local borders={'Normal'};local borderKeys={'Normal'}
local debugLog=function() end;local notify=function() end;local readable=tostring
local resolveServerId=function() return true end
local plays=0;local rewards=0;local releasedBoss=0
local router={ready=function() return true end,pickSlot=function() return 1 end,playDummy=function() plays+=1;return 1 end}
queue={acquire=function() return function() releasedBoss+=1 end end}
local remotes={GetBossCooldown={InvokeServer=function() return 0 end},
 Build={InvokeServer=function() task.wait(2);return {ok=true,party={},enemies={}} end},
 ReportBossVictory={FireServer=function() rewards+=1 end}}
local getRemote=function(name) return remotes[name] end
BOSS_CODE
 task.spawn(function() runBoss(b,1) end)
advance(.2);state.running=false;state.epoch+=1
advance(3)
assert(plays==0 and rewards==0 and releasedBoss==1,'Boss cancelled build cannot launch or claim')
-- A previously registered Boss callback becomes inert after OFF/ON.
state.running=true;state.epoch=3
remotes.Build.InvokeServer=function() return {ok=true,party={},enemies={}} end
local lateDone
router.playDummy=function(payload) plays+=1;lateDone=payload.onDone;return 1 end
 task.spawn(function() runBoss(b,3) end)
advance(.2);state.running=false;state.epoch=4;advance(.2)
lateDone(true)
assert(rewards==0 and state.wins==0,'stale Boss callback cannot report a win')
-- Actual Siege launch has the same OFF-during-build protection.
local st={alive=true,on=true,epoch=1,modules={router=router,queue=queue},retryUntil={},cooldownUntil={}}
local stage={index=1,name='Test'}
local say=function() end;local trace=function() end
local siegeCalls=0;local claims=0
local build={InvokeServer=function() siegeCalls+=1;task.wait(2);return {ok=true,party={{}},enemyIds={1,2,3,4}} end}
local claim={InvokeServer=function() claims+=1;return {ok=true} end}
local rf=function(name) return name=='StartDungeonStage' and build or claim end
local makeEnemy=function() return {} end
local fetchParty=function() return {{}} end
SIEGE_CODE
local before=plays
 task.spawn(function() tryStage(stage,1) end)
advance(.2);st.on=false;st.epoch+=1;advance(3)
assert(siegeCalls==1 and plays==before and claims==0 and st.activeStage==nil,'Siege cancelled build cannot launch or claim')
do
 local state={alive=true,enabled=true,epoch=1,verified=0}
 local engine={busy=false,replayPending=true}
 local cfg={poll=.25}
 local updated=0
 local remote={IsA=function() return true end,InvokeServer=function() task.wait(2);return {ok=true,run={}} end}
 local ReplicatedStorage={FindFirstChild=function() return remote end}
 local coloPause=function() error('cancelled generation must resync without pausing a new generation') end
 local observeWorld=function() updated+=1 end
 local updateRun=function() updated+=1 end
 local chooseStopFloor=function() return 35 end
 COLO_CODE
 task.spawn(function() invoke('fight') end)
 advance(.1);state.enabled=false;state.epoch+=1;advance(3)
 assert(engine.resync and not engine.busy and not engine.replayPending and updated==0 and state.verified==0,'cancelled Colosseum response cannot update run or replay')
end
print('PASS: real async timeout, no duplicate RPC, nil/multiple values, late-response rejection, abandoned queue release, actual Boss/Siege cancellation and stale callback')
'''.replace('BOSS_CODE',boss).replace('SIEGE_CODE',siege).replace('COLO_CODE',colo)
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary: raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'async.luau';p.write_text(mock+helper+checks);subprocess.run([binary,str(p)],check=True)
