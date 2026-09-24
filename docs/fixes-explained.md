# Fixes explained

The long version of the fix list on the front page: what each bug looked like in
a prison, why it happened, and what the fix changes, without the assembly. The
per-fix technical notes elsewhere in `docs/` have the addresses and bytes.

## Bug fixes

### Gang contraband hand-off (Gangs DLC)

Symptoms: a gang member gets the contraband hand-off icon and then paces around
at speed, ignores the regime, and every guard sent to search or escort him
drops the job immediately. Related: a crooked guard who stops doing anything at
all, and hand-offs never happening again after you fire a crooked guard.

Cause: the hand-off misbehaviour state has no exit on the prisoner side, and
the crooked guard's routine that is supposed to end it gives up on a regime
change, a gang member who no longer exists, or a guard who was fired or
killed. Nothing ever clears those, so prisoners are stranded permanently.

Fix: the prisoner now checks each tick that the hand-off is still valid (he is
the chosen gang member, the guard still exists, the regime allows it) and
clears himself if not. The guard routine clears stale gang members and aborts
cleanly on regime changes. The system re-picks a guard when the old one is
gone. Crooked guards, bribes and hand-offs keep working.

### Ranged weapon fire rate

Symptoms: assault rifles and SMGs fire one shot every two seconds, the same as
a sniper rifle, so armed guards with automatic weapons are close to useless.

Cause: after every ranged shot the game starts a two-second "reload" timer and
refuses to count the weapon's real recharge time until it expires. There is no
magazine or burst logic behind it; the two seconds are simply added to every
shot by everyone. Community Lua mods work around it by zeroing the timer every
tick on guards, which is expensive and cannot be applied to prisoners without
breaking Escape Mode.

Fix: the 2018 version of the game has the same timer, but with three values
instead of one: 0.02 s for assault rifles and SMGs, 2 s for the Tazer and 0.7 s
for every other weapon. The final version kept only the Tazer's and applies it
to everything. The fix puts the three values back, so a guard or prisoner fires
at the wait above plus the weapon's `RechargeTime` from `materials.txt`: a
revolver every 1.2 s, a shotgun every 1.7 s, an assault rifle about eight times
a second. Shell casings and the shotgun pump sound come when the timer runs
out, as before. Earlier versions of this fix removed the wait altogether, which
made pistols, shotguns and rifles fire faster than they ever had; version 2.0.0
goes back to what the game did in 2018. Technical notes, including the
per-weapon values, in `docs/weapon-firerate.md`.

### Alert icons with custom sprite-sheet mods

Symptoms: as soon as any mod with its own `sprites.png` is enabled, many
notification icons (gang alerts, contraband, overheating, tropical fever, fallen
trees, chewed fences, CCTV misconduct, tracking belts, plumbers and repairmen on
site) draw as the wrong piece of a sprite sheet. The bakery oven glow breaks the
same way.

Cause: those icons live in the `objects_d11_2` sheet, but the code that draws
them scales their coordinates with the main object atlas. Both sheets are the
same size in a vanilla install, so the mistake is invisible until a mod makes
the atlas bigger.

Fix: the icon draw now uses the scale of the sheet the icon actually comes
from. If you use the "Alert Icons Partial Fix" mod, disable it after applying
this; its workaround would otherwise double-correct. Technical notes in
`docs/alert-icons.md`.

### Prisoner and staff directions not saved

Symptoms: direction markings you place for prisoners or staff are gone after
you load the save.

Cause: the save writer does not know how to write single-byte fields. The
directions are stored as bytes, so the key is written without a value and
dropped on load. The same happens to visitor skin and clothing colours and a
few other byte fields.

Fix: the game now writes those fields as plain numbers, which the loader
already understands. Everything stored as a byte is saved, not just the two
direction fields. First reported and fixed by vojin154; technical notes in
`docs/direction-save.md`.

### Visitors and civilians stuck at visitor doors

Symptoms: reformed prisoners (Second Chances mentors), animal therapists, fire
safety teachers, delivery men and some other event-spawned NPCs stop at a
visitor door or visitor gate and never get through. Nobody comes to open it.
Double visitor doors work because a guard is sent.

Cause: the door's own "who may open me" list was never extended for the later
DLC entities, while the movement code already treats every non-prisoner as able
to open visitor doors, so it never asks a guard for help. The NPC is refused by
the door and waits forever.

Fix: the door now applies the same rule as the movement code: anyone who is
not a prisoner can open a visitor door. Prisoners are still refused. Technical
notes in `docs/visitor-door-access.md`.

