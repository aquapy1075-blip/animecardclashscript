-- Origin Story - UI adapted from aquapy1075-blip/animecardclashscript/anime_origin_ui.lua
-- Upstream SHA: 543f7f2b12f690f6b6592dcf10d805807fe2c29b
-- Standalone: embeds the adapted Origin UI; no remote code download.
-- Combat detection uses user supplied ShowBattle / ShowBattle2 visibility.
local Story=(function()
-- Story queue: map order, then encounter order, then difficulty order.
local Story = {}
Story.Modes = {'Easy','Medium','Hard','Impossible','Cosmic'}
Story.Worlds = {
    {name='Pirate Shark Park',map='ArlongPark',cards={'Usopp','Nami','Duffy','Zoro','Sanji','Arlong'}},
    {name='Bug Arena',map='CellGames',cards={'SonWarrior','PridefulPrince','AndroidMentor','FutureWarrior','DevouringBug','SonProdigy'}},
    {name='Castle of the Demons',map='CastleOfTheDemons',cards={'SashSickleSiblings','CompassDemon','FrozenLotusDemon','WeepingStoneMonk','SixEyedMoonDemon','FirstDemon'}},
    {name='Diamond Town',map='DiamondTown',cards={'VoidHand','EchoRookie','InkMangaka','DiamondHeart','StarLeader','PeacefulBomber'}},
    {name='Ninja Village',map='NinjaVillage',cards={'RainGod','CrowGenius','WanderingAvenger','TenTailVessel','ValleyLegend','FoxVessel'}},
    {name='Demon Lord Hall',map='DemonLordHall',cards={'HolyKnightCaptain','FlameGeneral','PrimordialButler','DestroyerPrincess','StormDragon','SlimeSovereign'}},
}
function Story.targetOptions(selectedMaps)
    local options={}
    for _,world in ipairs(Story.Worlds) do
        if (selectedMaps or {})[world.map] then
            for i,id in ipairs(world.cards) do
                options[#options+1]=world.name..' / '..id..(i==#world.cards and ' [BOSS]' or '')
            end
        end
    end
    return options
end
function Story.buildQueue(flags)
    local queue={}
    for _,world in ipairs(Story.Worlds) do
        if (flags.StoryMaps or {})[world.map] then
            for index,id in ipairs(world.cards) do
                if (flags.StoryCards or {})[id] then
                    for _,mode in ipairs(Story.Modes) do
                        if ((flags.StoryModes or {})[id] or {})[mode] then
                            queue[#queue+1]={map=world.map,world=world.name,cardId=id,difficulty=mode,boss=index==#world.cards}
                        end
                    end
                end
            end
        end
    end
    return queue
end
return Story

end)()
local Combat=(function()
-- Server protocol verified from captured StartResponse and BattleEnd messages.
local Combat = {}
function Combat.new()
    return {started=false,ended=false,results={},order={}}
end
function Combat.match(attempt,event)
    if type(event)~='table' or event.type~='BattleEnd' or type(event.won)~='boolean' then return false end
    if not attempt.battleId or event.battleId~=attempt.battleId then return false end
    if event.lane~=nil and attempt.lane~=nil and event.lane~=attempt.lane then return false end
    if event.difficulty~=nil and attempt.difficulty~=nil and event.difficulty~=attempt.difficulty then return false end
    return true
end
function Combat.event(attempt,event)
    if type(event)~='table' or event.type~='BattleEnd' or type(event.battleId)~='string' or type(event.won)~='boolean' then return end
    if attempt.battleId then
        if Combat.match(attempt,event) and not attempt.ended then
            attempt.ended=true;attempt.won=event.won
        end
    else
        -- A fast result may arrive before InvokeServer returns its admission snapshot.
        if not attempt.results[event.battleId] then attempt.order[#attempt.order+1]=event.battleId end
        attempt.results[event.battleId]=event
        if #attempt.order>32 then attempt.results[table.remove(attempt.order,1)]=nil end
    end
end
function Combat.accept(attempt,response,item)
    local snapshot=response[4]
    if response[1]~=true or response[2]~=true or type(snapshot)~='table' then return false end
    local portrait=snapshot.enemy and snapshot.enemy.portrait
    if snapshot.active~=true or snapshot.fresh~=true or type(snapshot.battleId)~='string'
        or type(portrait)~='table' or portrait.cardId~=item.cardId then return false end
    attempt.started=true;attempt.battleId=snapshot.battleId;attempt.lane=snapshot.lane;attempt.difficulty=item.difficulty
    local buffered=attempt.results[attempt.battleId]
    if buffered then Combat.event(attempt,buffered) end
    attempt.results={};attempt.order={}
    return true
end
return Combat

end)()
local Library=(function()
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
    Light={bg='F2F5FC',side='E7EDF8',panel='FFFFFF',row='EAF0FA',text='14213A',muted='526781',accent='4264D9',line='D1DBED',selected='DDE8FF',selectedText='173C85',mint='087B72',gold='986014',rose='B33764',violet='7045BC'},
    Midnight={bg='0B0D13',side='10121B',panel='171B28',row='202638',text='F0F4FF',muted='99A9C8',accent='6D8BFF',line='303B58',selected='28476B',selectedText='D9F4FF',mint='62DCC1',gold='F3C276',rose='F28FB4',violet='BAA0FF'},
    Ocean={bg='080F16',side='0C1822',panel='102635',row='17394B',text='ECFAFF',muted='8EBACD',accent='36DBCE',line='255166',selected='164C56',selectedText='CFFFF6',mint='5CE1C2',gold='F4CC84',rose='FF9EBD',violet='B5A5FF'},
    Violet={bg='171322',side='20192E',panel='2B213C',row='392C50',text='F6EFFF',muted='B8A8D4',accent='BC8AFF',line='534267',selected='503D78',selectedText='F4E8FF',mint='70E2CC',gold='F2CA83',rose='FFA0C1',violet='C7A8FF'},
    Emerald={bg='101C18',side='152B24',panel='1C372D',row='29463A',text='EFFFF4',muted='A0C8B0',accent='60D8A8',line='3E6454',selected='235545',selectedText='D2FFEC',mint='79E8BD',gold='F4CE86',rose='FCA3C0',violet='B7ACFF'},
    Rose={bg='23171C',side='311D27',panel='3E2633',row='503442',text='FFEFF4',muted='D9A9BC',accent='FF8FB2',line='704859',selected='64364E',selectedText='FFE2EE',mint='7AE5CE',gold='F5CF92',rose='FFABCD',violet='C8ADFF'},
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
    Name='OriginStoryUI',ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9900,
})
state.gui=root
local main=make('CanvasGroup',root,{
    Name='Window',GroupTransparency=0,Active=false,
    Size=UDim2.fromOffset(805,565),Position=UDim2.new(.5,-402,.5,-282),
    BorderSizePixel=0,BackgroundTransparency=0,
})
local shadow=make('Frame',root,{Name='WindowShadow',BorderSizePixel=0,Active=false,
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
accentLine.Size=UDim2.new(1,-36,0,3)
make('UIGradient',accentLine,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(112,93,255)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(62,159,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(46,229,199))})})
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
local bigTitle=newText(header,'ORIGIN  /  STORY',17,true)
bigTitle.Position=UDim2.fromOffset(62,10)
bigTitle.Size=UDim2.fromOffset(250,22)
local smallTitle=newText(header,'CONTROL CENTER  /  STORY',11,false)
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
local selectedTab='Story'
local navButtons={}
local tabPages={}
local tabNames={'Story','Config','Settings'}
for i,name in ipairs(tabNames) do
    local tab=uiButton(sidebar,string.format('%02d   %s',i,name),UDim2.new(1,-20,0,39))
    make('UIGradient',tab,{Rotation=30,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(155,195,240))})
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
    local sectionRoles={'violet','mint','gold','rose'}
    skin(t,'TextColor3',sectionRoles[(orderCounter-1)%4+1])
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
    local glow=make('UIGradient',r,{Rotation=15,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(165,185,225))})
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
    Size=UDim2.new(1,-16,0,36),Text='',PlaceholderText='Search targets or maps…',ClearTextOnFocus=false,
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
local function paintOption(option,label,checked)
    option.Text=label
    skin(option,'BackgroundColor3',checked and 'selected' or 'row')
    skin(option,'TextColor3',checked and 'selectedText' or 'text')
    local mark=option:FindFirstChild('SelectionMark')
    if not mark then
        mark=make('TextLabel',option,{Name='SelectionMark',AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-10,.5,0),Size=UDim2.fromOffset(24,24),BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=15,ZIndex=153})
        corner(mark,7)
        local border=make('UIStroke',mark,{Thickness=1,Transparency=.3})
        skin(border,'Color','mint')
    end
    mark.Text=checked and '✓' or ''
    mark.BackgroundTransparency=checked and .12 or .8
    skin(mark,'BackgroundColor3',checked and 'mint' or 'line')
    skin(mark,'TextColor3','bg')
