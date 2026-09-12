# Modding extension framework: design (draft, 2026-09-12)

Status: proposal for discussion, nothing built yet. Target build is the Steam
Sunset Update, as for every other patch.

## 1. What this is

Until now every patch in this project restores behaviour the game was meant to
have. A modding extension is different: it adds a capability to the Lua API
that the game never offered (the first request: status effects on staff and
other non-prisoner entities). Once mods depend on it, the extension is a
contract we have to keep, and breaking it breaks other people's work.

This document sets the rules for adding such extensions without destabilising
the game or the mods built on them, and scopes the first one.

## 2. Facts that shape the design

Everything below was read from the Sunset binary with the Ghidra project in
this repo (script outputs are not committed; addresses are for the technical
notes that will follow).

**Status effects are already an entity feature, not a prisoner feature.**
`StatusEffectSystem` is constructed at `Entity+0x3C8` by the `Entity`
constructor (`FUN_140530a30`, writes `Entity::vftable`) and ticked by
`Entity::Update` (vtable slot 40, `FUN_14053b050`). Every object with
`Properties Entity` in `materials.txt` (33 vanilla types: all staff, dogs,
visitors, actors, firemen, bounty hunters, delivery men, ...) has one, and the
save/load of the active-effect mask is registered in the same constructor.
The consumers of `IsActive` (`FUN_14072c7a0`) are mostly entity-generic UI: the
nameplate (`FUN_140437810`, also draws the staff nameplates), the biography
window (`FUN_1401dcfa0`), the staff report (`FUN_14035cd60`), the effect
sprite overlay (`FUN_140574390`). The engine already applies effects to
non-prisoners itself: `Guard::Update` (`FUN_1405d3af0`) calls `Add`, and the
entity combat virtuals (`FUN_140535d80`, `FUN_140542a20`) call `Set`.
What is prisoner-specific is the behavioural reaction to some effects (for
example `FUN_1406b1ef0` in `Prisoner`), so "does effect X do anything on a
guard" is a per-effect question, not a yes/no.

**Only the Lua table is prisoner-only.** Lua object tables are built by the
virtual `RegisterLua` (vtable slot 28). The base implementation
`FUN_1407d65b0` (3779 bytes; registers `GetNearbyObjects`, `Delete`,
`Tooltip`, the `DataRegistry` property tables and so on) is shared by roughly
180 object classes. `Prisoner` alone overrides it (`FUN_1406c68d0`): it calls
the base, then registers the `StatusEffects` sub-table
(`FUN_14072d040(this+0x3C8, L, "StatusEffects", table)`), the `Needs`
sub-table (`this+0xDA0`) and the `ReoffendingChance` getter. `Guard`, `Staff`,
`Worker`, `Doctor`, `Dog`, `Visitor`, `Actor` all use the base. So
`guard.StatusEffects` is `nil` today, and a script that indexes it errors.

**There is an undocumented `Object.GiveStatusEffect`.** The `Object` table
(`FUN_14045bdc0`) registers `GiveStatusEffect` -> `FUN_14045e8b0`, which takes
`(objectName, effectName, fraction)` and queues script command `0x27`. The
executor (`FUN_1401a6880`) resolves the object by id and then requires object
type `0x6D` (Prisoner) with a single compare before calling the game's own
`Set` (`FUN_14072c930`: charge = fraction x maximum, bit set, timestamp).
It is absent from `lua_function_list.txt`. One compare is all that keeps it
from working on staff.

**Where Lua globals come from.** The script system builds each Lua state in
`FUN_1407bfbc0` (caller `FUN_1407b8b00`): `Game` (`FUN_14046d0d0`), `Object`
(`FUN_14045bdc0`), `World`, `ScriptState`. That is the place to add a global
of our own.

**Room.** `.tyrs` is 0x1000 bytes with 0x1CA used (see `code-section.md`).

## 3. Principles (the contract)

1. **Additive only.** A hook, stub, Lua name or byte range that shipped in a
   stable release is never modified. New behaviour is a new patch id, a new
   stub range and a new Lua name. If a stable behaviour turns out wrong, the
   fix keeps the old name working and adds a corrected one.
