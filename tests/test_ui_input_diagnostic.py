"""Diagnostic must observe native UI without mutating it or invoking remotes."""
from pathlib import Path
import os, shutil, subprocess, tempfile
source=(Path(__file__).resolve().parents[1]/'ui_input_diagnostic.lua').read_text()
mock=r'''
local connections={}
local function signal()
 local s={}
 function s:Connect(fn)
  local c={Connected=true,fn=fn,Disconnect=function(self) self.Connected=false end}
  connections[#connections+1]=c;self[#self+1]=c;return c
 end
 function s:Fire(...) for _,c in ipairs(self) do if c.Connected then c.fn(...) end end end
 return s
end
local function object(values)
 local signals={}
 values.GetPropertyChangedSignal=function(_,key) signals[key]=signals[key] or signal();return signals[key] end
 values.GetFullName=function() return values.Name end
 values.IsA=function(_,class) return values.ClassName==class or class=='GuiObject' and values.ClassName=='Frame' end
 values.GetChildren=function() return values.children or {} end
 return setmetatable({}, {__index=values,__newindex=function() error('diagnostic mutated native object') end}),signals
end
local panel=object({Name='HUD.Panel',ClassName='Frame',Visible=true,Active=true})
local hud,hudSignals=object({Name='HUD',ClassName='ScreenGui',Enabled=true,children={panel}})
local pg=object({Name='PlayerGui',children={hud},ChildAdded=signal(),ChildRemoved=signal()})
local uis=object({Name='UIS',TouchEnabled=true,ModalEnabled=false,InputBegan=signal(),GetFocusedTextBox=function() return nil end})
local gs=object({Name='GuiService',SelectedObject=nil,GuiNavigationEnabled=true})
local env={}
local getgenv=function() return env end
local encoded=nil
local http={JSONEncode=function(_,data) encoded=data;return 'json' end}
local player={WaitForChild=function(_,name) assert(name=='PlayerGui');return pg end}
local game={GetService=function(_,name)
 if name=='Players' then return {LocalPlayer=player} end
 if name=='HttpService' then return http end
 if name=='UserInputService' then return uis end
 assert(name=='GuiService');return gs
end}
local Enum={UserInputType={Touch='Touch'}}
local saves=0
local writefile=function(path,data) assert(path=='anime_origin_ui_diagnostic.json' and data=='json');saves+=1 end
'''
checks=r'''
local d=env.AnimeOriginUIDiagnostic
assert(d.active and saves==0)
local count=#d.records
hudSignals.Enabled:Fire();assert(#d.records==count+1)
uis.InputBegan:Fire({UserInputType='Touch'},true)
assert(d.records[#d.records].kind=='touch' and d.records[#d.records].data.processed)
d.stop();assert(not d.active and saves==1 and encoded[#encoded].data.label=='stop')
for _,c in ipairs(connections) do assert(not c.Connected) end
count=#d.records;hudSignals.Enabled:Fire();assert(#d.records==count)
assert(hud.Enabled and panel.Visible and gs.GuiNavigationEnabled,'native properties unchanged')
print('PASS: read-only diagnostic snapshots, property/touch events, manual export, cleanup; zero game UI writes or remote calls')
'''
binary=os.environ.get('LUAU_BIN') or shutil.which('luau')
if not binary: raise SystemExit('Set LUAU_BIN or add luau to PATH')
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'diagnostic.luau';p.write_text(mock+source+checks)
 subprocess.run([binary,str(p)],check=True)
