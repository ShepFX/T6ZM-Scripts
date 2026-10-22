// T6 ZM - Zombie counter, run clock and round splits (Shep HUD, 22 Oct 2026)
//
// Drawn like the game's own HUD rather than as a panel: no boxes or bars, just
// text in the top-right corner, clear of the message feed on the left.
//
//     ZOMBIES 24        zombies left this round (alive + still to spawn), red at 5 or fewer
//        ALIVE 9        of those, how many are up on the map right now (smaller, grey)
//        DOGS 2        only while dogs are alive, or on a dog round
//     12:34.5           run clock (from round 1, the figure the speedrun boards use)
//     ROUND 12  1:23    the round that just ended, for 6 seconds
//
// .counter hides/shows the counter, .timer the clock and splits.
//
// No leaks:
//   - settext() only ever gets the fixed strings in shud_strings(); every number goes
//     through setvalue() or the client-side timer, so the configstring table cannot
//     fill up however long a game runs ("G_FindConfigstringIndex: overflow").
//   - At most 13 elements per player (no backgrounds), destroyed on disconnect, and
//     every per-player thread ends on disconnect.
//   - One level thread counts the enemies for everyone.

#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;


// ════════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ════════════════════════════════════════════════════════════════════════════

init()
{
    if ( isdefined( level.zc_hud_initialized ) && level.zc_hud_initialized )
        return;

    level.zc_hud_initialized = true;
    shud_strings();
    t6rt_init_state();
    level thread t6rt_round_monitor();
    level thread _zc_level_counter();
    level thread _zc_connect_monitor();
    level thread _zc_chat_monitor();
}

// Every string the HUD shows, registered once in a fixed order before any player
// HUD exists.
shud_strings()
{
    e = newhudelem();
    e.alpha = 0;
    e settext( "ZOMBIES" );
    e settext( "DOGS" );
    e settext( "ROUND" );
    e settext( ":" );
    e settext( "0" );
    e settext( "ALIVE" );
    e destroy();
}


// ════════════════════════════════════════════════════════════════════════════
//  LAYOUT
//  Units are the 640x480 HUD space, anchored to the player's own safe area
//  (user_left / user_top), which is where the game puts its own HUD.
// ════════════════════════════════════════════════════════════════════════════

// Everything lines up on the right edge; a label sits left of its number, so
// it is placed from the width of the digits.
shud_layout_init()
{
    self.shud_x = -6;         // right edge of the stack, from the right of the safe area
    self.shud_y = 8;          // top of the first row (clear of the Plutonium watermark)
    self.shud_num_w = 10.5;   // one big digit (default font, scale 2.0)
    self.shud_lab_dy = 8;     // label below the number's top, so the baselines meet
    self.shud_row_h = 20;     // one counter row
    self.shud_alive_w = 8.4;  // one digit of the smaller ALIVE number (scale 1.6)
    self.shud_alive_dy = 6;   // its label below the number's top
    self.shud_alive_h = 16;   // the ALIVE row
    self.shud_clock_h = 15;   // the clock row
    self.shud_small_w = 5;    // one digit of the small font
}

shud_digits( n )
{
    if ( n >= 100 )
        return 3;
    if ( n >= 10 )
        return 2;
    return 1;
}

// The label sits left of its number, so it moves when the digit count changes.
shud_place_label( num_digits, lab )
{
    lab.x = self.shud_x - num_digits * self.shud_num_w - 5;
}


// ════════════════════════════════════════════════════════════════════════════
//  LEVEL-WIDE ENEMY COUNT
//  One thread walks the zombie array per tick and caches the totals; every
//  player's HUD loop just reads them.
// ════════════════════════════════════════════════════════════════════════════

