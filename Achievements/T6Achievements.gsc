#include maps\mp\_utility;
#include maps\mp\gametypes\_globallogic_utils;
#include maps\mp\gametypes\_hud_util;

// T6 MP - End of match awards
//
// Tracks a handful of extra stats per player during the match and, when the
// game ends, cycles a list of awards across every player's screen. The post-
// game runs in three phases - outcome screen (~7s), final killcam (~5-8s),
// intermission scoreboard (~15s) - so the banner starts one second after the
// match ends and keeps rotating through all of them. It draws in the
// foreground so the final killcam cannot cover it.

init()
{
    level.t6ach_show_seconds = 3.2;    // how long each award stays on screen
    level.t6ach_per_player_max = 2;    // personal awards per player
    level.t6ach_min_kills_ratio = 5;   // kills needed before ratio awards count

    install_achievement_hooks();
    level thread on_player_connect();
    level thread watch_game_end();
}

install_achievement_hooks()
{
    if(isdefined(level.t6ach_hooks_installed) && level.t6ach_hooks_installed)
        return;

    level.t6ach_hooks_installed = 1;

    if(isdefined(level.onplayerdamage) && level.onplayerdamage != ::on_player_damage)
        level.t6ach_original_onplayerdamage = level.onplayerdamage;

    level.onplayerdamage = ::on_player_damage;

    if(!isdefined(level.onplayerkilledextraunthreadedcbs))
        level.onplayerkilledextraunthreadedcbs = [];

    level.onplayerkilledextraunthreadedcbs[level.onplayerkilledextraunthreadedcbs.size] = ::on_player_killed;
}

on_player_connect()
{
    for(;;)
    {
        level waittill("connected", player);
        player init_player_tracking();
        player init_achievement_hud();
    }
}

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------

init_achievement_hud()
{
    if(isdefined(self.t6ach_hud_ready) && self.t6ach_hud_ready)
        return;

    self.t6ach_hud_ready = 1;

    // Dark strip behind the text so it reads over the killcam and scoreboard.
    self.t6ach_bg = newclienthudelem(self);
    self.t6ach_bg.horzalign = "center";
    self.t6ach_bg.vertalign = "top";
    self.t6ach_bg.alignx = "center";
    self.t6ach_bg.aligny = "top";
    self.t6ach_bg.x = 0;
    self.t6ach_bg.y = 18;
    self.t6ach_bg.alpha = 0;
    self.t6ach_bg.foreground = 1;
    self.t6ach_bg.hidewheninmenu = 0;
    self.t6ach_bg.archived = 0;
    self.t6ach_bg.sort = 1;
    self.t6ach_bg setshader("black", 560, 74);

    self.t6ach_title = createfontstring("big", 1.4);
    self.t6ach_title setpoint("TOP", undefined, 0, 24);
    self.t6ach_title.glowalpha = 1;
    self.t6ach_title.hidewheninmenu = 0;
    self.t6ach_title.archived = 0;
    self.t6ach_title.foreground = 1;
    self.t6ach_title.sort = 2;
    self.t6ach_title.color = (1, 0.82, 0.1);
    self.t6ach_title.alpha = 0;

    self.t6ach_text = createfontstring("big", 2.2);
    self.t6ach_text setparent(self.t6ach_title);
    self.t6ach_text setpoint("TOP", "BOTTOM", 0, 2);
    self.t6ach_text.glowalpha = 1;
    self.t6ach_text.hidewheninmenu = 0;
    self.t6ach_text.archived = 0;
    self.t6ach_text.foreground = 1;
    self.t6ach_text.sort = 2;
    self.t6ach_text.color = (1, 1, 1);
    self.t6ach_text.alpha = 0;

    self.t6ach_sub = createfontstring("default", 1.3);
    self.t6ach_sub setparent(self.t6ach_text);
    self.t6ach_sub setpoint("TOP", "BOTTOM", 0, 1);
    self.t6ach_sub.hidewheninmenu = 0;
    self.t6ach_sub.archived = 0;
    self.t6ach_sub.foreground = 1;
    self.t6ach_sub.sort = 2;
    self.t6ach_sub.color = (0.75, 0.75, 0.75);
    self.t6ach_sub.alpha = 0;
}

