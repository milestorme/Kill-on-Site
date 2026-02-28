# KillOnSight – Changelog

## 3.2.7
- Update TOC's Compress to one 

## 3.2.6
- Fix: Prevent ADDON_ACTION_BLOCKED by deferring Nearby frame updates during combat
- Fix: Safe handling of Show/Hide, SetPoint, and SetAttribute in combat lockdown
- Fixed phantom Nearby entries by removing targets on click if they resolve as non-attackable (layered/phase ghost)


## 3.2.5 

### Added
- Added Battleground sound mute option (KoS/Guild/Nearby/Stealth)

### Changed
- Restructured addon folders (moved Lua modules into `Modules/`, and assets into `Images/`).
- Added `embeds.xml` and updated TOCs to load libraries via the embedded XML loader.

### Fixed
- `Core.lua` `IsFlagHostileSpy`: added nil guard for `COMBATLOG_OBJECT_REACTION_HOSTILE` so the function always returns `false` (not `nil`) when the constant is unavailable, consistent with the existing `band` guard and the sibling `IsFlagPlayer`.
- `Core.lua` `NAME_PLATE_UNIT_REMOVED` handler: normalized 8-space body indentation to the 2-space standard used by every other event block in the same handler.
- `Database.lua` `_StatsKey`: cached `name:match()` result to avoid evaluating the same pattern twice; removed unreachable inner `or name` branch.
- `Notifier.lua`: removed duplicate comment above `IsInGoblinTown` that appeared twice with a blank line between them.
- `Portrait.lua` `IsKoSTarget`: replaced `UnitName()` (returns name only) with a guarded `UnitFullName()` call to correctly retrieve the realm, so realm-qualified KoS entries trigger the portrait border on cross-realm targets.

## 3.2.4

### Fixed
- Fixed attackers list not populating when the player is attacked
- Resolved issue where combat log handler exited early due to strict dstGUID check
- Corrected logic to scope attacker tracking instead of returning from the entire handler

### Improved
- Added fallback detection using combat log flags (AFFILIATION_MINE, TYPE_PLAYER) for better compatibility across Classic/TBC/Wrath clients
- Improved reliability of attacker detection across inconsistent CLEU events

## 3.2.3

### Fixed
- Fixed TBC “phantom” Nearby entries (layer/nameplate cleanup + visibility guard)
- Removed legacy non-hostile target “ghost” workaround
- Added one-time logon notice when Enemy Nameplates are disabled (localized)

## 3.2.2

### Refactor & Cleanup

### Bug Fixes
- Fixed `IsGroupOrSelfByName` scoping bug where the function was called before its definition, silently skipping self/party filtering in encounter tracking
- Removed duplicate `_ScheduleGUIRefresh` definition; unified into a single implementation with consistent 0.2s delay
- Removed duplicate `local playerGUID` declaration inside `HandleCombatLog`

### Performance
- Moved `HandleName` closure out of `HandleCombatLog` to module level, preventing a new closure allocation on every `COMBAT_LOG_EVENT_UNFILTERED` fire
- Fixed `_FlashWindow` leaking a new UI frame on every alert; overlay child is now created once and reused

### Code Quality
- `Notifier.lua`, `Sync.lua`: replaced early `local DB = KillOnSight_DB` / `local Notifier = KillOnSight_Notifier` bindings with lazy `GetDB()` / `GetNotifier()` getters to avoid stale references
- `Database.lua`: extracted `_EnsureStatsEntry` helper to deduplicate identical boilerplate across `StatsAddSeenEncounter`, `StatsAddWin`, and `StatsAddLoss`
- `Database.lua`: legacy migration block now guarded by `KillOnSightDB.legacyMigrated` flag; skipped after first run instead of executing every login
- `Core.lua`: `ResolveGuildForGuid` now uses the module-level `CleanName` helper instead of a duplicate inner `Clean` function
- `Core.lua`: removed undocumented `/kos statsprune max` alias; only `maxentries` accepted, matching help text
- `Core.lua`: normalised indentation to consistent 2-space throughout

