# AFK System for T6 Zombies (Plutonium)

A robust GSC script for Black Ops II (T6) Zombies that allows players to safely step away from the game without ending the match or dying. Designed specifically for high-round attempts and long-duration sessions on Plutonium servers.

## 🚀 Features

* **Secure Teleportation:** Teleports AFK players to a verified spawn point to prevent "glitching" or staying in power-up/training spots.
* **Anti-Panic Delay:** A 60-second activation countdown prevents players from using the command to escape immediate death.
* **Damage Cancellation:** If a player takes damage during the activation countdown, the AFK request is cancelled.
* **Round Freeze:** If **all** active players are AFK, the zombie spawning pauses and the round is "frozen" to prevent the game from progressing or ending.
* **Visual Feedback:** Uses the "Zombie Blood" screen effect and a custom HUD timer for the AFK player.
* **Score Protection:** Locks the player's score while AFK to prevent points drift or exploits.
* **Resume Grace Period:** Provides 30 seconds of invulnerability upon returning to allow players to get their bearings.

## 🛠 Usage

1.  **To Activate:** Type `.afk` in the game chat.
2.  **To Cancel/Return:** Type `.afk` again during the countdown or while AFK to resume play.

## ⚙️ Configuration

The following variables can be adjusted within the `init()` function of the script:

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `min_round` | 20 | Minimum round required to use the command. |
| `cooldown_ms` | 7,200,000 (2 hrs) | Time in milliseconds before a player can use AFK again. |
| `duration_s` | 900 (15 mins) | Maximum time a player can stay AFK before being forced back. |
| `activation_delay_s` | 60 | The "grace period" before AFK mode actually kicks in. |

## 📦 Installation

1. Ensure you have the `t6-gsc-utils` plugin installed on your Plutonium server (required for chat command registration).
2. Place the script in your server's script folder:
   `%localappdata%\Plutonium\storage\t6\scripts\zm\`
3. Restart your server or rotate the map.

## ⚠️ Requirements

* **Plutonium T6**
* **t6-gsc-utils** (for the `chat::register_command` functionality)

## 📝 Technical Notes

* **Round Handling:** The script modifies `level.zombie_total` and `level.zombie_ai_limit` to pause the game. It saves the state of the round budget to ensure no zombies are "lost" when unfreezing.
* **Spawn Logic:** It attempts to find `player_respawn_point` structs. If those fail, it uses the first player's initial spawn coordinates as a fallback.
