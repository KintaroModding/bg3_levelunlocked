-- The experience multiplier corrects each gain of the party after the game added it: every member in the same tick,
-- with one AddExplorationExperience call each. The experience log reports every change of a party member's
-- experience.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
Harness.InstallMCM({ xp_multiplier = 5.0 })
Harness.ExtraData = { MaxXPLevel = 16, MaximumXPCap = 240000, Level1 = 300, Level2 = 600, Level3 = 1800,
    Level4 = 3800, Level5 = 6500, Level6 = 8000, Level7 = 9000, Level8 = 12000, Level9 = 14000, Level10 = 20000,
    Level11 = 24000, Level12 = 30000, Level13 = 20000, Level14 = 25000, Level15 = 30000, Level16 = 35000 }

-- The party of the first game test (2026-10-20).
local urge = Harness.Character("Dark_Urge", "11111111-1111-1111-1111-111111111111", { Experience = 2693 })
local shadowheart = Harness.Character("Shadowheart", "22222222-2222-2222-2222-222222222222", { Experience = 2673 })
local astarion = Harness.Character("Astarion", "33333333-3333-3333-3333-333333333333", { Experience = 2628 })
local gale = Harness.Character("Gale", "44444444-4444-4444-4444-444444444444", { Experience = 2693 })

Ext.Require("BootstrapServer.lua")
local XPMultiplier = Ext.Require("Server/XPMultiplier.lua")

local function ServerLog()
    Harness.RunTimers()
    return Harness.Files["bg3_levelunlocked/server.log"] or ""
end

local function Contains(text)
    return string.find(ServerLog(), text, 1, true) ~= nil
end

local function Totals()
    return { urge.Experience.TotalExperience, shadowheart.Experience.TotalExperience,
        astarion.Experience.TotalExperience, gale.Experience.TotalExperience }
end

local function AssertTotals(expected, message)
    local actual = Totals()
    for index = 1, 4 do
        AssertEq(actual[index], expected[index], message .. " (member " .. index .. ")")
    end
end

local function CallCount()
    return #Harness.ExperienceCalls
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
    AssertEq(math.type(XPMultiplier.Scale(33, 0.5)), "integer", "an integer for Osiris")
    AssertEq(XPMultiplier.Scale(0, 2), 0, "zero")
    AssertEq(XPMultiplier.Scale(-5, 2), -5, "negative")
end)

