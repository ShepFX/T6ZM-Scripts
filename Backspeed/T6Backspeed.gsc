/**
 * Backspeed fix (T6 / Black Ops 2 Zombies).
 *
 * PC BO2 slows backwards and sideways walking (0.7 / 0.8) compared with
 * console. Speedrun.com allows the fix in normal runs; B2OP sets the same
 * values. The engine resets both dvars on every map load, so they are set
 * here on each one instead of in the server cfg.
 */

init()
{
    setdvar( "player_backSpeedScale", 1 );
    setdvar( "player_strafeSpeedScale", 1 );
}
