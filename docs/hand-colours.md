# Hand colours for characters (modding extension)

| id | tier | since |
|---|---|---|
| `hands.colours` | experimental | 1.20.0 |

Setting up detection in general: [Modding extensions](modding-api.md).

## What it adds

A character's hands are one shared hand sprite, tinted with a skin colour the
game picks. Ten staff types get a colour per sprite variant from a list built
into the game. Every other type gets the same light skin colour, and so does
every character a mod adds, whatever its sprite looks like. With this extension
a mod can set the hand colour of any character type, per sprite variant, with a
`HandColours` block in `materials.txt`.

## Detect it

Nothing to set up in `materials.txt`: a game without the extension ignores the
block, and hands look as before. To check from a script:

```lua
local HasHandColours = TyrsPatch ~= nil and TyrsPatch.Has("hands.colours")
```

## How to use it

One block per object:

- `Object` names the character type (`Name` in its `Object` block).
- Each `Colour` line is one sprite variant (`SubType`), in order: the first line
  is SubType 0, the next SubType 1, and so on. A type has as many variants as
  its `SpriteVariants`.
- `All` covers every variant that has no `Colour` line of its own.

Colours are written `0xAARRGGBB`. For example, these bright colours are easy
to spot in game: every guard variant gets its own, and armed guards get yellow
hands for variant 0 and dark gloves for the rest.

```
BEGIN HandColours
    Object       Guard
    Colour       0xFFFF0000
    Colour       0xFF00FF00
    Colour       0xFF0000FF
    Colour       0xFFFF00FF
END

BEGIN HandColours
    Object       ArmedGuard
    Colour       0xFFFFFF00
    All          0xFF202020
END
```

To fix the hands of a few variants and keep the rest, copy the type's defaults
from the list below and change the lines you need. A mod that adds variants
(`SpriteVariants 8`, say) lists eight `Colour` lines.

## Rules

- Put the block **after** the `Object` it names: in the same file below it, or
  in a mod that loads later. Vanilla objects can be named anywhere. A block
  naming an object that isn't defined yet is skipped, with a line in
  `debug.txt`.
- When several blocks name the same object (from different mods, say), the
  later one wins for each variant it sets. A `Colour` line for a variant beats
  an `All` line.
- A line whose value isn't a colour is skipped with no message, but it still
  takes its variant's place, so the lines after it keep their variants.
- Write colours as `0xAARRGGBB`. A plain number only works up to `2147483647`.
- The alpha byte is passed to the game as written. Only `FF` has been tested.
- Up to 1024 `Colour` and `All` lines across all mods.

## What else changes

These follow from where the colour is set, read from the game's code:

- Prisoners, visitors and a few others have a skin colour of their own. A block
  for their type replaces it, for every one of them. Prisoners' heads appear
  to use the same colour, so they would change too (not looked at in game).
- Frigid and heatstroke still tint the hands on top of the colour.
- Zombies take the hand colour of the character they look like from the game's
  list. This block doesn't change them.

## Default colours

The colours the game uses. In the same form, ready to copy:

```
BEGIN HandColours
    Object       Workman
    Colour       0xFFFDC689
    Colour       0xFF925D36
    Colour       0xFFCB946C
    Colour       0xFF925D36
END

BEGIN HandColours
    Object       Guard
    Colour       0xFFFDC689
    Colour       0xFFCB946C
    Colour       0xFF925D36
    Colour       0xFF925D36
END

BEGIN HandColours
    Object       ArmedGuard
    Colour       0xFFEB8F17
    Colour       0xFFF3AC47
    Colour       0xFF5C3816
    Colour       0xFFFDC689
END

BEGIN HandColours
    Object       Cook
    Colour       0xFFFDC689
    Colour       0xFFCB946C
    Colour       0xFF925D36
    Colour       0xFFFDC689
END

BEGIN HandColours
    Object       Gardener
    Colour       0xFFFDC689
    Colour       0xFFEB8F17
    Colour       0xFF925D36
    Colour       0xFFEB8F17
END

BEGIN HandColours
    Object       Janitor
    Colour       0xFFFDC689
    Colour       0xFFCB946C
    Colour       0xFF925D36
    Colour       0xFF925D36
END

BEGIN HandColours
    Object       DogHandler
    Colour       0xFFFDC689
    Colour       0xFF925D36
    Colour       0xFFC5793B
    Colour       0xFFEB8F17
END

BEGIN HandColours
    Object       Teacher
    Colour       0xFFFDC689
    Colour       0xFFFDC689
    Colour       0xFF925D36
    Colour       0xFFFDC689
END

BEGIN HandColours
    Object       Soldier
    Colour       0xFFF3AC47
    Colour       0xFF8B5827
    Colour       0xFFFDC689
    Colour       0xFFFDC689
END

BEGIN HandColours
    Object       Sniper
    Colour       0xFF925D36
    Colour       0xFFFDC689
    Colour       0xFFFDC689
    Colour       0xFFFDAC89
END
```

Every other type, and every type a mod adds, uses `0xFFFDC689` for all
variants. Exceptions, read from the game's code and not looked at in game:

- Doctor, Chief and Farmer use `0xFFFDC689`, except with their hands up
  (surrendering or running in fear), when the game uses Doctor `0xFFFDC689`,
  `0xFF925D36`, `0xFFEB8F17`, `0xFFFDC689`; Chief `0xFFFDC689`; Farmer
  `0xFF694521`, `0xFFD38C60`, `0xFFF78881`, `0xFFFFB09E`. A `HandColours`
  block for them sets both.
- The Warden uses `0xFFFDC689`, except for two of the wardens you can pick,
  which have `0xFF8B4E2D` and `0xFF654537`.
- Variants above 3 (a mod that raises `SpriteVariants`): Workman `0xFFCB946C`,
  Guard, Janitor and Gardener `0xFF925D36`, Sniper `0xFFFDAC89`, the others
  `0xFFFDC689`.

The Guard, ArmedGuard and Janitor colours were also seen in game; the rest of
the list is read from the game's code.

## Changes

- 1.0.0 (patch 1.20.0): first version.

## Status

Tested in game on 2026-11-22 in a riot, with the example above plus blocks for
Janitor and Prisoner. With the extension, every guard and armed guard drawn had
the colour for its variant, Janitor variant 1 had its colour after an
unparsable first line, prisoners had their block's colour, also with their hands
up, and a block naming an unknown object and one without an `Object` line were
each reported in `debug.txt`. Without the extension the blocks were ignored and
hands kept the game's colours.

Patch: `patches/hand-colours.patch.json`. Uses the code section
(`code-section.md`).
