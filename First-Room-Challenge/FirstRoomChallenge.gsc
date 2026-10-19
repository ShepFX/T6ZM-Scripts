// T6 ZM - First Room Challenge
// Keeps wall weapons usable, but blocks doors/debris/airlock buys.
// Load this script and call maps\mp\T6FirstRoomChallenge::init().

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

    if ( getdvar( "mapname" ) == "zm_tomb" )
        level thread frc_lock_tank();

    // Die Rise: only the starting pistol and wall weapons; any other gun is a true death.
    if ( getdvar( "mapname" ) == "zm_highrise" )
        level thread frc_weapon_rule_init();

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

        if ( isdefined( level.frc_weapon_rule ) && level.frc_weapon_rule )
            player thread frc_weapon_watch();
    }
}

frc_intro_message()
{
    self endon( "disconnect" );
    self waittill( "spawned_player" );
    wait 2;

    if ( isdefined( level.frc_enabled ) && level.frc_enabled )
        self iprintlnbold( "^3First Room Challenge^7: doors are locked, wall weapons allowed." );

    if ( isdefined( level.frc_weapon_rule ) && level.frc_weapon_rule )
    {
        wait 4;
        self iprintlnbold( "^1Pistol and wall weapons only^7: any other gun kills you." );
    }
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

    // Die Rise: the escape pod in spawn drops to the ground once everyone stands in it.
    // With its trigger moved away nobody counts as inside, so it stays at the top and
    // keeps the shaft blocked (the shaft kill trigger stays on while the pod is up).
    pod = getent( "escape_pod_trigger", "targetname" );
    if ( isdefined( pod ) && !( isdefined( pod.trigger_off ) && pod.trigger_off ) )
    {
        pod trigger_off();
        logprint( "FRC escape pod locked\n" );
    }
}

// Die Rise weapon rule. The allowed list is the starting pistol plus every wall-buy
// weapon the map spawned, read from the map itself. Only guns are checked
// (GetWeaponsListPrimaries), so knife, grenades, claymores and Trample Steam are fine.
frc_weapon_rule_init()
{
    level.frc_weapon_rule = true;
    level.frc_allowed = [];

    start = "m1911_zm";
    if ( isdefined( level.start_weapon ) )
        start = level.start_weapon;
    level.frc_allowed[ level.frc_allowed.size ] = start;

    // Read the wall-buys once the map has loaded, and again when the game starts.
    wait 2;
    frc_read_wallbuys();
    flag_wait( "start_zombie_round_logic" );
    frc_read_wallbuys();
}

frc_read_wallbuys()
{
    spots = getstructarray( "weapon_upgrade", "targetname" );
    for ( i = 0; i < spots.size; i++ )
        frc_allow( spots[i].zombie_weapon_upgrade );

    trigs = getentarray( "weapon_upgrade", "targetname" );
    for ( i = 0; i < trigs.size; i++ )
        frc_allow( trigs[i].zombie_weapon_upgrade );

    list = "";
    for ( i = 0; i < level.frc_allowed.size; i++ )
        list = list + " " + level.frc_allowed[i];
    logprint( "FRC weapon rule on, allowed:" + list + "\n" );
}

frc_allow( weapon )
{
    if ( !isdefined( weapon ) || weapon == "" )
        return;

    for ( i = 0; i < level.frc_allowed.size; i++ )
    {
        if ( level.frc_allowed[i] == weapon )
            return;
    }

    level.frc_allowed[ level.frc_allowed.size ] = weapon;
}

frc_weapon_allowed( weapon )
{
    if ( !isdefined( weapon ) || weapon == "none" || weapon == "" )
        return true;

    // Hands and props the game gives you for a moment (perk bottles, revive, buying).
    if ( issubstr( weapon, "zombie_" ) || issubstr( weapon, "syrette" ) || issubstr( weapon, "equip_" )
        || issubstr( weapon, "_bottle" ) || issubstr( weapon, "knuckle" ) || issubstr( weapon, "chalk" ) )
        return true;

    for ( i = 0; i < level.frc_allowed.size; i++ )
    {
        if ( level.frc_allowed[i] == weapon )
            return true;
    }

    return false;
}

frc_weapon_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    self waittill( "spawned_player" );
    flag_wait( "start_zombie_round_logic" );

    for ( ;; )
    {
        wait 0.5;

        if ( !isalive( self ) || self.sessionstate != "playing" || isdefined( self.frc_punished ) )
            continue;
        if ( self maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
            continue;
        if ( isdefined( self.is_drinking ) && self.is_drinking > 0 )
            continue;

        guns = self getweaponslistprimaries();
        for ( i = 0; i < guns.size; i++ )
        {
            if ( !frc_weapon_allowed( guns[i] ) )
            {
                self thread frc_punish( guns[i] );
                break;
            }
        }
    }
}

// True death: take the gun, strip Who's Who and Quick Revive so nothing saves them,
// down them, then bleed them out at once.
frc_punish( weapon )
{
    self endon( "disconnect" );
    self.frc_punished = true;

    self takeweapon( weapon );
    logprint( "FRC banned weapon;" + self.name + ";" + weapon + "\n" );
    iprintln( "^1" + self.name + " ^7was killed for using a non-wall weapon." );

    if ( self hasperk( "specialty_finalstand" ) )
        self notify( "specialty_finalstand_stop" );
    if ( self hasperk( "specialty_quickrevive" ) )
        self notify( "specialty_quickrevive_stop" );
    self.lives = 0;
    wait 0.1;
    self unsetperk( "specialty_finalstand" );
    self unsetperk( "specialty_quickrevive" );

    if ( !self maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
    {
        self disableinvulnerability();
        self dodamage( self.health + 10000, self.origin );
    }

    for ( i = 0; i < 20; i++ )
    {
        wait 0.1;
        if ( self maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
        {
            self.bleedout_time = 0;
            break;
        }
    }

    wait 3;
    self.frc_punished = undefined;
}

// Origins: the tank cannot reach spawn, but keep it parked anyway. Both the ride
// trigger and the station call boxes refuse while tank_cooldown is set, and only a
// finished ride clears it.
frc_lock_tank()
{
    level endon( "end_game" );

    flag_wait( "start_zombie_round_logic" );
    wait 1;

    if ( !isdefined( level.vh_tank ) || !isdefined( level.vh_tank.ent_flag ) || !isdefined( level.vh_tank.ent_flag["tank_cooldown"] ) )
    {
        logprint( "FRC tank not found\n" );
        return;
    }

    // The ride trigger is linked to the tank, so it is left in place; the flag alone blocks it.
    level.vh_tank maps\mp\zombies\_zm_utility::ent_flag_set( "tank_cooldown" );

    frc_disable_ent_array( getentarray( "trig_tank_station_call", "targetname" ) );
    logprint( "FRC tank locked\n" );
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