_zc_level_counter()
{
    level endon( "end_game" );

    level.zc_total_z = 0;
    level.zc_total_d = 0;
    level.zc_live_z = 0;
    level.zc_dog_round = 0;

    for ( ;; )
    {
        wait 0.1;

        // Nothing to count for while the map is empty.
        if ( !isdefined( level.players ) || level.players.size == 0 )
        {
            wait 0.9;
            continue;
        }

        is_dog_round = level flag_exists( "dog_round" ) && flag( "dog_round" );

        live_z = 0;
        live_d = 0;
        enemies = get_round_enemy_array();
        if ( isdefined( enemies ) )
        {
            for ( i = 0; i < enemies.size; i++ )
            {
                if ( !isdefined( enemies[i] ) )
                    continue;
                if ( isdefined( enemies[i].is_dog ) && enemies[i].is_dog )
                    live_d++;
                else
                    live_z++;
            }
        }

        remaining = 0;
        if ( isdefined( level.zombie_total ) && level.zombie_total > 0 )
            remaining = level.zombie_total;

        // The spawn queue is dogs on a dog round and zombies otherwise; the game
        // does not say which queued spawns will be dogs on a mixed round.
        if ( is_dog_round )
        {
            level.zc_total_z = live_z;
            level.zc_total_d = live_d + remaining;
        }
        else
        {
            level.zc_total_z = live_z + remaining;
            level.zc_total_d = live_d;
        }

        level.zc_live_z = live_z;
        level.zc_dog_round = is_dog_round;
    }
}


// ════════════════════════════════════════════════════════════════════════════
//  PLAYERS
// ════════════════════════════════════════════════════════════════════════════

_zc_connect_monitor()
{
    level endon( "end_game" );
    players = get_players();
    for ( i = 0; i < players.size; i++ )
        players[i] thread shud_build();
    for ( ;; )
    {
        level waittill( "connected", player );
        player thread shud_build();
    }
}

// Preferences live for the current game.
_zc_load_pref( player )
{
    if ( isdefined( player.pers["zc_enabled"] ) )
        return player.pers["zc_enabled"];

    player.pers["zc_enabled"] = 1;
    return 1;
}

_zc_save_pref( player, enabled )
{
    player.pers["zc_enabled"] = enabled;
}

_zc_chat_monitor()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "say", text, player );

        if ( !isdefined( text ) || !isdefined( player ) )
            continue;
        if ( !isdefined( player.shud_ready ) || !player.shud_ready )
            continue; // HUD not built yet

        command = _zc_sanitize( text );

        if ( command == ".counter" )
        {
            player.zc_enabled = !player.zc_enabled;
            _zc_save_pref( player, player.zc_enabled );
            player shud_refresh( 0.20 );
        }
        else if ( command == ".timer" )
        {
            player.t6rt_enabled = !player.t6rt_enabled;
            player shud_refresh( 0.20 );
        }
    }
}

_zc_sanitize( text )
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


// ════════════════════════════════════════════════════════════════════════════
//  HUD
// ════════════════════════════════════════════════════════════════════════════

