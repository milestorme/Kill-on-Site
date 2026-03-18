## 3.4.5

- Added _IsDisabledInstance() hard gate at top of Detector:CheckUnit and OnNameplateRemoved as defense-in-depth against instance detection leaks
- Fixed tainted boolean comparisons from UnitIsUnit, UnitIsPlayer, UnitIsEnemy, UnitIsFriend, UnitCanAttack
- Rewrote IsInPvEInstance as single pcall block to catch tainted inInstance booleans

## 3.4.4

- Fixed TOC

## 3.4.3

- Fixed _ValidPlayerGUID taint errors caused by pcall(tostring) not actually untainting secret strings; all comparisons now wrapped in pcall(function() ... end)
- Hardened remaining bare instType comparisons in Core.lua and Portrait.lua

## 3.4.2

- Fixed Detector still firing inside Delves via UNIT_AURA/spellcast events that bypassed the instance gate
- Fixed tainted string comparisons in Detector (UnitName, UnitFullName, GetGuildInfo, UnitGUID) causing "attempt to compare local 'name'" errors in protected instances

## 3.4.1

### Fixed
- Tainted GUID/instance-type comparisons in NearbyFrame causing "attempt to compare local 'guid'" errors inside Delves by wrapping IsInInstance and UnitGUID checks in pcall.

## 3.4.0

### Fixed
- `Database.lua` `_StatsKey`: cached `name:match()` result to avoid evaluating the same pattern twice (backport from Classic v3.2.5)
- `Notifier.lua`: removed excessive blank lines between `_Print` and `IsInGoblinTown`
- `NearbyFrame.lua`: fixed inconsistent nil guard on modifier key check (Shift/Ctrl/Alt) in row click handler

## 3.3.9
- Fixed bug where detector was still active in delves

## 3.3.8

### Changed
- Restructured project: all modules moved into a dedicated `Modules/` folder for cleaner organisation.
- Libraries now load via a single `Libs/embeds.xml` instead of individual file entries in the TOC.

### Fixed
- Removed redundant double-export of `_G.KillOnSight_Core` at the end of Core.lua.

### Notes
- No gameplay, SavedVariables, or API changes — this is a project-structure and housekeeping release.
- `Midnight_Init.lua` remains in the addon root as the pre-module bootstrap.
- Load order is unchanged; all global captures verified correct.

## 3.3.7
- Fix: Prevent nil realmDB errors by lazily initializing database state when accessed early (DB:GetData / DB:GetProfile)

## 3.3.6

### Fixed
- Fix: Localized the battleground/arena "Nearby disabled" notice (new L.NEARBY_DISABLED_INSTANCE)
- Fix: Prevent UI taint and ADDON_ACTION_BLOCKED errors by deferring layout updates during combat
- Fix: Safe handling of frame positioning (SetPoint / ClearAllPoints) in combat lockdown
- Improvement: Centralized deferred execution system for combat-safe UI updates

## v3.3.5

### Changed
- Midnight version is now **Retail-only (Mainline)**.
- Removed all Classic-era compatibility code and conditional branches.
- Simplified multiple modules by eliminating `IS_RETAIL` checks and fallback logic.
- Replaced dependency on Core helper with a local `IsGroupOrSelfByName()` implementation in `Midnight_Stats.lua`.

### Fixed
- Fixed **Nearby frame lock state not persisting** due to incorrect saved variable key.
- Fixed **Options UI lock checkbox** not matching actual lock variable (`nearbyFrameLocked`).
- Fixed **localization bug** caused by `GetLocale()` shadowing locale table (affected KoS/Guild-KoS detection).
- Improved **font fallback handling** to prevent empty chat messages and provide proper warning output.

## v3.3.4

### Added
- Nearby list right-click option **"Copy Name"**
- Copy popup with auto-focus and pre-selected text for quick Ctrl+C copying

