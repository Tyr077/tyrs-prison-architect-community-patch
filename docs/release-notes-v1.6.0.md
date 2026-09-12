Adds one bug fix and rebuilds the patcher window around groups that remember what you picked. Existing
users: download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your tweak choices are kept.

## New in 1.6.0

**Exercise on equipment counts for grading.** A prisoner's Health grade scores
"% of stay exercising", but a prison whose prisoners work out on gym equipment
scored nothing for it however many hours they put in. The game credits that time
from the prisoner's current *action*, and the only activity in the whole game
tagged as the Exercise action is jogging laps around a yard. Weights benches,
treadmills, punch bags, gym mats, dumbbell racks, tyre apparatus, training
dummies and pull-up bars are all tagged "use an object", so their time went to
free time instead, even though the game was discharging the prisoner's Exercise
need the whole while. An indoor gym could not score that part of the Health
grade at all, and a poor Health grade adds up to 25% to a prisoner's
re-offending chance.

Time on an object now counts as exercise whenever the thing being used is one
that serves the Exercise need, which is how the game already describes every
piece of equipment. DLC and modded equipment are covered without naming
anything, and the animations are untouched. Prison-labour rooms that work the
prisoner's body still count as work, so work experience is unaffected.
Technical notes in `docs/exercise-grading.md`.

## Patcher

**Groups.** Everything is now under **Bug fixes** and **Optional tweaks**. Tick
a group to take all of it, or expand it to pick individual items. Groups stay
expanded or collapsed the way you left them, so the window stays short as more
fixes are added.

**It shows what you already have.** Every line says whether that fix is
installed in your game right now, and each group heading counts them up, so you
can see at a glance what is in and what is not without reading hashes.

**It remembers your choices.** What you ticked last time comes back next time,
kept in `%AppData%\TyrsPAPatch\settings.json`. A fix added by a later release is
on by default and a new tweak is off, so an update never silently changes
anything you had already decided. Deleting that file just resets to the
defaults.

**Apply makes the game match your selection.** The button is now **Apply
selection**: it installs what you ticked *and removes what you unticked*.
Previously the only way to take a fix back out was to revert everything and
start again. A line under the list says what the button is about to do before
you press it.

**Revert to original** is unchanged in meaning but no longer depends on what is
ticked: it always takes the game back to the unpatched file, fixes and tweaks
alike.

The command line (`--status`, `--apply`, `--apply --tweaks`, `--revert`) is
unchanged, so existing scripts keep working.

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, tick what you want, click **Apply selection**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply selection. **Revert to original** undoes everything, tweaks included, at any time.

## Credits

- **Ozoneraxi** (AIO bug tracker) worked out why exercise on equipment never counted towards the Health grade, down to the action tag responsible, and noted that no mod could fix it without losing the animations. Fixing the grading side instead avoids that cost.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `5eb8efe06405035ec6537739b697691c06fb19059d351dff1656fe5be2bbea67`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the nine fixes applied: `492de8d964835e2608046f11f7c1af6c3cc81e0790e8700680938bd3c0fdd53c`
- `Prison Architect64.exe` with the nine fixes and all three tweaks: `6a6bb5933b82b7e48aeba6761a499a87ceb0173b604f6816eb73439bac4686be`
