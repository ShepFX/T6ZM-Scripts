#include maps\mp\_utility;
#include common_scripts\utility;

/**
 * Shep Grief (T6 / Black Ops 2 Zombies, zgrief only) - 7 Nov 2026.
 *
 * Two jobs:
 *
 * 1. Team balance. Stock Grief puts a joining player on a random team
 *    (_globallogic_ui::menuautoassign picks teamkeys[randomint()]), so one side often
 *    stacks. level.autoassign is replaced with the same steps, except the team is the
 *    one with fewer players (a coin toss when they're even). Only players who haven't
 *    spawned yet are placed: moving a live player means killing them (the stock code
 *    calls suicide()), so a player who is already in keeps their team.
 *
 * 2. Grief stats for shep.rip. One line per event in logs/GriefEvents.txt:
 *        <runId>|<map>|<round>|<port>|<id>|<name>|<team>|<event>|<data>
 *    runId   random id for this game         map   farm / town / transit / cellblock / ...
 *    id      IW4MAdmin client id (the GUID until IW4MAdmin has set it)
 *    team    A (CIA, axis) or B (CDC, allies), "-" when not known yet
 *    events  start     data = mapname          (once, id/name "-")
 *            hook      data = ok / missing     (once: whether grief hits can be seen)
 *            assign    data = <axis>v<allies>  (a joiner placed on the smaller team; counts before them)
 *            down      data = "<griefer id>:<griefer name>" or "-"
 *                      A grief is an enemy who shot or knifed them in the 5 s before they went down.
 *            revive    data = -                (the reviver's line)
 *            bleedout  data = -
 *            end       data = win / loss / none (everyone still in when the game ends)
 *            winner    data = A / B / none     (once, id/name "-")
 *
 * How BO2 Grief ends (zm_game_module::check_for_round_end): when one team is all down,
 * the other team has to survive to the end of that zombie round; then
 * level.gamemodulewinningteam is set and the game is over. So a "win" is a whole game.
 *
 * Enemy hits: Grief runs level._game_module_player_damage_grief_callback for every hit
 * from the other team (bullets slow, knives push), so it is wrapped here to remember who
 * hit whom, and the stock callback still runs after.
 */

init()
{
	if ( getDvar( "g_gametype" ) != "zgrief" )
		return;

	level.sgFile = getDvar( "fs_homepath" ) + "/logs/GriefEvents.txt";
	level.sgRunId = randomInt( 1000000 ) + "-" + getTime();
	level.sgMap = getDvar( "ui_zm_mapstartlocation" );
	if ( level.sgMap == "" )
		level.sgMap = getDvar( "mapname" );

	level.autoassign = ::sg_autoassign;

	sg_log_level( "start", getDvar( "mapname" ) );
	level thread sg_hook_damage();
	level thread sg_watch_players();
	level thread sg_watch_end();
}

// ── team balance ─────────────────────────────────────────────────────────────

sg_autoassign( comingfrommenu )
{
	// Already in the game: stock behaviour (it keeps their team unless they pick another).
	if ( isDefined( self.hasspawned ) && self.hasspawned )
	{
		self maps\mp\gametypes_zm\_globallogic_ui::menuautoassign( comingfrommenu );
		return;
	}

	axis = 0;
	allies = 0;
	players = get_players();
	for ( i = 0; i < players.size; i++ )
	{
		if ( players[ i ] == self || !isDefined( players[ i ].pers[ "team" ] ) )
			continue;
		if ( players[ i ].pers[ "team" ] == "axis" )
			axis++;
		else if ( players[ i ].pers[ "team" ] == "allies" )
			allies++;
	}

	if ( axis < allies )
		assignment = "axis";
	else if ( allies < axis )
		assignment = "allies";
	else if ( randomInt( 2 ) == 0 )
		assignment = "axis";
	else
		assignment = "allies";

	// The rest is menuautoassign's own steps for a player who hasn't spawned.
	self closemenus();
	self.pers[ "team" ] = assignment;
	self.team = assignment;
	self.pers[ "class" ] = undefined;
	self.class = undefined;
	self.pers[ "weapon" ] = undefined;
	self.pers[ "savedmodel" ] = undefined;
	self maps\mp\gametypes_zm\_globallogic_ui::updateobjectivetext();
	self.sessionteam = assignment;

	if ( !isAlive( self ) )
		self.statusicon = "hud_status_dead";

	self notify( "joined_team" );
	level notify( "joined_team" );
	self notify( "end_respawn" );
	self maps\mp\gametypes_zm\_globallogic_ui::beginclasschoice();
	self setclientscriptmainmenu( game[ "menu_class" ] );

	sg_log( self, "assign", axis + "v" + allies );
}

// ── enemy hits ───────────────────────────────────────────────────────────────

