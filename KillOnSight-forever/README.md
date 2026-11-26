# Kill on Sight (KoS)

### Author: Milestorme

### Contributor: Minstrel

Kill on Sight is a PvP awareness addon for WoW Forever. It records hostile players you encounter, highlights players and guilds you choose to track, and provides a nearby list and configurable alerts.

## Features

- **Player KoS list:** Add, remove, and annotate players. KoS sightings are highlighted in Nearby and can trigger chat, screen-flash, and sound alerts.
- **Guild KoS:** Track hostile guilds and identify their members in Nearby. Guilds can be added from a player's Nearby context menu or through the Guilds tab.
- **Honor list:** Keep a separate list of respected players. Honor entries are tagged in Nearby and Stats and use a green target-portrait marker; Honor status does not trigger a KoS alert.
- **Nearby window:** Lists detected hostile players, shows full First Last identities, class information when known, KoS/Guild/Honor tags, and hidden-state indicators. Entries are ordered by priority and recent activity. Scroll to browse additional players; click a row to target and right-click for player, guild, Honor, and announcement actions.
- **Nearby customization:** Configure visibility, independent nearby-detection sound, lock state, auto-hide, scale, background transparency, name font and size, and maximum visible rows. The window can be moved when unlocked.
- **Alerts and sound:** Configure KoS/Guild sound, nearby-detection sound, enemy-targeting alerts, screen flash, and alert volume. Choose and preview a dedicated targeting sound. Alert sounds can be muted by setting volume to zero.
- **Stealth/hidden detection:** Detect supported stealth, Vanish, Prowl, and Shadowmeld states, display the state in Nearby, and provide a separate banner and sound alert when enabled.
- **Enemy Statistics:** Record first and last seen time, sightings, class, guild, faction, wins, and losses. Search and sort the list, inspect a selected player's details, reset Stats, and add/remove KoS or Honor entries or add the player's guild to Guild KoS.
- **Notes:** Save notes for KoS players, tracked guilds, and Honor players. Note icons in the relevant lists show the note on hover and open the editor when clicked.
- **Share entries:** Share one selected KoS target, guild, Honor entry, or Stats player at a time. The Share window selects a ready-to-copy message; paste it into chat to send. Non-users see readable text, while KillOnSight users can click the link to review and import the entry. Shares include the name only; notes remain local.
- **Supported chat:** Share links work in guild and officer, party and raid, instance and battleground, whisper (including Battle.net whisper), say, yell, community, and custom channel messages.
- **What's New popup:** On the first login after an addon version changes, show a Blizzard-style note containing the complete latest changelog section. The version is saved after the note appears, so it will not show again on later logins or `/reload`.
- **Peer version checking:** Exchange installed versions with guild and party/raid members, and show a chat notice when a newer version is received.
- **Minimap button:** Left-click to open the main window. Right-click to add your current player target to KoS. Its position and visibility are managed by the minimap button library.
- **Profiles:** Create, copy, rename, reset, and delete settings profiles. Nearby layout and alert options are saved per profile.
- **Saved data and identity:** Uses WoW Forever's First Last player identity (there is no realm component). Existing SavedVariables are retained, and legacy first-name/last-name records are reconciled during migration to avoid splitting the same player's data.
- **Localization:** Includes enUS, deDE, frFR, esES, esMX, itIT, ptBR, ptPT, ruRU, koKR, zhCN, zhTW, jaJP, nlNL, daDK, and plPL.

## Main window tabs

- **Players:** Manage KoS players and their notes.
- **Guilds:** Manage tracked guilds and their notes.
- **Stats:** Review sightings and PvP outcomes; sort, search, inspect details, reset, and manage KoS/Honor/Guild KoS status.
- **Options:** Configure alerts, sounds, Nearby appearance, and profiles.
- **Honor:** Manage the separate Honor list and notes.

The legacy Attackers tab is not exposed in this build.

## Spy KoS import

KillOnSight can import KoS entries from Spy if Spy has been enabled at least once.

1. Enable Spy and log in once (or use `/reload`) so Spy's SavedVariables are available.
2. Run `/kos importspy`.
3. Spy can be disabled afterwards if you no longer need it.

Only Spy KoS entries are imported. Existing KillOnSight entries are not duplicated. Imported notes/reasons are retained as notes and do not affect KoS logic. If Spy has no KoS entries, KillOnSight reports that nothing was imported.

## Commands

- `/kos` or `/kos show` — Toggle the main window.
- `/kos help` — Show command help.
- `/kos version` — Show the installed version. KillOnSight checks versions shared by guild and group members.
- `/kos add <name>` — Add a player to KoS. Use the player's First Last name.
- `/kos remove <name>` — Remove a player from KoS.
- `/kos addguild <guild>` — Add a guild to Guild KoS.
- `/kos removeguild <guild>` — Remove a guild from Guild KoS.
- `/kos list` — List current KoS and Guild KoS entries.
- `/kos importspy` — Import Spy KoS entries.
- `/kos statsprune` — Show the Stats retention policy.
- `/kos statsprune on|off` — Enable or disable automatic Stats pruning.
- `/kos statsprune maxdays <N>` — Set the maximum age of retained Stats entries.
- `/kos statsprune maxentries <N>` — Set the maximum number of retained Stats entries.
- `/kos statsprune now` — Prune Stats immediately using the current policy.

## Version checking

KillOnSight sends its installed version to guild members on login and to party/raid members on login or when joining a group. If it receives a newer version from another KillOnSight user, it prints an update notice once for that version. This is a peer check: it does not query the web, so it learns about a newer build only after a member running that build announces it. Use `/kos version` to see your installed version.

## Building the What's New popup

The game cannot read `CHANGELOG.md` directly. Before packaging a release, update the top changelog section and the TOC version, then run `python Tools/generate_whats_new.py` from the addon directory. The script checks that both versions match and compiles every heading and bullet from that newest changelog section into `Modules/WhatsNew.lua`, which the game loads for the popup.

## Installation

1. Download the addon from [CurseForge](https://www.curseforge.com/wow/addons/kill-on-sight).
2. Extract the addon into the WoW Forever client's `Interface/AddOns/` directory.
3. Ensure the addon folder is exactly `Interface/AddOns/KillOnSight/`.
4. Restart WoW or enter `/reload`.

Install this build over the existing KillOnSight folder to keep using its SavedVariables. Do not install a second copy beside it.