### Staff detour around keycard doors

Symptoms: guards and other staff walk huge detours instead of going through a
keycard door, even with the key and the door right in front of them.

Cause: the route planner charges every keycard door a flat penalty of about a
thousand tiles of walking, the same penalty it uses for swimming across water,
and it charges it to staff with keys as well. Any other route, however long,
looks cheaper.

Fix: keycard doors are now costed like jail doors: key holders pass at normal
cost, everyone else needs a guard as before. Technical notes in
`docs/keycard-door-path-cost.md`.

### Released prisoners stuck behind revoked keycard doors

Symptoms: a keycard door with prisoner access revoked is the only way out of a
cell block. Prisoners whose sentence ends get the RELEASED nameplate and then
stand still forever; no guard is ever sent to let them out.

Cause: the route planner treats a revoked keycard door as a solid wall for
anyone without a staff key, instead of the usual "a guard has to open this"
that every other locked door gets. A released prisoner has no key, so there is
no route to the exit at all and they never start walking.

Fix: released prisoners (and prisoners under escort, who the game already lets
ignore deployment zones) now see a revoked keycard door as "needs a guard",
the same as a jail door, and a guard opens it for them. Prisoners still
serving time are refused as before, tracking belt or not. Technical notes in
`docs/keycard-door-released-prisoners.md`.

### Scripted status effects (mods)

Symptoms: mods that give prisoners a status effect from a Lua script
(`prisoner.StatusEffects.tazed = 60`, the feature added in Alpha 28 and used
by Less Lethal Expansion among others) do nothing. The script runs, reading
the value back shows it was set, but the prisoner is never tazed, sedated or
suppressed and the effect is not in the save file.

Cause: a later update made the game keep a separate list of which effects are
active on each prisoner. Everything that acts on effects, the per-tick decay,
the status icons, the AI checks and the save file, goes by that list. The
game's own code keeps it up to date; the Lua setter was never taught to, so a
scripted effect is written into a slot nobody looks at.

Fix: the Lua setter now activates the effect exactly as the game does, and
clears it again when set to 0, so scripted effects show up, wear off and
survive a save. This fix needs a little new code, so the patcher also adds a
small section to the executable; it is removed again on revert. Technical
notes in `docs/lua-status-effects.md`.

### Shops only worked if prisoners could walk into the shop

Symptoms: a shop is built, staffed and stocked, prisoners have free time and
money, and nobody ever buys anything — or it serves one wing and not another.
The usual advice is to put the shop front on a wall zoned as part of the shop
and cut a door into the shop from every wing that should use it, which rather
defeats the point of a serving hatch.

Cause: the game decides where someone stands to use an object from a marker in
the object's artwork. The shop front is the one such object that was never given
one, so the game fell back to the only spot it had: the shop front itself, which
is a wall. It then asked whether the prisoner could walk to that spot and was
allowed there — that is, whether they could get inside the shop and were
permitted in it. A shop built the sensible way, staff behind the counter and
prisoners queueing outside, fails both questions, and the prisoner decides the
shop is unusable.

Fix: an object built into a wall can now be used from any tile beside it that
the prisoner can reach and is allowed to stand on. Objects standing on ordinary
floor tiles are untouched, so nothing else changes behaviour. Found by
Ozoneraxi; technical notes in `docs/shop-front.md`.

### Exercise on equipment not counted for grading

Symptoms: a prisoner's Health grade scores "% of stay exercising", but a prison
whose prisoners work out on gym equipment scores nothing for it however much
time they spend. Only prisoners jogging laps around a yard ever earn it.

Cause: the game credits that time from the prisoner's current *action*, and the
only activity tagged as the Exercise action is jogging in a yard. Weights
benches, treadmills, punch bags, gym mats and every other piece of equipment are
tagged "use an object", so their time is filed under free time instead, even
though the game is discharging the prisoner's Exercise need the whole while. A
poor Health grade also adds up to 25% to a prisoner's re-offending chance.

Fix: time on an object now counts as exercise whenever the thing being used is
one that serves the Exercise need, which is how the game already describes every
piece of equipment. DLC and modded equipment are covered without naming
anything, and the animations are untouched. Reported by Ozoneraxi, who
identified the cause; technical notes in `docs/exercise-grading.md`.

### Intake routes that accept only some categories

