local ESX, QBCore
local useOx = false

local function debugPrint(...)
    if Config.Debug then print('^3[takeperso]^0', ...) end
end

-- Framework erst bei Bedarf suchen, damit die Reihenfolge in der server.cfg egal ist
local function loadFramework()
    if ESX or QBCore then return true end

    useOx = GetResourceState('ox_inventory') == 'started'

    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    end

    if ESX or QBCore then
        print(('^2[takeperso] Framework erkannt: %s%s^0'):format(ESX and 'ESX' or 'QBCore', useOx and ' + ox_inventory' or ''))
        return true
    end
    return false
end

CreateThread(function()
    for _ = 1, 30 do
        if loadFramework() then return end
        Wait(1000)
    end
    print('^1[takeperso] Weder es_extended noch qb-core gefunden! Ist der Ordnername richtig und wird es gestartet?^0')
end)

local documentsById = {}
for _, doc in ipairs(Config.Documents) do
    documentsById[doc.id] = doc
end

---------------------------------------------------------------------
-- Framework-Bridge
---------------------------------------------------------------------

local function getCharacter(src)
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return nil end

        local char = {
            identifier = xPlayer.identifier,
            firstname = xPlayer.get('firstName'),
            lastname = xPlayer.get('lastName'),
            dob = xPlayer.get('dateofbirth'),
            sex = xPlayer.get('sex'),
            height = xPlayer.get('height')
        }

        if not char.firstname and MySQL then
            local row = MySQL.single.await(
                'SELECT firstname, lastname, dateofbirth, sex, height FROM users WHERE identifier = ?',
                { xPlayer.identifier }
            )
            if row then
                char.firstname, char.lastname = row.firstname, row.lastname
                char.dob, char.sex, char.height = row.dateofbirth, row.sex, row.height
            end
        end

        char.sex = (char.sex == 'f' or char.sex == 'F') and 'W' or 'M'
        return char
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return nil end

        local info = Player.PlayerData.charinfo or {}
        return {
            identifier = Player.PlayerData.citizenid,
            firstname = info.firstname,
            lastname = info.lastname,
            dob = info.birthdate,
            sex = tonumber(info.gender) == 1 and 'W' or 'M',
            height = nil,
            nationality = info.nationality
        }
    end
end

local function getItemCountUnsafe(src, item)
    if useOx then
        return exports.ox_inventory:Search(src, 'count', item) or 0
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        local invItem = xPlayer and xPlayer.getInventoryItem(item)
        return invItem and invItem.count or 0
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return 0 end
        if Player.Functions.GetItemByName then
            local invItem = Player.Functions.GetItemByName(item)
            return invItem and invItem.amount or 0
        end
        -- Neueres qb-inventory
        return exports['qb-inventory']:GetItemCount(src, item) or 0
    end
    return 0
end

local function getItemCount(src, item)
    local ok, count = pcall(getItemCountUnsafe, src, item)
    if not ok then
        print(('^1[takeperso] Fehler beim Prüfen von Item "%s": %s^0'):format(item, count))
        return 0
    end
    return tonumber(count) or 0
end

local function canCarry(target, item)
    if useOx then
        return exports.ox_inventory:CanCarryItem(target, item, 1)
    elseif ESX then
        local xTarget = ESX.GetPlayerFromId(target)
        if not xTarget then return false end
        return not xTarget.canCarryItem or xTarget.canCarryItem(item, 1)
    elseif QBCore then
        return QBCore.Functions.GetPlayer(target) ~= nil
    end
    return false
end

local function transferItem(src, target, item)
    if useOx then
        if not exports.ox_inventory:RemoveItem(src, item, 1) then return false end
        exports.ox_inventory:AddItem(target, item, 1)
        return true
    elseif ESX then
        local xPlayer, xTarget = ESX.GetPlayerFromId(src), ESX.GetPlayerFromId(target)
        if not xPlayer or not xTarget then return false end
        xPlayer.removeInventoryItem(item, 1)
        xTarget.addInventoryItem(item, 1)
        return true
    elseif QBCore then
        local Player, Target = QBCore.Functions.GetPlayer(src), QBCore.Functions.GetPlayer(target)
        if not Player or not Target then return false end
        if not Player.Functions.RemoveItem(item, 1) then return false end
        Target.Functions.AddItem(item, 1)
        return true
    end
    return false
end

---------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------

local function notify(src, msg)
    TriggerClientEvent('takeperso:client:notify', src, msg)
end

