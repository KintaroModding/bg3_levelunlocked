-- Below 1 the correction takes experience back. The game flagged the level-up for the full gain, so the mod rebuilds
-- the level state from the corrected total: AvailableLevel, CurrentLevelExperience and CanLevelUp.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
Harness.InstallMCM({ xp_multiplier = 0.5 })
Harness.ExtraData = { MaxXPLevel = 16, Level1 = 300, Level2 = 600, Level3 = 1800, Level4 = 3800 }

-- Level 4 starts at 2700.
local tav = Harness.Character("Tav", "11111111-1111-1111-1111-111111111111", { Experience = 2600 })
local karlach = Harness.Character("Karlach", "22222222-2222-2222-2222-222222222222", { Experience = 2600 })

Ext.Require("BootstrapServer.lua")
Ext.Events.SessionLoaded:Fire()

local function ServerLog()
    Harness.RunTimers()
    return Harness.Files["bg3_levelunlocked/server.log"] or ""
end

Test("half a gain that would cross a level does not give the level-up", function()
    Harness.PartyGain(150)
    AssertEq(tav.AvailableLevel.Level, 4, "the game flags level 4 for the full gain")
    Harness.RunTicks(40)
    for _, member in ipairs({ tav, karlach }) do
        AssertEq(member.Experience.TotalExperience, 2675, "half the gain")
        AssertEq(member.AvailableLevel.Level, 3, "no level 4")
        AssertEq(member.CanLevelUp, nil, "no level-up")
        AssertEq(member.Experience.CurrentLevelExperience, 2675 - 900, "progress in level 3")
    end
    AssertTrue(string.find(ServerLog(), "Level state of Tav: 2675 experience, level 3, can reach 3.", 1, true),
        "log line")
end)

Test("half a gain that still reaches the level keeps the level-up", function()
    Harness.PartyGain(50)
    Harness.RunTicks(40)
    for _, member in ipairs({ tav, karlach }) do
        AssertEq(member.Experience.TotalExperience, 2700, "half the gain")
        AssertEq(member.AvailableLevel.Level, 4, "level 4 reached")
        AssertTrue(member.CanLevelUp ~= nil, "level-up")
        AssertEq(member.Experience.CurrentLevelExperience, 0, "level 4 just started")
    end
end)

Test("the rebuild never goes below the level a character has", function()
    tav.EocLevel.Level = 4
    tav.CanLevelUp = nil
    Harness.PartyGain(10)
    Harness.RunTicks(40)
    AssertEq(tav.Experience.TotalExperience, 2705, "half the gain")
    AssertEq(tav.AvailableLevel.Level, 4, "level 4")
    AssertEq(tav.CanLevelUp, nil, "no level-up")
end)
