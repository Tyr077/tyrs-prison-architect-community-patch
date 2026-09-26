# Status Effect Tester (test mod)

A local mod used to check the "scripted status effects" fix
(`docs/lua-status-effects.md`). It adds a one-tile "Status Effect Tester"
object under Objects > Security. Its script gives every prisoner within five
tiles `StatusEffects.tazed = 60` every four game minutes (`Game.Time()`
units; a few real seconds at normal speed).

Install: copy this folder to
`%LocalAppData%\Introversion\Prison Architect\mods\lua-status-effects-test\`
and enable it under Extras > Mods, then load or start a prison and place the
object somewhere prisoners walk past.

- Unpatched game: prisoners walk past unaffected. The script debug window
  shows "read back 60", because the getter reads the stored value either way.
- Patched game: the tazed effect becomes active and is written to the save
  (checked by `tools/ingame-test/tests/lua-status-effects.ps1`). Prisoners near
  the object should drop as if tazed and show the tazed icon, get up after a
  while, and be tazed again on the next pass.

The mod contains its own one-tile `sprites.png`, so the alert-icons fix (or
the community workaround) is needed for the notification icons to stay
correct, as with any sprite mod.
