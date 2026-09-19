#include maps\mp\_utility;
#include common_scripts\utility;

/**
 * Speedrun logger (T6 / Black Ops 2 Zombies).
 *
 * Appends one line to logs/Speedrun.txt (beside the HighRound files) each time
 * a game reaches a milestone round or finishes the map's main easter egg, with
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
 * and rejoins is still on the roster.
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

		if ( lastRound >= 2 )
			level.srRosterLocked = true;

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
		level.srRoster[ slot ].name = sr_clean_name( players[ i ].name );
		if ( isDefined( players[ i ].persistentClientId ) )
			level.srRoster[ slot ].id = "" + players[ i ].persistentClientId;
		else if ( !isDefined( level.srRoster[ slot ].id ) )
			level.srRoster[ slot ].id = guid;
	}
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
sr_clean_name( name )
{
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
