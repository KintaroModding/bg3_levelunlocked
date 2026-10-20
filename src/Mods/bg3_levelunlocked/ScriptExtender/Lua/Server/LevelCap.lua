-- The level cap that the game uses: the XPData and Data keys of this mod's stats files
-- (Public/bg3_levelunlocked/Stats/Generated/Data/XPData.txt and Data.txt), as the game merged them. Another mod that
-- sets the same keys and loads later wins; the log line shows it.

local LevelCap = {}

LevelCap.MaxLevel = 16

-- MaxXPLevel: the highest level. LevelN: the experience from level N to N + 1. MaximumXPCap: the most experience a
-- character can hold.
LevelCap.Keys = { "MaxXPLevel", "MaximumXPCap", "Level12", "Level13", "Level14", "Level15", "Level16" }

--- Returns the value of an ExtraData key, or nil.
function LevelCap.Value(key)
    local ok, value = pcall(function() return Ext.Stats.GetStatsManager().ExtraData[key] end)
    if ok then
        return value
    end
    return nil
end

--- Returns every key with its value for the log: "MaxXPLevel = 16, MaximumXPCap = 240000, ...".
function LevelCap.Describe()
    local parts = {}
    for _, key in ipairs(LevelCap.Keys) do
        local value = LevelCap.Value(key)
        if type(value) == "number" and value == math.floor(value) then
            value = string.format("%d", value)
        end
        parts[#parts + 1] = key .. " = " .. tostring(value)
    end
    return table.concat(parts, ", ")
end

--- Returns nil when the game uses this mod's level cap, else a warning for the log.
function LevelCap.Check()
    local max = LevelCap.Value("MaxXPLevel")
    if max == LevelCap.MaxLevel then
        return nil
    end
    return string.format("The level cap is %s, not %d: another mod that loads later sets MaxXPLevel, or the stats "
        .. "files of this mod did not load.", tostring(max), LevelCap.MaxLevel)
end

return LevelCap
