// T6 ZM - Enemy Counter + Round Timer HUD
// Drop into maps/mp/zombies/ alongside other _zm_* scripts.
// Commands: .counter toggles enemy counter, .timer toggles round timer, .hud toggles both.

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
    level.zc_pref_names = [];
    level.zc_pref_values = [];
    level.zc_prefs_loaded = false;
    level.zc_prefs_dirty = false;

    t6rt_init_state();
    level thread t6rt_round_monitor();
    level thread _zc_pref_flush_loop();
    level thread _zc_pref_end_flush();
    level thread _zc_pref_game_ended_flush();
    level thread _zc_connect_monitor();
    level thread _zc_chat_monitor();
}


// ════════════════════════════════════════════════════════════════════════════
//  PLAYER CONNECTION
// ════════════════════════════════════════════════════════════════════════════

_zc_connect_monitor()
{
    level endon( "end_game" );
    players = get_players();
    for ( i = 0; i < players.size; i++ )
    {
        players[i] thread _zc_build_hud();
        players[i] thread t6rt_build_hud();
    }
    for ( ;; )
    {
        // T6 ZM uses "connected" for player join events
        level waittill( "connected", player );
        player thread _zc_build_hud();
        player thread t6rt_build_hud();
    }
}


// ════════════════════════════════════════════════════════════════════════════
//  PER-PLAYER PREFERENCE  (single file, one line per player: "name|enabled")
// ════════════════════════════════════════════════════════════════════════════

_zc_prefs_file()
{
    return "scriptdata/zc_prefs.txt";
}

// Strip color codes (^n) and problematic chars so the name is a clean key.
_zc_safe_name( player )
{
    raw = player.playername;
    if ( !isdefined( raw ) || raw == "" )
        raw = player.name;
    if ( !isdefined( raw ) || raw == "" )
        return "p" + player getEntityNumber();

    result = "";
    skip   = 0;
    for ( i = 0; i < raw.size; i++ )
    {
        if ( skip > 0 ) { skip--; continue; }
        c = raw[i];
        if ( c == "^" ) { skip = 1; continue; }
        if ( c == " " || c == "/" || c == "\\" || c == ":" || c == "|" )
            result += "_";
        else
            result += c;
    }
    if ( result == "" )
        return "p" + player getEntityNumber();
    return result;
}

_zc_load_pref( player )
{
    if ( isdefined( player.pers["zc_enabled"] ) )
        return player.pers["zc_enabled"];

    _zc_load_all_prefs();

    name = _zc_safe_name( player );
    idx = _zc_pref_cache_index( name );
    if ( idx >= 0 )
    {
        player.pers["zc_enabled"] = level.zc_pref_values[idx];
        return level.zc_pref_values[idx];
    }

    _zc_pref_cache_set( name, 1 );
    player.pers["zc_enabled"] = 1;
    level.zc_prefs_dirty = true;
    return 1;
}

_zc_save_pref( player, enabled )
{
    player.pers["zc_enabled"] = enabled;
    _zc_load_all_prefs();
    _zc_pref_cache_set( _zc_safe_name( player ), enabled );
    level.zc_prefs_dirty = true;
}

_zc_load_all_prefs()
{
    if ( isdefined( level.zc_prefs_loaded ) && level.zc_prefs_loaded )
        return;

    level.zc_prefs_loaded = true;
    level.zc_pref_names = [];
    level.zc_pref_values = [];

    file = fs_fopen( _zc_prefs_file(), "read" );
    if ( !isdefined( file ) || file == 0 )
        return;

    len = fs_length( file );
    if ( len <= 0 )
    {
        fs_fclose( file );
        return;
    }

    content = fs_read( file, len );
    fs_fclose( file );

    if ( !isdefined( content ) )
        return;

    lines = _zc_split( content, "\n" );
    for ( i = 0; i < lines.size; i++ )
    {
        line  = _zc_trim_cr( lines[i] );
        parts = _zc_split( line, "|" );
        if ( parts.size >= 2 && parts[0] != "" )
            _zc_pref_cache_set( parts[0], ( parts[1] != "0" ) );
    }
}

