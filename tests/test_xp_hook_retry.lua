-- When the hooks cannot start on SessionLoaded, they start when the level starts. Without MCM the factor is 1: the
-- gains stay as they are, and the log still shows them. Another mod's level cap gives a warning.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
Harness.ExtraData = { MaxXPLevel = 20, MaximumXPCap = 420000, Level1 = 300 }

local tav = Harness.Character("Tav", "11111111-1111-1111-1111-111111111111", { Experience = 100 })

Ext.Require("BootstrapServer.lua")

local function ServerLog()
    Harness.RunTimers()
    return Harness.Files["bg3_levelunlocked/server.log"] or ""
end

local function Contains(text)
    return string.find(ServerLog(), text, 1, true) ~= nil
end

local subscribe = Ext.Entity.Subscribe

Test("another level cap gives a warning", function()
    Ext.Entity.Subscribe = function() error("entity system not ready") end
    Ext.Events.SessionLoaded:Fire()
    Ext.Entity.Subscribe = subscribe
    AssertTrue(Contains("The level cap is 20, not 16: another mod that loads later sets MaxXPLevel"), "warning")
end)

Test("a failed start is logged on SessionLoaded", function()
    AssertTrue(Contains("The experience multiplier could not start (SessionLoaded): "), "multiplier line")
    AssertTrue(Contains("The experience log could not start (SessionLoaded): "), "log line")
    AssertTrue(Contains("entity system not ready"), "the error")
    AssertTrue(not Contains("Experience hooks ready"), "not ready")
end)

Test("the hooks start on LevelGameplayStarted", function()
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertTrue(Contains("Experience hooks ready (LevelGameplayStarted)."), "ready line")
    AssertEq(#Harness.ComponentSubscriptions.Experience, 2, "the multiplier and the log")
end)

Test("without MCM the gains stay as they are", function()
    Harness.PartyGain(75)
    Harness.RunTicks(20)
    AssertEq(tav.Experience.TotalExperience, 175, "unchanged gain")
    AssertEq(#Harness.ExperienceCalls, 0, "no call")
    AssertTrue(Contains("Gain x1: Tav +75 -> +75."), "gain line")
end)
