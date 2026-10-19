# Backspeed fix

PC Black Ops II slows you down more than console does when you walk backwards
(`player_backSpeedScale` 0.7) or sideways (`player_strafeSpeedScale` 0.8). This
sets both to 1.0, the console values and the same ones the B2OP record patch
uses. speedrun.com allows the backspeed fix in normal (unpatched) runs.

The engine resets both dvars on every map load, so a `set` in the server cfg or
over RCON only lasts until the next map. The script sets them again on each
load. Players don't need to install anything.

## Installation

Copy `T6Backspeed.gsc` to `storage/t6/scripts/zm/`.
