local Common = Ext.Require("Shared/Common.lua")
local Settings = Ext.Require("Shared/Settings.lua")
local ServerLog = Ext.Require("Server/ServerLog.lua")
local LevelCap = Ext.Require("Server/LevelCap.lua")
local XPMultiplier = Ext.Require("Server/XPMultiplier.lua")
local ExperienceWatch = Ext.Require("Server/ExperienceWatch.lua")

local function Multiplier()
    return (Settings.Get("xp_multiplier"))
end

-- Both hooks need the game's entity system. Tried on SessionLoaded, and again when the level starts if that failed.
local hooksReady = false

local function StartHooks(when)
    if hooksReady then
        return
    end
    local xpOk, xpErr = XPMultiplier.Start(Multiplier, ServerLog.Add)
    local watchOk, watchErr = ExperienceWatch.Start(ServerLog.Add)
    if xpOk and watchOk then
        hooksReady = true
        ServerLog.Add("Experience hooks ready (" .. when .. ").")
        return
    end
    if not xpOk then
        ServerLog.Add("The experience multiplier could not start (" .. when .. "): " .. tostring(xpErr))
    end
    if not watchOk then
        ServerLog.Add("The experience log could not start (" .. when .. "): " .. tostring(watchErr))
    end
end

Ext.Events.SessionLoaded:Subscribe(function()
    ServerLog.Add("Level Unlocked " .. Common.ModVersion() .. " loaded.")
    ServerLog.Add("Settings: " .. Settings.Describe() .. ".")
    ServerLog.Add("Level data: " .. LevelCap.Describe() .. ".")
    local warning = LevelCap.Check()
    if warning ~= nil then
        ServerLog.Add(warning)
    end
    StartHooks("SessionLoaded")
end)

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    StartHooks("LevelGameplayStarted")
end)

-- In multiplayer, the host's server holds the values that count. The multiplier reads the setting at every gain.
Settings.OnChange(function(settingId)
    local reason = settingId and ("Setting changed (" .. tostring(settingId) .. ")") or "MCM profile changed"
    ServerLog.Add(reason .. ": " .. Settings.Describe() .. ".")
end)
