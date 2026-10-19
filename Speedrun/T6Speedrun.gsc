#include maps\mp\_utility;
#include common_scripts\utility;

/**
 * Speedrun logger (T6 / Black Ops 2 Zombies).
 *
 * Appends one line to logs/Speedrun.txt (beside the HighRound files) each time
 * a game reaches a milestone round or finishes an easter egg (main quest, song
 * or side egg), with
 * the game time it took. The website turns those lines into "fastest to round
 * N" and "fastest easter egg" boards per map and player count.
 *
 * File format - one line per event, appended, never rewritten:
 *     <runId>|<mapToken>|<kind>|<target>|<ms>|<players>|<id:name,id:name>|<port>
 *
 *     runId     random id for this game, so the site can tell two games apart
 *     mapToken  same prefix the RoundSaver uses for its HighRound file
 *               (TranzitStandard, MotdClassic ...) so the site can pair them
 *     kind      "round" or "ee"
 *     target    the round reached, or the easter egg's token
 *     ms        milliseconds from the start of round 1 to the event
 *     players   squad size (see the roster rule below) - the board it goes on
 *
 * The clock starts at the first "start_of_round" notify, which is when round 1
 * actually begins after the intro, so every run on a map is measured the same
 * way. A game that did not begin at round 1 is not timed at all.
 *
 * Squad rules: everyone in the game before round 2 begins is the roster, and
 * the run is logged for that squad size with those names, even if some leave
 * before a milestone. A new player joining from round 2 onward ends timing for
 * that game - otherwise a solo run could land on the 2P board, or a three-man
 * carry to round 28 could be logged as a 1P time. A roster member who drops
 * and rejoins is still on the roster. Anyone who left during round 1 is
 * dropped when round 2 begins, so a player who quits early and is replaced
 * does not turn a 4-man game into a 5P run.
 */

init()
{
    level.srFile = getDvar( "fs_homepath" ) + "/logs/Speedrun.txt";
    level.srRunId = randomInt( 1000000 ) + "-" + getTime();
    level.srMapToken = sr_map_token();

    level.srMilestones = [];
    level.srMilestones[ level.srMilestones.size ] = 10;
    level.srMilestones[ level.srMilestones.size ] = 20;
    level.srMilestones[ level.srMilestones.size ] = 30;
    level.srMilestones[ level.srMilestones.size ] = 40;
    level.srMilestones[ level.srMilestones.size ] = 50;
    level.srMilestones[ level.srMilestones.size ] = 70;
    level.srMilestones[ level.srMilestones.size ] = 100;

    sr_write_boot_line_if_new();

    level thread sr_wait_for_start();
    level thread sr_watch_rounds();

    // Main quest completion notifies, one per map. Only the current map's ever
    // fires; the rest sit idle until the game ends.
    level thread sr_watch_ee( "transit_sidequest_achieved",  "tower_of_babble" );
    level thread sr_watch_ee( "highrise_sidequest_achieved", "high_maintenance" );
    level thread sr_watch_ee( "pop_goes_the_weasel_achieved", "pop_goes_the_weasel" );
    level thread sr_watch_ee( "sq_maxis_complete",           "mined_games_maxis" );
    level thread sr_watch_ee( "sq_richtofen_complete",       "mined_games_richtofen" );
    level thread sr_watch_ee( "tomb_sidequest_complete",     "little_lost_girl" );

    // Song easter eggs, timed to the moment each song unlocks.
    level thread sr_watch_songs();

    // Side easter eggs, timed to the moment the game marks each one done.
    level thread sr_watch_side_eggs();
}

sr_wait_for_start()
{
    level endon( "end_game" );

    level waittill( "start_of_round" );

    // A server that starts games above round 1 cannot be compared with one
    // that does not, so leave the run untimed.
    if ( !isDefined( level.round_number ) || level.round_number != 1 )
        return;

    level.srStart = getTime();
    level.srRoster = [];
    level.srRosterLocked = false;
}

sr_watch_rounds()
{
    level endon( "end_game" );

    lastRound = -1;

    for ( ;; )
    {
        wait 0.05;

        if ( !isDefined( level.srStart ) || isDefined( level.srInvalid ) )
            continue;

        sr_update_roster();

        if ( !isDefined( level.round_number ) || level.round_number == lastRound )
            continue;

        lastRound = level.round_number;

        if ( lastRound >= 2 && !level.srRosterLocked )
        {
            sr_prune_roster();
            level.srRosterLocked = true;
        }

        if ( sr_is_milestone( lastRound ) )
            sr_log( "round", "" + lastRound );
    }
}

