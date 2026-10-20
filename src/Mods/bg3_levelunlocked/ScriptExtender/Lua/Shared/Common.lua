-- Values and helpers shared by the server and client contexts.

local Common = {}

--- Returns the version of this mod from its meta.lsx, for example "1.0.0.0".
function Common.ModVersion()
    local ok, version = pcall(function() return Ext.Mod.GetMod(ModuleUUID).Info.ModVersion end)
    if not ok or version == nil then
        return "?"
    end
    return table.concat({ tostring(version[1]), tostring(version[2]), tostring(version[3]), tostring(version[4]) }, ".")
end

return Common
