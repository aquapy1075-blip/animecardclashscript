"""The lightweight recorder must leave unrelated calls and UI untouched."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

source=(Path(__file__).resolve().parents[1]/'rift_remote_capture.lua').read_text()
mock=r'''
local disabled=0
local legacy={Version=1,active=true,connections={{Disconnect=function() disabled+=1 end}}}
local env={AnimeOriginRiftCapture=legacy}
local getgenv=function() return env end
local warnings={}
local warn=function(message) warnings[#warnings+1]=message end
local function remote(class,path)
 return {ClassName=class,GetFullName=function() return path end,
 IsA=function(_,kind) return class==kind end}
end
local rf=remote('RemoteFunction','ReplicatedStorage.EventRemotes.BuildRiftGateBattle')
local re=remote('RemoteEvent','ReplicatedStorage.EventRemotes.RiftGateEnterRequest')
local unrelated=remote('RemoteFunction','ReplicatedStorage.Roll')
local searches=0
local root={FindFirstChild=function(_,name)
 searches+=1
 if name=='BuildRiftGateBattle' then return rf end
 if name=='RiftGateEnterRequest' then return re end
end,GetDescendants=function() error('must not scan all game instances') end}
local encodes=0
local http={JSONEncode=function(_,obj) encodes+=1;return 'json' end}
local game={GetService=function(_,name)
 if name=='ReplicatedStorage' then return root end
 assert(name=='HttpService','must not inspect other services');return http
end}
local typeof=type
local saves=0
local writefile=function(path,data) assert(path=='rift_remote_capture.json' and data=='json');saves+=1 end
local method='InvokeServer'
local methodReads=0
local getnamecallmethod=function() methodReads+=1;return method end
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
assert(c.active and forwarded==0,'starting capture must send no requests')
assert(not legacy.active and disabled==1,'deactivate old recorder listeners without exporting')
assert(encodes==0 and searches==11,'fixed remote lookup only; no background export')
local result=table.pack(installed(rf,'enter',{party={1,2,3,4}}))
assert(result.n==3 and result[1].ok and result[2]==nil and result[3]==7,'preserve returned tuple')
assert(#c.records==1 and c.records[1].status=='returned' and c.records[1].remote=='BuildRiftGateBattle')
method='FireServer';installed(re,'enter')
assert(c.records[2].status=='sent')
local count=#c.records;local reads=methodReads
installed(unrelated,'roll')
assert(#c.records==count and methodReads==reads,'unrelated calls bypass immediately')
method='GetFullName';installed(rf,'read');assert(#c.records==count,'non-RPC calls bypass')
method='InvokeServer';local ok=pcall(installed,rf,'fail')
assert(not ok and c.records[#c.records].status=='error','preserve errors')
local cyclic={};cyclic.self=cyclic
installed(rf,'cycle',cyclic);assert(c.records[#c.records].status=='returned')
assert(encodes==0 and saves==0 and searches==11,'no IO, listeners, periodic scans or autosave during capture')
local thread=coroutine.create(function() return installed(rf,'slow') end)
local ok,value=coroutine.resume(thread);assert(ok and value=='pending' and c.pending==1)
c.stop();assert(not pcall(c.start),'do not overwrite a pending session')
ok,value=coroutine.resume(thread);assert(ok and value==42 and c.pending==0)
assert(c.records[#c.records].status=='returned' and saves==1,'late reply does not autosave')
c.stop();assert(saves==2,'manual stop saves completed reply')
count=#c.records;installed(rf,'after stop');assert(#c.records==count)
c.start();assert(#c.records==0 and c.active and hooks==1 and searches==11,'restart reuses hook without rescanning')
c.limit=1;local before=forwarded;installed(rf,'last record')
assert(not c.active and #c.records==1 and forwarded==before+1 and saves==2,'limit stops only recording, not game or IO')
print('PASS: fixed Rift filter, unrelated fast path, no proactive RPC/listeners/autosave/UI changes, tuples/errors, legacy cleanup, manual save, limits')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:
    raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='rift-capture-test-') as directory:
    path=Path(directory)/'capture.spec.luau'
    path.write_text(mock+'\nlocal function runCapture()\n'+source+'\nend\nrunCapture()\n'+checks)
    subprocess.run([binary,str(path)],check=True)