// ---------------------------------------------------------------------------
// Tracking
// ---------------------------------------------------------------------------

init_player_tracking()
{
    keys = [];
    keys[keys.size] = "shotgun_kills";
    keys[keys.size] = "pistol_kills";
    keys[keys.size] = "explosive_kills";
    keys[keys.size] = "lmg_kills";
    keys[keys.size] = "smg_kills";
    keys[keys.size] = "sniper_kills";
    keys[keys.size] = "suppressed_kills";
    keys[keys.size] = "knife_kills";
    keys[keys.size] = "times_damaged";
    keys[keys.size] = "spawn_deaths";
    keys[keys.size] = "damage_dealt";
    keys[keys.size] = "longshot_kills";
    keys[keys.size] = "multikills";
    keys[keys.size] = "revenge_kills";
    keys[keys.size] = "airborne_kills";
    keys[keys.size] = "prone_kills";
    keys[keys.size] = "hipfire_kills";
    keys[keys.size] = "t6ach_best_streak";

    for(i = 0; i < keys.size; i++)
    {
        if(!isdefined(self.pers[keys[i]]))
            self.pers[keys[i]] = 0;
    }

    if(!isdefined(self.t6ach_streak))
        self.t6ach_streak = 0;
}

on_player_damage(einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, psoffsettime)
{
    modifieddamage = undefined;

    if(isdefined(level.t6ach_original_onplayerdamage))
        modifieddamage = [[ level.t6ach_original_onplayerdamage ]](einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, psoffsettime);

    damage_to_count = idamage;

    if(isdefined(modifieddamage))
    {
        if(modifieddamage <= 0)
            return modifieddamage;

        damage_to_count = modifieddamage;
    }

    if(damage_to_count > 0 && isdefined(eattacker) && isplayer(eattacker) && eattacker != self && self isenemyplayer(eattacker))
    {
        self init_player_tracking();
        eattacker init_player_tracking();
        self.pers["times_damaged"]++;

        counted = damage_to_count;
        if(isdefined(self.health) && counted > self.health)
            counted = self.health;
        if(counted < 0)
            counted = 0;

        eattacker.pers["damage_dealt"] += counted;
    }

    return modifieddamage;
}

on_player_killed(einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime, deathanimduration)
{
    self init_player_tracking();
    self track_spawn_death();

    // Victim's streak ends regardless of who did it
    if(isdefined(self.t6ach_streak) && self.t6ach_streak > self.pers["t6ach_best_streak"])
        self.pers["t6ach_best_streak"] = self.t6ach_streak;
    self.t6ach_streak = 0;

    if(!isdefined(attacker) || !isplayer(attacker) || attacker == self)
        return;

    if(self isenemyplayer(attacker) == 0)
        return;

    attacker init_player_tracking();
    attacker track_weapon_kill(sweapon, smeansofdeath);
    attacker track_kill_context(self, sweapon, smeansofdeath);
    self.t6ach_last_killer = attacker;

    if(!isdefined(level.t6ach_first_blood))
        level.t6ach_first_blood = attacker.name;
}

track_spawn_death()
{
    spawn_time = undefined;

    if(isdefined(self.spawntime))
        spawn_time = self.spawntime;
    else if(isdefined(self.lastspawntime))
        spawn_time = self.lastspawntime;

    if(isdefined(spawn_time) && (gettime() - spawn_time) < 3000)
        self.pers["spawn_deaths"]++;
}

