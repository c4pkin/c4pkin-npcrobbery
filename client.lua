local QBCore = exports['qb-core']:GetCoreObject()

local Config = {
    targetName = "c4pkin-npcrobbery",
    targetLabel = "Ara",
    targetIcon = "fas fa-search",
    targetDistance = 2.0, 
    
    lootItems = { -- Ölü npclerden çıkacak itemler
        {item = "water_bottle", chance = 30},
        {item = "cash", chance = 70, minAmount = 10, maxAmount = 50} 
    },
    
    animalPeds = { -- Hayvan pedleri
        ["a_c_deer"] = true,
        ["a_c_rabbit_01"] = true,
        ["a_c_boar"] = true
    },
    
    animalLootItems = { -- Hayvanlardan çıkacak itemler
        {item = "water_bottle", chance = 35, minAmount = 1, maxAmount = 5},  -- ! Test itemleri güncellenmesi gerek.
        {item = "tosti", chance = 35, minAmount = 1, maxAmount = 5}, 
        {item = "both", chance = 30, minAmount = 1, maxAmount = 3} 
    },
    
    police = {
        enabled = true, -- Polis bildirimi aktif/pasif
        notifyChance = 80, -- Polis bildirim şansı (%)
        requiredCops = 1, -- Bildirim için gereken minimum polis sayısı
        dispatchCooldown = 120000, -- Aynı bölgeden tekrar bildirim için gereken süre (ms)
        blipDuration = 45000, -- Polis blip'inin haritada kalma süresi (ms)
        blipScale = 1.0, 
        blipColor = 1, 
        blipSprite = 303 
    }
}

local deadPeds = {}
local lootedPeds = {}
local lastDispatchCoords = nil
local lastDispatchTime = 0
local activeBlips = {}

Citizen.CreateThread(function()
    while true do
        Wait(500)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        local peds = GetGamePool("CPed")
        for _, ped in ipairs(peds) do
            if not IsPedAPlayer(ped) and IsEntityDead(ped) and not IsPedInAnyVehicle(ped, true) and not lootedPeds[ped] then
                local pedCoords = GetEntityCoords(ped)
                local distance = #(playerCoords - pedCoords)
                
                if distance <= 30.0 and not deadPeds[ped] then
                    deadPeds[ped] = true

                    AddTargetToDeadPed(ped)

                end
            end
        end
    end
end)

function AddTargetToDeadPed(ped)

    local targetId = Config.targetName .. "-" .. ped
    
    local pedModel = GetEntityModel(ped)
    local pedModelName = GetEntityArchetypeName(ped)
    
    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                icon = Config.targetIcon,
                label = Config.targetLabel,
                action = function()
                    -- Hayvan mı insan mı 
                    if Config.animalPeds[pedModelName] then
                        if HasKnife() then
                            LootAnimalPed(ped)
                        else
                            QBCore.Functions.Notify("Hayvanı aramak için elinizde bıçak olmalı", "error")
                        end
                    else
                        LootDeadPed(ped)
                    end
                end,
                canInteract = function()
                    return not lootedPeds[ped]
                end
            }
        },
        distance = Config.targetDistance
    })
end

function HasKnife()
    local ped = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(ped)
    
    if weaponHash == GetHashKey("weapon_knife") then
        return true
    else
        return false
    end
end

