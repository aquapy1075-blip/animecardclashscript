-- Anime Origin UI library. Rendering only; gameplay stays in cardorrigin.lua.
local Library={Version=1}
function Library.Create(ctx)
local profile=ctx.profile
local repaintControls=function() end
local playerGui=ctx.playerGui
local state=ctx.state
local flags=ctx.flags
local cfg=ctx.cfg
local Workspace=ctx.Workspace
local env=ctx.env
local UIS=ctx.UIS
local rift=ctx.rift
local boss=ctx.boss
local raid=ctx.raid
local siege=ctx.siege
local reconnect=ctx.reconnect
local handoff=ctx.handoff
local setFlag=ctx.setFlag
local applyFlags=ctx.applyFlags
local requestReconnect=ctx.requestReconnect
local loadIndex=ctx.loadIndex
local saveProfile=ctx.saveProfile
local loadProfile=ctx.loadProfile
local deleteProfile=ctx.deleteProfile
local setAutoProfile=ctx.setAutoProfile
local markCurrentForNextExecute=ctx.markCurrentForNextExecute
local themes={
    Midnight={bg='0D1320',side='101A2B',panel='172338',row='22334D',text='EFF5FF',muted='96ABC8',accent='8BAFFF',line='2B405D'},
    Ocean={bg='0D1922',side='112635',panel='173247',row='204159',text='ECFAFF',muted='9BBCCC',accent='53C8E6',line='325267'},
    Violet={bg='171322',side='20192E',panel='2B213C',row='392C50',text='F6EFFF',muted='B8A8D4',accent='BC8AFF',line='534267'},
    Emerald={bg='101C18',side='152B24',panel='1C372D',row='29463A',text='EFFFF4',muted='A0C8B0',accent='60D8A8',line='3E6454'},
    Rose={bg='23171C',side='311D27',panel='3E2633',row='503442',text='FFEFF4',muted='D9A9BC',accent='FF8FB2',line='704859'},
}
local function rgb(hex)
    return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
end
local themeColors={}
local skinned=setmetatable({}, {__mode='k'})
local surfaces=setmetatable({}, {__mode='k'})
local transparency=-1
local updateTransparencyLabel=function() end
local function transparencyValue()
    local value=tonumber(flags.AO_UI_Transparency) or 15
    if value~=value then value=15 end
    return math.clamp(value,0,65)/100
end
local function applyTransparency()
    local value=transparencyValue()
    if value==transparency then return end
    transparency=value
    for obj,base in pairs(surfaces) do
        if obj.Parent then obj.BackgroundTransparency=base+(1-base)*value end
    end
    updateTransparencyLabel(value)
end
local function color(role)
    return themeColors[role] or Color3.fromRGB(255,255,255)
end
local function skin(obj,property,role)
    skinned[obj]=skinned[obj] or {}
    skinned[obj][property]=role
    obj[property]=color(role)
    return obj
end
local function make(class,parent,props)
    local obj=Instance.new(class)
    for key,value in pairs(props or {}) do obj[key]=value end
    obj.Parent=parent
    if obj:IsA('GuiObject') and obj.BackgroundTransparency<1 then
        local base=obj.BackgroundTransparency
        surfaces[obj]=base
        obj.BackgroundTransparency=base+(1-base)*transparencyValue()
    end
    return obj
end
local function corner(obj,size)
    make('UICorner',obj,{CornerRadius=UDim.new(0,size or 9)})
end
local function stroke(obj)
    local s=make('UIStroke',obj,{Thickness=1,Transparency=0.15})
    skin(s,'Color','line')
end
local function newText(parent,label,size,bold)
    local l=make('TextLabel',parent,{
        BackgroundTransparency=1,Text=tostring(label),
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 13,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0,
    })
    skin(l,'TextColor3',bold and 'text' or 'muted')
    return l
end
local function uiButton(parent,caption,size)
    local b=make('TextButton',parent,{
        Text=caption,Size=size or UDim2.fromOffset(135,32),
        BackgroundTransparency=0,BorderSizePixel=0,
        Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=true,
        TextTruncate=Enum.TextTruncate.AtEnd,
    })
    corner(b,8)
    skin(b,'BackgroundColor3','row')
    skin(b,'TextColor3','text')
    return b