### Retail/Mainline Removal *(addon is ClassicEra-only)*
- Removed `IS_RETAIL` variable and all conditional branches from `Core.lua`, `Detector.lua`, and `GUI.lua`
- Removed `EnemyNameplatesEnabled()` and `WarnIfEnemyNameplatesDisabled()` from `Core.lua`; `COMBAT_LOG_EVENT_UNFILTERED` now registered unconditionally
- `Detector.lua`: removed Retail-only nameplate distance filter; simplified `IS_CLASSIC_CLAMP_CLIENT` check
- `GUI.lua`: Attackers tab always shown; Goblin Towns and Range Clamp options always rendered
- `Portrait.lua`: removed `IsRetailMainline()` and `RunRetail()` (~345 lines); Classic code now runs at module level directly (563 → 189 lines)
- All 16 locale files: removed unused `RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF` key

## 3.2.1

### Fixed
- Suppressed KoS and Guild alerts in Sanctuary zones (matches Nearby frame behavior)
- Fixed one-time alert beep when hearthstoning/teleporting into Sanctuary cities

## 3.2.0

### Fixed
- Legacy list migration now reliably maps into `data.players` / `data.guilds` so existing KoS/Guild entries are visible after upgrades.
- Slash parsing now lowercases only the command token (arguments keep user-provided casing).
- `/kos addguild` and `/kos removeguild` now support multi-word guild names.
- `Util.lua` is now loaded in Classic, Wrath, and MoP TOCs for consistent tag rendering behavior.

## 3.1.9

### Added
- Nearby: Optional detection range clamp for a more Classic-like feel (enabled by default on TBC 2.5.5 → MoP 5.5.3).
- Nearby: Live list updates during combat while preserving targeting for already-visible rows.
- Tooltip: Shows `Not targetable` for new entries that cannot be targeted during combat.

## 3.1.8

### Added
- Nearby stealth detector screen flash disable/enable option

## 3.1.7

### Added
- Nearby background darkness slider with live opacity updates.
- Classic-safe `SafeSetShown` handling.
- Legacy realm database migration (Realm → Realm-Faction).
- Missing tooltip locale keys across all supported languages.

### Fixed
- Nearby frame not showing on Classic Era (1.15.8).
- KoS detection not populating Nearby list on Classic.
- Sanctuary suppression incorrectly hiding frame in rested areas.
- Tooltip showing raw `TT_*` locale keys.
- Minimal-mode backdrop alpha not updating from profile settings.
- Duplicate suppression handlers causing recursion and hidden frame issues.

### Changed
- Reworked Nearby options layout for consistent alignment.
- Unified suppression logic for sanctuary and goblin towns.
- Standardized profile access between GUI and NearbyFrame.

### Localization
- Added translations for:
  - TT_KOS
  - TT_GUILD
  - TT_NOT_TARGETABLE
- Updated all locales (deDE, frFR, esES, esMX, ruRU, ptBR, ptPT, itIT, jaJP, koKR, zhCN, zhTW).

### Internal
- Cleaned duplicate suppression functions.
- Improved Classic/TBC compatibility paths.


## 3.1.6

### Nearby Frame

* Added **dynamic auto width** to the Nearby list.
* Nearby frame now expands automatically to fit the longest visible entry.
* Disabled text wrapping so long player names and specs stay on a single line.
* Implemented faster, smoother width animation for responsive resizing.
* Improved width measurement using an unconstrained internal FontString to correctly detect long entries.

### Font Settings

* Fixed issue where Nearby font selection and font size were not saved.
* Font and size now persist correctly across `/reload` and relog.
* Added missing profile defaults for:

  * `nearbyNameFont`
  * `nearbyNameFontSize`

### Performance & Behaviour

* Reduced resize jitter during rapid Nearby updates.
* Improved width updates when fonts or specs change.
* Safer handling of width changes during combat.

### Internal

* Updated `NearbyFrame.lua` auto*width logic for Classic Era compatibility.
* Added database defaults to ensure profile settings load correctly.


## 3.1.5
### Fixed
* Version string consistency across README, TOCs, and sync metadata.

## 3.1.4
### Added
* Added Nearby Name Font dropdown to the Options panel.
* Added Nearby Name Size slider to adjust player name text in the Nearby list.
	* Embedded LibSharedMedia*3.0 for expanded font support and automatic font detection.
* Added full localisation for:
	* Nearby name font
	* Nearby name size
	* across all supported game locales.

## 3.1.3
### Fixed
* Nearby list context menu now uses Blizzard dropdown initialization to avoid missing `EasyMenu` at runtime.