// Before round 2 anyone present joins the roster. After that a face that is
// not on it ends timing for this game.
sr_update_roster()
{
    players = get_players();
    for ( i = 0; i < players.size; i++ )
    {
        guid = "" + players[ i ] getGuid();
        slot = sr_roster_index( guid );

        if ( slot < 0 )
        {
            if ( level.srRosterLocked )
            {
                level.srInvalid = true;
                iPrintLn( "^3Speedrun timing ended - a new player joined after round 1" );
                return;
            }
            slot = level.srRoster.size;
            level.srRoster[ slot ] = spawnStruct();
            level.srRoster[ slot ].guid = guid;
        }

        // Keep the latest name and the IW4MAdmin id, which arrives a few
        // seconds after connecting, so a player who leaves is still credited.
        level.srRoster[ slot ].name = sr_cached_name( players[ i ] );
        if ( isDefined( players[ i ].persistentClientId ) )
            level.srRoster[ slot ].id = "" + players[ i ].persistentClientId;
        else if ( !isDefined( level.srRoster[ slot ].id ) )
            level.srRoster[ slot ].id = guid;
    }
}

// Round 2 has begun: keep only the roster members still in the game.
sr_prune_roster()
{
    players = get_players();
    kept = [];
    for ( r = 0; r < level.srRoster.size; r++ )
    {
        for ( i = 0; i < players.size; i++ )
        {
            if ( "" + players[ i ] getGuid() == level.srRoster[ r ].guid )
            {
                kept[ kept.size ] = level.srRoster[ r ];
                break;
            }
        }
    }
    level.srRoster = kept;
}

sr_roster_index( guid )
{
    for ( i = 0; i < level.srRoster.size; i++ )
    {
        if ( level.srRoster[ i ].guid == guid )
            return i;
    }
    return -1;
}

sr_watch_songs()
{
    level endon( "end_game" );

    // music_override one frame ago - some eggs only play if no other music is
    // on, and their own handler sets it in the frame of the trigger.
    level.srPrevOverride = false;
    level thread sr_track_music_override();

    if ( level.script == "zm_transit" && getDvar( "ui_gametype" ) == "zclassic" )
        level thread sr_watch_meteor_song( "song_carrion" );
    else if ( level.script == "zm_highrise" )
        level thread sr_watch_meteor_song( "song_we_all_fall_down" );
    else if ( level.script == "zm_buried" )
        level thread sr_watch_meteor_song( "song_always_running" );
    else if ( level.script == "zm_prison" )
    {
        level thread sr_watch_meteor_song( "song_rusty_cage" );
        level thread sr_watch_nixie_song();
    }
    else if ( level.script == "zm_tomb" )
    {
        level thread sr_watch_meteor_song( "song_archangel" );
        level thread sr_watch_ee( "sndEnd115", "song_aether" );
        level thread sr_watch_radio_song();
    }
    else if ( level.script == "zm_nuked" )
    {
        level thread sr_watch_meteor_song( "song_nuked_teddy_bears" );
        level thread sr_watch_nuked_population_song();
        level thread sr_watch_nuked_mannequin_song();
    }
}

sr_track_music_override()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level.srPrevOverride = isDefined( level.music_override ) && level.music_override;
        wait 0.05;
    }
}

sr_song_done( token )
{
    if ( isDefined( level.srStart ) && !isDefined( level.srInvalid ) )
        sr_log( "ee", token );
}

// The usual song egg: three meteors / bottles / teddy bears / fragments.
sr_watch_meteor_song( token )
{
    level endon( "end_game" );

    while ( !( isDefined( level.meteor_counter ) && level.meteor_counter >= 3 ) )
        wait 0.5;
    sr_song_done( token );
}

// Origins: the three radios (Shepherd of Fire).
sr_watch_radio_song()
{
    level endon( "end_game" );

    while ( !( isDefined( level.found_ee_radio_count ) && level.found_ee_radio_count >= 3 ) )
        wait 0.5;
    sr_song_done( "song_shepherd_of_fire" );
}

// Mob of the Dead: 935 on the nixie tubes plays the second song - but only if
// no other music is on at that moment. The notify repeats while 935 shows.
sr_watch_nixie_song()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "nixie_935" );
        if ( level.srPrevOverride )
            continue;
        wait 0.5;
        if ( isDefined( level.music_override ) && level.music_override )
            break;
    }
    sr_song_done( "song_where_are_we_going" );
}

// Nuketown: move the clock, then grab the door power-up with population 15.
sr_watch_nuked_population_song()
{
    level endon( "end_game" );

    level waittill( "nuke_clock_moved" );
    level waittill( "magic_door_power_up_grabbed" );
    if ( isDefined( level.population_count ) && level.population_count == 15 && !level.srPrevOverride )
        sr_song_done( "song_nuked_population" );
}

