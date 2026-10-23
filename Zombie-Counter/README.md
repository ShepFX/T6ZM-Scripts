# HUD: zombie counter, run clock and round splits

The Black Ops 2 zombies HUD, drawn like the game's own HUD rather than as a panel:
no boxes or bars, just text in the top-right corner, right-aligned. The top left
is where the game's message feed goes (high round records and every
`iPrintLn`), so the HUD keeps clear of it.

```
                ZOMBIES 24     zombies left this round (alive + still to spawn), red at 5 or fewer
                   ALIVE 9     of those, how many are up on the map right now
                    DOGS 2     only on dog rounds, or while dogs are alive
                     12:34     run clock, the time the speedrun boards use
                   BEST 38     the map's record for the number of players in the game, gold once beaten
            ROUND 12  1:23     the round that just ended, for 6 seconds
```

The run clock takes its start from the speedrun logger (`level.srStart`), so the
clock and the speedrun boards always show the same time. A player who loads in
late sees the same time as everyone else.

BEST reads the records `RoundSaver/T6RoundSaverNew.gsc` loads (`level.highRound*`) and
follows players joining and leaving. Without that script, or with more than 4
players, the row stays hidden.

## Usage

- **`.counter`** hides or shows the counter.
- **`.timer`** hides or shows the clock, BEST and splits.

The clock counts up on the player's own screen in hundredths.


## No leaks

- `settext()` is only ever called with a few fixed strings, registered once at
  map load. Every number goes through `setvalue()`, so a long game can't fill
  the configstring table ("G_FindConfigstringIndex: overflow").
- No background boxes, so fewer HUD elements per player, which leaves room for
  the perk icons. Each player's elements are destroyed when they disconnect.
- One level thread counts the enemies for everyone.

## Installation

Copy `CounterHUD.gsc` into `scripts/zm/`. Plutonium runs its `init()` at map load.
