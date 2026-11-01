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
 * Box spins and downs also go one line each to logs/GameEvents.txt (31 Oct 2026):
 *     <runId>|<mapToken>|<round>|<port>|<id>|<name>|box|<weapon or "teddy">
 *     <runId>|<mapToken>|<round>|<port>|<id>|<name>|down|<x>,<y>,<z>
 * A box line is the weapon the spin offered, taken or not; "teddy" moved the box.
 * Once per game: ...|0|-|map|<x0>,<y0>,<x1>,<y1>,<northYaw> - the minimap corners (only Nuketown has them).
 * Floor plans for the heatmaps (1 Nov 2026):
 *     ...|0|-|grid|<cx>,<cy>,<cz>,<n>;...   time spent per 64x64x128-unit cell, every 5 minutes
 *     ...|0|-|mark|<type>:<name>:<x>,<y>,<z>   perks, PaP, box spots and wall buys, once per game
 * Cells are offset by 65536 so they are never negative: cx = int((x + 65536) / 64).
 * Live radar (1 Nov 2026), stock maps only: every second, one line per player into the game log in the format
 * IW4MAdmin's Live Radar reads (see its PT6 _customcallbacks.gsc), with the team field holding
 * the player's state - up, down (last stand), afterlife (Mob of the Dead's ghost form) or dead (spectating):
 *     LiveRadar;<guid hex>;<origin>;<angles>;<state>;0;0;0;none;<health>;<alive>;0
 *
 * Same logic as T4GameStats.gsc / T5GameStats.gsc: a bled-out player turns
 * spectator until the next round, which is what is watched, and game over is
 * the "end_game" notify or level.intermission, whichever comes first.
 */

init()
{
	level.gsFile = getDvar( "fs_homepath" ) + "/logs/GameStats.txt";
	level.gsEventFile = getDvar( "fs_homepath" ) + "/logs/GameEvents.txt";
	level.gsRunId = randomInt( 1000000 ) + "-" + getTime();
	level.gsMapToken = gs_map_token();
	level.gsSessions = [];

	level thread gs_watch_players();
	level thread gs_watch_end();
	level thread gs_watch_drops();
	level thread gs_watch_machines();
	level thread gs_watch_box_spins();
	level thread gs_log_minimap();
	level thread gs_floor_sample();
	level thread gs_floor_flush();
	level thread gs_log_marks();
	level thread gs_radar();
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
	self thread gs_watch_downs();

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

// Each spin ends with "randomization_done" on the chest's zbarrier, with the
// offered weapon in weapon_string; a teddy bear leaves it undefined
// (_zm_magicbox.gsc). chest_user is the player who paid.
gs_watch_box_spins()
{
	while ( !isDefined( level.chests ) )
		wait 1;
	for ( i = 0; i < level.chests.size; i++ )
	{
		if ( isDefined( level.chests[ i ] ) && isDefined( level.chests[ i ].zbarrier ) )
			level.chests[ i ] thread gs_watch_chest();
	}
}

gs_watch_chest()
{
	level endon( "end_game" );
	for ( ;; )
	{
		self.zbarrier waittill( "randomization_done" );
		user = self.chest_user;
		if ( !isDefined( user ) || !isPlayer( user ) )
			continue;
		weapon = "teddy";
		if ( isDefined( self.zbarrier.weapon_string ) )
			weapon = self.zbarrier.weapon_string;
		gs_event( user, "box", weapon );
	}
}

// player.downs counts every down; where the player was when it went up.
gs_watch_downs()
{
	self endon( "disconnect" );
	last = gs_num( self.downs );
	for ( ;; )
	{
		wait 0.2;
		now = gs_num( self.downs );
		if ( now > last )
			gs_event( self, "down", int( self.origin[ 0 ] ) + "," + int( self.origin[ 1 ] ) + "," + int( self.origin[ 2 ] ) );
		last = now;
	}
}

// The two minimap_corner entities the compass is drawn between (_compass.gsc).
gs_log_minimap()
{
	wait 5;
	corners = getEntArray( "minimap_corner", "targetname" );
	if ( corners.size != 2 )
		return;
	data = int( corners[ 0 ].origin[ 0 ] ) + "," + int( corners[ 0 ].origin[ 1 ] ) + ","
	     + int( corners[ 1 ].origin[ 0 ] ) + "," + int( corners[ 1 ].origin[ 1 ] ) + "," + int( getNorthYaw() );
	line = level.gsRunId + "|" + level.gsMapToken + "|" + gs_round() + "|" + getDvar( "net_port" ) + "|0|-|map|" + data;
	file = fopen( level.gsEventFile, "a" );
	if ( isDefined( file ) && file != 0 )
	{
		fwrite( file, line + "\n" );
		fclose( file );
	}
}

// Every 2 s, one count for the cell each playing player stands in.
gs_floor_sample()
{
	level.gsFloor = [];
	for ( ;; )
	{
		wait 2;
		if ( gs_game_over() )
			return;
		players = get_players();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isDefined( p ) || !isDefined( p.sessionstate ) || p.sessionstate != "playing" )
				continue;
			key = int( ( p.origin[ 0 ] + 65536 ) / 64 ) + "," + int( ( p.origin[ 1 ] + 65536 ) / 64 ) + "," + int( ( p.origin[ 2 ] + 65536 ) / 128 );
			if ( !isDefined( level.gsFloor[ key ] ) )
				level.gsFloor[ key ] = 0;
			level.gsFloor[ key ] = level.gsFloor[ key ] + 1;
		}
	}
}