// Nuketown: every mannequin destroyed.
sr_watch_nuked_mannequin_song()
{
    level endon( "end_game" );

    while ( !( isDefined( level.mannequin_count ) && level.mannequin_count > 0 ) )
        wait 1;
    while ( level.mannequin_count > 0 )
        wait 0.5;
    sr_song_done( "song_nuked_mannequins" );
}

// Each watches state the stock map script sets when the egg is done (see the
// file each comment names), polled because most have no notify of their own.
// Several are per player; the squad's time is when the first of them gets it.
sr_watch_side_eggs()
{
    if ( level.script == "zm_prison" )
    {
        // zm_prison_spoon.gsc gives the spork once the spoon is charged.
        level thread sr_watch_player_weapon( "spork_zm_alcatraz", "golden_spork" );
        // _zm_weap_tomahawk.gsc gives the tomahawk when it is picked up from
        // the hellhole after the three dogs are fed.
        level thread sr_watch_player_weapon( "bouncing_tomahawk_zm", "hells_retriever", "upgraded_tomahawk_zm" );
    }
    else if ( level.script == "zm_tomb" )
    {
        level thread sr_watch_golden_shovel();
        level thread sr_watch_drone_medallions();
        level thread sr_watch_soul_boxes();
    }
    else if ( level.script == "zm_buried" )
    {
        level thread sr_watch_fountain();
        level thread sr_watch_ghost_piano();
    }
}

sr_flag_on( name )
{
    return isDefined( level.flag ) && isDefined( level.flag[ name ] ) && level.flag[ name ];
}

sr_watch_player_weapon( weapon, token, upgraded )
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait 0.5;
        players = get_players();
        for ( i = 0; i < players.size; i++ )
        {
            if ( players[ i ] hasWeapon( weapon ) || ( isDefined( upgraded ) && players[ i ] hasWeapon( upgraded ) ) )
            {
                sr_song_done( token );
                return;
            }
        }
    }
}

// Origins: 30 dig spots with the shovel (zm_tomb_dig.gsc).
sr_watch_golden_shovel()
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait 0.5;
        players = get_players();
        for ( i = 0; i < players.size; i++ )
        {
            if ( isDefined( players[ i ].dig_vars ) && isDefined( players[ i ].dig_vars[ "has_upgraded_shovel" ] )
                && players[ i ].dig_vars[ "has_upgraded_shovel" ] )
            {
                sr_song_done( "golden_shovel" );
                return;
            }
        }
    }
}

// Origins: the Maxis Drone brings back all four medallions (_zm_ai_quadrotor.gsc
// counts them down). The flag is only set once the drone then reaches the MG08,
// so it is the fallback, not the trigger.
sr_watch_drone_medallions()
{
    level endon( "end_game" );

    while ( !( ( isDefined( level.n_ee_medallions ) && level.n_ee_medallions <= 0 ) || sr_flag_on( "ee_medallions_collected" ) ) )
        wait 0.5;
    sr_song_done( "drone_medallions" );
}

// Origins: all four soul boxes filled (zm_tomb_challenges.gsc).
sr_watch_soul_boxes()
{
    level endon( "end_game" );

    while ( !( isDefined( level.n_soul_boxes_completed ) && level.n_soul_boxes_completed >= 4 ) )
        wait 0.5;
    sr_song_done( "soul_boxes" );
}

// Buried: both fountains broken opens the fountain teleporter (zm_buried_fountain.gsc).
sr_watch_fountain()
{
    level endon( "end_game" );

    while ( !sr_flag_on( "fountain_transport_active" ) )
        wait 0.5;
    sr_song_done( "fountain_teleporter" );
}

// Buried: the ghost piano's free perk (zm_buried_ee.gsc). The field, not the
// notify - the ghost round's own free perk sends the same notify.
sr_watch_ghost_piano()
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait 0.5;
        players = get_players();
        for ( i = 0; i < players.size; i++ )
        {
            if ( isDefined( players[ i ].got_easter_egg_reward ) && players[ i ].got_easter_egg_reward )
            {
                sr_song_done( "ghost_piano" );
                return;
            }
        }
    }
}

sr_watch_ee( notifyName, token )
{
    level endon( "end_game" );

    level waittill( notifyName );

    if ( isDefined( level.srStart ) && !isDefined( level.srInvalid ) )
        sr_log( "ee", token );
}

sr_is_milestone( rnd )
{
    for ( i = 0; i < level.srMilestones.size; i++ )
    {
        if ( level.srMilestones[ i ] == rnd )
            return true;
    }
    return false;
}

