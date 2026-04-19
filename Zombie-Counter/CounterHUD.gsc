// T6 ZM - Enemy Counter HUD
// Drop into maps/mp/zombies/ alongside other _zm_* scripts.
// Type .counter in chat to toggle the HUD on/off (preference saved to scriptdata/).

#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;


// ════════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ════════════════════════════════════════════════════════════════════════════

init()
{
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
        players[i] thread _zc_build_hud();
    for ( ;; )
    {
        // T6 ZM uses "connected" for player join events
        level waittill( "connected", player );
        player thread _zc_build_hud();
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

    name = _zc_safe_name( player );

    file = fs_fopen( _zc_prefs_file(), "read" );
    if ( !isdefined( file ) || file == 0 )
    {
        _zc_save_pref( player, 1 );
        return 1;
    }

    len = fs_length( file );
    if ( len <= 0 )
    {
        fs_fclose( file );
        _zc_save_pref( player, 1 );
        return 1;
    }

    content = fs_read( file, len );
    fs_fclose( file );

    if ( !isdefined( content ) )
    {
        _zc_save_pref( player, 1 );
        return 1;
    }

    lines = _zc_split( content, "\n" );
    for ( i = 0; i < lines.size; i++ )
    {
        line  = _zc_trim_cr( lines[i] );
        parts = _zc_split( line, "|" );
        if ( parts.size >= 2 && parts[0] == name )
        {
            enabled = ( parts[1] != "0" );
            player.pers["zc_enabled"] = enabled;
            return enabled;
        }
    }

    // Player not in the file yet — add them with the default.
    _zc_save_pref( player, 1 );
    return 1;
}

_zc_save_pref( player, enabled )
{
    player.pers["zc_enabled"] = enabled;

    name = _zc_safe_name( player );
    val  = "1";
    if ( !enabled )
        val = "0";

    lines = [];
    found = 0;

    // Read existing entries so we can update in place.
    file = fs_fopen( _zc_prefs_file(), "read" );
    if ( isdefined( file ) && file != 0 )
    {
        len = fs_length( file );
        if ( len > 0 )
        {
            content = fs_read( file, len );
            fs_fclose( file );
            if ( isdefined( content ) )
            {
                raw = _zc_split( content, "\n" );
                for ( i = 0; i < raw.size; i++ )
                {
                    line = _zc_trim_cr( raw[i] );
                    if ( line == "" ) continue;
                    parts = _zc_split( line, "|" );
                    if ( parts.size >= 2 && parts[0] == name )
                    {
                        lines[lines.size] = name + "|" + val;
                        found = 1;
                    }
                    else
                    {
                        lines[lines.size] = line;
                    }
                }
            }
        }
        else
        {
            fs_fclose( file );
        }
    }

    if ( !found )
        lines[lines.size] = name + "|" + val;

    file = fs_fopen( _zc_prefs_file(), "write" );
    if ( !isdefined( file ) || file == 0 )
        return;
    for ( i = 0; i < lines.size; i++ )
        fs_writeline( file, lines[i] );
    fs_fclose( file );
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
//  CHAT COMMAND  —  .counter  toggles the HUD
// ════════════════════════════════════════════════════════════════════════════

_zc_chat_monitor()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "say", text, player );

        if ( !isdefined( text ) || !isdefined( player ) )
            continue;
        if ( !isdefined( player.zc_bg ) )
            continue; // HUD not built yet
        if ( _zc_sanitize( text ) != ".counter" )
            continue;

        player.zc_enabled = !player.zc_enabled;
        _zc_save_pref( player, player.zc_enabled );

        if ( player.zc_enabled )
            player _zc_set_visible( 1, 0.20 );
        else
            player _zc_set_visible( 0, 0.20 );
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
        self.zc_srow fadeovertime( t ); self.zc_srow.alpha = 1.0;
        if ( isdefined( self.zc_dog_vis ) && self.zc_dog_vis )
        {
            self.zc_drow fadeovertime( t );
            self.zc_drow.alpha = 1.0;
        }
        // Force a full redraw on the next update tick
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
        self.zc_drow fadeovertime( t ); self.zc_drow.alpha = 0;
        self.zc_srow fadeovertime( t ); self.zc_srow.alpha = 0;
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

    player.zc_zrow = _zc_hud( player, px + 5, py + 17, 1.0, 0.58, 0.58, 0.63, 7 );
    player.zc_zrow.font = "small";
    player.zc_zrow settext( "ZOMBIES 0" );
    player.zc_zrow.fontscale = 1.0;

    player.zc_drow = _zc_hud( player, px + 5, py + 29, 1.0, 1.00, 0.78, 0.12, 7 );
    player.zc_drow.font = "small";
    player.zc_drow settext( "DOGS 0" );
    player.zc_drow.fontscale = 1.0;
    player.zc_drow.alpha = 0.0;

    player.zc_srow = _zc_hud( player, px + 5, py + 29, 1.0, 0.50, 0.88, 0.50, 7 );
    player.zc_srow.font = "small";
    player.zc_srow settext( "SPAWNED 0" );
    player.zc_srow.fontscale = 1.0;

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
            player.zc_zrow settext( "ZOMBIES " + total_z );
            player.zc_zrow.fontscale = 1.0;
            if ( total_z <= 5 )
                player.zc_zrow.color = ( 1.0, 0.25, 0.05 );
            else
                player.zc_zrow.color = ( 0.58, 0.58, 0.63 );
            player.zc_zrow thread _zc_pulse( player );
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
            if ( dog_vis )
            {
                player.zc_srow.y = py + 41;
                player.zc_bg setshader( "white", 80, 55 );
                player.zc_ac setshader( "white",  4, 55 );
            }
            else
            {
                player.zc_srow.y = py + 29;
                player.zc_bg setshader( "white", 80, 42 );
                player.zc_ac setshader( "white",  4, 42 );
            }
        }

        // DOGS
        if ( total_d != player.zc_prev_dleft )
        {
            player.zc_prev_dleft = total_d;
            player.zc_drow settext( "DOGS " + total_d );
            player.zc_drow.fontscale = 1.0;
            player.zc_drow thread _zc_pulse( player );
        }

        // SPAWNED
        if ( spawned != player.zc_prev_spawned )
        {
            player.zc_prev_spawned = spawned;
            player.zc_srow settext( "SPAWNED " + spawned );
            player.zc_srow.fontscale = 1.0;
            player.zc_srow thread _zc_pulse( player );
        }
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