// Live radar lines. The guid goes out in hex because the radar plugin parses it that way.
// Stock maps only: a modded server (fs_game set, e.g. Stairway to Hell) logs nothing.
gs_radar()
{
	if ( getDvar( "fs_game" ) != "" )
		return;
	for ( ;; )
	{
		wait 1;
		if ( gs_game_over() )
			return;
		players = get_players();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isDefined( p ) )
				continue;
			alive = isDefined( p.sessionstate ) && p.sessionstate == "playing";
			state = "up";
			if ( !alive )
				state = "dead";
			else if ( isDefined( p.revivetrigger ) )
				state = "down";
			else if ( isDefined( p.afterlife ) && p.afterlife )
				state = "afterlife";
			logPrint( "LiveRadar;" + gs_hex( p getGuid() ) + ";" + p.origin + ";" + p getPlayerAngles() + ";" + state
			        + ";0;0;0;none;" + gs_num( p.health ) + ";" + gs_num( alive ) + ";0\n" );
		}
	}
}

gs_hex( value )
{
	n = int( value );
	if ( n <= 0 )
		return "0";
	digits = "0123456789abcdef";
	out = "";
	for ( i = 0; i < 16 && n > 0; i++ )
	{
		out = digits[ n % 16 ] + out;
		n = int( n / 16 );
	}
	return out;
}

// The counts go out every 5 minutes (and at game over), 40 cells a line.
gs_floor_flush()
{
	for ( ;; )
	{
		for ( t = 0; t < 300 && !gs_game_over(); t++ )
			wait 1;
		cells = level.gsFloor;
		level.gsFloor = [];
		if ( isDefined( cells ) )
		{
			keys = getArrayKeys( cells );
			data = "";
			n = 0;
			for ( i = 0; i < keys.size; i++ )
			{
				if ( n > 0 )
					data = data + ";";
				data = data + keys[ i ] + "," + cells[ keys[ i ] ];
				n++;
				if ( n == 40 || i == keys.size - 1 )
				{
					gs_level_line( "grid", data );
					data = "";
					n = 0;
				}
			}
		}
		if ( gs_game_over() )
			return;
	}
}

// Where the perk machines, Pack-a-Punch, box spots and wall buys are.
gs_log_marks()
{
	wait 10;
	vending = getEntArray( "zombie_vending", "targetname" );
	for ( i = 0; i < vending.size; i++ )
	{
		if ( !isDefined( vending[ i ].script_noteworthy ) )
			continue;
		type = "perk";
		if ( vending[ i ].script_noteworthy == "specialty_weapupgrade" )
			type = "pap";
		gs_mark( type, vending[ i ].script_noteworthy, vending[ i ].origin );
	}
	for ( t = 0; t < 1200 && !isDefined( level.chests ); t++ )
		wait 1;
	if ( isDefined( level.chests ) )
	{
		for ( i = 0; i < level.chests.size; i++ )
		{
			if ( isDefined( level.chests[ i ] ) )
				gs_mark( "box", "box", level.chests[ i ].origin );
		}
	}
	wallbuys = getstructarray( "weapon_upgrade", "targetname" );
	for ( i = 0; i < wallbuys.size; i++ )
	{
		if ( isDefined( wallbuys[ i ].zombie_weapon_upgrade ) )
			gs_mark( "wall", wallbuys[ i ].zombie_weapon_upgrade, wallbuys[ i ].origin );
	}
}

gs_mark( type, name, origin )
{
	gs_level_line( "mark", type + ":" + name + ":" + int( origin[ 0 ] ) + "," + int( origin[ 1 ] ) + "," + int( origin[ 2 ] ) );
}

gs_level_line( type, data )
{
	line = level.gsRunId + "|" + level.gsMapToken + "|" + gs_round() + "|" + getDvar( "net_port" ) + "|0|-|" + type + "|" + data;
	file = fopen( level.gsEventFile, "a" );
	if ( isDefined( file ) && file != 0 )
	{
		fwrite( file, line + "\n" );
		fclose( file );
	}
}

gs_event( player, type, data )
{
	if ( gs_game_over() )
		return;
	id = "" + player getGuid();
	if ( isDefined( player.persistentClientId ) )
		id = "" + player.persistentClientId;
	name = "";
	if ( isDefined( player.name ) )
		name = gs_clean_name( player.name );
	line = level.gsRunId + "|" + level.gsMapToken + "|" + gs_round() + "|" + getDvar( "net_port" ) + "|"
	     + id + "|" + name + "|" + type + "|" + data;
	file = fopen( level.gsEventFile, "a" );
	if ( isDefined( file ) && file != 0 )
	{
		fwrite( file, line + "\n" );
		fclose( file );
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
