-- Door Test Controller: spawns NPCs of the types below at (FromX, FromY), keeps sending them to
-- (ToX, ToY) on the other side of a door with Object.NavigateTo, and records per type how many were
-- spawned, how many arrived (within 1.5 tiles of the target) and how close the closest one got.
--
-- The in-game test (tools/ingame-test/tests/visitor-door-access.ps1) writes a copy of this file with
-- the settings filled in. Results go into this object's own fields, which the game saves in the
-- object's ScriptSystem block: Spawned_<type>, Arrived_<type>, Closest_<type>.

-- BEGIN CONFIG
local Types = { "Workman", "Repairman" }
local PerType = 2
local FromX, FromY = 0.5, 0.5
local ToX, ToY = 0.5, 0.5
local RenavEvery = 10
-- END CONFIG

local Timer = 0
local Npcs = {}   -- { name = <spawn result>, type = <type>, arrived = bool }

local function get(f)
    local ok, v = pcall(f)
    if ok then return v end
    return nil
end

local function pos(n)
    local x = get(function() return n.Pos.x end) or get(function() return Object.GetProperty(n, "Pos.x") end)
    local y = get(function() return n.Pos.y end) or get(function() return Object.GetProperty(n, "Pos.y") end)
    return tonumber(x), tonumber(y)
end

local function send(n)
    pcall(function() Object.NavigateTo(n, ToX, ToY) end)
end

local function spawnAll()
    if this.Started then return end
    this.Started = true
    for _, t in ipairs(Types) do
        local made = 0
        for i = 1, PerType do
            local n = get(function() return Object.Spawn(t, FromX, FromY) end)
            if n ~= nil then
                made = made + 1
                table.insert(Npcs, { name = n, type = t, arrived = false })
                send(n)
            end
        end
        this["Spawned_" .. t] = made
        this["Arrived_" .. t] = 0
    end
end

function Update(timePassed)
    Timer = Timer + timePassed
    if Timer < 2 then return end
    Timer = 0
    spawnAll()
    this.Polls = (this.Polls or 0) + 1
    for _, npc in ipairs(Npcs) do
        if not npc.arrived then
            local x, y = pos(npc.name)
            if x ~= nil then
                local d = math.sqrt((x - ToX) ^ 2 + (y - ToY) ^ 2)
                local ck = "Closest_" .. npc.type
                if this[ck] == nil or d < this[ck] then this[ck] = d end
                if d <= 1.5 then
                    npc.arrived = true
                    this["Arrived_" .. npc.type] = (this["Arrived_" .. npc.type] or 0) + 1
                elseif this.Polls % RenavEvery == 0 then
                    send(npc.name)
                end
            end
        end
    end
end