shud_build()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    self waittill( "spawned_player" );

    if ( isdefined( self.shud_ready ) && self.shud_ready )
        return;

    self shud_layout_init();
    x = self.shud_x;

    // Counter: a big number with a small label in front of it.
    self.zc_zval = shud_text( self, "right", x, 0, "default", 2.0, 0.95, 0.95, 0.92 );
    self.zc_zval setvalue( 0 );
    self.zc_zlab = shud_text( self, "right", x, 0, "small", 1.0, 0.86, 0.86, 0.82 );
    self.zc_zlab settext( "ZOMBIES" );
    self shud_place_label( 1, self.zc_zlab );

    self.zc_aval = shud_text( self, "right", x, 0, "default", 1.6, 0.74, 0.76, 0.78 );
    self.zc_aval setvalue( 0 );
    self.zc_alab = shud_text( self, "right", x, 0, "small", 1.0, 0.74, 0.76, 0.78 );
    self.zc_alab settext( "ALIVE" );
    self.zc_alab.x = x - self.shud_alive_w - 5;

    self.zc_dval = shud_text( self, "right", x, 0, "default", 2.0, 0.94, 0.70, 0.24 );
    self.zc_dval setvalue( 0 );
    self.zc_dlab = shud_text( self, "right", x, 0, "small", 1.0, 0.94, 0.70, 0.24 );
    self.zc_dlab settext( "DOGS" );
    self shud_place_label( 1, self.zc_dlab );

    // Run clock: counts up on the client (see t6rt_redraw).
    self.t6rt_total_time = shud_text( self, "right", x, 0, "default", 1.3, 0.95, 0.95, 0.92 );

    // Split: "ROUND 12  1:23". Fixed labels plus setvalue() numbers; the seconds
    // are one number with a separate "0" in front under 10 seconds.
    self.t6rt_split_label = shud_text( self, "right", x, 0, "small", 1.0, 0.86, 0.86, 0.82 );
    self.t6rt_split_label settext( "ROUND" );
    self.t6rt_split_round = shud_text( self, "right", x, 0, "small", 1.0, 0.86, 0.86, 0.82 );
    self.t6rt_split_round setvalue( 0 );
    self.t6rt_split_tx = x;
    self.t6rt_split_secs  = shud_text( self, "right", self.t6rt_split_tx,      0, "small", 1.0, 0.66, 0.83, 1.00 );
    self.t6rt_split_pad   = shud_text( self, "right", self.t6rt_split_tx - 5,  0, "small", 1.0, 0.66, 0.83, 1.00 );
    self.t6rt_split_pad settext( "0" );
    self.t6rt_split_colon = shud_text( self, "right", self.t6rt_split_tx - 10, 0, "small", 1.0, 0.66, 0.83, 1.00 );
    self.t6rt_split_colon settext( ":" );
    self.t6rt_split_mins  = shud_text( self, "right", self.t6rt_split_tx - 13, 0, "small", 1.0, 0.66, 0.83, 1.00 );
    self.t6rt_split_secs setvalue( 0 );
    self.t6rt_split_mins setvalue( 0 );

    self.t6rt_split_elems = [];
    self.t6rt_split_elems[0] = self.t6rt_split_label;
    self.t6rt_split_elems[1] = self.t6rt_split_round;
    self.t6rt_split_elems[2] = self.t6rt_split_secs;
    self.t6rt_split_elems[3] = self.t6rt_split_pad;
    self.t6rt_split_elems[4] = self.t6rt_split_colon;
    self.t6rt_split_elems[5] = self.t6rt_split_mins;

    // Everything starts hidden; shud_refresh() shows what applies.
    elems = self shud_all_elems();
    for ( i = 0; i < elems.size; i++ )
        elems[i].alpha = 0;

    self.zc_enabled = _zc_load_pref( self );
    self.t6rt_enabled = level.t6rt_enabled_default;
    self.zc_zshow = true;
    self.zc_ashow = false;
    self.zc_dshow = false;
    self.t6rt_split_showing = false;
    self.t6rt_split_padded = true;
    self.t6rt_seen_generation = -1;
    self.t6rt_seen_timer_generation = -1;
    self.shud_ready = true;

    self thread shud_cleanup();
    self shud_refresh( 0 );
    self thread shud_counter_loop();
    self thread t6rt_refresh_loop();
    self thread t6rt_split_loop();
}

shud_all_elems()
{
    elems = [];
    elems[elems.size] = self.zc_zval;
    elems[elems.size] = self.zc_zlab;
    elems[elems.size] = self.zc_aval;
    elems[elems.size] = self.zc_alab;
    elems[elems.size] = self.zc_dval;
    elems[elems.size] = self.zc_dlab;
    if ( isdefined( self.t6rt_total_time ) )
        elems[elems.size] = self.t6rt_total_time;
    for ( i = 0; i < self.t6rt_split_elems.size; i++ )
        elems[elems.size] = self.t6rt_split_elems[i];
    return elems;
}

// The clock element is replaced whenever the run restarts, so this looks the
// elements up when the player leaves rather than remembering them now.
shud_cleanup()
{
    self waittill( "disconnect" );

    elems = self shud_all_elems();
    for ( i = 0; i < elems.size; i++ )
    {
        if ( isdefined( elems[i] ) )
            elems[i] destroy();
    }
}

