local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TargetPetName = getgenv().TargetPetName

local Root

for _, tbl in ipairs(getgc(true)) do
    if type(tbl) == "table" and rawget(tbl, "PetStorage") then
        Root = tbl
        break
    end
end

assert(Root, "Root not found")

local PetList = Root.PetStorage.playerPetData.petList
assert(PetList, "PetList not found")

local function FindUID()
    for uid, pet in pairs(PetList) do
        local name = pet.name or pet.petName
        local locked = pet.locked or pet.isLocked

        if name == TargetPetName and locked == false then
            return uid
        end
    end
end

local function RemoveBatch(uid)
    local list = {}

    for i = 1, 100 do
        list[i] = uid
    end

    pcall(function()
        ReplicatedStorage.Remote.Pet.ReqRemovePets:InvokeServer(list)
    end)
end

task.spawn(function()
    while task.wait(3) do
        if getgenv().TargetPetName then
            local uid = FindUID()

            if uid then
                RemoveBatch(uid)
            end
        end
    end
end)
