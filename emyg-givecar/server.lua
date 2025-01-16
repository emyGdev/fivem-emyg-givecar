local QBCore = exports['qb-core']:GetCoreObject()

-- Webhook URL'nizi buraya girin
local webhook = "https://discord.com/api/webhooks/1325780304408870942/iVDpodMmee3D1qhF7zxNeoNlDFhGn5glSaCdKkQSwiRFtB9-SVKNjNH2o74eIaB3MZQN"


local function GenerateRandomPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''

    for i = 1, 8 do 
        local randomIndex = math.random(1, #chars)
        plate = plate .. chars:sub(randomIndex, randomIndex)
    end

    return plate
end

local function GetFormattedDate()
    return os.date("**%d/%m/%Y** %H:%M:%S")
end

local function LogToDiscord(title, description, color)
    local embed = {{
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        ["image"] = {["url"] = "https://i.imgur.com/zGreRxv.jpeg"}, 
        ["footer"] = {["text"] = "EMY/Shop Log"}
    }}

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
end

local function GetDiscordTag(playerId)
    for _, id in pairs(GetPlayerIdentifiers(playerId)) do
        if string.find(id, "discord:") then
            return "<@" .. string.sub(id, 9) .. ">"
        end
    end
    return GetPlayerName(playerId) .. " (Discord bulunamadı)"
end


QBCore.Commands.Add('givecar', "🚗 Bir oyuncuya araç ver", {
    {name="id", help="🔢 Oyuncu ID'si"}, 
    {name="model", help="🚘 Araç Modeli"},
    {name="plate", help="🔤 Özel Plaka (Opsiyonel)"}
}, false, function(source, args)
    local src = source -- 
    local targetId = tonumber(args[1]) 
    local vehicleModel = args[2] 
    local customPlate = args[3] or GenerateRandomPlate() -- 

    if not targetId or not vehicleModel then
        TriggerClientEvent('QBCore:Notify', src, "❌ Eksik argüman! Kullanım: /givecar [id] [model] [plaka (isteğe bağlı)]", "error")
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, "❌ Geçersiz oyuncu ID'si!", "error")
        return
    end

   
    local adminDiscord = GetDiscordTag(src)
    local targetDiscord = GetDiscordTag(targetId)

    
    exports.oxmysql:execute('SELECT plate FROM player_vehicles WHERE plate = ?', { customPlate }, function(result)
        if result and #result > 0 then
            TriggerClientEvent('QBCore:Notify', src, "❌ Bu plaka zaten kullanılıyor! Plaka: " .. customPlate, "error")
            return
        end

    
        exports.oxmysql:insert('INSERT INTO player_vehicles (license, citizenid, vehicle, plate, state, garage) VALUES (?, ?, ?, ?, ?, ?)', {
            targetPlayer.PlayerData.license,
            targetPlayer.PlayerData.citizenid,
            vehicleModel,
            customPlate,
            1,
            "pillboxgarage"
        }, function(insertId)
            if insertId then
              
                TriggerClientEvent('QBCore:Notify', src, "✅ 🚗 Araç başarıyla verildi! Model: " .. vehicleModel .. ", Plaka: " .. customPlate, "success")
               
                TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "✅ 🚘 Bir yönetici tarafından araç verildi! Model: " .. vehicleModel .. ", Plaka: " .. customPlate, "success")

                
                LogToDiscord(
                    "🚗 Araç Verme Logu",
                    string.format(
                        "🛠 **Araç veren:** %s\n👤 **Araç alan:** %s\n🚘 **Araç Adı:** %s\n🔤 **Plaka:** %s\n📅 **Tarih:** %s", 
                        adminDiscord, 
                        targetDiscord, 
                        vehicleModel, 
                        customPlate,
                        GetFormattedDate()
                    ),
                    3066993 
                )
            else
                
                TriggerClientEvent('QBCore:Notify', src, "❌ Araç veritabanına eklenemedi!", "error")
            end
        end)
    end)
end, 'admin')


QBCore.Commands.Add('delcar', "🚗 Bir oyuncunun aracını sil", {
    {name="id", help="🔢 Oyuncu ID'si"}, 
    {name="plate", help="🔤 Araç Plakası"}
}, false, function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local plate = args[2]

    if not targetId or not plate then
        TriggerClientEvent('QBCore:Notify', src, "❌ Eksik argüman! Kullanım: /delcar [id] [plaka]", "error")
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, "❌ Geçersiz oyuncu ID'si!", "error")
        return
    end

    
    local adminDiscord = GetDiscordTag(src)
    local targetDiscord = GetDiscordTag(targetId)

    
    exports.oxmysql:execute('SELECT vehicle FROM player_vehicles WHERE citizenid = ? AND plate = ?', {
        targetPlayer.PlayerData.citizenid,
        plate
    }, function(result)
        if result and result[1] then
            local vehicleModel = result[1].vehicle

            exports.oxmysql:execute('DELETE FROM player_vehicles WHERE citizenid = ? AND plate = ?', {
                targetPlayer.PlayerData.citizenid,
                plate
            }, function(deleteResult)
                if deleteResult.affectedRows and deleteResult.affectedRows > 0 then
                   
                    TriggerClientEvent('QBCore:Notify', src, "✅ 🚗 Oyuncunun aracı silindi! Model: " .. vehicleModel .. ", Plaka: " .. plate, "success")
                    
                    TriggerClientEvent('QBCore:Notify', targetId, "❌ 🚘 Bir aracınız silindi! Model: " .. vehicleModel .. ", Plaka: " .. plate, "error")

                   
                    LogToDiscord(
                        "❌ Araç Silme Logu",
                        string.format(
                            "🛠 **Araç silen:** %s\n👤 **Araç sahibi:** %s\n🚘 **Araç Adı:** %s\n🔤 **Plaka:** %s\n📅 **Tarih:** %s",
                            adminDiscord,
                            targetDiscord,
                            vehicleModel,
                            plate,
                            GetFormattedDate()
                        ),
                        15158332 -- Kırmızı renk
                    )
                else
                    TriggerClientEvent('QBCore:Notify', src, "❌ Araç silinemedi! Plaka: " .. plate, "error")
                end
            end)
        else
            TriggerClientEvent('QBCore:Notify', src, "❌ Araç bulunamadı! Plaka: " .. plate, "error")
        end
    end)
end, 'admin')