2. **Two tiers, visible everywhere.**
   - *Stable*: on by default, names and semantics frozen, only additions.
   - *Experimental*: off by default, marked as such in the patcher, the docs
     and the release notes; may change or be removed between releases.
   Every extension enters as experimental and is promoted only by a release
   note entry, after at least one full release cycle with a real mod using it
   and no open reports. Promotion changes no bytes, only the flag.
3. **Feature detection, not version checks.** Every extension is detectable
   from Lua at run time by a `nil` test on the thing it adds, and later by
   `TyrsPatch.Has("<feature id>")`. Mod authors are told to degrade gracefully
   on an unpatched game; the patch never becomes something a mod crashes
   without.
4. **Vanilla-shaped API.** Extend the game's own tables and conventions
   (`obj.StatusEffects.<name>`, `Object.GiveStatusEffect`) rather than invent a
   parallel API. The game already documents them, so a mod written for staff
   reads exactly like one written for prisoners, and there is nothing new to
   learn.
5. **No save-format changes.** An extension may only use state the game already
   saves, or session-only state in `.tyrs`. A save made with the patch must
   load on an unpatched game.
6. **No cost without a mod.** Hooks go in registration and setter paths, never
   in per-tick loops. A player without mods pays nothing.
7. **Fail closed.** Stubs validate what they touch (object type, index range)
   and otherwise fall through to the game's original behaviour. A wrong Lua
   call is ignored or returns `nil`; it never crashes the game.
8. **Bases are frozen.** `code-section` never changes. When it fills, a new
   hidden base (`code-section-2`) appends a further section after it, using the
   same "file length equals offset" append rule. The allocation map in
   `code-section.md` is the ledger; a check script fails the build on overlap.
9. **`superseded` for any byte change at a shipped site** (already a rule; it
   is what makes upgrades from older releases work).
10. **Every extension ships complete:** patch JSON, build script, a mod-author
    page (Lua signature, tier, `since` version, behaviour, limits), a technical
    page, a test mod under `tools/testmods/`, and an entry in the API index
    `docs/modding-api.md`.

What counts as a breaking change for a stable extension: renaming or removing a
Lua name; changing what a value means, its range, or when it takes effect;
changing which objects it applies to in a way that removes any; changing the
default tick state of the patch. Adding names, adding object types, and fixing
a crash are not breaking.

## 4. Patcher changes

**Schema** (`PatchDoc`, all optional so existing files stay valid):

| field | values | meaning |
|---|---|---|
| `category` | `fix` (default), `tweak`, `modapi` | which list heading it appears under |
| `stability` | `stable` (default), `experimental` | tier; `experimental` implies off by default |
| `api` | `{ "id": "status-effects.entities", "since": "1.6.0", "lua": ["obj.StatusEffects", "Object.GiveStatusEffect"] }` | what mods can detect and where it is documented |

`optional: true` stays as the marker for balance tweaks (back-compatible;
`category: tweak` is implied by it). Default tick state: fixes and stable
modapi on; tweaks and experimental modapi off; anything already applied is
ticked so Revert can undo it (existing behaviour).

**UI.** The single list gains group headings: "Bug fixes", "Modding
extensions", "Modding extensions (experimental)", "Optional tweaks". The info
line under the list states the tier and the `since` version. The status
headline counts fixes as now and adds "N modding extension(s) on, M
experimental".

**CLI.** `--apply` installs fixes and stable extensions; `--experimental` adds
the experimental ones; `--tweaks` unchanged; `--status` prints the tier next to
each entry.

**Engine.** No change is needed for edits in `.rdata` or vtables (edits are
plain file offsets). Add `scripts/Test-Allocations.ps1`: parses every
`patches/*.patch.json`, asserts no two patches touch overlapping offsets, and
that every `.tyrs` range is listed in `code-section.md`. Run it before every
release.