// self = attacker, victim = who died
track_kill_context(victim, weapon, meansofdeath)
{
    now = gettime();

    // streak
    self.t6ach_streak++;
    if(self.t6ach_streak > self.pers["t6ach_best_streak"])
        self.pers["t6ach_best_streak"] = self.t6ach_streak;

    // multikill: kills within 4 seconds of each other
    if(isdefined(self.t6ach_last_kill_time) && (now - self.t6ach_last_kill_time) <= 4000)
    {
        self.t6ach_chain++;
        if(self.t6ach_chain == 2)
            self.pers["multikills"]++;
    }
    else
    {
        self.t6ach_chain = 1;
    }
    self.t6ach_last_kill_time = now;

    // revenge: the victim is the last person who killed us
    if(isdefined(self.t6ach_last_killer) && self.t6ach_last_killer == victim)
    {
        self.pers["revenge_kills"]++;
        self.t6ach_last_killer = undefined;
    }

    if(is_melee_kill(weapon, meansofdeath) || is_explosive_kill(weapon, meansofdeath))
        return;

    // distance / stance / movement based, gunfire only
    if(isdefined(victim.origin) && isdefined(self.origin) && distance(self.origin, victim.origin) > 1500)
        self.pers["longshot_kills"]++;

    if(!self isonground())
        self.pers["airborne_kills"]++;

    if(self getstance() == "prone")
        self.pers["prone_kills"]++;

    if(self playerads() < 0.4)
        self.pers["hipfire_kills"]++;
}

track_weapon_kill(weapon, meansofdeath)
{
    if(!isdefined(weapon))
        weapon = "";

    if(!isdefined(meansofdeath))
        meansofdeath = "";

    if(is_melee_kill(weapon, meansofdeath))
    {
        self.pers["knife_kills"]++;
        return;
    }

    if(is_explosive_kill(weapon, meansofdeath))
    {
        self.pers["explosive_kills"]++;
        return;
    }

    weapon_class = undefined;

    if(weapon != "" && weapon != "none")
        weapon_class = getweaponclass(weapon);

    if(weapon_class == "weapon_shotgun")
        self.pers["shotgun_kills"]++;
    else if(weapon_class == "weapon_pistol")
        self.pers["pistol_kills"]++;
    else if(weapon_class == "weapon_lmg")
        self.pers["lmg_kills"]++;
    else if(weapon_class == "weapon_smg")
        self.pers["smg_kills"]++;
    else if(weapon_class == "weapon_sniper")
        self.pers["sniper_kills"]++;
    else if(issubstr(weapon, "shotgun"))
        self.pers["shotgun_kills"]++;
    else if(issubstr(weapon, "pistol"))
        self.pers["pistol_kills"]++;
    else if(issubstr(weapon, "lmg"))
        self.pers["lmg_kills"]++;
    else if(issubstr(weapon, "smg"))
        self.pers["smg_kills"]++;
    else if(issubstr(weapon, "sniper"))
        self.pers["sniper_kills"]++;

    if(is_suppressed_weapon(weapon))
        self.pers["suppressed_kills"]++;
}

is_melee_kill(weapon, meansofdeath)
{
    return meansofdeath == "MOD_MELEE" || issubstr(meansofdeath, "MOD_MELEE") || weapon == "knife_mp" || weapon == "knife_held_mp" || weapon == "knife_ballistic_mp" || weapon == "ballistic_knife_mp" || weapon == "hatchet_mp";
}

is_explosive_kill(weapon, meansofdeath)
{
    if(issubstr(meansofdeath, "MOD_GRENADE") || issubstr(meansofdeath, "MOD_EXPLOSIVE") || issubstr(meansofdeath, "MOD_PROJECTILE"))
        return 1;

    return weapon == "frag_grenade_mp" || weapon == "sticky_grenade_mp" || weapon == "claymore_mp" || weapon == "satchel_charge_mp" || weapon == "c4_mp" || weapon == "usrpg_mp" || weapon == "fhj18_mp" || weapon == "smaw_mp" || weapon == "m32_mp";
}

is_suppressed_weapon(weapon)
{
    return issubstr(weapon, "silencer") || issubstr(weapon, "suppress");
}

// ---------------------------------------------------------------------------
// End of match
// ---------------------------------------------------------------------------