end
local function renderMenuOptions()
    if not menuData then return end
    for _,connection in ipairs(menuConnections) do connection:Disconnect() end
    menuConnections={}
    for _,child in ipairs(menuList:GetChildren()) do
        if child:IsA('GuiButton') or child:IsA('TextLabel') then child:Destroy() end
    end
    local scrollBefore=menuList.CanvasPosition
    local query=tostring(menuSearch.Text):lower()
    local count=0
    for index,label in ipairs(menuData.options) do
        if tostring(label):lower():find(query,1,true) then
            count=count+1
            local selected=menuData.multi and menuData.selected and menuData.selected()[label]
            local caption=tostring(label)
            local choice=uiButton(menuList,caption,UDim2.new(1,-4,0,38))
            choice.LayoutOrder=index;choice.ZIndex=152;choice:SetAttribute('ChoiceLabel',tostring(label))
            choice.TextXAlignment=Enum.TextXAlignment.Left
            make('UIPadding',choice,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,44)})
            if menuData.multi then paintOption(choice,tostring(label),selected) end
            local callback=menuData.choose
            local indexValue,labelValue=index,label
            menuConnections[#menuConnections+1]=choice.MouseButton1Click:Connect(function()
                local data=menuData
                if data and data.multi then
                    callback(indexValue,labelValue)
                    for _,option in ipairs(menuList:GetChildren()) do
                        if option:IsA('TextButton') then
                            local label=option:GetAttribute('ChoiceLabel')
                            if label then
                                local checked=data.selected()[label]
                                paintOption(option,label,checked)
                            end
                        end
                    end
                else hideMenu();callback(indexValue,labelValue) end
            end)
        end
    end
    if count==0 then
        local empty=newText(menuList,'No matching options',12,false)
        empty.Size=UDim2.new(1,-8,0,38);empty.ZIndex=152
    end
    menuList.CanvasPosition=scrollBefore
