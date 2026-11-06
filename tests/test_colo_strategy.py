"""Check pick balance, support families, fixed draft rows and dice replacements."""
from pathlib import Path
import os, shutil, subprocess, tempfile
main=(Path(__file__).resolve().parents[1]/'cardorrigin.lua').read_text()
strategy=main[main.index('local function normalize(v)'):main.index('local remoteColo=createRemoteColo()')]
mock=r'''
local now=100
local os={clock=function() return now end}
local cfg={poll=.25,maxDraftRerolls=4,restartUntilCarry=true,autoRerun=true,allowSupports=true,wantEndless=true}
local state={alive=true,enabled=true,verified=0,runCount=0,draftRerolls=0,lastSeenWave=0}
local handoff={}
local chooseStopFloor=function() return 99 end
local coloPause=function(reason) error(reason) end
local calls={};local response={ok=true}
local remote={IsA=function() return true end,InvokeServer=function(_,action,payload)
 calls[#calls+1]={action=action,payload=payload};return response
end}
local ReplicatedStorage={FindFirstChild=function() return remote end}
'''
checks=r'''
local function card(name) return {name=name,hp=100,maxHP=100,dmg=50,supportCount=8,sacred={{id='immune'},{id='dodge'}}} end
local carry=card('Deathless Outlaw')
local run={phase='blessing',wave=15,world={hpPct=1.05,dmgPct=2.8,dr=0,critDmg=0},skill={worldUp=1},
 team={carry},devil={'Blinding','Confusion','Fatigue'}}
local e=createRemoteColo();response={ok=true,run=run};e.tick()
assert(state.worldBlessPicks.hp==7 and state.worldBlessPicks.dmg==14,'recover resumed pick counts')
for i=1,16 do
 now+=1
 -- RPC result is prepared from the stat we expect the strategy to select.
 local opt=i<=15 and 'hp' or 'dmg'
 local previous=run.world
 local world={hpPct=previous.hpPct,dmgPct=previous.dmgPct,dr=0,critDmg=0}
 if opt=='hp' then world.hpPct+=.15 else world.dmgPct+=.2 end
 local nextRun={phase='blessing',wave=15,world=world,skill=run.skill,team=run.team,devil=run.devil}
 response={ok=true,run=nextRun};e.tick()
 assert(calls[#calls].payload.opt==opt,'balance selection counts, not raw percentages')
 run=nextRun
end
assert(state.worldBlessPicks.hp==22 and state.worldBlessPicks.dmg==15)
assert(math.abs(state.worldBuffs.hpPct-3.3)<.000001 and math.abs(state.worldBuffs.dmgPct-3)<.000001)
local fresh=createRemoteColo();fresh.synced=true;fresh.resync=false
local freshRun={phase='blessing',wave=5,world={hpPct=0,dmgPct=0},team={carry},devil={'Blinding','Confusion','Fatigue'}}
fresh.run=freshRun;fresh.worldSnapshot=table.clone(freshRun.world)
for _,opt in ipairs({'hp','dmg','hp','dmg','hp'}) do
 local world=table.clone(freshRun.world)
 if opt=='hp' then world.hpPct+=.1 else world.dmgPct+=.1 end
 response={ok=true,run={phase='blessing',wave=5,world=world,team=freshRun.team,devil=freshRun.devil}}
 calls={};now+=1;fresh.tick();assert(calls[1].payload.opt==opt,'fresh World cycle follows 3 HP : 2 DMG')
 freshRun=response.run
end
assert(fresh.worldPicks.hp==3 and fresh.worldPicks.dmg==2)
local hollow=card('Hollow Harvester');hollow.supportCount=0;hollow.supports={}
local goddess=card('Useless Goddess');goddess.supportCount=0;goddess.supports={}
local idol=card('Idol');idol.supportCount=0;idol.supports={}
local e=createRemoteColo();e.synced=true;e.resync=false
local offers={{name='HP One',desc='+15% DMG, +15% Max HP'},
 {name='Attack',desc='+20% DMG'},{name='HP Two',desc='+30% DMG, +30% Max HP'},
 {name='Guard',desc='+10% Damage Reduction'}}
e.run={phase='blessing',wave=5,skill={supportExpand=1},team={carry,goddess,hollow,idol},offer={peoples=offers}}
calls={};response={ok=true};now+=1;e.tick()
assert(calls[1].payload.cat=='peoples' and calls[1].payload.assign[1]==3 and calls[1].payload.assign[3]==3,'Max HP buffs go to Hollow after eight carry supports')
assert(calls[1].payload.assign[2]~=1 and calls[1].payload.assign[2]~=3,'other offers assigned to another valid teammate')
carry.supportCount=0;carry.supports={}
e=createRemoteColo();e.synced=true;e.resync=false
e.run={phase='blessing',wave=5,skill={supportExpand=1},team={carry,goddess,hollow,idol},offer={peoples={{name='Senzu Bean'},{name='Potara Earrings'},{name='Log'},{name='Vivre Card'}}}}
calls={};now+=1;e.tick()
for _,target in ipairs(calls[1].payload.assign) do assert(target==1,'carry fills before Hollow') end
carry.supportCount=8
local e=createRemoteColo();e.synced=true;e.resync=false;e.run={phase='draft',wave=1,rerollsLeft=4,draft={rows={
 {card('Deathless Outlaw'),card('Fire Soldier (Evolved)')},
 {card('Deathless Outlaw')},
 {card('Useless Goddess (Mutated)'),card('Other')},
 {card('Useless Goddess'),card('Sorcerer Supreme')},
}}}
state.draftRerolls=0;calls={};response={ok=true};now+=1;e.tick()
assert(calls[1].action=='draft')
local p=calls[1].payload.picks
assert(p[2]==1 and p[1]==2,'prefer carry in row 2 when the same carry is offered there')
assert(p[3]==1 and p[4]==2,'bench supporters and no duplicate Goddess aura')
local e=createRemoteColo();e.synced=true;e.resync=false;e.run={phase='draft',wave=1,rerollsLeft=4,draft={rows={
 {card('Fire Soldier (Evolved)'),card('Introvert Guitarist')},
 {card('Deathless Outlaw')},
 {card('Useless Goddess'),card('Demon Venerable')},
 {card('Sorcerer Supreme'),card('Ghoul Hunger')},
}}}
calls={};response={ok=true};now+=1;e.tick()
local picks=calls[1].payload.picks
assert(picks[1]==2 and picks[2]==1 and picks[3]==1 and picks[4]==1,'one carry plus three supports, even low-ranked support beats secondary carry')
local e=createRemoteColo();e.synced=true;e.resync=false;e.run={phase='diceCard',wave=5,
 team={card('Other'),carry,card('Sorcerer Supreme'),card('Useless Goddess')},diceCard=card('Introvert Guitarist')}
calls={};response={ok=true};now+=1;e.tick()
assert(calls[1].action=='diceChoose' and calls[1].payload.slot==1,'dice can add a third support without replacing carry or stronger supports')
-- Goddess/Harvester variants count as one family; pick a unique alternative.
local e=createRemoteColo();e.synced=true;e.resync=false;e.run={phase='draft',wave=1,rerollsLeft=0,draft={rows={
 {card('Useless Goddess'),card('Hollow Harvester')},
 {card('Deathless Outlaw')},
 {card('Useless Goddess (Mutated)')},
 {card('Hollow Harvester (Cursed)'),card('Idol')},
}}}
calls={};response={ok=true};now+=1;e.tick()
local p=calls[1].payload.picks
assert(p[1]==2 and p[3]==1 and p[4]==2,'global draft search keeps exactly one Goddess and one Harvester')
local e=createRemoteColo();e.synced=true;e.resync=false
local t={card('Hollow Harvester'),card('Deathless Outlaw'),card('Idol'),card('Useless Goddess')}
e.run={phase='ready',wave=2,team=t}
local nt=table.clone(t);nt[1],nt[2]=nt[2],nt[1]
calls={};response={ok=true,run={phase='ready',wave=2,team=nt}};now+=1;e.tick()
assert(calls[1].action=='swap' and calls[1].payload.a==2 and calls[1].payload.b==1,'three supports moves carry to slot 1')
assert(e.run.team[1].name=='Deathless Outlaw')
-- Verified swap protocol: one request per tick, server-authoritative result.
local e=createRemoteColo();e.synced=true;e.resync=false
local team={card('Useless Goddess'),card('Other'),card('Deathless Outlaw'),card('Idol')}
e.run={phase='ready',wave=2,team=team}
local function swapTick(a,b)
 local previous=e.run
 local nextTeam=table.clone(previous.team);nextTeam[a],nextTeam[b]=nextTeam[b],nextTeam[a]
 response={ok=true,run={phase='ready',wave=2,team=nextTeam}}
 calls={};now+=1;e.tick()
 assert(#calls==1 and calls[1].action=='swap' and calls[1].payload.a==a and calls[1].payload.b==b)
 assert(e.run.team[a]==previous.team[b] and e.run.team[b]==previous.team[a])
end
swapTick(3,2);swapTick(1,3);swapTick(3,4)
assert(e.run.team[2].name=='Deathless Outlaw' and e.run.team[4].name=='Useless Goddess' and e.run.team[3].name=='Idol')
calls={};response={ok=true};now+=1;e.tick();assert(#calls==1 and calls[1].action=='fight','stable arrangement fights instead of looping swaps')
local e=createRemoteColo();e.synced=true;e.resync=false
e.run={phase='ready',wave=2,team={card('Deathless Outlaw'),card('Other'),card('Idol'),card('Useless Goddess')}}
response={ok=true,run=e.run};now+=1
local ok,reason=pcall(e.tick);assert(not ok and tostring(reason):find('not confirmed',1,true),'unchanged server team cannot cause infinite swaps')
local names={'Idol','Crimson Ruin Devil','Golden King','Accelerated Heaven','Game Princess',"Reality's Worst Duet",
 'Abyssal Pianist','Introvert Guitarist','Blackwing Devil (Mutated)','Swift (Cursed)','The Grinning Spectator'}
for _,name in ipairs(names) do assert(sideScore(card(name))>0,'support missing: '..name) end
local e=createRemoteColo();e.synced=true;e.resync=false;e.run={phase='diceCard',wave=5,
 team={card('Other'),carry,card('Other'),card('Idol')},diceCard=card('Useless Goddess')}
calls={};response={ok=true};now+=1;e.tick()
assert(calls[1].action=='diceChoose' and calls[1].payload.slot==3,'place a new good support in the weak back slot')
local e=createRemoteColo();e.synced=true;e.resync=false;e.run={phase='diceCard',wave=5,
 team={card('Other'),carry,card('Useless Goddess'),card('Idol')},diceCard=card('Useless Goddess')}
calls={};now+=1;e.tick()
assert(calls[1].payload.bonus=='buff' and calls[1].payload.target==2,'do not duplicate a nonstacking support')
local e=createRemoteColo();calls={}
local cards={card('Other'),card('Deathless Outlaw'),card('Useless Goddess'),card('Idol')}
cards[4].dead=true
response={ok=true,run={phase='ready',wave=5,team=cards,world={}}};now+=1;e.tick()
assert(#state.teamCards==4 and state.teamCards[2].role=='carry' and state.teamCards[3].role=='support'
 and state.teamCards[1].role=='normal' and state.teamCards[4].dead,'all team roles exposed to UI')
cards[2].name='changed outside';assert(state.teamCards[2].name=='Deathless Outlaw','display snapshot independent of RPC tables')
e.resync=true;response={ok=true};now+=1;e.tick();assert(#state.teamCards==0,'ended run clears displayed team')
print('PASS: 3:2 World picks, Hollow HP after carry full with resumed catch-up, variant support families, carry row 2 when available, fixed bench draft, verified server swaps, stable order, unconfirmed swap stop, dice upgrades, no duplicate aura')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='colo-strategy-test-') as d:
 p=Path(d)/'colo.luau';p.write_text(mock+strategy+checks);subprocess.run([binary,str(p)],check=True)
