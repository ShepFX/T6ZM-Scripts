#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm_utility;

init()
{
    level thread CreateCounter();
    for(;;)
    {
        level waittill("connected", player);
        player thread Begin();
    }
}

Begin()
{
    self endon("disconnect");
    self waittill("spawned_player");
    wait 7;
	
}

CreateCounter()
{
    level.zombiesCounter = createServerFontString("hudsmall" , 1.2);
    level.zombiesCounter setPoint("RIGHT", "RIGHT", "RIGHT", 220);
    while(true)
    {
    	enemies = get_round_enemy_array().size + level.zombie_total;
        if( enemies != 0 )
        	level.zombiesCounter.label = &"Zombies: ^1";
        else
        	level.zombiesCounter.label = &"Zombies: ^6";
        level.zombiesCounter setValue( enemies );
        wait 0.05;
    }
}
