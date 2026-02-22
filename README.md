# Kill on Sight (KoS)

**Author:** Milestorme

Kill on Sight is a lightweight PvP awareness addon that tracks hostile players you’ve marked as **KoS** (Kill on Sight) and optionally highlights enemies from **tracked guilds**. It provides a Spy-like nearby list, alerts, and optional stealth detection support across multiple game versions.

## Features

- **KoS list**: Add/remove players and get alerts when they’re seen nearby.
- **Guild tracking**: Track hostile players belonging to specific guilds ("Guild-KoS").
- **Nearby window**
  - Sorts by most recent **Last seen**
  - Optional row icons (class/skull), per-row fade timers, scaling, transparency
  - Auto-hide when empty
  - One-click actions (Add KoS / Add Guild) with visual tags
- **Notifications**
  - Chat message, screen flash, and optional sound
  - Separate stealth detection banner + sound (when enabled)
  - Throttling to prevent spam
- **Attackers / Stats UI**
  - Attackers list
  - Enemy statistics: first seen, last seen, seen count, wins/losses
  - Sorting and reset controls
- **Sync**
  - Sync KoS/Guild entries with guild (when available)
  - Changelog pruning to reduce SavedVariables bloat

- **Notes (KoS)**
  - Optional per-player note icon on the KoS tab
  - Mouseover shows the full note text; click to create/edit/clear

## Spy KoS Import

KillOnSight can import KoS entries from **Spy** if Spy has been enabled at least once.

### How to Import
1. Enable **Spy**
2. Log in once (or `/reload`) so Spy’s SavedVariables load
3. Run:
   ```
   /kos importspy
   ```
4. (Optional) Disable Spy afterwards

### Notes
- Only **KoS entries** are imported
- Existing KillOnSight entries are **not duplicated**
- If Spy has no KoS entries, nothing is imported and a chat message is shown
- Imported notes/reasons from Spy are stored safely and ignored by core KoS logic
- KillOnSight behavior and detection logic are unchanged

## Commands

- `/kos show` — Toggle the main window
- `/kos help` — Print command help
- `/kos add <name>` — Add a player to KoS
- `/kos remove <name>` — Remove a player from KoS
- `/kos addguild <guild>` — Add a guild to Guild-KoS
- `/kos removeguild <guild>` — Remove a guild from Guild-KoS
- `/kos list` — List current entries
- `/kos sync` — Trigger a sync
- `/kos importspy` — Import KoS entries from Spy

## Installation

1. Download the addon from [Curseforge](https://www.curseforge.com/wow/addons/kill-on-sight).
2. Extract into your WoW AddOns folder:
   - Retail: `World of Warcraft/_retail_/Interface/AddOns/`
   - Classic-era variants: <br>`World of Warcraft/_classic_/Interface/AddOns/` <br>
                           `World of Warcraft/_classic_era_/Interface/AddOns/`<br>
                           `World of Warcraft/_anniversary_/Interface/AddOns/` <br>
3. Ensure the folder is **exactly**: `Interface/AddOns/KillOnSight/`
4. Restart WoW (or `/reload`).

## Localization

Included locales (major languages):

- enUS, deDE, frFR, esES, esMX, itIT, ptBR, ptPT, ruRU, koKR, zhCN, zhTW, jaJP, nlNL, daDK, plPL

If a translation is missing for a key, the addon falls back to showing the key name (so gaps are obvious).

