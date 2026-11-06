"""Verify personal roll filtering and notification delivery without network IO."""
from pathlib import Path
import os,shutil,subprocess,tempfile
main=(Path(__file__).resolve().parents[1]/'cardorrigin.lua').read_text()
controller=main[main.index('local function createPullWebhook()'):main.index('local pullWebhook=createPullWebhook()')]
mock=r'''
local now=100
local os={clock=function() return now end}
local state={alive=true}
local player={Name='TestPlayer'}
local task={spawn=function() end,wait=function() end}
local listener=nil
local disconnected=0
local signal={Connect=function(_,fn) listener=fn;return {Disconnect=function() listener=nil;disconnected+=1 end} end}
local roll={IsA=function(_,kind) return kind=='RemoteEvent' end,OnClientEvent=signal}
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
 if name=='EventRemotes' then return {FindFirstChild=function(_,key) assert(key=='RollRequest');return roll end} end
 if name=='CardImages' then return {GetImage=function(id) return id==3 and 'rbxassetid://12345' or 'rbxasset://textures/ui/GuiImagePlaceholder.png' end} end
 if name=='GameDatabase' then return {FindFirstChild=function() return db end} end
end}
local encoded
local HttpService={JSONEncode=function(_,value) encoded=value;return 'body' end,JSONDecode=function(_,body) if body=='image' then return {data={{state='Completed',imageUrl='https://tr.rbxcdn.com/card.png'}}} end;return {retry_after=2} end}
local requests={}
local response={StatusCode=204}
local request=function(options) if options.Method=='GET' then assert(options.Url:find('assetIds=12345',1,true));return {StatusCode=200,Body='image'} end;requests[#requests+1]=options;if response=='error' then error('private URL error') end;return response end
'''
checks=r'''
local w=createPullWebhook()
w.enable(true);local initial=listener;w.enable(true)
assert(listener==initial,'no duplicate listener on profile updates')
assert(not w.setEndpoint('http://discord.com/api/webhooks/123/test'))
assert(not w.setEndpoint('https://discord.com.evil.test/api/webhooks/123/test'))
assert(w.setEndpoint('https://discord.com/api/webhooks/123/test-token'))
listener({CardID=1,Border='Origin'});listener({CardID=2,Border='Origin'});listener({CardID=4});listener({CardID='missing'})
w.tick();assert(#requests==0 and w.state.matched==0,'base-only strictly above 1B; unknown rarities ignored')
listener({CardID=3,Name='Untrusted name',Border='Gold'})
w.tick();assert(#requests==1 and w.state.sent==1 and w.state.matched==1)
assert(encoded.embeds[1].fields[2].value=='Above','database supplies card identity')
assert(encoded.embeds[1].fields[3].value=='1/1,000,000,001' and encoded.embeds[1].fields[4].value=='Calamity')
assert(encoded.embeds[1].image.url=='https://tr.rbxcdn.com/card.png','card art uses its own asset ID')
assert(encoded.allowed_mentions and #encoded.allowed_mentions.parse==0,'no Discord pings')
listener({CardID=5,Border='Normal'});response={StatusCode=429,Body='retry'};now+=3;w.tick()
local count=#requests;w.tick();assert(#requests==count and w.state.failed==0)
now+=2.1;response={StatusCode=204};w.tick();assert(w.state.sent==2,'retry explicit rate limits');assert(encoded.embeds[1].image==nil,'missing art does not block notification')
listener({CardID=3});now+=3;response='error';w.tick()
count=#requests;now+=10;w.tick();assert(#requests==count and w.state.failed==1,'uncertain delivery is not retried')
assert(not w.state.status:find('private',1,true),'never reveal raw URL errors')
listener({CardID=3});w.setEndpoint('https://discord.com/api/webhooks/456/replaced');now+=3;w.tick()
assert(#requests==count,'URL changes clear previously queued messages')
w.enable(false);assert(listener==nil)
response={StatusCode=204};assert(w.test());w.tick();assert(#requests==count+1 and w.state.sent==2,'manual test works while alerts are off and does not inflate pull totals')
w.stop();count=#requests;now+=20;w.tick();assert(#requests==count and not w.state.hasEndpoint)
w.enable(true);assert(listener==nil and not w.setEndpoint('https://discord.com/api/webhooks/123/test') and not w.test(),'stopped controller cannot restart')
assert(disconnected==1)
print('PASS: personal event, strict base rarity, border excluded, endpoint validation, payload, rate limits, no uncertain retries, URL redaction, disable/test/stop cleanup')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary:raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory(prefix='pull-webhook-test-') as d:
 p=Path(d)/'pull.luau';p.write_text(mock+controller+checks);subprocess.run([binary,str(p)],check=True)