### Retail
- Improved PvE instance suppression to fully disable detector inside Delves
- Prevented Retail secret-string errors when inside instanced PvE content


## v3.3.3

### Fixed
 - Update Sync funtion
 
## v3.3.2

### Added
- Nearby: New Options slider to limit --max visible rows before scrolling-- (default --20--, adjustable --5–20--).

## v3.3.1

### Fixed
- Stats --Seen-- count now increments correctly when players timeout or are re-encountered from Nearby.
- Fixed encounter resolution not firing when Nearby entries expired or were cleared.
- Resolved Lua errors:
  - GUI.lua missing `end` near EOF.
  - NearbyFrame.lua unexpected `\` symbol.
- Fixed Nearby frame incorrectly rendering certain special characters (e.g. `ß`) when using Avantgarde font.

### Improved
- Added smart font fallback for glyphs not supported by Avantgarde to keep names rendering correctly.
- Nearby display now stays visually consistent with Tooltip and Target frame name rendering.

## Version 3.3.0

### Added

- Profile system for Options (create, rename, edit).
- Account-wide KoS database shared across all characters and realms.
- Improved realm detection for cross-realm players.
- UTF-8 name handling for special characters in Nearby and Stats.
- Instant Options UI update when switching profiles.

### Improvements

- Nearby tooltip consistency with Stats data.
- Default Nearby background opacity set to 60% for new/reset profiles.
- Localization-friendly UI labels.

## Version 3.2.9

### Added

- Added Faction color to nearby tooltip and faction to stats.
- Store --realm-- in stats and display players as `Name-Realm` on Stats page.
- New --Nearby Background-- slider with profile persistence.
- Blizzard-style slider layout for Nearby Scale / Background.

### Changed

- Reworked Nearby sliders to match Name Size layout (label + value + slider).
- Converted UI text to locale keys:

  - `L.UI_NEARBY_SCALE`
  - `L.UI_NEARBY_BACKGROUND`
- Cleaned locale strings (removed debug text like “0=invisible”).

### Fixed

- Removed Realm: heading from tooltip
- Fixed font chat message spam

## Version 3.2.8

### Nearby Frame – Dynamic Auto Width

- Reworked auto-width system for improved reliability on Retail clients.
- Nearby frame now measures text using an unconstrained internal FontString to correctly expand for long entries.
- Faster, smoother width animation for more responsive resizing.
- Disabled text wrapping so entries remain on a single line.

### Combat Safety Fixes

- Fixed `ADDON_ACTION_BLOCKED` error caused by resizing the Nearby frame during combat.
- Nearby list --continues updating in combat-- so new enemies appear instantly.
- Frame resizing and re-sorting are safely deferred until combat ends.
- Pending width updates apply automatically on `PLAYER_REGEN_ENABLED`.

### Behaviour Improvements

- Prevented animation loop from attempting width updates during combat lockdown.
- Improved refresh flow so spec updates and new sightings do not cause protected calls.
- Stabilised Nearby updates in battlegrounds and high-combat environments.

### Internal

- Refactored NearbyFrame width calculation and update flow.
- Added safer handling for width animation and refresh queues.
- General cleanup to reduce taint risk on Retail UI.


## Version 3.2.7

### Nearby Frame Improvements

- Added --dynamic auto-width-- for Nearby list.
- Nearby frame now expands to fit the longest visible entry on a single line.
- Disabled text wrapping to prevent multi-line entries.
- Added smooth width animation with significantly faster expansion speed.
- Improved resize responsiveness when specs or fonts update.

### Performance & Behaviour

- Optimised width animation using dynamic speed scaling (fast expand, smooth settle).
- Reduced micro-resize jitter when multiple players update at once.
- Improved refresh handling after spec cache updates.

### Inspect / Spec Handling

- Improved inspect cache behaviour.
- Pre-warm inspect cache when Nearby entries appear (lightweight throttle).
- Prevent repeated inspect requests once a player spec is known.
- Faster tooltip spec updates.

### Font Handling

- Fixed issue where font selection required size change to apply.
- Font updates now apply instantly without blanking Nearby entries.
- Improved stability when switching fonts while players are visible.

### Internal

- Cleaned up NearbyFrame update flow.
- Reduced refresh lag caused by queued timers.
- General code refactor for smoother UI updates.

## v3.2.6

### Fixed

- Retail War Mode: specialization detection from tooltip now validates spec against the unit’s class to prevent incorrect specs appearing.
- Battlegrounds / instances: prevented “ADDON_ACTION_BLOCKED” errors caused by SetShown() during combat lockdown.
- Nearby frame visibility changes are now safely deferred until combat ends.
- Portrait.lua hardened against Blizzard protected “secret” values to prevent dragon icons appearing on all enemies in BGs.
- Disabled Nearby-related spec / portrait logic in instances where Nearby is suppressed.
- Errors caused by comparing protected GUID values in battlegrounds.
- Instance suppression now runs before GUID handling to prevent crashes.
- Nameplate spec system throwing “table index is secret” errors in BGs and instances.
- Retail inspect helpers running when Nearby should be disabled.

### Improved

- War Mode specialization detection using Blizzard tooltip data.
- Tooltip no longer shows “Inspecting...” unless an inspect is actually pending.
- War Mode specialization updates without requiring inspect requests.
- Prevented specs getting stuck on “Inspecting...”.

## v3.2.5

### Fixed

- Bug on instance enter

## v3.2.4

### Added

- Added Avantgarde font option (LibSharedMedia registration).

### Improved

- Retail inspect system rewritten for stability.
- Specs now queue from target and nameplates.
- Fixed Inspecting... getting stuck due to stale unit tokens.
- Added heartbeat + timeout recovery for inspect queue.

## 3.2.3

### Changed

- Core: consolidated GUI refresh debouncing to allow immediate and deferred updates without clobbering each other.
- Detector: added TTL cleanup for stealth/visibility state tables to prevent long-session buildup.
- Sync: switched to addon metadata version and safer percent-encoding for payload values.
- Minimap/Notifier: removed duplicate dropdown helper and unused anti-spam stub.

## 3.2.2

### Added

- Retail: pre-warm specialization inspect cache for new Nearby entries using a lightweight throttled queue.
- Retail: internal spec cache/backoff to avoid repeated inspect requests for the same player in crowded areas.

### Changed

- Retail: rewritten Inspect queue now prefers cached specs, tracks last-known unit tokens per GUID, and refreshes tooltips immediately on INSPECT_READY.

## 3.2.1

### Changed

- Retail: rewrote Nearby specialization inspection flow to update tooltips immediately when spec data is already cached.
- Retail: INSPECT_READY now updates the currently-hovered tooltip without requiring mouse-off/mouse-over.

### Fixed

- Retail: improved inspect unit resolution by caching last-known unit tokens and re-resolving via mouseover/target/focus/nameplates.
- Retail: reduced cases where spec would only appear after re-hovering.

## 3.2.0

### Added

- Nameplate scanning added for specialization inspect detection.
- Localized "Inspecting..." tooltip loading text.

### Fixed

- Combat lockdown ADDON_ACTION_BLOCKED issues with Nearby frame.
- Tooltip locale key showing instead of translated text.
- Lua syntax error in NearbyFrame.lua from nameplate inspect logic.

## 3.1.9

### Added

- Nearby tooltip now shows class (colored) and specialization (Retail via Inspect).
- Retail: automatic specialization detection for Nearby entries using INSPECT_READY.

## 3.1.8

### Added

- Added Nearby Name Font dropdown to the Options panel.
- Added Nearby Name Size slider to adjust player name text in the Nearby list.

  - Embedded LibSharedMedia-3.0 for expanded font support and automatic font detection.
- Added full localisation for:

  - Nearby name font
  - Nearby name size
  - across all supported game locales.

## 3.1.7

### Fixed

- Retail: ensure open-world win/loss stats credit when tracking targets or mouseover enemies.

## 3.1.6

### Fixed

- Retail: avoid UnitAura fallback in stealth checks to prevent AuraUtil secret-value errors.

## 3.1.5

### Fixed

- Nearby: avoid protected SetAttribute calls while clearing rows during combat.

## 3.1.4

### Fixed

- Nearby: pull full UnitFullName realm data so tooltips show realms when available.

## 3.1.3

### Fixed

- Nearby: avoid protected EnableMouse calls in combat to prevent action-blocked errors.

## 3.1.2

### Fixed

- Nearby: show realm name in the tooltip and keep click-to-target working for cross-realm players.

## 3.1.1

### Fixed

- Restored stealth inference on nameplate removal by passing the correct unit token and GUID.
- Prevented protected layout calls in combat by deferring Nearby minimal-mode layout changes until combat ends.
- Prevented protected SetHeight calls in combat by deferring Nearby frame height updates until combat ends.
- Restored Retail engagement tracking queuing for battleground win attribution.
- Allowed KoS portrait rings in battlegrounds and arenas (no suppression for KoS/Guild targets).
- Avoided Nearby menu errors by falling back when EasyMenu is unavailable.
- Fixed Nearby "Clear list" to fully reset cached entries.

## 3.1.0

### Fixed

- Removed a global `EasyMenu` shim that conflicted with other addons.
- Fixed an issue where RestedXP Guide menus were duplicated or replaced by KillOnSight entries.
- Improved compatibility with addons that rely on Blizzard’s native dropdown menu handling.

## 3.0.9 (Retail / Midnight 12.0.0)

### Stability & Crash Fixes

- Fixed multiple Retail 12.0.0 crashes caused by Blizzard returning protected
  --“secret values”-- for unit names.
- Hardened all nameplate removal handling to safely normalize unit names
  without string comparisons or method calls on protected values.
- Fixed boolean-test crashes caused by protected return values from
  `UnitTargetsPlayer()` and combat-window checks.

### Instance Safety

- Disabled Nearby / Detector processing inside:

  - Battlegrounds
  - Arenas
  - Dungeons (including Mythic+)
  - Raids
  - Scenarios
- Prevents Retail 12.x API edge cases and taint during instanced content.
- Nearby list is automatically cleared and hidden when entering instances.

### Data Handling

- Improved Retail name handling using `pcall` + `tostring` normalization.
- No changes to SavedVariables structure.
- No data loss or destructive behavior introduced.

---

## Version 3.0.8 (Retail Midnight)

- --Disable Nearby detector on Retail--

  - Prevents repeated forbidden-action errors and UI lockouts
  - Portraits no lonher show on KoS targets in BG and stats no longer log in BG due to blizzard API changes

## Version 3.0.7 (Retail Midnight Stability Update)

### 🚀 Retail (Patch 12.0 / Midnight)

- --Removed COMBAT_LOG_EVENT_UNFILTERED usage on Retail--

  - Prevents repeated forbidden-action errors and UI lockouts
  - Retail now uses unit-scoped and nameplate-based detection only
- --Nearby detection reworked for Retail--

  - Uses `NAME_PLATE_UNIT_ADDED`, target, and mouseover
  - Added --distance filtering-- to prevent far-range nameplates from flooding Nearby
- --Enemy Nameplates requirement handling--

  - When enemy nameplates are disabled:

    - Nearby switches to a limited mode (target/mouseover only)
    - A --localized warning-- is shown (includes “press V” shortcut)
  - Warning is shown --after sync messages-- for better UX
- --Attackers list disabled on Retail--

  - Removed from UI and options
  - Prevents misleading or unverifiable attacker data without combat log access

### 🛡️ Notification & Zone Rules

- --Sanctuary zones now fully respected--

  - KoS and Guild notifications no longer fire in sanctuaries

### 🌍 Localization

- Added new locale key:

  - `RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF`
- Implemented across --all supported languages-- with native translations
- Removed hardcoded English warnings

### 🔧 Stability & Compatibility

- Updated embedded libraries where required to avoid BugSack/BugGrabber dependency issues

### 🧹 UI / Cleanup

- --Removed Stealth detection options from the UI--

  - Blizzard API changes in 12.0.x prevent reliable stealth detection
  - Stealth options are now fully hidden to avoid confusion

### ⚙️ Technical / Internal

- Removed reliance on deprecated or restricted combat log behavior
- Reduced unnecessary sorting and refresh work for better performance
- Improved Nearby list stability in combat-restricted environments

### Notes

Retail behavior intentionally differs from Classic-era clients due to Blizzard API changes in Patch 12.0.X Nearby detection on Retail requires --enemy nameplates enabled-- for full functionality.
Stealth alerts are not available in Retail 12.0.x due to Blizzard API restrictions.
This is a design limitation, not an addon bug.

## 3.0.6

### Fixed

- Deferred guild resolution (Spy-style): guild names now populate reliably for Nearby, Attackers, and Stats once the data becomes available (target/mouseover/nameplates)

- Attackers UI now refreshes automatically when guild info is enriched

- Fixed Nearby list click-to-target reliability, especially in battlegrounds (e.g. Alterac Valley).

  - Secure targeting attributes are now consistent and no longer desync during combat.
  - Clicking a player name now targets the correct unit reliably.

- Fixed KoS / Guild alert spam caused by repeated aura, combat log, and visibility updates.

  - KoS and Guild alerts (sound, screen flash, chat announce) now trigger --only once per player while they remain in the Nearby list--.
  - Alerts reset only after the player fully leaves the Nearby list and is seen again.

### Added

- Optional --Notes-- column on the KoS tab

  - Clickable note icon per entry (dimmed when empty)
  - Mouseover shows full note text in a wrapped, scrollable tooltip
  - Click opens a small editor to create/edit/clear notes
  - Notes are stored as `reason` in SavedVariables (Spy imports show here automatically)

### Changed

- `/kos importspy` now refreshes the KoS list immediately
- `/kos importspy` prints a message even when no new entries are found

### Notes

- Notes are metadata only and do not change KoS/Guild detection

---

## 3.0.5

### Added

- Added --Spy KoS import support--

  - New slash command: `/kos importspy`
  - Imports Kill-on-Sight entries from Spy’s SavedVariables
  - Automatically skips entries already present in KillOnSight
  - Safe to disable Spy after import
- Imported metadata (such as Spy “reason”) is stored safely and ignored by core KoS logic

### Notes

- Spy must be enabled and loaded at least once before importing
- No changes to KillOnSight KoS/Guild detection or behavior

---

## 3.0.4

### Fixed

- NPC --rare, rare elite, elite, and world boss-- targets now always display their dragon indicators
- Corrected client detection so Classic-era clients use proper target-frame handling
- Ensured Retail and Classic use appropriate visual paths without conflict

### Notes

- Player KoS and Guild behavior is unchanged
- This fix applies across Retail, Classic Era, TBC Anniversary, Wrath, and Titan-Reforged

---

## 3.0.3

### Added

- Full localization support for all major languages
- Shortened tooltip strings to prevent overflow on non-English clients
- Added TOC localization metadata

### Fixed

- Retail fallback handling for target frames
- Minor UI consistency issues across versions

---

## 3.0.2

### Fixed

- Cross-version targeting fallback logic
- Sanctuary zone handling for Nearby list
- Stability and performance improvements

---

## 3.0.1

### Added

- Retail target-frame support with safe fallbacks
- Improved stealth detection handling
- Performance optimizations and throttling improvements