// Puts every row where it belongs for what is on show, and fades each element
// to its alpha. Rows stack from the top: zombies, alive, dogs, clock, split.
shud_refresh( t )
{
    y = self.shud_y;

    za = 0;
    aa = 0;
    da = 0;
    if ( self.zc_enabled )
    {
        if ( self.zc_zshow )
        {
            self shud_place_row( self.zc_zval, self.zc_zlab, y );
            y += self.shud_row_h;
            za = 1;
        }
        if ( self.zc_zshow && self.zc_ashow )
        {
            self.zc_aval.y = y;
            self.zc_alab.y = y + self.shud_alive_dy;
            y += self.shud_alive_h;
            aa = 1;
        }
        if ( self.zc_dshow )
        {
            self shud_place_row( self.zc_dval, self.zc_dlab, y );
            y += self.shud_row_h;
            da = 1;
        }
        y += 2;
    }
    shud_fade( self.zc_zval, za, t );
    shud_fade( self.zc_zlab, za * 0.8, t );
    shud_fade( self.zc_aval, aa * 0.9, t );
    shud_fade( self.zc_alab, aa * 0.7, t );
    shud_fade( self.zc_dval, da, t );
    shud_fade( self.zc_dlab, da * 0.85, t );

    ca = 0;
    sa = 0;
    if ( self.t6rt_enabled )
    {
        if ( level.t6rt_total_start_ms > 0 )
            ca = 0.9;
        if ( self.t6rt_split_showing )
            sa = 1;
    }
    if ( isdefined( self.t6rt_total_time ) )
    {
        self.t6rt_total_time.y = y;
        shud_fade( self.t6rt_total_time, ca, t );
    }
    y += self.shud_clock_h;

    for ( i = 0; i < self.t6rt_split_elems.size; i++ )
    {
        self.t6rt_split_elems[i].y = y;
        a = sa;
        if ( i == 0 || i == 1 )
            a = sa * 0.8;
        if ( i == 3 && !self.t6rt_split_padded )
            a = 0;
        shud_fade( self.t6rt_split_elems[i], a, t );
    }
}

// The label sits on the number's baseline.
shud_place_row( num, lab, y )
{
    num.y = y;
    lab.y = y + self.shud_lab_dy;
}

shud_fade( e, a, t )
{
    if ( !isdefined( e ) )
        return;
    if ( t > 0 )
        e fadeovertime( t );
    e.alpha = a;
}

shud_counter_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    prev_z = -1;
    prev_a = -1;
    prev_d = -1;

    for ( ;; )
    {
        wait 0.1;

        if ( !isdefined( level.zc_total_z ) )
            continue;

        z = level.zc_total_z;
        a = level.zc_live_z;
        d = level.zc_total_d;

        // A dog round with no zombies left shows the dogs on their own; ALIVE only
        // while there are zombies left in the round.
        zshow = !( level.zc_dog_round && z == 0 );
        ashow = zshow && z > 0;
        dshow = level.zc_dog_round || d > 0;
        if ( zshow != self.zc_zshow || ashow != self.zc_ashow || dshow != self.zc_dshow )
        {
            self.zc_zshow = zshow;
            self.zc_ashow = ashow;
            self.zc_dshow = dshow;
            self shud_refresh( 0.25 );
        }

        if ( z != prev_z )
        {
            if ( prev_z < 0 || shud_digits( z ) != shud_digits( prev_z ) )
                self shud_place_label( shud_digits( z ), self.zc_zlab );
            prev_z = z;
            self.zc_zval setvalue( z );
            if ( z <= 5 )
                self.zc_zval.color = ( 0.92, 0.22, 0.14 );
            else
                self.zc_zval.color = ( 0.95, 0.95, 0.92 );
            if ( self.zc_enabled )
                self.zc_zval thread shud_pulse( self );
        }

        // The alive count moves constantly, so it changes quietly (no pulse).
        if ( a != prev_a )
        {
            if ( prev_a < 0 || shud_digits( a ) != shud_digits( prev_a ) )
                self.zc_alab.x = self.shud_x - shud_digits( a ) * self.shud_alive_w - 5;
            prev_a = a;
            self.zc_aval setvalue( a );
        }

        if ( d != prev_d )
        {
            if ( prev_d < 0 || shud_digits( d ) != shud_digits( prev_d ) )
                self shud_place_label( shud_digits( d ), self.zc_dlab );
            prev_d = d;
            self.zc_dval setvalue( d );
            if ( self.zc_enabled && dshow )
                self.zc_dval thread shud_pulse( self );
        }
    }
}

// A quick tick on the number when it changes.
shud_pulse( player )
{
    self notify( "shud_pulse" );
    self endon( "shud_pulse" );
    player endon( "disconnect" );

    self changefontscaleovertime( 0.05 );
    self.fontscale = 2.3;
    wait 0.05;

    if ( !isdefined( self ) )
        return;

    self changefontscaleovertime( 0.15 );
    self.fontscale = 2.0;
}

