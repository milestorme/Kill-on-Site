# KillOnSight Module Review

This document reviews every runtime module listed in the `KillOnSight-*.toc` files for the `KillOnSight` addon folder.

## Architecture at a glance

- `Core.lua` is the orchestrator: slash commands, event wiring, encounter lifecycle, and module initialization.
- `Database.lua` is the source of truth for profile settings, tracked players/guilds, stats, and sync changelog.
- `Detector.lua` + `Core.lua` combat log handlers generate enemy sightings and notify downstream systems.
- `Notifier.lua`, `NearbyFrame.lua`, `GUI.lua`, `Minimap.lua`, and `Portrait.lua` implement user-facing UI/alerts.
- `Sync.lua` handles guild-channel synchronization of KoS/Guild data.
- `SpyImport.lua` imports Spy's KoS list.
- `Util.lua` and `Activity.lua` are light helper modules.

---

## 1) `Database.lua`

### Responsibility
Primary persistence and state layer:
- profile defaults + per-realm/faction scoping
- tracked players/guilds CRUD
- revisioned change log for sync
- attacker list and enemy stats storage
- pruning helpers for changelog and stats growth

### Public surface (major methods)
- Init/profile/data: `Init`, `GetProfile`, `GetData`
- list management: `AddPlayer`, `RemovePlayer`, `AddGuild`, `RemoveGuild`, `Lookup*`, `Has*`
- metadata: `SetPlayerClass`, `SetPlayerReason`, `MarkSeen*`
- stats: `NoteEnemySeen`, `StatsAddSeenEncounter`, `StatsAddWin`, `StatsAddLoss`, `PruneStatsPlayers`, `ClearStatsPlayers`
- sync integration: `ApplyRemoteChange`, changelog helpers
- attackers: `AddLastAttacker`, `UpdateLastAttackerGuild*`, `GetLastAttackers`, `ClearLastAttackers`

### Review notes
- Strong centralization: almost all persistent logic is cleanly contained here.
- Changelog and stats both include explicit pruning knobs, which is important for SavedVariables size control.
- Class normalization handles localized class names, reducing locale-specific data corruption risk.
- Risk: the file is large and multi-concern; long-term maintainability would benefit from splitting into smaller submodules (profile/lists/stats/sync journal).

---

## 2) `Util.lua`

### Responsibility
Small shared helper module.

### Public surface
- `AppendTags(nameText, isKoS, isGuild)`

### Review notes
- Minimal and focused.
- Correctly localizes tag text with safe fallback strings.
- Could remain as-is; very low complexity.

---

## 3) `Notifier.lua`

### Responsibility
All user-facing notifications:
- chat output
- warning frame/center text
- flash effects
- sounds
- stealth-specific warnings
- context suppression (sanctuary / goblin towns)

### Public surface (major)
- `NotifyPlayer`, `NotifyGuild`, `NotifyHidden`, `NotifyActivity`
- `Chat`, `Sound`, `Flash`, `CenterWarning`
- stealth config methods (`ApplyStealthSettings`, `GetStealthTiming`, etc.)

### Review notes
- Good defensive design: lazy DB access avoids init-order failures.
- Includes anti-spam and context suppression logic that is crucial in crowded zones.
- Risk: many UI side effects in one file can make regressions harder to isolate; consider optional extraction of stealth-warning rendering into a dedicated helper.

---

## 4) `NearbyFrame.lua`

### Responsibility
Live “nearby enemy” window:
- collection and rendering of detected enemies
- row formatting/icons/timers/fades
- frame layout, scaling, lock/move state
- auto-width and minimal-mode behavior
- contextual suppression support

### Public surface (major)
- lifecycle/UI: `Create`, `Init`, `Refresh`, `ScheduleRefresh`
- input/state: `Seen`, `ClearAll`, `SetLocked`, `SetShown`, `SetMinimized`
- layout: `ApplyPosition`, `SavePosition`, width/height/fade controls

### Review notes
- Feature-rich and well-covered functionally.
- Includes careful UX details (tooltip ticker management, dynamic sizing, throttled layout updates).
- Highest complexity module in the addon; likely the first candidate for maintainability refactor (e.g., split row rendering, sizing logic, and suppression logic into subtables/files).

---

## 5) `Detector.lua`

### Responsibility
Unit-based detection path (target/mouseover/nameplate driven checks):
- validates context
- determines if notifications should fire
- forwards sightings to DB/Notifier/Core/Nearby

