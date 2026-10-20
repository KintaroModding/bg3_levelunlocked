-- Writes every change of a party member's experience to the log: the proof that the multiplier works, and what a
-- level-up past 12 does. It only reads.

local XPMultiplier = Ext.Require("Server/XPMultiplier.lua")

local ExperienceWatch = {}

local started = false
-- [character UUID, else name] = the total experience seen last.
local totals = {}

--- Returns "level 12, can reach 13" from the level components, or "" when they are missing.
local function Levels(entity)
    local ok, text = pcall(function()
        local level = entity.EocLevel.Level
        local available = entity.AvailableLevel and entity.AvailableLevel.Level
        if available ~= nil and available > level then
            return string.format(", level %d, can reach %d", level, available)
        end
        return string.format(", level %d", level)
    end)
    return ok and text or ""
end

local function OnExperience(entity, log)
    if entity.PartyMember == nil or entity.Experience == nil then
        return
    end
    local name = XPMultiplier.Name(entity)
    local uuidOk, uuid = pcall(function() return entity.Uuid.EntityUuid end)
    local key = uuidOk and uuid or name
    local total = entity.Experience.TotalExperience
    local last = totals[key]
    if last == total then
        return
    end
    totals[key] = total
    if last == nil then
        log(string.format("Experience of %s: %d%s.", name, total, Levels(entity)))
    else
        log(string.format("Experience of %s: %d -> %d (%+d)%s.", name, last, total, total - last, Levels(entity)))
    end
end

--- Subscribes to changes of the Experience component once per Lua state. Returns true, or false and the error.
function ExperienceWatch.Start(log)
    if started then
        return true
    end
    local ok, err = pcall(Ext.Entity.Subscribe, "Experience", function(entity)
        local watchOk, watchErr = pcall(OnExperience, entity, log)
        if not watchOk then
            log("Could not read the experience: " .. tostring(watchErr))
        end
    end)
    if not ok then
        return false, err
    end
    started = true
    return true
end

return ExperienceWatch
