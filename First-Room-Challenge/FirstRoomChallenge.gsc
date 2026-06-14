// T6 ZM - First Room Challenge
// Keeps wall weapons usable, but blocks doors/debris/airlock buys.
// Load this script and call maps\mp\FirstRoomChallenge::init().

#include common_scripts\utility;
#include maps\mp\_utility;

main()
{
    init();
}

init()
{
    if ( isdefined( level.frc_initialized ) && level.frc_initialized )
        return;

    level.frc_initialized = true;
    level.frc_enabled = true;
    level.frc_deny_hint = "First Room Challenge: doors are disabled.";

    // door_buy() in _zm_blockers checks this before score/force handling.
    level.custom_door_buy_check = ::frc_door_buy_check;

    level thread frc_disable_blocker_loop();
    level thread frc_chat_listener();
    level thread frc_player_connect();

    println( "[FIRST ROOM] challenge initialized" );
}

frc_player_connect()
{
    level endon( "end_game" );
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread frc_intro_message();
    }
}

frc_intro_message()
{
    self endon( "disconnect" );
    self waittill( "spawned_player" );
    wait 2;

    if ( isdefined( level.frc_enabled ) && level.frc_enabled )
        self iprintlnbold( "^3First Room Challenge^7: doors are locked, wall weapons allowed." );
}

frc_chat_listener()
{
    level endon( "end_game" );
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "say", text, player );

        if ( !isdefined( text ) || !isdefined( player ) )
            continue;

        command = frc_sanitize( text );

        if ( command == ".firstroom" || command == ".frc" )
        {
            if ( level.frc_enabled )
                player iprintlnbold( "^3First Room Challenge^7 is ON: no doors/debris, wall weapons allowed." );
            else
                player iprintlnbold( "^3First Room Challenge^7 is OFF." );
        }
    }
}

frc_door_buy_check( door )
{
    if ( !isdefined( level.frc_enabled ) || !level.frc_enabled )
        return true;

    self frc_deny_feedback();
    return false;
}

frc_disable_blocker_loop()
{
    level endon( "end_game" );
    level endon( "game_ended" );

    // Let stock blocker init build hints/links first, then suppress buys.
    wait 2;

    for ( ;; )
    {
        if ( isdefined( level.frc_enabled ) && level.frc_enabled )
            frc_disable_buyable_blockers();

        wait 1;
    }
}

frc_disable_buyable_blockers()
{
    frc_disable_ent_array( getentarray( "zombie_door", "targetname" ) );
    frc_disable_ent_array( getentarray( "zombie_debris", "targetname" ) );
    frc_disable_ent_array( getentarray( "zombie_airlock_buy", "targetname" ) );
}

frc_disable_ent_array( ents )
{
    if ( !isdefined( ents ) )
        return;

    for ( i = 0; i < ents.size; i++ )
        frc_disable_trigger( ents[i] );
}

frc_disable_trigger( ent )
{
    if ( !isdefined( ent ) )
        return;

    ent setcursorhint( "HINT_NOICON" );
    ent sethintstring( level.frc_deny_hint );

    // trigger_off keeps the blocker physically present but non-buyable.
    ent trigger_off();
}

frc_deny_feedback()
{
    if ( !isdefined( self ) || !isplayer( self ) )
        return;

    self iprintln( "^1Doors are disabled for First Room Challenge." );
    self playsound( "no_purchase" );
}

frc_sanitize( text )
{
    if ( !isdefined( text ) )
        return "";

    for ( i = 0; i < 64; i++ )
    {
        if ( text == "" )
            return "";

        first = getSubStr( text, 0, 1 );
        if ( first == " " || first == "\t" )
        {
            text = getSubStr( text, 1, 1024 );
            continue;
        }

        break;
    }

    return text;
}
