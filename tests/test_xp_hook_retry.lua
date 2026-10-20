-- When the experience system does not exist yet on SessionLoaded, the hooks start when the level starts. Without MCM
-- the factor is 1: the gains stay as they are, and the log still shows them. Another mod's level cap gives a warning.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
Harness.ExtraData = { MaxXPLevel = 20, MaximumXPCap = 420000 }

local system = { IncreaseExperience = {} }
Ext.System.ServerExperience = system

Ext.Require("BootstrapServer.lua")

local function ServerLog()
    Harness.RunTimers()
    return Harness.Files["bg3_levelunlocked/server.log"] or ""
end

local function Contains(text)
    return string.find(ServerLog(), text, 1, true) ~= nil
end

Test("another level cap gives a warning", function()
    Ext.Events.SessionLoaded:Fire()
    AssertTrue(Contains("The level cap is 20, not 16: another mod that loads later sets MaxXPLevel"), "warning")
end)

Test("a missing system is logged on SessionLoaded", function()
    AssertTrue(Contains("The experience multiplier could not start (SessionLoaded): "), "multiplier line")
    AssertTrue(Contains("System ServerExperience not registered"), "the error")
    AssertTrue(not Contains("Experience hooks ready"), "not ready")
end)

Test("the hooks start on LevelGameplayStarted", function()
    Harness.RegisteredSystems.ServerExperience = true
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertTrue(Contains("Experience hooks ready (LevelGameplayStarted)."), "ready line")
    AssertEq(#Harness.SystemHooks.ServerExperience.Pre, 1, "one hook before the update")
    AssertEq(#Harness.ComponentSubscriptions.Experience, 1, "one subscription: the retry does not subscribe again")
end)

Test("without MCM the gains stay as they are", function()
    local tav = Harness.Character("Tav", "11111111-1111-1111-1111-111111111111")
    system.IncreaseExperience[tav] = 75
    Harness.RunSystemUpdate("ServerExperience", nil)
    AssertEq(system.IncreaseExperience[tav], 75, "unchanged")
    AssertTrue(Contains("Experience for Tav: 75 -> 75 (x1)."), "line")
end)