function LootDeadPed(ped)

    TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_BUM_BIN", 0, true)
    QBCore.Functions.Progressbar("search_npc", "Kişi Aranıyor...", 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {}, {}, {}, function() 
        ClearPedTasks(PlayerPedId())
        lootedPeds[ped] = true
        
        local playerCoords = GetEntityCoords(PlayerPedId())
        if Config.police.enabled then
            local notifyPolice = math.random(1, 100) <= Config.police.notifyChance
            
            if notifyPolice then
                -- Polis sayısını kontrol et
                QBCore.Functions.TriggerCallback("c4pkin-npcrobbery:server:GetCopCount", function(cops)
                    if cops >= Config.police.requiredCops then

                        local currentTime = GetGameTimer()
                        if not lastDispatchCoords or #(playerCoords - lastDispatchCoords) > 50.0 or (currentTime - lastDispatchTime) > Config.police.dispatchCooldown then
                            lastDispatchCoords = playerCoords
                            lastDispatchTime = currentTime
                            
                            -- Polise bildirim gönder
                            TriggerServerEvent("c4pkin-npcrobbery:server:PoliceAlert", {
                                coords = playerCoords,
                                message = "Şüpheli bir kişi ölü bir kişiyi arıyor"
                            })
                        end
                    end
                end)
            end
        end
        
        local lootGiven = false
        
        for _, lootData in ipairs(Config.lootItems) do
            local roll = math.random(1, 100)
            if roll <= lootData.chance then
                if lootData.item == "cash" then

                    local amount = math.random(lootData.minAmount, lootData.maxAmount)
                    TriggerServerEvent("c4pkin-npcrobbery:server:GiveMoney", amount)
                    QBCore.Functions.Notify("$" .. amount .. " buldunuz", "success")
                    lootGiven = true
                else

                    TriggerServerEvent("c4pkin-npcrobbery:server:GiveItem", lootData.item)
                    QBCore.Functions.Notify(QBCore.Shared.Items[lootData.item].label .. " buldunuz", "success")
                    lootGiven = true
                end
                break 
            end
        end
        
        if not lootGiven then
            QBCore.Functions.Notify("Hiçbir şey bulamadınız.", "error")
        end
        
        exports['qb-target']:RemoveTargetEntity(ped)
    end, function() 
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify("İşlem iptal edildi.", "error")
    end)
end

RegisterNetEvent("c4pkin-npcrobbery:client:PoliceAlert")
AddEventHandler("c4pkin-npcrobbery:client:PoliceAlert", function(data)

    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.job.name == "police" then

        QBCore.Functions.Notify(data.message, "police", 10000)
        
        PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)
        
        local alpha = 250
        local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        
        SetBlipSprite(blip, Config.police.blipSprite)
        SetBlipHighDetail(blip, true)
        SetBlipScale(blip, Config.police.blipScale)
        SetBlipColour(blip, Config.police.blipColor)
        SetBlipAlpha(blip, alpha)
        SetBlipAsShortRange(blip, false)
        
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Şüpheli Faaliyet")
        EndTextCommandSetBlipName(blip)
        
        table.insert(activeBlips, {
            blip = blip,
            expireTime = GetGameTimer() + Config.police.blipDuration,
            alpha = alpha,
            coords = data.coords
        })
    end
end)

function LootAnimalPed(ped)

    TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_BUM_BIN", 0, true)
    QBCore.Functions.Progressbar("search_animal", "Hayvan Parçalanıyor...", 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {}, {}, {}, function() 
        ClearPedTasks(PlayerPedId())
        lootedPeds[ped] = true
        
        local lootGiven = false
        
        for _, lootData in ipairs(Config.animalLootItems) do
            local roll = math.random(1, 100)
            if roll <= lootData.chance then

                local amount = math.random(lootData.minAmount, lootData.maxAmount)
                
                if lootData.item == "both" then
                   
                    TriggerServerEvent("c4pkin-npcrobbery:server:GiveItem", "water_bottle", amount)
                    TriggerServerEvent("c4pkin-npcrobbery:server:GiveItem", "tosti", amount)
                    QBCore.Functions.Notify(amount .. "x Su şişesi ve " .. amount .. "x Tosti buldunuz", "success")
                else
                    
                    TriggerServerEvent("c4pkin-npcrobbery:server:GiveItem", lootData.item, amount)
                    QBCore.Functions.Notify(amount .. "x " .. QBCore.Shared.Items[lootData.item].label .. " buldunuz", "success")
                end
                
                lootGiven = true
                break 
            end
        end
        
        if not lootGiven then
            QBCore.Functions.Notify("Hiçbir şey bulamadınız.", "error")
        end
        
        exports['qb-target']:RemoveTargetEntity(ped)
    end, function() 
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify("İşlem iptal edildi.", "error")
    end)
end

Citizen.CreateThread(function()
    while true do
        local activeBlipCount = #activeBlips
        
        if activeBlipCount > 0 then
            local curTime = GetGameTimer()
            
            for i = activeBlipCount, 1, -1 do
                local blipData = activeBlips[i]
                
                if curTime > blipData.expireTime then

                    blipData.alpha = blipData.alpha - 1
                    SetBlipAlpha(blipData.blip, blipData.alpha)
                    
                    if blipData.alpha <= 0 then
                        RemoveBlip(blipData.blip)
                        table.remove(activeBlips, i)
                    end
                end
            end
            
            Wait(150)
        else
            Wait(1000)
        end
    end
end)