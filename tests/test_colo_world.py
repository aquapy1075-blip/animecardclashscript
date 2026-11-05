"""Check server World Blessing snapshots independently of Roblox rendering."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

main = (Path(__file__).resolve().parents[1] / 'cardorrigin.lua').read_text()
start = main.index("    local worldStats=")
end = main.index('    local function updateRun(run)', start)
observer = main[start:end]
checks = r'''
local function snapshot(dmg,hp,dr,crit)
    return {world={dmgPct=dmg or 0,hpPct=hp or 0,dr=dr or 0,critDmg=crit or 0},wave=8}
end
observeWorld('lobby',{run=snapshot(.3,.15,.1,.25)})
assert(state.worldBuffs.dmgPct==.3 and state.worldBuffs.critDmg==.25)
assert(state.worldBuffDelta==nil and state.worldBuffWave==7,'resume totals without invented reward history')
engine.run={wave=7}
observeWorld('fight',{wave=7,run=snapshot(.3,.15,.1,.25)})
assert(state.worldBuffWave==7 and state.worldBuffDelta.dmgPct==0)
local result={run=snapshot(.4,.15,.1,.25)}
observeWorld('blessing',result)
assert(math.abs(state.worldBuffDelta.dmgPct-.1)<.000001,'capture actual server increase')
result.run.world.dmgPct=99
assert(state.worldBuffs.dmgPct==.4,'snapshots are independent copies')
observeWorld('diceChoose',{run=snapshot(.4,.15,.1,.25)})
assert(math.abs(state.worldBuffDelta.dmgPct-.1)<.000001,'unchanged replies do not double-count')
observeWorld('blessing',{run=snapshot(.4,.3,.1,.25)})
assert(math.abs(state.worldBuffDelta.hpPct-.15)<.000001,'accumulate multiple changes for one completed wave')
observeWorld('fight',{wave=8,run=snapshot(.4,.3,.1,.25)})
assert(state.worldBuffWave==8 and state.worldBuffDelta.dmgPct==0
    and state.worldBuffDelta.hpPct==0,'next completed wave resets its reward delta')
observeWorld('fight',{wave=9,summary={}})
assert(state.worldBuffs.dmgPct==.4 and state.worldBuffWave==9,'final wave preserves last known totals')
observeWorld('start',{run={world={dmgPct=0,hpPct=0,dr=0,critDmg=0},wave=1}})
assert(state.worldBuffs.dmgPct==0 and state.worldBuffDelta==nil and state.worldBuffWave==nil,'fresh run clears previous history')
observeWorld('lobby',{})
assert(state.worldBuffs==nil and state.worldBuffDelta==nil,'empty lobby does not show stale totals')
print('PASS: World totals, resumed history, completed wave deltas, stable snapshots, no double count, new wave/run reset, terminal summary')
'''
binary = os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:
    raise SystemExit('Set LUAU_BIN to the Luau executable or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='colo-world-test-') as directory:
    script = Path(directory) / 'world.spec.luau'
    script.write_text('local engine={}\nlocal state={}\n' + observer + checks)
    subprocess.run([binary, str(script)], check=True)
