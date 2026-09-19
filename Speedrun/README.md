# Speedrun logger for T6 Zombies

Logs how long a game took to reach milestone rounds (10, 20, 30, 40, 50, 70,
100) and to complete the map's main easter egg, so stats.cukservers.net can
show "fastest to round N" and "fastest easter egg" boards per map and squad
size.

## How it works

- The clock starts at the first `start_of_round` notify, which is when round 1
  actually begins after the intro. A game that did not start at round 1 is not
  timed.
- Everyone present before round 2 is the roster, and the run is logged for that
  squad size. Anyone joining from round 2 onward ends timing for the game, so a
  solo run cannot land on the 2P board.
- Easter egg completion is detected from the notify the map's own quest script
  fires on the final step:

| Map | Notify | Board |
|---|---|---|
| TranZit | `transit_sidequest_achieved` | Tower of Babble |
| Die Rise | `highrise_sidequest_achieved` | High Maintenance |
| Mob of the Dead | `pop_goes_the_weasel_achieved` | Pop Goes the Weasel |
| Buried | `sq_maxis_complete` / `sq_richtofen_complete` | Mined Games |
| Origins | `tomb_sidequest_complete` | Little Lost Girl |

Each event appends one line to `logs/Speedrun.txt` beside the RoundSaver's
HighRound files:

```
<runId>|<mapToken>|<kind>|<target>|<ms>|<players>|<id:name,id:name>|<port>
```

## Installation

Copy `T6Speedrun.gsc` into `scripts/zm/` on the server alongside
`T6RoundSaverNew.gsc`. Plutonium runs it automatically at map load.
