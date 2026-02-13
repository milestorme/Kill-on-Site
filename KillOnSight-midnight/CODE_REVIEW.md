# Code Review — `KillOnSight-midnight`

## Scope
Manual review of the Retail Midnight addon implementation, with emphasis on sync safety, data integrity, and operational reliability.

## Findings

### 1) Unauthenticated `RESET` can wipe local KoS/Guild data (High)
**Where:** `Sync.lua`, `OnMessage()` handling for `RESET`.

The addon accepts any incoming `RESET` command on the registered addon prefix and immediately clears local `players` and `guilds` tables, without correlating to a user-initiated sync request or validating sender trust state.

**Impact:** A forged or accidental `RESET` packet can erase local state before a valid snapshot arrives.

**Recommendation:**
- Gate `RESET` acceptance behind an active sync session token (request/response correlation).
- Require sender to match the peer selected for current sync exchange.
- Add timeout + rollback behavior if snapshot completion (`END`) is not observed.

---

### 2) Self-message filtering likely fails on modern sender formats (Medium)
**Where:** `Sync.lua`, `OnMessage()` sender check.

Self-filter logic compares `sender` against `UnitName("player")`. Modern addon sender values are often full names (`Name-Realm`), while `UnitName("player")` is usually short name only.

**Impact:** The addon may process its own sync traffic, causing unnecessary apply work and potential duplicate processing behavior.

**Recommendation:** Compare against normalized full player identity (e.g., `UnitFullName("player")` + realm normalization), or use robust ambiguity normalization before equality checks.

---

### 3) Sync control packets are processed without channel/session validation (Medium)
**Where:** `Sync.lua`, `OnMessage()` command dispatch for `HELLO/REQ/RESET/D/DL/END`.

Incoming packets are accepted solely by prefix and sender string. There is no check that messages arrive on expected channels (`GUILD/PARTY/RAID/INSTANCE_CHAT`) for the active sync context, nor that packet order is tied to an active session.

**Impact:** Increased exposure to malformed/fake packet sequences and state desynchronization.

**Recommendation:**
- Validate `channel` against allowed channels and current sync mode.
- Track a per-sync state machine (`idle -> requested -> receiving -> complete`).
- Reject out-of-order control packets (`END` before payload, unsolicited `RESET`, etc.).

---

### 4) Installation/docs path consistency risk for assets (Low)
**Where:** `README.md`, `KillOnSight.toc`, and `Midnight_Init.lua`.

The README says folder should be `KillOnSight_Midnight`, while TOC icon path and runtime addon folder constant reference `KillOnSight`.

**Impact:** Depending on packaging/folder naming, icon/sound/media references may break or confuse installers.

**Recommendation:** Use one canonical addon folder name across README, TOC asset paths, and runtime constants.

## Positive notes
- Sync includes size/cap safeguards (`MAX_DIFF_CHANGES`, `MAX_DIFF_BYTES`) and snapshot fallback, which is a solid reliability baseline.
- Database profile/default migration logic is extensive and generally defensive for backward compatibility.
