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
        local name = pet.name or pet.petName or pet.configName
        local locked = pet.locked or pet.isLocked or false

        if name == TargetPetName and locked == false then
            return uid
        end
    end
end

local function RemoveBatch(uid)
    local list = {}

    for i = 1, 150 do
        list[i] = uid
    end

    local ok, result = pcall(function()
        return ReplicatedStorage.Remote.Pet.ReqRemovePets:InvokeServer(list)
    end)

    print("RemovePet x150:", ok, result)
end

local uid = FindUID()

if uid then
    RemoveBatch(uid)
else
    print("No pet found:", TargetPetName)
end
