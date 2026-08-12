# AI Ledger

All AI-assisted development entries for this assessment.

---

## #1 — Scaffold Clean Architecture folder structure

**Tool:** Cursor AI (Auto)  
**Intent:** Generate the complete folder hierarchy for both Flutter apps following Clean Architecture with Riverpod.  
**Output:** Full directory tree with layer descriptions used in ARCHITECTURE.md and both apps.  
**Commit:** `feat: scaffold clean architecture structure for guru_app and trainer_app`

---

## #2 — Generate Hive TypeAdapters for data models

**Tool:** Cursor AI (Auto)  
**Intent:** Create Hive-compatible model classes with `@HiveType` and `@HiveField` annotations for User, Message, CallRequest, SessionLog, RoomMeta.  
**Output:** All model files in `data/models/` with adapter registration code in `main.dart`.  
**Commit:** `feat: add hive models with type adapters for all entities`

---

## #3 — Implement Riverpod AsyncNotifier for chat

**Tool:** Cursor AI (Auto)  
**Intent:** Generate a `ChatNotifier extends AsyncNotifier<List<Message>>` that exposes send, markRead, and stream subscription.  
**Output:** `presentation/providers/chat_provider.dart` in both apps.  
**Commit:** `feat: add chat provider with stream subscription and read receipt logic`

---

## #4 — Debugging: Hive box not open error

**Tool:** Cursor AI (Auto)  
**Intent:** Fix `HiveError: Box not found. Did you forget to call Hive.openBox()?` on cold start.  
**Error pasted:** `HiveError: Box 'messages' is not open.`  
**AI Steps:** Ensure all boxes are opened sequentially in `main()` before `runApp()`, wrap with try/catch, add box existence check.  
**Fix applied:** Moved all `Hive.openBox` calls into a `_initHive()` function awaited before `runApp`.  
**Commit:** `fix: ensure hive boxes opened before runapp on cold start`

---

## #5 — Generate 100ms token server

**Tool:** Cursor AI (Auto)  
**Intent:** Create a minimal Node.js HTTP server that generates 100ms auth tokens using APP_ACCESS_KEY and APP_SECRET.  
**Output:** `token_server/index.js` with JWT signing using 100ms algorithm spec.  
**Commit:** `feat: add nodejs token server for 100ms auth`

---

## #6 — Implement scheduler conflict detection

**Tool:** Cursor AI (Auto)  
**Intent:** Write a use case that checks if a requested time slot already has an approved CallRequest for the same trainer, and returns a typed Failure if so.  
**Output:** `domain/usecases/request_call_usecase.dart` with conflict check logic.  
**Commit:** `feat: add conflict detection in call request use case`

---

## #7 — Refactor: chat bubble widget

**Tool:** Cursor AI (Auto)  
**Intent:** Refactor inline bubble code into a reusable `ChatBubble` widget with role-based color, status ticks, and timestamp.  
**Before:** 80-line inline Container in ConversationScreen.  
**After:** Extracted `ChatBubble` widget with clean props interface.  
**Commit:** `refactor: extract chat bubble into reusable widget`

---

## #8 — Generate unit tests for scheduler validation

**Tool:** Cursor AI (Auto)  
**Intent:** Generate unit tests for past-time validation, conflict detection, and duration calculation.  
**Output:** `test/scheduler_validation_test.dart` and `test/session_duration_test.dart`.  
**Commit:** `test: add unit tests for scheduler validation and session duration`

---

## #9 — Debugging: 100ms SDK join failure on Android

**Tool:** Cursor AI (Auto)  
**Intent:** Fix `PlatformException: CAMERA_ERROR` when joining 100ms room without camera permission.  
**Error:** `PlatformException(CAMERA_ERROR, Camera permission not granted, null, null)`  
**AI Steps:** Add `permission_handler` package, request CAMERA and MICROPHONE before calling `hmsSDK.join()`, handle denied state with user-facing snackbar.  
**Commit:** `fix: request camera and mic permissions before 100ms join`

---

## #10 — Generate DevPanel overlay

**Tool:** Cursor AI (Auto)  
**Intent:** Create a floating debug panel showing env vars (masked), build info, and last 20 structured logs.  
**Output:** `presentation/widgets/dev_panel_overlay.dart` with a draggable FAB trigger.  
**Commit:** `feat: add dev panel overlay with structured log viewer`

---

## #11 — Implement typing indicator simulation

**Tool:** Cursor AI (Auto)  
**Intent:** Simulate a typing indicator on message send with 400–800ms random delay before "response" appears and the indicator dismisses.  
**Output:** Logic in `ChatNotifier` using `Future.delayed` with random duration + `isTyping` state flag in provider.  
**Commit:** `feat: add simulated typing indicator in chat provider`

---

## #12 — Generate message serialization tests

**Tool:** Cursor AI (Auto)  
**Intent:** Write tests that serialize a `Message` to JSON and back, verifying all fields round-trip correctly.  
**Output:** `test/message_serialization_test.dart`.  
**Commit:** `test: add message serialization round-trip tests`
