# Assigned guards blocking solitary and treatment

Patch: `patches/assigned-guard-jobs.patch.json`.

## What you'll notice

A prisoner with a guard assigned to them (**Assign Guard** on the rap sheet,
or the Chief's Guard Assignment) was never taken to solitary for misconduct and
never treated by a doctor in their cell, unless you did it by hand. With the
fix, they are punished and treated like everyone else.

## What changes

The job that keeps the assigned guard watching the prisoner no longer counts
as a job already in progress for that prisoner, so solitary and treatment jobs
are created. The assigned guard takes the prisoner to solitary, then goes back
to watching.

## Status

Solitary tested in game: five prisoners with an assigned guard and a pending
solitary punishment, next to five without a guard. Without the fix none of the
five with a guard was punished in about 20 game hours, and all five without one
were; with the fix all ten were, and the guards went back to watching
afterwards. Treatment by doctors is not confirmed yet.
