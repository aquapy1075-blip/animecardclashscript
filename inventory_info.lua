repeat task.wait() until game:IsLoaded()
local RS = game:GetService('ReplicatedStorage')
local Http = game:GetService('HttpService')
local Shared = RS:WaitForChild('Shared')
local Config = Shared:WaitForChild('Config')
local Net = Shared:WaitForChild('Net'):WaitForChild('RemoteObjects')
local Stats = require(Shared.Util.CardStats)
local Abilities = require(Shared.UI.AbilityRules)
local Accessories = require(Config.AccessoryConfig)
local profile
local connection = Net:WaitForChild('ProfileSync').OnClientEvent:Connect(function(data)
    if type(data) == 'table' and type(data.cards) == 'table' and type(data.decks) == 'table' then
        profile = data
    end
end)
local ok, err = pcall(function() Net:WaitForChild('RequestSync', 10):FireServer() end)
if not ok then connection:Disconnect();error('RequestSync: '..tostring(err)) end
local deadline = os.clock() + 15
repeat task.wait(.1) until profile or os.clock() > deadline
connection:Disconnect()
assert(profile, 'Chua nhan duoc deck. Mo menu Deck roi chay lai.')
local index = profile.decks.active or 1
local presets = profile.decks.presets or {}
local deck = presets[index] or presets[tostring(index)]
assert(type(deck) == 'table', 'Khong tim thay preset dang dung: '..tostring(index))
local function clean(value, depth)
    depth = depth or 0
    if depth > 8 then return nil end
    local kind = type(value)
    if kind == 'string' or kind == 'number' or kind == 'boolean' then return value end
    if kind ~= 'table' then return nil end
    local out = {}
    for k,v in pairs(value) do
        local item = clean(v, depth+1)
        if item ~= nil and (type(k)=='string' or type(k)=='number') then out[tostring(k)] = item end
    end
    return out
end
local function lineup(entries)
    local out = {}
    for slot=1,5 do
        local entry = entries and (entries[slot] or entries[tostring(slot)])
        if type(entry)=='table' and type(entry.cardId)=='string' then
            local id = entry.cardId
            local variant = entry.variant or 'Standard'
            local owned = profile.cards[Stats.key(id, variant)] or {}
            local level = owned.level or 0
            local def = Stats.definition(id) or {}
            local ability = Abilities.forCard(id) or {}
            local statsOK, stats = pcall(Stats.compute, id, variant, level)
            local accOK, accId, accLevel = pcall(Accessories.equipOn, profile, Stats.key(id,variant))
            out[#out+1] = {
                slot=slot, cardId=id, name=def.name or id, variant=variant, level=level,
                stats=statsOK and stats or nil,
                statsError=not statsOK and tostring(stats) or nil,
                passive=clean(ability.passive), active=clean(ability.active),
                limits=clean(ability.limits), tags=clean(ability.tags),
                accessory=accOK and accId and {id=accId,level=accLevel} or nil
            }
        end
    end
    return out
end
local inventory, definitions, errors = {}, {}, {}
local totalCopies = 0
for key, owned in pairs(profile.cards) do
    if type(key)=='string' and type(owned)=='table' then
        local id, variant = Stats.parseKey(key)
        local count = tonumber(owned.count) or 1
        if id and variant and count>0 then
            local level=owned.level or 0
            local okRow,row=pcall(function()
                local def=Stats.definition(id)
                local stats=Stats.compute(id,variant,level)
                local accId,accLevel=Accessories.equipOn(profile,key)
                if not definitions[id] then
                    local ability=Abilities.forCard(id) or {}
                    definitions[id]={
                        name=def and def.name or id,
                        isSupport=Stats.isSupport(id),
                        passive=clean(ability.passive),active=clean(ability.active),
                        limits=clean(ability.limits),tags=clean(ability.tags)
                    }
                end
                return {cardId=id,variant=variant,level=level,count=count,stats=stats,
                    accessory=accId and {id=accId,level=accLevel} or nil}
            end)
            if okRow then inventory[#inventory+1]=row;totalCopies=totalCopies+count
            else errors[#errors+1]={cardId=id,variant=variant,error=tostring(row)} end
        end
    end
end
table.sort(inventory,function(a,b)
    if a.cardId~=b.cardId then return a.cardId<b.cardId end
    return a.variant<b.variant
end)
local report={
    game='Anime Card Online',version=1,preset=index,
    statsNote='CardStats: level + border, excluding combat buffs, accessories and System modifiers.',
    inventoryEntries=#inventory,totalCopies=totalCopies,
    inventory=inventory,abilities=definitions,errors=errors,
    attack=lineup(deck.attack),support=lineup(deck.support)
}
local output=Http:JSONEncode(report)
local env=(getgenv and getgenv()) or _G
env.ACOInventoryInfo=output
local copied=type(setclipboard)=='function' and pcall(setclipboard,output)
local saved=type(writefile)=='function' and pcall(writefile,'ACO-inventory-info.json',output)
if not copied and not saved then print(output) end
warn(('ACO Inventory: %d card/border entries, %d copies. '):format(#inventory,totalCopies)
    ..(copied and 'Da copy clipboard. ' or 'Khong co clipboard. ')
    ..(saved and 'Da luu ACO-inventory-info.json. ' or '')
    ..(#errors>0 and ('Loi doc '..#errors..' muc; xem errors trong JSON.') or ''))
