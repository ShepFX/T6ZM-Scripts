# First Room Challenge for T6 Zombies

This GSC script enables a simple first-room challenge mode for Black Ops 2 (T6) Zombies.

Players can still buy wall weapons, but doors and room-opening blockers cannot be purchased.

## Features

- Blocks standard `zombie_door` purchases.
- Blocks `zombie_debris` purchases.
- Blocks `zombie_airlock_buy` style room blockers.
- Leaves wall weapon buy triggers untouched.
- Shows players a short first-room challenge message when they spawn.
- Provides a status command for players.

## Commands

```text
.firstroom
.frc
```

Both commands show whether the challenge is active. The challenge is enabled automatically once the script is loaded.

## Installation

1. Place `FirstRoomChallenge.gsc` with your other custom T6 Zombies scripts.
2. Load the script through your GSC injector or server script configuration.
3. Call the script init from your loaded script path, adjusted to wherever you place it:

```gsc
maps\mp\FirstRoomChallenge::init();
```

If you rename the file or place it in a different script folder, update the call path to match.

## Notes

- This script does not remove physical doors or debris. It prevents players from buying them.
- It installs `level.custom_door_buy_check` to deny normal door purchases.
- It also disables known buyable blocker triggers after map init so debris and airlock-style blockers stay locked.
- Wall weapons should continue to work normally.