shud_text( player, align, x, y, font, scale, r, g, b )
{
    e = newclienthudelem( player );
    e.foreground = 1;
    e.hidewhendead = 0;
    e.hidewheninmenu = 1;
    e.horzalign = "user_right";
    e.vertalign = "user_top";
    e.alignx = align;
    e.aligny = "top";
    e.x = x;
    e.y = y;
    e.font = font;
    e.fontscale = scale;
    e.color = ( r, g, b );
    e.alpha = 1;
    e.sort = 7;
    return e;
}


// ============================================================================
//  RUN CLOCK / SPLITS
// ============================================================================

t6rt_init_state()
{
    level.t6rt_enabled_default = true;
    level.t6rt_current_round = 0;
    level.t6rt_round_active = false;
    level.t6rt_round_start_ms = 0;
    level.t6rt_last_completed_round = 0;
    level.t6rt_generation = 0;

    // Total run time: set once when round 1 starts and never reset, so the
    // headline figure matches what the speedrun boards rank runs on.
    level.t6rt_total_start_ms = 0;
    level.t6rt_total_generation = 0;

    // The split for the round that just ended shows under the clock, then
    // hides itself again.
    level.t6rt_split_round = 0;
    level.t6rt_split_ms = 0;
    level.t6rt_split_seconds = 6;
}

t6rt_round_monitor()
{
    level endon( "end_game" );
    level endon( "game_ended" );

    level thread t6rt_round_poll_monitor();

    wait 1;

    if ( isdefined( level.round_number ) )
        t6rt_start_round( level.round_number );

    for ( ;; )
    {
        level waittill( "end_of_round" );

        if ( level.t6rt_round_start_ms > 0 )
            t6rt_store_split( gettime() - level.t6rt_round_start_ms );

        level waittill( "start_of_round" );
        t6rt_start_round( level.round_number );
    }
}

t6rt_start_round( round )
{
    if ( !isdefined( round ) )
        round = 0;

    start_ms = gettime();
    if ( isdefined( level.round_start_time ) && level.round_start_time > 0 )
        start_ms = level.round_start_time;

    if ( level.t6rt_round_active && level.t6rt_current_round == round && level.t6rt_round_start_ms == start_ms )
        return;

    level.t6rt_current_round = round;
    level.t6rt_round_active = true;
    level.t6rt_round_start_ms = start_ms;

    level.t6rt_generation++;
    level notify( "t6rt_refresh" );
}

t6rt_store_split( elapsed_ms )
{
    if ( level.t6rt_current_round <= 0 || level.t6rt_last_completed_round == level.t6rt_current_round )
        return;

    level.t6rt_last_completed_round = level.t6rt_current_round;
    level.t6rt_round_active = false;
    level.t6rt_generation++;

    level.t6rt_split_round = level.t6rt_current_round;
    level.t6rt_split_ms = elapsed_ms;

    level notify( "t6rt_refresh" );
    level notify( "t6rt_split" );
}

t6rt_round_poll_monitor()
{
    level endon( "end_game" );
    level endon( "game_ended" );

    wait 2;

    last_round = 0;
    last_start_ms = 0;

    if ( isdefined( level.round_number ) )
        last_round = level.round_number;

    if ( isdefined( level.round_start_time ) )
        last_start_ms = level.round_start_time;

    for ( ;; )
    {
        wait 0.25;

        if ( !isdefined( level.round_number ) )
            continue;

        // The run clock starts with T6Speedrun's run (level.srStart: the first
        // player's first move after spawning, never before round 1), so the two
        // always match and a slow load-in costs nothing. A game that did not
        // start at round 1 is not timed there; the clock then runs from the
        // first round seen once someone is playing.
        start = 0;
        if ( isdefined( level.srStart ) )
            start = level.srStart;
        else if ( level.t6rt_total_start_ms <= 0 && level.round_number > 1 && t6rt_anyone_playing() )
            start = gettime();
        if ( start > 0 && start != level.t6rt_total_start_ms )
        {
            level.t6rt_total_start_ms = start;
            level.t6rt_total_generation++;
            level.t6rt_generation++;
            level notify( "t6rt_refresh" );
        }

        if ( level.t6rt_round_active && level.round_number != level.t6rt_current_round )
        {
            if ( level.t6rt_round_start_ms > 0 )
                t6rt_store_split( gettime() - level.t6rt_round_start_ms );

            last_round = level.round_number;
        }

        if ( isdefined( level.round_start_time ) && level.round_start_time > 0 && level.round_start_time != last_start_ms )
        {
            last_start_ms = level.round_start_time;
            t6rt_start_round( level.round_number );
            last_round = level.round_number;
        }
        else if ( last_round == 0 || level.round_number < last_round )
        {
            t6rt_start_round( level.round_number );
            last_round = level.round_number;
        }
    }
}

