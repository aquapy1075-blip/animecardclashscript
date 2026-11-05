"""Exercise captured Rift RPC order and genuine native-battle completion."""
from pathlib import Path
import os, shutil, subprocess, tempfile
main=(Path(__file__).resolve().parents[1]/'cardorrigin.lua').read_text()
controller=main[main.index('local function createRiftGateController()'):main.index('local rift=createRiftGateController()')]
mock=r'''
local now=1000000
local os={clock=function() return now end,time=function() return now end}
local env={}
local state={alive=true}
local combat={}
local tryCombat=function(owner) if combat.owner then return false end combat.owner=owner;return true end
local freeCombat=function(owner) if combat.owner==owner then combat.owner=nil end end
local function signal()
 local fn
 return {Connect=function(_,callback) fn=callback;return {Disconnect=function() fn=nil end} end,
 Fire=function(_,...) if fn then fn(...) end end}
end
local calls={}
local remotes={}
local function make(name,class)
 local r={OnClientEvent=signal(),IsA=function(_,kind) return kind==class end}
 r.FireServer=function(_,...) calls[#calls+1]={name=name,args=table.pack(...)} end
 r.InvokeServer=function(_,...) calls[#calls+1]={name=name,args=table.pack(...)};return {ok=true,party={{CardID=6}},enemies={{CardID=183}}} end
 remotes[name]=r
end
for _,name in ipairs({'RiftGateSpawned','RiftGateClosed','RiftGateReward','RiftGateEnterRequest','ReportRiftGateVictory','RiftGateLeave'}) do make(name,'RemoteEvent') end
make('BuildRiftGateBattle','RemoteFunction')
local done
local plays=0
local router={ready=function() return true end,playDummy=function(payload,slot)
 assert(slot==2 and payload.startHidden and #payload.party==1 and #payload.enemies==1)
 done=payload.onDone;plays+=1;return true
end}
local unlocks=0
local queue={acquire=function() return function() unlocks+=1 end end}
local ReplicatedStorage={FindFirstChild=function(_,name)
 if name=='EventRemotes' then return {FindFirstChild=function(_,key) return remotes[key] end} end
 if name=='BattleRouter' then return router end
 if name=='AutoBattleQueue' then return queue end
end}
local require=function(value) return value end
local playerGui={FindFirstChild=function() return nil end}
local game={GetService=function() return {} end}
local task={spawn=function() end,wait=function() end}
'''
checks=r'''
local r=createRiftGateController();r.enable(true)
r.tick();assert(#calls==0,'wait for a real event')
remotes.RiftGateSpawned.OnClientEvent:Fire();now+=1.1;r.tick()
assert(calls[1].name=='RiftGateEnterRequest' and calls[1].args.n==0)
assert(r.cooldownText()=='05:00','entry cooldown is five minutes')
now+=3.1;r.tick()
assert(calls[2].name=='BuildRiftGateBattle' and calls[2].args.n==1 and calls[2].args[1]==true)
assert(plays==1 and unlocks==1 and #calls==2,'build is not a victory')
done(true)
assert(calls[3].name=='ReportRiftGateVictory' and calls[3].args.n==0)
r.tick();assert(#calls==3,'wait for server reward acknowledgement')
remotes.RiftGateReward.OnClientEvent:Fire();local cleared=now
assert(r.cooldownText()=='05:00','clear cooldown is also five minutes')
now+=1.1;r.tick()
assert(calls[4].name=='RiftGateLeave' and r.state.clears==1 and combat.owner==nil)
remotes.RiftGateSpawned.OnClientEvent:Fire();r.tick();assert(#calls==4,'preserve admission cooldown')
now=cleared+299;r.tick();assert(#calls==4,'no entry before five minutes')
now=cleared+300.1;r.tick();assert(calls[5].name=='RiftGateEnterRequest','entry allowed after five minutes if an event is available')
r.stop();env.AnimeOriginRiftRateLimit={};calls={}
local r=createRiftGateController();r.enable(true);remotes.RiftGateSpawned.OnClientEvent:Fire();r.tick();now+=3.1;r.tick()
done(false);now+=1.1;r.tick()
assert(#calls==3 and calls[3].name=='RiftGateLeave','loss never reports victory')
r.stop();env.AnimeOriginRiftRateLimit={};calls={}
local r=createRiftGateController();r.enable(true);remotes.RiftGateSpawned.OnClientEvent:Fire();r.tick();now+=3.1;r.tick()
now+=241;r.tick()
assert(not r.state.on and #calls==2 and combat.owner=='rift','timeout does not fake victory or unlock a live battle')
done(false);now+=1.1;r.tick();assert(combat.owner==nil)
r.stop();env.AnimeOriginRiftRateLimit={};calls={}
local r=createRiftGateController();r.enable(true);remotes.RiftGateSpawned.OnClientEvent:Fire();r.tick();r.enable(false);now+=3.1;r.tick()
assert(#calls==2 and calls[2].name=='RiftGateLeave' and combat.owner==nil,'disable before build releases admission')
print('PASS: captured four-step Rift flow, builder true argument, native victory, reward acknowledgement, loss/timeout, disable, cooldown, combat lock')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='rift-remote-test-') as d:
 p=Path(d)/'rift.luau';p.write_text(mock+controller+checks);subprocess.run([binary,str(p)],check=True)
