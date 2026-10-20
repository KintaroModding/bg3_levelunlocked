-- Multiplies the experience that party members gain. The game has no event for a gain, and its experience system adds
-- the gains inside its own update (a hook before that update saw none in the game test of 2026-10-20). So the mod
-- watches the Experience component of the party members and corrects each gain afterwards with
-- Osi.AddExplorationExperience: the game adds the difference and checks the level-up itself.
--
-- The game gives a gain to every party member separately, and AddExplorationExperience gives only to the character it
-- names (game test of 2026-10-20). The mod corrects all members in the same tick, so the game's combat log shows one
-- line, "The party gained N experience". Then it waits until the corrections arrived before it reads new gains.
--
-- Below 1 the correction is negative. The game flags a level-up when experience is added and never checks again, so
-- the level state is rebuilt from the corrected total afterwards (AvailableLevel, CurrentLevelExperience, CanLevelUp).
-- These engine facts come from the tests that Path to Apotheosis published (docs/XP_CURVE.md, 2026-10-08).

local XPMultiplier = {}

XPMultiplier.MinFactor = 0.5
XPMultiplier.MaxFactor = 5.0
-- Ticks to collect the gains of one event: the game changes the party members one after the other.
XPMultiplier.CollectTicks = 2
-- Ticks between the corrections and the check that they arrived: the game applies AddExplorationExperience later.
XPMultiplier.SettleTicks = 10
-- How often the check waits again for a correction that has not arrived yet.
XPMultiplier.MaxWaits = 5

--- Returns the factor for a setting value: clamped to MinFactor..MaxFactor and rounded to two decimals (the MCM slider
--- sends values such as 4.098 while it is dragged). A value that is not a number gives 1.
function XPMultiplier.Factor(value)
    if type(value) ~= "number" or value ~= value then
        return 1
    end
    value = math.max(XPMultiplier.MinFactor, math.min(XPMultiplier.MaxFactor, value))
    return math.floor(value * 100 + 0.5) / 100
end

--- Returns the amount times the factor, rounded to a whole number. Amounts of 0 or less stay as they are.
function XPMultiplier.Scale(amount, factor)
    if type(amount) ~= "number" or amount <= 0 then
        return amount
    end
    return math.floor(amount * factor + 0.5)
end

--- Returns "1.5" for 1.5 and "2" for 2.0, for the log.
function XPMultiplier.FormatFactor(factor)
    local text = string.format("%.2f", factor)
    text = string.gsub(text, "0+$", "")
    return (string.gsub(text, "%.$", ""))
end

--- Returns the name of a character for the log, else its UUID.
function XPMultiplier.Name(entity)
    for _, field in ipairs({ "Name", "NameKey" }) do
        local ok, name = pcall(function() return entity.DisplayName[field]:Get() end)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    local ok, uuid = pcall(function() return entity.Uuid.EntityUuid end)
    if ok and uuid ~= nil then
        return tostring(uuid)
    end
    return tostring(entity)
end

--- Returns the total experience at which each level starts, from the XPData keys the game uses: starts[1] = 0 and
--- starts[L] = Level1 + ... + Level(L - 1), up to MaxXPLevel.
function XPMultiplier.LevelStarts()
    local data = Ext.Stats.GetStatsManager().ExtraData
    local max = math.floor(data.MaxXPLevel or 12)
    local starts = { 0 }
    for level = 2, max do
        starts[level] = starts[level - 1] + math.floor(data["Level" .. (level - 1)] or 0)
    end
    return starts
end

--- Returns the highest level whose start the total reaches.
function XPMultiplier.LevelForTotal(starts, total)
    local level = 1
    for candidate = 2, #starts do
        if total < starts[candidate] then
            break
        end
        level = candidate
    end
    return level
end