t6rt_refresh_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( self.t6rt_seen_generation != level.t6rt_generation )
            self t6rt_redraw();

        level waittill( "t6rt_refresh" );
    }
}

// The run clock counts up on the client, so it only has to be handed a new
// starting value when the run itself changes - not on every round. A running
// timer cannot be re-based, so the element is replaced.
t6rt_redraw()
{
    self.t6rt_seen_generation = level.t6rt_generation;

    if ( self.t6rt_seen_timer_generation == level.t6rt_total_generation )
        return;
    self.t6rt_seen_timer_generation = level.t6rt_total_generation;

    if ( level.t6rt_total_start_ms <= 0 )
        return;

    if ( isdefined( self.t6rt_total_time ) )
        self.t6rt_total_time destroy();
    self.t6rt_total_time = shud_text( self, "right", self.shud_x, 0, "default", 1.3, 0.95, 0.95, 0.92 );
    self.t6rt_total_time settenthstimerup( t6rt_total_elapsed_seconds() + 0.1 );
    self shud_refresh( 0 );
}

t6rt_split_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "t6rt_split" );
        self thread t6rt_split_show();
    }
}

// The round that just finished shows under the clock for a few seconds. A
// second round ending while it is up simply restarts it.
t6rt_split_show()
{
    self endon( "disconnect" );
    self notify( "t6rt_split_new" );
    self endon( "t6rt_split_new" );
    level endon( "end_game" );

    total = int( level.t6rt_split_ms / 1000 );
    if ( total < 0 )
        total = 0;
    m = int( total / 60 );
    s = total - m * 60;

    // Right to left: the time at the edge, the round number before it, then "ROUND".
    w = self.shud_small_w;
    rx = self.t6rt_split_tx - ( ( shud_digits( m ) + 2 ) * w + 3 ) - 8;
    self.t6rt_split_round.x = rx;
    self.t6rt_split_label.x = rx - shud_digits( level.t6rt_split_round ) * w - 4;

    // Under 10 seconds the "0" pad fills the tens place; otherwise the colon
    // moves up against the two-digit seconds.
    self.t6rt_split_padded = s < 10;
    if ( self.t6rt_split_padded )
    {
        self.t6rt_split_colon.x = self.t6rt_split_tx - 10;
        self.t6rt_split_mins.x = self.t6rt_split_tx - 13;
    }
    else
    {
        self.t6rt_split_colon.x = self.t6rt_split_tx - 9;
        self.t6rt_split_mins.x = self.t6rt_split_tx - 12;
    }

    self.t6rt_split_round setvalue( level.t6rt_split_round );
    self.t6rt_split_mins setvalue( m );
    self.t6rt_split_secs setvalue( s );

    self.t6rt_split_showing = true;
    self shud_refresh( 0.3 );

    wait level.t6rt_split_seconds;

    self.t6rt_split_showing = false;
    self shud_refresh( 0.6 );
}

t6rt_anyone_playing()
{
    players = get_players();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[i].sessionstate ) && players[i].sessionstate == "playing" )
            return true;
    }
    return false;
}

t6rt_total_elapsed_seconds()
{
    if ( !isdefined( level.t6rt_total_start_ms ) || level.t6rt_total_start_ms <= 0 )
        return 0;

    elapsed_ms = gettime() - level.t6rt_total_start_ms;
    if ( elapsed_ms < 0 )
        elapsed_ms = 0;

    return elapsed_ms / 1000;
}
