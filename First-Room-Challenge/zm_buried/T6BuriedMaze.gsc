// T6 ZM - Buried Maze First Room
// Players start at the maze fountain. Each game 3 of 5 wall-buy spots get a random gun each. A solid wall
// closes the path to the witch's house; leaving the area puts you back (no instant death); the maze
// hedges reshuffle every 5th round.
// Only does anything on zm_buried. Runs next to T6FirstRoomChallenge.gsc (which locks doors/debris).
// Positions are the owner's .pos readings (17 Oct 2026).

#include common_scripts\utility;
#include maps\mp\_utility;

init()
{
    if ( getdvar( "mapname" ) != "zm_buried" )
        return;

    level.bmz_spawns = [];
    level.bmz_spawns[0] = spawnstruct(); level.bmz_spawns[0].origin = ( 4785, 437, 4 );  level.bmz_spawns[0].yaw = 83;
    level.bmz_spawns[1] = spawnstruct(); level.bmz_spawns[1].origin = ( 4745, 704, 4 );  level.bmz_spawns[1].yaw = 320;
    level.bmz_spawns[2] = spawnstruct(); level.bmz_spawns[2].origin = ( 5044, 699, 12 ); level.bmz_spawns[2].yaw = 213;
    level.bmz_spawns[3] = spawnstruct(); level.bmz_spawns[3].origin = ( 5060, 464, 15 ); level.bmz_spawns[3].yaw = 172;

    // walking out of the area puts you back (a hard wall) instead of the stock instant death;
    // the map's real kill brushes (pits) still kill
    level.player_out_of_playable_area_monitor_callback = ::bmz_oob_should_kill;

    level thread bmz_player_connect();
    level thread bmz_setup_zones();
    level thread bmz_maze_shuffle();
    // owner's gun1..gun5 spots (17 Oct)
    level.bmz_gun_spots = array( ( 4412, 564, -18 ), ( 4699, 1264, -9 ), ( 5260, 749, -4 ), ( 4177, -118, -3 ), ( 3988, 49, -7 ) );
    level thread bmz_random_wallbuys( 3 );
    // owner's block1 -> block2: the way to the witch's house
    level thread bmz_wall( ( 3608, 912, -3 ), ( 3860, 1001, -11 ) );

    logprint( "BMZ buried maze first room initialized\n" );
}

// ---------- spawning ----------

bmz_player_connect()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread bmz_on_spawn();
        player thread bmz_barrier();
    }
}

// ---------- hard barrier ----------

bmz_oob_should_kill()
{
    return self maps\mp\zombies\_zm::in_kill_brush();
}

// Remembers where the player last stood inside the enabled zones and snaps them back there the
// moment they leave, so the area's edge behaves like a wall.
bmz_barrier()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    while ( !isdefined( level.bmz_ready ) )
        wait 0.1;

    for ( ;; )
    {
        wait 0.1;

        if ( self.sessionstate != "playing" || self isinmovemode( "ufo", "noclip" ) )
        {
            self.bmz_last_good = undefined;
            continue;
        }

        if ( self maps\mp\zombies\_zm::in_life_brush() || self maps\mp\zombies\_zm::in_enabled_playable_area() )
        {
            if ( self isonground() )
                self.bmz_last_good = self.origin;
            continue;
        }

        if ( isdefined( self.bmz_last_good ) )
        {
            self setorigin( self.bmz_last_good );
            self setvelocity( ( 0, 0, 0 ) );
        }
        else
            self bmz_put_at_fountain();
    }
}

bmz_on_spawn()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "spawned_player" );
        // the fountain only counts as in bounds once the maze zones are on, or the
        // out-of-playable-area check kills the player at once
        while ( !isdefined( level.bmz_ready ) )
            wait 0.05;
        wait 0.05;
        self bmz_put_at_fountain();
    }
}

bmz_put_at_fountain()
{
    // each player gets their own spot (by entity number) so nobody spawns inside another
    s = level.bmz_spawns[ self getentitynumber() % level.bmz_spawns.size ];
    self setorigin( s.origin );
    self setplayerangles( ( 0, s.yaw, 0 ) );
}

