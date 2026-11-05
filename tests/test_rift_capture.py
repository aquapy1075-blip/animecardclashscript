"""Verify the manual recorder observes RPCs without changing their results."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

source=(Path(__file__).resolve().parents[1]/'rift_remote_capture.lua').read_text()
mock=r'''
local env={}
local getgenv=function() return env end
local warnings={}
local warn=function(message) warnings[#warnings+1]=message end
local task={defer=function(fn) fn() end}
local function signal()
 local listeners={}
 return {Connect=function(_,fn)
  local c={Connected=true}
  function c:Disconnect() self.Connected=false end
  listeners[#listeners+1]={fn=fn,c=c};return c
 end,Fire=function(_,...) for _,v in ipairs(listeners) do if v.c.Connected then v.fn(...) end end end}
end
local function remote(class,path)
 return {_instance=true,ClassName=class,GetFullName=function() return path end,
 IsA=function(_,kind) return class==kind end,OnClientEvent=signal()}
end
local rf=remote('RemoteFunction','ReplicatedStorage.EventRemotes.TestRift')
local re=remote('RemoteEvent','ReplicatedStorage.EventRemotes.RiftGateReward')
local chat=remote('RemoteEvent','ReplicatedStorage.DefaultChatSystemChatEvents.Chat')
local root={DescendantAdded=signal(),GetDescendants=function() return {rf,re,chat} end}
local exports={}
local http={JSONEncode=function(_,obj) exports[#exports+1]=obj;return 'json' end}
local game={GetService=function(_,name) return name=='HttpService' and http or root end}
local typeof=function(obj) return type(obj)=='table' and obj._instance and 'Instance' or type(obj) end
local saved={}
local writefile=function(path,data) saved[path]=data end
local method='InvokeServer'
local getnamecallmethod=function() return method end
local installed
local forwarded=0
local hooks=0
local original=function(self,action,...)
 forwarded+=1
 if action=='fail' then error('server error',0) end
 if action=='slow' then coroutine.yield('pending');return 42 end
 return {ok=true},nil,7
end
local hookmetamethod=function(_,_,fn) installed=fn;hooks+=1;return original end
'''
checks=r'''
local c=env.AnimeOriginRiftCapture
assert(c.active and forwarded==0,'starting capture must send no remote requests')
local result=table.pack(installed(rf,'enter',{party={1,2,3,4}}))
assert(result.n==3 and result[1].ok and result[2]==nil and result[3]==7,'preserve exact returned tuple')
assert(#c.records==1 and c.records[1].status=='returned' and c.records[1].method=='InvokeServer')
method='FireServer';installed(re,'claim')
assert(c.records[2].status=='sent')
re.OnClientEvent:Fire({reward=25})
assert(c.records[3].direction=='server_to_client' and c.records[3].method=='OnClientEvent')
local count=#c.records
installed(chat,'chat');chat.OnClientEvent:Fire('chat')
assert(#c.records==count,'omit chat')
method='InvokeServer';local ok=pcall(installed,rf,'fail')
assert(not ok and c.records[#c.records].status=='error','preserve remote errors')
local thread=coroutine.create(function() return installed(rf,'slow') end)
local ok,value=coroutine.resume(thread);assert(ok and value=='pending' and c.pending==1)
c.stop();assert(not pcall(c.start),'cannot overwrite a session with pending replies')
ok,value=coroutine.resume(thread);assert(ok and value==42 and c.pending==0)
assert(c.records[#c.records].status=='returned' and saved[c.path]=='json','late reply saved after stop')
count=#c.records;re.OnClientEvent:Fire('after stop');installed(rf,'after stop')
assert(#c.records==count,'stop disconnects observers and bypasses outgoing capture')
c.start();assert(#c.records==0 and c.active and hooks==1)
re.OnClientEvent:Fire('one incoming record')
assert(#c.records==1,'restart does not duplicate incoming listeners')
local cyclic={};cyclic.self=cyclic
installed(rf,'cycle',cyclic)
assert(c.records[2].status=='returned','cycles cannot break the game RPC')
c.maxRecords=#c.records
local before=forwarded;installed(rf,'over limit')
assert(not c.active and c.limitReason and forwarded==before+1,'limit stops recording, not the game RPC')
print('PASS: no proactive RPC, outgoing/events/replies, nil returns, errors, pending replies, stop/restart, chat exclusion, cycles, record limit')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:
    raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='rift-capture-test-') as directory:
    path=Path(directory)/'capture.spec.luau'
    path.write_text(mock+'\nlocal function runCapture()\n'+source+'\nend\nrunCapture()\n'+checks)
    subprocess.run([binary,str(path)],check=True)
