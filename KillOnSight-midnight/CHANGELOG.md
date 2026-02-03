# KillOnSight – Changelog

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
  **“secret values”** for unit names.
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
- **Disable Nearby detector on Retail**
  - Prevents repeated forbidden-action errors and UI lockouts
  - Portraits no lonher show on KoS targets in BG and stats no longer log in BG due to blizzard API changes
  
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

### 🛡️ Notification & Zone Rules
- **Sanctuary zones now fully respected**
  - KoS and Guild notifications no longer fire in sanctuaries

### 🌍 Localization
- Added new locale key:
  - `RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF`
- Implemented across **all supported languages** with native translations
- Removed hardcoded English warnings

### 🔧 Stability & Compatibility
- Updated embedded libraries where required to avoid BugSack/BugGrabber dependency issues

### 🧹 UI / Cleanup
- **Removed Stealth detection options from the UI**
  - Blizzard API changes in 12.0.x prevent reliable stealth detection
  - Stealth options are now fully hidden to avoid confusion

### ⚙️ Technical / Internal
- Removed reliance on deprecated or restricted combat log behavior
- Reduced unnecessary sorting and refresh work for better performance
- Improved Nearby list stability in combat-restricted environments  


### Notes
Retail behavior intentionally differs from Classic-era clients due to Blizzard API changes in Patch 12.0.X Nearby detection on Retail requires **enemy nameplates enabled** for full functionality.
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
