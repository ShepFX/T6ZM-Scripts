# Enemy Counter HUD for T6 Zombies

This GSC script adds a persistent, per-player **Enemy Counter HUD** to Black Ops 2 (T6) Zombies. It provides real-time tracking of remaining zombies, active dogs, and currently spawned enemies on the map.

---

## Key Features

* **Real-Time Tracking:** Displays the total number of zombies left in the round, active Hellhounds, and how many enemies are currently spawned on the map.
* **Dynamic HUD:** The interface automatically expands to show a "DOGS" row during dog rounds or when Hellhounds are present, and shrinks when they are gone.
* **Visual Alerts:** The zombie counter changes color to a bright orange/red when 5 or fewer enemies remain to alert players to the end of the round.
* **Persistent Preferences:** User settings (ON/OFF) are saved to a text file (`scriptdata/zc_prefs.txt`) and persist across different matches and server restarts.
* **Clean Aesthetics:** Includes pulse animations whenever counts change and a sleek, semi-transparent background.

---

## Commands

Players can toggle the HUD individually using the following chat command:

* `.counter` — Toggles the Enemy Tracker HUD on or off.

---

## Installation

1.  Navigate to your T6 Zombies scripts directory (typically `maps/mp/zombies/`).
2.  Place the `CounterHUD_t6.gsc` file into this folder.
3.  Ensure the script is loaded by your GSC injector or server configuration.
4.  **Note:** The script automatically creates and manages a `scriptdata/` folder for saving player preferences.

---

## Technical Details

### HUD Elements
| Element | Description |
| :--- | :--- |
| **ZOMBIES** | Total enemies remaining in the current round. |
| **DOGS** | Total Hellhounds remaining (only visible during dog rounds or active spawns). |
| **SPAWNED** | The number of enemies currently physically present on the map. |

### Configuration
The script uses an orange accent theme by default:
* **Accent Color:** `(1.00, 0.55, 0.05)`.
* **Background Alpha:** `0.72`.
* **Update Rate:** The HUD refreshes every **0.1 seconds**.