local started = false
local log = function() end
local getFactor = function() return 1 end
-- [uuid] = the total this character should have: its gains, the corrections for them included.
local expected = {}
-- [uuid] = gains not corrected yet.
local gains = {}
-- Ticks left before the gains are corrected; nil when none wait.
local collectTicks = nil
-- The corrections on their way: { Diffs = { [uuid] = n }, Ticks = n, Waits = n }. While it is set, the mod reads no
-- gains: the check at its end does.
local pending = nil
-- Characters whose level state must be rebuilt after a negative correction: { Uuids = { uuid, ... }, Ticks = n }.
local rebuild = nil

local function Uuid(entity)
    local ok, uuid = pcall(function() return entity.Uuid.EntityUuid end)
    if ok then
        return uuid
    end
    return nil
end

local function Entity(uuid)
    local ok, entity = pcall(Ext.Entity.Get, uuid)
    if ok and entity ~= nil and entity.Experience ~= nil then
        return entity
    end
    return nil
end

local function NameOf(uuid)
    local entity = Entity(uuid)
    return entity and XPMultiplier.Name(entity) or tostring(uuid)
end

local function AddExperience(uuid, amount)
    local ok, err = pcall(Osi.AddExplorationExperience, uuid, amount)
    if not ok then
        log("AddExplorationExperience failed for " .. NameOf(uuid) .. ": " .. tostring(err))
    end
    return ok
end

local function AddGain(uuid, amount)
    gains[uuid] = (gains[uuid] or 0) + amount
    collectTicks = collectTicks or XPMultiplier.CollectTicks
end

local function OnExperience(entity)
    if entity.PartyMember == nil or entity.Experience == nil then
        return
    end
    local uuid = Uuid(entity)
    if uuid == nil then
        return
    end
    local total = entity.Experience.TotalExperience
    if expected[uuid] == nil then
        expected[uuid] = total
        return
    end
    if pending ~= nil then
        return
    end
    local delta = total - expected[uuid]
    expected[uuid] = total
    if delta > 0 then
        AddGain(uuid, delta)
    end
end

