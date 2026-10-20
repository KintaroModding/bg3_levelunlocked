-- MCM_blueprint.json and Settings.Defaults list the same settings with the same defaults. The runner reads the
-- blueprint into MCM_BLUEPRINT.

local Settings = Ext.Require("Shared/Settings.lua")

--- Returns every setting of the blueprint: at the root, in tabs and in sections.
local function BlueprintSettings()
    local found = {}
    local function Add(list)
        for _, setting in ipairs(list or {}) do
            found[#found + 1] = setting
        end
    end
    Add(MCM_BLUEPRINT.Settings)
    for _, tab in ipairs(MCM_BLUEPRINT.Tabs or {}) do
        Add(tab.Settings)
        for _, section in ipairs(tab.Sections or {}) do
            Add(section.Settings)
        end
    end
    return found
end

--- Compares two values; tables (for example color defaults) by their contents.
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not Same(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

Test("the blueprint exists and has settings", function()
    AssertTrue(MCM_BLUEPRINT ~= nil, "MCM_blueprint.json next to meta.lsx")
    AssertEq(MCM_BLUEPRINT.SchemaVersion, 1, "SchemaVersion")
    AssertTrue(#BlueprintSettings() > 0, "at least one setting")
end)

Test("every setting id in the blueprint is unique", function()
    local seen = {}
    for _, setting in ipairs(BlueprintSettings()) do
        AssertTrue(type(setting.Id) == "string" and setting.Id ~= "", "every setting has an Id")
        AssertTrue(not seen[setting.Id], "the id " .. setting.Id .. " is used twice")
        seen[setting.Id] = true
    end
end)

Test("every blueprint setting has its default in Settings.Defaults", function()
    for _, setting in ipairs(BlueprintSettings()) do
        -- An event button is a button only: it has no value.
        if setting.Type ~= "event_button" then
            AssertTrue(Settings.Defaults[setting.Id] ~= nil, setting.Id .. " is missing in Settings.Defaults")
            AssertTrue(Same(Settings.Defaults[setting.Id], setting.Default),
                setting.Id .. ": Settings.Defaults differs from the blueprint's Default")
        end
    end
end)

Test("every id in Settings.Defaults is in the blueprint", function()
    local ids = {}
    for _, setting in ipairs(BlueprintSettings()) do
        ids[setting.Id] = true
    end
    for id in pairs(Settings.Defaults) do
        AssertTrue(ids[id], id .. " is in Settings.Defaults but not in MCM_blueprint.json")
    end
end)
