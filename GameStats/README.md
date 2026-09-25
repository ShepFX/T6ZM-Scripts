# Game stats logger

Appends one line per player per game to `logs/GameStats.txt`, recording what they
actually did: kills, headshots, downs, revives, bleed-outs and points.

A player's line is written when they leave, and for everyone still in when the
game ends, so every session is counted exactly once and nobody is double
counted for reconnecting.

Each line carries a `runId` shared by everyone in that game, so the rows for a
single game can be grouped back together, plus the server port — folder names
and server names do not reliably match, but a port is unique.

## Installation

Copy `T6GameStats.gsc` into ``scripts/zm/``. Plutonium runs it at map load.

Deployed as `T6GameStats.gsc` on 11 T6 zombie servers.