--- Corrects the collected gains of every member in the same tick.
local function CorrectGains()
    local factor = XPMultiplier.Factor(getFactor())
    local uuids = {}
    for uuid in pairs(gains) do
        uuids[#uuids + 1] = uuid
    end
    table.sort(uuids)
    local parts = {}
    local diffs = {}
    local any = false
    for _, uuid in ipairs(uuids) do
        local gain = gains[uuid]
        local scaled = XPMultiplier.Scale(gain, factor)
        parts[#parts + 1] = string.format("%s %+d -> %+d", NameOf(uuid), gain, scaled)
        if scaled ~= gain and AddExperience(uuid, scaled - gain) then
            diffs[uuid] = scaled - gain
            expected[uuid] = expected[uuid] + diffs[uuid]
            any = true
        end
    end
    gains = {}
    log(string.format("Gain x%s: %s.", XPMultiplier.FormatFactor(factor), table.concat(parts, ", ")))
    if any then
        pending = { Diffs = diffs, Ticks = XPMultiplier.SettleTicks, Waits = 0 }
    end
end

--- Checks that the corrections arrived, then takes every other change since then as a new gain or loss.
local function CheckPending()
    local totals = {}
    local late = {}
    for uuid in pairs(expected) do
        local entity = Entity(uuid)
        if entity ~= nil then
            totals[uuid] = entity.Experience.TotalExperience
            local diff = pending.Diffs[uuid]
            if diff ~= nil and totals[uuid] - expected[uuid] == -diff then
                late[#late + 1] = uuid
            end
        end
    end
    if #late > 0 and pending.Waits < XPMultiplier.MaxWaits then
        pending.Waits = pending.Waits + 1
        pending.Ticks = XPMultiplier.SettleTicks
        return
    end
    for _, uuid in ipairs(late) do
        log("The correction for " .. NameOf(uuid) .. " did not arrive in time.")
    end
    local negative = {}
    for uuid, diff in pairs(pending.Diffs) do
        if diff < 0 then
            negative[#negative + 1] = uuid
        end
    end
    pending = nil
    for uuid, total in pairs(totals) do
        local delta = total - expected[uuid]
        expected[uuid] = total
        if delta > 0 then
            AddGain(uuid, delta)
        end
    end
    if #negative > 0 then
        table.sort(negative)
        rebuild = { Uuids = negative, Ticks = XPMultiplier.SettleTicks }
    end
end

--- Sets AvailableLevel, CurrentLevelExperience and CanLevelUp from the total, never below the character's level.
local function RebuildLevel(uuid)
    local entity = Entity(uuid)
    if entity == nil or entity.AvailableLevel == nil or entity.EocLevel == nil then
        return
    end
    local starts = XPMultiplier.LevelStarts()
    local total = entity.Experience.TotalExperience
    local level = entity.EocLevel.Level
    local earned = math.max(XPMultiplier.LevelForTotal(starts, total), level)
    if entity.AvailableLevel.Level ~= earned then
        entity.AvailableLevel.Level = earned
        entity:Replicate("AvailableLevel")
    end
    entity.Experience.CurrentLevelExperience = total - (starts[earned] or 0)
    entity:Replicate("Experience")
    if earned > level and entity.CanLevelUp == nil then
        entity:CreateComponent("CanLevelUp")
    elseif earned <= level and entity.CanLevelUp ~= nil then
        entity:RemoveComponent("CanLevelUp")
    end
    expected[uuid] = total
    log(string.format("Level state of %s: %d experience, level %d, can reach %d.", XPMultiplier.Name(entity), total,
        level, earned))
end

local function OnTick()
    if pending ~= nil then
        pending.Ticks = pending.Ticks - 1
        if pending.Ticks <= 0 then
            CheckPending()
        end
        return
    end
    if rebuild ~= nil then
        rebuild.Ticks = rebuild.Ticks - 1
        if rebuild.Ticks <= 0 then
            local uuids = rebuild.Uuids
            rebuild = nil
            for _, uuid in ipairs(uuids) do
                local ok, err = pcall(RebuildLevel, uuid)
                if not ok then
                    log("Could not rebuild the level state of " .. NameOf(uuid) .. ": " .. tostring(err))
                end
            end
        end
        return
    end
    if collectTicks ~= nil then
        collectTicks = collectTicks - 1
        if collectTicks <= 0 then
            collectTicks = nil
            CorrectGains()
        end
    end
end

--- Takes the current totals of the party members that the mod does not know yet as their starting point, so their
--- first gain counts too.
function XPMultiplier.ReadParty()
    for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("PartyMember")) do
        local uuid = Uuid(entity)
        if uuid ~= nil and entity.Experience ~= nil and expected[uuid] == nil then
            expected[uuid] = entity.Experience.TotalExperience
        end
    end
end

--- Starts the multiplier once per Lua state. getFactorFn() returns the setting value; logFn(message) writes a line.
--- Returns true, or false and the error.
function XPMultiplier.Start(getFactorFn, logFn)
    if started then
        return true
    end
    getFactor = getFactorFn
    log = logFn
    local ok, err = pcall(function()
        XPMultiplier.ReadParty()
        Ext.Entity.Subscribe("Experience", function(entity)
            local watchOk, watchErr = pcall(OnExperience, entity)
            if not watchOk then
                log("Could not read a gain: " .. tostring(watchErr))
            end
        end)
        -- A member who joins can get the party's experience at once: that is no gain to scale.
        Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
            local entity = Entity(character)
            local uuid = entity and Uuid(entity)
            if uuid ~= nil then
                expected[uuid] = entity.Experience.TotalExperience
            end
        end)
        local reported = {}
        Ext.Events.Tick:Subscribe(function()
            local tickOk, tickErr = pcall(OnTick)
            -- The tick runs every frame: report each error once.
            if not tickOk and not reported[tostring(tickErr)] then
                reported[tostring(tickErr)] = true
                log("Experience multiplier error: " .. tostring(tickErr))
            end
        end)
    end)
    if not ok then
        return false, err
    end
    started = true
    return true
end

return XPMultiplier