_zc_pref_cache_index( name )
{
    for ( i = 0; i < level.zc_pref_names.size; i++ )
    {
        if ( level.zc_pref_names[i] == name )
            return i;
    }
    return -1;
}

_zc_pref_cache_set( name, enabled )
{
    idx = _zc_pref_cache_index( name );
    if ( idx < 0 )
    {
        idx = level.zc_pref_names.size;
        level.zc_pref_names[idx] = name;
    }
    level.zc_pref_values[idx] = enabled;
}

_zc_pref_flush_loop()
{
    level endon( "end_game" );
    level endon( "game_ended" );

    for ( ;; )
    {
        wait 5;
        _zc_flush_prefs();
    }
}

_zc_pref_end_flush()
{
    level waittill( "end_game" );
    _zc_flush_prefs();
}

_zc_pref_game_ended_flush()
{
    level waittill( "game_ended" );
    _zc_flush_prefs();
}

_zc_flush_prefs()
{
    if ( !isdefined( level.zc_prefs_dirty ) || !level.zc_prefs_dirty )
        return;

    file = fs_fopen( _zc_prefs_file(), "write" );
    if ( !isdefined( file ) || file == 0 )
        return;

    for ( i = 0; i < level.zc_pref_names.size; i++ )
    {
        val = "1";
        if ( !level.zc_pref_values[i] )
            val = "0";
        fs_writeline( file, level.zc_pref_names[i] + "|" + val );
    }

    fs_fclose( file );
    level.zc_prefs_dirty = false;
}

_zc_split( str, delim )
{
    parts   = [];
    current = "";
    for ( i = 0; i < str.size; i++ )
    {
        if ( str[i] == delim )
        {
            parts[parts.size] = current;
            current = "";
        }
        else
            current += str[i];
    }
    if ( current != "" )
        parts[parts.size] = current;
    return parts;
}

_zc_trim_cr( s )
{
    if ( s.size > 0 && getSubStr( s, s.size - 1, s.size ) == "\r" )
        return getSubStr( s, 0, s.size - 1 );
    return s;
}


// ════════════════════════════════════════════════════════════════════════════
//  CHAT COMMANDS
// ════════════════════════════════════════════════════════════════════════════

_zc_chat_monitor()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "say", text, player );

        if ( !isdefined( text ) || !isdefined( player ) )
            continue;

        command = _zc_sanitize( text );

        if ( command == ".counter" )
        {
            if ( !isdefined( player.zc_bg ) )
                continue; // Counter HUD not built yet

            player.zc_enabled = !player.zc_enabled;
            _zc_save_pref( player, player.zc_enabled );
            player _zc_set_visible( player.zc_enabled, 0.20 );
        }
        else if ( command == ".timer" )
        {
            if ( !isdefined( player.t6rt_ready ) || !player.t6rt_ready )
                continue; // Timer HUD not built yet

            player.t6rt_enabled = !player.t6rt_enabled;
            player t6rt_set_visible( player.t6rt_enabled, 0.20 );
        }
        else if ( command == ".hud" )
        {
            hud_enabled = 1;
            if ( ( isdefined( player.zc_enabled ) && player.zc_enabled ) || ( isdefined( player.t6rt_enabled ) && player.t6rt_enabled ) )
                hud_enabled = 0;

            if ( isdefined( player.zc_bg ) )
            {
                player.zc_enabled = hud_enabled;
                _zc_save_pref( player, player.zc_enabled );
                player _zc_set_visible( player.zc_enabled, 0.20 );
            }

            if ( isdefined( player.t6rt_ready ) && player.t6rt_ready )
            {
                player.t6rt_enabled = hud_enabled;
                player t6rt_set_visible( player.t6rt_enabled, 0.20 );
            }
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
        if ( first == " " || first == "§" || first == "\t" )
        {
            text = getSubStr( text, 1, 1024 );
            continue;
        }
        break;
    }
    return text;
}


