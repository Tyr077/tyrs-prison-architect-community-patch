-- Fire Rate Observer: on every update, read ReloadTimer on every armed guard on the map. A rise
-- means the guard just fired and FireRangedShot stored a new value: the final game stores 2.0 for
-- every weapon, the weapon-firerate fix stores the 2018 values (0.7 shotgun and other single-shot
-- guns, 2.0 Tazer, 0.02 automatics). Polling sees the value a little after the store. Equipment is
-- the guard's main weapon, so a Tazer shot from a guard with a shotgun is counted under Shotgun; the
-- histogram (RT_<weapon>_b<tenths>) keeps the 0.7 and 2.0 shots apart.
--
-- Results go into this object's own fields (RT_<weapon>_max, RT_<weapon>_n), which the game writes
-- into the save's ScriptSystem block for the object. Game.DebugOut shows in the script debug window,
-- not in debug.txt.

local Last = {}

local function key(g)
    local ok, id = pcall(function() return g.Id.u end)
    if ok and id then return id end
    return tostring(g)
end

function Update(timePassed)
    local guards = this.GetNearbyObjects("ArmedGuard", 400)
    for g, _ in pairs(guards) do
        local ok, v = pcall(function() return g.ReloadTimer end)
        if ok and type(v) == "number" then
            local k = key(g)
            local prev = Last[k] or 0
            if v > prev + 0.001 then
                local okE, e = pcall(function() return g.Equipment end)
                local w = tostring(okE and e or "unknown")
                local mk = "RT_" .. w .. "_max"
                local nk = "RT_" .. w .. "_n"
                -- histogram in tenths of a second, rounded up: b7 = (0.6, 0.7], b20 = (1.9, 2.0]
                local bk = "RT_" .. w .. "_b" .. tostring(math.ceil(v * 10 - 0.0001))
                this[nk] = (this[nk] or 0) + 1
                this[bk] = (this[bk] or 0) + 1
                if v > (this[mk] or 0) then this[mk] = v end
                Game.DebugOut(string.format("FireRateObserver: guard %s weapon %s ReloadTimer %.3f", tostring(k), w, v))
            end
            Last[k] = v
        elseif not ok and not this.RT_error then
            this.RT_error = tostring(v)
            Game.DebugOut("FireRateObserver: cannot read ReloadTimer: " .. tostring(v))
        end
    end
end
