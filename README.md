# WTF Flutter Engineer Assessment

Two Flutter apps that work together locally: **Guru App** (Member) + **Trainer App**.

## Downloads

| Asset | Link |
|-------|------|
| Guru App (APK) | [Download](https://drive.google.com/file/d/1or0t2KgZm5T-oVUHpQ1nANK0xYhpJj0T/view?usp=sharing) |
| Trainer App (APK) | [Download](https://drive.google.com/file/d/1zappvv3jmTsnKAipWUHkFAFhICC6v_Pj/view?usp=sharing) |
| Demo Video (Guru / Trainer) | [Watch](https://drive.google.com/file/d/1dHcmZIz9SlR-QsJc29YNInYOP9wVD64g/view?usp=sharing) |

## Prerequisites

- Flutter 3.x
- Dart 3.x
- Node.js 18+ (for token server)
- Android emulator or real device

## Quick Start

### 1. Token Server

```bash
cd token_server
cp .env.example .env
# Fill in your 100ms APP_ACCESS_KEY and APP_SECRET
npm install
node index.js
# Runs on http://localhost:3000
```

### 2. Guru App

```bash
cd guru_app
flutter pub get
flutter run
```

### 3. Trainer App

```bash
cd trainer_app
flutter pub get
flutter run
```

> Run both apps simultaneously on separate emulators/devices for full cross-app experience.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for layer breakdown.

## ADRs

See [DECISIONS.md](DECISIONS.md) for architectural decision records.

## AI Usage

See [AI_LEDGER.md](AI_LEDGER.md) for all AI-assisted development entries.

## Test Credentials

| App | User | Role |
|---|---|---|
| Guru App | DK | member |
| Trainer App | Aarav | trainer |

## Project Structure

```
wtf_flutter_test/
├─ README.md
├─ AI_LEDGER.md
├─ ARCHITECTURE.md
├─ DECISIONS.md
├─ token_server/
├─ shared/
│  ├─ models/
│  ├─ services/
│  ├─ widgets/
│  └─ utils/
├─ guru_app/
└─ trainer_app/
```
