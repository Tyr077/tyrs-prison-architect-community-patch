# Visitors in every visitation room

Patch: `patches/visitor-spawn-tables.patch.json`. Uses the code section
(`code-section.md`). GitHub issue #4.

## What you'll notice

One visitor table or booth that no prisoner can be matched with, such as a
booth facing a Protective Custody sector with no Protective Custody prisoners,
could stop visits in the whole prison. With several visitation rooms, the room
the game checked first could also take nearly all visitors while the others
got few or none. With the fix, every room gets visitors.

## What changes

When a visitor arrived, the game tried only the first free visitor table, and
always started looking at the same table. If no prisoner could be matched with
it, the visitor was used up and nobody visited. The game now moves on to the
next table, and each new visitor starts looking one table further along, so
every table gets its turn.

## Status

Tested in game on the reporter's saves:

- The Jailhouse (booths facing a Protective Custody sector): no visits
  without the fix, 13 prisoners visited within one game day with it.
- A prison with Max, Medium and Min Security visitation rooms, booths running
  from wall to wall: before, only the Medium Security room got visitors; with
  the fix all three did, and 14 Max, 18 Medium and 17 Min Security prisoners
  were visited within about ten game hours. The rooms needed no changes.

## Notes

A table that can never be matched still gets no visitors. Check the sector on
the prisoners' side of each booth.
