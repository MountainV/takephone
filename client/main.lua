local menuOpen = false
local menuDocs = {}
local headshots = {}
local cardUntil = 0
local cardThreadRunning = false

local function debugPrint(...)
    if Config.Debug then print('[takeperso]', ...) end
end

local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

-- Erstellt ein Foto (Mugshot) eines Peds für die Karte
local function getHeadshot(ped)
    if not ped or not DoesEntityExist(ped) then return nil end

    -- Freigestelltes Foto (ohne Hintergrund), sonst normales Foto
    local handle = RegisterPedheadshotTransparent(ped)
    if not handle or handle == 0 then
        handle = RegisterPedheadshot(ped)
    end

    local timeout = GetGameTimer() + 3000
    while not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) do
        if GetGameTimer() > timeout then
            UnregisterPedheadshot(handle)
            return nil
        end
        Wait(0)
    end

    headshots[#headshots + 1] = handle
    return GetPedheadshotTxdString(handle)
end

-- Fotos erst freigeben, wenn weder Menü noch Karte offen sind
local function cleanupHeadshots(force)
    if not force and (menuOpen or GetGameTimer() < cardUntil) then return end
    for _, handle in ipairs(headshots) do
        UnregisterPedheadshot(handle)
    end
    headshots = {}
end

local function getClosestPlayer()
    local myCoords = GetEntityCoords(PlayerPedId())
    local closest, closestDist = nil, Config.MaxDistance

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local dist = #(GetEntityCoords(GetPlayerPed(player)) - myCoords)
            if dist <= closestDist then
                closest, closestDist = GetPlayerServerId(player), dist
            end
        end
    end

    return closest
end

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeMenu' })
    cleanupHeadshots()
end

local function hideCard()
    cardUntil = 0
    SendNUIMessage({ action = 'hideCard' })
end

-- Zeigt eine Karte ohne Mausfokus an, man kann also normal weiterlaufen.
-- Entf oder Backspace schließt sie.
local function displayCard(doc, ped)
    -- Altes Foto erst freigeben, damit nicht das falsche Bild angezeigt wird
    if not menuOpen then cleanupHeadshots(true) end

    local duration = (Config.ShowDuration or 0) * 1000
    local headshot = getHeadshot(ped)

    cardUntil = duration > 0 and (GetGameTimer() + duration) or math.huge
    SendNUIMessage({ action = 'showCard', doc = doc, headshot = headshot, duration = duration })

    if cardThreadRunning then return end
    cardThreadRunning = true

    CreateThread(function()
        while GetGameTimer() < cardUntil do
            if not menuOpen and (IsControlJustPressed(0, 214) or IsControlJustPressed(0, 194)) then -- Entf / Backspace
                hideCard()
            end
            Wait(0)
        end
        cardThreadRunning = false
        cleanupHeadshots()
    end)
end

---------------------------------------------------------------------
-- Taste / Befehl
---------------------------------------------------------------------

local waitingForServer = false

RegisterCommand('persomenu', function()
    debugPrint('Taste gedrückt, menuOpen =', menuOpen)
    if menuOpen then return closeMenu() end
    if IsPauseMenuActive() then return end

    waitingForServer = true
    TriggerServerEvent('takeperso:server:requestMenu')

    SetTimeout(3000, function()
        if waitingForServer then
            waitingForServer = false
            print('[takeperso] Keine Antwort vom Server. Läuft die Resource auf dem Server? Fehler in der Server-Konsole?')
        end
    end)
end, false)

RegisterKeyMapping('persomenu', 'Persönliches Menü öffnen', 'keyboard', Config.OpenKey)

-- Falls die Maus / das Menü hängen bleibt: /persoreset
RegisterCommand('persoreset', function()
    closeMenu()
    hideCard()
    cleanupHeadshots(true)
    print('[takeperso] Menü zurückgesetzt.')
end, false)

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------

RegisterNetEvent('takeperso:client:openMenu', function(docs)
    waitingForServer = false
    debugPrint(('Menü erhalten mit %d Dokument(en)'):format(#docs))

    menuDocs = docs
    menuOpen = true
    SendNUIMessage({ action = 'openMenu', docs = docs, banner = Config.Banner })

    if not Config.WalkWhileMenu then
        SetNuiFocus(true, true)
        return
    end

    -- Menü per Tastatur bedienen und dabei weiterlaufen (WASD + Maus zum Umschauen)
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(true)

    CreateThread(function()
        local blocked = {
            24, 25, 37, 44, 45, 140, 141, 142, 257, 263, 264, -- Angriff, Zielen, Waffenrad, Deckung, Nachladen
            18, 172, 173, 174, 175, 176, 177, 191, 194, 201, 202, -- Pfeiltasten, Enter, Backspace
            199, 200, 322, 245 -- Pausemenü, ESC, Chat
        }
        while menuOpen do
            for _, control in ipairs(blocked) do
                DisableControlAction(0, control, true)
            end
            Wait(0)
        end
        SetNuiFocusKeepInput(false)
    end)
end)

RegisterNetEvent('takeperso:client:closeMenu', closeMenu)

-- Jemand zeigt mir sein Dokument
RegisterNetEvent('takeperso:client:viewDocument', function(doc, fromServerId)
    local fromPlayer = GetPlayerFromServerId(fromServerId)
    displayCard(doc, fromPlayer ~= -1 and GetPlayerPed(fromPlayer) or nil)
end)

-- Ich habe mein Dokument erfolgreich gezeigt -> selbst auch sehen
RegisterNetEvent('takeperso:client:shownOwn', function(doc)
    displayCard(doc, PlayerPedId())
end)

RegisterNetEvent('takeperso:client:notify', function(msg)
    waitingForServer = false
    notify(msg)
end)

RegisterNetEvent('takeperso:client:playAnim', function()
    if not Config.UseAnimation then return end
    local dict = 'mp_common'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 1000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(PlayerPedId(), dict, 'givetake1_a', 8.0, -8.0, 2000, 48, 0, false, false, false)
        RemoveAnimDict(dict)
    end
end)

---------------------------------------------------------------------
-- NUI Callbacks
---------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('view', function(data, cb)
    cb('ok')
    for _, doc in ipairs(menuDocs) do
        if doc.id == data.id then
            closeMenu()
            displayCard(doc, PlayerPedId())
            return
        end
    end
end)

RegisterNUICallback('show', function(data, cb)
    cb('ok')
    local target = getClosestPlayer()
    if not target then
        return notify('Kein Spieler in der Nähe.')
    end
    closeMenu()
    TriggerServerEvent('takeperso:server:show', data.id, target)
end)

RegisterNUICallback('give', function(data, cb)
    cb('ok')
    local target = getClosestPlayer()
    if not target then
        return notify('Kein Spieler in der Nähe.')
    end
    TriggerServerEvent('takeperso:server:give', data.id, target)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if menuOpen then SetNuiFocus(false, false) end
    cleanupHeadshots(true)
end)
