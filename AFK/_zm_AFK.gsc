#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

//
// AFK System for T6 Zombies (Plutonium)
// Usage: .afk in chat to toggle AFK mode
// Requires: Round 20+, 2-hour cooldown between uses
//

init()
{
	println( "[AFK] init() called" );

	level.afk_system = spawnstruct();
	level.afk_system.min_round = 20;
	level.afk_system.cooldown_ms = 7200000;
	level.afk_system.duration_s = 900;
	level.afk_system.activation_delay_s = 60;
	level.afk_system.round_frozen = false;
	level.afk_system.saved_round_zombies = 0;
	level.afk_system.saved_ai_limit = 0;
	level.afk_system.spawn_points = undefined;
	level.afk_system.verified_spawn = undefined;

	level thread on_player_connect();
	level thread round_freeze_monitor();
	level thread cache_spawn_points();
	// level thread debug_hud_monitor();

	// Register .afk chat command (t6-gsc-utils)
	chat::register_command( ".afk", ::on_afk_command, true, false );

	println( "[AFK] init() complete" );
}

// ============================================================
// Player Connection & Chat Listener
// ============================================================

on_player_connect()
{
	level endon( "end_game" );

	for ( ;; )
	{
		level waittill( "connected", player );

		println( "[AFK] player connected: " + player.name );

		player.is_afk = false;
		player.afk_activating = false;

		if ( !isdefined( player.pers["afk_last_used"] ) )
			player.pers["afk_last_used"] = 0;

		player thread capture_spawn_position();
	}
}

on_afk_command( args )
{
	println( "[AFK] .afk command by " + self.name );
	self thread try_toggle_afk();
}

// ============================================================
// Spawn Point Cache & Capture
// ============================================================

cache_spawn_points()
{
	wait 5;

	spawns = getstructarray( "player_respawn_point", "targetname" );

	if ( !isdefined( spawns ) || spawns.size == 0 )
		spawns = getstructarray( "initial_spawn_points", "targetname" );

	if ( isdefined( spawns ) && spawns.size > 0 )
	{
		level.afk_system.spawn_points = spawns;
		println( "[AFK] cached " + spawns.size + " spawn points" );
	}
	else
		println( "[AFK] WARNING: no spawn points found" );
}

capture_spawn_position()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self waittill( "spawned_player" );

	if ( !isdefined( level.afk_system.verified_spawn ) )
	{
		level.afk_system.verified_spawn = self.origin;
		println( "[AFK] captured verified spawn from " + self.name + " at (" + int( self.origin[0] ) + "," + int( self.origin[1] ) + "," + int( self.origin[2] ) + ")" );
	}
}

get_afk_spawn_point()
{
	// Primary: verified spawn from actual player spawn position
	if ( isdefined( level.afk_system.verified_spawn ) )
	{
		point = spawnstruct();
		point.origin = level.afk_system.verified_spawn;
		point.angles = ( 0, 0, 0 );
		println( "[AFK] using verified spawn at (" + int( point.origin[0] ) + "," + int( point.origin[1] ) + "," + int( point.origin[2] ) + ")" );
		return point;
	}

	// Fallback: struct-based spawn points (pick farthest from zombies)
	if ( isdefined( level.afk_system.spawn_points ) && level.afk_system.spawn_points.size > 0 )
	{
		spawns = level.afk_system.spawn_points;
		best = spawns[0];
		best_dist = 0;

		zombies = get_round_enemy_array();

		for ( i = 0; i < spawns.size; i++ )
		{
			if ( !isdefined( spawns[i].origin ) )
				continue;

			min_zombie_dist = 999999999;

			if ( isdefined( zombies ) && zombies.size > 0 )
			{
				for ( z = 0; z < zombies.size; z++ )
				{
					if ( !isdefined( zombies[z] ) || !isalive( zombies[z] ) )
						continue;

					d = distancesquared( spawns[i].origin, zombies[z].origin );
					if ( d < min_zombie_dist )
						min_zombie_dist = d;
				}
			}

			if ( min_zombie_dist > best_dist )
			{
				best_dist = min_zombie_dist;
				best = spawns[i];
			}
		}

		println( "[AFK] WARNING: using fallback spawn struct (verified spawn not captured)" );
		return best;
	}

	println( "[AFK] WARNING: no spawn points available for teleport" );
	return undefined;
}

