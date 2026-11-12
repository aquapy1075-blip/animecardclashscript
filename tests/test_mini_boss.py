from pathlib import Path
import os,shutil,subprocess,tempfile
main=(Path(__file__).resolve().parents[1]/'cardorrigin.lua').read_text()
controller=main[main.index('local function createBossController(mainState)'):main.index('local boss=createBossController(state)')]
resolver=controller[controller.index('    local function resolveServerId(b)'):controller.index('    -- Sung Jinwoo/queen')]
mock=r'''
-- Baseline controller tests use synchronous remotes. Yielding/cancellation is tested separately.
local function awaitRemote(remote,current,...)
 if not current() then return false,'cancelled' end
 local result=table.pack(pcall(remote.InvokeServer,remote,...))
 if not current() then return false,'cancelled' end
 return table.unpack(result,1,result.n)
end
local function acquireQueue(queue,current) if current() then return queue.acquire() end end

local now=100
local os={clock=function() return now end,date=function() return '' end}
local task={spawn=function() end,wait=function() end}
local state={alive=true}
local ReplicatedStorage={FindFirstChild=function() return nil end}
'''
checks=r'''
local boss=createBossController(state)
local minis={}
for _,b in ipairs(boss.bosses) do if b.kind=='mini' then minis[#minis+1]=b end end
assert(#minis==8 and #boss.borderKeys==6)
for i,b in ipairs(minis) do
 assert(b.build=='BuildMini_'..b.id:sub(6) and not b.selected)
 boss.setBorder(b.id,6);assert(b.border==6)
 boss.selectBoss(b.id,true);assert(b.selected)
end
boss.setBorder(minis[1].id,2)
assert(minis[1].border==2 and minis[2].border==6,'independent border selections')
boss.enableMini(true);assert(boss.state.running and boss.state.miniEnabled and not boss.state.bossEnabled)
boss.enable(true);boss.enableMini(false);assert(boss.state.running and boss.state.bossEnabled)
boss.enableMini(true);boss.enable(false);assert(boss.state.running and boss.state.miniEnabled)
boss.stop();assert(boss.state.stopped and not boss.state.running)
'''
resolver_mock=r'''
local config={id='actual_server_key',buildRemote='BuildMini_yuta'}
local nested=function() end
local callback=function() end
local debug={getupvalues=function(fn) return fn==callback and {nested} or {config} end}
local getconnections=function() return {{Function=callback}} end
local open={OnClientEvent={}}
ReplicatedStorage.FindFirstChild=function(_,name) return name=='OpenMini_yuta' and open or nil end
'''
resolver_checks=r'''
local b={kind='mini',build='BuildMini_yuta',open='OpenMini_yuta'}
assert(resolveServerId(b) and b.serverId=='actual_server_key','use live config, not a guessed mini prefix')
config.id='changed';assert(resolveServerId(b) and b.serverId=='actual_server_key','cache verified mapping')
local unknown={kind='mini',build='BuildMini_sukuna',open='OpenMini_yuta'}
assert(not resolveServerId(unknown) and unknown.serverId==nil and unknown.cdState=='config','mismatched config cannot send guessed IDs')
getconnections=nil
local missing={kind='mini',build='BuildMini_yuta',open='OpenMini_yuta'}
assert(not resolveServerId(missing) and missing.cdState=='config','missing executor API fails closed')
print('PASS: eight mini bosses, six border mappings, independent selection/master switches, cleanup, verified runtime IDs, missing/mismatched config')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='mini-boss-test-') as d:
 p=Path(d)/'mini.luau';p.write_text(mock+controller+checks+resolver_mock+resolver+resolver_checks);subprocess.run([binary,str(p)],check=True)

