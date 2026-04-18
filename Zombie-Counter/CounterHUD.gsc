// T6 ZM - Enemy Counter
// Drop into scripts/zm/ — Plutonium calls init() automatically.

#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;


// ════════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ════════════════════════════════════════════════════════════════════════════

init()
{
    level thread _zc_connect_monitor();
}


// ════════════════════════════════════════════════════════════════════════════
//  PLAYER CONNECTION
// ════════════════════════════════════════════════════════════════════════════

_zc_connect_monitor()
{
    level endon( "game_ended" );
    players = get_players();
    for ( i = 0; i < players.size; i++ )
        players[i] thread _zc_build_hud();
    for ( ;; )
    {
        level waittill( "connected", player );
        player thread _zc_build_hud();
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
//  HUD CONSTRUCTION & UPDATE LOOP
// ════════════════════════════════════════════════════════════════════════════

_zc_build_hud()
{
    self endon( "disconnect" );
    level endon( "game_ended" );
    player = self;

    bg = _zc_bar( player, 0, 8, 80, 42, 0.04, 0.04, 0.07, 0.72, 5 );
    ac = _zc_bar( player, 80, 8,  4, 42, 0.95, 0.28, 0.04, 0.90, 6 );
    _zc_bar( player, 4, 21, 72, 1, 0.95, 0.28, 0.04, 0.40, 6 );

    hdr = _zc_hud( player, 5, 10, 1.0, 0.95, 0.28, 0.04, 7 );
    hdr settext( "ENEMY TRACKER" );
    hdr.fontscale = 1.0;

    zrow = _zc_hud( player, 5, 25, 1.0, 0.58, 0.58, 0.63, 7 );
    zrow.font = "small";
    zrow settext( "ZOMBIES 0" );
    zrow.fontscale = 1.0;

    drow = _zc_hud( player, 5, 37, 1.0, 1.00, 0.78, 0.12, 7 );
    drow.font = "small";
    drow settext( "DOGS 0" );
    drow.fontscale = 1.0;
    drow.alpha = 0.0;

    srow = _zc_hud( player, 5, 37, 1.0, 0.50, 0.88, 0.50, 7 );
    srow.font = "small";
    srow settext( "SPAWNED 0" );
    srow.fontscale = 1.0;

    prev_zleft   = -1;
    prev_dleft   = -1;
    prev_spawned = -1;
    prev_dog_vis = -1;

    for ( ;; )
    {
        wait 0.1;

        is_dog_round = isdefined( level.dog_intermission ) && level.dog_intermission;

        live_z = 0;
        live_d = 0;
        enemies = get_round_enemy_array();
        if ( isdefined( enemies ) )
        {
            for ( i = 0; i < enemies.size; i++ )
            {
                if ( isdefined( enemies[i].isdog ) && enemies[i].isdog )
                    live_d++;
                else
                    live_z++;
            }
        }

        remaining = isdefined( level.zombie_total ) ? level.zombie_total : 0;
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
        if ( total_z != prev_zleft )
        {
            prev_zleft = total_z;
            zrow settext( "ZOMBIES " + total_z );
            zrow.fontscale = 1.0;
            if ( total_z <= 5 )
                zrow.color = ( 1.0, 0.25, 0.05 );
            else
                zrow.color = ( 0.58, 0.58, 0.63 );
            zrow thread _zc_pulse( player );
        }

        // Dog row fade
        dog_vis = ( is_dog_round || total_d > 0 ) ? 1 : 0;
        if ( dog_vis != prev_dog_vis )
        {
            prev_dog_vis = dog_vis;
            drow fadeovertime( 0.25 );
            drow.alpha = dog_vis;
            if ( dog_vis )
            {
                srow.y = 49;
                bg setshader( "white", 80, 55 );
                ac setshader( "white",  4, 55 );
            }
            else
            {
                srow.y = 37;
                bg setshader( "white", 80, 42 );
                ac setshader( "white",  4, 42 );
            }
        }

        // DOGS
        if ( total_d != prev_dleft )
        {
            prev_dleft = total_d;
            drow settext( "DOGS " + total_d );
            drow.fontscale = 1.0;
            drow thread _zc_pulse( player );
        }

        // SPAWNED
        if ( spawned != prev_spawned )
        {
            prev_spawned = spawned;
            srow settext( "SPAWNED " + spawned );
            srow.fontscale = 1.0;
            srow thread _zc_pulse( player );
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