// ════════════════════════════════════════════════════════════════════════════
//  HUD VISIBILITY TOGGLE
// ════════════════════════════════════════════════════════════════════════════

// show = 1 to reveal, 0 to hide.  t = fade duration in seconds (0 = instant).
_zc_set_visible( show, t )
{
    if ( !isdefined( self.zc_bg ) )
        return;

    if ( show )
    {
        self.zc_bg   fadeovertime( t ); self.zc_bg.alpha   = 0.72;
        self.zc_ac   fadeovertime( t ); self.zc_ac.alpha   = 0.90;
        self.zc_sep  fadeovertime( t ); self.zc_sep.alpha  = 0.40;
        self.zc_hdr  fadeovertime( t ); self.zc_hdr.alpha  = 1.0;
        self.zc_zrow fadeovertime( t ); self.zc_zrow.alpha = 1.0;
        self.zc_zval fadeovertime( t ); self.zc_zval.alpha = 1.0;
        self.zc_srow fadeovertime( t ); self.zc_srow.alpha = 1.0;
        self.zc_sval fadeovertime( t ); self.zc_sval.alpha = 1.0;
        if ( isdefined( self.zc_dog_vis ) && self.zc_dog_vis )
        {
            self.zc_drow fadeovertime( t ); self.zc_drow.alpha = 1.0;
            self.zc_dval fadeovertime( t ); self.zc_dval.alpha = 1.0;
        }
        // Force values to refresh without playing every pulse animation at once.
        self.zc_suppress_pulse = true;
        self.zc_prev_zleft   = -1;
        self.zc_prev_dleft   = -1;
        self.zc_prev_spawned = -1;
        self.zc_prev_dog_vis = -1;
    }
    else
    {
        self.zc_bg   fadeovertime( t ); self.zc_bg.alpha   = 0;
        self.zc_ac   fadeovertime( t ); self.zc_ac.alpha   = 0;
        self.zc_sep  fadeovertime( t ); self.zc_sep.alpha  = 0;
        self.zc_hdr  fadeovertime( t ); self.zc_hdr.alpha  = 0;
        self.zc_zrow fadeovertime( t ); self.zc_zrow.alpha = 0;
        self.zc_zval fadeovertime( t ); self.zc_zval.alpha = 0;
        self.zc_drow fadeovertime( t ); self.zc_drow.alpha = 0;
        self.zc_dval fadeovertime( t ); self.zc_dval.alpha = 0;
        self.zc_srow fadeovertime( t ); self.zc_srow.alpha = 0;
        self.zc_sval fadeovertime( t ); self.zc_sval.alpha = 0;
    }
}


// ════════════════════════════════════════════════════════════════════════════
//  HUD HELPERS
// ════════════════════════════════════════════════════════════════════════════

_zc_hud( player, x, y, scale, r, g, b, srt )
{
    e = newclienthudelem( player );
    e.foreground     = 1;
    e.hidewhendead   = 0;
    e.hidewheninmenu = 0;
    e.horzalign  = "left";
    e.vertalign  = "top";
    e.alignx     = "left";
    e.aligny     = "top";
    e.x          = x;
    e.y          = y;
    e.fontscale  = scale;
    e.font       = "default";
    e.color      = ( r, g, b );
    e.alpha      = 1.0;
    e.sort       = srt;
    return e;
}

_zc_bar( player, x, y, w, h, r, g, b, a, srt )
{
    e = newclienthudelem( player );
    e.foreground     = 1;
    e.hidewhendead   = 0;
    e.hidewheninmenu = 0;
    e.horzalign  = "left";
    e.vertalign  = "top";
    e.alignx     = "left";
    e.aligny     = "top";
    e.x     = x;
    e.y     = y;
    e.sort  = srt;
    e setshader( "white", w, h );
    e.color = ( r, g, b );
    e.alpha = a;
    return e;
}


