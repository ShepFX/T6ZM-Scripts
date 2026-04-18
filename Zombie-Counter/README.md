# zm_zombie_counter — T6 Zombies Enemy Tracker

A lightweight HUD overlay for **Plutonium T6 Zombies** that displays live enemy counts in a compact panel pinned to the top-left of the screen.

---

## Installation

1. Copy `zm_zombie_counter.gsc` into your Plutonium scripts folder:
   ```
   %localappdata%\Plutonium\storage\t6\scripts\zm\
   ```
2. Launch the game — Plutonium automatically calls `init()` on every GSC file in that folder. No map edits or extra configuration required.

---

## Display

```
┌─────────────────────┐█
│  ENEMY TRACKER      │█
│  ─────────────────  │█
│  ZOMBIES  24        │█
│  SPAWNED  3         │█
└─────────────────────┘█
```

| Row | What it shows |
|-----|--------------|
| **ZOMBIES** | Total enemies remaining this round — alive on the map **plus** those still queued to spawn |
| **SPAWNED** | Enemies currently alive and active on the map right now |
| **DOGS** | Total hellhounds remaining (alive + queued). Row only appears during dog rounds and fades out when the round ends |

The difference between ZOMBIES and SPAWNED is the number of zombies not yet spawned in. For example, **ZOMBIES 8 / SPAWNED 2** means 8 left to kill overall, but only 2 are currently walking around.

### Colour coding

- **ZOMBIES** turns red when 5 or fewer remain
- **DOGS** row is always amber/gold
- **SPAWNED** is always green
- Numbers pulse briefly whenever the value changes

---

## Compatibility

- **Platform:** Plutonium T6 (Black Ops 2 Zombies)
- **Modes:** All standard ZM maps (Classic, Grief, Turned, etc.)
- **Players:** Works in solo and co-op — each player gets their own HUD instance
- **Maps:** No map-specific dependencies; works on any map that uses the standard ZM spawner

---

## Notes

- The counter reads directly from `level.zombie_total` and `get_round_enemy_array()` — the same sources the game itself uses, so counts are always accurate
- Dog round detection uses `level.dog_intermission`; the DOGS row and panel expand automatically when a dog round starts and collapse when it ends
- The overlay stays visible while dead (`hidewhendead = 0`) and is hidden when a menu is open (`hidewheninmenu = 0` set to keep it from cluttering the pause screen — change to `1` if preferred)
