-- Status Effect Tester: every four game minutes, give every prisoner within five tiles the "tazed"
-- status effect through the Lua StatusEffects table, the Alpha 28 feature that the community patch
-- restores. The getter always reads the value back, patched or not; the visible test is whether the
-- prisoner actually drops and shows the tazed icon.

local Time  = Game.Time
local Delay = 4            -- Game.Time() units (game minutes) between pulses
local Ready = Time()

function Update()
    if Time() < Ready then return end
    Ready = Time() + Delay
    local prisoners = this.GetNearbyObjects("Prisoner", 5)
    for prisoner, distance in pairs(prisoners) do
        if prisoner.StatusEffects.tazed < 1 then
            prisoner.StatusEffects.tazed = 60
            Game.DebugOut("StatusEffectTester: set tazed=60, read back " .. tostring(prisoner.StatusEffects.tazed))
        end
    end
end
