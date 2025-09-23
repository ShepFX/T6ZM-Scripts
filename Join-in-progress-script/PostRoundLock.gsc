#include maps\mp_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm_hud_util;
#include maps\mp\gametypes_zm_hud_message;

init()
{
    // Config
    level.min_lock_round = 20; // round at which the lock system becomes active

    // State
    level.locked = false;
    level.pin = "";
    level.lock_initialized = false;

    // Reset dvars on script start
    SetDvar( "password", "" );
    SetDvar( "g_password", "" );

    // Threads
    level thread onPlayerConnect();
    level thread roundMonitor();

    // Chat listeners at level scope (param order: text, player)
    level thread listenForChatCommands();      // "say"
    level thread listenForTeamChatCommands();  // "say_team"
}

onPlayerConnect()
{
    for ( ;; )
    {
        level waittill( "connected", player );

        // ADS + 2 input toggle
        player thread monitorUnlockInput();
    }
}

// Round transitions -> announce state
roundMonitor()
{
    level endon( "disconnect" );

    for ( ;; )
    {
        level waittill( "between_round_over" );

        // First time we reach threshold -> auto-lock
        if ( isRoundLockActive() && !level.lock_initialized )
        {
            level.lock_initialized = true;
            level.locked = true;
            level.pin = generatePin();
            SetDvar( "g_password", level.pin );
            SetDvar( "password", level.pin );
        }

        if ( !level.lock_initialized )
            continue;

        if ( level.locked )
        {
            if ( !isDefined( level.pin ) || level.pin == "" )
                level.pin = generatePin();

            SetDvar( "g_password", level.pin );
            SetDvar( "password", level.pin );

            announceAll( getLockedMessage() );
        }
        else
        {
            SetDvar( "g_password", "" );
            SetDvar( "password", "" );

            announceAll( getUnlockedMessage() );
        }
    }
}

// ADS + 2 to toggle
monitorUnlockInput()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        if ( self adsbuttonpressed() && self ActionSlotTwoButtonPressed() )
        {
            setLocked( !level.locked, self );
            wait( 0.4 ); // debounce
        }
        wait( 0.05 );
    }
}

// Level-scope chat listener: global chat
listenForChatCommands()
{
    level endon( "disconnect" );

    for ( ;; )
    {
        level waittill( "say", text, player );

        if ( !isDefined( text ) || !isDefined( player ) )
            continue;

        if ( text == ".unlock" )
        {
            setLocked( false, player );
        }
        else if ( text == ".lock" )
        {
            setLocked( true, player );
        }
    }
}

// Level-scope chat listener: team chat
listenForTeamChatCommands()
{
    level endon( "disconnect" );

    for ( ;; )
    {
        level waittill( "say_team", text, player );

        if ( !isDefined( text ) || !isDefined( player ) )
            continue;

        if ( text == ".unlock" )
        {
            setLocked( false, player );
        }
        else if ( text == ".lock" )
        {
            setLocked( true, player );
        }
    }
}

// Set lock state and announce via kill feed.
// actor: optional player who triggered the change.
setLocked( shouldLock, actor )
{
    actorName = getActorName( actor );

    // Block locking until the minimum round is reached
    if ( shouldLock && !isRoundLockActive() )
    {
        if ( isDefined( actor ) )
            actor iPrintLn( "^3Locking is disabled until round ^5" + level.min_lock_round );
        return;
    }

    if ( shouldLock )
    {
        level.lock_initialized = true;
        level.locked = true;
        level.pin = generatePin();

        SetDvar( "g_password", level.pin );
        SetDvar( "password", level.pin );

        announceAll( actorName + " ^7locked the server. Password ^5" + level.pin );
    }
    else
    {
        level.locked = false;

        SetDvar( "g_password", "" );
        SetDvar( "password", "" );

        announceAll( actorName + " ^7unlocked the server." );
    }
}

// Helpers

isRoundLockActive()
{
    return isDefined( level.round_number ) && level.round_number >= level.min_lock_round;
}

getLockedMessage()
{
    return "Server is now ^1LOCKED^7. Use password ^5" + level.pin + " ^7to rejoin. Unlock with ^5ADS + 2^7 or type ^5.unlock^7";
}

getUnlockedMessage()
{
    return "Server remains ^2unlocked^7 - to lock again do ^5.lock^7 (or press ^5ADS + 2^7)";
}

// Broadcast to all players via kill feed
announceAll( message )
{
    players = getPlayersSafe();
    for ( i = 0; i < players.size; i++ )
        players[i] iPrintLn( message );
}

// Safe actor name
getActorName( actor )
{
    if ( isDefined( actor ) && isDefined( actor.name ) )
        return actor.name;
    return "Someone";
}

// 4-digit PIN
generatePin()
{
    str = "";
    for ( i = 0; i < 4; i++ )
        str = str + randomInt( 10 );
    return str;
}

// Safe players array getter
getPlayersSafe()
{
    if ( isDefined( level.players ) )
        return level.players;

    return getEntArray( "player", "classname" );
}
