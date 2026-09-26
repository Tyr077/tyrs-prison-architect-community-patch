# Shops without prisoners inside

Patch: `patches/shop-front.patch.json`. Uses the code section
(`code-section.md`).

## What you'll notice

Prisoners could only buy from a shop front if they could walk into the shop and
were allowed in it. With the fix they buy from the other side of the counter,
so the shop front can face a hallway and the shop can stay off limits to
customers.

## What changes

When a prisoner cannot reach the shop front's own tile, or is not allowed
there, the game now also accepts a tile next to it that the prisoner can reach
and is allowed on. Only objects built into a wall, such as the shop front, are
affected.

## Status

Not yet tested in game.
