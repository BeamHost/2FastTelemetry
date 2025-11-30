-- File: main.lua
-- 2FastTelemetry main entrypoint for BeamMP 3.x
-- Loads modules, wires BeamMP events, and runs timing + event loops.

local json = require("json")
local Tracks = require("lua.tracks")
local Timing = require("lua.timing")
local Commands = require("lua.commands")
local Rating = require("lua.rating")
local Events = require("lua.events")
local UserData = require("lua.userdata")

-- Configuration
local TICK_INTERVAL_MS = 50

local lastTick = os.clock()

local function ensureDirs()
    local dirs = {"userData"}
    for _, d in ipairs(dirs) do
        os.execute("mkdir -p " .. d)
    end
end

local function init()
    ensureDirs()
    Tracks.loadAllTracks()
    Events.loadConfig()
    Events.attach(Tracks, Timing)
    local defaultLayout = Events.getDefaultLayout() or Tracks.getAnyLayoutId()
    if defaultLayout then
        Tracks.setCurrentLayout(defaultLayout)
    end
    Timing.init(Tracks)
    Commands.init(Tracks, Timing, Rating, Events, UserData)
end

-- BeamMP Event Wiring ------------------------------------------------------
function onInit()
    init()
    MP.DebugPrint("2FastTelemetry initialized")
end

function onPlayerJoin(playerId)
    local name = MP.GetPlayerName(playerId)
    UserData.ensureLoaded(name)
    Rating.initPlayer(UserData.get(name))
    Timing.onPlayerLoaded(playerId)
end

function onPlayerDisconnect(playerId)
    local name = MP.GetPlayerName(playerId)
    UserData.save(name)
    Timing.onPlayerLeft(playerId)
end

function onVehicleSpawn(playerId, vehicleId)
    Timing.onVehicleSpawn(playerId, vehicleId)
end

function onVehicleReset(playerId)
    Timing.onVehicleReset(playerId)
end

function onChatMessage(playerId, message)
    if Commands.handleChat(playerId, message) then return 1 end
    return 0
end

function onTick()
    local now = os.clock()
    local dt = (now - lastTick) * 1000
    if dt >= TICK_INTERVAL_MS then
        lastTick = now
        Timing.onTick(dt)
        Events.onTick(dt)
    end
end

-- Event hooks for BeamMP server. Names follow API 3.x convention.
MP.RegisterEvent("onInit", "onInit")
MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnect")
MP.RegisterEvent("onVehicleSpawn", "onVehicleSpawn")
MP.RegisterEvent("onVehicleReset", "onVehicleReset")
MP.RegisterEvent("onChatMessage", "onChatMessage")
MP.RegisterEvent("onTick", "onTick")

return {}