### Public surface
- `CheckUnit(unit)`

### Review notes
- Compact and purpose-specific.
- Good coupling pattern: delegates UI and state operations to dedicated modules.
- Uses throttling/cache cleanup to avoid spam and stale cache growth.

---

## 6) `Activity.lua`

### Responsibility
Combat-log activity hook container.

### Public surface
- `OnCombatLog()`

### Review notes
- Extremely thin module currently.
- If this remains intentionally lightweight, that is fine; otherwise it may be an opportunity to either expand with clear ownership or fold into `Core.lua` to reduce indirection.

---

## 7) `Sync.lua`

### Responsibility
KoS/Guild sync transport and protocol handling:
- message serialization/deserialization
- HELLO/DIFF/SNAPSHOT style exchange
- chunking payloads across addon messages
- application of remote changes through DB

### Public surface (major)
- `Init`, `Hello`, `RequestDiff`, `OnMessage`

### Review notes
- Protocol workflow is clear and separated into parsing/build helpers.
- Bounded diff support plus fallback snapshot logic is a solid design for eventual consistency.
- Consider adding protocol-version constants in one explicit block to simplify future compatibility updates.

---

## 8) `GUI.lua`

### Responsibility
Main addon options and management UI:
- tabs (players, guilds, attackers, stats, settings)
- list rendering/sorting
- note tooltip/editor
- settings controls and refresh orchestration

### Public surface
- `Create`, `RefreshAll`, `Show`, `Hide`, `Toggle`

### Review notes
- Functional breadth is high and appears to cover key workflows.
- Many helper constructors and builders indicate decent internal structure despite file size.
- Similar to `NearbyFrame.lua`, this is a strong candidate for decomposition by tab/feature to simplify maintenance and testing.

---

## 9) `Minimap.lua`

### Responsibility
LibDataBroker / minimap icon integration.

### Public surface
- `Create()`

### Review notes
- Focused and concise.
- Good place to keep interaction affordances lightweight.

---

## 10) `Portrait.lua`

### Responsibility
Target frame portrait border highlighting for KoS/Guild-KoS targets.

### Public surface
- Update pipeline internal; module exports frame object for event-driven updates.

### Review notes
- Clear single-purpose visual enhancement.
- Defensive texture handling (`EnsureOriginal`, mode checks) is good for compatibility.

---

## 11) `SpyImport.lua`

### Responsibility
Import Spy SavedVariables (`SpyPerCharDB.KOSData`) into KillOnSight player list.

### Public surface
- `ImportPerCharacter`, `Run`

### Review notes
- Clear operator feedback (imported/skipped counts).
- Safe behavior (skips duplicates, optional class/reason enrichment) is appropriate.

---

## 12) `Core.lua`

### Responsibility
Application coordinator:
- module lookups and lifecycle startup
- slash command handling
- combat log processing and encounter tracking
- deferred guild resolution
- GUI refresh scheduling
- bridges Detector/Nearby/Notifier/DB/Sync

### Public surface (major)
- exported frame methods include encounter touch and refresh hooks; slash command entry points are local helpers

### Review notes
- Acts as intended “brain” module.
- Encounter model (touch/resolve/timeout) is a good anti-spam abstraction for stats integrity.
- Risk: at current size, Core contains multiple responsibilities (CLI, CL parser, cache management, encounter logic). Future cleanup could move slash-command handlers and combat-log parser into dedicated files.

---

## Cross-module findings

### Strengths
- Clear module ownership at a high level (DB vs detection vs UI vs sync).
- Extensive safety checks around init order and optional dependencies.
- Attention to performance and SavedVariables growth via throttling and pruning.

### Refactor priorities (if planning next iteration)
1. Split very large UI modules (`GUI.lua`, `NearbyFrame.lua`) into feature-focused files.
2. Extract `Core.lua` combat-log parser and slash command handler into dedicated modules.
3. Optionally split `Database.lua` into `db_profile`, `db_lists`, `db_stats`, and `db_syncjournal` concerns.

### Validation checklist after future refactors
- `/kos` command parity (all existing commands still work)
- detection + notification throttling behavior remains unchanged
- sync diff/snapshot still converges between guild members
- stats counters (seen/win/loss) preserve previous semantics
- nearby frame layout persistence survives reload/login
