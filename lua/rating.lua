-- File: lua/rating.lua
-- Simple Elo-like rating updated every lap.

local Rating = {}

Rating.DEFAULT = 1500
Rating.K_HOTLAP = 4
Rating.K_RACE = 16

function Rating.initPlayer(data)
    if not data.rating then
        data.rating = Rating.DEFAULT
    end
end

local function calcDelta(ctx)
    local k = ctx.isRaceLap and Rating.K_RACE or Rating.K_HOTLAP
    local base = (ctx.fieldSize and ctx.fieldSize > 1) and (ctx.fieldSize - (ctx.position or ctx.fieldSize)) or 0
    local pace = ctx.lapTimeMs and ctx.layoutPaceMs and ((ctx.layoutPaceMs - ctx.lapTimeMs) / ctx.layoutPaceMs) or 0
    local sof = ctx.strengthOfField or 0
    return k * (0.5 * base + 20 * pace + sof)
end

function Rating.updateOnLap(data, ctx)
    Rating.initPlayer(data)
    local delta = calcDelta(ctx)
    data.rating = math.max(1, math.floor(data.rating + delta))
    return delta
end

return Rating