// ════════════════════════════════════════════════════════════════════════════
//  ENEMY ENUMERATION (T6)
// ════════════════════════════════════════════════════════════════════════════

// T6 exposes get_round_enemy_array() directly.
// Dogs share the same array and carry .is_dog, so one pass separates them.
_zc_get_enemies()
{
    return get_round_enemy_array();
}


// ════════════════════════════════════════════════════════════════════════════
//  HUD CONSTRUCTION & UPDATE LOOP
// ════════════════════════════════════════════════════════════════════════════

_zc_build_hud()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    player = self;

    // Wait for full spawn before creating client hud elems.
    self waittill( "spawned_player" );

    // Padding offsets — bump to shift whole HUD.
    px = 20;
    py = 24;

    // Accent colour (orange).
    ar = 1.00;
    ag = 0.55;
    ab = 0.05;

    // Store all elements on the player entity so _zc_set_visible can reach them.
    player.zc_bg  = _zc_bar( player, px + 0,  py + 0,  80, 42, 0.04, 0.04, 0.07, 0.72, 5 );
    player.zc_ac  = _zc_bar( player, px + 80, py + 0,   4, 42, ar, ag, ab, 0.90, 6 );
    player.zc_sep = _zc_bar( player, px + 4,  py + 13, 72,  1, ar, ag, ab, 0.40, 6 );

    player.zc_hdr = _zc_hud( player, px + 5, py + 2,  1.0, ar, ag, ab, 7 );
    player.zc_hdr settext( "ENEMY TRACKER" );
    player.zc_hdr.fontscale = 1.0;

    // Static labels — settext() called once, no repeated configstring allocation.
    // Numeric values use setvalue() which renders integers natively (no configstrings).
    player.zc_zrow = _zc_hud( player, px + 5,  py + 17, 1.0, 0.58, 0.58, 0.63, 7 );
    player.zc_zrow.font = "small";
    player.zc_zrow settext( "ZOMBIES" );
    player.zc_zrow.fontscale = 1.0;

    player.zc_zval = _zc_hud( player, px + 50, py + 17, 1.0, 0.58, 0.58, 0.63, 7 );
    player.zc_zval.font = "small";
    player.zc_zval setvalue( 0 );
    player.zc_zval.fontscale = 1.0;

    player.zc_drow = _zc_hud( player, px + 5,  py + 29, 1.0, 1.00, 0.78, 0.12, 7 );
    player.zc_drow.font = "small";
    player.zc_drow settext( "DOGS" );
    player.zc_drow.fontscale = 1.0;
    player.zc_drow.alpha = 0.0;

    player.zc_dval = _zc_hud( player, px + 50, py + 29, 1.0, 1.00, 0.78, 0.12, 7 );
    player.zc_dval.font = "small";
    player.zc_dval setvalue( 0 );
    player.zc_dval.fontscale = 1.0;
    player.zc_dval.alpha = 0.0;

    player.zc_srow = _zc_hud( player, px + 5,  py + 29, 1.0, 0.50, 0.88, 0.50, 7 );
    player.zc_srow.font = "small";
    player.zc_srow settext( "SPAWNED" );
    player.zc_srow.fontscale = 1.0;

    player.zc_sval = _zc_hud( player, px + 50, py + 29, 1.0, 0.50, 0.88, 0.50, 7 );
    player.zc_sval.font = "small";
    player.zc_sval setvalue( 0 );
    player.zc_sval.fontscale = 1.0;

    player.zc_dog_vis = 0;

    // Prev-value trackers kept on player so _zc_set_visible can reset them.
    player.zc_prev_zleft   = -1;
    player.zc_prev_dleft   = -1;
    player.zc_prev_spawned = -1;
    player.zc_prev_dog_vis = -1;

    // Load saved preference; hide instantly if the player had it off.
    player.zc_enabled = _zc_load_pref( player );
    if ( !player.zc_enabled )
        player _zc_set_visible( 0, 0 );

    for ( ;; )
    {
        wait 0.1;

        if ( !player.zc_enabled )
            continue;

        // T6: dog_round flag covers the whole round.
        is_dog_round = level flag_exists( "dog_round" ) && flag( "dog_round" );

        live_z = 0;
        live_d = 0;
        enemies = _zc_get_enemies();
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

        if ( isdefined( level.zombie_total ) )
            remaining = level.zombie_total;
        else
            remaining = 0;
        if ( remaining < 0 )
            remaining = 0;

        if ( is_dog_round )
        {
            total_z = live_z;
            total_d = live_d + remaining;
        }
        else
        {
            total_z = live_z + remaining;
            total_d = live_d;
        }

        // SPAWNED = currently alive on the map right now
        spawned = live_z;

        // ZOMBIES
        if ( total_z != player.zc_prev_zleft )
        {
            player.zc_prev_zleft = total_z;
            player.zc_zval setvalue( total_z );
            if ( total_z <= 5 )
            {
                player.zc_zrow.color = ( 1.0, 0.25, 0.05 );
                player.zc_zval.color = ( 1.0, 0.25, 0.05 );
            }
            else
            {
                player.zc_zrow.color = ( 0.58, 0.58, 0.63 );
                player.zc_zval.color = ( 0.58, 0.58, 0.63 );
            }
            if ( !isdefined( player.zc_suppress_pulse ) || !player.zc_suppress_pulse )
                player.zc_zval thread _zc_pulse( player );
        }

        // Dog row fade
        if ( is_dog_round || total_d > 0 )
            dog_vis = 1;
        else
            dog_vis = 0;

        player.zc_dog_vis = dog_vis;

        if ( dog_vis != player.zc_prev_dog_vis )
        {
            player.zc_prev_dog_vis = dog_vis;
            player.zc_drow fadeovertime( 0.25 );
            player.zc_drow.alpha = dog_vis;
            player.zc_dval fadeovertime( 0.25 );
            player.zc_dval.alpha = dog_vis;
            if ( dog_vis )
            {
                player.zc_srow.y = py + 41;
                player.zc_sval.y = py + 41;
                player.zc_bg setshader( "white", 80, 55 );
                player.zc_ac setshader( "white",  4, 55 );
                if ( isdefined( player.t6rt_ready ) && player.t6rt_ready )
                    player t6rt_move( 83 );
            }
            else
            {
                player.zc_srow.y = py + 29;
                player.zc_sval.y = py + 29;
                player.zc_bg setshader( "white", 80, 42 );
                player.zc_ac setshader( "white",  4, 42 );
                if ( isdefined( player.t6rt_ready ) && player.t6rt_ready )
                    player t6rt_move( 69 );
            }
        }

        // DOGS
        if ( total_d != player.zc_prev_dleft )
        {
            player.zc_prev_dleft = total_d;
            player.zc_dval setvalue( total_d );
            if ( !isdefined( player.zc_suppress_pulse ) || !player.zc_suppress_pulse )
                player.zc_dval thread _zc_pulse( player );
        }

        // SPAWNED
        if ( spawned != player.zc_prev_spawned )
        {
            player.zc_prev_spawned = spawned;
            player.zc_sval setvalue( spawned );
            if ( !isdefined( player.zc_suppress_pulse ) || !player.zc_suppress_pulse )
                player.zc_sval thread _zc_pulse( player );
        }

        player.zc_suppress_pulse = false;
    }
}


