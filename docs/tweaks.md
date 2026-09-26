# Optional tweaks

Tweaks are balance changes rather than bug fixes. They are off by default:
tick them under **Optional tweaks** in the patcher, or pass `--tweaks` on the
command line to turn all of them on.

## No reoffending fine (`tweak-no-reoffend-fine`)

Second Chances DLC. When a released prisoner reoffends, the prison is no longer
charged the $5,000 parole fine. Reoffenders are still counted and can still
come back.

Status: not yet tested in game.

## No returning prisoners (`tweak-no-returning-prisoners`)

Second Chances DLC. Intake always brings in newly generated prisoners instead
of bringing back reoffenders with all their old reputations. Reoffending
statistics and the fine are unchanged.

Status: not yet tested in game.

## Staff death morale penalty fades (`tweak-staff-death-morale-decay`)

The staff morale penalty for staff deaths shrinks by one death per in-game day
until it is gone. The staff deaths figure in the top bar still shows the real
number.

Status: not yet tested in game.

## Armed guard warnings ignore overall staff morale (`tweak-armed-guard-warnings`)

With Staff Needs on, an armed guard's chance to shout a warning before
attacking no longer drops with the prison's overall staff morale. A guard whose
own needs are neglected still attacks without warning. Listed as a fix in the
1.10.0 test build.

Status: not yet confirmed in game.

## Protective Custody prisoners work and attend programs in shared sectors (`tweak-pc-shared-zones`)

Protective Custody prisoners take jobs and go to classes in Shared sectors and
in Custom sectors that include Protective Custody. Without the tweak they only
get work and classes in Protective Custody Only sectors, although they may
spend free time in the others. With it, keeping them apart from general
population is down to your deployment and regimes.

Status: tested in game.