// ============================================================
// AFK Toggle & Eligibility
// ============================================================

try_toggle_afk()
{
	// Cancel pending activation
	if ( self.afk_activating )
	{
		self.afk_activating = false;
		self notify( "afk_cancel" );
		self iprintln( "AFK activation ^1cancelled^7." );
		return;
	}

	// Deactivate if currently AFK
	if ( self.is_afk )
	{
		self thread deactivate_afk();
		return;
	}

	// Must not be spectator
	if ( self.sessionstate == "spectator" )
	{
		self iprintln( "Cannot use AFK while ^1spectating^7." );
		return;
	}

	// Round gate
	if ( level.round_number < level.afk_system.min_round )
	{
		self iprintln( "AFK available from round ^3" + level.afk_system.min_round + "^7." );
		return;
	}

	// Cooldown gate
	if ( self.pers["afk_last_used"] > 0 )
	{
		elapsed = gettime() - self.pers["afk_last_used"];
		if ( elapsed < level.afk_system.cooldown_ms )
		{
			remaining_min = int( ( level.afk_system.cooldown_ms - elapsed ) / 60000 );
			self iprintln( "AFK on cooldown. ^3" + remaining_min + "^7 min remaining." );
			return;
		}
	}

	// Must be alive
	if ( !isalive( self ) )
	{
		self iprintln( "Cannot use AFK while ^1dead^7." );
		return;
	}

	// Must not be downed
	if ( isdefined( self.revivetrigger ) )
	{
		self iprintln( "Cannot use AFK while ^1downed^7." );
		return;
	}

	println( "[AFK] " + self.name + " passed all checks, starting activation delay" );
	self thread afk_activation_delay();
}

// ============================================================
// Activation Delay (1-minute anti-panic)
// ============================================================

afk_activation_delay()
{
	self endon( "disconnect" );
	self endon( "afk_cancel" );
	level endon( "end_game" );

	self.afk_activating = true;
	self.afk_health_at_start = self.health;
	delay = level.afk_system.activation_delay_s;

	println( "[AFK] activation delay started for " + self.name + " (" + delay + "s)" );

	self iprintln( "AFK activating in ^3" + delay + "^7s. Type ^3.afk^7 to cancel." );

	// Watch for damage during grace period
	self thread afk_damage_watcher();

	for ( i = delay; i > 0; i-- )
	{
		if ( !isalive( self ) || isdefined( self.revivetrigger ) )
		{
			println( "[AFK] activation cancelled (death/down) for " + self.name );
			self.afk_activating = false;
			self iprintln( "AFK activation ^1cancelled^7." );
			return;
		}

		if ( i == 30 || i == 10 || ( i <= 5 && i > 0 ) )
			self iprintln( "AFK in ^3" + i + "^7..." );

		wait 1;
	}

	// Final safety check
	if ( !isalive( self ) || isdefined( self.revivetrigger ) )
	{
		println( "[AFK] activation cancelled (final check) for " + self.name );
		self.afk_activating = false;
		self iprintln( "AFK activation ^1cancelled^7." );
		return;
	}

	self thread activate_afk();
}

afk_damage_watcher()
{
	self endon( "disconnect" );
	self endon( "afk_cancel" );
	level endon( "end_game" );

	self waittill( "damage", amount, attacker, dir, point, mod );

	println( "[AFK] damage during grace period for " + self.name + " (" + amount + " " + mod + ")" );

	if ( self.afk_activating )
	{
		self.afk_activating = false;
		self iprintln( "AFK activation ^1cancelled^7 - you took damage!" );
		self notify( "afk_cancel" );
	}
}

// ============================================================
// Activate / Deactivate AFK
// ============================================================

