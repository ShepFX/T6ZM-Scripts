#include maps\mp\_utility;
#include common_scripts\utility;

/**
 * Game stats logger (T6 / Black Ops 2 Zombies).
 *
 * Appends one line per player to logs/GameStats.txt (beside Speedrun.txt) with
 * what they did in the game: kills, headshots, downs, revives, bleed-outs and
 * points. A player's line is written when they leave, and for everyone still
 * in when the game ends, so every session is counted once.
 *
 * File format - one line per player session:
 *     <runId>|<mapToken>|<round>|<reason>|<port>|<id>|<name>|<kills>|<headshots>|
 *     <downs>|<revives>|<bleedouts>|<points>|<joinRound>|<ms>|<box>|<perks>|<pap>|
 *     <powerups>|<powerupTypes>
 *
 *     runId      random id for this game (same idea as the speedrun log)
 *     mapToken   same as the speedrun log (TranzitStandard, MotdClassic ...)
 *     round      the round when the line was written
 *     reason     "end" - still in when the game ended - or "left"
 *     id         IW4MAdmin client id (the GUID until IW4MAdmin has set it)
 *     bleedouts  times the player bled out and spectated until the next round
 *     points     total points earned this game, not what they had left
 *     joinRound  the round they joined in
 *     ms         time in the game
 *     box        mystery box spins they paid for (the game's own use_magicbox count,
 *                or what gs_watch_machines saw where that stays 0 - Mob of the Dead)
 *     perks      perks they bought from a machine - free ones are not counted
 *     pap        Pack-a-Punch uses (the game's own use_pap count, same fallback)
 *     powerups   power-ups they picked up
 *     powerupTypes  the same by type, "nuke=2/full_ammo=1", empty when none
 *
 * A session with no kills that lasted under 30 seconds is not written, so
 * someone connecting and leaving straight away adds nothing.
 *
 * Same logic as T4GameStats.gsc / T5GameStats.gsc: a bled-out player turns
 * spectator until the next round, which is what is watched, and game over is
 * the "end_game" notify or level.intermission, whichever comes first.
 */

init()
{
	level.gsFile = getDvar( "fs_homepath" ) + "/logs/GameStats.txt";
	level.gsRunId = randomInt( 1000000 ) + "-" + getTime();
	level.gsMapToken = gs_map_token();
	level.gsSessions = [];

	level thread gs_watch_players();
	level thread gs_watch_end();
	level thread gs_watch_drops();
	level thread gs_watch_machines();
}

// New player entities get their own tracking thread.
gs_watch_players()
{
	for ( ;; )
	{
		players = get_players();
		for ( i = 0; i < players.size; i++ )
		{
			if ( isDefined( players[ i ] ) && !isDefined( players[ i ].gsSession ) )
				players[ i ] thread gs_track_player();
		}
		wait 1;
	}
}

gs_track_player()
{
	session = spawnStruct();
	session.guid = "" + self getGuid();
	session.joinRound = gs_round();
	session.joinTime = getTime();
	session.bleedouts = 0;
	session.box = 0;
	session.perks = 0;
	session.pap = 0;
	session.boxSeen = 0;
	session.papSeen = 0;
	session.powerups = 0;
	session.powerupTypes = [];
	session.written = false;
	self.gsSession = session;
	level.gsSessions[ level.gsSessions.size ] = session;

	self thread gs_watch_bleedouts( session );
	self thread gs_watch_leave( session );
	self thread gs_watch_perks( session );

	// Keep a copy of the numbers, so a player who drops is still logged with
	// what they had - their entity is gone by the time "disconnect" arrives.
	self endon( "disconnect" );
	for ( ;; )
	{
		gs_snapshot_of( self, session );
		wait 1;
	}
}

gs_watch_bleedouts( session )
{
	self endon( "disconnect" );

	last = "";
	for ( ;; )
	{
		state = "";
		if ( isDefined( self.sessionstate ) )
			state = self.sessionstate;

		// Only "playing" to "spectator" counts: a player joining mid-round
		// starts as a spectator, and game over moves everyone to intermission.
		if ( state == "spectator" && last == "playing" && !gs_game_over() )
			session.bleedouts++;

		last = state;
		wait 0.25;
	}
}

// "perk_bought" is sent to the buyer only for a machine purchase (Wunderfizz
// included), so free perks from power-ups, Tombstone and Who's Who don't count.
gs_watch_perks( session )
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "perk_bought", perk );
		session.perks++;
	}
}

// Every power-up the game drops is watched until someone grabs it or it goes.
// The game names the grabber 0.1s before hiding it, so a 0.05s check sees it.
gs_watch_drops()
{
	for ( ;; )
	{
		level waittill( "powerup_dropped", powerup );
		if ( isDefined( powerup ) )
			powerup thread gs_watch_drop();
	}
}

gs_watch_drop()
{
	while ( isDefined( self ) && !isDefined( self.power_up_grab_player ) )
		wait 0.05;
	if ( !isDefined( self ) )
		return;

	player = self.power_up_grab_player;
	if ( !isDefined( player ) || !isDefined( player.gsSession ) )
		return;
	name = "other";
	if ( isDefined( self.powerup_name ) )
		name = gs_clean_name( self.powerup_name );

	session = player.gsSession;
	session.powerups++;
	if ( !isDefined( session.powerupTypes[ name ] ) )
		session.powerupTypes[ name ] = 0;
	session.powerupTypes[ name ] = session.powerupTypes[ name ] + 1;
}

