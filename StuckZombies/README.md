# Stuck zombie watchdog

A zombie that stays in one spot for 3 minutes is respawned: removed without
points or kill credit and put back into the round's queue, so it comes in again
from a normal spawner. Zombies that move are never touched.

Players were wedging the last zombies of a round into window barriers to stall
the round and take breaks, which got around the AFK system. The game's own
failsafe misses these zombies because it only compares positions 30 seconds
apart and skips any zombie that recently tore at a board.

"One spot" means never more than 128 units from where the watch started, so
shuffling back and forth in a barrier still counts. Only ordinary zombies are
watched; dogs and other special enemies keep their own behaviour.

Every respawn is logged to the games log as `STUCKZOMBIE;<map>;<round>;<pos>`.

## Installation

Copy `T6StuckZombies.gsc` to ``storage/t6/scripts/zm/``.