activate_afk()
{
	println( "[AFK] activating for " + self.name + " (score=" + self.score + ")" );

	self.afk_activating = false;
	self.is_afk = true;
	self.afk_saved_score = self.score;

	// Save pre-AFK position for restore on deactivate
	self.afk_saved_origin = self.origin;
	self.afk_saved_angles = self getplayerangles();

	// Teleport to spawn to prevent positional exploits
	spawn_point = get_afk_spawn_point();
	if ( isdefined( spawn_point ) )
	{
		self setorigin( spawn_point.origin );
		if ( isdefined( spawn_point.angles ) )
			self setplayerangles( spawn_point.angles );
		println( "[AFK] teleported " + self.name + " to spawn" );
	}

	// Lock controls (keeps chat open)
	self disableweapons();
	self setmovespeedscale( 0 );
	self allowjump( 0 );

	// Godmode + zombie AI ignore
	self enableinvulnerability();
	self.ignoreme = true;

	// Zombie blood visual (ghostly screen effect while AFK)
	self useservervisionset( 1 );
	self setvisionsetforplayer( "zm_powerup_zombie_blood", 1 );

	// HUD - "AFK" label
	self.afk_hud_label = newclienthudelem( self );
	self.afk_hud_label.x = 0;
	self.afk_hud_label.y = -60;
	self.afk_hud_label.alignx = "center";
	self.afk_hud_label.aligny = "middle";
	self.afk_hud_label.horzalign = "center";
	self.afk_hud_label.vertalign = "middle";
	self.afk_hud_label.fontscale = 2.5;
	self.afk_hud_label.alpha = 1;
	self.afk_hud_label.color = ( 1, 0.8, 0 );
	self.afk_hud_label.sort = 100;
	self.afk_hud_label.hidewheninmenu = false;
	self.afk_hud_label setText( "AFK" );

	// HUD - countdown timer
	self.afk_hud_timer = newclienthudelem( self );
	self.afk_hud_timer.x = 0;
	self.afk_hud_timer.y = -35;
	self.afk_hud_timer.alignx = "center";
	self.afk_hud_timer.aligny = "middle";
	self.afk_hud_timer.horzalign = "center";
	self.afk_hud_timer.vertalign = "middle";
	self.afk_hud_timer.fontscale = 2;
	self.afk_hud_timer.alpha = 1;
	self.afk_hud_timer.color = ( 1, 0.8, 0 );
	self.afk_hud_timer.sort = 100;
	self.afk_hud_timer.hidewheninmenu = false;

	// Broadcast to all players
	foreach ( player in level.players )
		player iprintln( self.name + " is now ^3AFK^7." );

	self thread afk_timer_countdown();
	self thread afk_score_lock();

	println( "[AFK] " + self.name + " is now AFK" );
}

deactivate_afk()
{
	if ( !self.is_afk )
		return;

	println( "[AFK] deactivating for " + self.name );

	self.is_afk = false;
	self.pers["afk_last_used"] = gettime();

	// Restore controls
	self enableweapons();
	self setmovespeedscale( 1 );
	self allowjump( 1 );

	// Remove AI ignore but keep invulnerability for grace period
	self.ignoreme = false;

	// Clear zombie blood visual
	self useservervisionset( 0 );

	// Restore pre-AFK position
	if ( isdefined( self.afk_saved_origin ) )
	{
		self setorigin( self.afk_saved_origin );
		self setplayerangles( self.afk_saved_angles );
		println( "[AFK] restored " + self.name + " to pre-AFK position" );
		self.afk_saved_origin = undefined;
		self.afk_saved_angles = undefined;
	}

	// 30s invulnerability grace period after resuming
	self thread afk_resume_grace();

	// Restore score
	self.score = self.afk_saved_score;

	// Destroy HUD
	if ( isdefined( self.afk_hud_label ) )
		self.afk_hud_label destroy();
	if ( isdefined( self.afk_hud_timer ) )
		self.afk_hud_timer destroy();

	// Clear saved score
	self.afk_saved_score = undefined;

	// Kill sub-threads (score lock, timer countdown)
	self notify( "afk_ended" );

	// Broadcast
	foreach ( player in level.players )
		player iprintln( self.name + " is no longer ^3AFK^7." );

	println( "[AFK] " + self.name + " is no longer AFK" );
}

// ============================================================
// Score Lock & Timer Countdown
// ============================================================