sr_log( kind, target )
{
    elapsed = getTime() - level.srStart;
    sr_update_roster();
    if ( isDefined( level.srInvalid ) || level.srRoster.size == 0 )
        return;

    line = level.srRunId + "|" + level.srMapToken + "|" + kind + "|" + target + "|"
         + elapsed + "|" + level.srRoster.size + "|" + sr_player_blocks() + "|"
         + getDvar( "net_port" );

    sr_append( line );

    if ( kind == "round" )
        iPrintLn( "^7Round " + target + " in ^2" + sr_format_time( elapsed ) );
    else
        iPrintLn( "^7Easter egg done in ^2" + sr_format_time( elapsed ) );
}

sr_player_blocks()
{
    blocks = "";
    for ( i = 0; i < level.srRoster.size; i++ )
    {
        block = level.srRoster[ i ].id + ":" + level.srRoster[ i ].name;

        if ( blocks == "" )
            blocks = block;
        else
            blocks = blocks + "," + block;
    }
    return blocks;
}

// Strip the characters the line format uses so a name can never break parsing.
// The character loop is the expensive part, so run it only when a player's
// name actually changes rather than on every scan.
sr_cached_name( player )
{
    raw = player.name;
    if ( !isDefined( raw ) )
        return "Player";

    if ( isDefined( player.srNameRaw ) && player.srNameRaw == raw && isDefined( player.srNameClean ) )
        return player.srNameClean;

    player.srNameRaw = raw;
    player.srNameClean = sr_clean_name( raw );
    return player.srNameClean;
}

sr_clean_name( name )
{
    if ( !isDefined( name ) )
        return "Player";

    out = "";
    for ( i = 0; i < name.size; i++ )
    {
        c = name[ i ];
        if ( c != "|" && c != ":" && c != "," && c != ";" )
            out += c;
    }
    if ( out == "" )
        return "Player";
    return out;
}

sr_format_time( ms )
{
    total = int( ms / 1000 );
    h = int( total / 3600 );
    m = int( ( total % 3600 ) / 60 );
    s = total % 60;

    text = "";
    if ( h > 0 )
        text = h + ":" + sr_pad( m ) + ":" + sr_pad( s );
    else
        text = m + ":" + sr_pad( s );
    return text;
}

sr_pad( n )
{
    if ( n < 10 )
        return "0" + n;
    return "" + n;
}

// Writing a marker line the first time the file is created proves the append
// path works on this server before anyone reaches a milestone. The site
// ignores "boot" lines.
sr_write_boot_line_if_new()
{
    file = fopen( level.srFile, "r" );
    if ( isDefined( file ) && file != 0 )
    {
        fclose( file );
        return;
    }
    sr_append( level.srRunId + "|" + level.srMapToken + "|boot|0|0|0||" + getDvar( "net_port" ) );
}

sr_append( line )
{
    file = fopen( level.srFile, "a" );
    if ( isDefined( file ) && file != 0 )
    {
        fwrite( file, line + "\n" );
        fclose( file );
    }
}

// Same naming as T6RoundSaverNew.gsc, so <token>HighRound.txt is the board
// this run belongs to.
sr_map_token()
{
    gamemode = getDvar( "ui_gametype" );
    map = sr_map_name( level.script );
    if ( level.script == "zm_transit" && gamemode == "zsurvival" )
        map = sr_start_location_name( getDvar( "ui_zm_mapstartlocation" ) );
    return map + sr_gamemode_name( gamemode );
}

sr_start_location_name( location )
{
    if ( location == "cornfield" )
        return "Cornfield";
    else if ( location == "diner" )
        return "Diner";
    else if ( location == "farm" )
        return "Farm";
    else if ( location == "power" )
        return "Power";
    else if ( location == "town" )
        return "Town";
    else if ( location == "transit" )
        return "BusDepot";
    else if ( location == "tunnel" )
        return "Tunnel";
    return "Tranzit";
}

sr_map_name( map )
{
    if ( map == "zm_buried" )
        return "Buried";
    else if ( map == "zm_highrise" )
        return "DieRise";
    else if ( map == "zm_prison" )
        return "Motd";
    else if ( map == "zm_nuked" )
        return "Nuketown";
    else if ( map == "zm_tomb" )
        return "Origins";
    else if ( map == "zm_transit" )
        return "Tranzit";
    return "NA";
}

sr_gamemode_name( gamemode )
{
    if ( gamemode == "zstandard" )
        return "Standard";
    else if ( gamemode == "zclassic" )
        return "Classic";
    else if ( gamemode == "zsurvival" )
        return "Survival";
    else if ( gamemode == "zgrief" )
        return "Grief";
    else if ( gamemode == "zcleansed" )
        return "Turned";
    return "NA";
}
