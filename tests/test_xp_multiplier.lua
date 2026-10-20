-- The experience multiplier scales the pending gains of the server's experience system before its update, once per
-- gain, with the MCM value at that moment. The experience log reports every change of a party member's experience.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
Harness.InstallMCM({ xp_multiplier = 2.0 })
Harness.RegisteredSystems.ServerExperience = true
Harness.ExtraData = { MaxXPLevel = 16, MaximumXPCap = 240000, Level12 = 30000, Level13 = 20000, Level14 = 25000,
    Level15 = 30000, Level16 = 35000 }

local system = { IncreaseExperience = {} }
Ext.System.ServerExperience = system

Ext.Require("BootstrapServer.lua")
local XPMultiplier = Ext.Require("Server/XPMultiplier.lua")

local tav = Harness.Character("Tav", "11111111-1111-1111-1111-111111111111", { Experience = 1000, Level = 3 })
local gale = Harness.Character("Gale", "22222222-2222-2222-2222-222222222222", { Experience = 1000, Level = 3 })

local function ServerLog()
    Harness.RunTimers()
    return Harness.Files["bg3_levelunlocked/server.log"] or ""
end

local function Contains(text)
    return string.find(ServerLog(), text, 1, true) ~= nil
end

--- One update in which the game adds every pending gain and empties the map.
local function GameAddsPending()
    for entity, amount in pairs(system.IncreaseExperience) do
        entity.Experience.TotalExperience = entity.Experience.TotalExperience + amount
    end
    system.IncreaseExperience = {}
end

Test("Factor clamps to 0.5..5 and rounds to two decimals", function()
    AssertEq(XPMultiplier.Factor(0.1), 0.5, "below the range")
    AssertEq(XPMultiplier.Factor(9), 5.0, "above the range")
    AssertEq(XPMultiplier.Factor(1.5000001), 1.5, "slider noise")
    AssertEq(XPMultiplier.Factor("2"), 1, "not a number")
    AssertEq(XPMultiplier.Factor(0 / 0), 1, "NaN")
end)

Test("Scale rounds to whole numbers and leaves 0 and less alone", function()
    AssertEq(XPMultiplier.Scale(100, 1.5), 150, "1.5")
    AssertEq(XPMultiplier.Scale(101, 0.5), 51, "rounds half up")
    AssertEq(XPMultiplier.Scale(33, 0.5), 17, "rounds")
    AssertEq(math.type(XPMultiplier.Scale(33, 0.5)), "integer", "an integer for the game's int map")
    AssertEq(XPMultiplier.Scale(0, 2), 0, "zero")
    AssertEq(XPMultiplier.Scale(-5, 2), -5, "negative")
end)

Test("FormatFactor drops trailing zeros", function()
    AssertEq(XPMultiplier.FormatFactor(1.5), "1.5", "1.5")
    AssertEq(XPMultiplier.FormatFactor(2.0), "2", "2")
    AssertEq(XPMultiplier.FormatFactor(0.75), "0.75", "0.75")
end)

Test("the session load logs the level data and starts the hooks", function()
    Ext.Events.SessionLoaded:Fire()
    AssertTrue(Contains("Level data: MaxXPLevel = 16, MaximumXPCap = 240000, Level12 = 30000, Level13 = 20000, "
        .. "Level14 = 25000, Level15 = 30000, Level16 = 35000."), "level data line")
    AssertTrue(not Contains("The level cap is"), "no warning")
    AssertTrue(Contains("Experience hooks ready (SessionLoaded)."), "hooks line")
    AssertEq(#Harness.SystemHooks.ServerExperience.Pre, 1, "one hook before the update")
    AssertEq(#Harness.SystemHooks.ServerExperience.Post, 1, "one hook after the update")
    AssertEq(#Harness.ComponentSubscriptions.Experience, 1, "one experience subscription")
end)

Test("a later LevelGameplayStarted does not hook twice", function()
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(#Harness.SystemHooks.ServerExperience.Pre, 1, "still one hook")
end)

Test("every pending gain is multiplied before the game adds it", function()
    system.IncreaseExperience[tav] = 100
    system.IncreaseExperience[gale] = 100
    Harness.RunSystemUpdate("ServerExperience", GameAddsPending)
    AssertEq(tav.Experience.TotalExperience, 1200, "Tav")
    AssertEq(gale.Experience.TotalExperience, 1200, "Gale")
    AssertTrue(Contains("Experience for Tav: 100 -> 200 (x2)."), "Tav line")
    AssertTrue(Contains("Experience for Gale: 100 -> 200 (x2)."), "Gale line")
end)

Test("a gain that stays in the map for another update is not multiplied again", function()
    system.IncreaseExperience[tav] = 50
    Harness.RunSystemUpdate("ServerExperience", nil)
    AssertEq(system.IncreaseExperience[tav], 100, "after the first update")
    Harness.RunSystemUpdate("ServerExperience", nil)
    AssertEq(system.IncreaseExperience[tav], 100, "after the second update")
    Harness.RunSystemUpdate("ServerExperience", GameAddsPending)
    AssertEq(tav.Experience.TotalExperience, 1300, "added once")
end)

Test("a new gain of the same amount after the game added the old one is multiplied", function()
    system.IncreaseExperience[tav] = 100
    Harness.RunSystemUpdate("ServerExperience", GameAddsPending)
    AssertEq(tav.Experience.TotalExperience, 1500, "first gain")
    system.IncreaseExperience[tav] = 200
    Harness.RunSystemUpdate("ServerExperience", GameAddsPending)
    AssertEq(tav.Experience.TotalExperience, 1900, "second gain, the same amount as the first result")
end)

Test("a changed setting counts for the next gain", function()
    Harness.FireMCMSettingSaved("xp_multiplier", 0.5)
    system.IncreaseExperience[gale] = 101
    Harness.RunSystemUpdate("ServerExperience", GameAddsPending)
    AssertEq(gale.Experience.TotalExperience, 1251, "half, rounded")
    AssertTrue(Contains("Experience for Gale: 101 -> 51 (x0.5)."), "line")
end)

Test("an error in the update is logged once and does not stop the game", function()
    local broken = setmetatable({}, { __pairs = function() error("map broken") end })
    Ext.System.ServerExperience = { IncreaseExperience = broken }
    Harness.RunSystemUpdate("ServerExperience", nil)
    Harness.RunSystemUpdate("ServerExperience", nil)
    Ext.System.ServerExperience = system
    local _, count = string.gsub(ServerLog(), "Could not scale the experience:[^\n]*map broken", "")
    AssertEq(count, 1, "one line")
end)

Test("the experience log reports party members only", function()
    Harness.FireComponentChange("Experience", tav)
    AssertTrue(Contains("Experience of Tav: 1900, level 3."), "first line")
    tav.Experience.TotalExperience = 2700
    tav.AvailableLevel.Level = 4
    Harness.FireComponentChange("Experience", tav)
    AssertTrue(Contains("Experience of Tav: 1900 -> 2700 (+800), level 3, can reach 4."), "change line")
    local before = ServerLog()
    Harness.FireComponentChange("Experience", tav)
    AssertEq(ServerLog(), before, "no line without a change")
    local npc = Harness.Character("Goblin", "33333333-3333-3333-3333-333333333333", { Party = false })
    Harness.FireComponentChange("Experience", npc)
    AssertTrue(not Contains("Goblin"), "no line for others")
end)