// ════════════════════════════════════════════════════════════════════════════
//  PULSE ANIMATION
// ════════════════════════════════════════════════════════════════════════════

_zc_pulse( player )
{
    self notify( "zc_pulse" );
    self endon(  "zc_pulse" );
    player endon( "disconnect" );

    base = self.fontscale;
    self changefontscaleovertime( 0.05 );
    self.fontscale = base * 1.5;
    wait 0.05;

    if ( !isdefined( self ) )
        return;

    self changefontscaleovertime( 0.14 );
    self.fontscale = base;
}


// ============================================================================
//  ROUND TIMER / SPLITTER
// ============================================================================

t6rt_init_state()
{
    level.t6rt_enabled_default = true;
    level.t6rt_current_round = 0;
    level.t6rt_current_time = "";
    level.t6rt_round_active = false;
    level.t6rt_round_start_ms = 0;
    level.t6rt_last_completed_round = 0;
    level.t6rt_prev_round_1 = 0;
    level.t6rt_prev_round_2 = 0;
    level.t6rt_prev_time_1 = "";
    level.t6rt_prev_time_2 = "";
    level.t6rt_generation = 0;
    level.t6rt_timer_generation = 0;
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
    level.t6rt_current_time = "";
    level.t6rt_round_active = true;
    level.t6rt_round_start_ms = start_ms;

    level.t6rt_generation++;
    level.t6rt_timer_generation++;
    level notify( "t6rt_refresh" );
}

