<p align="center">
  <img src="assets/killonsight-banner.png" alt="Kill on Sight — PvP Awareness for World of Warcraft" width="100%">
</p>

<h1 align="center">Kill on Sight</h1>

<p align="center"><strong>Know who is nearby. Remember who matters.</strong></p>

Kill on Sight (KoS) is a PvP awareness addon that tracks hostile players and guilds, records encounters, and helps you recognize threats nearby. This repository contains separate packages for several WoW clients; features vary by client because their APIs differ.

## Choose the package for your game

| WoW client | Repository folder | Notes |
|---|---|---|
| Retail before Midnight (11.x) | `KillOnSight/` | Uses the Retail API branch. Stealth and attacker tracking depend on events available in that client version. |
| Midnight / Retail 12.x | `KillOnSight-midnight/` | Nearby detection uses enemy nameplates because the client restricts combat-log data. Some classic features, including the Attackers list and stealth alerts, are unavailable or limited in this branch. |
| Classic Era and TBC Anniversary | `KillOnSight/` | Classic feature set includes stealth detection and the Attackers list; guild Sync is available in supported Classic/TBC builds. |
| WoW Forever 1.60.1 | `KillOnSight-forever/` | Uses First Last character names without realm names. Includes one-entry chat sharing, clickable import links, a version-specific What's New note, and peer version checking. This package does not use Guild Sync. |

Use the package that matches your client. Do not combine files from different package folders.

## Core features

- **KoS and Guild KoS:** Keep player and guild threat lists, with notes and nearby identification.
- **Nearby:** Review detected enemies, their class and guild when known, recent sightings, and KoS/Honor status. Right-click a player for available actions.
- **Alerts:** Configure chat notices, sound, screen flash, and enemy-targeting alerts where supported by the client.
- **Enemy Statistics:** Track sightings, first and last seen, class, guild, faction, and PvP outcomes where supported.
- **Honor list:** Keep a separate list of respected players, with notes and visual tags.
- **Spy import:** Import KoS entries from Spy after its SavedVariables have been created.

## WoW Forever sharing and update features

These features are currently in the WoW Forever package:

- Share one selected KoS target, guild, Honor entry, or Stats player; Nearby also has a Share action.
- Copy a readable message into supported chats, including guild, party/raid, whispers, and `/say`. Non-users see the name and share type as text. KillOnSight users can click the link, review the entry, and confirm an import.
- Shares include the selected name only. Notes remain local and are not sent.
- The What's New popup shows the complete changelog section for the installed version once on first login after updating. It remembers the version shown, so it does not repeat on `/reload` or later logins.
- The peer version checker exchanges addon versions with guild and group members and reports a newer version when one is announced. It does not check CurseForge or the web. Use `/kos version` to see the installed version.

## Commands

Common commands (availability may vary by package):

- `/kos` or `/kos show` — Toggle the main window.
- `/kos help` — Show command help.
- `/kos add <name>` and `/kos remove <name>` — Manage a KoS player.
- `/kos addguild <guild>` and `/kos removeguild <guild>` — Manage a Guild KoS entry.
- `/kos list` — List entries.
- `/kos importspy` — Import KoS entries from Spy.
- `/kos sync` — Trigger Guild Sync in supported Classic/TBC builds only; not available in the WoW Forever package.
- `/kos version` — Show the installed version in WoW Forever.

## Manual installation

1. Download or open the repository and choose the package folder for your WoW client.
2. Copy the addon's `KillOnSight` folder (the one containing its `.toc` file) into that client's `Interface/AddOns/` directory.
3. Confirm the final path is `.../Interface/AddOns/KillOnSight/`, then restart WoW or run `/reload`.

Typical AddOns locations:

- **Retail and Midnight:** `World of Warcraft/_retail_/Interface/AddOns/`
- **Classic Era:** `World of Warcraft/_classic_era_/Interface/AddOns/`
- **Classic Anniversary / TBC Anniversary:** `World of Warcraft/_anniversary_/Interface/AddOns/`
- **WoW Forever:** `World of Warcraft/_forever_/Interface/AddOns/`

If you install from a downloaded ZIP, extract the matching package and place its addon folder at the path above. Do not copy the outer repository package directory as the addon folder unless that directory itself contains the `.toc` file.

## Localization

The included packages support multiple locales. Coverage differs by package; check its locale files for the languages included in that build.

## License

MIT
