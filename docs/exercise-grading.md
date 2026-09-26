# Exercise equipment counts for grading

Patch: `patches/exercise-grading.patch.json` (built by
`scripts/Build-ExerciseGrading.ps1`). Uses the code section
(`code-section.md`).

## What you'll notice

Time prisoners spent on gym equipment did not count towards the exercise score
of the Health grade. With the fix it does.

## What changes

When a prisoner uses equipment the game lists as meeting the exercise need, the
time is now recorded as exercise.

## Status

Tested in game.