// ---------- zombie spawning ----------

// Switch on the zones the fountain spawns and the shrine sit in. Needed twice over: the
// out-of-playable-area check only accepts enabled zones, and zombies only spawn in them.
// Done as soon as the zone manager has built level.zones, before players are moved there.
bmz_setup_zones()
{
    level endon( "end_game" );

    while ( !isdefined( level.zones ) || level.zones.size == 0 )
        wait 0.05;
    wait 0.1;

    points = [];
    for ( i = 0; i < level.bmz_spawns.size; i++ )
        points[ points.size ] = level.bmz_spawns[i].origin;
    for ( i = 0; i < level.bmz_gun_spots.size; i++ )
        points[ points.size ] = level.bmz_gun_spots[i];

    level.bmz_zones = [];
    for ( i = 0; i < points.size; i++ )
    {
        z = maps\mp\zombies\_zm_zonemgr::get_zone_from_position( points[i], 1 );
        if ( isdefined( z ) && !isinarray( level.bmz_zones, z ) )
            level.bmz_zones[ level.bmz_zones.size ] = z;
    }

    list = "";
    for ( i = 0; i < level.bmz_zones.size; i++ )
    {
        list = list + " " + level.bmz_zones[i];
        maps\mp\zombies\_zm_zonemgr::enable_zone( level.bmz_zones[i] );
    }
    logprint( "BMZ enabled zones:" + list + "\n" );
    println( "BMZ enabled zones:" + list );
    level.bmz_ready = true;
}

// ---------- maze shuffle ----------

// The stock maze only rearranges while nobody is in it or looking at it, so with everyone living
// in the maze it never moved. Every 5th round it now changes regardless. Anyone standing where a
// hedge comes up is moved to the fountain first so nobody ends up inside a wall.
bmz_maze_shuffle()
{
    level endon( "end_game" );

    while ( !isdefined( level._maze ) || !isdefined( level._maze._perms ) )
        wait 0.5;

    for ( ;; )
    {
        level waittill( "start_of_round" );

        if ( level.round_number < 5 || level.round_number % 5 != 0 )
            continue;

        // copy the names first: maze_do_perm_change edits a list made from the active one
        old = [];
        for ( i = 0; i < level._maze._active_perm_list.size; i++ )
            old[ old.size ] = level._maze._active_perm_list[i];
        maps\mp\zm_buried_maze::maze_do_perm_change();
        level notify( "zm_buried_maze_changed" );

        rising = [];
        for ( i = 0; i < level._maze._active_perm_list.size; i++ )
        {
            name = level._maze._active_perm_list[i];
            if ( !isinarray( old, name ) && isdefined( level._maze._blocker_locations[name] ) )
                rising[ rising.size ] = level._maze._blocker_locations[name].origin;
        }

        iprintlnbold( "^5The maze is shifting!" );
        logprint( "BMZ maze shuffled on round " + level.round_number + " (" + rising.size + " hedges up)\n" );

        // the hedges take ~0.25 s each to start and 0.65 s to rise: keep clearing for a few seconds
        for ( t = 0; t < 40; t++ )
        {
            players = getplayers();
            for ( p = 0; p < players.size; p++ )
            {
                if ( players[p].sessionstate != "playing" )
                    continue;
                for ( r = 0; r < rising.size; r++ )
                {
                    d = players[p].origin - rising[r];
                    if ( d[0] * d[0] + d[1] * d[1] < 64 * 64 && abs( d[2] ) < 100 )
                    {
                        players[p] bmz_put_at_fountain();
                        break;
                    }
                }
            }
            wait 0.1;
        }
    }
}

// ---------- witch's house wall ----------

