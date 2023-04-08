#include maps\mp_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm_hud_util;
#include maps\mp\gametypes_zm_hud_message;

init()
{
    level thread onPlayerConnect();
    self endon("disconnect");
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread checkfucker();
    }
}

checkfucker()
{
    if ( level.round_number < 10 ) return;
    self IPrintLnBold( "^5No joining in progress! After Round 10 Bozo" );
    wait 2;
    kick( self GetEntityNumber() );
}
