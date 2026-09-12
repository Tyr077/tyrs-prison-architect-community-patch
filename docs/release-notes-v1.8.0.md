Adds two bug fixes on top of 1.7.0. Existing users: download the new `TyrsPAPatch.exe`, run it,
click **Apply selection**. Your tweak choices are kept.

1.6.0 and 1.7.0 were only ever test builds and were never released, so their changes are listed
here too.

## New in 1.8.0

**Intake keeps working when a route accepts only some categories.** Logistics >
Transport lets each road, helipad and boat dock accept only some prisoner
categories. Prisons that used that — a helipad for Max Sec, the road for
everyone else — found after a while that nobody arrived any more: the sidebar
said *Your prison is closed to new inmates* while cells stood empty, whatever
the intake setting. When a vehicle was loaded for such a route, the game drew
prisoners from the intake queue in list order and threw away every queued
prisoner of a category the route did not accept until it found one it did.
Those prisoners were never created but were still counted as on their way, and a
prisoner on its way counts against capacity, so day after day the prison filled
up on paper. A vehicle now takes the queued prisoners of the categories its route
accepts and leaves the rest queued for a route that does. One thing to know: a
category that no route accepts still waits for ever, as it always did, so make
sure every category you take is accepted somewhere. Technical notes in
`docs/intake-route-categories.md`.

**Visitor booths work facing up.** A row of booths across a visitation room
worked with the prisoners' side at the bottom and never arranged a visit with it
at the top, unless prisoners were let into the visitor half of the room, which
defeats the booth. A booth's prisoner side is the side it faces, and both the
prisoner and the visitor already walked to the right sides; but the check that
pairs a prisoner with a visitor always looked at the side a booth facing down
gives the prisoner, so for a booth facing up it demanded that the prisoner could
reach, and was allowed on, the visitor side. The pairing check now looks at the
side the prisoner will actually use. The game draws a booth facing up exactly
like one facing down, so there is no visual cue: if your prisoners' sector is
above the booths, rotate the booths to face up while placing them. Technical
notes in `docs/visitor-booth-facing.md`.

## Also in this release, from 1.7.0

**Shops work without letting prisoners into the shop.** The game decides where
someone stands to use an object from a marker in the object's artwork, and the
shop front is the one such object that was never given one, so the game fell
back to the shop front itself, a wall, and then asked whether the prisoner could
walk to that spot and was allowed there. A shop built the sensible way, staff
behind the counter and prisoners queueing outside, failed both questions. An
object built into a wall can now be used from any tile beside it that the
prisoner can reach and is allowed to stand on. Technical notes in
`docs/shop-front.md`.

## Also in this release, from 1.6.0

**Exercise on equipment counts for grading.** Only jogging laps around a yard
ever earned the "% of stay exercising" part of the Health grade; every piece of
gym equipment is tagged "use an object", so its time went to free time. Time on
an object now counts as exercise whenever the thing being used serves the
Exercise need. Technical notes in `docs/exercise-grading.md`.

**The patcher window was rebuilt.** Everything is grouped under **Bug fixes**
and **Optional tweaks**; every line says whether that fix is installed right
now; your selections are remembered in `%AppData%\TyrsPAPatch\settings.json`;
**Apply selection** installs what you ticked and removes what you unticked, and
**Revert to original** always takes the game back to the unpatched file. The
command line (`--status`, `--apply`, `--apply --tweaks`, `--revert`) is
unchanged.

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, tick what you want, click **Apply selection**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply selection. **Revert to original** undoes everything, tweaks included, at any time.

## Testing these two

They have been verified by disassembling the patched executable but not yet in
a running prison. If you try them, this is what to look for:

- **Intake:** one route that accepts only some categories (a helipad for Max
  Sec, say) and another that accepts the rest, Fill Capacity, a few days at
  speed. Prisoners of both kinds should keep arriving and the sidebar should not
  report intake closed while cells are free. Any change in what arrives with
  every route accepting every category would be a bug.
- **Booths:** a visitation room with booths across the middle, the prisoners'
  sector above the booths, no way for prisoners into the lower half, booths
  rotated to face up. Visits should be arranged and take place with the prisoner
  at the top. Booths facing the other three ways and visitor tables should be
  unchanged.

## Credits

- **Ozoneraxi** (AIO bug tracker) established that any transport route accepting only some categories breaks Fill Capacity, with a test matrix that ruled out mixed transport as such; that is what pointed at the loading step. They also recorded that booths only fail in the prisoner-up layout and that the workaround needs both halves of the room reachable, which is precisely the check that was wrong.
- **Ozoneraxi** (AIO bug tracker) for the shop-front and exercise-grading findings behind the 1.7.0 and 1.6.0 fixes.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: (filled in by the follow-up commit)
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the twelve fixes applied: `abc00ad59876212f79a879af269879fdae5982ed8e1e5f1bd3296cf7f891e300`
- `Prison Architect64.exe` with the twelve fixes and all three tweaks: `99c12563ad0c79c5d5791a56a32cc80801892458543750f2df6f252205647630`