end

local root=make('ScreenGui',playerGui,{
    Name='AnimeOriginV10_7_UI',ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9900,
})
state.gui=root
local main=make('Frame',root,{
    Size=UDim2.fromOffset(805,565),Position=UDim2.new(.5,-402,.5,-282),
    BorderSizePixel=0,BackgroundTransparency=0,
})
corner(main,18)
skin(main,'BackgroundColor3','bg')
stroke(main)
local accentLine=make('Frame',main,{
    Position=UDim2.fromOffset(18,0),Size=UDim2.new(1,-36,0,2),BorderSizePixel=0,
})
skin(accentLine,'BackgroundColor3','accent')
make('UIGradient',accentLine,{Transparency=NumberSequence.new(0,.85)})
local scale=make('UIScale',main,{Scale=1})
local function sizeForDevice()
    local camera=Workspace.CurrentCamera
    if not camera then return end
    local view=camera.ViewportSize
    local n=math.min(1,(view.X-24)/825,(view.Y-24)/585)
    scale.Scale=math.max(.53,n)
    main.Position=UDim2.new(.5,-402*scale.Scale,.5,-282*scale.Scale)
end
sizeForDevice()
if Workspace.CurrentCamera then
    local camera=Workspace.CurrentCamera
    local c=camera:GetPropertyChangedSignal('ViewportSize'):Connect(sizeForDevice)
    state.connections=state.connections or {}
    state.connections[#state.connections+1]=c
end
local header=make('Frame',main,{
    Size=UDim2.new(1,0,0,57),BackgroundTransparency=1,
})
local iconTile=make('Frame',header,{
    Position=UDim2.fromOffset(16,12),Size=UDim2.fromOffset(34,34),BorderSizePixel=0,
})
corner(iconTile,10)
skin(iconTile,'BackgroundColor3','accent')
local monogram=newText(iconTile,'AO',12,true)
skin(monogram,'TextColor3','bg')
monogram.TextXAlignment=Enum.TextXAlignment.Center
monogram.Size=UDim2.fromScale(1,1)
local bigTitle=newText(header,'ANIME ORIGIN',17,true)
bigTitle.Position=UDim2.fromOffset(62,10)
bigTitle.Size=UDim2.fromOffset(250,22)
local smallTitle=newText(header,'CONTROL CENTER  /  REMOTE EDITION',11,false)
smallTitle.Position=UDim2.fromOffset(63,32)
smallTitle.Size=UDim2.fromOffset(260,16)
local sessionBadge=newText(header,'● READY',11,true)
sessionBadge.Position=UDim2.new(1,-190,0,20)
sessionBadge.Size=UDim2.fromOffset(105,20)
local hide=uiButton(header,'—',UDim2.fromOffset(30,28))
hide.Position=UDim2.new(1,-77,0,14)
local dismiss=uiButton(header,'×',UDim2.fromOffset(30,28))
dismiss.Position=UDim2.new(1,-42,0,14)

local sidebar=make('Frame',main,{
    Position=UDim2.fromOffset(0,57),Size=UDim2.new(0,174,1,-57),BorderSizePixel=0,
})
skin(sidebar,'BackgroundColor3','side')
local divider=make('Frame',main,{
    Position=UDim2.fromOffset(173,57),Size=UDim2.new(0,1,1,-57),BorderSizePixel=0,
})
skin(divider,'BackgroundColor3','line')
make('UIListLayout',sidebar,{
    Padding=UDim.new(0,8),FillDirection=Enum.FillDirection.Vertical,
    HorizontalAlignment=Enum.HorizontalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder,
})
make('UIPadding',sidebar,{PaddingTop=UDim.new(0,22)})
local body=make('Frame',main,{
    Position=UDim2.fromOffset(175,57),Size=UDim2.new(1,-175,1,-57),
    BackgroundTransparency=1,ClipsDescendants=true,
})
local selectedTab='Colosseum'
local navButtons={}
local tabPages={}
local tabNames={'Colosseum','Rift Gate','Multi-Boss','Raid','Siege','Settings','Config'}
for i,name in ipairs(tabNames) do
    local tab=uiButton(sidebar,string.format('%02d   %s',i,name),UDim2.new(1,-20,0,39))
    tab.LayoutOrder=i
    tab.TextXAlignment=Enum.TextXAlignment.Left
    make('UIPadding',tab,{PaddingLeft=UDim.new(0,14)})
    navButtons[name]=tab
    local page=make('ScrollingFrame',body,{
        Name=name,Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,BorderSizePixel=0,Visible=name==selectedTab,
        CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=4,ScrollBarImageTransparency=.25,
    })
    skin(page,'ScrollBarImageColor3','accent')
    make('UIPadding',page,{
        PaddingTop=UDim.new(0,14),PaddingBottom=UDim.new(0,16),
        PaddingLeft=UDim.new(0,18),PaddingRight=UDim.new(0,19),
    })
    make('UIListLayout',page,{
        Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder,
    })
    tabPages[name]=page
    tab.MouseButton1Click:Connect(function()
        selectedTab=name
        smallTitle.Text='CONTROL CENTER  /  '..string.upper(name)
        for title,p in pairs(tabPages) do p.Visible=(title==name) end
        repaintControls()
    end)
end
local widgets={}
local statusLabels={}
local orderCounter=0
local function section(tab,label)
    orderCounter=orderCounter+1
    local t=newText(tabPages[tab],string.upper(label),12,true)
    t.Size=UDim2.new(1,0,0,30)
    t.LayoutOrder=orderCounter
    return t
end
local function row(tab,label)
    orderCounter=orderCounter+1
    local parent=tabPages[tab]
    local r=make('Frame',parent,{
        Size=UDim2.new(1,-2,0,49),BorderSizePixel=0,
        LayoutOrder=orderCounter,
    })
    corner(r,9)
    skin(r,'BackgroundColor3','panel')
    local nameLabel=newText(r,label,13,true)
    nameLabel.Position=UDim2.fromOffset(14,0)
    nameLabel.Size=UDim2.new(1,-221,1,0)
    return r
end
local function addStatus(tab,label,initial)
    local r=row(tab,label)
    local s=newText(r,initial or '--',12,false)
    s.Position=UDim2.new(1,-260,0,0)
    s.Size=UDim2.new(0,246,1,0)
    s.TextXAlignment=Enum.TextXAlignment.Right
    statusLabels[label]=s
    return s
end
local function addToggle(tab,label,key)
    local r=row(tab,label)
    local b=uiButton(r,'OFF',UDim2.fromOffset(94,31))
    b.Position=UDim2.new(1,-109,.5,-15)
    b.MouseButton1Click:Connect(function() setFlag(key,not flags[key]) end)
    widgets[#widgets+1]=function()
        local on=flags[key]==true
        b.Text=on and 'ON  ●' or 'OFF  ○'
        b.BackgroundColor3=on and color('accent') or color('row')
        b.TextColor3=on and color('bg') or color('muted')
    end
    return b
end

local menu=make('Frame',root,{
    Visible=false,Size=UDim2.fromOffset(184,0),BorderSizePixel=0,
    BackgroundTransparency=0,ZIndex=150,
})
corner(menu,10)
skin(menu,'BackgroundColor3','side')
stroke(menu)
local function hideMenu() menu.Visible=false end
local function openMenu(anchor,options,choose)
    for _,child in ipairs(menu:GetChildren()) do
        if child:IsA('GuiButton') then child:Destroy() end
    end
    if #options==0 then options={'(empty)'} end
    local height=#options*35+10
    local position=anchor.AbsolutePosition
    local camera=Workspace.CurrentCamera
    local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
    local top=position.Y+anchor.AbsoluteSize.Y+4
    if top+height>viewport.Y-8 then top=math.max(10,position.Y-height-4) end
    menu.Size=UDim2.fromOffset(184,height)
    menu.Position=UDim2.fromOffset(math.max(5,math.min(position.X,viewport.X-194)),top)
    for i,label in ipairs(options) do
        local choice=uiButton(menu,tostring(label),UDim2.fromOffset(174,31))
        choice.Position=UDim2.fromOffset(5,5+(i-1)*35)
        choice.ZIndex=152
        choice.MouseButton1Click:Connect(function()
            hideMenu()
            choose(i,label)
        end)
    end
    menu.Visible=true
end
local function addDropdown(tab,label,key,choices,indexed)
    local r=row(tab,label)
    local b=uiButton(r,'--  ▾',UDim2.fromOffset(180,31))
    b.Position=UDim2.new(1,-195,.5,-15)
    b.MouseButton1Click:Connect(function()
        if menu.Visible then hideMenu();return end
        openMenu(b,choices,function(index,value)
            setFlag(key,indexed and index or value)
        end)
    end)
    widgets[#widgets+1]=function()
        local v=flags[key]
        if indexed then v=choices[math.clamp(tonumber(v) or 1,1,#choices)] end
        b.Text=tostring(v or '--')..'  ▾'
    end
    return b
end
local function addInput(tab,label,key,placeholder)
    local r=row(tab,label)
    local box=make('TextBox',r,{
        Size=UDim2.fromOffset(180,31),Position=UDim2.new(1,-195,.5,-15),
        BackgroundTransparency=0,BorderSizePixel=0,TextSize=13,
        Font=Enum.Font.GothamMedium,PlaceholderText=placeholder or '',
        ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Center,
    })
    corner(box,8)
    skin(box,'BackgroundColor3','row')
    skin(box,'TextColor3','text')
    skin(box,'PlaceholderColor3','muted')
    box.FocusLost:Connect(function() setFlag(key,box.Text) end)
    widgets[#widgets+1]=function()
        if not box:IsFocused() then box.Text=tostring(flags[key] or '') end
    end
    return box
end
local function addAction(tab,label,caption,callback)
    local r=row(tab,label)
    local b=uiButton(r,caption,UDim2.fromOffset(180,31))
    b.Position=UDim2.new(1,-195,.5,-15)
    b.MouseButton1Click:Connect(callback)
    return b
end
local paintedTheme=nil
local paintedTab=nil
local paintedFlags={}
local function paintTheme()
    local theme=themes[flags.AO_UI_Theme] and flags.AO_UI_Theme or 'Midnight'
    if theme==paintedTheme then return false end
    paintedTheme=theme
    for role,hex in pairs(themes[theme]) do themeColors[role]=rgb(hex) end
    for obj,properties in pairs(skinned) do
        if obj.Parent then
            for property,role in pairs(properties) do obj[property]=color(role) end
        end
    end
    return true
end
repaintControls=function()
    local themeChanged=paintTheme()
    local dirty=themeChanged
    for key,value in pairs(flags) do
        if key~='AO_UI_Transparency' and paintedFlags[key]~=value then dirty=true end
        paintedFlags[key]=value
    end
    if themeChanged or paintedTab~=selectedTab then
        paintedTab=selectedTab
        for title,b in pairs(navButtons) do
            b.BackgroundColor3=(title==selectedTab) and color('accent') or color('side')
            b.TextColor3=(title==selectedTab) and color('bg') or color('muted')
        end
    end
    applyTransparency()
    if dirty then for _,fn in ipairs(widgets) do fn() end end
end

section('Colosseum','Colosseum')
addToggle('Colosseum','Auto Colosseum','AO_AutoColosseum')
addStatus('Colosseum','Mode','Remote / no UI / no replay')
addToggle('Colosseum','Hell Mode','AO_Colo_Hell')
addToggle('Colosseum','Endless Mode','AO_Colo_Endless')
addInput('Colosseum','Stop Floor','AO_Colo_StopFloor','35 or 30-40')
section('Colosseum','Live Status')
local colStatus=addStatus('Colosseum','Colo status','OFF')
local colCarry=addStatus('Colosseum','Carry','--')
local colProgress=addStatus('Colosseum','PB / Curse / Floor','--')

section('Rift Gate','Rift Gate')
addToggle('Rift Gate','Auto Rift','AO_AutoRift')
addToggle('Rift Gate','Walk to NPC','AO_Rift_Walk')
addToggle('Rift Gate','Auto Leave','AO_Rift_Leave')
section('Rift Gate','Live Status')
local riftStatus=addStatus('Rift Gate','Rift status','OFF')
local riftTimer=addStatus('Rift Gate','Next Rift','READY')
local riftClears=addStatus('Rift Gate','Clears','0')

section('Multi-Boss','Multi-Boss')
addToggle('Multi-Boss','Auto Boss','AO_AutoBoss')
local bossStatus=addStatus('Multi-Boss','Boss status','OFF')
for _,b in ipairs(boss.bosses) do
    orderCounter=orderCounter+1
    local r=make('Frame',tabPages['Multi-Boss'],{
        Size=UDim2.new(1,-2,0,51),BorderSizePixel=0,LayoutOrder=orderCounter,
    })
    corner(r,9)
    skin(r,'BackgroundColor3','panel')
    local name=newText(r,b.name,13,true)
    name.Position=UDim2.fromOffset(12,0)
    name.Size=UDim2.fromOffset(117,51)
    local toggle=uiButton(r,'OFF',UDim2.fromOffset(61,29))
    toggle.Position=UDim2.fromOffset(132,11)
    local dropdown=uiButton(r,'Normal ▾',UDim2.fromOffset(136,29))
    dropdown.Position=UDim2.fromOffset(204,11)
    local timer=newText(r,'CHECKING',12,true)
    timer.Position=UDim2.new(1,-140,0,0)
    timer.Size=UDim2.fromOffset(128,51)
    timer.TextXAlignment=Enum.TextXAlignment.Right
    toggle.MouseButton1Click:Connect(function()
        setFlag('AO_Boss_'..b.id,not flags['AO_Boss_'..b.id])
    end)
    dropdown.MouseButton1Click:Connect(function()
        if menu.Visible then hideMenu();return end
        openMenu(dropdown,boss.borders,function(index)
            setFlag('AO_Border_'..b.id,index)
        end)
    end)
    widgets[#widgets+1]=function()
        local on=flags['AO_Boss_'..b.id]==true
        toggle.Text=on and 'ON' or 'OFF'
        toggle.BackgroundColor3=on and color('accent') or color('row')
        toggle.TextColor3=on and color('bg') or color('muted')
        dropdown.Text=boss.borders[math.clamp(tonumber(flags['AO_Border_'..b.id]) or 1,1,6)]..' ▾'
    end
    b.displayCooldown=timer
end
local bossCounts=addStatus('Multi-Boss','Wins / Losses','0 / 0')

section('Raid','Auto Raid')
addToggle('Raid','Auto Raid','AO_AutoRaid')
local raidStatus=addStatus('Raid','Raid status','OFF')
section('Raid','Select Stages')
for _,stage in ipairs(raid.stages) do
    orderCounter=orderCounter+1
    local item=make('Frame',tabPages['Raid'],{
        Size=UDim2.new(1,-2,0,49),BorderSizePixel=0,LayoutOrder=orderCounter,
    })
    corner(item,9)
    skin(item,'BackgroundColor3','panel')
    local label=newText(item,'Stage '..stage.index..' - '..stage.name,13,true)
    label.Position=UDim2.fromOffset(14,0)
    label.Size=UDim2.new(1,-245,1,0)
    local timer=newText(item,'SYNC',12,true)
    timer.Position=UDim2.new(1,-229,0,0)
    timer.Size=UDim2.fromOffset(112,49)
    timer.TextXAlignment=Enum.TextXAlignment.Right
    local toggle=uiButton(item,'OFF',UDim2.fromOffset(94,31))
    toggle.Position=UDim2.new(1,-109,.5,-15)
    local key='AO_Raid_Stage_'..stage.index
    toggle.MouseButton1Click:Connect(function() setFlag(key,not flags[key]) end)
    widgets[#widgets+1]=function()
        local enabled=flags[key]==true
        toggle.Text=enabled and 'ON  ●' or 'OFF  ○'
        toggle.BackgroundColor3=enabled and color('accent') or color('row')
        toggle.TextColor3=enabled and color('bg') or color('muted')
    end
    stage.displayCooldown=timer
end
local raidCounts=addStatus('Raid','Wins / Losses','0 / 0')

section('Siege','Auto Siege — Round Robin')
addToggle('Siege','Auto Siege','AO_AutoSiege')
local siegeStatus=addStatus('Siege','Siege status','OFF')
local siegeCounts=addStatus('Siege','Wins / Losses','0 / 0')
section('Siege','Select multiple stages (1–12)')
for _,stage in ipairs(siege.stages) do
    orderCounter=orderCounter+1
    local item=make('Frame',tabPages['Siege'],{
        Size=UDim2.new(1,-2,0,49),BorderSizePixel=0,LayoutOrder=orderCounter,
    })
    corner(item,9);skin(item,'BackgroundColor3','panel')
    local label=newText(item,string.format('%02d  %s',stage.index,stage.name),12,true)
    label.Position=UDim2.fromOffset(14,0)
    label.Size=UDim2.new(1,-238,1,0)
    local timer=newText(item,'SYNC',12,true)
    timer.Position=UDim2.new(1,-227,0,0)
    timer.Size=UDim2.fromOffset(110,49)
    timer.TextXAlignment=Enum.TextXAlignment.Right
    local toggle=uiButton(item,'OFF',UDim2.fromOffset(91,31))
    toggle.Position=UDim2.new(1,-107,.5,-15)
    local key='AO_Siege_Stage_'..stage.index
    toggle.MouseButton1Click:Connect(function() setFlag(key,not flags[key]) end)
    widgets[#widgets+1]=function()
        local on=flags[key]==true
        toggle.Text=on and 'ON  ●' or 'OFF  ○'
        toggle.BackgroundColor3=on and color('accent') or color('row')
        toggle.TextColor3=on and color('bg') or color('muted')
    end
    stage.displayCooldown=timer
end

section('Settings','Appearance')
addDropdown('Settings','Theme','AO_UI_Theme',{'Midnight','Ocean','Violet','Emerald','Rose'},false)
local transparencyRow=row('Settings','Transparency')
local transparencyText=newText(transparencyRow,'15%',12,true)
transparencyText.Position=UDim2.new(1,-60,0,0)
transparencyText.Size=UDim2.new(0,46,1,0)
transparencyText.TextXAlignment=Enum.TextXAlignment.Right
local slider=make('TextButton',transparencyRow,{
    Name='TransparencySlider',Text='',AutoButtonColor=false,
    BackgroundTransparency=1,Position=UDim2.new(1,-245,.5,-16),
    Size=UDim2.fromOffset(170,32),BorderSizePixel=0,
})
local track=make('Frame',slider,{
    Position=UDim2.new(0,0,.5,-3),Size=UDim2.new(1,0,0,6),BorderSizePixel=0,
})
corner(track,3);skin(track,'BackgroundColor3','row')
local fill=make('Frame',track,{Size=UDim2.new(15/65,0,1,0),BorderSizePixel=0})
corner(fill,3);skin(fill,'BackgroundColor3','accent')
local knob=make('Frame',slider,{
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(15/65,0,.5,0),
    Size=UDim2.fromOffset(14,14),BorderSizePixel=0,
})
corner(knob,7);skin(knob,'BackgroundColor3','accent')
updateTransparencyLabel=function(value)
    local ratio=value/.65
    transparencyText.Text=tostring(math.floor(value*100+.5))..'%'
    fill.Size=UDim2.new(ratio,0,1,0)
    knob.Position=UDim2.new(ratio,0,.5,0)
end
local sliderInput=nil
local function adjustTransparency(x)
    if slider.AbsoluteSize.X<=0 then return end
    local ratio=math.clamp((x-slider.AbsolutePosition.X)/slider.AbsoluteSize.X,0,1)
    local value=math.floor(ratio*65+.5)
    if value~=flags.AO_UI_Transparency then setFlag('AO_UI_Transparency',value) end
end
slider.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
        sliderInput=input
        adjustTransparency(input.Position.X)
    end
end)
state.connections=state.connections or {}
state.connections[#state.connections+1]=UIS.InputChanged:Connect(function(input)
    if sliderInput and (input==sliderInput or input.UserInputType==Enum.UserInputType.MouseMovement) then
        adjustTransparency(input.Position.X)
    end
end)
state.connections[#state.connections+1]=UIS.InputEnded:Connect(function(input)
    if input==sliderInput then sliderInput=nil end
end)
section('Settings','Connection')
addToggle('Settings','Auto Reconnect','AO_Reconnect')
local reconnectStatus=addStatus('Settings','Reconnect','Monitoring')
addAction('Settings','Reconnect Now','REJOIN',function()
    reconnect.attempts=0
    reconnect.lastTry=-math.huge
    requestReconnect(true)
end)
section('Settings','Session')
addAction('Settings','Stop Script','STOP SCRIPT',function()
    state.stop()
    if env.AnimeOriginV10_7==state then env.AnimeOriginV10_7=nil end
    if root.Parent then root:Destroy() end
end)

section('Config','Profiles')
local configRow=row('Config','Config Name')
local nameInput=make('TextBox',configRow,{
    Size=UDim2.fromOffset(180,31),Position=UDim2.new(1,-195,.5,-15),
    Font=Enum.Font.GothamMedium,TextSize=13,BorderSizePixel=0,
    BackgroundTransparency=0,Text=profile.currentProfile,ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Center,
})
corner(nameInput,8)
skin(nameInput,'BackgroundColor3','row')
skin(nameInput,'TextColor3','text')
local savedDrop
savedDrop=addAction('Config','Saved Config','SELECT  ▾',function()
    if menu.Visible then hideMenu();return end
    loadIndex()
    openMenu(savedDrop,profile.storedNames,function(index,name)
        if name~='(empty)' then
            profile.currentProfile=name
            nameInput.Text=name
            profile.configStatus='Selected: '..name
        end
    end)
end)
addAction('Config','Save','SAVE',function()
    profile.revision=profile.revision+1
    if saveProfile(nameInput.Text) then
        nameInput.Text=profile.currentProfile
        if markCurrentForNextExecute() then
            profile.configStatus='Saved + will Auto Load: '..profile.currentProfile
        end
    end
end)
addAction('Config','Load','LOAD',function()
    profile.revision=profile.revision+1
    if loadProfile(nameInput.Text) then applyFlags();repaintControls() end
end)
addAction('Config','Delete','DELETE',function()
    profile.revision=profile.revision+1
    if deleteProfile(nameInput.Text) then nameInput.Text=profile.currentProfile end
end)
addAction('Config','Set as Auto Load','SET AUTO LOAD',function()
    profile.revision=profile.revision+1
    if setAutoProfile(nameInput.Text) then nameInput.Text=profile.currentProfile end
end)
addAction('Config','Reload Auto Load','RELOAD',function()
    profile.revision=profile.revision+1
    if loadProfile(profile.autoProfile) then
        nameInput.Text=profile.currentProfile
        applyFlags()
        repaintControls()
    end
end)
section('Config','Profile Status')
local configCurrent=addStatus('Config','Auto Load Profile','Default')
local configResult=addStatus('Config','Storage','--')

-- Header drag; hide/minimize never stops an AUTO loop.
local dragging=false
local originMouse,originPosition,dragTouch
header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        dragTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
        originMouse=input.Position
        originPosition=main.Position
    end
end)
local dragMove=UIS.InputChanged:Connect(function(input)
    if dragging and (input==dragTouch or input.UserInputType==Enum.UserInputType.MouseMovement) then
        local delta=input.Position-originMouse
        main.Position=UDim2.new(originPosition.X.Scale,originPosition.X.Offset+delta.X,
            originPosition.Y.Scale,originPosition.Y.Offset+delta.Y)
    end
end)
local dragEnd=UIS.InputEnded:Connect(function(input)
    if input==dragTouch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false;dragTouch=nil
    end
end)
local hotkey=UIS.InputBegan:Connect(function(input,used)
    if not used and input.KeyCode==Enum.KeyCode.RightShift and state.alive then
        root.Enabled=not root.Enabled
    end
end)
state.connections=state.connections or {}
for _,conn in ipairs({dragMove,dragEnd,hotkey}) do
    state.connections[#state.connections+1]=conn
end
hide.MouseButton1Click:Connect(function()
    local small=main.Size.Y.Offset<100
    main.Size=UDim2.fromOffset(805,small and 565 or 57)
    sidebar.Visible=small
    divider.Visible=small
    body.Visible=small
    hide.Text=small and '—' or '▢'
end)
dismiss.MouseButton1Click:Connect(function() root.Enabled=false end)
local stopEverything=state.stop
state.stop=function()
    stopEverything()
    for _,conn in ipairs(state.connections or {}) do pcall(function() conn:Disconnect() end) end
end
local function showStatus(widget,value)
    if widget and widget.Parent and widget.Text~=value then widget.Text=value end
end
local overviewLast=0
local function refreshOverview()
    if os.clock()-overviewLast<0.7 then return end
    overviewLast=os.clock()
    if not root.Parent or not root.Enabled or main.Size.Y.Offset<100 then return end
    local running=state.enabled or rift.state.on or boss.state.running or raid.state.on or siege.state.on
    showStatus(sessionBadge,running and '● RUNNING' or '○ STANDBY')
    local badgeColor=running and color('accent') or color('muted')
    if sessionBadge.TextColor3~=badgeColor then sessionBadge.TextColor3=badgeColor end
    local colLabel=state.blocked and ('PAUSED: '..tostring(state.blockedReason or 'Unknown'))
        or (state.enabled and (handoff.active and 'RIFT PRIORITY / Colo suspended'
            or handoff.returning and ('RESUME COLO / '..tostring(state.transportStatus))
            or tostring((state.phase~='' and state.phase) or state.transportStatus or 'ON')) or 'OFF')
    showStatus(colStatus,colLabel)
    showStatus(colCarry,tostring(state.carryName or '--')..'  /  Floor '..tostring(state.lastSeenWave))
    showStatus(colProgress,tostring(state.supportCount)..'/8  /  '..tostring(state.curseCount)..'/3  /  '..tostring(state.stopFloor or cfg.stopSpec))
    showStatus(riftStatus,(rift.state.on and 'ON / ' or 'OFF / ')..tostring(rift.state.status or 'WAITING'))
    showStatus(riftTimer,rift.cooldownText())
    showStatus(riftClears,tostring(rift.state.clears or 0))
    showStatus(bossStatus,(boss.state.running and 'ON / ' or 'OFF / ')..tostring(boss.state.status or '--'))
    showStatus(bossCounts,tostring(boss.state.wins)..' / '..tostring(boss.state.losses))
    showStatus(raidStatus,(raid.state.on and 'ON / ' or 'OFF / ')..tostring(raid.state.status))
    showStatus(raidCounts,tostring(raid.state.wins)..' / '..tostring(raid.state.losses))
    showStatus(siegeStatus,(siege.state.on and 'ON / ' or 'OFF / ')..tostring(siege.state.status))
    showStatus(siegeCounts,tostring(siege.state.wins)..' / '..tostring(siege.state.losses))
    if selectedTab=='Siege' then for _,stage in ipairs(siege.stages) do
        local cd=siege.cooldownText(stage)
        showStatus(stage.displayCooldown,cd)
        stage.displayCooldown.TextColor3=cd=='READY' and Color3.fromRGB(104,225,168)
            or cd=='LOCKED' and Color3.fromRGB(245,128,128) or color('muted')
    end
    end
    if selectedTab=='Raid' then for _,stage in ipairs(raid.stages) do
        local text=raid.cooldownText(stage)
        showStatus(stage.displayCooldown,text)
        stage.displayCooldown.TextColor3=text=='READY' and Color3.fromRGB(104,225,168)
            or text=='LOCKED' and Color3.fromRGB(245,128,128) or color('muted')
    end
    end
    if selectedTab=='Multi-Boss' then for _,b in ipairs(boss.bosses) do
        local cd=boss.cooldownText(b)
        showStatus(b.displayCooldown,cd)
        b.displayCooldown.TextColor3=(cd=='READY') and Color3.fromRGB(104,225,168)
            or (cd=='N/A' and Color3.fromRGB(245,128,128) or color('muted'))
    end
    end
    showStatus(reconnectStatus,tostring(state.reconnectStatus or reconnect.status or '--'))
    showStatus(configCurrent,tostring(profile.autoProfile))
    showStatus(configResult,profile.configStatus)
end
repaintControls()
refreshOverview()
return {Repaint=repaintControls,Refresh=refreshOverview,Root=root}
end
return Library
