local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('c4pkin-npcrobbery:server:GiveMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        Player.Functions.AddMoney('cash', amount)
    end
end)

RegisterNetEvent('c4pkin-npcrobbery:server:GiveItem', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local itemAmount = amount or 1 
    
    if Player then
        Player.Functions.AddItem(item, itemAmount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', itemAmount)
    end
end)

QBCore.Functions.CreateCallback('c4pkin-npcrobbery:server:GetCopCount', function(source, cb)
    local cops = 0
    
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
            cops = cops + 1
        end
    end
    
    cb(cops)
end)

RegisterNetEvent('c4pkin-npcrobbery:server:PoliceAlert', function(data)

    TriggerClientEvent('c4pkin-npcrobbery:client:PoliceAlert', -1, data)
    
end)