// Invisible solid blocks (collision models Buried itself loads for its fixes) from a to b,
// three high, so the gap can't be walked or jumped through.
bmz_wall( a, b )
{
    flag_wait( "start_zombie_round_logic" );

    d = b - a;
    flat = ( d[0], d[1], 0 );
    len = length( flat );
    dir = vectornormalize( flat );
    yaw = vectortoangles( flat )[1];
    floor_z = a[2];
    if ( b[2] < floor_z )
        floor_z = b[2];
    count = int( len / 100 ) + 2;   // 128-unit blocks every ~100 units, overlapping past both ends

    for ( i = 0; i < count; i++ )
    {
        p = a + dir * ( i * len / ( count - 1 ) );
        for ( h = 0; h < 3; h++ )
        {
            block = spawn( "script_model", ( p[0], p[1], floor_z + h * 128 ) );
            block setmodel( "collision_geo_128x128x128_standard" );
            block.angles = ( 0, yaw, 0 );
            block ghost();
        }
    }
    logprint( "BMZ witch house wall: " + count * 3 + " blocks\n" );
}

// ---------- random wall buys ----------

// Buried's own wall guns at their normal prices.
bmz_random_wallbuys( count )
{
    guns = [];
    guns[ guns.size ] = array( "m14_zm", "M14", 500 );
    guns[ guns.size ] = array( "rottweil72_zm", "Olympia", 500 );
    guns[ guns.size ] = array( "beretta93r_zm", "B23R", 1000 );
    guns[ guns.size ] = array( "mp5k_zm", "MP5", 1000 );
    guns[ guns.size ] = array( "pdw57_zm", "PDW-57", 1000 );
    guns[ guns.size ] = array( "svu_zm", "SVU-AS", 1000 );
    guns[ guns.size ] = array( "ak74u_zm", "AK74u", 1200 );
    guns[ guns.size ] = array( "m16_zm", "M16", 1200 );
    guns[ guns.size ] = array( "an94_zm", "AN-94", 1200 );
    guns[ guns.size ] = array( "870mcs_zm", "Remington 870", 1500 );
    guns[ guns.size ] = array( "lsat_zm", "LSAT", 2000 );
    guns = array_randomize( guns );
    spots = array_randomize( level.bmz_gun_spots );

    for ( i = 0; i < count && i < spots.size && i < guns.size; i++ )
        level thread bmz_wallbuy( spots[i], guns[i][0], guns[i][1], guns[i][2] );
}

// ---------- custom wall buys ----------

// A floating gun with a use prompt. Buying gives the gun; buying again refills ammo for half.
bmz_wallbuy( origin, weapon, label, cost )
{
    level endon( "end_game" );

    flag_wait( "start_zombie_round_logic" );

    model = spawn( "script_model", origin + ( 0, 0, 50 ) );
    model setmodel( getweaponmodel( weapon ) );
    model thread bmz_spin();

    trig = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 48, 64 );
    trig setcursorhint( "HINT_NOICON" );
    trig sethintstring( "Hold ^3[{+activate}]^7 for " + label + " [Cost: " + cost + "]  Ammo [Cost: " + int( cost / 2 ) + "]" );
    trig triggerignoreteam();

    logprint( "BMZ wall buy " + weapon + " at " + origin + "\n" );

    for ( ;; )
    {
        trig waittill( "trigger", player );

        if ( !isplayer( player ) || player maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
            continue;
        if ( isdefined( player.is_drinking ) && player.is_drinking > 0 )
            continue;

        has = player hasweapon( weapon );
        price = cost;
        if ( has )
            price = int( cost / 2 );

        if ( player.score < price )
        {
            player playsound( "no_purchase" );
            continue;
        }

        player maps\mp\zombies\_zm_score::minus_to_player_score( price );
        player playsound( "zmb_cha_ching" );

        if ( has )
            player givemaxammo( weapon );
        else
            player maps\mp\zombies\_zm_weapons::weapon_give( weapon );

        wait 0.5;   // one buy per hold
    }
}

bmz_spin()
{
    level endon( "end_game" );
    for ( ;; )
    {
        self rotateyaw( 360, 4 );
        wait 4;
    }
}
