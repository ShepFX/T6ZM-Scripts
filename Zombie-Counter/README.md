# Enemy Counter + Round Timer HUD for T6 Zombies

This GSC script adds a clean, stacked HUD to Black Ops 2 (T6) Zombies. It combines the enemy counter with a lightweight round timer and split display.

## Features

- Real-time enemy counter for zombies, Hellhounds, and currently spawned enemies.
- Dynamic dog row that appears only during dog rounds or active Hellhound spawns.
- End-of-round warning color when 5 or fewer zombies remain.
- Round timer panel styled to match the enemy counter.
- Current round timer plus the previous two completed round splits.
- Per-player counter preference saved to `scriptdata/zc_prefs.txt`.
- Separate chat toggles for the counter, timer, or both panels.

## Commands

```text
.counter  Toggle only the enemy counter
.timer    Toggle only the round timer/splits panel
.hud      Toggle both panels together
```

## Installation

1. Place `CounterHUD.gsc` with your other custom T6 Zombies scripts.
2. Load the script through your GSC injector or server script configuration.
3. Call the script init from your loaded script path, adjusted to wherever you place it:

```gsc
maps\zm\CounterHUD::init();
```

If you rename the file or place it in a different script folder, update the call path to match.

## HUD Layout

| Panel | Rows |
| :--- | :--- |
| Enemy counter | `ZOMBIES`, optional `DOGS`, `SPAWNED` |
| Splits | current round, last round split, previous split |

The timer panel is the same width and style as the counter panel, and it automatically moves down when the dog row expands the counter.

## Configuration

The default visual style uses:

- Accent color: `(1.00, 0.55, 0.05)`
- Background alpha: `0.72`
- Counter refresh rate: `0.1` seconds
- Timer source: T6 `start_of_round` / `end_of_round` notifications