afk_score_lock()
{
	self endon( "disconnect" );
	self endon( "afk_ended" );

	for ( ;; )
	{
		wait 0.5;
		if ( self.score != self.afk_saved_score )
		{
			println( "[AFK] score drift for " + self.name + ": " + self.score + " -> " + self.afk_saved_score );
			self.score = self.afk_saved_score;
		}
	}
}

afk_timer_countdown()
{
	self endon( "disconnect" );
	self endon( "afk_ended" );

	total = level.afk_system.duration_s;

	// Use setTimer for client-side countdown (no config string spam)
	self.afk_hud_timer setTimer( total );

	for ( i = total; i >= 0; i-- )
	{
		// Timed warnings
		if ( i == 300 )
			self iprintlnbold( "^3AFK expires in 5 minutes." );
		else if ( i == 60 )
		{
			self iprintlnbold( "^1AFK expires in 1 minute!" );
			self.afk_hud_timer.color = ( 1, 0.2, 0.2 );
			self.afk_hud_label.color = ( 1, 0.2, 0.2 );
		}
		else if ( i == 30 )
			self iprintlnbold( "^1AFK expires in 30 seconds!" );
		else if ( i == 10 )
			self iprintlnbold( "^1AFK expires in 10 seconds!" );

		if ( i > 0 )
			wait 1;
	}

	// Timer expired — force deactivate
	println( "[AFK] timer expired for " + self.name );
	self iprintlnbold( "^1AFK time expired!" );
	self thread deactivate_afk();
}

afk_resume_grace()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	grace = 30;
	self iprintln( "^3Invulnerable for " + grace + "s - get your bearings!" );
	println( "[AFK] " + self.name + " resume grace started (" + grace + "s)" );

	for ( i = grace; i > 0; i-- )
	{
		if ( i == 10 )
			self iprintln( "^1Invulnerability ends in 10s!" );
		else if ( i == 5 )
			self iprintln( "^1Invulnerability ends in 5s!" );

		wait 1;
	}

	self disableinvulnerability();
	self iprintln( "^1Invulnerability ended." );
	println( "[AFK] " + self.name + " resume grace ended" );
}

// ============================================================
// Round Freeze System
// ============================================================

round_freeze_monitor()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait 0.5;

		active_count = 0;
		afk_count = 0;

		foreach ( player in level.players )
		{
			if ( !isdefined( player.is_afk ) )
				continue;

			if ( player.is_afk )
				afk_count++;
			else if ( isalive( player ) && player.sessionstate == "playing" )
				active_count++;
		}

		should_freeze = ( afk_count > 0 && active_count == 0 );

		if ( should_freeze && !level.afk_system.round_frozen )
		{
			println( "[AFK] freeze triggered: afk=" + afk_count + " active=" + active_count );
			freeze_round();
		}
		else if ( !should_freeze && level.afk_system.round_frozen )
		{
			println( "[AFK] unfreeze triggered: afk=" + afk_count + " active=" + active_count );
			unfreeze_round();
		}
	}
}

freeze_round()
{
	alive_at_freeze = get_current_zombie_count();

	level.afk_system.round_frozen = true;
	level.afk_system.saved_round_zombies = alive_at_freeze + level.zombie_total;
	level.afk_system.saved_ai_limit = level.zombie_ai_limit;

	println( "[AFK] freeze: alive=" + alive_at_freeze + " queue=" + level.zombie_total + " budget=" + level.afk_system.saved_round_zombies );

	// Stop spawning
	level.zombie_ai_limit = 0;

	// Prevent round-end: ensure zombie_total > 0 so game thinks more are coming
	if ( level.zombie_total <= 0 )
		level.zombie_total = 1;

	foreach ( player in level.players )
		player iprintln( "^3Round paused - all players AFK." );
}

unfreeze_round()
{
	alive_now = get_current_zombie_count();

	// Recalculate queue: if zombies died during freeze (lava, env damage),
	// add them back to the queue so the round doesn't skip
	new_queue = level.afk_system.saved_round_zombies - alive_now;
	if ( new_queue < 0 )
		new_queue = 0;

	println( "[AFK] unfreeze: alive=" + alive_now + " budget=" + level.afk_system.saved_round_zombies + " new_queue=" + new_queue );

	level.afk_system.round_frozen = false;
	level.zombie_total = new_queue;
	level.zombie_ai_limit = level.afk_system.saved_ai_limit;

	foreach ( player in level.players )
		player iprintln( "^2Round resumed." );
}