Symptoms: Logistics > Transport lets each road, helipad and boat dock accept
only some prisoner categories. Use that, say a helipad for Max Sec and the road
for everyone else, and after a while nobody arrives at all. The sidebar says
*Your prison is closed to new inmates* while cells stand empty, whatever the
intake setting. Setting every route to accept everything, and forcing the
queue to refill, was the only way out.

Cause: when a vehicle is loaded for a route, the game draws prisoners from the
intake queue in list order and throws away every queued prisoner of a category
that route does not accept until it finds one it does. Those prisoners are
never created, but they are still counted as on their way, and a prisoner on
its way counts against capacity. The count creeps up day after day until, on
paper, the prison is full.

Fix: a vehicle now takes the queued prisoners of the categories its route
accepts and leaves the rest queued for a route that does. A category that no
route accepts still waits for ever, as before; make sure every category you
take is accepted somewhere. Ozoneraxi's test matrix on the AIO tracker
established that any partially filtered route triggers it; technical notes in
`docs/intake-route-categories.md`.

### Visitor booths facing up

Symptoms: a row of visitor booths across a visitation room works when the
prisoners' side is at the bottom and never arranges a visit when it is at the
top, unless prisoners are let into the visitor half of the room, which defeats
the booth.

Cause: a booth's prisoner side is the side it faces, and both the prisoner and
the visitor already walk to the correct sides for every facing. But the check
that pairs a prisoner with a visitor always looked at the side a booth facing
down gives the prisoner, so for a booth facing up it demanded that the prisoner
could reach, and was allowed on, the visitor side.

Fix: the pairing check now looks at the side the prisoner will actually use.
Note that the game draws a booth facing up exactly like one facing down, so
there is no visual cue: if your prisoners' sector is above the booths, rotate
the booths to face up while placing them. Booths facing down, left or right
and visitor tables are unchanged. Ozoneraxi's AIO tracker recorded the failing
layout and the workaround that pointed at the check; technical notes in
`docs/visitor-booth-facing.md`.

### Prisoners near gunfire surrender

Symptoms: when an armed guard opens fire, only the prisoner being shot at
reacts. Everyone standing around it carries on rioting. Older players remember,
and the wiki still says, that prisoners within four squares of a shot might
surrender, up to ten per shot.

Cause: that rule was real. In the 2018 version of the game every shot, from
anyone but a prisoner and with anything but the Tazer, picked up to ten random
prisoners within four squares of where the shot was aimed or of the shooter and
made each react as if it had been shot at itself. Against an armed guard that
usually means surrender; the toughest prisoners may go for the guard instead.
The final version's shooting code simply ends before that part, and nothing else
does the job.

Fix: the missing part is added back to the end of the shooting code, doing what
the 2018 version did. Technical notes in `docs/gunfire-surrender.md`.

### Muzzle flash, smoke and buckshot

Symptoms: guns fire with nothing but a thin tracer. Assault rifles and SMGs have
no muzzle flash, the shotgun shows no smoke and no spread of buckshot, and
automatic rifles play a full burst sound for every single round.

Cause: the game still contains its older firing code, which draws all of those
effects and plays an automatic rifle's burst sound at most twice a second. But
nothing uses that code any more. Every shot now goes through a newer routine
that only draws one tracer and plays the sound every time.

Fix: the newer routine now draws the old effects: a muzzle flash for the assault
rifle, SMG and modified assault rifle, and for the shotgun five puffs of smoke
and fifteen pellets spread around the target. Automatic rifles play their burst
sound at most twice a second again. Damage, accuracy and rate of fire are
unchanged. Technical notes in `docs/weapon-effects.md`.

### Armed guards reload in pavilions

Symptoms: an armed guard manning a Guard Pavilion shoots once and then never
again.

Cause: a guard on a pavilion counts as being carried by it, and the game skips
most of a carried person's update, including the reload timer that runs after
every shot. The stationed guard waits for a reload that never finishes, and
guards refuse to shoot until it does.

Fix: the reload timer keeps running while a guard is stationed. Nothing else
about stationed guards changes. The All-in-One mod's pavilion script worked
around this by running the timer down itself; technical notes in
`docs/pavilion-reload.md`.

### Disarmed armed guards can fight

Symptoms: an armed guard who has been disarmed keeps going after prisoners but
never hurts anyone, and stays stuck in the fight. It happens while Freefire is
on, or once the guard is badly hurt.

Cause: in those two situations the game has an armed guard fight with the weapon
it carries, and it never checks that the guard still carries one. A disarmed
guard's "weapon" is an empty hand with no attack at all.

