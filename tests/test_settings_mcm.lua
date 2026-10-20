-- With the Mod Configuration Menu: the settings come from MCM, and every change of this mod's settings reaches
-- Settings.OnChange. Both bootstrap files run in one Lua state, as on the host.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
-- MCM loads before this mod (the dependency in meta.lsx), so this mod gets the MCM table.
Harness.InstallMCM({ xp_multiplier = 1.5 })

Ext.Require("BootstrapServer.lua")
Ext.Require("BootstrapClient.lua")
local Settings = Ext.Require("Shared/Settings.lua")

local changes = {}
local subscribed = Settings.OnChange(function(settingId)
    changes[#changes + 1] = settingId or "profile"
end)

local function ServerLog()
    Harness.RunTimers()
    return Harness.Files["bg3_levelunlocked/server.log"] or ""
end

Test("the session load logs the values from MCM", function()
    Ext.Events.SessionLoaded:Fire()
    AssertTrue(string.find(ServerLog(), "Settings: xp_multiplier = 1.5 (MCM).", 1, true), "server.log line")
end)

Test("a saved setting of this mod reaches OnChange with its id", function()
    AssertEq(subscribed, true, "OnChange subscribed")
    Harness.FireMCMSettingSaved("xp_multiplier", 2.0)
    AssertEq(changes[#changes], "xp_multiplier", "setting id")
    AssertEq(Settings.Get("xp_multiplier"), 2.0, "new value")
    AssertTrue(string.find(ServerLog(), "Setting changed (xp_multiplier): xp_multiplier = 2 (MCM).", 1, true),
        "server.log line")
end)

Test("settings of other mods are ignored", function()
    local count = #changes
    Harness.FireMCMSettingSaved("xp_multiplier", 3.0, "00000000-0000-0000-0000-000000000000")
    AssertEq(#changes, count, "no call")
    AssertEq(Settings.Get("xp_multiplier"), 2.0, "value unchanged")
end)

Test("a profile switch reaches OnChange without an id", function()
    Harness.MCMValues.xp_multiplier = 0.5
    Ext.ModEvents.BG3MCM["MCM_Profile_Activated"]:Fire({ profileName = "Other" })
    AssertEq(changes[#changes], "profile", "call without id")
    AssertTrue(string.find(ServerLog(), "MCM profile changed: xp_multiplier = 0.5 (MCM).", 1, true),
        "server.log line")
end)

Test("an MCM error or a value of the wrong type gives the default", function()
    local original = MCM.Get
    MCM.Get = function() error("broken") end
    local value, source = Settings.Get("xp_multiplier")
    AssertEq(value, Settings.Defaults.xp_multiplier, "default after an error")
    AssertEq(source, "default", "source after an error")
    MCM.Get = function() return "yes" end
    value, source = Settings.Get("xp_multiplier")
    MCM.Get = original
    AssertEq(value, Settings.Defaults.xp_multiplier, "default for a wrong type")
    AssertEq(source, "default", "source for a wrong type")
end)

Test("an unknown setting id is an error", function()
    local ok, message = pcall(Settings.Get, "no_such_setting")
    AssertEq(ok, false, "error")
    AssertTrue(string.find(tostring(message), "unknown setting no_such_setting", 1, true), "message")
end)