sg_hook_damage()
{
	// zgrief's main() sets the callback; wait a little in case this runs first.
	for ( i = 0; i < 100 && !isDefined( level._game_module_player_damage_grief_callback ); i++ )
		wait 0.1;

	if ( !isDefined( level._game_module_player_damage_grief_callback ) )
	{
		sg_log_level( "hook", "missing" );
		return;
	}

	level.sgStockGriefCallback = level._game_module_player_damage_grief_callback;
	level._game_module_player_damage_grief_callback = ::sg_grief_damage;
	sg_log_level( "hook", "ok" );
}

sg_grief_damage( einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, psoffsettime )
{
	if ( isDefined( eattacker ) && isPlayer( eattacker ) && eattacker != self )
	{
		self.sgGriefer = eattacker;
		self.sgGriefTime = getTime();
	}

	self [[ level.sgStockGriefCallback ]]( einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, psoffsettime );
}

// ── downs, revives, bleed-outs ───────────────────────────────────────────────

sg_watch_players()
{
	for ( ;; )
	{
		players = get_players();
		for ( i = 0; i < players.size; i++ )
		{
			if ( isDefined( players[ i ] ) && !isDefined( players[ i ].sgTracked ) )
			{
				players[ i ].sgTracked = true;
				players[ i ] thread sg_track_player();
			}
		}
		wait 1;
	}
}

sg_track_player()
{
	self endon( "disconnect" );

	downs = sg_num( self.downs );
	revives = sg_num( self.revives );
	state = "";
	for ( ;; )
	{
		wait 0.2;
		if ( sg_game_over() )
			return;

		now = sg_num( self.downs );
		if ( now > downs )
			sg_log( self, "down", sg_griefer_of( self ) );
		downs = now;

		now = sg_num( self.revives );
		if ( now > revives )
			sg_log( self, "revive", "-" );
		revives = now;

		// "playing" to "spectator" is a bleed-out; a mid-game joiner starts as a spectator.
		cur = "";
		if ( isDefined( self.sessionstate ) )
			cur = self.sessionstate;
		if ( cur == "spectator" && state == "playing" )
			sg_log( self, "bleedout", "-" );
		state = cur;
	}
}

sg_griefer_of( player )
{
	if ( !isDefined( player.sgGriefer ) || !isDefined( player.sgGriefTime ) )
		return "-";
	if ( getTime() - player.sgGriefTime > 5000 )
		return "-";
	g = player.sgGriefer;
	if ( !isDefined( g ) || !isPlayer( g ) || sg_team( g ) == sg_team( player ) )
		return "-";
	return sg_id( g ) + ":" + sg_clean_name( g.name );
}

// ── end of the game ──────────────────────────────────────────────────────────

sg_watch_end()
{
	while ( !isDefined( level.gamemodulewinningteam ) && !sg_game_over() )
		wait 0.25;

	winner = "none";
	if ( isDefined( level.gamemodulewinningteam ) )
		winner = level.gamemodulewinningteam;

	players = get_players();
	for ( i = 0; i < players.size; i++ )
	{
		result = "none";
		team = sg_team( players[ i ] );
		if ( winner != "none" && team != "-" )
		{
			if ( team == winner )
				result = "win";
			else
				result = "loss";
		}
		sg_log( players[ i ], "end", result );
	}
	sg_log_level( "winner", winner );
}

sg_game_over()
{
	return isDefined( level.intermission ) && level.intermission;
}

// ── log lines ────────────────────────────────────────────────────────────────

sg_log( player, event, data )
{
	sg_write( sg_id( player ) + "|" + sg_clean_name( player.name ) + "|" + sg_team( player ), event, data );
}

sg_log_level( event, data )
{
	sg_write( "0|-|-", event, data );
}

sg_write( who, event, data )
{
	line = level.sgRunId + "|" + level.sgMap + "|" + sg_round() + "|" + getDvar( "net_port" ) + "|" + who + "|" + event + "|" + data;
	file = fopen( level.sgFile, "a" );
	if ( isDefined( file ) && file != 0 )
	{
		fwrite( file, line + "\n" );
		fclose( file );
	}
}

sg_id( player )
{
	if ( isDefined( player.persistentClientId ) )
		return "" + player.persistentClientId;
	return "" + player getGuid();
}

sg_team( player )
{
	if ( isDefined( player._encounters_team ) )
		return player._encounters_team;
	if ( isDefined( player.team ) && player.team == "axis" )
		return "A";
	if ( isDefined( player.team ) && player.team == "allies" )
		return "B";
	return "-";
}

sg_round()
{
	if ( isDefined( level.round_number ) )
		return level.round_number;
	return 0;
}

sg_num( value )
{
	if ( isDefined( value ) )
		return int( value );
	return 0;
}

// The log is "|"-separated: keep names on one field.
sg_clean_name( name )
{
	if ( !isDefined( name ) )
		return "";
	out = "";
	for ( i = 0; i < name.size; i++ )
	{
		c = name[ i ];
		if ( c == "|" || c == "\n" || c == "\r" )
			c = " ";
		out += c;
	}
	return out;
}