local function hashOf(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % 2147483647
    end
    return hash
end

-- Dokumentnummer im Stil echter Ausweise (z.B. L01X00T47), immer gleich pro Charakter
local numberChars = 'CFGHJKLMNPRTVWXYZ0123456789'
local function documentNumber(prefix, hash)
    local out = prefix or ''
    for _ = 1, 9 - #out do
        local idx = hash % #numberChars + 1
        out = out .. numberChars:sub(idx, idx)
        hash = hash // #numberChars + 7919
    end
    return out
end

-- Geburtsdatum einheitlich als TT.MM.JJJJ
local function formatDate(date)
    if not date then return '-' end
    date = tostring(date)
    local y, m, d = date:match('^(%d%d%d%d)[-/.](%d%d?)[-/.](%d%d?)')
    if y then return ('%02d.%02d.%s'):format(tonumber(d), tonumber(m), y) end
    d, m, y = date:match('^(%d%d?)[-/.](%d%d?)[-/.](%d%d%d%d)')
    if d then return ('%02d.%02d.%s'):format(tonumber(d), tonumber(m), y) end
    return date
end

local function buildDocument(src, doc, char)
    char = char or getCharacter(src)
    if not char then return nil end
    if doc.item and getItemCount(src, doc.item) < 1 then return nil end

    local hash = hashOf(tostring(char.identifier) .. doc.id)
    local day, month = hash % 28 + 1, (hash // 28) % 12 + 1
    local year = 2019 + (hash // 336) % 6

    return {
        id = doc.id,
        label = doc.label,
        template = doc.template,
        classes = doc.classes,
        number = documentNumber(doc.prefix, hash),
        accessNumber = ('%06d'):format(hash % 1000000),
        issued = ('%02d.%02d.%d'):format(day, month, year),
        expires = ('%02d.%02d.%d'):format(day, month, year + (doc.validYears or 10)),
        country = Config.Country,
        countryCode = Config.CountryCode,
        authority = Config.Authority,
        canGive = Config.AllowGive and doc.item ~= nil,
        holder = {
            firstname = char.firstname or 'Unbekannt',
            lastname = char.lastname or 'Unbekannt',
            dob = formatDate(char.dob),
            sex = char.sex or '-',
            height = char.height and (tostring(char.height) .. ' cm') or nil,
            birthplace = char.birthplace or Config.DefaultBirthplace,
            nationality = char.nationality or Config.DefaultNationality
        }
    }
end

local function isNear(src, target)
    if not target or target == src or not GetPlayerName(target) then return false end
    local srcCoords = GetEntityCoords(GetPlayerPed(src))
    local targetCoords = GetEntityCoords(GetPlayerPed(target))
    return #(srcCoords - targetCoords) <= Config.MaxDistance + 1.0
end

local cooldowns = {}
local function onCooldown(src)
    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < 1000 then return true end
    cooldowns[src] = now
    return false
end

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------

RegisterNetEvent('takeperso:server:requestMenu', function()
    local src = source
    debugPrint(('Spieler %s öffnet das Menü'):format(src))

    if not loadFramework() then
        print('^1[takeperso] Menü kann nicht geöffnet werden: kein Framework (ESX/QBCore) gefunden.^0')
        return notify(src, 'Persomenü: Framework nicht gefunden (siehe Server-Konsole).')
    end

    local ok, char = pcall(getCharacter, src)
    if not ok then
        print(('^1[takeperso] Fehler beim Laden des Charakters: %s^0'):format(char))
        return notify(src, 'Persomenü: Fehler beim Laden des Charakters (siehe Server-Konsole).')
    end
    if not char then
        debugPrint(('Kein Charakter für Spieler %s gefunden'):format(src))
        return notify(src, 'Dein Charakter ist noch nicht geladen.')
    end

    local docs = {}
    for _, doc in ipairs(Config.Documents) do
        local data = buildDocument(src, doc, char)
        if data then docs[#docs + 1] = data end
    end

    debugPrint(('Sende %d Dokument(e) an Spieler %s'):format(#docs, src))
    TriggerClientEvent('takeperso:client:openMenu', src, docs)
end)

RegisterNetEvent('takeperso:server:show', function(docId, target)
    local src = source
    target = tonumber(target)
    if onCooldown(src) then return end

    local doc = documentsById[docId]
    if not doc then return end

    if not isNear(src, target) then
        return notify(src, 'Kein Spieler in der Nähe.')
    end

    local data = buildDocument(src, doc)
    if not data then
        return notify(src, ('Du besitzt keinen %s.'):format(doc.label))
    end

    TriggerClientEvent('takeperso:client:viewDocument', target, data, src)
    TriggerClientEvent('takeperso:client:shownOwn', src, data)
    TriggerClientEvent('takeperso:client:playAnim', src)
    notify(src, ('Du hast deinen %s gezeigt.'):format(doc.label))
end)

RegisterNetEvent('takeperso:server:give', function(docId, target)
    local src = source
    target = tonumber(target)
    if onCooldown(src) then return end

    local doc = documentsById[docId]
    if not doc or not doc.item or not Config.AllowGive then return end

    if not isNear(src, target) then
        return notify(src, 'Kein Spieler in der Nähe.')
    end

    if getItemCount(src, doc.item) < 1 then
        return notify(src, ('Du besitzt keinen %s.'):format(doc.label))
    end

    if not canCarry(target, doc.item) then
        return notify(src, 'Die Person kann das nicht mehr tragen.')
    end

    if transferItem(src, target, doc.item) then
        TriggerClientEvent('takeperso:client:playAnim', src)
        notify(src, ('Du hast deinen %s übergeben.'):format(doc.label))
        notify(target, ('Du hast einen %s erhalten.'):format(doc.label))
        TriggerClientEvent('takeperso:client:closeMenu', src)
    end
end)
