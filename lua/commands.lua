-- File: lua/commands.lua
-- Chat commands for 2FastTelemetry

local Commands = {}

local Tracks
local Timing
local Rating
local Events
local UserData

local function reply(playerId, msg)
    MP.SendChatMessage(playerId, "[2Fast] " .. msg)
end

local function formatMs(ms)
    if not ms then return "--" end
    local totalSeconds = ms / 1000
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds - minutes * 60
    return string.format("%d:%06.3f", minutes, seconds)
end

function Commands.init(_Tracks, _Timing, _Rating, _Events, _UserData)
    Tracks = _Tracks
    Timing = _Timing
    Rating = _Rating
    Events = _Events
    UserData = _UserData
end

function Commands.handleChat(playerId, message)
    if not message:find("^/") then return false end
    local args = {}
    for token in message:gmatch("%S+") do table.insert(args, token) end
    local cmd = args[1]:sub(2):lower()
    if cmd == "2fast" or cmd == "telemetry" then
        reply(playerId, "Commands: /rating /laps /event")
        return true
    elseif cmd == "rating" then
        local name = MP.GetPlayerName(playerId)
        local data = UserData.get(name)
        reply(playerId, string.format("Rating: %d", data.rating or Rating.DEFAULT))
        return true
    elseif cmd == "laps" then
        local name = MP.GetPlayerName(playerId)
        local state = Timing.players[playerId]
        local layoutId = state and state.layoutId or (Tracks.getCurrentLayout() or {}).layoutId
        local carId = state and state.carId or MP.GetPlayerVehicleModel(playerId)
        local data = UserData.get(name)
        local track = data.tracksDriven[layoutId] or {}
        local carStats = data.carsDriven[carId] or {}
        reply(playerId, string.format("Layout %s best: %s | Car %s best: %s", layoutId or "n/a", formatMs(track.bestLapMs), carId or "n/a", formatMs(carStats.bestLapMs)))
        return true
    elseif cmd == "event" then
        local active = Events.getActiveEvent()
        if active then
            reply(playerId, string.format("Active event: %s (%s) laps: %d", active.name, active.layoutId, active.laps))
        else
            local nextEvent = Events.peekNextEvent()
            if nextEvent then
                reply(playerId, string.format("Next event: %s on %s, %d laps", nextEvent.name, nextEvent.layoutId, nextEvent.laps))
            else
                reply(playerId, "No events configured")
            end
        end
        return true
    end
    return false
end

return Commands
