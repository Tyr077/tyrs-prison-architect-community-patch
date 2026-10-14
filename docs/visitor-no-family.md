# Visitors wasted on prisoners with no family

Patch: `patches/visitor-no-family.patch.json`. Uses the code section
(`code-section.md`).

## What you'll notice

The game never creates a visit for a prisoner with no family, but it still
matched arriving visitors with them, and each time the visitor was used up and
nobody visited. These prisoners never get a visit, so they never wait for their
next one either: in a room where most prisoners had already been visited, they
took most of the visitors. With the fix, visitors go to prisoners who can
actually be visited.

## What changes

A prisoner with no family is no longer matched with a visitor.

## Status

Tested in game on a player's prison with three visitation rooms, over about ten
game hours: without the fix, 32 visitors were used up on prisoners with no
family and 49 prisoners were visited; with it, no visitor was wasted and 78
prisoners were visited.
