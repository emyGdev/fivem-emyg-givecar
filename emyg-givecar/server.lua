QBCore = exports['qb-core']:GetCoreObject()

-- Rastgele Plaka Oluşturucu
local function GenerateRandomPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''

    for i = 1, 8 do -- Plaka uzunluğu 8 karakter olacak
        local randomIndex = math.random(1, #chars)
        plate = plate .. chars:sub(randomIndex, randomIndex)
    end

    return plate
end

-- /givecar Komutu
QBCore.Commands.Add('givecar', "Bir oyuncuya araç ver", {
    {name="id", help="Oyuncu ID'si"}, 
    {name="model", help="Araç Modeli"},
    {name="plate", help="Özel Plaka (Opsiyonel)"}
}, false, function(source, args)
    local src = source -- Komutu kullanan adminin kaynağı
    local targetId = tonumber(args[1]) -- Oyuncunun ID'si
    local vehicleModel = args[2] -- Araç modeli
    local customPlate = args[3] or GenerateRandomPlate() -- Özel plaka ya da rastgele plaka

    if not targetId or not vehicleModel then
        TriggerClientEvent('QBCore:Notify', src, "❌ Eksik argüman! Kullanım: /givecar [id] [model] [plaka (isteğe bağlı)]", "error")
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, "❌ Geçersiz oyuncu ID'si!", "error")
        return
    end

    -- Plaka Çakışması Kontrolü
    exports.oxmysql:execute('SELECT plate FROM player_vehicles WHERE plate = ?', { customPlate }, function(result)
        if result and #result > 0 then
            TriggerClientEvent('QBCore:Notify', src, "❌ Bu plaka zaten kullanılıyor! Plaka: " .. customPlate, "error")
            return
        end

        -- Veritabanına Araç Ekle (oxmysql)
        exports.oxmysql:insert('INSERT INTO player_vehicles (license, citizenid, vehicle, plate, state, garage) VALUES (?, ?, ?, ?, ?, ?)', {
            targetPlayer.PlayerData.license,
            targetPlayer.PlayerData.citizenid,
            vehicleModel,
            customPlate,
            1,
            "pillboxgarage"
        }, function(insertId)
            if insertId then
                -- Admin'e Bildirim
                TriggerClientEvent('QBCore:Notify', src, "✅ Başarılı! Araç verildi. Model: " .. vehicleModel .. ", Plaka: " .. customPlate, "success")
                -- Oyuncuya Bildirim
                TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "✅ Bir yönetici tarafından araç verildi! Model: " .. vehicleModel .. ", Plaka: " .. customPlate, "success")
            else
                -- Admin'e Hata Bildirimi
                TriggerClientEvent('QBCore:Notify', src, "❌ Araç veritabanına eklenemedi!", "error")
            end
        end)
    end)
end, 'admin')

-- /delcar Komutu
QBCore.Commands.Add('delcar', "Bir oyuncunun aracını sil", {
    {name="id", help="Oyuncu ID'si"}, 
    {name="plate", help="Araç Plakası"}
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

    -- Araç Modelini Veritabanından Al ve Sil
    exports.oxmysql:execute('SELECT vehicle FROM player_vehicles WHERE citizenid = ? AND plate = ?', {
        targetPlayer.PlayerData.citizenid,
        plate
    }, function(result)
        if result and result[1] then
            local vehicleModel = result[1].vehicle

            -- Aracı Sil
            exports.oxmysql:execute('DELETE FROM player_vehicles WHERE citizenid = ? AND plate = ?', {
                targetPlayer.PlayerData.citizenid,
                plate
            }, function(deleteResult)
                if deleteResult.affectedRows and deleteResult.affectedRows > 0 then
                    -- Admin'e Bildirim
                    TriggerClientEvent('QBCore:Notify', src, "✅ Oyuncunun aracı silindi! Model: " .. vehicleModel .. ", Plaka: " .. plate, "success")
                    -- Oyuncuya Bildirim
                    TriggerClientEvent('QBCore:Notify', targetId, "❌ Bir aracınız silindi! Model: " .. vehicleModel .. ", Plaka: " .. plate, "error")
                else
                    -- Admin'e Hata Bildirimi
                    TriggerClientEvent('QBCore:Notify', src, "❌ Araç silinemedi! Plaka: " .. plate, "error")
                end
            end)
        else
            -- Admin'e Hata Bildirimi
            TriggerClientEvent('QBCore:Notify', src, "❌ Plakaya ait araç bulunamadı! Plaka: " .. plate, "error")
        end
    end)
end, 'admin')