**Version signalling.** The patcher version string is written into `.tyrs`
data by the `modapi-core` base (section 6), so `TyrsPatch.Version` in Lua
always equals the release that patched the file.

## 5. Extension 1: status effects on every entity

Feature id `status-effects.entities`. Enters as experimental.

**Lua surface** (identical semantics to prisoners; no new names to learn):

```lua
-- (a) the table every prisoner already has, now on every entity
local guards = this.GetNearbyObjects("Guard", 10)
for guard, dist in pairs(guards) do
    if guard.StatusEffects then            -- nil on an unpatched game
        guard.StatusEffects.tazed = 60     -- charge, as for prisoners; 0 clears
    end
end

-- (b) the game's own function, no longer prisoner-only
Object.GiveStatusEffect(guardName, "sedated", 1.0)   -- fraction of the maximum
```

`StatusEffects` is `nil` on objects that are not entities (doors, beds), as
today. Reads return the charge; assignment goes through the setter that the
1.5.0 fix already corrected, so activation, decay, icon and save all behave as
for prisoners.

**Mechanism (a), recommended: vtable edits.** Every entity class except
`Prisoner` has `FUN_1407d65b0` in vtable slot 28. Point that slot, in each
entity class's vtable, at a stub in `.tyrs` that calls `FUN_1407d65b0` with
the original arguments and then does what `Prisoner::RegisterLua` does for
`StatusEffects`: build the name string and the `LuaTable`
(`FUN_140108ff0`), call `FUN_14072d040(this+0x3C8, L, name, table)`, run the
destructors. Estimated 200 to 300 bytes. Only pointer swaps in `.rdata`, no
game instruction is relocated, and the stub cannot fire for a non-entity.
The class list (`Entity`, `Staff`, `Guard`, `Worker`, `Doctor`, `Dog`,
`Visitor`, `Actor`, `Fireman`, `BountyHunter`, `CivilianChild`,
`RestaurantCustomer`, `Waterman`, `DeliveryMan`, and any `Staff` subclasses)
must be produced mechanically: the vtables referencing `FUN_1407d65b0`
intersected with the classes whose RTTI base-class array contains `Entity`.
Fallback if the list is unwieldy: a detour on `FUN_1407d65b0` itself that
tests the ObjectDef `Entity` property bit (the flag next to the `Staff` bit
that `FUN_1407dd630` tests) and skips objects whose vtable is the Prisoner
vtable.

**Mechanism (b): one compare.** In `FUN_1401a6880` the test
`type == 0x6D` becomes a call to a small predicate stub that accepts any
object with the `Entity` property. Fail closed: non-entities are still
refused.

**Behaviour matrix.** Before promotion, each of the 28 effects is tried on a
Guard, a Doctor, a Dog and a Visitor and recorded as: icon shown / decays /
survives save / any AI reaction. Expectation from the code: the UI and decay
are universal; `tazed`, `sedated`, `wounded`, the water and disease effects
probably have entity-level reactions (the engine applies them to staff
itself); `suppressed`, `angst`, `riledup` and the like are read only by
prisoner code and will be inert on staff. The mod-author page publishes the
matrix so nobody has to guess.

**Cost.** `RegisterLua` runs whenever the game builds a Lua table for an object,
including every object returned by `GetNearbyObjects`. Prisoners already pay
for the 27 getter/setter registrations; this extends that cost to entities.
Measure with a stress mod (every tick, `GetNearbyObjects("Guard", 50)` in a
prison with 100+ staff) before and after; if it is visible, the fallback is
lazy registration (build the sub-table on first index), which is more code.

**Save safety.** The active-effect mask on staff is already written and read
by the entity's own registry, so a save with a tazed guard loads on an
unpatched game (the effect simply decays there). Confirm by round trip.

**Test mod.** Extend `tools/testmods/lua-status-effects-test` (or add a
sibling) with a second object that applies effects to nearby staff through both
(a) and (b), and prints the read-back.

## 6. `modapi-core`: the `TyrsPatch` global

Hidden base, `requires: ["code-section"]`, hooks the tail of `FUN_1407bfbc0`
so every Lua state gets:

