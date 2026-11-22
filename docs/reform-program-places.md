# Reform programs without equipment restart every session

Patch: `patches/reform-program-places.patch.json`. Uses the code section
(`code-section.md`).

## What you'll notice

Flower Therapy and Three Strikes pass very few prisoners. Before every session
the game took all their students off the program and put them back on, which
started their progress over, so a prisoner's chance only ever came from the last
session. With the fix their students stay on the program and their progress builds
up over the sessions, as in other programs.

## What changes

Programs whose definition lists no equipment, which in the base game are Flower
Therapy and Three Strikes, keep their students from one session to the next, up
to the program's places. Programs with equipment are not affected. Mod programs
without equipment get the fix too.

These two programs will pass far more prisoners than before.

## Status

Tested in game with Three Strikes: without the fix the student was taken off
before the second session and lost their progress. With it the same student
stayed for three sessions and their attendance kept growing (120, 232, 336).
Only one prisoner could take part in the test prison. Flower Therapy is not
tested.
