# Hold to fire automatic weapons: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`. Needs the code section (`code-section.md`).

## Symptom

Assault rifles and SMGs cannot be fired automatically by holding the mouse
button when you control a character: in Warden Mode every shot needs a click,
and in Escape Mode only the assault rifle keeps firing.

Guards, soldiers, Elite Ops and bounty hunters are not affected by this; their
rate of fire is the fire-rate fix (`weapon-firerate.md`).

## Cause

The mouse state object `DAT_140D57648` keeps `+0x14A` "left button held" (set on
`WM_LBUTTONDOWN`, cleared on `WM_LBUTTONUP`, in `FUN_14011A760`) and `+0x14D`
"left button went down this frame" (`FUN_14011A1C0`).

- **Warden Mode.** The controlled warden's attack `FUN_140764010` fires only
  when `+0x14D` is set (`0x140764100`). Its rate limit already exists:
  `AttackTimer` (`Entity+0x348`), which `FireRangedShot` sets to the weapon's
  `RechargeTime` and the controller update `FUN_140763D30` counts down.
- **Escape Mode.** The update `FUN_140552F10` attacks on `+0x14D`, and also on
  `+0x14A` when the selected inventory item is `0x2D`, the AssaultRifle
  (`0x14055308F`). The SubMachineGun (`0x2E`) and the DLC ModifiedAssaultRifle
  (`0x68`) are not in that check.

## Fix

1. Warden Mode, `0x140764100` (`cmp byte [rax+0x14D],0` / `jz`, 13 bytes) jumps
   to `.tyrs+0x8A0`. A click fires as before. Otherwise it fires when the button
   is held and the warden carries an automatic weapon (`[rdi+0x2F8]` = `0x2D`,
   `0x2E` or `0x68`). Everything else goes to the original no-fire target
   `0x1407643E2`.
2. Warden Mode, `0x1407642F3` (`cmp byte [rsp+0x98],0` / `jnz`, 10 bytes) jumps
   to `.tyrs+0x8F0`. This is the test in front of "order failed": outside attack
   mode the attack refuses a gun in a selected slot, an empty selected slot, or
   Fists on a target, unless the target under the cursor is a Zombie (`0x239`,
   the byte at `[rsp+0x98]`). The stub replays the zombie test; for a refusal it
   plays "order failed" (`0x1407642FD`) only when the button went down this
   frame, and a frame where it is merely held leaves through the common exit
   `0x1407643CE`. Holding the button therefore attacks exactly what a click
   would, without repeating the failure sound every frame.
3. Escape Mode, `0x14055308F` (`cmp item,0x2D` / `jne`, 6 bytes) jumps to
   `.tyrs+0x880`, which accepts `0x2D`, `0x2E` and `0x68` and returns to the
   original fire (`0x140553095`) or skip (`0x1405530A0`) address.

### Version 1.1.0: zombies

Version 1.0.0 did the held-button test itself and required attack mode for it,
to avoid the failure sound. The game lets a click attack a zombie without
attack mode, so players fight zombies that way, and holding the button did
nothing against them. 1.1.0 drops the attack-mode test from the first stub and
moves the "held, not clicked" decision to the refusal site (edit 2). The 1.0.0
warden stub is listed as `superseded` (the new one is padded with `CC` to the
same 77 bytes), and the two new edits list their original bytes, so an exe
patched by 1.9.0-test1 shows as an older version and is rewritten rather than
refused.

The rate while held is unchanged: `AttackTimer` in Warden Mode, and in Escape
Mode the gate in `FUN_140557310`, which the fire-rate fix turns into "time since
the last shot >= RechargeTime". Without the fire-rate fix, Escape Mode still
waits the old two-second reload between shots.

`scripts/Build-FullAutoHold.ps1` builds the patch; `-EscAt`, `-WarAt` and
`-RefuseAt` move the stubs.

## Ammo

Not changed by this fix. In Warden Mode `FireRangedShot` counts down the ammo of
the warden's selected inventory slot (`World+0x4398`, inventory at `+0x78`),
before any of the hooks above and whether the shot came from a click or a held
button. Slot ammo comes from the weapon's `Ammo` in `materials.txt` (30 for the
assault rifle and SMG). The game never empties a slot whose ammo is -1 (the
value of an empty slot, and of weapons lying on the ground), and with no slot
selected it counts down the four bytes in front of the ammo array.

## Verified

1.1.0: disassembly of a patched copy (all seventeen fixes) at both warden hooks
and all three stubs; with the patcher, a 1.9.0-test1 exe (fixes only, and with
tweaks) upgrades to the same hash as a fresh install (`3365c46e…`,
`3d0af4f8…`) and reverts to the original. Not yet seen in a running game.
