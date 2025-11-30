-- File: lua/userdata.lua
-- JSON persistence for player stats.

local json = require("json")
local Rating = require("lua.rating")

local UserData = {
    cache = {}
}

local function isPersistable(name)
    if not name or name == "" then return false end
    if name:lower():find("^guest") then return false end
    if name:match("^%d+$") then return false end
    return true
end

local function pathFor(name)
    return "userData/" .. name .. ".json"
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function writeFile(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

function UserData.ensureLoaded(name)
    if UserData.cache[name] then return UserData.cache[name] end
    local data = {
        name = name,
        totalLapsCompleted = 0,
        totalRaceTimeMs = 0,
        carsDriven = {},
        tracksDriven = {},
        rating = Rating.DEFAULT,
        raceWins = 0,
        raceLossesOrStarts = 0,
        autoEventsParticipated = 0
    }
    if isPersistable(name) then
        local file = pathFor(name)
        local raw = readFile(file)
        if raw then
            local parsed = json.decode(raw)
            if parsed then data = parsed end
        end
    end
    UserData.cache[name] = data
    return data
end

function UserData.get(name)
    return UserData.cache[name] or UserData.ensureLoaded(name)
end

function UserData.save(name, data)
    data = data or UserData.cache[name]
    if not isPersistable(name) or not data then return false end
    return writeFile(pathFor(name), json.encode(data))
end

function UserData.saveAll()
    for name, data in pairs(UserData.cache) do
        UserData.save(name, data)
    end
end

function UserData.updateOnLap(playerName, layoutId, carId, lapTime, sectors, isRaceLap, position, fieldSize)
    local data = UserData.get(playerName)
    data.totalLapsCompleted = (data.totalLapsCompleted or 0) + 1
    data.totalRaceTimeMs = (data.totalRaceTimeMs or 0) + (lapTime or 0)
    data.carsDriven[carId] = data.carsDriven[carId] or { laps = 0, bestLapMs = nil }
    local carStats = data.carsDriven[carId]
    carStats.laps = carStats.laps + 1
    if not carStats.bestLapMs or lapTime < carStats.bestLapMs then
        carStats.bestLapMs = lapTime
    end
    data.tracksDriven[layoutId] = data.tracksDriven[layoutId] or { bestLapMs = nil, laps = 0 }
    local trackStats = data.tracksDriven[layoutId]
    trackStats.laps = trackStats.laps + 1
    if not trackStats.bestLapMs or lapTime < trackStats.bestLapMs then
        trackStats.bestLapMs = lapTime
    end
    if isRaceLap then
        data.raceLossesOrStarts = (data.raceLossesOrStarts or 0) + 1
        if position == 1 then data.raceWins = (data.raceWins or 0) + 1 end
    end
    return data
end

return UserData
