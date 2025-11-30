-- File: lua/events.lua
-- Automatic race/event loop management

local json = require("json")
local Tracks = nil
local Timing = nil
local UserData = require("lua.userdata")

local Events = {
    config = { events = {} },
    activeEvent = nil,
    nextIndex = 1,
    cooldownMs = 0,
    countdownMs = 0,
    state = "lobby"
}

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

function Events.loadConfig()
    local raw = readFile("config/event_loop.json")
    if raw then
        local parsed = json.decode(raw)
        if parsed then Events.config = parsed end
    end
end

function Events.attach(trackModule, timingModule)
    Tracks = trackModule
    Timing = timingModule
end

function Events.getDefaultLayout()
    local ev = Events.config.events[1]
    return ev and ev.layoutId or nil
end

function Events.getActiveEvent()
    return Events.activeEvent
end

function Events.peekNextEvent()
    return Events.config.events[Events.nextIndex]
end

local function eligiblePlayers(event)
    local list = {}
    for pid, state in pairs(Timing.players) do
        local car = state.carId or MP.GetPlayerVehicleModel(pid)
        if not event.allowedCars or #event.allowedCars == 0 then
            table.insert(list, pid)
        else
            for _, allowed in ipairs(event.allowedCars) do
                if car == allowed then
                    table.insert(list, pid)
                end
            end
        end
    end
    return list
end

local function orderGridByRating(pids)
    table.sort(pids, function(a, b)
        local ra = (UserData.get(MP.GetPlayerName(a)).rating or 0)
        local rb = (UserData.get(MP.GetPlayerName(b)).rating or 0)
        return ra > rb
    end)
    return pids
end

local function placeOnGrid(layout, grid)
    if not layout or not layout.startGrid then return end
    for idx, pid in ipairs(grid) do
        local slot = layout.startGrid[idx]
        if slot then
            MP.SetPlayerTeleport(pid, slot.position.x, slot.position.y, slot.position.z, slot.rotation or 0)
        end
    end
end

local function startRace(event)
    local layout = Tracks.getLayoutById(event.layoutId)
    Tracks.setCurrentLayout(event.layoutId)
    local pids = orderGridByRating(eligiblePlayers(event))
    placeOnGrid(layout, pids)
    Timing.startRace(pids)
    Events.activeEvent = event
    Events.state = "race"
    Events.countdownMs = 0
    MP.TriggerClientEvent(-1, "2fast:raceStart", json.encode({ event = event, field = pids }))
end

local function finishRace()
    Timing.finishRace()
    Events.activeEvent = nil
    Events.state = "cooldown"
    Events.cooldownMs = (Events.peekNextEvent() and (Events.peekNextEvent().raceCooldownSec or 300) * 1000) or 300000
    Events.nextIndex = Events.nextIndex % #Events.config.events + 1
    MP.TriggerClientEvent(-1, "2fast:raceFinished", json.encode({}))
end

function Events.onTick(dt)
    if not Tracks then return end
    if Events.state == "race" then
        -- TODO: detect race end conditions based on laps completed
        return
    end
    if Events.state == "cooldown" then
        Events.cooldownMs = math.max(0, Events.cooldownMs - dt)
        if Events.cooldownMs <= 0 then
            Events.state = "lobby"
        end
        return
    end
    if Events.state == "lobby" then
        local nextEvent = Events.peekNextEvent()
        if not nextEvent then return end
        local players = eligiblePlayers(nextEvent)
        if #players >= (nextEvent.minPlayers or 2) then
            Events.state = "countdown"
            Events.countdownMs = 5000
            Events.pendingEvent = nextEvent
            MP.TriggerClientEvent(-1, "2fast:raceCountdown", json.encode({ seconds = Events.countdownMs / 1000, event = nextEvent }))
        end
        return
    end
    if Events.state == "countdown" then
        Events.countdownMs = math.max(0, Events.countdownMs - dt)
        if Events.countdownMs <= 0 and Events.pendingEvent then
            startRace(Events.pendingEvent)
            Events.pendingEvent = nil
        end
    end
end

return Events
