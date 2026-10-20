-- Without the Mod Configuration Menu (missing, or loaded after this mod): the defaults apply, and nothing fails.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }

Ext.Require("BootstrapServer.lua")
Ext.Require("BootstrapClient.lua")
local Settings = Ext.Require("Shared/Settings.lua")

Test("without MCM the defaults apply", function()
    AssertEq(MCM, nil, "no MCM table")
    for id, default in pairs(Settings.Defaults) do
        local value, source = Settings.Get(id)
        AssertEq(value, default, id)
        AssertEq(source, "default", id .. " source")
    end
end)

Test("the session load logs the defaults", function()
    Ext.Events.SessionLoaded:Fire()
    Harness.RunTimers()
    AssertTrue(string.find(Harness.Files["bg3_levelunlocked/server.log"] or "", "Settings: xp_multiplier = 1.0 (default).",
        1, true), "server.log line")
end)

Test("OnChange reports that no change can come", function()
    AssertEq(Settings.OnChange(function() end), false, "no subscription")
end)
