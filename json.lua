-- File: json.lua
-- Lightweight JSON helper. In BeamMP 3.x, many servers bundle dkjson; this acts
-- as a wrapper with a tiny fallback encoder/decoder for small payloads.

local json = {}

local ok, dkjson = pcall(require, "dkjson")
if ok and dkjson then
    json.decode = function(str)
        return dkjson.decode(str)
    end
    json.encode = function(tbl)
        return dkjson.encode(tbl, { indent = false })
    end
else
    -- Minimal fallback for simple tables (string/number/boolean/nil, no cycles)
    local function escapeStr(s)
        s = s:gsub('\\', '\\\\'):gsub('"', '\\"')
        return '"' .. s .. '"'
    end

    local function encodeValue(v)
        local t = type(v)
        if t == "string" then return escapeStr(v) end
        if t == "number" or t == "boolean" then return tostring(v) end
        if v == nil then return "null" end
        if t == "table" then
            local isArray = (#v > 0)
            local parts = {}
            if isArray then
                for i = 1, #v do
                    parts[#parts+1] = encodeValue(v[i])
                end
                return "[" .. table.concat(parts, ",") .. "]"
            else
                for k, val in pairs(v) do
                    parts[#parts+1] = escapeStr(tostring(k)) .. ":" .. encodeValue(val)
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
        end
        return '"unsupported"'
    end

    local function parseError(msg)
        return nil, msg
    end

    -- Extremely small JSON reader using load; not for untrusted input.
    local function decode(str)
        local luaStr = str:gsub('null', 'nil'):gsub('true', 'true'):gsub('false', 'false')
        local f, err = load("return " .. luaStr)
        if not f then return parseError(err) end
        return f()
    end

    json.encode = encodeValue
    json.decode = decode
end

return json
