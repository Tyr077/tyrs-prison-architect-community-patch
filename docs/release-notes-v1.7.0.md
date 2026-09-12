Adds a second bug fix on top of 1.6.0. Existing users: download the new `TyrsPAPatch.exe`, run it,
click **Apply selection**. Your tweak choices are kept.

1.6.0 was only ever a test build and was never released, so its changes are listed here too.

## New in 1.7.0

**Shops work without letting prisoners into the shop.** You build a shop, staff
it, stock it, give prisoners free time and money — and nobody buys anything. Or
it serves one wing and not another. The advice has always been to put the shop
front on a wall zoned as part of the shop and cut a door into the shop from
every wing meant to use it, which rather defeats the point of a serving hatch.

The game decides where someone stands to use an object from a marker in the
object's artwork. The shop front is the one such object that was never given
one, so the game fell back to the only spot it had: the shop front itself,
which is a wall. It then asked whether the prisoner could walk to that spot and
was allowed there — in other words, whether they could get inside the shop and
were permitted in it. A shop built the sensible way, staff behind the counter
and prisoners queueing outside, fails both questions, and the prisoner decides
the shop is unusable and wanders off.

An object built into a wall can now be used from any tile beside it that the
prisoner can reach and is allowed to stand on. Objects standing on ordinary
floor tiles are untouched, so nothing else changes behaviour, and the spot
prisoners walk to is unchanged — they queue at the counter exactly as they do in
a shop that works today. Technical notes in `docs/shop-front.md`.

## Also in this release, from 1.6.0

**Exercise on equipment counts for grading.** A prisoner's Health grade scores
"% of stay exercising", but a prison whose prisoners work out on gym equipment
scored nothing for it however many hours they put in. The only activity in the
game tagged as the Exercise action is jogging laps around a yard; weights
benches, treadmills, punch bags, gym mats, dumbbell racks, tyre apparatus,
training dummies and pull-up bars are all tagged "use an object", so their time
went to free time instead. An indoor gym could not score that part of the Health
grade at all, and a poor Health grade adds up to 25% to a prisoner's
re-offending chance. Time on an object now counts as exercise whenever the thing
being used is one that serves the Exercise need. DLC and modded equipment are
covered without naming anything, and the animations are untouched. Technical
notes in `docs/exercise-grading.md`.

**The patcher window was rebuilt.** Everything is now grouped under **Bug
fixes** and **Optional tweaks**: tick a group to take all of it, or expand it to
pick individual items, and the groups stay as you left them so the window stays
short as more fixes are added. Every line says whether that fix is installed in
your game right now, and each heading counts them up. What you ticked last time
comes back next time, kept in `%AppData%\TyrsPAPatch\settings.json`; a fix added
by a later release is on by default and a new tweak is off, so an update never
silently changes anything you had already decided.

Two behaviours changed. **Apply selection** now installs what you ticked *and
removes what you unticked* — previously the only way to take a fix back out was
to revert everything and start again — and a line under the list says what it is
about to do. **Revert to original** no longer depends on what is ticked: it
always takes the game back to the unpatched file. The command line
(`--status`, `--apply`, `--apply --tweaks`, `--revert`) is unchanged.

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, tick what you want, click **Apply selection**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply selection. **Revert to original** undoes everything, tweaks included, at any time.

## Credits

- **Ozoneraxi** (AIO bug tracker) established that shops need their customers to be able to path inside, and published the layouts that work around it; that pointed straight at the standing position the game picks. They also worked out why exercise on equipment never counted towards the Health grade, down to the action tag responsible, and noted that no mod could fix it without losing the animations — fixing the grading side instead avoids that cost.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `de1aa0b209ff268875f94b8a6ff9b83e293ae001d76ef73e70ec385e75784edb`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the ten fixes applied: `cdb6b582199337c8d299bfb7c4b382607fcc0bec066456405aadaacc8aa73bd3`
- `Prison Architect64.exe` with the ten fixes and all three tweaks: `4d7d01a92e1f2909934d96b28204dafb5941eb9284715b4903ef5b3f791d5b69`