watch_game_end()
{
    level waittill("game_ended", winner);

    // Let the VICTORY / DEFEAT splash land first, then start straight away -
    // the outcome screen is only ~7 seconds before the final killcam begins.
    wait 1.0;

    awards = build_award_list();
    if(awards.size == 0)
        return;

    level thread cycle_awards(awards);
}

cycle_awards(awards)
{
    // Keep going through the killcam and intermission until the map changes.
    // If we run out of awards, loop back around.
    index = 0;
    for(;;)
    {
        show_award(awards[index], index + 1, awards.size);
        wait level.t6ach_show_seconds;

        index++;
        if(index >= awards.size)
        {
            if(awards.size <= 2)
            {
                clear_award();
                return;
            }
            index = 0;
        }
    }
}

show_award(award, num, total)
{
    players = level.players;

    for(i = 0; i < players.size; i++)
    {
        player = players[i];
        if(!isdefined(player) || !isplayer(player))
            continue;

        if(!isdefined(player.t6ach_hud_ready) || !player.t6ach_hud_ready)
            player init_achievement_hud();

        mine = isdefined(award.player) && award.player == player;

        player.t6ach_title settext("^3MATCH AWARDS ^7" + num + "/" + total);
        player.t6ach_text settext(award.line);

        if(mine)
            player.t6ach_sub settext("^2That's you! ^7" + award.detail);
        else
            player.t6ach_sub settext(award.detail);

        player.t6ach_bg.alpha = 0.55;
        player.t6ach_title.alpha = 1;
        player.t6ach_text.alpha = 1;
        player.t6ach_sub.alpha = 1;

        // brief fade-in on each new award
        player.t6ach_text.alpha = 0.2;
        player.t6ach_text fadeovertime(0.3);
        player.t6ach_text.alpha = 1;
    }
}

clear_award()
{
    players = level.players;

    for(i = 0; i < players.size; i++)
    {
        player = players[i];
        if(!isdefined(player) || !isplayer(player))
            continue;

        if(isdefined(player.t6ach_bg)) player.t6ach_bg.alpha = 0;
        if(isdefined(player.t6ach_title)) player.t6ach_title.alpha = 0;
        if(isdefined(player.t6ach_text)) player.t6ach_text.alpha = 0;
        if(isdefined(player.t6ach_sub)) player.t6ach_sub.alpha = 0;
    }
}

make_award(player, title, colour, detail)
{
    a = spawnstruct();
    a.player = player;
    a.line = colour + title + " ^7- " + player.name;
    a.detail = detail;
    return a;
}

stat(player, key)
{
    if(!isdefined(player.pers[key]))
        return 0;
    return player.pers[key];
}

kills(player)
{
    if(isdefined(player.kills)) return player.kills;
    return 0;
}

deaths(player)
{
    if(isdefined(player.deaths)) return player.deaths;
    return 0;
}

