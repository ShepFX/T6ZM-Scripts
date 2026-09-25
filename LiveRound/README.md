# Live round reporter

Publishes the round currently being played so the website and IW4MAdmin can
show it while a game is running.

Two outputs, both updated on a round change and refreshed once a minute so a
stale file left by a crashed server is distinguishable from a live game:

- **A file** (`currentround.txt` on T5, `CurrentRound.txt` on T6) read by
  stats.cukservers.net: `<round>|<players>|<port>|<hostname>|<map>`
- **A dvar** `cuk_round`, read by IW4MAdmin over rcon on its normal status
  poll, which is what puts "Round N" on the webfront server cards.

The dvar exists because the round is otherwise invisible outside the game: it
is a script variable rather than a dvar, it is absent from the server status
response, and the game log never records a round change.

Both outputs are cleared at game end so a finished game stops displaying.

## Installation

Copy the script into `raw/scripts/sp/` (T5) or `scripts/zm/` (T6). Plutonium
runs it automatically at map load.