// Mob of the Dead never fills use_magicbox / use_pap, so the box and the
// Pack-a-Punch are watched as well: the game sets chest.chest_user and
// trigger.pack_player when someone pays and clears them once it is over.
gs_watch_machines()
{
	lastBox = [];
	lastPap = [];
	for ( ;; )
	{
		if ( isDefined( level.chests ) )
		{
			for ( i = 0; i < level.chests.size; i++ )
			{
				user = undefined;
				if ( isDefined( level.chests[ i ] ) )
					user = level.chests[ i ].chest_user;
				if ( isDefined( user ) && ( !isDefined( lastBox[ i ] ) || lastBox[ i ] != user ) && isDefined( user.gsSession ) )
					user.gsSession.boxSeen++;
				lastBox[ i ] = user;
			}
		}
		if ( isDefined( level.pap_triggers ) )
		{
			for ( i = 0; i < level.pap_triggers.size; i++ )
			{
				user = undefined;
				if ( isDefined( level.pap_triggers[ i ] ) )
					user = level.pap_triggers[ i ].pack_player;
				if ( isDefined( user ) && ( !isDefined( lastPap[ i ] ) || lastPap[ i ] != user ) && isDefined( user.gsSession ) )
					user.gsSession.papSeen++;
				lastPap[ i ] = user;
			}
		}
		wait 0.05;
	}
}

gs_watch_leave( session )
{
	self waittill( "disconnect" );
	if ( !session.written && !gs_game_over() )
		gs_write( session, "left" );
}

gs_watch_end()
{
	level thread gs_end_notify();
	while ( !gs_game_over() )
		wait 0.25;

	players = get_players();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isDefined( players[ i ] ) && isDefined( players[ i ].gsSession ) )
			gs_snapshot_of( players[ i ], players[ i ].gsSession );
	}
	for ( i = 0; i < level.gsSessions.size; i++ )
	{
		if ( !level.gsSessions[ i ].written && !isDefined( level.gsSessions[ i ].left ) )
			gs_write( level.gsSessions[ i ], "end" );
	}
}

gs_end_notify()
{
	level waittill( "end_game" );
	level.gsEnded = true;
}

gs_game_over()
{
	if ( isDefined( level.gsEnded ) )
		return true;
	return isDefined( level.intermission ) && level.intermission;
}

gs_snapshot_of( player, session )
{
	if ( isDefined( player.name ) )
		session.name = gs_clean_name( player.name );

	if ( isDefined( player.persistentClientId ) )
		session.id = "" + player.persistentClientId;
	else if ( !isDefined( session.id ) )
		session.id = session.guid;

	session.kills = gs_num( player.kills );
	session.headshots = gs_num( player.headshots );
	session.downs = gs_num( player.downs );
	session.revives = gs_num( player.revives );
	session.box = gs_max( gs_pers( player, "use_magicbox" ), session.boxSeen );
	session.pap = gs_max( gs_pers( player, "use_pap" ), session.papSeen );
	if ( isDefined( player.score_total ) )
		session.points = gs_num( player.score_total );
	else
		session.points = gs_num( player.score );
	session.lastSeen = getTime();
}

gs_write( session, reason )
{
	session.written = true;
	if ( reason == "left" )
		session.left = true;

	if ( !isDefined( session.lastSeen ) || !isDefined( session.name ) )
		return;
	ms = session.lastSeen - session.joinTime;
	if ( ms < 30000 && session.kills == 0 )
		return;

	line = level.gsRunId + "|" + level.gsMapToken + "|" + gs_round() + "|" + reason + "|"
	     + getDvar( "net_port" ) + "|" + session.id + "|" + session.name + "|"
	     + session.kills + "|" + session.headshots + "|" + session.downs + "|"
	     + session.revives + "|" + session.bleedouts + "|" + session.points + "|"
	     + session.joinRound + "|" + ms + "|" + session.box + "|" + session.perks + "|"
	     + session.pap + "|" + session.powerups + "|" + gs_powerup_types( session );

	file = fopen( level.gsFile, "a" );
	if ( isDefined( file ) && file != 0 )
	{
		fwrite( file, line + "\n" );
		fclose( file );
	}
}

gs_round()
{
	if ( isDefined( level.round_number ) )
		return level.round_number;
	return 0;
}

// The game's own per-player counters (_zm_stats), 0 where a map does not keep them.
gs_pers( player, name )
{
	if ( isDefined( player.pers ) && isDefined( player.pers[ name ] ) )
		return int( player.pers[ name ] );
	return 0;
}

gs_max( a, b )
{
	if ( a > b )
		return a;
	return b;
}

gs_powerup_types( session )
{
	out = "";
	names = getArrayKeys( session.powerupTypes );
	for ( i = 0; i < names.size; i++ )
	{
		if ( out != "" )
			out += "/";
		out += names[ i ] + "=" + session.powerupTypes[ names[ i ] ];
	}
	return out;
}

gs_num( value )
{
	if ( isDefined( value ) )
		return int( value );
	return 0;
}

// Strip the characters the line format uses so a name can never break parsing.
// Bounded as well as tested - see sr_clean_name in T6Speedrun.gsc.
gs_clean_name( name )
{
	out = "";
	for ( i = 0; i < 64 && i < name.size; i++ )
	{
		c = name[ i ];
		if ( !isDefined( c ) )
			break;
		if ( c != "|" && c != ":" && c != "," && c != ";" )
			out += c;
	}
	if ( out == "" )
		return "Player";
	return out;
}

// Same naming as T6Speedrun.gsc / T6RoundSaverNew.gsc.
gs_map_token()
{
	gamemode = getDvar( "ui_gametype" );
	map = gs_map_name( level.script );
	if ( level.script == "zm_transit" && gamemode == "zsurvival" )
		map = gs_start_location_name( getDvar( "ui_zm_mapstartlocation" ) );
	return map + gs_gamemode_name( gamemode );
}

gs_start_location_name( location )
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

gs_map_name( map )
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

gs_gamemode_name( gamemode )
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
