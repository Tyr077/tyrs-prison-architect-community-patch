# Visitors with an unusable visitation table

Patch: `patches/visitor-spawn-tables.patch.json`. Uses the code section
(`code-section.md`). GitHub issue #4.

## What you'll notice

With a second visitation room, or any visitor table or booth that no prisoner
can be matched with, visits could stop in the whole prison. A booth facing a
Protective Custody sector with no Protective Custody prisoners was enough. With
the fix, the other tables keep getting visitors.

## What changes

When a visitor arrived, the game tried only the first free visitor table. If no
prisoner could be matched with that table, the visitor was used up and nobody
visited. The game now moves on to the next table, as the 2018 version did.

## Status

Tested in game on the reporter's save: no visits without the fix, 13 prisoners
visited within one game day with it.

## Notes

A table that can never be matched still gets no visitors. Check the sector on
the prisoners' side of each booth.
