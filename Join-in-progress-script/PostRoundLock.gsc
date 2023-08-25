#include maps\mp_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm_hud_util;
#include maps\mp\gametypes_zm_hud_message;

init()
{
    SetDvar( "password", "" );
    SetDvar( "g_password", "" );
    level thread SetPasswordsOnRound( 20 );
    level thread onPlayerConnect();
}

onPlayerConnect()
{
    for ( ;; )
    {
        level waittill( "connected", player );
        level.locked = false;
        player thread monitorUnlockInput(player);
    }
}

setPasswordsOnRound( roundNumber )
{
    level endon( "disconnect" );
    
    while ( true ) 
    {
        level waittill( "between_round_over" );
        if ( level.round_number >= roundNumber )
        {
            level.locked = true; // Set lock
            pin = generateString();
            setDvar( "g_password", pin );
            level thread messageRepeat( "Server is now locked. Use password ^5" + pin + " ^7to rejoin. Or Unlock using ^5ADS + 2" );
            break;
        }
    }
}

messageRepeat( message )
{
    level endon( "disconnect" );
    
    while ( true )
    {
        iPrintLn( message );
        level waittill( "between_round_over" );
    }
}

generateString()
{
    str = "";

    for ( i = 0; i < 4; i++ )
    {
        str = str + randomInt( 10 );
    }

    return str;
}

monitorUnlockInput(player)
{
    player endon( "disconnect" );
    
    while ( true )
    {
        if ( level.locked && player adsbuttonpressed() && player ActionSlotTwoButtonPressed() )
        {
            level.locked = false; 
            player iPrintLn( "Lock removed. Server is now unlocked." );
            setDvar( "g_password", "" );
        }
        wait ( 0.1 );
    }
}

