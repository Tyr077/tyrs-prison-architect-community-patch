-- PC Test Controller: puts Protective Custody prisoners into a running prison with
-- Object.SetProperty(prisoner, "Category", 4), and watches who gets work.
--
-- The in-game test (tools/ingame-test/tests/pc-shared-zones.ps1) writes a copy of this file with
-- the settings below filled in. Everything the script finds is kept in this object's own fields, which
-- the game saves in the object's ScriptSystem block; Game.DebugOut only reaches the script debug window.
--
--   ConvertFrom   category name converted to Protective Custody at the first update ("" = none)
--   Spawn         number of new prisoners spawned at the first update, next to an existing prisoner,
--                 then made Protective Custody
--   ToggleCount   number of MinSec prisoners (odd Id.i, in scan order) switched to Protective Custody
--                 once Game.Time() has advanced by ToggleAfter from its first reading (0 = no toggle)
--   SnapEvery     polls between timeline snapshots

-- BEGIN CONFIG
local ConvertFrom = "SuperMax"
local Spawn = 0
local ToggleCount = 0
local ToggleAfter = 0
local SnapEvery = 15
-- END CONFIG

local Timer = 0

local function get(f)
    local ok, v = pcall(f)
    if ok then return v end
    return nil
end

local function now()
    return tonumber(get(function() return Game.Time() end)) or 0
end

local function prisoners()
    return this.GetNearbyObjects("Prisoner", 400)
end

local function setProtected(p)
    local ok = pcall(function() Object.SetProperty(p, "Category", 4) end)
    return ok
end

local function firstActions()
    if this.Started then return end
    this.Started = true
    this.GT0 = now()
    local converted, anchor = 0, nil
    for p, _ in pairs(prisoners()) do
        local cat = tostring(get(function() return p.Category end))
        if ConvertFrom ~= "" and cat == ConvertFrom then
            if setProtected(p) then converted = converted + 1 end
        elseif cat == "MinSec" and anchor == nil then
            anchor = p
        end
    end
    this.Converted = converted
    if Spawn > 0 and anchor ~= nil then
        local x = get(function() return anchor.Pos.x end)
        local y = get(function() return anchor.Pos.y end)
        local made = 0
        for i = 1, Spawn do
            local name = get(function() return Object.Spawn("Prisoner", x, y) end)
            if name ~= nil then
                if setProtected(name) then made = made + 1 end
                local idu = get(function() return Object.GetProperty(name, "Id.u") end)
                if idu ~= nil then this["Spawned_" .. made] = idu end
            end
        end
        this.Spawned = made
        this.SpawnX = x
        this.SpawnY = y
    end
end

local function toggle()
    if ToggleCount <= 0 or this.Toggled then return end
    if now() - (this.GT0 or 0) < ToggleAfter then return end
    this.Toggled = 0
    this.ToggleGT = now()
    for p, _ in pairs(prisoners()) do
        if this.Toggled >= ToggleCount then break end
        local cat = tostring(get(function() return p.Category end))
        local idi = get(function() return p.Id.i end)
        if cat == "MinSec" and type(idi) == "number" and idi % 2 == 1 then
            if setProtected(p) then
                this.Toggled = this.Toggled + 1
                this["Toggled_" .. this.Toggled] = get(function() return p.Id.u end)
            end
        end
    end
end

local function observe()
    local n, s, j = {}, {}, {}
    for p, _ in pairs(prisoners()) do
        local cat = tostring(get(function() return p.Category end) or "unknown")
        n[cat] = (n[cat] or 0) + 1
        local st = get(function() return p.Station.i end)
        if type(st) == "number" and st ~= -1 then s[cat] = (s[cat] or 0) + 1 end
        local job = get(function() return p.JobId end)
        if type(job) == "number" and job ~= -1 then j[cat] = (j[cat] or 0) + 1 end
    end
    this.Polls = (this.Polls or 0) + 1
    this.GTLast = now()
    for cat, c in pairs(n) do
        if c > (this["N_" .. cat] or 0) then this["N_" .. cat] = c end
        if (s[cat] or 0) > (this["S_" .. cat] or 0) then this["S_" .. cat] = s[cat] end
        if (j[cat] or 0) > (this["J_" .. cat] or 0) then this["J_" .. cat] = j[cat] end
    end
    if this.Polls % SnapEvery == 0 then
        local k = "T" .. tostring(math.floor(this.Polls / SnapEvery))
        this[k .. "_GT"] = this.GTLast
        for cat, c in pairs(n) do
            this[k .. "_" .. cat] = tostring(j[cat] or 0) .. "/" .. tostring(s[cat] or 0) .. "/" .. tostring(c)
        end
    end
end

function Update(timePassed)
    Timer = Timer + timePassed
    if Timer < 2 then return end
    Timer = 0
    firstActions()
    toggle()
    observe()
end