Test("LevelStarts follows the XPData keys up to the cap", function()
    local starts = XPMultiplier.LevelStarts()
    AssertEq(#starts, 16, "16 levels")
    AssertEq(starts[4], 2700, "level 4")
    AssertEq(starts[12], 100000, "level 12")
    AssertEq(starts[13], 130000, "level 13")
    AssertEq(starts[16], 205000, "level 16")
    AssertEq(XPMultiplier.LevelForTotal(starts, 204999), 15, "just below 16")
    AssertEq(XPMultiplier.LevelForTotal(starts, 999999), 16, "the cap")
end)

Test("the session load logs the level data and starts the hooks", function()
    Ext.Events.SessionLoaded:Fire()
    AssertTrue(Contains("Settings: xp_multiplier = 5 (MCM)."), "settings line without '5.'")
    AssertTrue(Contains("Level data: MaxXPLevel = 16, MaximumXPCap = 240000, Level12 = 30000, Level13 = 20000, "
        .. "Level14 = 25000, Level15 = 30000, Level16 = 35000."), "level data line")
    AssertTrue(not Contains("The level cap is"), "no warning")
    AssertTrue(Contains("Experience hooks ready (SessionLoaded)."), "hooks line")
    AssertEq(#Harness.ComponentSubscriptions.Experience, 2, "the multiplier and the log")
end)

Test("a later LevelGameplayStarted does not hook twice", function()
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(#Harness.ComponentSubscriptions.Experience, 2, "still two subscriptions")
end)

Test("x5: every member gets the difference, all in the same tick", function()
    Harness.PartyGain(20)
    Harness.RunTicks(20)
    AssertTotals({ 2793, 2773, 2728, 2793 }, "every member +100")
    AssertEq(CallCount(), 4, "one call per member")
    for _, call in ipairs(Harness.ExperienceCalls) do
        AssertEq(call.Amount, 80, "the difference")
        AssertEq(call.Tick, Harness.ExperienceCalls[1].Tick, "the same tick, so the game shows one line")
    end
    AssertTrue(Contains("Gain x5: Dark_Urge +20 -> +100, Shadowheart +20 -> +100, Astarion +20 -> +100, "
        .. "Gale +20 -> +100."), "gain line")
    AssertTrue(Contains("Experience of Gale: 2713, level 3, can reach 4."), "the log's first look, after the game's gain")
    AssertTrue(Contains("Experience of Gale: 2713 -> 2793 (+80)"), "the correction in the log")
end)

Test("a second gain of the game is multiplied too", function()
    Harness.PartyGain(10)
    Harness.RunTicks(30)
    AssertTotals({ 2843, 2823, 2778, 2843 }, "every member +50")
    AssertEq(CallCount(), 8, "four more calls")
end)

Test("nothing more happens without a gain", function()
    local before = CallCount()
    Harness.RunTicks(30)
    AssertEq(CallCount(), before, "no call")
    AssertTotals({ 2843, 2823, 2778, 2843 }, "no change")
end)

Test("a gain while the corrections are on their way is multiplied too", function()
    Harness.PartyGain(10)
    Harness.RunTicks(4)
    Harness.PartyGain(10)
    Harness.RunTicks(40)
    AssertTotals({ 2943, 2923, 2878, 2943 }, "every member +100")
end)

Test("a changed setting counts for the next gain", function()
    Harness.FireMCMSettingSaved("xp_multiplier", 1.5)
    Harness.PartyGain(100)
    Harness.RunTicks(20)
    AssertTotals({ 3093, 3073, 3028, 3093 }, "every member +150")
    AssertTrue(Contains("Setting changed (xp_multiplier): xp_multiplier = 1.5 (MCM)."), "setting line")
end)

Test("at x1 the gains stay as they are", function()
    Harness.FireMCMSettingSaved("xp_multiplier", 1.0)
    local before = CallCount()
    Harness.PartyGain(30)
    Harness.RunTicks(20)
    AssertTotals({ 3123, 3103, 3058, 3123 }, "every member +30")
    AssertEq(CallCount(), before, "no call")
    AssertTrue(Contains("Gain x1: Dark_Urge +30 -> +30"), "gain line")
end)

Test("a member who joins with the party's experience is not multiplied", function()
    Harness.FireMCMSettingSaved("xp_multiplier", 2.0)
    local karlach = Harness.Character("Karlach", "55555555-5555-5555-5555-555555555555", { Experience = 900 })
    Harness.FireComponentChange("Experience", karlach)
    karlach.Experience.TotalExperience = 3123
    Harness.Listeners["CharacterJoinedParty/1"](karlach.Uuid.EntityUuid)
    Harness.FireComponentChange("Experience", karlach)
    local before = CallCount()
    Harness.RunTicks(20)
    AssertEq(CallCount(), before, "no call")
    AssertEq(karlach.Experience.TotalExperience, 3123, "unchanged")
end)

Test("a correction that arrives late is waited for and not multiplied again", function()
    Harness.FireMCMSettingSaved("xp_multiplier", 2.0)
    Harness.ExperienceDelay = 25
    Harness.PartyGain(10)
    Harness.RunTicks(60)
    Harness.ExperienceDelay = 1
    AssertTotals({ 3143, 3123, 3078, 3143 }, "every member +20")
    AssertTrue(not Contains("did not arrive in time"), "no late line")
end)

Test("a correction that never arrives is logged", function()
    Harness.ExperienceDelay = 1000
    Harness.PartyGain(10)
    Harness.RunTicks(100)
    Harness.ExperienceDelay = 1
    AssertTrue(Contains("The correction for Dark_Urge did not arrive in time."), "late line")
    AssertTotals({ 3153, 3133, 3088, 3153 }, "only the game's gain so far")
end)

Test("a failing AddExplorationExperience is logged and stops nothing", function()
    local original = Osi.AddExplorationExperience
    Osi.AddExplorationExperience = function() error("not now") end
    Harness.PartyGain(10)
    Harness.RunTicks(20)
    Osi.AddExplorationExperience = original
    AssertTrue(Contains("AddExplorationExperience failed for Dark_Urge: "), "error line")
    Harness.PartyGain(10)
    Harness.RunTicks(20)
    AssertEq(urge.Experience.TotalExperience, 3153 + 10 + 20, "the next gain works")
end)
