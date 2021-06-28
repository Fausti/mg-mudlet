-- TODO:
-- - RaceLock in AreaUserData
-- - MapUserData sichern
-- - Funktionen aufsplitten (e.g. clearMap(), importFromTable(), ...)

-- Liste aller Rassen im MG um Typos zu erkennen. Schreibweise wie in MG.char.base.race
-- aber in Kleinbuchstaben!

local raceList = {
    "mensch",
    "zwerg",
    "elf",
    "feline",
    "hobbit",
    "dunkelelf",
    "goblin",
    "ork"
}

function importStartMap()
    local fileName = getMudletHomeDir() .. "/exported_map.map"
    -- loadJsonMap(fileName)

    local data = {}
    table.load(fileName, data)
    
    -- MapUserData löschen
    clearMapUserData()
    
    -- vorhandene Räume löschen
    for id, _ in pairs(getRooms()) do
        deleteRoom(id)
    end

    -- vorhandene Gebiete löschen, ausser "Default Area"
    for _, id in pairs(getAreaTable()) do
        if id > -1 then
            deleteArea(id)
        end
    end

    for _, areaData in pairs(data.areas) do
        local areaName = areaData.name
        local areaID = areaData.id
        
        if getAreaTableSwap()[areaData.id] ~= nil then
            -- Area schon vorhanden? Löschen...
            deleteArea(areaID)
        end

        -- wir bekommen eventuell neue IDs zu unseren Areas, also merken
        areaID = addAreaName(areaName)

        for k, v in pairs(areaData.userData) do
            setAreaUserData(areaID, k, v)
        end

        for _, roomData in pairs(areaData.rooms) do
            local roomID = roomData.id

            if roomExists(roomID) then
                -- Eventuell vorhandenen Raum mit roomID löschen
                -- sollte aber eigentlichnicht auftreten

                deleteRoom(roomID)
            end

            local ignoreRoom = false

            if roomData.userData ~= nil then
                if roomData.userData.raceLock ~= nil then
                    local userRace = string.lower(gmcp.MG.char.base.race)
                    if roomData.userData.raceLock ~= userRace then
                        -- Raum überspringen
                        ignoreRoom = true

                        display("ignore", userRace, roomData.userData.raceLock)
                    end
                end
            end

            if not ignoreRoom then
                addRoom(roomID)
                setRoomArea(roomID, areaID)
                setRoomName(roomID, roomData.name)
                setRoomIDbyHash(roomID, roomData.hash)
                setRoomChar(roomID, roomData.char)
                setRoomCoordinates(roomID, roomData.coordinates.x, roomData.coordinates.y, roomData.coordinates.z)
                setRoomWeight(roomID, roomData.weight)
                setRoomEnv(roomID, roomData.environment)

                if roomData.userData ~= nil then
                    for k, v in pairs(roomData.userData) do
                        setRoomUserData(roomID, k, v)
                    end
                end

                if roomData.stubExits ~= nil then
                    for _, v in pairs(roomData.stubExits) do
                        setExitStub(roomID, v, true)
                    end
                end
            end
        end

        -- NACHDEM alle Räume in der Karte sind jetzt nocheinmal alle durchgehen
        -- und die Ausgänge einsetzen

        for _, roomData in pairs(areaData.rooms) do
            local roomID = roomData.id

            if roomExists(roomID) then
                -- nur wenn der Raum existiert

                if roomData.exits ~= nil then
                    for direction, targetID in pairs(roomData.exits) do
                        if roomExists(targetID) then
                            -- Raum existiert
                            setExit(roomID, targetID, direction)
                        else
                            -- Raum war wohl rassenspezifisch, er wurde nicht geladen
                            setExitStub(roomID, direction, true)
                        end
                    end
                end
    
                if roomData.specialExits ~= nil then
                    for k, v in pairs(roomData.specialExits) do
                        addSpecialExit(roomID, v, k)
                    end
                end
    
                if roomData.doors ~= nil then
                    for k, v in pairs(roomData.doors) do
                        setDoor(roomID, k, v)
                    end
                end
            end
        end
    end
end

function exportStartMap()
    local fileName = getMudletHomeDir() .. "/exported_map.map"
    -- saveJsonMap(fileName)

    local data = {
        areas = {}
    } -- Tabelle für die Kartendaten

    local areas = getAreaTable()
    for areaName, areaID in pairs(areas) do
        local areaData = {
            name = areaName,
            id = areaID,
            userData = getAllAreaUserData(areaID),
            rooms = {}
        }

        for _, roomID in pairs(getAreaRooms(areaID)) do
            local x, y, z = getRoomCoordinates(roomID)
            local roomData = {
                id = roomID,
                hash = getRoomHashByID(roomID),
                name = getRoomName(roomID),
                char = getRoomChar(roomID),
                coordinates = {
                    x = x,
                    y = y,
                    z = z
                },
                weight = getRoomWeight(roomID),
                environment = getRoomEnv(roomID),
                exits = getRoomExits(roomID),
                specialExits = getSpecialExitsSwap(roomID),
                stubExits = getExitStubs1(roomID),
                doors = getDoors(roomID),
                userData = getAllRoomUserData(roomID)
            }

            table.insert(areaData.rooms, roomData)
        end

        table.insert(data.areas, areaData)
    end

    -- local dataLua = yajl.to_string(data)
    table.save(fileName, data)

    echoM(string.format("Karte nach: %s exportiert.", fileName))
end

-- Funktionen bekommen kein Alias, sondern werden über
-- das lua Modul von Mudlet aufgerufen.
-- So können wir die Sachen für spätere Änderungen ruhig in
-- der Skriptsammlung lassen.

function getRoomRaceLock(roomID)
    roomID = roomID or getPlayerRoom()

    local raceLock = getRoomUserData(roomID, "raceLock")

    if raceLock == nil or raceLock == "" then
        return nil -- Kein Racelock
    end

    return raceLock
end

function removeRoomRaceLock()
    if not getPlayerRoom() then
        echoM("Du solltest Dich schon in einem Raum befinden...")
        return
    end

    -- Rassenlock entfernen
    clearRoomUserDataItem(getPlayerRoom(), "raceLock")
    echoM("Racelock entfernt!")
end

function setRoomRaceLock(race)
    if not getPlayerRoom() then
        echoM("Du solltest Dich schon in einem Raum befinden...")
        return    
    end

    if not race then
        local currentRaceLock = getRoomRaceLock(getPlayerRoom())

        if currentRaceLock == nil then
            echoM("Der Raum gehört keiner Rasse!")
        else
            echoM(string.format("Der Raum gehört der Rasse: %s", currentRaceLock))
        end

        return
    end

    race = string.lower(race) -- in Kleinbuchstaben umwandeln
    
    -- Rassenlock für Raum setzen
    if not table.contains(raceList, race) then
        echoM(string.format("Die Rasse '%s' existiert nicht im MorgenGrauen!", race))
        return
    else
        setRoomUserData(getPlayerRoom(), "raceLock", race)
        echoM(string.format("Der Raum gehoert nun: %s", race))
    end
end