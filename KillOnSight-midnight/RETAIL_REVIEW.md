# Retail (Midnight) Review

## Scope
Review of the `KillOnSight-midnight` retail-focused implementation with a focus on detection logic and event handling.

## Summary
Overall the retail-specific path shows careful handling of protected APIs and a strong effort to keep detection working without CLEU. The nameplate-driven detection pipeline and stealth inference are thoughtful. The main concern is a parameter mismatch in the stealth fallback path that likely prevents stealth notifications from triggering when a nameplate disappears.

## Findings
### 1) Stealth inference on nameplate removal passes the wrong parameters (bug)
**Impact:** The stealth fallback logic can silently fail because `CheckStealthTransition` is called with a GUID string in place of a unit token and missing expected parameters. This means `UnitHasStealthAura` / `UnitIsVisible` are invoked on a GUID instead of a unit, so the transition check can never succeed.

**Evidence:**
- `CheckStealthTransition` expects `(unit, name, classFile, guild, guid, highConfidence)` and uses the `unit` token for `UnitHasStealthAura`/`UnitIsVisible`.【F:Detector.lua†L86-L133】
- `OnNameplateRemoved` calls `CheckStealthTransition(guid, name, true, "NameplateRemoved")`, which passes the GUID as the unit token and does not pass the expected `guid`/`highConfidence` parameters.【F:Detector.lua†L196-L234】

**Recommendation:** Change the call to pass the unit token and GUID explicitly, e.g.:
```lua
CheckStealthTransition(unit, name, nil, nil, guid, true)
```
If class/guild values are available for nameplates, supply them as well.

## Strengths
- Clear separation of retail vs classic behavior and defensive handling of protected APIs. (Core retail instance checks, nameplate-driven detection, and safe pcall usage.)【F:Core.lua†L1-L121】【F:Detector.lua†L75-L133】
- Robust notification throttling and optional stealth detection behavior with user-configurable toggles.【F:Detector.lua†L86-L135】【F:Detector.lua†L166-L178】

## Suggestions (non-blocking)
- Consider centralizing the nameplate scan ticker cleanup (e.g., stop on addon disable/logout) to avoid a permanent ticker in sessions where the Nearby feature is disabled. This is a minor performance improvement but not a functional issue in most cases.【F:Core.lua†L180-L188】【F:Core.lua†L829-L848】
