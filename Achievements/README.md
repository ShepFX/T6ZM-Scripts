# T6 MP Match Awards

End-of-match awards for Black Ops 2 multiplayer. Drop `T6Achievements.gsc` into
`scripts/mp/` on the server.

## Why the rewrite

The original waited six seconds after the match ended and drew a normal HUD
element. The post-match outcome screen only lasts seven seconds before the
final killcam starts, so the awards appeared for a second and were then
covered. This version starts one second after the match ends, draws in the
foreground with a dark strip behind the text, and keeps cycling through the
killcam and the intermission scoreboard until the map changes.

## Awards

Match-wide (one winner each): MVP, Top Gun, Longest Streak, Final Blow,
First Blood, Damage Dealer, Wingman, Punching Bag.

Personal (up to two per player, one in lobbies over six): Shotgun Monster,
One Shot One Kill, Gunslinger, Demolition Expert, Spray & Pray, Run & Gun,
Silent Assassin, Knife to a Gunfight, Long Range, Chain Reaction, Payback,
Air Superiority, Dropshot, From the Hip, Headhunter / Marksman, Unkillable /
Sniper's Eye, Glass Cannon, Swiss Cheese, The Pacifist, Bullet Sponge,
Wrong Place Wrong Time, Objective King, Denial Service, Hold the Line,
Public Enemy #1.

Each award shows a detail line with the number behind it, and the player who
earned it sees "That's you!" on their own screen.