```lua
TyrsPatch.Version      -- "1.6.0", the release that patched this exe
TyrsPatch.Api          -- integer, +1 on every stable addition
TyrsPatch.Has(id)      -- true if the extension is applied (either tier)
TyrsPatch.Tier(id)     -- "stable", "experimental" or nil
```

Feature registry without touching the core: the core owns a fixed table of
slots in `.tyrs` data (say 16 x 32 bytes: id string, tier byte). Each
extension's patch writes its own slot as one of its edits (expect `CC..`,
replace `id\0..tier`), so applying or reverting an extension updates the
registry through the patcher's normal state tracking, and the core stub skips
slots whose first byte is `CC`. Needs the addresses of the game's Lua table
helpers (the `FUN_1404595b0` family used by `RegisterLua`) or of the linked
Lua C API (`lua_createtable`, `lua_pushcclosure`, `lua_setfield`).

Until the core exists, feature detection is the `nil` test on the added name,
which stays valid forever (principle 3).

## 7. Phases

1. **Research** (no release): enumerate the entity vtables mechanically (new
   Ghidra script: RTTI base-class walk); confirm the ObjectDef `Entity` bit and
   its predicate; pin down `RegisterLua`'s parameters and the `LuaTable`
   constructor/destructor contract (the destructor warns when the table is
   popped early, so stack discipline must be exact); find the Lua helper or
   C API addresses for the core; record baseline frame cost of
   `GetNearbyObjects` on staff.
2. **Patcher framework** (1.6.0): schema, grouped list, CLI flag, allocation
   check script, `docs/modding-api.md` index, contributor checklist in the
   README. No game bytes change; releasable on its own.
3. **Extension 1, experimental** (1.6.0 or 1.7.0): mechanisms (a) and (b),
   test mod, behaviour matrix, mod-author page. Invite the Less Lethal
   Expansion author and anyone who asked for staff effects to try it.
4. **`modapi-core`, experimental** (1.7.0): `TyrsPatch` global and registry;
   extension 1 registers its slot.
5. **Promotion** (1.8.0): extension 1 and the core to stable once the release
   cycle passes clean; announce the mod-author guide.

Later candidates, each through the same gate: regime forcing (open request),
`GiveStatusEffect` by object table instead of name, entity queries. Out of
scope: `Needs` on staff. The need system is genuinely prisoner-only
(`Prisoner+0xDA0`, no counterpart in `Entity`), so it would mean new per-entity
state and save data, which principle 5 forbids.

## 8. Risks and open questions

- **Stub reproduces C++ temporaries** (std::string, `LuaTable`) in assembly.
  Mitigation: mirror `Prisoner::RegisterLua` instruction for instruction,
  verify with the test mod on four entity classes, and run a soak (thousands
  of `GetNearbyObjects` calls) to check the Lua stack does not grow.
- **Effects with prisoner-only reactions** will look "broken" on staff to a
  mod author who does not read the matrix. The doc and the `Tier` answer are
  the mitigation; this is also why it starts experimental.
- **Mods that already guard `if obj.StatusEffects then`** (there may be some,
  written defensively) start doing things on staff the day the extension is
  ticked. Acceptable; it is what they asked for. Note it in the release notes.
- **Room in `.tyrs`.** Phases 3 and 4 fit comfortably (about 1 KB). Plan
  `code-section-2` for whatever comes after; do not enlarge `.tyrs`.
- **The Sunset build is frozen**, so the only compatibility axis is our own
  releases. That is what makes a frozen stable tier realistic.

## 9. Decisions needed

1. Name of the Lua global: `TyrsPatch` (matches the patcher) or something
   project-neutral such as `CommunityPatch`. Once shipped it is permanent.
2. Stable extensions ticked by default (recommended: yes; they are inert
   without a mod, and mod authors need a predictable baseline).
3. Every extension spends at least one release as experimental (recommended:
   yes, no exceptions).
4. Mechanism for extension 1: vtable edits (recommended) or the detour.