// Match-wide awards first (one winner each), then up to two personal awards
// per player, best first.
build_award_list()
{
    players = [];
    all = level.players;
    for(i = 0; i < all.size; i++)
    {
        if(isdefined(all[i]) && isplayer(all[i]))
        {
            all[i] init_player_tracking();
            players[players.size] = all[i];
        }
    }

    awards = [];
    if(players.size == 0)
        return awards;

    // ---- match awards ----
    top = best_by(players, "score", 1);
    if(isdefined(top) && isdefined(top.score) && top.score > 0)
        awards[awards.size] = make_award(top, "MVP", "^3", top.score + " points, " + kills(top) + " kills");

    top = best_by(players, "kills", 1);
    if(isdefined(top) && kills(top) >= 5 && players.size > 1)
        awards[awards.size] = make_award(top, "Top Gun", "^1", kills(top) + " kills, " + deaths(top) + " deaths");

    top = best_by_pers(players, "t6ach_best_streak", 5);
    if(isdefined(top))
        awards[awards.size] = make_award(top, "Longest Streak", "^1", stat(top, "t6ach_best_streak") + " kills without dying");

    if(isdefined(level.finalkillcam_winner) && isdefined(level.finalkillcamsettings) && isdefined(level.finalkillcamsettings[level.finalkillcam_winner]) && isdefined(level.finalkillcamsettings[level.finalkillcam_winner].attacker))
    {
        fk = level.finalkillcamsettings[level.finalkillcam_winner].attacker;
        if(isdefined(fk) && isplayer(fk))
            awards[awards.size] = make_award(fk, "Final Blow", "^6", "landed the last kill of the match");
    }

    if(isdefined(level.t6ach_first_blood))
    {
        fb = find_player_by_name(players, level.t6ach_first_blood);
        if(isdefined(fb))
            awards[awards.size] = make_award(fb, "First Blood", "^1", "opened the scoring");
    }

    top = best_by_pers(players, "damage_dealt", 800);
    if(isdefined(top))
        awards[awards.size] = make_award(top, "Damage Dealer", "^1", stat(top, "damage_dealt") + " damage dealt");

    top = best_by(players, "assists", 6);
    if(isdefined(top))
        awards[awards.size] = make_award(top, "Wingman", "^2", top.assists + " assists");

    top = best_by(players, "deaths", 12);
    if(isdefined(top) && players.size > 2)
        awards[awards.size] = make_award(top, "Punching Bag", "^3", deaths(top) + " deaths, sorry");

    // ---- personal awards ----
    for(i = 0; i < players.size; i++)
    {
        personal = players[i] build_player_achievements();
        if(personal.size == 0)
            continue;

        personal = array_randomize(personal);
        limit = level.t6ach_per_player_max;
        if(players.size > 6)
            limit = 1;
        if(personal.size < limit)
            limit = personal.size;

        for(j = 0; j < limit; j++)
            awards[awards.size] = personal[j];
    }

    return awards;
}

best_by(players, field, minimum)
{
    best = undefined;
    best_val = minimum - 1;
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(!isdefined(p) || !isdefined(p.pers) )
            continue;
        val = undefined;
        if(field == "score" && isdefined(p.score)) val = p.score;
        else if(field == "kills") val = kills(p);
        else if(field == "deaths") val = deaths(p);
        else if(field == "assists" && isdefined(p.assists)) val = p.assists;
        if(!isdefined(val))
            continue;
        if(val > best_val)
        {
            best_val = val;
            best = p;
        }
    }
    return best;
}

best_by_pers(players, key, minimum)
{
    best = undefined;
    best_val = minimum - 1;
    for(i = 0; i < players.size; i++)
    {
        val = stat(players[i], key);
        if(val > best_val)
        {
            best_val = val;
            best = players[i];
        }
    }
    return best;
}

find_player_by_name(players, name)
{
    for(i = 0; i < players.size; i++)
    {
        if(isdefined(players[i]) && players[i].name == name)
            return players[i];
    }
    return undefined;
}

