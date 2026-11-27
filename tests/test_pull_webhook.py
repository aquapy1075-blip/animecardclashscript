"""Verify personal roll filtering and notification delivery without network IO."""
from pathlib import Path
import os,shutil,subprocess,tempfile
main=(Path(__file__).resolve().parents[1]/'cardorrigin.lua').read_text()
controller=main[main.index('local function createPullWebhook()'):main.index('local pullWebhook=createPullWebhook()')]
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
local os={clock=function() return now end}
local state={alive=true}
local player={Name='TestPlayer'}
local game={PlaceId=123}
local task={spawn=function() end,wait=function() end}
local inventory={}
local inventoryCalls=0
local inventoryFailure=false
local remote={IsA=function(_,kind) return kind=='RemoteFunction' end,InvokeServer=function()
 inventoryCalls+=1;if inventoryFailure then error('offline') end;return inventory
end}
local cards={
 [1]={Name='Under',BaseRarity='1/999,999,999'},
 [2]={Name='Exactly',BaseRarity='1/1,000,000,000'},
 [3]={Name='Above',BaseRarity='1/1,000,000,001'},
 [4]={Name='Custom',BaseRarity='Custom'},
 [5]={Name='Normal Huge',BaseRarity='1/2,000,000,000'},
}
local db={GetCard=function(id) return cards[id] end}
local require=function(v) return v end
local ReplicatedStorage={FindFirstChild=function(_,name)
 if name=='EventRemotes' then return {FindFirstChild=function(_,key) assert(key=='GetInventory');return remote end} end
 if name=='CardImages' then return {GetImage=function(id) return id==3 and 'rbxassetid://12345' or 'rbxasset://textures/ui/GuiImagePlaceholder.png' end} end
 if name=='GameDatabase' then return {FindFirstChild=function() return db end} end
end}
local encoded
local stored=nil
local savedJSON=nil
local diskFailure=false
local makefolder=function() end
local writefile=function(path,value)
 assert(path=='AnimeOriginV9/webhook.json');if diskFailure then error('disk unavailable') end;stored=value
end
local readfile=function(path) assert(path=='AnimeOriginV9/webhook.json');return stored end
local HttpService={JSONEncode=function(_,value) if value.url~=nil then savedJSON=table.clone(value);return 'settings' end;encoded=value;return 'body' end,JSONDecode=function(_,body) if body=='settings' then return savedJSON end;if body=='image' then return {data={{state='Completed',imageUrl='https://tr.rbxcdn.com/card.png'}}} end;return {retry_after=2} end}
local requests={}
local onThumbnail=nil
local response={StatusCode=204}
local request=function(options) if options.Method=='GET' then if onThumbnail then onThumbnail() end;assert(options.Url:find('assetIds=12345',1,true));return {StatusCode=200,Body='image'} end;requests[#requests+1]=options;if response=='error' then error('private URL error') end;return response end
'''
checks=r'''
local w=createPullWebhook()
assert(not w.setEndpoint('http://discord.com/api/webhooks/123/test'))
assert(not w.setEndpoint('https://discord.com.evil.test/api/webhooks/123/test'))
assert(w.setEndpoint('https://discord.com/api/webhooks/123/test-token'))
inventory={['3']={counts={Normal=5}}}
w.enable(true);w.tick();assert(#requests==0,'existing cards become baseline')
local calls=inventoryCalls;w.enable(true);w.tick();assert(inventoryCalls==calls,'polling bounded; profile apply keeps baseline')
inventory={['1']={count=10},['2']={counts={Origin=10}},['3']={counts={Normal=5,Gold=2}},['4']={count=1}}
now+=11;w.tick()
assert(#requests==1 and w.state.matched==2 and w.state.sent==1,'all-source gains, base threshold, aggregated copies')
assert(encoded.embeds[1].fields[2].value=='Above')
assert(encoded.embeds[1].fields[4].value=='Calamity' and encoded.embeds[1].fields[6].value=='2')
assert(encoded.embeds[1].image.url=='https://tr.rbxcdn.com/card.png')
assert(#encoded.allowed_mentions.parse==0)
now+=11;w.tick();assert(#requests==1,'same inventory cannot duplicate notifications')
inventory={['3']={counts={Normal=4,Gold=3}}};now+=11;w.tick()
assert(#requests==1,'border conversion does not invent acquisitions')
inventoryFailure=true;now+=11;w.tick();inventoryFailure=false
inventory={['3']={counts={Normal=4,Gold=3}},['5']={count=1,bestBorder='Normal'}}
response={StatusCode=429,Body='retry'};now+=11;w.tick()
local count=#requests;w.tick();assert(#requests==count)
now+=2.1;response={StatusCode=204};w.tick();assert(w.state.sent==2 and encoded.embeds[1].image==nil)
inventory={{CardID=3,Border='Normal',Count=8},{CardID=5,Border='Normal',Count=1}}
now+=11;response='error';w.tick();count=#requests
now+=11;w.tick();assert(#requests==count and w.state.failed==1,'uncertain delivery is not retried')
assert(not w.state.status:find('private',1,true))
w.enable(false);response={StatusCode=204};assert(w.test());w.tick();assert(#requests==count+1)
w.enable(true);now+=11;w.tick();assert(#requests==count+1,'re-enable establishes a fresh baseline')
w.stop();count=#requests;now+=20;w.tick();assert(#requests==count and not w.state.hasEndpoint)
w.enable(true);assert(not w.setEndpoint('https://discord.com/api/webhooks/123/test') and not w.test())
local restored=createPullWebhook()
assert(restored.state.hasEndpoint and restored.state.endpointSaved,'URL restores after script restart')
assert(restored.setEndpoint('') and savedJSON.url=='','CLEAR URL overwrites saved secret')
local cleared=createPullWebhook();assert(not cleared.state.hasEndpoint,'cleared secret cannot reappear on restart')
diskFailure=true
assert(cleared.setEndpoint('https://discord.com/api/webhooks/123/test') and not cleared.state.endpointSaved,'save failure keeps session URL but reports failure')
restored.stop();cleared.stop()
-- Mutating the endpoint during the thumbnail request must abort BEFORE POST.
diskFailure=false
local race=createPullWebhook();race.setEndpoint('https://discord.com/api/webhooks/123/old-token')
inventory={['3']={counts={Normal=1}}};race.enable(true);race.tick()
inventory={['3']={counts={Normal=2}}}
onThumbnail=function() race.setEndpoint('https://discord.com/api/webhooks/456/new-token') end
local before=#requests;now+=11;race.tick();onThumbnail=nil
assert(#requests==before,'old payload cannot be sent to new destination after thumbnail yield')
-- Reconnect notifications use saved endpoint even with rare-card notifications OFF.
race.enable(false)
assert(race.reconnect({attempt=2,reason='Account opened elsewhere',status='Reconnect attempt started'}))
race.tick()
assert(#requests==before+1 and requests[#requests].Url:find('/456/new-token',1,true))
assert(encoded.embeds[1].title=='Anime Origin · Reconnect attempt' and race.state.sent==0)
assert(race.state.status=='Reconnect notification delivered')
race.stop()
print('PASS: endpoint persistence, restore, clear, save failure; all-source inventory gains, baseline, polling, duplicate suppression, border conversions, strict base rarity, images, rate limits, cleanup')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='pull-webhook-test-') as d:
 p=Path(d)/'pull.luau';p.write_text(mock+controller+checks);subprocess.run([binary,str(p)],check=True)

