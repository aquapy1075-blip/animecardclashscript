"""Test reconnect backoff, kick/session errors, queue bootstrap gate, and notification timing without network IO."""
from pathlib import Path
import os, shutil, subprocess, tempfile
main=(Path(__file__).resolve().parents[1]/'cardorrigin.lua').read_text()
controller=main[main.index('-- Reconnect and teleport bootstrap.'):main.index('local function chooseStopFloor()')]
mock=r'''
local now=100
local os={clock=function() return now end}
local env={}
local state={alive=true,enabled=false,epoch=0}
local captured={}
local function signal()
 local callbacks={}
 return {Connect=function(_,fn)
  local c={Connected=true,Disconnect=function(self) self.Connected=false end}
  callbacks[#callbacks+1]={fn=fn,c=c};return c
 end,Fire=function(_,...) for _,v in ipairs(callbacks) do if v.c.Connected then v.fn(...) end end end}
end
local player={Name='Test',OnTeleport=signal()}
local GuiService={GetErrorMessage=function() return '' end}
local Enum={TeleportState={Started='Started',Failed='Failed'}}
local teleports=0
local TeleportService={TeleportInitFailed=signal(),Teleport=function(_,place,who)
 assert(place==123 and who==player);teleports+=1
end}
local rift={stop=function() end}
local task={spawn=function() end,wait=function() end}
local queued={}
local queue_on_teleport=function(text) queued[#queued+1]=text end
local fileSettings=nil
local makefolder=function() end
local writefile=function(path,value) assert(path=='AnimeOriginV9/auto_execute.json');fileSettings=value end
local readfile=function(path) assert(path=='AnimeOriginV9/auto_execute.json');return fileSettings end
local game={PlaceId=123,IsLoaded=function() return true end,GetService=function(_,name)
 if name=='CoreGui' then return {FindFirstChild=function() return nil end} end
 if name=='HttpService' then return {JSONEncode=function(_,v) return table.clone(v) end,JSONDecode=function(_,v) return v end} end
end}
'''
checks=r'''
local events={}
reconnect.notify=function(event)
 assert(teleports==#events,'notification dispatched BEFORE teleport request')
 events[#events+1]=event
end
assert(isLostConnection('you were kicked from this experience'))
assert(isLostConnection('same account launched from another device (error code: 264)'))
assert(isLostConnection('error code: 267'))
assert(isLostConnection('mất kết nối'))
assert(not isLostConnection(''))
setAutoExecute(true)
assert(#queued==1 and fileSettings.enabled and not fileSettings.reconnect)
armAutoExecute();assert(#queued==1,'deduplicate queued loader')
assert(not queued[1]:find('webhooks',1,true),'bootstrap contains no webhook token')
local originalGame=game
local boots=0
local boot={}
local function runBootstrap(enabled)
 local f=assert(loadstring(queued[1]))
 local sandbox=setmetatable({getgenv=function() return boot end,readfile=function() return {enabled=enabled,reconnect=true} end,
  game={IsLoaded=function() return true end,GetService=function() return {JSONDecode=function(_,v) return v end} end,
  HttpGet=function(_,url) assert(url:find('cardorrigin.lua',1,true));return 'BOOT' end},
  loadstring=function(source) assert(source=='BOOT');return function() boots+=1;boot.AnimeOriginV10_7={alive=true} end end,
 },{__index=getfenv()})
 setfenv(f,sandbox);f()
end
runBootstrap(false);assert(boots==0,'queued OFF preference suppresses bootstrap')
runBootstrap(true);assert(boots==1 and boot.AnimeOriginReconnectArrival)
runBootstrap(true);assert(boots==1,'duplicate queue cannot run another controller')
reconnect.lastReason='Account opened elsewhere'
assert(requestReconnect(false));assert(teleports==1 and #events==1 and fileSettings.reconnect)
assert(not requestReconnect(false) and teleports==1,'backoff blocks immediate retry')
now+=8;assert(requestReconnect(false));assert(teleports==2 and reconnect.nextAt==now+16)
TeleportService.TeleportInitFailed:Fire({},'Flooded','wrong player');assert(not reconnect.failure)
-- Notify stub here no longer asserts attempt ordering: asynchronous failure is its own event.
reconnect.notify=function(event) events[#events+1]=event end
TeleportService.TeleportInitFailed:Fire(player,'Failure','join failed')
assert(reconnect.failure and not reconnect.pending and not autoExecute.queued)
now+=16;assert(requestReconnect(false));assert(#queued==2 and teleports==3)
setAutoExecute(false);assert(fileSettings.enabled==false and autoExecute.status:find('skip',1,true))
reconnect.attempts=reconnect.limit;now+=100
assert(not requestReconnect(false) and teleports==3,'bounded retry budget')
reconnect.enabled=false;reconnect.attempts=0;reconnect.nextAt=0
assert(not requestReconnect(false) and requestReconnect(true),'manual REJOIN works with auto disabled')
local connections=table.clone(reconnect.connections)
state.stop()
assert(not state.alive and not fileSettings.enabled)
for _,c in ipairs(connections) do assert(not c.Connected) end
print('PASS: kicks/account-session errors, reconnect events before teleport, backoff/limits, async teleport failure, queue capability, OFF gate, duplicate bootstrap, arrival marker, stop cleanup')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary: raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'reconnect.luau';p.write_text(mock+controller+checks);subprocess.run([binary,str(p)],check=True)
