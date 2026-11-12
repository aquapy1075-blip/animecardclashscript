-- Skeleton Raid: timed-jump assist, server-event-driven auto-start and automatic Ready.
-- Uses native movement; does not change HP, invulnerability, hits, timers or raid results.
local Dodge=(function()
local Dodge={}
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function distance(x,y,ax,ay,bx,by)
    local dx,dy=bx-ax,by-ay
    local square=dx*dx+dy*dy
    local t=square>1e-8 and clamp(((x-ax)*dx+(y-ay)*dy)/square,0,1) or 0
    return math.sqrt((x-ax-dx*t)^2+(y-ay-dy*t)^2)
end
Dodge.distance=distance
function Dodge.risk(objects,x,y,moved,time,hitRadius)
    local cost=0
    local function segment(ax,ay,bx,by,width,weight)
        local clearance=distance(x,y,ax,ay,bx,by)-width-hitRadius
        if clearance<0 then cost=cost+(500-clearance*30)*(weight or 1)
        elseif clearance<18 then cost=cost+(18-clearance)^2*.1*(weight or 1) end
    end
    for _,object in ipairs(objects) do
        local e=object.e
        if type(e)=='table' and not object.dying then
            local age=time-(object.born or e.t or 0)
            local col=e.col or 'w'
            local dangerous=col=='w' or (col=='b' and moved) or (col=='o' and not moved)
            if age>=0 and object.kind=='bone' and dangerous and age<=(e.life or 0) and (not e.warn or age>=e.warn) then
                local grow=e.warn and e.grow and clamp((age-e.warn)/e.grow,0,1) or 1
                local ax,ay=e.ax+(e.vx or 0)*age,e.ay+(e.vy or 0)*age
                segment(ax,ay,ax+(e.bx-e.ax)*grow,ay+(e.by-e.ay)*grow,(e.th or 13)*.42)
            elseif age>=.5 and object.kind=='spin' and dangerous and age<=(e.dur or 0) then
                for arm=1,e.arms do
                    local angle=math.rad(e.omega*age+(arm-1)*360/e.arms)
                    local cx,cy=math.cos(angle),math.sin(angle)
                    segment(cx*e.r0,cy*e.r0,cx*e.len,cy*e.len,(e.th or 13)*.42)
                end
            elseif object.kind=='beam' and age>=(e.warn or 0)-.3 and age<(e.warn or 0)+(e.fire or 0) then
                local angle=math.rad(object.ang or e.ang or 0)
                local ox,oy=object.ox or e.x,object.oy or e.y
                if type(ox)=='number' and type(oy)=='number' then
                    segment(ox,oy,ox+math.cos(angle)*4000,oy+math.sin(angle)*4000,(e.w or 20)*.4,age<(e.warn or 0) and .6 or 1)
                end
            end
        end
    end
    return cost
end
local directions={D={0,1},U={0,-1},L={-1,0},R={1,0}}
function Dodge.predict(heart,cur,box,dx,dy,jump,dt)
    local moved=math.sqrt(dx*dx+dy*dy)>.05
    if heart.mode=='blue' then
        local d=directions[heart.dir] or directions.D
        local gx,gy=d[1],d[2];local tx,ty=-gy,gx
        local tangent=dx*tx+dy*ty
        local gravityVelocity=heart.vx*gx+heart.vy*gy
        local jumpDown=jump or (dx*(-gx)+dy*(-gy)>.5)
        if jumpDown and not heart.jumpWas then heart.jumpBuf=.15 end
        heart.jumpWas=jumpDown
        local jumping=jumpDown or (heart.jumpBuf or 0)>0
        heart.jumpBuf=math.max(0,(heart.jumpBuf or 0)-dt)
        if heart.grounded and jumping then gravityVelocity=-box.jump;heart.grounded=false;heart.lowGrav=math.max(heart.lowGrav or 0,.15) end
        gravityVelocity=gravityVelocity+box.gravity*((jumpDown or (heart.lowGrav or 0)>0) and gravityVelocity<0 and .55 or 1)*dt
        heart.lowGrav=math.max(0,(heart.lowGrav or 0)-dt)
        if not heart.slam then gravityVelocity=math.min(gravityVelocity,box.fall) end
        heart.vx=gx*gravityVelocity+tx*tangent*box.speed
        heart.vy=gy*gravityVelocity+ty*tangent*box.speed
        heart.x=heart.x+heart.vx*dt;heart.y=heart.y+heart.vy*dt
        moved=math.abs(tangent)>.05 or jumping
    else
        heart.x=heart.x+dx*box.speed*dt;heart.y=heart.y+dy*box.speed*dt
    end
    local r=box.heartRadius
    local minX,maxX=cur.x-cur.w/2+r,cur.x+cur.w/2-r
    local minY,maxY=cur.y-cur.h/2+r,cur.y+cur.h/2-r
    local wall=(heart.dir=='D' and heart.y>maxY) or (heart.dir=='U' and heart.y<minY) or (heart.dir=='L' and heart.x<minX) or (heart.dir=='R' and heart.x>maxX)
    heart.x=clamp(heart.x,minX,maxX);heart.y=clamp(heart.y,minY,maxY)
    if heart.mode=='blue' then
        heart.grounded=wall
        if wall then
            local d=directions[heart.dir] or directions.D
            local speed=heart.vx*d[1]+heart.vy*d[2]
            if speed>0 then heart.vx=heart.vx-d[1]*speed;heart.vy=heart.vy-d[2]*speed end
            heart.slam=false
        else moved=true end
    end
    heart.moved=moved and .12 or math.max(0,(heart.moved or 0)-dt)
    return heart
end
function Dodge.choose(instance,box,time)
    local blue=instance.heart.mode=='blue'
    local d=directions[instance.heart.dir] or directions.D
    local tx,ty=-d[2],d[1]
    -- Blue movement stays tangent to gravity. An upward direction must not
    -- silently become a jump before the explicit jump policy says so.
    local moves=blue and {{0,0},{tx,ty},{-tx,-ty}} or {{0,0},{-1,0},{1,0},{0,-1},{0,1},{-.7071,-.7071},{.7071,-.7071},{-.7071,.7071},{.7071,.7071}}
    local policies={{delay=math.huge,hold=0}}
    if blue then
        for _,delay in ipairs({0,.1,.2,.3,.4,.5}) do
            for _,hold in ipairs({.18,.42}) do policies[#policies+1]={delay=delay,hold=hold} end
        end
    end
    local best,bestCost=nil,math.huge
    local steps=blue and 20 or 8
    for _,direction in ipairs(moves) do
        for _,policy in ipairs(policies) do
            local dx,dy=direction[1],direction[2]
            local heart={}
            for key,value in pairs(instance.heart) do heart[key]=value end
            if blue and instance.input then
                heart.jumpWas=instance.input.jumpWas==true
                heart.jumpBuf=tonumber(instance.input.jumpBuf) or 0
            end
            local cost=0
            for step=1,steps do
                local elapsed=(step-1)*.05
                local jump=elapsed>=policy.delay and elapsed<policy.delay+policy.hold
                Dodge.predict(heart,instance.cur,box,dx,dy,jump,.05)
                cost=cost+Dodge.risk(instance.objs,heart.x,heart.y,heart.moved>0,time+step*.05,box.hitRadius)*(1-step*.025)
            end
            local centerX,centerY=heart.x-instance.cur.x,heart.y-instance.cur.y
            -- Do not reward a blue heart for jumping toward the box center.
            -- That previous vertical-centering cost caused idle/early jumps.
            local centerCost=blue and (centerX*tx+centerY*ty)^2 or centerX^2+centerY^2
            cost=cost+centerCost*.00004+(dx*dx+dy*dy)*.03
            if policy.hold>0 then cost=cost+.12+policy.hold*.04 end
            local jumpNow=policy.delay==0
            if cost<bestCost then bestCost=cost;best={x=dx,y=dy,jump=jumpNow,jumpDelay=policy.delay,jumpHold=policy.hold} end
        end
    end
    return best,bestCost
end
return Dodge

end)()
local env=(getgenv and getgenv()) or _G
if env.OriginSkeletonDodge then env.OriginSkeletonDodge.stop() end
local root=game:GetService('ReplicatedStorage'):WaitForChild('Shared'):WaitForChild('SkeletonRaid')
local config=require(root:WaitForChild('Config'))
local module=root:FindFirstChild('DodgeBox',true)
assert(module and module:IsA('ModuleScript'),'SkeletonRaid DodgeBox not found')
local native=require(module)
assert(type(native)=='table' and type(native._moveHeart)=='function','Unsupported DodgeBox interface')
local original=native._moveHeart
local originalUpdate=native.update
local updateWrapper
local state={enabled=true,controlled=setmetatable({}, {__mode='k'}),decisions=0,lastError=nil,phase=nil,round=0,result=nil,autoStart=true,difficulty='Final',raidActive=false,waitingStart=false,startAttempts=0,nextStartAt=os.clock()+2,autoReady=true,pickSent=false,pickAttempts=0,readyConfirmed=false,deckOptions=nil}
env.OriginSkeletonDodge=state
local wrapper
wrapper=function(self,dt)
    if state.enabled and self.running and self.visible and type(self.heart)=='table' and type(self.cur)=='table' and type(self.objs)=='table' and type(self.input)=='table' then
        local entry=state.controlled[self] or {nextAt=0}
        state.controlled[self]=entry
        local now=os.clock()
        if now>=entry.nextAt then
            local ok,decision=pcall(Dodge.choose,self,config.Box,entry.frameTime or (workspace:GetServerTimeNow()-self.t0))
            if ok and decision then
                entry.decision=decision;entry.nextAt=now+.05;state.decisions=state.decisions+1
            else
                state.lastError=tostring(decision);state.enabled=false
                self.input.stick=Vector2.zero;self.input.btnJump=false
                warn('Skeleton dodge stopped: '..state.lastError)
            end
        end
        if state.enabled and entry.decision then
            self.input.stick=Vector2.new(entry.decision.x,entry.decision.y)
            self.input.btnJump=entry.decision.jump
        end
    end
    return original(self,dt)
end
native._moveHeart=wrapper
if type(originalUpdate)=='function' then
    updateWrapper=function(self,dt,time)
        local entry=state.controlled[self] or {nextAt=0}
        state.controlled[self]=entry
        if type(time)=='number' and type(self.t0)=='number' then entry.frameTime=time-self.t0 end
        if self.running then state.raidActive=true;state.waitingStart=false end
        return originalUpdate(self,dt,time)
    end
    native.update=updateWrapper
end
local event=game:GetService('ReplicatedStorage').Shared.Net.RemoteObjects:FindFirstChild('SkeletonRaid')
local function resetPick()
    state.deckOptions=nil;state.pickSent=false;state.readyConfirmed=false;state.readyStatus=nil
end
local function tryReady()
    if not state.enabled then return false,'Assist stopped' end
    if state.phase~='Pick' then return false,'Not in Pick phase' end
    if state.pickSent then return false,'Ready already sent for this raid' end
    if type(state.deckOptions)~='table' then return false,'Waiting for Deck options' end
    local found={}
    for _,option in pairs(state.deckOptions) do
        if type(option)=='table' and type(option.index)=='number' then found[option.index]=true end
    end
    for index=1,5 do if not found[index] then return false,'Deck does not contain indices 1–5' end end
    if not event or not event:IsA('RemoteEvent') then return false,'SkeletonRaid RemoteEvent missing' end
    state.pickSent=true;state.pickAttempts=state.pickAttempts+1
    local ok,err=pcall(function() event:FireServer('Pick',{1,2,3,4,5}) end)
    if not ok then state.autoReady=false;state.lastError='Ready send failed: '..tostring(err);return false,state.lastError end
    return true,'Ready sent; waiting for Take phase'
end
state.readyRaid=tryReady
local connection
if event and event:IsA('RemoteEvent') then
    connection=event.OnClientEvent:Connect(function(payload)
        if type(payload)~='table' then return end
        if payload.kind=='Phase' then
            if payload.phase=='Prepare' then
                local key=tostring(payload.seed)..'|'..tostring(payload.startAt)
                if key~=state.pickRunKey then state.pickRunKey=key;resetPick() end
            end
            state.phase=payload.phase;state.round=payload.round or 0
            if payload.phase=='Take' then state.readyConfirmed=true;state.readyStatus='Pick completed (Take)' end
            state.raidActive=true;state.waitingStart=false
        end
        if payload.kind=='Deck' then state.deckOptions=payload.options end
        if payload.kind=='Take' then state.readyConfirmed=true;state.readyStatus='Pick completed (Take)' end
        if state.autoReady and (payload.kind=='Deck' or (payload.kind=='Phase' and payload.phase=='Pick')) then
            local ok,reason=tryReady()
            state.readyStatus=reason
        end
        if payload.kind=='Closed' then
            state.raidActive=false;state.waitingStart=false;state.phase='Closed'
            state.nextStartAt=os.clock()+2
        end
        if payload.kind=='Result' then state.result=payload.data end
    end)
end
state.stop=function()
    state.enabled=false;state.autoStart=false;state.autoReady=false
    if native._moveHeart==wrapper then native._moveHeart=original end
    if updateWrapper and native.update==updateWrapper then native.update=originalUpdate end
    for instance in pairs(state.controlled) do
        if instance.input then instance.input.stick=Vector2.zero;instance.input.btnJump=false end
    end
    if connection then connection:Disconnect();connection=nil end
end
state.status=function()
    return {enabled=state.enabled,phase=state.phase,round=state.round,decisions=state.decisions,lastError=state.lastError,result=state.result,autoStart=state.autoStart,difficulty=state.difficulty,raidActive=state.raidActive,waitingStart=state.waitingStart,startAttempts=state.startAttempts,autoReady=state.autoReady,pickSent=state.pickSent,pickAttempts=state.pickAttempts,readyConfirmed=state.readyConfirmed,readyStatus=state.readyStatus}
end
local function lobbyRemote()
    local shared=game:GetService('ReplicatedStorage'):FindFirstChild('Shared')
    local raids=shared and shared:FindFirstChild('GuestRaids')
    local folder=raids and raids:FindFirstChild('Remotes')
    local remote=folder and folder:FindFirstChild('Lobby')
    return remote and remote:IsA('RemoteEvent') and remote or nil
end
state.startRaid=function()
    if not state.enabled then return false,'Assist stopped' end
    if state.raidActive or state.waitingStart then return false,'Raid active or start pending' end
    if type(config.Difficulties)~='table' or not config.Difficulties[state.difficulty] then return false,'Unknown difficulty' end
    local lobby=lobbyRemote()
    if not lobby then return false,'GuestRaids.Remotes.Lobby missing' end
    resetPick()
    local ok,err=pcall(function() lobby:FireServer('Start','SkeletonBoss',state.difficulty) end)
    if not ok then return false,tostring(err) end
    state.startAttempts=state.startAttempts+1;state.waitingStart=true;state.startSentAt=os.clock()
    state.nextStartAt=nil;state.phase='StartRequested'
    return true,'Start requested; waiting for server Phase'
end
task.spawn(function()
    while state.enabled do
        if state.waitingStart and os.clock()-(state.startSentAt or os.clock())>15 then
            state.waitingStart=false;state.autoStart=false;state.nextStartAt=nil
            state.lastError='Start not confirmed by server; auto-start paused. Check proximity/unlocks, then call startRaid() to retry.'
            warn(state.lastError)
        elseif state.autoStart and not state.raidActive and not state.waitingStart and state.nextStartAt and os.clock()>=state.nextStartAt then
            local ok,err=state.startRaid()
            if not ok then state.autoStart=false;state.nextStartAt=nil;state.lastError=tostring(err);warn('Skeleton auto-start paused: '..state.lastError) end
        end
        task.wait(.25)
    end
end)
print('Skeleton: timed-jump assist + auto-start Final enabled. Auto Ready selects indices 1–5. Stop: getgenv().OriginSkeletonDodge.stop()')
