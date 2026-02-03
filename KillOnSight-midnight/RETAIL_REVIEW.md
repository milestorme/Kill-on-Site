# Retail (Midnight) Review

## Scope
Review of the `KillOnSight-midnight` retail-focused implementation with a focus on detection logic and event handling.

## Summary
Overall the retail-specific path shows careful handling of protected APIs and a strong effort to keep detection working without CLEU. The nameplate-driven detection pipeline and stealth inference are thoughtful. The main concern is a preemptive visibility state update in the nameplate removal path that prevents the stealth fallback from ever detecting a visible → hidden transition.

## Findings
### 1) Stealth inference on nameplate removal pre-sets visibility state (bug)
**Impact:** The stealth fallback logic can silently fail because the nameplate removal handler sets the visibility state to `false` before calling `CheckStealthTransition`. That means the fallback path never sees a `visiblePrev == true` → `visibleNow == false` transition, so it does not promote the hidden notification.

**Evidence:**
- `CheckStealthTransition` requires a `visiblePrev == true` and `visibleNow == false` transition to infer hidden state when `highConfidence` is set.【F:Detector.lua†L104-L134】
- `OnNameplateRemoved` sets `visibleStateByGUID[guid] = false` before calling `CheckStealthTransition`, so `visiblePrev` is already `false` by the time the check runs.【F:Detector.lua†L216-L233】

**Recommendation:** Defer the visibility update until after the transition check, or remove the preemptive `visibleStateByGUID[guid] = false` so the previous visibility state can be compared. If needed, move that assignment into `CheckStealthTransition` after the inference logic runs.

## Strengths
- Clear separation of retail vs classic behavior and defensive handling of protected APIs. (Core retail instance checks, nameplate-driven detection, and safe pcall usage.)【F:Core.lua†L1-L121】【F:Detector.lua†L75-L133】
- Robust notification throttling and optional stealth detection behavior with user-configurable toggles.【F:Detector.lua†L86-L135】【F:Detector.lua†L166-L178】

## Suggestions (non-blocking)
- Consider centralizing the nameplate scan ticker cleanup (e.g., stop on addon disable/logout) to avoid a permanent ticker in sessions where the Nearby feature is disabled. This is a minor performance improvement but not a functional issue in most cases.【F:Core.lua†L180-L188】【F:Core.lua†L829-L848】
