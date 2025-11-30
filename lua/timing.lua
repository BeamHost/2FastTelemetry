-- File: lua/timing.lua
-- Lap timing, checkpoint tracking, and UI updates.

local json = require("json")
local Rating = require("lua.rating")
local UserData = require("lua.userdata")

local Timing = {
    players = {},
    Tracks = nil
}

local function nowMs()
    return math.floor(os.clock() * 1000)
end

local function sendUI(playerId, event, payload)
    MP.TriggerClientEvent(playerId, event, json.encode(payload))
end

local function resetLapState(state)
    state.currentLapStart = nowMs()
    state.currentLapTime = 0
    state.currentSector = 1
    state.currentCheckpoint = 1
    state.missed = false
    state.deltas = {}
end

function Timing.init(Tracks)
    Timing.Tracks = Tracks
end

function Timing.onPlayerLoaded(playerId)
    local layout = Timing.Tracks.getCurrentLayout()
    Timing.players[playerId] = {
        layoutId = layout and layout.layoutId,
        carId = MP.GetPlayerVehicleModel(playerId),
        laps = {},
        bestLapMs = {},
        bestSplits = {},
        inRace = false
    }
    resetLapState(Timing.players[playerId])
end

function Timing.onPlayerLeft(playerId)
    Timing.players[playerId] = nil
end

function Timing.onVehicleSpawn(playerId, vehicleId)
    local state = Timing.players[playerId]
    if state then
        state.carId = MP.GetPlayerVehicleModel(playerId)
        resetLapState(state)
    end
end

function Timing.onVehicleReset(playerId)
    local state = Timing.players[playerId]
    if state then
        state.missed = true
        sendUI(playerId, "2fast:lapInvalidated", { reason = "reset" })
    end
end

function Timing.onTeleport(playerId)
    local state = Timing.players[playerId]
    if state then
        state.missed = true
        sendUI(playerId, "2fast:lapInvalidated", { reason = "teleport" })
    end
end

local function getCheckpoint(layout, idx)
    if not layout or not layout.checkpoints then return nil end
    for _, cp in ipairs(layout.checkpoints) do
        if cp.id == idx then return cp end
    end
end

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function updateDelta(state, layout, carId, lapMs)
    local best = (state.bestLapMs[carId] or {})[layout.layoutId]
    local delta = nil
    if best then delta = lapMs - best end
    state.lastDelta = delta
end

local function finalizeLap(playerId, state, layout)
    local lapMs = nowMs() - state.currentLapStart
    if state.missed then
        sendUI(playerId, "2fast:lapInvalidated", { reason = "missed" })
        resetLapState(state)
        return
    end
    local carId = state.carId or MP.GetPlayerVehicleModel(playerId)
    state.bestLapMs[carId] = state.bestLapMs[carId] or {}
    local carBest = state.bestLapMs[carId]
    if not carBest[layout.layoutId] or lapMs < carBest[layout.layoutId] then
        carBest[layout.layoutId] = lapMs
    end
    updateDelta(state, layout, carId, lapMs)
    local userName = MP.GetPlayerName(playerId)
    local data = UserData.updateOnLap(userName, layout.layoutId, carId, lapMs, state.deltas, state.inRace, state.racePos, state.raceField)
    Rating.updateOnLap(data, {
        isRaceLap = state.inRace,
        lapTimeMs = lapMs,
        position = state.racePos,
        fieldSize = state.raceField,
        layoutPaceMs = carBest[layout.layoutId]
    })
    UserData.save(userName, data)
    sendUI(playerId, "2fast:lapCompleted", {
        lapTimeMs = lapMs,
        bestLapMs = carBest[layout.layoutId],
        delta = state.lastDelta,
        sectorSplits = state.deltas
    })
    resetLapState(state)
end

function Timing.onTick(dt)
    for playerId, state in pairs(Timing.players) do
        local layout = Timing.Tracks.getCurrentLayout()
        if not layout then goto continue end
        state.layoutId = layout.layoutId
        local pos = MP.GetPlayerPosition(playerId)
        if not pos then goto continue end
        local cp = getCheckpoint(layout, state.currentCheckpoint)
        if cp then
            local dist = distance(pos, {x = cp.position.x, y = cp.position.y, z = cp.position.z})
            if dist <= cp.radius then
                state.currentCheckpoint = state.currentCheckpoint + 1
                state.currentSector = cp.sectorIndex
                state.deltas[cp.sectorIndex] = nowMs() - state.currentLapStart
                sendUI(playerId, "2fast:sectorUpdate", {
                    sector = cp.sectorIndex,
                    splitMs = state.deltas[cp.sectorIndex]
                })
                if state.currentCheckpoint > #layout.checkpoints then
                    finalizeLap(playerId, state, layout)
                end
            end
        end
        state.currentLapTime = nowMs() - state.currentLapStart
        sendUI(playerId, "2fast:tick", {
            lapTimeMs = state.currentLapTime,
            currentSector = state.currentSector,
            delta = state.lastDelta
        })
        ::continue::
    end
end

function Timing.startRace(field)
    -- field: ordered list of playerIds
    for pos, pid in ipairs(field) do
        local state = Timing.players[pid]
        if state then
            state.inRace = true
            state.racePos = pos
            state.raceField = #field
            resetLapState(state)
        end
    end
end

function Timing.finishRace()
    for _, state in pairs(Timing.players) do
        state.inRace = false
    end
end

return Timing