build_player_achievements()
{
    a = [];
    k = kills(self);
    d = deaths(self);
    hs = 0;
    if(isdefined(self.headshots)) hs = self.headshots;

    if(stat(self, "shotgun_kills") >= 8)
        a[a.size] = make_award(self, "Shotgun Monster", "^5", stat(self, "shotgun_kills") + " shotgun kills");

    if(stat(self, "sniper_kills") >= 8)
        a[a.size] = make_award(self, "One Shot, One Kill", "^5", stat(self, "sniper_kills") + " sniper kills");

    if(stat(self, "pistol_kills") >= 6)
        a[a.size] = make_award(self, "Gunslinger", "^6", stat(self, "pistol_kills") + " pistol kills");

    if(stat(self, "explosive_kills") >= 5)
        a[a.size] = make_award(self, "Demolition Expert", "^4", stat(self, "explosive_kills") + " explosive kills");

    if(stat(self, "lmg_kills") >= 15)
        a[a.size] = make_award(self, "Spray & Pray", "^3", stat(self, "lmg_kills") + " LMG kills");

    if(stat(self, "smg_kills") >= 12)
        a[a.size] = make_award(self, "Run & Gun", "^4", stat(self, "smg_kills") + " SMG kills");

    if(stat(self, "suppressed_kills") >= 5)
        a[a.size] = make_award(self, "Silent Assassin", "^5", stat(self, "suppressed_kills") + " suppressed kills");

    if(stat(self, "knife_kills") >= 4)
        a[a.size] = make_award(self, "Knife to a Gunfight", "^1", stat(self, "knife_kills") + " melee kills");

    if(stat(self, "longshot_kills") >= 5)
        a[a.size] = make_award(self, "Long Range", "^5", stat(self, "longshot_kills") + " longshots");

    if(stat(self, "multikills") >= 3)
        a[a.size] = make_award(self, "Chain Reaction", "^1", stat(self, "multikills") + " multi-kills");

    if(stat(self, "revenge_kills") >= 4)
        a[a.size] = make_award(self, "Payback", "^6", stat(self, "revenge_kills") + " revenge kills");

    if(stat(self, "airborne_kills") >= 3)
        a[a.size] = make_award(self, "Air Superiority", "^4", stat(self, "airborne_kills") + " kills while jumping");

    if(stat(self, "prone_kills") >= 5)
        a[a.size] = make_award(self, "Dropshot", "^3", stat(self, "prone_kills") + " kills from prone");

    if(stat(self, "hipfire_kills") >= 10)
        a[a.size] = make_award(self, "From the Hip", "^4", stat(self, "hipfire_kills") + " hipfire kills");

    if(hs >= 5 && k >= level.t6ach_min_kills_ratio && (hs * 100 / k) >= 30)
        a[a.size] = make_award(self, "Headhunter", "^3", hs + " headshots (" + int(hs * 100 / k) + "%)");
    else if(hs >= 5)
        a[a.size] = make_award(self, "Marksman", "^3", hs + " headshots");

    if(d == 0 && k >= 10)
        a[a.size] = make_award(self, "Unkillable", "^1", k + " kills, zero deaths");
    else if(d > 0 && k >= level.t6ach_min_kills_ratio && (k / d) >= 4.0)
        a[a.size] = make_award(self, "Sniper's Eye", "^2", k + "-" + d + " K/D");

    if(k >= 15 && d >= 15)
        a[a.size] = make_award(self, "Glass Cannon", "^1", k + " kills, " + d + " deaths");

    if(d >= 20)
        a[a.size] = make_award(self, "Swiss Cheese", "^3", d + " deaths");

    if(k <= 2 && isdefined(self.score) && self.score >= 1000)
        a[a.size] = make_award(self, "The Pacifist", "^2", self.score + " points with " + k + " kills");

    if(stat(self, "times_damaged") >= 15)
        a[a.size] = make_award(self, "Bullet Sponge", "^4", "hit " + stat(self, "times_damaged") + " times");

    if(stat(self, "spawn_deaths") >= 3)
        a[a.size] = make_award(self, "Wrong Place, Wrong Time", "^3", stat(self, "spawn_deaths") + " deaths within 3s of spawning");

    if(isdefined(self.captures) && self.captures >= 5)
        a[a.size] = make_award(self, "Objective King", "^2", self.captures + " captures");

    if(isdefined(self.returns) && self.returns >= 4)
        a[a.size] = make_award(self, "Denial Service", "^2", self.returns + " returns");

    if(isdefined(self.defends) && self.defends >= 5)
        a[a.size] = make_award(self, "Hold the Line", "^2", self.defends + " defends");

    if(a.size == 0 && k >= 25)
        a[a.size] = make_award(self, "Public Enemy #1", "^1", k + " kills");

    return a;
}

array_randomize(array)
{
    for(i = array.size - 1; i > 0; i--)
    {
        j = randomIntRange(0, i + 1);
        temp = array[i];
        array[i] = array[j];
        array[j] = temp;
    }

    return array;
}
