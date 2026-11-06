-- Anime Origin UI library. Rendering only; gameplay stays in cardorrigin.lua.
local Library={Version=1}
function Library.Create(ctx)
local profile=ctx.profile
local repaintControls=function() end
local playerGui=ctx.playerGui
local state=ctx.state
if type(state.__animeUiDestroy)=='function' then state.__animeUiDestroy() end
local flags=ctx.flags
local cfg=ctx.cfg
local Workspace=ctx.Workspace
local env=ctx.env
local UIS=ctx.UIS
local GuiService=ctx.GuiService
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
local saveAppearance=ctx.saveAppearance or function() end
local lifecycle={alive=true,connections={},tweens=setmetatable({}, {__mode='k'})}
local TweenService=ctx.TweenService
if not TweenService then pcall(function() TweenService=game:GetService('TweenService') end) end
local function trackUI(connection)
    lifecycle.connections[connection]=true
    state.connections=state.connections or {}
    state.connections[#state.connections+1]=connection
    return connection
end
local function disconnectUI(connection)
    if not connection then return end
    pcall(function() connection:Disconnect() end)
    lifecycle.connections[connection]=nil
    for index=#(state.connections or {}),1,-1 do
        if state.connections[index]==connection then table.remove(state.connections,index) end
    end
end
local function animate(obj,properties,duration)
    if not lifecycle.alive or not obj.Parent then return end
    local previous=lifecycle.tweens[obj]
    if previous then previous:Cancel() end
    if not TweenService then for key,value in pairs(properties) do obj[key]=value end;return end
    local tween=TweenService:Create(obj,TweenInfo.new(duration or .16,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),properties)
    lifecycle.tweens[obj]=tween
    local connection
    connection=tween.Completed:Connect(function()
        connection:Disconnect()
        if lifecycle.tweens[obj]==tween then lifecycle.tweens[obj]=nil end
    end)
    tween:Play()
end
local window={width=805,height=565,x=.5,y=.5,compact=false,minimized=false,visible=true}
local applyResponsiveLayout=function() end
local cancelInteraction=function() end
local notify=function() end
local tooltip=function() end
local responsiveRows={}
local themes={
    Light={bg='F2F5FC',side='E7EDF8',panel='FFFFFF',row='EAF0FA',text='14213A',muted='526781',accent='4264D9',line='D1DBED'},
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
    if role=='carry' then return rgb(flags.AO_UI_Theme=='Light' and '9B6500' or 'FFD479') end
    if role=='support' then return rgb(flags.AO_UI_Theme=='Light' and '087B72' or '6AE3CC') end
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
    if obj:IsA('GuiObject') then obj.Selectable=false end
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
    corner(b,10)
    skin(b,'BackgroundColor3','row')
    skin(b,'TextColor3','text')
    local outline=make('UIStroke',b,{Thickness=1,Transparency=1})
    skin(outline,'Color','accent')
    b.MouseEnter:Connect(function() animate(outline,{Transparency=.45},.12) end)
    b.MouseLeave:Connect(function() animate(outline,{Transparency=1},.16) end)
    b.MouseButton1Down:Connect(function() animate(outline,{Transparency=.1},.07) end)
    b.MouseButton1Up:Connect(function() animate(outline,{Transparency=.45},.1) end)
    return b
end

local root=make('ScreenGui',playerGui,{
    Name='AnimeOriginV10_7_UI',ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9900,
})
state.gui=root
local main=make('CanvasGroup',root,{
    Name='Window',GroupTransparency=0,Active=true,
    Size=UDim2.fromOffset(805,565),Position=UDim2.new(.5,-402,.5,-282),
    BorderSizePixel=0,BackgroundTransparency=0,
})
local shadow=make('Frame',root,{Name='WindowShadow',BorderSizePixel=0,
    BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=.78,ZIndex=1})
corner(shadow,20)
main.ZIndex=2
corner(main,16)
skin(main,'BackgroundColor3','bg')
stroke(main)
local accentLine=make('Frame',main,{
    Position=UDim2.fromOffset(18,0),Size=UDim2.new(1,-36,0,2),BorderSizePixel=0,
})
skin(accentLine,'BackgroundColor3','accent')
make('UIGradient',accentLine,{Transparency=NumberSequence.new(0,.85)})
local scale=make('UIScale',main,{Scale=1})
local function viewport()
    local camera=Workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local function readGeometry()
    local function number(key,fallback,low,high)
        local value=tonumber(flags[key])
        if not value or value~=value or value==math.huge or value==-math.huge then return fallback end
        return math.clamp(value,low,high)
    end
    window.width=number('AO_UI_WindowW',805,600,1200)
    window.height=number('AO_UI_WindowH',565,420,1000)
    window.x=number('AO_UI_WindowX',.5,0,1)
    window.y=number('AO_UI_WindowY',.5,0,1)
    if tonumber(flags.AO_UI_WindowX)==-1 then window.x=.5 end
    if tonumber(flags.AO_UI_WindowY)==-1 then window.y=.5 end
end
local function sizeForDevice()
    local view=viewport()
    window.compact=view.X<680
    local width=window.compact and math.min(window.width,math.max(240,view.X-16)) or window.width
    local height=window.compact and math.min(window.height,math.max(260,view.Y-16)) or window.height
    window.shownWidth=width;window.shownHeight=height
    scale.Scale=math.min(1,math.max(.01,(view.X-16)/width),math.max(.01,(view.Y-16)/height))
    local actualHeight=window.minimized and 57 or height
    main.Size=UDim2.fromOffset(width,actualHeight)
    main.Position=UDim2.fromOffset(math.max(0,view.X-width*scale.Scale)*window.x,
        math.max(0,view.Y-actualHeight*scale.Scale)*window.y)
    shadow.Position=UDim2.fromOffset(main.Position.X.Offset+4,main.Position.Y.Offset+7)
    shadow.Size=UDim2.fromOffset(width*scale.Scale,actualHeight*scale.Scale)
    applyResponsiveLayout()
    if window.reflowOverlays then window.reflowOverlays() end
end
local function saveGeometry()
    flags.AO_UI_WindowW=window.width;flags.AO_UI_WindowH=window.height
    flags.AO_UI_WindowX=window.x;flags.AO_UI_WindowY=window.y
    saveAppearance()
end
local cameraConnection
local function bindCamera()
    disconnectUI(cameraConnection)
    local camera=Workspace.CurrentCamera
    cameraConnection=camera and trackUI(camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
        cancelInteraction();sizeForDevice()
    end)) or nil
    cancelInteraction();sizeForDevice()
end
readGeometry()
bindCamera()
trackUI(Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(bindCamera))
local header=make('Frame',main,{
    Size=UDim2.new(1,0,0,57),BackgroundTransparency=1,
})
local headerRule=make('Frame',header,{Position=UDim2.new(0,16,1,-1),Size=UDim2.new(1,-32,0,1),
    BackgroundTransparency=.5,BorderSizePixel=0})
skin(headerRule,'BackgroundColor3','line')
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

local sidebar=make('ScrollingFrame',main,{
    CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=0,BackgroundTransparency=0,
    Position=UDim2.fromOffset(0,57),Size=UDim2.new(0,174,1,-57),BorderSizePixel=0,
})
skin(sidebar,'BackgroundColor3','side')
local divider=make('Frame',main,{
    Position=UDim2.fromOffset(173,57),Size=UDim2.new(0,1,1,-57),BorderSizePixel=0,
})
skin(divider,'BackgroundColor3','line')
local navLayout=make('UIListLayout',sidebar,{
    Padding=UDim.new(0,8),FillDirection=Enum.FillDirection.Vertical,
    HorizontalAlignment=Enum.HorizontalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder,
})
local navPadding=make('UIPadding',sidebar,{PaddingTop=UDim.new(0,22)})
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
        page.Position=UDim2.fromOffset(0,9)
        animate(page,{Position=UDim2.fromOffset(0,0)},.18)
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
    corner(r,10)
    skin(r,'BackgroundColor3','panel')
    stroke(r)
    local nameLabel=newText(r,label,13,true)
    nameLabel.Position=UDim2.fromOffset(14,0)
    nameLabel.Size=UDim2.new(1,-221,1,0)
    responsiveRows[r]={label=nameLabel,kind='row'}
    return r
end
local function addStatus(tab,label,initial)
    local r=row(tab,label)
    local s=newText(r,initial or '--',12,false)
    s.Position=UDim2.new(1,-260,0,0)
    s.Size=UDim2.new(0,246,1,0)
    s.TextXAlignment=Enum.TextXAlignment.Right
    statusLabels[label]=s
    responsiveRows[r].kind='status';responsiveRows[r].value=s
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
        animate(b,{BackgroundColor3=on and color('accent') or color('row'),
            TextColor3=on and color('bg') or color('muted')},.16)
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
local menuConnections={}
local menuSearch=make('TextBox',menu,{Name='DropdownSearch',Position=UDim2.fromOffset(8,8),
    Size=UDim2.new(1,-16,0,36),Text='',PlaceholderText='Search options…',ClearTextOnFocus=false,
    Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0,ZIndex=152})
corner(menuSearch,8);skin(menuSearch,'BackgroundColor3','row');skin(menuSearch,'TextColor3','text')
skin(menuSearch,'PlaceholderColor3','muted')
local menuList=make('ScrollingFrame',menu,{Name='DropdownOptions',Position=UDim2.fromOffset(6,50),
    Size=UDim2.new(1,-12,1,-56),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=151,
    CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3})
skin(menuList,'ScrollBarImageColor3','accent')
make('UIListLayout',menuList,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local menuData=nil
local function releaseOwnFocus()
    pcall(function()
        local focused=UIS:GetFocusedTextBox()
        if focused and focused:IsDescendantOf(root) then focused:ReleaseFocus() end
    end)
end
local function hideMenu()
    menu.Visible=false;menuData=nil
    releaseOwnFocus()
    for _,connection in ipairs(menuConnections) do connection:Disconnect() end
    menuConnections={}
    for _,child in ipairs(menuList:GetChildren()) do
        if child:IsA('GuiButton') or child:IsA('TextLabel') then child:Destroy() end
    end
end
local function renderMenuOptions()
    if not menuData then return end
    for _,connection in ipairs(menuConnections) do connection:Disconnect() end
    menuConnections={}
    for _,child in ipairs(menuList:GetChildren()) do
        if child:IsA('GuiButton') or child:IsA('TextLabel') then child:Destroy() end
    end
    local query=tostring(menuSearch.Text):lower()
    local count=0
    for index,label in ipairs(menuData.options) do
        if tostring(label):lower():find(query,1,true) then
            count=count+1
            local choice=uiButton(menuList,tostring(label),UDim2.new(1,-4,0,38))
            choice.LayoutOrder=index;choice.ZIndex=152
            local callback=menuData.choose
            menuConnections[#menuConnections+1]=choice.MouseButton1Click:Connect(function()
                hideMenu();callback(index,label)
            end)
        end
    end
    if count==0 then
        local empty=newText(menuList,'No matching options',12,false)
        empty.Size=UDim2.new(1,-8,0,38);empty.ZIndex=152
    end
    menuList.CanvasPosition=Vector2.new(0,0)
end
menuSearch:GetPropertyChangedSignal('Text'):Connect(renderMenuOptions)
local function openMenu(anchor,options,choose)
    hideMenu()
    local view=viewport()
    local width=math.min(260,view.X-16)
    local height=math.min(math.max(110,#options*43+60),300,view.Y-20)
    local position=anchor.AbsolutePosition
    local top=position.Y+anchor.AbsoluteSize.Y+6
    if top+height>view.Y-8 then top=position.Y-height-6 end
    menu.Size=UDim2.fromOffset(width,height)
    menu.Position=UDim2.fromOffset(math.clamp(position.X,8,math.max(8,view.X-width-8)),
        math.clamp(top,8,math.max(8,view.Y-height-8)))
    menuSearch.Text=''
    menuData={options=options,choose=choose}
    renderMenuOptions()
    menu.Visible=true
    local target=menu.Size
    menu.Size=UDim2.fromOffset(width,math.max(72,height-12))
    animate(menu,{Size=target},.14)
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
    corner(box,10)
    skin(box,'BackgroundColor3','row')
    skin(box,'TextColor3','text')
    skin(box,'PlaceholderColor3','muted')
    box.FocusLost:Connect(function() if lifecycle.alive then setFlag(key,box.Text) end end)
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
        local tween=lifecycle.tweens[obj]
        if tween then tween:Cancel();lifecycle.tweens[obj]=nil end
        if obj.Parent then
            for property,role in pairs(properties) do obj[property]=color(role) end
        end
    end
    return true
end
repaintControls=function()
    if not lifecycle.alive then return end
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
    local geometryChanged=false
    for _,key in ipairs({'AO_UI_WindowW','AO_UI_WindowH','AO_UI_WindowX','AO_UI_WindowY'}) do
        if window[key]~=flags[key] then geometryChanged=true;window[key]=flags[key] end
    end
    if geometryChanged then readGeometry();cancelInteraction();sizeForDevice() end
    applyTransparency()
    if dirty then for _,fn in ipairs(widgets) do fn() end end
end

local delay=ctx.Delay or function(seconds,callback) task.delay(seconds,callback) end
local tooltipBox=make('TextLabel',root,{Name='Tooltip',Visible=false,Size=UDim2.fromOffset(240,54),
    BackgroundTransparency=.06,BorderSizePixel=0,ZIndex=220,TextWrapped=true,
    TextSize=12,Font=Enum.Font.Gotham,Text='',TextXAlignment=Enum.TextXAlignment.Left})
corner(tooltipBox,10);skin(tooltipBox,'BackgroundColor3','side');skin(tooltipBox,'TextColor3','text')
make('UIPadding',tooltipBox,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
tooltip=function(obj,text)
    local held=false
    local function show()
        if not lifecycle.alive or not root.Enabled or not obj.Parent then return end
        local view=viewport();local position=obj.AbsolutePosition
        tooltipBox.Text=type(text)=='function' and text() or text
        tooltipBox.Position=UDim2.fromOffset(math.clamp(position.X,6,math.max(6,view.X-246)),
            math.clamp(position.Y+obj.AbsoluteSize.Y+7,6,math.max(6,view.Y-60)))
        tooltipBox.Visible=true
    end
    obj.MouseEnter:Connect(show)
    obj.MouseLeave:Connect(function() tooltipBox.Visible=false end)
    obj.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch then
            held=true;delay(.5,function() if held then show() end end)
        end
    end)
    obj.InputEnded:Connect(function() held=false;tooltipBox.Visible=false end)
end
local toast={queue={},active=false,generation=0}
local toastBox=make('Frame',root,{Name='Toast',Visible=false,Size=UDim2.fromOffset(300,84),
    BorderSizePixel=0,ZIndex=210})
corner(toastBox,12);stroke(toastBox);skin(toastBox,'BackgroundColor3','side')
local toastBar=make('Frame',toastBox,{Size=UDim2.new(0,3,1,-20),Position=UDim2.fromOffset(0,10),BorderSizePixel=0,ZIndex=211})
local toastTitle=newText(toastBox,'',12,true);toastTitle.Position=UDim2.fromOffset(15,12)
toastTitle.Size=UDim2.new(1,-30,0,18);toastTitle.ZIndex=211
local toastMessage=newText(toastBox,'',12,false);toastMessage.Position=UDim2.fromOffset(15,34)
toastMessage.Size=UDim2.new(1,-30,0,40);toastMessage.TextWrapped=true;toastMessage.ZIndex=211
local function pumpToast()
    if not lifecycle.alive or toast.active or not root.Enabled or #toast.queue==0 then return end
    local item=table.remove(toast.queue,1)
    toast.item=item
    toast.active=true;toast.generation=toast.generation+1
    local generation=toast.generation
    local tint={info='8BAFFF',success='4ACBA7',warning='E3B658',error='ED8193'}
    toastTitle.Text=string.upper(item.kind);toastBar.BackgroundColor3=rgb(tint[item.kind] or tint.info)
    toastMessage.Text=item.message
    local view=viewport();local width=math.min(320,view.X-24)
    toastBox.Size=UDim2.fromOffset(width,84)
    toastBox.Position=UDim2.fromOffset(view.X-width-12,view.Y+10);toastBox.Visible=true
    animate(toastBox,{Position=UDim2.fromOffset(view.X-width-12,view.Y-96)},.2)
    delay(item.duration,function()
        if not lifecycle.alive or generation~=toast.generation then return end
        animate(toastBox,{Position=UDim2.fromOffset(view.X-width-12,view.Y+10)},.16)
        delay(.17,function()
            if not lifecycle.alive or generation~=toast.generation then return end
            toastBox.Visible=false;toast.active=false;toast.item=nil;pumpToast()
        end)
    end)
end
notify=function(message,kind,duration)
    if not lifecycle.alive then return end
    if kind~='success' and kind~='warning' and kind~='error' then kind='info' end
    duration=tonumber(duration) or 3
    if duration~=duration then duration=3 end
    if #toast.queue>=8 then table.remove(toast.queue,1) end
    toast.queue[#toast.queue+1]={message=tostring(message),kind=kind or 'info',
        duration=math.clamp(duration,1,10)}
    pumpToast()
end
window.reflowOverlays=function()
    local view=viewport()
    if menu.Visible then
        local width=math.min(menu.Size.X.Offset,view.X-16)
        local height=math.min(menu.Size.Y.Offset,view.Y-16)
        animate(menu,{Size=UDim2.fromOffset(width,height),Position=UDim2.fromOffset(
            math.clamp(menu.Position.X.Offset,8,math.max(8,view.X-width-8)),
            math.clamp(menu.Position.Y.Offset,8,math.max(8,view.Y-height-8)))},.1)
    end
    tooltipBox.Visible=false
end
local function suspendOverlays()
    hideMenu();tooltipBox.Visible=false
    if toast.active then
        if lifecycle.alive and toast.item then
            if #toast.queue>=8 then table.remove(toast.queue) end
            table.insert(toast.queue,1,toast.item)
        end
        toast.item=nil
        toast.generation=toast.generation+1;toast.active=false;toastBox.Visible=false
    end
end
section('Colosseum','Colosseum')
addToggle('Colosseum','Auto Colosseum','AO_AutoColosseum')
addToggle('Colosseum','Hell Mode','AO_Colo_Hell')
addToggle('Colosseum','Endless Mode','AO_Colo_Endless')
addInput('Colosseum','Stop Floor','AO_Colo_StopFloor','35 or 30-40')
section('Colosseum','Live Status')
local colStatus=addStatus('Colosseum','Colo status','OFF')
local cardsRow=row('Colosseum','Cards')
responsiveRows[cardsRow]=nil
local cardsHeading=cardsRow:FindFirstChildWhichIsA('TextLabel')
cardsHeading.Position=UDim2.fromOffset(14,10)
cardsHeading.Size=UDim2.new(1,-100,0,20)
local colFloor=newText(cardsRow,'Floor 0',12,false)
colFloor.Position=UDim2.new(1,-100,0,10)
colFloor.Size=UDim2.fromOffset(86,20)
colFloor.TextXAlignment=Enum.TextXAlignment.Right
local cardWidgets={}
for index=1,4 do
    local tile=make('Frame',cardsRow,{Name='TeamCard'..index,BorderSizePixel=0})
    corner(tile,10);skin(tile,'BackgroundColor3','row')
    local edge=make('Frame',tile,{Size=UDim2.new(0,3,1,-16),Position=UDim2.fromOffset(0,8),BorderSizePixel=0})
    corner(edge,2)
    local badge=newText(tile,string.format('%02d  CARD',index),10,true)
    badge.Position=UDim2.fromOffset(12,7);badge.Size=UDim2.new(1,-24,0,15)
    local name=newText(tile,'Waiting for team',13,true)
    name.Position=UDim2.fromOffset(12,25);name.Size=UDim2.new(1,-24,0,22)
    cardWidgets[index]={tile=tile,edge=edge,badge=badge,name=name}
    tooltip(tile,function() return name.Text..' · '..badge.Text end)
end
local function paintCards(compact)
    cardsRow.Size=UDim2.new(1,-2,0,compact and 286 or 164)
    for index,widget in ipairs(cardWidgets) do
        local column=(index-1)%2
        local line=math.floor((index-1)/2)
        widget.tile.Position=compact and UDim2.fromOffset(12,38+(index-1)*60)
            or UDim2.new(column*.5,12-column*2,0,38+line*60)
        widget.tile.Size=compact and UDim2.new(1,-24,0,54) or UDim2.new(.5,-22,0,54)
    end
end
paintCards(false)
local function refreshCards()
    local team=state.teamCards
    -- Older main scripts still work with the same Create(ctx) contract.
    if not team then team={[state.carrySlot or 2]={name=state.carryName,role='carry'}} end
    for index,widget in ipairs(cardWidgets) do
        local card=team[index]
        local role=card and card.role or 'normal'
        local tintRole=role=='carry' and 'carry' or role=='support' and 'support' or 'muted'
        local tint=color(tintRole)
        skinned[widget.badge].TextColor3=tintRole
        skinned[widget.name].TextColor3=role=='normal' and 'text' or tintRole
        skinned[widget.edge]=skinned[widget.edge] or {}
        skinned[widget.edge].BackgroundColor3=tintRole
        local label=string.format('%02d  %s%s',index,role=='carry' and 'CARRY' or role=='support' and 'SUPPORT' or 'CARD',
            card and card.dead and '  ·  DOWN' or '')
        local name=card and card.name or 'Waiting for team'
        if widget.badge.Text~=label then widget.badge.Text=label end
        if widget.name.Text~=name then widget.name.Text=name end
        if widget.badge.TextColor3~=tint then widget.badge.TextColor3=tint;widget.edge.BackgroundColor3=tint end
        local textTint=role=='normal' and color('text') or tint
        if widget.name.TextColor3~=textTint then widget.name.TextColor3=textTint end
    end
    local floor='Floor '..tostring(state.lastSeenWave or 0)
    if colFloor.Text~=floor then colFloor.Text=floor end
end
local colProgress=addStatus('Colosseum','PB / Curse / Floor','--')
local worldRow=row('Colosseum','World Blessing')
worldRow.Size=UDim2.new(1,-2,0,83)
responsiveRows[worldRow]=nil
local worldHeading=worldRow:FindFirstChildWhichIsA('TextLabel')
worldHeading.Position=UDim2.fromOffset(14,9)
worldHeading.Size=UDim2.new(1,-28,0,20)
local colWorld=newText(worldRow,'Total: --\nWave: --',12,false)
colWorld.Position=UDim2.fromOffset(14,32)
colWorld.Size=UDim2.new(1,-28,0,42)
colWorld.TextWrapped=true
colWorld.TextTruncate=Enum.TextTruncate.None
colWorld.TextYAlignment=Enum.TextYAlignment.Top
local function worldBuffText()
    local names={{'hpPct','HP'},{'dmgPct','DMG'},{'dr','DR'},{'critDmg','Crit DMG'}}
    local totals,gains={},{}
    local function percent(value)
        if math.abs(value)<.000001 then value=0 end
        return string.format('%+.1f',value*100):gsub('%.0$','')..'%'
    end
    for _,item in ipairs(names) do
        if state.worldBuffs then
            totals[#totals+1]=item[2]..' '..percent(state.worldBuffs[item[1]] or 0)
        end
        local delta=state.worldBuffDelta and (state.worldBuffDelta[item[1]] or 0)
        if delta and math.abs(delta)>.000001 then
            gains[#gains+1]=item[2]..' '..percent(delta)
        end
    end
    local wave=state.worldBuffWave
    local recent=wave and wave>0 and ('Wave '..wave..': ') or 'Wave: '
    recent=recent..(state.worldBuffDelta and (#gains>0 and table.concat(gains,'  /  ') or 'No World buff') or '--')
    return 'Total: '..(#totals>0 and table.concat(totals,'  /  ') or '--')..'\n'..recent
end

section('Rift Gate','Rift Gate')
addToggle('Rift Gate','Auto Rift','AO_AutoRift')
addToggle('Rift Gate','Auto Leave','AO_Rift_Leave')
section('Rift Gate','Live Status')
local riftStatus=addStatus('Rift Gate','Rift status','OFF')
local riftTimer=addStatus('Rift Gate','Next Rift','READY')
local riftClears=addStatus('Rift Gate','Clears','0')

section('Multi-Boss','Multi-Boss')
addToggle('Multi-Boss','Auto Boss','AO_AutoBoss')
local bossStatus=addStatus('Multi-Boss','Boss status','OFF')
local miniSectionAdded=false
for _,b in ipairs(boss.bosses) do
    if b.kind=='mini' and not miniSectionAdded then
        miniSectionAdded=true
        section('Multi-Boss','Mini Bosses')
        addToggle('Multi-Boss','Auto Mini Boss','AO_AutoMiniBoss')
    end
    orderCounter=orderCounter+1
    local r=make('Frame',tabPages['Multi-Boss'],{
        Size=UDim2.new(1,-2,0,51),BorderSizePixel=0,LayoutOrder=orderCounter,
    })
    corner(r,10)
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
    responsiveRows[r]={kind='boss',label=name,toggle=toggle,dropdown=dropdown,timer=timer}
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
    corner(item,10)
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
    responsiveRows[item]={kind='stage',label=label,toggle=toggle,timer=timer}
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
    corner(item,10);skin(item,'BackgroundColor3','panel')
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
    responsiveRows[item]={kind='stage',label=label,toggle=toggle,timer=timer}
    stage.displayCooldown=timer
end

section('Settings','Appearance')
addDropdown('Settings','Theme','AO_UI_Theme',{'Midnight','Light','Ocean','Violet','Emerald','Rose'},false)
local transparencyRow=row('Settings','Transparency')
responsiveRows[transparencyRow].kind='transparency'
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
local navigationBefore={}
local navigationChanged={}
local function restoreGameInput()
    if not GuiService then return end
    pcall(function() GuiService.SelectedObject=nil end)
    -- One-time reset for keyboard users. Do not bind WASD/Enter or alter any
    -- native button's Visible, Enabled, transparency, size or position.
    if not UIS.GamepadEnabled then
        for _,property in ipairs({'GuiNavigationEnabled','AutoSelectGuiEnabled'}) do
            pcall(function()
                if navigationBefore[property]==nil then navigationBefore[property]=GuiService[property] end
                GuiService[property]=false;navigationChanged[property]=true
            end)
        end
    end
end
restoreGameInput()
addAction('Settings','Game keyboard input','RESET INPUT',restoreGameInput)
local webhookStatus,webhookCounts,webhookLast
if ctx.pullWebhook then
    section('Settings','Rare Pull Webhook · Base > 1B')
    addToggle('Settings','Rare pull alerts','AO_PullWebhook')
    local webhookRow=row('Settings','Discord webhook URL')
    local webhookInput=make('TextBox',webhookRow,{Name='WebhookInput',Size=UDim2.fromOffset(200,34),
        Position=UDim2.new(1,-214,.5,-17),BackgroundTransparency=0,BorderSizePixel=0,
        Font=Enum.Font.Gotham,TextSize=12,Text='',PlaceholderText='Paste URL · session only',ClearTextOnFocus=false})
    corner(webhookInput,10);skin(webhookInput,'BackgroundColor3','row')
    skin(webhookInput,'TextColor3','text');skin(webhookInput,'PlaceholderColor3','muted')
    tooltip(webhookInput,'Base rarity only, strictly above 1 billion. URL stays in memory and is not saved to profiles.')
    webhookInput.FocusLost:Connect(function()
        if not lifecycle.alive then return end
        local value=webhookInput.Text
        if value=='' then return end
        local accepted=ctx.pullWebhook.setEndpoint(value)
        webhookInput.Text=''
        webhookInput.PlaceholderText=ctx.pullWebhook.state.hasEndpoint and 'Configured · click to replace' or 'Paste URL · session only'
        notify(accepted and 'Webhook configured for this session' or 'Invalid Discord webhook URL',accepted and 'success' or 'error')
    end)
    addAction('Settings','Test webhook','SEND TEST',function()
        local queued=ctx.pullWebhook.test()
        notify(queued and 'Webhook test queued; check delivery status below' or ctx.pullWebhook.state.status,queued and 'info' or 'warning')
    end)
    addAction('Settings','Clear webhook','CLEAR URL',function()
        ctx.pullWebhook.setEndpoint('');webhookInput.Text='';webhookInput.PlaceholderText='Paste URL · session only'
    end)
    webhookStatus=addStatus('Settings','Webhook delivery','OFF')
    webhookCounts=addStatus('Settings','Matched / Sent / Failed','0 / 0 / 0')
    webhookLast=addStatus('Settings','Last rare card','--')
end
section('Settings','Connection')
addToggle('Settings','Auto Reconnect','AO_Reconnect')
local reconnectStatus=addStatus('Settings','Reconnect','Monitoring')
addAction('Settings','Reconnect Now','REJOIN',function()
    reconnect.attempts=0
    reconnect.lastTry=-math.huge
    requestReconnect(true)
end)
section('Settings','Session')
local confirmation=make('Frame',root,{Name='StopConfirmation',Visible=false,
    Size=UDim2.fromOffset(290,164),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BorderSizePixel=0,ZIndex=200})
corner(confirmation,14);stroke(confirmation);skin(confirmation,'BackgroundColor3','side')
local confirmationTitle=newText(confirmation,'Stop all automation?',15,true)
confirmationTitle.Position=UDim2.fromOffset(16,15);confirmationTitle.Size=UDim2.new(1,-32,0,25);confirmationTitle.ZIndex=201
local confirmationNote=newText(confirmation,'This stops the script. Hiding the window keeps it running.',12,false)
confirmationNote.Position=UDim2.fromOffset(16,48);confirmationNote.Size=UDim2.new(1,-32,0,44)
confirmationNote.TextWrapped=true;confirmationNote.ZIndex=201
local cancelStop=uiButton(confirmation,'CANCEL',UDim2.fromOffset(118,38))
cancelStop.Position=UDim2.fromOffset(16,108);cancelStop.ZIndex=201
local confirmStop=uiButton(confirmation,'STOP ALL',UDim2.fromOffset(118,38))
confirmStop.Position=UDim2.fromOffset(156,108);confirmStop.ZIndex=201
cancelStop.MouseButton1Click:Connect(function() confirmation.Visible=false end)
confirmStop.MouseButton1Click:Connect(function()
    state.stop()
    if env.AnimeOriginV10_7==state then env.AnimeOriginV10_7=nil end
end)
addAction('Settings','Stop Script','STOP SCRIPT',function()
    hideMenu();confirmation.Visible=true
end)

section('Config','Profiles')
local configRow=row('Config','Config Name')
local nameInput=make('TextBox',configRow,{
    Size=UDim2.fromOffset(180,31),Position=UDim2.new(1,-195,.5,-15),
    Font=Enum.Font.GothamMedium,TextSize=13,BorderSizePixel=0,
    BackgroundTransparency=0,Text=profile.currentProfile,ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Center,
})
corner(nameInput,10)
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
            notify(profile.configStatus,'success')
        end
    end
end)
addAction('Config','Load','LOAD',function()
    profile.revision=profile.revision+1
    if loadProfile(nameInput.Text) then applyFlags();repaintControls();notify('Profile loaded: '..profile.currentProfile,'success')
    else notify(profile.configStatus,'error') end
end)
addAction('Config','Delete','DELETE',function()
    profile.revision=profile.revision+1
    if deleteProfile(nameInput.Text) then nameInput.Text=profile.currentProfile;notify('Profile deleted','info')
    else notify(profile.configStatus,'warning') end
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

-- Responsive window interaction: all coordinates are clamped to the viewport.
local dragging=false
local resizing=false
local originMouse,originPosition,dragTouch
local resizeOrigin,resizeWidth,resizeHeight
local resizeHandle=uiButton(main,'◢',UDim2.fromOffset(30,30))
resizeHandle.Name='ResizeHandle';resizeHandle.Position=UDim2.new(1,-32,1,-32)
resizeHandle.ZIndex=20;resizeHandle.BackgroundTransparency=1
surfaces[resizeHandle]=nil
local function pointer(input)
    return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
end
cancelInteraction=function()
    dragging=false;resizing=false;dragTouch=nil;sliderInput=nil
end
local function movedPosition(x,y)
    local view=viewport()
    local width=main.Size.X.Offset*scale.Scale
    local height=main.Size.Y.Offset*scale.Scale
    local maxX=math.max(0,view.X-width);local maxY=math.max(0,view.Y-height)
    window.x=maxX>0 and math.clamp(x,0,maxX)/maxX or 0
    window.y=maxY>0 and math.clamp(y,0,maxY)/maxY or 0
    sizeForDevice()
end
header.InputBegan:Connect(function(input)
    if pointer(input) then
        dragging=true;resizing=false
        dragTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
        originMouse=input.Position;originPosition=main.Position
    end
end)
resizeHandle.InputBegan:Connect(function(input)
    if pointer(input) and not window.minimized then
        resizing=true;dragging=false
        dragTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
        resizeOrigin=input.Position;resizeWidth=window.width;resizeHeight=window.height
    end
end)
local dragMove=trackUI(UIS.InputChanged:Connect(function(input)
    if not root.Enabled then cancelInteraction();return end
    if sliderInput and (input==sliderInput or input.UserInputType==Enum.UserInputType.MouseMovement) then
        adjustTransparency(input.Position.X)
    elseif (dragging or resizing) and (input==dragTouch or input.UserInputType==Enum.UserInputType.MouseMovement) then
        if dragging then
            movedPosition(originPosition.X.Offset+input.Position.X-originMouse.X,
                originPosition.Y.Offset+input.Position.Y-originMouse.Y)
        else
            window.width=math.clamp(resizeWidth+(input.Position.X-resizeOrigin.X)/scale.Scale,600,1200)
            window.height=math.clamp(resizeHeight+(input.Position.Y-resizeOrigin.Y)/scale.Scale,420,1000)
            sizeForDevice()
        end
    end
end))
local dragEnd=trackUI(UIS.InputEnded:Connect(function(input)
    if input==sliderInput then sliderInput=nil end
    if input==dragTouch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        if (dragging or resizing) and not window.minimized then saveGeometry() end
        dragging=false;resizing=false;dragTouch=nil
    end
end))
local function setWindowVisible(show)
    window.visibilityRevision=(window.visibilityRevision or 0)+1
    local token=window.visibilityRevision
    window.visible=show
    cancelInteraction();suspendOverlays();confirmation.Visible=false
    if show then
        root.Enabled=true;shadow.Visible=true;sizeForDevice()
        local target=main.Position
        main.GroupTransparency=1
        main.Position=UDim2.fromOffset(target.X.Offset,target.Y.Offset+12)
        animate(main,{GroupTransparency=0,Position=target},.18)
        pumpToast()
    else
        releaseOwnFocus()
        animate(main,{GroupTransparency=1},.15)
        delay(.16,function()
            if not lifecycle.alive or token~=window.visibilityRevision then return end
            root.Enabled=false;shadow.Visible=false;main.GroupTransparency=0
        end)
    end
end
local hotkey=trackUI(UIS.InputBegan:Connect(function(input,used)
    if not used and input.KeyCode==Enum.KeyCode.RightShift and state.alive then
        setWindowVisible(not window.visible)
    elseif not used and input.UserInputType==Enum.UserInputType.MouseButton1 and menu.Visible then
        local point=input.Position;local position=menu.AbsolutePosition;local size=menu.AbsoluteSize
        if point.X<position.X or point.Y<position.Y or point.X>position.X+size.X or point.Y>position.Y+size.Y then hideMenu() end
    end
end))
trackUI(root:GetPropertyChangedSignal('Enabled'):Connect(function()
    if window.visible~=root.Enabled then
        window.visibilityRevision=(window.visibilityRevision or 0)+1
        window.visible=root.Enabled
        local tween=lifecycle.tweens[main]
        if tween then tween:Cancel();lifecycle.tweens[main]=nil end
        main.GroupTransparency=0
    end
    if not root.Enabled then cancelInteraction();suspendOverlays();confirmation.Visible=false end
    shadow.Visible=root.Enabled
end))
hide.MouseButton1Click:Connect(function()
    cancelInteraction();suspendOverlays();confirmation.Visible=false
    local position=main.Position
    window.minimized=not window.minimized
    local height=window.minimized and 57 or window.shownHeight
    local view=viewport()
    window.y=math.clamp(position.Y.Offset/math.max(1,view.Y-height*scale.Scale),0,1)
    sizeForDevice()
    local target=main.Size
    main.Size=UDim2.fromOffset(window.shownWidth,window.minimized and height+12 or height-12)
    animate(main,{Size=target},.18)
    hide.Text=window.minimized and '▢' or '—'
end)
dismiss.MouseButton1Click:Connect(function() setWindowVisible(false) end)
tooltip(hide,'Minimize the window. Automation keeps running.')
tooltip(dismiss,'Hide this window. Press Right Shift to show it again.')
tooltip(resizeHandle,'Drag to resize. Size and position are saved with the profile.')
local stopWrapper
local function destroyUI(removeRoot)
    if not lifecycle.alive then return end
    lifecycle.alive=false;toast.generation=toast.generation+1;toast.queue={}
    if GuiService then
        for property in pairs(navigationChanged) do
            pcall(function()
                if GuiService[property]==false then GuiService[property]=navigationBefore[property] end
            end)
            navigationChanged[property]=nil
        end
    end
    cancelInteraction();suspendOverlays()
    for connection in pairs(lifecycle.connections) do disconnectUI(connection) end
    for obj,tween in pairs(lifecycle.tweens) do tween:Cancel();lifecycle.tweens[obj]=nil end
    if state.gui==root then state.gui=nil end
    if state.__animeUiDestroy==destroyUI then state.__animeUiDestroy=nil end
    if state.stop==stopWrapper then state.stop=state.__animeUiStopBase end
    if removeRoot~=false and root.Parent then root:Destroy() end
end
trackUI(root.Destroying:Connect(function() destroyUI(false) end))
local stopEverything=state.__animeUiStopBase or state.stop
state.__animeUiStopBase=stopEverything
state.__animeUiDestroy=destroyUI
stopWrapper=function()
    stopEverything()
    destroyUI(true)
end
state.stop=stopWrapper
-- Capture desktop geometry once; compact layouts never overwrite that baseline.
for r,entry in pairs(responsiveRows) do
    entry.height=r.Size.Y.Offset
    entry.children={}
    for _,obj in ipairs(r:GetChildren()) do
        if obj:IsA('GuiObject') then
            entry.children[obj]={Position=obj.Position,Size=obj.Size,TextXAlignment=obj:IsA('TextLabel') and obj.TextXAlignment or nil}
        end
    end
end
applyResponsiveLayout=function()
    local compact=window.compact
    local width=window.shownWidth
    sidebar.Position=UDim2.fromOffset(0,57)
    sidebar.Size=compact and UDim2.new(1,0,0,48) or UDim2.new(0,174,1,-57)
    sidebar.AutomaticCanvasSize=compact and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
    sidebar.ScrollingDirection=compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
    navLayout.FillDirection=compact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    navLayout.HorizontalAlignment=compact and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
    navPadding.PaddingTop=UDim.new(0,compact and 5 or 22)
    navPadding.PaddingLeft=UDim.new(0,compact and 10 or 0)
    for _,button in pairs(navButtons) do button.Size=compact and UDim2.fromOffset(145,38) or UDim2.new(1,-20,0,39) end
    body.Position=compact and UDim2.fromOffset(0,105) or UDim2.fromOffset(175,57)
    body.Size=compact and UDim2.new(1,0,1,-105) or UDim2.new(1,-175,1,-57)
    sidebar.Visible=not window.minimized;body.Visible=not window.minimized
    divider.Visible=not compact and not window.minimized
    sessionBadge.Visible=not compact
    bigTitle.Size=UDim2.new(1,-150,0,22)
    smallTitle.Size=UDim2.new(1,-150,0,16)
    resizeHandle.Visible=not window.minimized and not compact
    paintCards(compact)
    worldRow.Size=UDim2.new(1,-2,0,compact and 112 or 83)
    colWorld.Size=UDim2.new(1,-28,1,-38)
    for r,entry in pairs(responsiveRows) do
        if not compact then
            r.Size=UDim2.new(1,-2,0,entry.height)
            for obj,properties in pairs(entry.children) do
                obj.Position=properties.Position;obj.Size=properties.Size
                if properties.TextXAlignment then obj.TextXAlignment=properties.TextXAlignment end
            end
        else
            local contentWidth=width-40
            r.Size=UDim2.new(1,-2,0,entry.kind=='boss' and 104 or entry.kind=='transparency' and 90 or 80)
            entry.label.Position=UDim2.fromOffset(12,8)
            entry.label.Size=UDim2.new(1,-24,0,22)
            if entry.kind=='boss' then
                entry.label.Size=UDim2.new(1,-130,0,28)
                entry.timer.Position=UDim2.new(1,-112,0,8);entry.timer.Size=UDim2.fromOffset(100,28)
                entry.toggle.Position=UDim2.fromOffset(12,51);entry.toggle.Size=UDim2.fromOffset(84,38)
                entry.dropdown.Position=UDim2.fromOffset(108,51);entry.dropdown.Size=UDim2.new(1,-120,0,38)
            elseif entry.kind=='stage' then
                entry.timer.Position=UDim2.fromOffset(12,40);entry.timer.Size=UDim2.new(1,-130,0,30)
                entry.timer.TextXAlignment=Enum.TextXAlignment.Left
                entry.toggle.Position=UDim2.new(1,-106,0,36);entry.toggle.Size=UDim2.fromOffset(94,38)
            elseif entry.kind=='transparency' then
                transparencyText.Position=UDim2.new(1,-60,0,8);transparencyText.Size=UDim2.fromOffset(46,22)
                slider.Position=UDim2.fromOffset(14,36);slider.Size=UDim2.new(1,-28,0,38)
            elseif entry.kind=='status' then
                entry.value.Position=UDim2.fromOffset(12,36);entry.value.Size=UDim2.new(1,-24,0,30)
                entry.value.TextXAlignment=Enum.TextXAlignment.Left
            else
                for obj in pairs(entry.children) do
                    if obj:IsA('GuiButton') or obj:IsA('TextBox') then
                        local w=math.min(200,math.max(100,contentWidth-24))
                        obj.Position=UDim2.new(1,-w-12,0,36);obj.Size=UDim2.fromOffset(w,36)
                    end
                end
            end
        end
    end
end
sizeForDevice()
local function showStatus(widget,value)
    if widget and widget.Parent and widget.Text~=value then widget.Text=value end
end
local overviewLast=0
local function refreshOverview()
    if os.clock()-overviewLast<0.7 then return end
    overviewLast=os.clock()
    if not lifecycle.alive or not root.Parent or not root.Enabled or window.minimized then return end
    pumpToast()
    local running=state.enabled or rift.state.on or boss.state.running or raid.state.on or siege.state.on
    showStatus(sessionBadge,running and '● RUNNING' or '○ STANDBY')
    local badgeColor=running and color('accent') or color('muted')
    if sessionBadge.TextColor3~=badgeColor then sessionBadge.TextColor3=badgeColor end
    local colLabel=state.blocked and ('PAUSED: '..tostring(state.blockedReason or 'Unknown'))
        or (state.enabled and (handoff.active and 'RIFT PRIORITY / Colo suspended'
            or handoff.returning and ('RESUME COLO / '..tostring(state.transportStatus))
            or tostring((state.phase~='' and state.phase) or state.transportStatus or 'ON')) or 'OFF')
    showStatus(colStatus,colLabel)
    refreshCards()
    showStatus(colProgress,tostring(state.supportCount)..'/8  /  '..tostring(state.curseCount)..'/3  /  '..tostring(state.stopFloor or cfg.stopSpec))
    showStatus(colWorld,worldBuffText())
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
    if ctx.pullWebhook then
        local status=ctx.pullWebhook.state
        showStatus(webhookStatus,status.status)
        showStatus(webhookCounts,tostring(status.matched)..' / '..tostring(status.sent)..' / '..tostring(status.failed))
        showStatus(webhookLast,status.lastCard)
    end
    showStatus(reconnectStatus,tostring(state.reconnectStatus or reconnect.status or '--'))
    showStatus(configCurrent,tostring(profile.autoProfile))
    showStatus(configResult,profile.configStatus)
end
repaintControls()
refreshOverview()
return {Repaint=repaintControls,Refresh=refreshOverview,Root=root,Notify=notify,Destroy=destroyUI}
end
return Library
