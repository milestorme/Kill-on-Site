# KillOnSight – Changelog

## 3.1.5
### Fixed
- Version string consistency across README, TOCs, and sync metadata.

## 3.1.4
### Added
- Added Nearby Name Font dropdown to the Options panel.
- Added Nearby Name Size slider to adjust player name text in the Nearby list.
	- Embedded LibSharedMedia-3.0 for expanded font support and automatic font detection.
- Added full localisation for:
	- Nearby name font
	- Nearby name size
	- across all supported game locales.

## 3.1.3
### Fixed
- Nearby list context menu now uses Blizzard dropdown initialization to avoid missing `EasyMenu` at runtime.

## 3.1.2
### Fixed
- Restored the debounced GUI refresh helper so modules can trigger UI updates safely.
- Ensured notify throttling cache entries are pruned periodically to avoid unbounded growth.

## 3.1.1
### Fixed
- Removed a global `EasyMenu` shim that conflicted with other addons.
- Fixed an issue where RestedXP Guide menus were duplicated or replaced by KillOnSight entries.
- Improved compatibility with addons that rely on Blizzard’s native dropdown menu handling.

## 3.1.0
**Release type:** Nearby List reliability & tooltip improvements  
**Primary focus:** Classic / TBC Anniversary

### Improved
- **Live Nearby List tooltip updates**
  - Tooltip now updates in real time while hovering, without requiring mouse movement.
- Improved handling of **players temporarily not targetable**.
  - Entries are marked only while genuinely not targetable.
  - Status clears immediately once the player becomes targetable again.
- Improved Nearby List targeting reliability on **TBC Anniversary**.

### Notes
- Changes are limited to Nearby List behavior and tooltips.
- No changes to detection logic, alerts, or Retail behavior.

## 3.0.9
**Release type:** Stability & targeting reliability update  
**Focus:** TBC Anniversary / Classic safety, Nearby List robustness

### Fixed
- Fixed multiple **Lua 5.1 compatibility issues** uncovered during hard structural audit.
- Removed invalid / unsafe constructs from `NearbyFrame.lua` that could cause load or runtime errors.
- Fixed tooltip update logic so **Nearby List tooltips refresh immediately while hovering** after click results (no re-hover required).
- Fixed rare syntax hazards caused by partial or duplicated `SetScript()` lines.
- Fixed targeting edge cases where entries could desync from their secure macro target.

### Improved
- **Greatly improved Nearby List targeting reliability on TBC Anniversary**:
  - Better handling of name normalization for Classic/TBC clients.
  - Safer post-click validation when targets are not attackable due to layering.
- Added robust handling for **layer/cache ghost players**:
  - Entries are temporarily suppressed when targeted but not attackable.
  - Tooltip clearly indicates “not targetable right now” without removing entries permanently.
- Tooltip logic is now fully centralized and refresh-safe.

### Audit & Maintenance
- Performed a **full hard parse-style audit** across all Lua files:
  - Verified correct `function / end` and `repeat / until` structure.
  - Verified XML validity.
  - Verified TOC metadata consistency.
- Unified addon versioning:
  - All TOC files updated to **3.0.9**
  - `Sync.lua` updated to `ADDON_VER = "3.0.9"`
- Confirmed no Retail-only regressions introduced.

### Notes
- This version establishes **3.0.9 as a clean, audited baseline** for future development.
- No gameplay logic or detection behavior was removed — changes are safety- and reliability-focused only.

---


## 3.0.8 (Classic / TBC Anniversary)

### Sync
- Reworked guild sync to be **safe and non-destructive**.
- Removed all reset and delete behavior — sync now **only merges additions and updates**.
- Restricted sync traffic to the **GUILD channel only**.
- Added clear chat feedback when a sync completes, including how many entries were merged or ignored.

### Data & Persistence
- KoS entries now persist **realm suffix** and **guild** when available.
- Existing entries are **automatically enriched** with realm/guild data when players are encountered again.
- No breaking changes to existing SavedVariables.

### Stability
- Improved safety around cross-realm data handling.
- Hardened sync logic against malformed or unexpected messages.

---

## Version 3.0.7 (Retail Midnight Stability Update)

### 🚀 Retail (Patch 12.0 / Midnight)
- **Removed COMBAT_LOG_EVENT_UNFILTERED usage on Retail**
  - Prevents repeated forbidden-action errors and UI lockouts
  - Retail now uses unit-scoped and nameplate-based detection only
- **Nearby detection reworked for Retail**
  - Uses `NAME_PLATE_UNIT_ADDED`, target, and mouseover
  - Added **distance filtering** to prevent far-range nameplates from flooding Nearby
- **Enemy Nameplates requirement handling**
  - When enemy nameplates are disabled:
    - Nearby switches to a limited mode (target/mouseover only)
    - A **localized warning** is shown (includes “press V” shortcut)
  - Warning is shown **after sync messages** for better UX
- **Attackers list disabled on Retail**
  - Removed from UI and options
  - Prevents misleading or unverifiable attacker data without combat log access
- **Target frame fixes on Retail**
  - Restored correct Blizzard target frame appearance
  - Dragon indicators now overlay cleanly without altering frame art

### 🛡️ Notification & Zone Rules
- **Sanctuary zones now fully respected**
  - KoS and Guild notifications no longer fire in sanctuaries
- **Booty Bay & Gadgetzan suppression enforced everywhere**
  - Notification rules now apply consistently across all detection paths
- **Booty Bay / Gadgetzan option hidden on Retail**
  - Option remains available for Classic / TBC where applicable

### 🌍 Localization
- Added new locale key:
  - `RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF`
- Implemented across **all supported languages** with native translations
- Removed hardcoded English warnings

### 🎨 UI & Layout Improvements
- **Options UI width increased by 15%**
  - Improves readability for verbose locales (notably German)
- **Stealth Detection options spacing adjusted**
  - Moved ~6% further from KoS/Guild & Nearby sections for clarity
- Layout spacing preserved when Retail-only options are hidden

### 🔧 Stability & Compatibility
- Updated embedded libraries where required to avoid BugSack/BugGrabber dependency issues
- Ensured Retail changes do **not** affect:
  - Classic
  - TBC
  - Wrath
- No functional regressions on non-Retail clients

---

### Notes
Retail behavior intentionally differs from Classic-era clients due to Blizzard API changes in Patch 12.0. Nearby detection on Retail requires **enemy nameplates enabled** for full functionality.


## 3.0.6
### Fixed
- Deferred guild resolution (Spy-style): guild names now populate reliably for Nearby, Attackers, and Stats once the data becomes available (target/mouseover/nameplates)
- Attackers UI now refreshes automatically when guild info is enriched
- Fixed Nearby list click-to-target reliability, especially in battlegrounds (e.g. Alterac Valley).
  - Secure targeting attributes are now consistent and no longer desync during combat.
  - Clicking a player name now targets the correct unit reliably.

- Fixed KoS / Guild alert spam caused by repeated aura, combat log, and visibility updates.
  - KoS and Guild alerts (sound, screen flash, chat announce) now trigger **only once per player while they remain in the Nearby list**.
  - Alerts reset only after the player fully leaves the Nearby list and is seen again.
### Added
- Optional **Notes** column on the KoS tab
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
- Added **Spy KoS import support**
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
- NPC **rare, rare elite, elite, and world boss** targets now always display their dragon indicators
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
