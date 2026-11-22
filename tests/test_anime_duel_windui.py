from pathlib import Path
import ast,os
p=Path(__file__).with_name('test_anime_duel.py');source=p.read_text()
source=source.replace("src=(root/'anime_duel_script.lua').read_text()", "src=(root/'anime_duel_windui.lua').read_text()")
start=source.index('def run_case(');end=source.index("\nrun_case(",start)
fn='''def run_case(name,fixture,assertions):
    if name!='Wind native bindings' and any(x in assertions for x in ['objects','app.Root','app.ui','loadScript','maintenance[','UI object','uiObject(']): return
    if any(x in name.lower() for x in ['ui','library','font','theme','mobile','prism','sidebar','button','toggle-only']): return
    import tempfile,subprocess
    with tempfile.TemporaryDirectory() as d:
        path=Path(d)/'test.luau'
        path.write_text(fixture+'\\n'+windmock+'\\nlocal function loadScript()\\n'+src+'\\nend\\nloadScript()\\n'+assertions)
        result=subprocess.run([binary,str(path)],capture_output=True,text=True)
        if result.returncode: print(name,result.stdout,result.stderr);raise SystemExit(result.returncode)
        print('PASS',name)
'''
source=source[:start]+fn+source[end:]
windmock=r'''
local windObjects={}
local function container(kind,config)
 local obj={kind=kind,config=config or {},UIElements={Main=Instance.new('Frame')}}
 windObjects[#windObjects+1]=obj
 for _,method in ipairs({'Tab','Section','Toggle','Dropdown','Paragraph','Button','Input','Slider'}) do
  obj[method]=function(_,c)return container(method,c)end
 end
 function obj:Set(value,callback)self.value=value;if callback~=false and self.config.Callback then self.config.Callback(value)end end
 function obj:Select(value)self.value=value;if value~=nil and self.config.Callback then self.config.Callback(value)end end
 function obj:Refresh(values)self.values=values end
 function obj:SetTitle(v)self.title=v end
 function obj:SetDesc(v)self.desc=v end
 function obj:SetThumbnail(v)self.image=v end
 function obj:SetBackgroundTransparency(v)self.transparency=v end
 function obj:OnDestroy(cb)self.onDestroy=cb end
 function obj:Destroy()self.UIElements.Main:Destroy();if self.onDestroy then self.onDestroy()end end
 return obj
end
local wind={CreateWindow=function(_,c)return container('Window',c)end,SetTheme=function()end,AddTheme=function()end,Notify=function()end}
function game:HttpGet(url)assert(url:find('1.6.66',1,true));return 'test' end
local function loadstring(_)return function()return wind end end
'''
# Original initial standalone test is excluded since it asserts the previous UI.
a=source.index("run_case('UI, preparation,");b=source.index('\n',a);source=source[:a]+source[b:]
ns={'__file__':str(p),'windmock':windmock};exec(compile(source,str(p),'exec'),ns)
ns['run_case']('Wind native bindings',ns['mock'],r'''
local app=env.AnimeDuelScript
local toggles=0
for _,o in ipairs(windObjects)do if o.kind=='Toggle' then
 if o.config.Title=='Auto Story Boss' or o.config.Title=='Auto Dungeon' then toggles=toggles+1 end
end end
assert(toggles==2 and not app.uiError,tostring(app.uiError))
assert(app.ui.Library==wind)
assert(app.config.dungeonTeam=='blonde_commander_rainbow,blue_duo_gold,first_emperor_gold,rose_evil_roku_gold','saved team preserved on UI creation')
app.destroy()
''')
