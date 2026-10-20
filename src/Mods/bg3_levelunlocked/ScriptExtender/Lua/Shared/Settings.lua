-- Player settings from the Mod Configuration Menu (MCM). Every access is guarded: without MCM, or when MCM loaded
-- after this mod, the defaults below apply. MCM puts the global MCM table into this mod only when MCM loads first (the
-- dependency in meta.lsx makes the mod managers sort it first) and the mod has MCM_blueprint.json.

local Settings = {}

-- UUID of the Mod Configuration Menu (folder BG3MCM).
Settings.MCMModuleUUID = "755a8a72-407f-4f0d-9a33-274ac0f0b53d"

-- Every setting of MCM_blueprint.json with its "Default" there: the values without MCM. The tests check that both
-- lists match. The ids are part of the players' saved settings: never rename one after a release.
Settings.Defaults = {
    xp_multiplier = 1.0,
}

--- Returns the value of a setting and where it came from: "MCM", or "default" when MCM is missing, fails, or has no
--- value of the default's type. An id that is not in Settings.Defaults is an error.
function Settings.Get(id)
    local default = Settings.Defaults[id]
    if default == nil then
        error("Settings.Get: unknown setting " .. tostring(id), 2)
    end
    if MCM ~= nil then
        local ok, value = pcall(MCM.Get, id)
        if ok and value ~= nil and type(value) == type(default) then
            return value, "MCM"
        end
    end
    return default, "default"
end

--- Returns every setting with its value and source, sorted by id, for the log: "xp_multiplier = 1.5 (MCM)".
function Settings.Describe()
    local ids = {}
    for id in pairs(Settings.Defaults) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local parts = {}
    for _, id in ipairs(ids) do
        local value, source = Settings.Get(id)
        -- %g: 5 and 1.5, not the "5." that the Script Extender's tostring gives for 5.0.
        local text = type(value) == "number" and string.format("%g", value) or tostring(value)
        parts[#parts + 1] = id .. " = " .. text .. " (" .. source .. ")"
    end
    return table.concat(parts, ", ")
end

--- Calls fn(settingId) after the player saves a setting of this mod in MCM (a reset too), and fn(nil) after a switch
--- of the MCM profile, which can change every value at once. Returns false when MCM is not loaded: then the values
--- stay the same for the whole session.
function Settings.OnChange(fn)
    if not (Ext.Mod.IsModLoaded(Settings.MCMModuleUUID) and Ext.ModEvents and Ext.ModEvents.BG3MCM) then
        return false
    end
    local events = Ext.ModEvents.BG3MCM
    events["MCM_Setting_Saved"]:Subscribe(function(payload)
        if type(payload) == "table" and payload.modUUID == ModuleUUID then
            fn(payload.settingId)
        end
    end)
    events["MCM_Profile_Activated"]:Subscribe(function()
        fn(nil)
    end)
    return true
end

return Settings
