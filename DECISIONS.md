# Architectural Decision Records

## ADR #1 — State Management: Riverpod

**Status:** Accepted

**Context:** The project needs reactive state across multiple screens with async data (chat, call requests, session logs). Options: Provider, Bloc, Riverpod.

**Decision:** Riverpod (v2 with code generation) because it offers compile-safe providers, no BuildContext dependency for business logic, and native async/stream support that maps cleanly to real-time chat and call flows.

**Consequences:** Slightly steeper learning curve than Provider. Code generation adds a build step. The upside is testability — providers can be overridden in tests without mocking the widget tree.

---

## ADR #2 — Local Storage: Hive

**Status:** Accepted

**Context:** Needs local persistence for messages, call requests, session logs, and user profiles without a backend.

**Decision:** Hive because it is pure Dart, no native setup beyond initialization, fast enough for the data volumes expected, and straightforward to type-adapt with code generation.

**Consequences:** Not SQL — no ad-hoc queries. Workaround: keep typed boxes per entity and filter in Dart. Acceptable for the feature set.

---

## ADR #3 — RTC Strategy: 100ms SDK (hmssdk_flutter)

**Status:** Accepted

**Context:** Mandatory per assessment brief.

**Decision:** Use `hmssdk_flutter` with a local Node.js token server. On call approval, a room is created via 100ms Management API. Members and trainers join with role-specific tokens fetched from the token server. Roles enforce permissions: trainer can end room, member cannot.

**Consequences:** Requires a running token server locally. Token expiry handled via re-fetch before join. SDK events drive call state (peer join/leave, track mute/unmute). If 100ms API is unavailable, app falls back to a mock room with a clear in-app notice.