Fix: an armed guard who carries nothing fights with its fists, as it already
does whenever its weapon is holstered. An armed guard who still has its shotgun
is unaffected. Technical notes in `docs/disarmed-armed-guards.md`.

### Escape Mode Freefire with per-sector actions

Symptoms: in Escape Mode, killing someone makes the warden order Freefire for
three minutes, but with "Search and Actions per sector" on, which is the
default, the guards carry on as if nothing happened.

Cause: the order only flips the old prison-wide Freefire switch. With per-sector
actions the guards look at each sector's own Freefire setting instead, and the
warden never touched those.

Fix: the order now also turns on Freefire in every sector, and turns it off
again when the three minutes are up, just as the old switch is turned off.
Technical notes in `docs/escape-freefire-sectors.md`.

### Hold to fire automatic weapons

Symptoms: when you control a character, assault rifles and SMGs do not fire
automatically. In Warden Mode every shot needs its own click; in Escape Mode the
assault rifle keeps firing while the button is held, but the SMG and the
modified assault rifle do not.

Cause: Warden Mode only ever looked at "the button was just pressed", and Escape
Mode's check for holding the button named the assault rifle and nothing else.

Fix: holding the button keeps firing the assault rifle, SMG and modified
assault rifle in both modes, at each weapon's own rate of fire, at anything a
click would attack. That includes zombies, which the game lets the warden shoot
without switching to attack mode; the first test build only kept firing in
attack mode, so holding the button did nothing against them. Other weapons
still fire once per click. In Escape Mode the ranged weapon fire-rate fix is
what makes that rate faster than one shot every two seconds. Technical notes in
`docs/full-auto-hold.md`.

## Optional tweaks

These change game balance rather than fix bugs, so they are **off by default**.
Tick the ones you want in the patcher before clicking Apply selection (or pass
`--tweaks` on the command line to turn all of them on). Everything below is
marked "[Optional]" in the list. Technical notes for all of them are in
`docs/tweaks.md`.

### No reoffending fine (Second Chances)

Every released prisoner who reoffends costs you a flat $5,000 "Prisoner
Reoffending Fine" two days after release, whether or not you had any say in
the release. This tweak removes the charge. Reoffending is still tracked,
reoffenders can still return, and the reward for prisoners who stay clean is
unchanged.

### No returning prisoners (Second Chances)

A reoffended prisoner can come back through intake as the exact prisoner who
left, with every reputation they earned inside, which is how an Extremely
Deadly, Extremely Volatile Min Sec turns up. With this tweak intake always
generates prisoners by the normal category rules. Reoffending statistics and
the fine are unaffected.

### Staff death morale penalty fades

Each staff member who dies on duty costs one point of staff morale for the
rest of the session. With this tweak the penalty fades by one death per
in-game day. The death count itself is left alone, so the "staff have died on
duty" line in the staff morale panel still shows the real number. This tweak
uses the same small code section as the scripted status effects fix.

### Armed guard warnings ignore overall staff morale

With Staff Needs on, the chance that an armed guard shouts a warning before it
shoots is multiplied by the prison's overall staff morale, on top of the rule
that a guard whose own needs are neglected does not warn at all. At low morale
armed guards shoot first however content the guard itself is, and staff deaths
pull morale down for the rest of the session. With this tweak the overall
figure no longer matters; the per-guard rule stays, and with Staff Needs off
nothing changes. This was a bug fix in the 1.10.0 test build. The 2018 version
of the game turned out to work the same way, so it is a design choice and
became a tweak.

### Protective Custody prisoners work and attend programs in shared sectors

Protective Custody prisoners may walk into Shared sectors, and into Custom
sectors that include Protective Custody, and spend their free time there, but
the final version only gives them jobs and classes in Protective Custody Only
sectors. It checks this in three places: where a job is, where the prisoner's
work station is, and where the prisoner stands when it takes part. A Custom
sector never counts, even with Protective Custody ticked, because the rule looks
at the sector's zone type and not at its ticked categories. So general
population and Protective Custody cannot share a workshop, a kitchen or a
classroom, even on regimes that keep them apart. The 2018 version had no such
rule, and the game's own deployment help still says Protective Custody prisoners
use Shared sector rooms. With this tweak the rule is skipped: they work and
study wherever their deployment lets them go, which is where they could already
spend their free time, and keeping the groups apart is down to your deployment
and regimes. Reported as GitHub issue #3.