## 3.1.2
### Fixed
* Restored the debounced GUI refresh helper so modules can trigger UI updates safely.
* Ensured notify throttling cache entries are pruned periodically to avoid unbounded growth.

## 3.1.1
### Fixed
* Removed a global `EasyMenu` shim that conflicted with other addons.
* Fixed an issue where RestedXP Guide menus were duplicated or replaced by KillOnSight entries.
* Improved compatibility with addons that rely on Blizzard’s native dropdown menu handling.

## 3.1.0
**Release type:** Nearby List reliability & tooltip improvements  
**Primary focus:** Classic / TBC Anniversary

### Improved
* **Live Nearby List tooltip updates**
  * Tooltip now updates in real time while hovering, without requiring mouse movement.
* Improved handling of **players temporarily not targetable**.
  * Entries are marked only while genuinely not targetable.
  * Status clears immediately once the player becomes targetable again.
* Improved Nearby List targeting reliability on **TBC Anniversary**.

### Notes
* Changes are limited to Nearby List behavior and tooltips.
* No changes to detection logic, alerts, or Retail behavior.

## 3.0.9
**Release type:** Stability & targeting reliability update  
**Focus:** TBC Anniversary / Classic safety, Nearby List robustness

### Fixed
* Fixed multiple **Lua 5.1 compatibility issues** uncovered during hard structural audit.
* Removed invalid / unsafe constructs from `NearbyFrame.lua` that could cause load or runtime errors.
* Fixed tooltip update logic so **Nearby List tooltips refresh immediately while hovering** after click results (no re*hover required).
* Fixed rare syntax hazards caused by partial or duplicated `SetScript()` lines.
* Fixed targeting edge cases where entries could desync from their secure macro target.

### Improved
* **Greatly improved Nearby List targeting reliability on TBC Anniversary**:
  * Better handling of name normalization for Classic/TBC clients.
  * Safer post*click validation when targets are not attackable due to layering.
* Added robust handling for **layer/cache ghost players**:
  * Entries are temporarily suppressed when targeted but not attackable.
  * Tooltip clearly indicates “not targetable right now” without removing entries permanently.
* Tooltip logic is now fully centralized and refresh*safe.

### Audit & Maintenance
* Performed a **full hard parse*style audit** across all Lua files:
  * Verified correct `function / end` and `repeat / until` structure.
  * Verified XML validity.
  * Verified TOC metadata consistency.
* Unified addon versioning:
  * All TOC files updated to **3.0.9**
  * `Sync.lua` updated to `ADDON_VER = "3.0.9"`
* Confirmed no Retail*only regressions introduced.

### Notes
* This version establishes **3.0.9 as a clean, audited baseline** for future development.
* No gameplay logic or detection behavior was removed — changes are safety* and reliability*focused only.

***


## 3.0.8 (Classic / TBC Anniversary)

### Sync
* Reworked guild sync to be **safe and non*destructive**.
* Removed all reset and delete behavior — sync now **only merges additions and updates**.
* Restricted sync traffic to the **GUILD channel only**.
* Added clear chat feedback when a sync completes, including how many entries were merged or ignored.

### Data & Persistence
* KoS entries now persist **realm suffix** and **guild** when available.
* Existing entries are **automatically enriched** with realm/guild data when players are encountered again.
* No breaking changes to existing SavedVariables.

### Stability
* Improved safety around cross*realm data handling.
* Hardened sync logic against malformed or unexpected messages.

***

## Version 3.0.7 (Retail Midnight Stability Update)

### 🚀 Retail (Patch 12.0 / Midnight)
* **Removed COMBAT_LOG_EVENT_UNFILTERED usage on Retail**
  * Prevents repeated forbidden*action errors and UI lockouts
  * Retail now uses unit*scoped and nameplate*based detection only
* **Nearby detection reworked for Retail**
  * Uses `NAME_PLATE_UNIT_ADDED`, target, and mouseover
  * Added **distance filtering** to prevent far*range nameplates from flooding Nearby
* **Enemy Nameplates requirement handling**
  * When enemy nameplates are disabled:
    * Nearby switches to a limited mode (target/mouseover only)
    * A **localized warning** is shown (includes “press V” shortcut)
  * Warning is shown **after sync messages** for better UX