end
menuSearch:GetPropertyChangedSignal('Text'):Connect(function() menuList.CanvasPosition=Vector2.new(0,0);renderMenuOptions() end)
local function openMenu(anchor,options,choose)
    hideMenu()
    local view=viewport()
    local width=math.min(420,view.X-24)
    local height=math.min(math.max(110,#options*43+60),420,view.Y-24)
    local position=anchor.AbsolutePosition
    local top=position.Y+anchor.AbsoluteSize.Y+6
    if top+height>view.Y-8 then top=position.Y-height-6 end
    menu.Size=UDim2.fromOffset(width,height)
    menu.Position=UDim2.fromOffset(math.clamp(position.X,8,math.max(8,view.X-width-8)),
        math.clamp(top,8,math.max(8,view.Y-height-8)))
    menuList.CanvasPosition=Vector2.new(0,0)
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
    local actionRole=({START='mint',STOP='rose',SAVE='mint',LOAD='violet',DELETE='rose',PREVIEW='gold',['SET AUTO LOAD']='gold'})[caption]
    if actionRole then
        skin(b,'BackgroundColor3','selected')
        skin(b,'TextColor3',actionRole)
        local edge=make('UIStroke',b,{Thickness=1,Transparency=.5})
        skin(edge,'Color',actionRole)
    end
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
-- Multi-select reuses the Origin UI searchable popup and preserves selections while filtering.
local function multiDropdown(label,options,getSet,onChange)
    local function currentOptions() return type(options)=='function' and options() or options end
    local button
    button=addAction('Story',label,'SELECT  ▾',function()
        if menu.Visible then hideMenu();return end
        openMenu(button,currentOptions(),function(_,value)
            local nextSet={}
            for k,v in pairs(getSet()) do nextSet[k]=v end
            nextSet[value]=not nextSet[value] or nil
            onChange(nextSet)
            repaintControls()
        end)
        menuData.multi=true
        menuData.selected=getSet
        renderMenuOptions()
    end)
    widgets[#widgets+1]=function()
        local count=0
        local available=currentOptions()
        for _,value in ipairs(available) do if getSet()[value] then count=count+1 end end
        button.Text=#available==0 and 'Choose maps first' or tostring(count)..' selected  ▾'
    end
    return button
end
local story=ctx.story
local mapLabels,cardLabels={},{ }
local mapLookup,cardLookup={},{ }
for _,w in ipairs(story.Worlds) do
    local label=w.name..' ['..w.map..']'
    mapLabels[#mapLabels+1]=label;mapLookup[label]=w.map
    for i,id in ipairs(w.cards) do
        label=w.name..' / '..id..(i==#w.cards and ' [BOSS]' or '')
        cardLabels[#cardLabels+1]=label;cardLookup[label]=id
    end
end
local function displaySet(lookup,selection)
    local result={}
    for label,id in pairs(lookup) do if selection[id] then result[label]=true end end
    return result
end
local function internalSet(lookup,selection)
    local result={}
    for label in pairs(selection) do if lookup[label] then result[lookup[label]]=true end end
    return result
end
orderCounter=orderCounter+1
local hero=make('Frame',tabPages.Story,{Name='StoryHero',Size=UDim2.new(1,-2,0,106),LayoutOrder=orderCounter,BorderSizePixel=0})
corner(hero,12);stroke(hero)
hero.BackgroundColor3=Color3.fromRGB(255,255,255)
make('UIGradient',hero,{Rotation=15,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(71,43,124)),ColorSequenceKeypoint.new(.6,Color3.fromRGB(26,88,124)),ColorSequenceKeypoint.new(1,Color3.fromRGB(20,111,101))})})
local heroTitle=newText(hero,'STORY AUTOMATION',19,true)
heroTitle.Position=UDim2.fromOffset(18,14);heroTitle.Size=UDim2.new(1,-36,0,26)
heroTitle.TextColor3=Color3.fromRGB(239,246,255)
skinned[heroTitle]=nil
local heroSub=newText(hero,'Build your route. Choose each fight. Keep moving forward.',12,false)
heroSub.Position=UDim2.fromOffset(18,44);heroSub.Size=UDim2.new(1,-36,0,20)
heroSub.TextColor3=Color3.fromRGB(179,203,230);skinned[heroSub]=nil
local heroCount=newText(hero,'6 WORLDS   /   36 ENCOUNTERS   /   5 DIFFICULTIES',11,true)
heroCount.Position=UDim2.fromOffset(18,76);heroCount.Size=UDim2.new(1,-36,0,18)
heroCount.TextColor3=Color3.fromRGB(99,232,217);skinned[heroCount]=nil
section('Story','Story selection')
multiDropdown('Maps',mapLabels,function() return displaySet(mapLookup,flags.StoryMaps) end,
    function(value) setFlag('StoryMaps',internalSet(mapLookup,value)) end)
multiDropdown('Mob / Boss',function() return story.targetOptions(flags.StoryMaps) end,function() return displaySet(cardLookup,flags.StoryCards) end,
    function(value) setFlag('StoryCards',internalSet(cardLookup,value)) end)
section('Story','Modes per mob / boss')
-- Each selected target reveals its own difficulty multi-dropdown. Defaults to Easy.
local modeRows={}
for _,w in ipairs(story.Worlds) do
    for i,id in ipairs(w.cards) do
        local button=multiDropdown(id..(i==#w.cards and ' [BOSS]' or ''),story.Modes,
            function() return flags.StoryModes[id] or {} end,
            function(value)
                local nextModes={}
                for k,v in pairs(flags.StoryModes) do nextModes[k]=v end
                nextModes[id]=value;setFlag('StoryModes',nextModes)
            end)
        modeRows[#modeRows+1]={row=button.Parent,id=id,map=w.map}
    end
end
widgets[#widgets+1]=function()
    for _,entry in ipairs(modeRows) do
        entry.row.Visible=flags.StoryMaps[entry.map]==true and flags.StoryCards[entry.id]==true
    end
end
local preview
section('Story','Queue and controls')
addToggle('Story','Repeat whole queue','StoryRepeat')
addAction('Story','Preview ordered queue','PREVIEW',function()
    local queue=story.buildQueue(flags)
    local lines={}
    for i,item in ipairs(queue) do lines[#lines+1]=i..'. '..item.world..' / '..item.cardId..' / '..item.difficulty end
    local text=#lines>0 and table.concat(lines,'\n') or 'Empty queue'
    preview.Text=text
    preview.Size=UDim2.new(1,-4,0,math.max(40,#lines*19+12))
    notify(tostring(#queue)..' fights selected','info')
end)
addAction('Story','Start selected story','START',ctx.start)
addAction('Story','Stop after current request','STOP',ctx.pause)
local storyStatus=addStatus('Story','Status','Ready')
local storyCurrent=addStatus('Story','Current target','--')
local storyCount=addStatus('Story','Queue position','0 / 0')
-- Multi-line preview is a dedicated block, not a fixed-height control row.
orderCounter=orderCounter+1
preview=newText(tabPages.Story,'Press PREVIEW to show the ordered queue.',12,false)
preview.LayoutOrder=orderCounter;preview.Size=UDim2.new(1,-4,0,40)
preview.TextWrapped=true;preview.TextTruncate=Enum.TextTruncate.None
preview.TextYAlignment=Enum.TextYAlignment.Top
section('Story','Combat detection')
addStatus('Story','Combat signal','Server battleId / lane')
addStatus('Story','Victory signal','BattleEnd.won (matching battleId)')
addAction('Story','Export received battle payloads','COPY CAPTURE',ctx.exportCapture)
section('Config','Profiles')
local profileName=profile.currentProfile
local nameBox=addInput('Config','Profile name','ProfileName','Default')
flags.ProfileName=profile.currentProfile
local savedDrop
savedDrop=addAction('Config','Saved profiles','SELECT  ▾',function()
    openMenu(savedDrop,profile.storedNames,function(_,name)
        flags.ProfileName=name;profile.currentProfile=name;repaintControls()
    end)
end)
addAction('Config','Save profile','SAVE',function() ctx.saveProfile(flags.ProfileName) end)
addAction('Config','Load profile','LOAD',function() ctx.loadProfile(flags.ProfileName) end)
addAction('Config','Delete profile','DELETE',function() ctx.deleteProfile(flags.ProfileName) end)
addAction('Config','Load on next execute','SET AUTO LOAD',function() ctx.setAutoProfile(flags.ProfileName) end)
local configStatus=addStatus('Config','Storage','Ready')
local configAuto=addStatus('Config','Auto Load','None')
section('Settings','Origin UI appearance')
addDropdown('Settings','Theme','AO_UI_Theme',{'Midnight','Ocean','Violet','Emerald','Rose','Light'})
addDropdown('Settings','Transparency %','AO_UI_Transparency',{0,15,30,45,65})
addAction('Settings','Unload script and UI','UNLOAD',function() state.stop() end)

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
    cancelInteraction();suspendOverlays();
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
local touchRoot=make('ScreenGui',playerGui,{
    Name='OriginStoryToggle',ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9901,Enabled=UIS.TouchEnabled==true,
})
local touchToggle=uiButton(touchRoot,'AO',UDim2.fromOffset(46,40))
touchToggle.Name='TouchWindowToggle'
touchToggle.Position=UDim2.new(1,-54,0,54)
touchToggle.MouseButton1Click:Connect(function()
    if lifecycle.alive then setWindowVisible(not window.visible) end
end)
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
    if not root.Enabled then cancelInteraction();suspendOverlays(); end
    shadow.Visible=root.Enabled
end))
hide.MouseButton1Click:Connect(function()
    cancelInteraction();suspendOverlays();
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
    cancelInteraction();suspendOverlays()
    for connection in pairs(lifecycle.connections) do disconnectUI(connection) end
    for obj,tween in pairs(lifecycle.tweens) do tween:Cancel();lifecycle.tweens[obj]=nil end
    if touchRoot.Parent then touchRoot:Destroy() end
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
local function refreshOverview()
    if not lifecycle.alive or not root.Enabled or window.minimized then return end
    pumpToast()
    showStatus(sessionBadge,state.enabled and 'RUNNING' or 'STANDBY')
    showStatus(storyStatus,state.status or 'Ready')
    showStatus(configStatus,profile.status or 'Ready')
    showStatus(configAuto,profile.autoProfile~='' and profile.autoProfile or 'None')
    local current=state.current
    showStatus(storyCurrent,current and (current.cardId..' / '..current.difficulty) or '--')
    showStatus(storyCount,tostring(state.index)..' / '..tostring(#state.queue))
end
repaintControls()
refreshOverview()
return {Repaint=repaintControls,Refresh=refreshOverview,Root=root,Notify=notify,Destroy=destroyUI}
end
return Library

end)()
local env=(getgenv and getgenv()) or _G
local previous=env.OriginStory
-- An InvokeServer cannot be cancelled. Do not create a second controller while one is pending.
if previous and previous.pending then error('Origin Story: previous request still pending; wait for it to return.') end
if previous and previous.stop then previous.stop() end
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local player=Players.LocalPlayer
assert(player,'Origin Story requires a client session')
local net=game:GetService('ReplicatedStorage'):WaitForChild('Shared',15)
assert(net,'Shared not found')
net=net:WaitForChild('Net',15)
assert(net,'Net not found')
net=net:WaitForChild('RemoteObjects',30)
assert(net,'RemoteObjects not found')
local action=net:WaitForChild('BattleAction',15)
assert(action and action:IsA('RemoteFunction'),'BattleAction RemoteFunction not found')
local flags={AO_UI_Theme='Midnight',AO_UI_Transparency=15,StoryMaps={},StoryCards={},StoryModes={},StoryRepeat=false}
for _,w in ipairs(Story.Worlds) do
    for _,id in ipairs(w.cards) do flags.StoryModes[id]={Easy=true} end
end
local state={alive=true,enabled=false,connections={},status='Ready',index=0,queue={},pending=false,logs={},awaiting=false,runId=0}
env.OriginStory=state
local ui
local function message(text,kind)
    state.status=text
    if ui then ui.Notify(text,kind or 'info',4) end
end
local function snapshot(value,depth,seen)
    local t=typeof(value)
    if t=='nil' then return '<nil>' end
    if t=='boolean' or t=='number' then return value end
    if t=='string' then return value:sub(1,1000) end
    if t~='table' then return '<'..t..'>' end
    if depth>=5 or seen[value] then return '<limited>' end
    seen[value]=true
    local result={};local count=0
    for k,v in pairs(value) do
        count=count+1;if count>60 then result['<truncated>']=true;break end
        result[tostring(k)]=snapshot(v,depth+1,seen)
    end
    seen[value]=nil
    return result
end
local function log(source,args)
    state.logs[#state.logs+1]={source=source,time=os.clock(),args=snapshot(args,0,{})}
    if #state.logs>60 then table.remove(state.logs,1) end
end
local function stopRun(reason)
    state.enabled=false;state.runId=state.runId+1
    if reason then message(reason,'warning') end
end
local battleEvent=net:WaitForChild('BattleEvent',15)
assert(battleEvent and battleEvent:IsA('RemoteEvent'),'BattleEvent RemoteEvent missing')
state.connections[#state.connections+1]=battleEvent.OnClientEvent:Connect(function(event)
    local attempt=state.attempt
    if not attempt or not state.enabled then return end
    Combat.event(attempt,event)
    if type(event)=='table' and event.type=='BattleEnd' then
        log('BattleEnd',{battleId=event.battleId,lane=event.lane,difficulty=event.difficulty,won=event.won,matched=Combat.match(attempt,event)})
    end
end)
local function beginRun()
    if state.enabled or state.pending then message('A run/request is already active.','warning');return end
    local queue=Story.buildQueue(flags)
    if #queue==0 then message('Select maps, targets and at least one mode per target.','warning');return end
    state.queue=queue;state.index=0;state.enabled=true;state.runId=state.runId+1
    local runId=state.runId
    local function active() return state.alive and state.enabled and state.runId==runId end
    local function waitSeconds(seconds)
        local deadline=os.clock()+seconds
        while active() and os.clock()<deadline do task.wait(.1) end
        return active()
    end
    task.spawn(function()
        local i=1
        while active() and i<=#queue do
            local item=queue[i]
            local attempt=Combat.new()
            state.index=i;state.current=item;state.attempt=attempt;state.awaiting=true;state.pending=true
            log('StartRequest',{index=i,cardId=item.cardId,difficulty=item.difficulty})
            message('Starting '..item.cardId..' / '..item.difficulty)
            task.spawn(function()
                local response=table.pack(pcall(function()
                    return action:InvokeServer('StartEncounter',{difficulty=item.difficulty,cardId=item.cardId})
                end))
                state.pending=false;attempt.returned=true;attempt.response=response
                log('StartResponse',response)
                if active() then Combat.accept(attempt,response,item) end
            end)
            local startDeadline=os.clock()+30
            while active() and state.pending and os.clock()<startDeadline do task.wait(.1) end
            if not active() then break end
            if state.pending then stopRun('Start request still pending; stopped without sending another request.');break end
            if not attempt.started then
                -- Unknown admission is not a loss. Do not repeatedly start an untracked fight.
                state.attempt=nil;state.awaiting=false
                stopRun('Server did not return a verified Story battle ID; see COPY CAPTURE.');break
            end
            log('StoryAdmitted',{battleId=attempt.battleId,lane=attempt.lane,cardId=item.cardId,difficulty=item.difficulty})
            state.status='Waiting for BattleEnd: '..item.cardId..' / '..item.difficulty
            local endDeadline=os.clock()+900
            while active() and not attempt.ended do
                if os.clock()>endDeadline then stopRun('No matching BattleEnd after 15 minutes; stopped, result unknown.');break end
                task.wait(.1)
            end
            if not active() then break end
            local won=attempt.won
            log('BattleResult',{battleId=attempt.battleId,lane=attempt.lane,index=i,cardId=item.cardId,difficulty=item.difficulty,won=won})
            state.awaiting=false;state.attempt=nil
            if won then
                message('WIN: '..item.cardId..' / '..item.difficulty,'success')
                i=i+1
                if i>#queue and flags.StoryRepeat then i=1 end
            else
                message('LOSS: retrying '..item.cardId..' / '..item.difficulty,'warning')
            end
            if not waitSeconds(won and 1 or 3) then break end
        end
        if active() then state.enabled=false;state.attempt=nil;message('Selected story queue won and completed.','success') end
    end)
end
state.stop=function()
    state.alive=false;state.enabled=false
    for _,c in ipairs(state.connections) do pcall(function() c:Disconnect() end) end
    state.connections={}
    if ui then ui.Destroy() end
end
local function exportCapture()
    local data=HttpService:JSONEncode({note='Local received battle payloads; no network upload',records=state.logs})
    if type(setclipboard)=='function' then setclipboard(data);message('Battle capture copied.','success')
    elseif type(writefile)=='function' then writefile('OriginStory-capture.json',data);message('Saved OriginStory-capture.json','success')
    else print(data);message('Battle capture printed in console.') end
end
local function setFlag(key,value)
    flags[key]=value
    if ui then ui.Repaint() end
end
local profile={currentProfile='Default',autoProfile='',storedNames={},status='Ready',revision=0}
local profileDir='OriginStory'
local canFiles=type(readfile)=='function' and type(writefile)=='function' and type(isfile)=='function' and type(makefolder)=='function'
local index={names={},auto=''}
local function validName(name)
    return type(name)=='string' and #name>0 and #name<=48 and name:match('^[%w _%-]+$')~=nil
end
local function path(name) return profileDir..'/'..name..'.json' end
local function writeIndex() writefile(profileDir..'/index.json',HttpService:JSONEncode(index)) end
local function profileMessage(text,kind) profile.status=text;message(text,kind) end
local function loadProfile(name,quiet)
    if state.enabled or state.pending then profileMessage('Stop Story before loading a profile.','warning');return false end
    if not canFiles or not validName(name) then profileMessage('File APIs unavailable or invalid profile name.','warning');return false end
    local ok,data=pcall(function() return HttpService:JSONDecode(readfile(path(name))) end)
    if not ok or type(data)~='table' or data.version~=1 or type(data.flags)~='table' then
        profileMessage('Cannot load profile: '..tostring(name),'error');return false
    end
    local nextFlags=data.flags
    local maps,cards,modes={},{},{}
    for _,world in ipairs(Story.Worlds) do
        if type(nextFlags.StoryMaps)=='table' and nextFlags.StoryMaps[world.map]==true then maps[world.map]=true end
        for _,id in ipairs(world.cards) do
            if type(nextFlags.StoryCards)=='table' and nextFlags.StoryCards[id]==true then cards[id]=true end
            modes[id]={}
            local selection=type(nextFlags.StoryModes)=='table' and nextFlags.StoryModes[id]
            for _,mode in ipairs(Story.Modes) do
                if type(selection)=='table' and selection[mode]==true then modes[id][mode]=true end
            end
        end
    end
    flags.StoryMaps=maps;flags.StoryCards=cards;flags.StoryModes=modes
    flags.StoryRepeat=nextFlags.StoryRepeat==true
    for key,value in pairs(nextFlags) do
        if type(key)=='string' and key:match('^AO_UI_') and (type(value)=='string' or type(value)=='number') then flags[key]=value end
    end
    profile.currentProfile=name;profile.status='Loaded: '..name
    if ui then ui.Repaint() end
    if not quiet then profileMessage(profile.status,'success') end
    return true
end
local function saveProfile(name)
    if not canFiles then profileMessage('Executor file APIs unavailable.','warning');return end
    if not validName(name) then profileMessage('Use 1–48 letters, numbers, spaces, _ or -.','warning');return end
    local ok=pcall(function()
        writefile(path(name),HttpService:JSONEncode({version=1,flags=flags}))
        if not table.find(index.names,name) then table.insert(index.names,name);table.sort(index.names) end
        writeIndex()
    end)
    if ok then profile.currentProfile=name;profile.storedNames=index.names;profileMessage('Saved: '..name,'success')
    else profileMessage('Profile save failed.','error') end
end
local function deleteProfile(name)
    if not canFiles or not validName(name) or type(delfile)~='function' then profileMessage('Delete/file APIs unavailable.','warning');return end
    local ok=pcall(function()
        if isfile(path(name)) then delfile(path(name)) end
        for i=#index.names,1,-1 do if index.names[i]==name then table.remove(index.names,i) end end
        if index.auto==name then index.auto='';profile.autoProfile='' end
        writeIndex()
    end)
    if ok then profile.storedNames=index.names;profileMessage('Deleted: '..name,'success') else profileMessage('Delete failed.','error') end
end
local function setAutoProfile(name)
    if not canFiles or not validName(name) or not table.find(index.names,name) then profileMessage('Save this profile first.','warning');return end
    index.auto=name
    local ok=pcall(writeIndex)
    if ok then profile.autoProfile=name;profileMessage('Auto Load: '..name,'success') else profileMessage('Auto Load save failed.','error') end
end
if canFiles then
    local ok=pcall(function()
        if type(isfolder)~='function' or not isfolder(profileDir) then pcall(makefolder,profileDir) end
        if isfile(profileDir..'/index.json') then
            local data=HttpService:JSONDecode(readfile(profileDir..'/index.json'))
            if type(data)=='table' and type(data.names)=='table' then
                for _,name in ipairs(data.names) do if validName(name) then index.names[#index.names+1]=name end end
                if validName(data.auto) then index.auto=data.auto end
            end
        end
    end)
    profile.storedNames=index.names;profile.autoProfile=index.auto
    if ok and index.auto~='' then loadProfile(index.auto,true) end
else profile.status='File APIs unavailable; session only' end

ui=Library.Create({playerGui=player:WaitForChild('PlayerGui'),state=state,flags=flags,
    Workspace=game:GetService('Workspace'),UIS=game:GetService('UserInputService'),env=env,
    profile=profile,saveProfile=saveProfile,loadProfile=loadProfile,deleteProfile=deleteProfile,setAutoProfile=setAutoProfile,
    setFlag=setFlag,story=Story,start=beginRun,pause=function() stopRun('Stopped; current battle continues in game.') end,
    clearBattle=function()
        if state.pending or state.enabled then message('Stop and wait for pending request first.','warning');return end
        state.awaiting=false;message('Previous battle marked ended; ready to start.')
    end,
    exportCapture=exportCapture,
})
task.spawn(function()
    while state.alive do ui.Repaint();ui.Refresh();task.wait(.3) end
end)
message('Ready: server BattleEnd results matched by battleId.')
