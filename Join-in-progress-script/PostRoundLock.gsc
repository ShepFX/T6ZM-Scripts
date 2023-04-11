
#include maps\mp_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm_hud_util;
#include maps\mp\gametypes_zm_hud_message;


Init()
{
    SetDvar("password", "");
    SetDvar("g_password", "");

    level thread SetPasswordsOnRound(10);
}

SetPasswordsOnRound(roundNumber)
{
  while ( true )
  {
    level waittill( "between_round_over");

    if (level.round_number >= roundNumber)
    {
        SetDvar("password", "Fucker");
        SetDvar("g_password", "Fucker");
        break;
    }
  }
}