* **Attackers list disabled on Retail**
  * Removed from UI and options
  * Prevents misleading or unverifiable attacker data without combat log access
* **Target frame fixes on Retail**
  * Restored correct Blizzard target frame appearance
  * Dragon indicators now overlay cleanly without altering frame art

### 🛡️ Notification & Zone Rules
* **Sanctuary zones now fully respected**
  * KoS and Guild notifications no longer fire in sanctuaries
* **Booty Bay & Gadgetzan suppression enforced everywhere**
  * Notification rules now apply consistently across all detection paths
* **Booty Bay / Gadgetzan option hidden on Retail**
  * Option remains available for Classic / TBC where applicable

### 🌍 Localization
* Added new locale key:
  * `RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF`
* Implemented across **all supported languages** with native translations
* Removed hardcoded English warnings

### 🎨 UI & Layout Improvements
* **Options UI width increased by 15%**
  * Improves readability for verbose locales (notably German)
* **Stealth Detection options spacing adjusted**
  * Moved ~6% further from KoS/Guild & Nearby sections for clarity
* Layout spacing preserved when Retail*only options are hidden

### 🔧 Stability & Compatibility
* Updated embedded libraries where required to avoid BugSack/BugGrabber dependency issues
* Ensured Retail changes do **not** affect:
  * Classic
  * TBC
  * Wrath
* No functional regressions on non*Retail clients

***

### Notes
Retail behavior intentionally differs from Classic*era clients due to Blizzard API changes in Patch 12.0. Nearby detection on Retail requires **enemy nameplates enabled** for full functionality.


## 3.0.6
### Fixed
* Deferred guild resolution (Spy*style): guild names now populate reliably for Nearby, Attackers, and Stats once the data becomes available (target/mouseover/nameplates)
* Attackers UI now refreshes automatically when guild info is enriched
* Fixed Nearby list click*to*target reliability, especially in battlegrounds (e.g. Alterac Valley).
  * Secure targeting attributes are now consistent and no longer desync during combat.
  * Clicking a player name now targets the correct unit reliably.

* Fixed KoS / Guild alert spam caused by repeated aura, combat log, and visibility updates.
  * KoS and Guild alerts (sound, screen flash, chat announce) now trigger **only once per player while they remain in the Nearby list**.
  * Alerts reset only after the player fully leaves the Nearby list and is seen again.
### Added
* Optional **Notes** column on the KoS tab
  * Clickable note icon per entry (dimmed when empty)
  * Mouseover shows full note text in a wrapped, scrollable tooltip
  * Click opens a small editor to create/edit/clear notes
  * Notes are stored as `reason` in SavedVariables (Spy imports show here automatically)

### Changed
* `/kos importspy` now refreshes the KoS list immediately
* `/kos importspy` prints a message even when no new entries are found

### Notes
* Notes are metadata only and do not change KoS/Guild detection

***

## 3.0.5
### Added
* Added **Spy KoS import support**
  * New slash command: `/kos importspy`
  * Imports Kill*on*Sight entries from Spy’s SavedVariables
  * Automatically skips entries already present in KillOnSight
  * Safe to disable Spy after import
* Imported metadata (such as Spy “reason”) is stored safely and ignored by core KoS logic

### Notes
* Spy must be enabled and loaded at least once before importing
* No changes to KillOnSight KoS/Guild detection or behavior

***

## 3.0.4
### Fixed
* NPC **rare, rare elite, elite, and world boss** targets now always display their dragon indicators
* Corrected client detection so Classic*era clients use proper target*frame handling
* Ensured Retail and Classic use appropriate visual paths without conflict

### Notes
* Player KoS and Guild behavior is unchanged
* This fix applies across Retail, Classic Era, TBC Anniversary, Wrath, and Titan*Reforged

***

## 3.0.3
### Added
* Full localization support for all major languages
* Shortened tooltip strings to prevent overflow on non*English clients
* Added TOC localization metadata

### Fixed
* Retail fallback handling for target frames
* Minor UI consistency issues across versions

***

## 3.0.2
### Fixed
* Cross*version targeting fallback logic
* Sanctuary zone handling for Nearby list
* Stability and performance improvements

***

## 3.0.1
### Added
* Retail target*frame support with safe fallbacks
* Improved stealth detection handling
* Performance optimizations and throttling improvements
