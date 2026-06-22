local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local enabled = true
local uid

for _,tbl in pairs(getgc(true)) do
    if type(tbl) == "table"
    and rawget(tbl,"petUid")
    and rawget(tbl,"isSelected") == true then

        uid = tbl.petUid
        break
    end
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.G then
        enabled = not enabled
        print("Auto Battle:", enabled and "ON" or "OFF")
    end
end)

task.spawn(function()
    while true do
        if enabled and uid then
            ReplicatedStorage.Remote.Battle.ReqEnterNpcBattle:FireServer(
                10009,
                900006,
                uid
            )
        end

        task.wait(3)
    end
end)
