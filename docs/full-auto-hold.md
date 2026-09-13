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
   is held, the controller is in attack mode (`[rbx+0xA9]`, the same state that
   lets a click through without "order failed") and the warden carries an
   automatic weapon (`[rdi+0x2F8]` = `0x2D`, `0x2E` or `0x68`). Everything else
   goes to the original no-fire target `0x1407643E2`.
2. Escape Mode, `0x14055308F` (`cmp item,0x2D` / `jne`, 6 bytes) jumps to
   `.tyrs+0x880`, which accepts `0x2D`, `0x2E` and `0x68` and returns to the
   original fire (`0x140553095`) or skip (`0x1405530A0`) address.

The rate while held is unchanged: `AttackTimer` in Warden Mode, and in Escape
Mode the gate in `FUN_140557310`, which the fire-rate fix turns into "time since
the last shot >= RechargeTime". Without the fire-rate fix, Escape Mode still
waits the old two-second reload between shots.

`scripts/Build-FullAutoHold.ps1` builds the patch; `-EscAt` and `-WarAt` move the
stubs.

## Verified

Disassembly of a patched copy. Not yet seen in a running game.