// ============================================================
// On-Screen Debug HUD (per player, top-left)
// UNCOMMENTED - enable debug_hud_monitor() in init() to use
// ============================================================

debug_hud_monitor()
{
	level endon( "end_game" );

	for ( ;; )
	{
		level waittill( "connected", player );
		player thread debug_hud_player();
	}
}

debug_hud_player()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	wait 1;

	// Line 1: player + eligibility state
	self.afk_dbg_line1 = newclienthudelem( self );
	self.afk_dbg_line1.x = 5;
	self.afk_dbg_line1.y = 30;
	self.afk_dbg_line1.alignx = "left";
	self.afk_dbg_line1.aligny = "top";
	self.afk_dbg_line1.horzalign = "left";
	self.afk_dbg_line1.vertalign = "top";
	self.afk_dbg_line1.fontscale = 1.2;
	self.afk_dbg_line1.alpha = 0.85;
	self.afk_dbg_line1.color = ( 0.8, 1, 0.8 );
	self.afk_dbg_line1.sort = 200;
	self.afk_dbg_line1.hidewheninmenu = true;

	// Line 2: round freeze + player counts
	self.afk_dbg_line2 = newclienthudelem( self );
	self.afk_dbg_line2.x = 5;
	self.afk_dbg_line2.y = 45;
	self.afk_dbg_line2.alignx = "left";
	self.afk_dbg_line2.aligny = "top";
	self.afk_dbg_line2.horzalign = "left";
	self.afk_dbg_line2.vertalign = "top";
	self.afk_dbg_line2.fontscale = 1.2;
	self.afk_dbg_line2.alpha = 0.85;
	self.afk_dbg_line2.color = ( 0.8, 1, 0.8 );
	self.afk_dbg_line2.sort = 200;
	self.afk_dbg_line2.hidewheninmenu = true;

	// Update every 5 seconds to avoid config string overflow
	for ( ;; )
	{
		if ( self.is_afk )
			state = "^1AFK";
		else if ( self.afk_activating )
			state = "^3ACTV";
		else
			state = "^2IDLE";

		alive_str = "^2Y";
		if ( !isalive( self ) )
			alive_str = "^1N";

		downed_str = "^2N";
		if ( isdefined( self.revivetrigger ) )
			downed_str = "^1Y";

		round_num = "?";
		if ( isdefined( level.round_number ) )
			round_num = "" + level.round_number;

		cd_str = "^2RDY";
		if ( isdefined( self.pers["afk_last_used"] ) && self.pers["afk_last_used"] > 0 )
		{
			cd_elapsed = gettime() - self.pers["afk_last_used"];
			if ( cd_elapsed < level.afk_system.cooldown_ms )
			{
				cd_remaining_s = int( ( level.afk_system.cooldown_ms - cd_elapsed ) / 1000 );
				if ( cd_remaining_s < 60 )
					cd_str = "^1" + cd_remaining_s + "s";
				else
					cd_str = "^1" + int( cd_remaining_s / 60 ) + "m";
			}
		}

		self.afk_dbg_line1 setText( "^6[AFK] ^7" + state + " ^7al:" + alive_str + " dn:" + downed_str + " r:" + round_num + " cd:" + cd_str );

		frozen_str = "^2N";
		if ( level.afk_system.round_frozen )
			frozen_str = "^1Y";

		zalive = "" + get_current_zombie_count();

		ztotal = "?";
		if ( isdefined( level.zombie_total ) )
			ztotal = "" + level.zombie_total;

		active_c = 0;
		afk_c = 0;
		foreach ( p in level.players )
		{
			if ( isdefined( p.is_afk ) && p.is_afk )
				afk_c++;
			else if ( isalive( p ) && p.sessionstate == "playing" )
				active_c++;
		}

		self.afk_dbg_line2 setText( "^6[AFK] ^7frz:" + frozen_str + " za:" + zalive + " zq:" + ztotal + " p:" + active_c + "/^1" + afk_c );

		wait 5;
	}
}
