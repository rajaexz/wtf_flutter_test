# Architecture

Both apps follow Clean Architecture with three layers inside `lib/`:

```
lib/
├─ core/
│  ├─ constants/
│  │  ├─ app_strings.dart
│  │  └─ app_colors.dart
│  ├─ error/
│  │  └─ failures.dart
│  └─ utils/
│     ├─ extensions.dart
│     └─ validators.dart
├─ data/
│  ├─ datasources/     # Hive boxes, in-memory streams
│  ├─ models/          # Hive-adapted data models with fromJson/toJson
│  └─ repositories/    # Implementations of domain contracts
├─ domain/
│  ├─ entities/        # Pure Dart business objects
│  ├─ repositories/    # Abstract interfaces
│  └─ usecases/        # Single-responsibility use cases
├─ presentation/
│  ├─ providers/       # Riverpod providers (AsyncNotifier, StreamNotifier)
│  ├─ screens/         # Screen-level widgets
│  └─ widgets/         # Reusable UI components
└─ main.dart
```

## Layer Rules

- **Domain** has zero external dependencies. Entities are plain Dart classes.
- **Data** depends on Domain only. Models extend or implement entities.
- **Presentation** depends on Domain (via providers). Never imports Data directly.
- Riverpod providers sit in Presentation and call use cases or repositories.

## Real-time Strategy

Chat and call state are streamed via `StreamController.broadcast()` in the data layer. Both apps share the `shared/` Dart package for model contracts and service abstractions. In-memory streams simulate WebSocket behaviour for local development.

## 100ms Integration

```
Token Server (localhost:3000)
  GET /token?userId=<id>&role=<member|trainer>
  → returns { token: "..." }

App flow:
  1. Trainer approves call request
  2. App calls 100ms Management API to create/get room → saves hmsRoomId
  3. At join time, app fetches token from token server
  4. hmssdk_flutter joins room with token + role
  5. SDK events update call UI state via Riverpod
```

## Data Flow Diagram

```
User Action
    │
    ▼
Riverpod Provider (AsyncNotifier)
    │
    ▼
Use Case (domain/usecases/)
    │
    ▼
Repository Interface (domain/repositories/)
    │
    ▼
Repository Impl (data/repositories/)
    │
    ├─► Hive Box (persistence)
    └─► StreamController (real-time broadcast)
```
