-- Multiplies the experience that characters gain. The server's experience system (esv::exp::ExperienceSystem,
-- Ext.System.ServerExperience) collects the pending gains in its map IncreaseExperience (character -> amount) and adds
-- them in its update. A hook before that update scales every pending amount, so every source counts (kills,
-- exploration, quests), and the game itself adds the experience and checks for a level-up.

local XPMultiplier = {}

XPMultiplier.MinFactor = 0.5
XPMultiplier.MaxFactor = 5.0

--- Returns the factor for a setting value: clamped to MinFactor..MaxFactor and rounded to two decimals (the MCM slider
--- can give 1.5000001). A value that is not a number gives 1.
function XPMultiplier.Factor(value)
    if type(value) ~= "number" or value ~= value then
        return 1
    end
    value = math.max(XPMultiplier.MinFactor, math.min(XPMultiplier.MaxFactor, value))
    return math.floor(value * 100 + 0.5) / 100
end

--- Returns the amount times the factor, rounded to a whole number. Amounts of 0 or less stay as they are.
function XPMultiplier.Scale(amount, factor)
    if type(amount) ~= "number" or amount <= 0 then
        return amount
    end
    return math.floor(amount * factor + 0.5)
end

--- Returns "1.5" for 1.5 and "2" for 2.0, for the log.
function XPMultiplier.FormatFactor(factor)
    local text = string.format("%.2f", factor)
    text = string.gsub(text, "0+$", "")
    return (string.gsub(text, "%.$", ""))
end

--- Returns a key for an entity that stays the same while the entity lives.
local function EntityKey(entity)
    local ok, value = pcall(Ext.Utils.HandleToInteger, entity)
    if ok and value ~= nil then
        return value
    end
    return tostring(entity)
end

--- Returns the name of a character for the log, else its UUID.
function XPMultiplier.Name(entity)
    for _, field in ipairs({ "Name", "NameKey" }) do
        local ok, name = pcall(function() return entity.DisplayName[field]:Get() end)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    local ok, uuid = pcall(function() return entity.Uuid.EntityUuid end)
    if ok and uuid ~= nil then
        return tostring(uuid)
    end
    return tostring(entity)
end

local started = false
-- [entity key] = the amount this mod left in the map. When the game has not added an amount yet, the next update must
-- not scale it again; the post-update hook forgets every key that left the map.
local written = {}

local function ScalePending(getFactor, log)
    local system = Ext.System.ServerExperience
    if system == nil then
        return
    end
    local pending = {}
    for entity, amount in pairs(system.IncreaseExperience) do
        pending[#pending + 1] = { Entity = entity, Amount = amount }
    end
    if #pending == 0 then
        return
    end
    local factor = XPMultiplier.Factor(getFactor())
    for _, item in ipairs(pending) do
        local key = EntityKey(item.Entity)
        if written[key] ~= item.Amount then
            local scaled = XPMultiplier.Scale(item.Amount, factor)
            if scaled ~= item.Amount then
                system.IncreaseExperience[item.Entity] = scaled
            end
            written[key] = scaled
            log(string.format("Experience for %s: %s -> %s (x%s).", XPMultiplier.Name(item.Entity),
                tostring(item.Amount), tostring(scaled), XPMultiplier.FormatFactor(factor)))
        end
    end
end

local function ForgetAdded()
    if next(written) == nil then
        return
    end
    local system = Ext.System.ServerExperience
    local left = {}
    if system ~= nil then
        for entity in pairs(system.IncreaseExperience) do
            left[EntityKey(entity)] = true
        end
    end
    for key in pairs(written) do
        if not left[key] then
            written[key] = nil
        end
    end
end

--- Hooks the experience system once per Lua state. getFactor() returns the setting value; log(message) writes a line.
--- Returns true when the hook is in place, else false and the error (the system may not exist yet).
function XPMultiplier.Start(getFactor, log)
    if started then
        return true
    end
    local ok, err = pcall(function()
        -- The post-update hook first: alone it does nothing, so a failure of the second call leaves no half hook.
        Ext.Entity.OnSystemPostUpdate("ServerExperience", function()
            pcall(ForgetAdded)
        end)
        local reported = {}
        Ext.Entity.OnSystemUpdate("ServerExperience", function()
            local scaledOk, scaledErr = pcall(ScalePending, getFactor, log)
            -- The hook runs every frame: report each error once.
            if not scaledOk and not reported[tostring(scaledErr)] then
                reported[tostring(scaledErr)] = true
                log("Could not scale the experience: " .. tostring(scaledErr))
            end
        end)
    end)
    if not ok then
        return false, err
    end
    started = true
    return true
end

return XPMultiplier
