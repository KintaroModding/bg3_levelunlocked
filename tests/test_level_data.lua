-- The stats files and the progression rows fit together: the cap in XPData.txt, the experience cap in Data.txt, the
-- level the Lua side checks, and one row per class table for every level from 13 to the cap.

local LevelCap = Ext.Require("Server/LevelCap.lua")

local SRC_PUBLIC = MOD_LUA_ROOT .. "/../../../../Public/bg3_levelunlocked"
local VANILLA_LEVELS = { 300, 600, 1800, 3800, 6500, 8000, 9000, 12000, 14000, 20000, 24000, 30000 }
local FIRST_NEW_LEVEL = 13

-- The class tables of the game (Name -> TableUUID), and the multiclass spell slot table.
local CLASS_TABLES = {
    Barbarian = "60bbcc97-5381-4898-bc15-908c072895de",
    Bard = "229c98da-2cd1-4a5e-8051-9d90ec7931e7",
    Cleric = "64474b62-b4f5-46b3-b94a-c676c6da3116",
    Druid = "6e7b7bad-e122-4679-8b3c-8f8987a9d466",
    Fighter = "ba4e707e-4bbd-4630-963b-ce2f2947f971",
    Monk = "fe1319a2-86be-469c-aab5-e3b0bd714e0e",
    Paladin = "ba2afe85-acba-4ea1-a238-2b4543f47821",
    Ranger = "8f068974-ed32-43fc-a9d9-028be1c01a9c",
    Rogue = "9a44e828-92db-4d6c-acbc-a4f8ef340415",
    Sorcerer = "e2416b02-953a-4ce8-aa8f-eb98d549d86d",
    Warlock = "a7a958f1-d858-4021-9fa7-cf87e7d71377",
    Wizard = "d18eda7e-4b7d-490d-9952-cd33a3c60479",
}
local MULTICLASS_TABLE = "a6f80028-fee2-41e0-bd24-d2f0758d936f"

--- Returns the key "<name>","<value>" lines of a stats data file as a table.
local function ReadKeys(file)
    local text = READ_FILE(SRC_PUBLIC .. "/Stats/Generated/Data/" .. file)
    assert(text, file .. " is missing")
    local keys = {}
    for key, value in string.gmatch(text, 'key "([^"]+)","([^"]*)"') do
        assert(keys[key] == nil, file .. ": " .. key .. " twice")
        keys[key] = tonumber(value)
    end
    return keys
end

--- Returns the Progression nodes of Progressions.lsx: { [attribute id] = value }.
local function ReadRows()
    local text = READ_FILE(SRC_PUBLIC .. "/Progressions/Progressions.lsx")
    assert(text, "Progressions.lsx is missing")
    local rows = {}
    for body in string.gmatch(text, '<node id="Progression">(.-)</node>') do
        local row = {}
        for id, value in string.gmatch(body, '<attribute id="([^"]+)" type="[^"]+" value="([^"]*)"/>') do
            row[id] = value
        end
        rows[#rows + 1] = row
    end
    return rows
end

local xpData = ReadKeys("XPData.txt")
local data = ReadKeys("Data.txt")

Test("XPData.txt sets the cap that the Lua side checks", function()
    AssertEq(xpData.MaxXPLevel, LevelCap.MaxLevel, "MaxXPLevel")
end)

Test("XPData.txt has the experience for every new level, up to the bar at the cap", function()
    for level = FIRST_NEW_LEVEL, LevelCap.MaxLevel do
        AssertTrue(type(xpData["Level" .. level]) == "number" and xpData["Level" .. level] > 0, "Level" .. level)
    end
    AssertEq(xpData["Level" .. (LevelCap.MaxLevel + 1)], nil, "nothing above the cap")
    AssertEq(xpData.Level12, nil, "the game's own levels stay as they are")
end)

Test("MaximumXPCap lets the bar at the cap fill", function()
    local total = 0
    for _, amount in ipairs(VANILLA_LEVELS) do
        total = total + amount
    end
    for level = FIRST_NEW_LEVEL, LevelCap.MaxLevel do
        total = total + xpData["Level" .. level]
    end
    AssertEq(data.MaximumXPCap, total, "MaximumXPCap")
end)

Test("every class table has one row per new level, with a feat at 16 only", function()
    local seen = {}
    for _, row in ipairs(ReadRows()) do
        local table = row.TableUUID
        local level = tonumber(row.Level)
        if table ~= MULTICLASS_TABLE then
            AssertEq(CLASS_TABLES[row.Name], table, "TableUUID of " .. tostring(row.Name))
            AssertEq(row.AllowImprovement, level == 16 and "true" or nil, row.Name .. " " .. level .. " feat")
        end
        AssertEq(row.ProgressionType, "0", "ProgressionType")
        AssertTrue(level >= FIRST_NEW_LEVEL and level <= LevelCap.MaxLevel, "level " .. tostring(level))
        local key = table .. ":" .. level
        AssertTrue(not seen[key], "two rows for " .. key)
        seen[key] = true
    end
    local all = { MULTICLASS_TABLE }
    for _, table in pairs(CLASS_TABLES) do
        all[#all + 1] = table
    end
    for _, table in ipairs(all) do
        for level = FIRST_NEW_LEVEL, LevelCap.MaxLevel do
            AssertTrue(seen[table .. ":" .. level], "missing row " .. table .. ":" .. level)
        end
    end
end)

Test("the rows add no boosts, passives or selectors and have unique UUIDs", function()
    local uuids = {}
    for _, row in ipairs(ReadRows()) do
        AssertEq(row.Boosts, nil, "Boosts")
        AssertEq(row.PassivesAdded, nil, "PassivesAdded")
        AssertEq(row.Selectors, nil, "Selectors")
        AssertTrue(row.UUID ~= nil and not uuids[row.UUID], "UUID " .. tostring(row.UUID))
        uuids[row.UUID] = true
    end
end)
