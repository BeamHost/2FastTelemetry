-- File: lua/tracks.lua
-- Track and layout management: loads staff-authored JSON checkpoints.

local json = require("json")

local Tracks = {
    layouts = {},
    currentLayoutId = nil
}

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function listLayouts()
    local files = {}
    local p = io.popen('ls tracks')
    if p then
        for file in p:lines() do
            if file:match("%.json$") then
                table.insert(files, "tracks/" .. file)
            end
        end
        p:close()
    end
    return files
end

function Tracks.loadAllTracks()
    Tracks.layouts = {}
    for _, path in ipairs(listLayouts()) do
        local raw = readFile(path)
        if raw then
            local data = json.decode(raw)
            if data and data.layoutId then
                Tracks.layouts[data.layoutId] = data
                MP.DebugPrint("Loaded layout " .. data.layoutId)
            else
                MP.DebugPrint("Failed to parse layout at " .. path)
            end
        end
    end
end

function Tracks.getLayoutById(layoutId)
    return Tracks.layouts[layoutId]
end

function Tracks.getAnyLayoutId()
    for id, _ in pairs(Tracks.layouts) do
        return id
    end
    return nil
end

function Tracks.setCurrentLayout(layoutId)
    if Tracks.layouts[layoutId] then
        Tracks.currentLayoutId = layoutId
        MP.TriggerClientEvent(-1, "2fast:layoutChanged", json.encode({layoutId = layoutId}))
    end
end

function Tracks.getCurrentLayout()
    return Tracks.layouts[Tracks.currentLayoutId]
end

return Tracks