t6rt_store_split( elapsed_ms )
{
    if ( level.t6rt_current_round <= 0 || level.t6rt_last_completed_round == level.t6rt_current_round )
        return;

    level.t6rt_last_completed_round = level.t6rt_current_round;
    level.t6rt_current_time = t6rt_format_time( elapsed_ms );
    level.t6rt_round_active = false;
    level.t6rt_generation++;
    level.t6rt_timer_generation++;

    level.t6rt_prev_round_2 = level.t6rt_prev_round_1;
    level.t6rt_prev_time_2 = level.t6rt_prev_time_1;

    level.t6rt_prev_round_1 = level.t6rt_current_round;
    level.t6rt_prev_time_1 = t6rt_format_time( elapsed_ms );

    level notify( "t6rt_refresh" );
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
        wait 1;

        if ( !isdefined( level.round_number ) )
            continue;

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

t6rt_build_hud()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    level endon( "game_ended" );

    player = self;
    player waittill( "spawned_player" );

    if ( isdefined( player.t6rt_ready ) && player.t6rt_ready )
        return;

    player.t6rt_ready = true;
    player.t6rt_enabled = level.t6rt_enabled_default;
    player.t6rt_seen_generation = -1;
    player.t6rt_seen_timer_generation = -1;

    // Same visual language and width as the counter, stacked below it.
    px = 20;
    py = 69;
    if ( level flag_exists( "dog_round" ) && flag( "dog_round" ) )
        py = 83;
    w = 80;
    h = 54;

    ar = 1.00;
    ag = 0.55;
    ab = 0.05;

    player.t6rt_time_x = px + 75;
    player.t6rt_time_y = py + 17;

    player.t6rt_bg = t6rt_bar( player, px + 0, py + 0, w, h, 0.04, 0.04, 0.07, 0.72, 5 );
    player.t6rt_accent = t6rt_bar( player, px + w, py + 0, 4, h, ar, ag, ab, 0.90, 6 );
    player.t6rt_sep = t6rt_bar( player, px + 4, py + 13, w - 8, 1, ar, ag, ab, 0.40, 6 );

    player.t6rt_title = t6rt_text_left( player, px + 5, py + 2, "default", 1.0, ar, ag, ab, 7 );
    player.t6rt_title settext( "SPLITS" );

    player.t6rt_cur_label = t6rt_text_left( player, px + 5, py + 17, "small", 1.0, 0.58, 0.58, 0.63, 7 );
    player.t6rt_cur_label settext( "R0" );

    player.t6rt_cur_time = t6rt_text_right( player, player.t6rt_time_x, player.t6rt_time_y, "small", 1.0, 1.00, 1.00, 1.00, 7 );
    player.t6rt_cur_time settext( "--:--" );

    player.t6rt_prev1_label = t6rt_text_left( player, px + 5, py + 30, "small", 1.0, 0.58, 0.58, 0.63, 7 );
    player.t6rt_prev1_label settext( "LAST" );

    player.t6rt_prev1_time = t6rt_text_right( player, player.t6rt_time_x, py + 30, "small", 1.0, 0.72, 0.78, 0.86, 7 );
    player.t6rt_prev1_time settext( "--:--" );

    player.t6rt_prev2_label = t6rt_text_left( player, px + 5, py + 42, "small", 1.0, 0.45, 0.48, 0.55, 7 );
    player.t6rt_prev2_label settext( "PREV" );

    player.t6rt_prev2_time = t6rt_text_right( player, player.t6rt_time_x, py + 42, "small", 1.0, 0.55, 0.60, 0.68, 7 );
    player.t6rt_prev2_time settext( "--:--" );

    if ( !player.t6rt_enabled )
        player t6rt_set_visible( 0, 0 );

    player thread t6rt_refresh_loop();
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

t6rt_redraw()
{
    self.t6rt_seen_generation = level.t6rt_generation;

    if ( isdefined( self.t6rt_cur_label ) )
        self.t6rt_cur_label settext( "R" + level.t6rt_current_round );

    if ( isdefined( self.t6rt_cur_time ) && self.t6rt_seen_timer_generation != level.t6rt_timer_generation )
    {
        self.t6rt_seen_timer_generation = level.t6rt_timer_generation;
        self.t6rt_cur_time destroy();
        self.t6rt_cur_time = t6rt_text_right( self, self.t6rt_time_x, self.t6rt_time_y, "small", 1.0, 1.00, 1.00, 1.00, 7 );

        if ( isdefined( level.t6rt_round_active ) && level.t6rt_round_active )
            self.t6rt_cur_time settenthstimerup( t6rt_elapsed_seconds() + 0.1 );
        else if ( isdefined( level.t6rt_current_time ) && level.t6rt_current_time != "" )
            self.t6rt_cur_time settext( level.t6rt_current_time );
        else
            self.t6rt_cur_time settext( "--:--" );

        if ( isdefined( self.t6rt_enabled ) && !self.t6rt_enabled )
            self.t6rt_cur_time.alpha = 0;
    }

    if ( isdefined( self.t6rt_prev1_label ) )
    {
        if ( level.t6rt_prev_round_1 > 0 )
            self.t6rt_prev1_label settext( "R" + level.t6rt_prev_round_1 );
        else
            self.t6rt_prev1_label settext( "LAST" );
    }

    if ( isdefined( self.t6rt_prev1_time ) )
    {
        if ( level.t6rt_prev_time_1 != "" )
            self.t6rt_prev1_time settext( level.t6rt_prev_time_1 );
        else
            self.t6rt_prev1_time settext( "--:--" );
    }

    if ( isdefined( self.t6rt_prev2_label ) )
    {
        if ( level.t6rt_prev_round_2 > 0 )
            self.t6rt_prev2_label settext( "R" + level.t6rt_prev_round_2 );
        else
            self.t6rt_prev2_label settext( "PREV" );
    }

    if ( isdefined( self.t6rt_prev2_time ) )
    {
        if ( level.t6rt_prev_time_2 != "" )
            self.t6rt_prev2_time settext( level.t6rt_prev_time_2 );
        else
            self.t6rt_prev2_time settext( "--:--" );
    }
}

t6rt_set_visible( visible, fade_time )
{
    alpha = 0;
    if ( visible )
        alpha = 1;

    bg_alpha = 0;
    accent_alpha = 0;
    sep_alpha = 0;

    if ( visible )
    {
        bg_alpha = 0.72;
        accent_alpha = 0.90;
        sep_alpha = 0.40;
    }

    self.t6rt_bg fadeovertime( fade_time );
    self.t6rt_bg.alpha = bg_alpha;
    self.t6rt_accent fadeovertime( fade_time );
    self.t6rt_accent.alpha = accent_alpha;
    self.t6rt_sep fadeovertime( fade_time );
    self.t6rt_sep.alpha = sep_alpha;

    elems = [];
    elems[0] = self.t6rt_title;
    elems[1] = self.t6rt_cur_label;
    elems[2] = self.t6rt_cur_time;
    elems[3] = self.t6rt_prev1_label;
    elems[4] = self.t6rt_prev1_time;
    elems[5] = self.t6rt_prev2_label;
    elems[6] = self.t6rt_prev2_time;

    for ( i = 0; i < elems.size; i++ )
    {
        if ( !isdefined( elems[i] ) )
            continue;

        elems[i] fadeovertime( fade_time );
        elems[i].alpha = alpha;
    }
}

t6rt_move( py )
{
    if ( !isdefined( self.t6rt_bg ) )
        return;

    self.t6rt_bg.y = py;
    self.t6rt_accent.y = py;
    self.t6rt_sep.y = py + 13;
    self.t6rt_title.y = py + 2;
    self.t6rt_cur_label.y = py + 17;
    self.t6rt_time_y = py + 17;
    if ( isdefined( self.t6rt_cur_time ) )
        self.t6rt_cur_time.y = self.t6rt_time_y;
    self.t6rt_prev1_label.y = py + 30;
    self.t6rt_prev1_time.y = py + 30;
    self.t6rt_prev2_label.y = py + 42;
    self.t6rt_prev2_time.y = py + 42;
}

t6rt_text_left( player, x, y, font, scale, r, g, b, sort )
{
    elem = newclienthudelem( player );
    elem.foreground = 1;
    elem.hidewhendead = 0;
    elem.hidewheninmenu = 0;
    elem.horzalign = "left";
    elem.vertalign = "top";
    elem.alignx = "left";
    elem.aligny = "top";
    elem.x = x;
    elem.y = y;
    elem.font = font;
    elem.fontscale = scale;
    elem.color = ( r, g, b );
    elem.alpha = 1;
    elem.sort = sort;
    return elem;
}

t6rt_text_right( player, x, y, font, scale, r, g, b, sort )
{
    elem = newclienthudelem( player );
    elem.foreground = 1;
    elem.hidewhendead = 0;
    elem.hidewheninmenu = 0;
    elem.horzalign = "left";
    elem.vertalign = "top";
    elem.alignx = "right";
    elem.aligny = "top";
    elem.x = x;
    elem.y = y;
    elem.font = font;
    elem.fontscale = scale;
    elem.color = ( r, g, b );
    elem.alpha = 1;
    elem.sort = sort;
    return elem;
}

t6rt_bar( player, x, y, w, h, r, g, b, a, sort )
{
    elem = newclienthudelem( player );
    elem.foreground = 1;
    elem.hidewhendead = 0;
    elem.hidewheninmenu = 0;
    elem.horzalign = "left";
    elem.vertalign = "top";
    elem.alignx = "left";
    elem.aligny = "top";
    elem.x = x;
    elem.y = y;
    elem.sort = sort;
    elem setshader( "white", w, h );
    elem.color = ( r, g, b );
    elem.alpha = a;
    return elem;
}

t6rt_format_time( elapsed_ms )
{
    if ( elapsed_ms < 0 )
        elapsed_ms = 0;

    total_seconds = int( elapsed_ms / 1000 );
    minutes = int( total_seconds / 60 );
    seconds = total_seconds - ( minutes * 60 );

    second_text = "" + seconds;
    if ( seconds < 10 )
        second_text = "0" + seconds;

    return minutes + ":" + second_text;
}

t6rt_elapsed_seconds()
{
    if ( !isdefined( level.t6rt_round_start_ms ) || level.t6rt_round_start_ms <= 0 )
        return 0;

    elapsed_ms = gettime() - level.t6rt_round_start_ms;
    if ( elapsed_ms < 0 )
        elapsed_ms = 0;

    return elapsed_ms / 1000;
}
