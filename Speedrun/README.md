# Speedrun logger for T6 Zombies

Logs how long a game took to reach milestone rounds (10, 20, 30, 40, 50, 70,
100) and to complete the map's main easter egg, so shep.rip can
show "fastest to round N" and "fastest easter egg" boards per map and squad
size.

## How it works

- The run starts when the first player can actually play: their first move or
  button press (fire, aim, use, grenade, melee) after spawning. Time spent
  loading in, or in the fade from black, costs nothing. Standing still doesn't
  hold the clock: it starts 3 seconds after the first spawn at the latest, and
  never before round 1 begins. A game that did not start at round 1 is not
  timed.
- Everyone in the game from round 1 is the roster; anyone joining from round 2
  onward ends timing for the game. A roster member who drops and rejoins stays
  on it.
- Round boards count the squad still in when round 2 starts, so a round-1 leaver
  who gets replaced never makes a 5-player run. Easter eggs also count round-1
  leavers who stayed at least a minute (up to 4 players). Round 1 can be stalled
  for as long as a squad likes, so without this a helper could do every step but
  the last and leave, putting a squad's egg on the solo board.
- Easter egg completion is detected from the notify the map's own quest script
  fires on the final step:

| Map | Notify | Board |
|---|---|---|
| TranZit | `transit_sidequest_achieved` | Tower of Babble |
| Die Rise | `highrise_sidequest_achieved` | High Maintenance |
| Mob of the Dead | `stage_final`, then `level.winner` set | Pop Goes the Weasel |
| Buried | `sq_maxis_complete` / `sq_richtofen_complete` | Mined Games |
| Origins | `tomb_sidequest_complete` | Little Lost Girl |

Song and side easter eggs are timed as well, and so is the buyable ending on the
Stairway to Hell port.

Each event appends one line to `logs/Speedrun.txt` beside the RoundSaver's
HighRound files:

```
<runId>|<mapToken>|<kind>|<target>|<ms>|<players>|<id:name,id:name>|<port>
```

## Installation

Copy `T6Speedrun.gsc` into `scripts/zm/` on the server alongside
`T6RoundSaverNew.gsc`. Plutonium runs it automatically at map load.

Mob of the Dead is the exception to "use the achievement's notify". Its
`pop_goes_the_weasel_achieved` fires when the bridge showdown *starts*, and only
in the co-op branch - solo, or a bridge with nobody to fight, never sends it.
The logger waits for `stage_final` and then for `level.winner`, which both
endings set once they are decided, so both endings and solo runs are timed at
the real finish.
