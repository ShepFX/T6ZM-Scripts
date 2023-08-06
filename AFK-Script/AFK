init()
{
    level thread onplayerconnect();
}

onplayerconnect()
{
    for (;;)
    {
        level waittill("connecting", player);
        player.clientid = level.clientid;
        level.clientid++;
        player thread onplayerspawned();
    }
}

onplayerspawned()
{
    level endon("game_ended");
    self endon("disconnect");
    
    old_origin = self.origin;
    old_angles = self.getPlayerAngles();
    wait 1; // change this to level.round > 20?
    
    afkc = 0;
    cooldown = 0;
    status = 1;

    for (;;)
    {
        old_origin = self.origin;
        old_angles = self.getPlayerAngles();
        wait 0.05;

        if (cooldown == 1)
        {
            wait 1800;
            cooldown = 0;
            status = 1;
        }
        else if (status == 1)
        {
            status = 0;
            self.thread print_to_all(self.name + " is ^1AFK-Ready");
        }

        if (self.adsbuttonpressed() && self.ActionSlotTwoButtonPressed())
        {
            self.ignoreme = 1; // Zombies won't find the player
            self.enableInvulnerability(); // God mode is on
            old_origin = self.origin;
            old_angles = self.getPlayerAngles();
            self.thread print_to_all(self.name + " is ^1AFK ^7for ^1max. 5 Minutes");
            afk = 0;
            wait 5;

            while (distance(old_origin, self.origin) <= 5 || old_angles != self.getPlayerAngles() && afk == 0 && afkc < 5900)
            {
                if (self.adsbuttonpressed() || self.ActionSlotFourButtonPressed() || self.attackbuttonpressed() || self.jumpbuttonpressed() || self.meleeButtonPressed() || self.throwbuttonpressed() || self.actionslotonebuttonpressed() || self.ActionSlotTwoButtonPressed() || self.ActionSlotThreeButtonPressed() || self.SprintButtonPressed() || self.ChangeSeatButtonPressed() || self.SecondaryOffhandButtonPressed() || self.FragButtonPressed() || self.UseButtonPressed())
                {
                    afk = 1;
                }
                old_angles = self.getPlayerAngles();
                afkc++;
                wait 0.05;
            }

            self.thread print_to_all(self.name + " is no longer ^1AFK^7, ^130^7 Minutes ^1cooldown");
            self.sessionstate = "playing";
            self.ignoreme = 0; // Zombies will find the player again
            self.disableInvulnerability(); // God mode is off
            afkc = 0;
            cooldown = 1;
        }
    }
}

endgame_fix()
{
    self endon("disconnect");
    level endon("end_game");
    level waittill("connected", player);

    for (;;)
    {
        wait 1;
        counter = 0;

        foreach (player in level.players)
        {
            if (player.sessionstate == "spectator" || !isAlive(player))
            {
                counter++;
            }
        }

        if (counter == level.players.size)
        {
            level notify("end_game");
        }
    }
}

print_to_all(msg)
{
    foreach (player in level.players)
    {
        player.iprintln(msg);
    }
}
