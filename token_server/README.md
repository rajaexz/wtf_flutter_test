# Token Server

Minimal HTTP server for 100ms auth tokens + room create + optional FCM push.

## Downloads

| Asset | Link |
|-------|------|
| Guru App (APK) | [Download](https://drive.google.com/file/d/1or0t2KgZm5T-oVUHpQ1nANK0xYhpJj0T/view?usp=sharing) |
| Trainer App (APK) | [Download](https://drive.google.com/file/d/1zappvv3jmTsnKAipWUHkFAFhICC6v_Pj/view?usp=sharing) |
| Demo Video (Guru / Trainer) | [Watch](https://drive.google.com/file/d/1dHcmZIz9SlR-QsJc29YNInYOP9wVD64g/view?usp=sharing) |

## Setup (100ms — required for live video)

1. Sign up at https://dashboard.100ms.live
2. Create a Dev workspace/project with a template that has **host** + **guest** roles (default)
3. Copy **App Access Key** + **App Secret** from Developer settings

```bash
cp .env.example .env
# Edit .env — set real APP_ACCESS_KEY and APP_SECRET
npm install
npm start
```

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Creds + role map status |
| POST | `/rooms` | Create/get 100ms room `{ "callRequestId": "..." }` |
| GET | `/token?userId=&role=&callRequestId=` | Client auth token for SDK join |
| POST | `/fcm-token` | Register device FCM token |
| POST | `/notify` | Push via FCM (needs `FCM_SERVER_KEY`) |

**Token example:**
```
GET http://localhost:3000/token?userId=member_dk&role=member&callRequestId=<id>
```

```json
{ "token": "eyJ...", "roomId": "...", "role": "guest", "mock": false }
```

## Role mapping

App roles map to 100ms template roles (defaults):

| App role | 100ms role |
|----------|------------|
| trainer | host |
| member | guest |

Override with `HMS_ROLE_TRAINER` / `HMS_ROLE_MEMBER` in `.env` if your template uses custom names.

## Firebase push

This server uses **Firebase Admin SDK** (FCM HTTP v1), not the old legacy Server Key.

1. Firebase Console → Project settings → **Service accounts** → **Generate new private key**
2. Save the JSON as `token_server/firebase-adminsdk.json` (gitignored)
3. Or set `FIREBASE_SERVICE_ACCOUNT=./path/to/file.json` in `.env`
4. `npm start` — `/health` should show `"firebaseReady": true`

Apps register device tokens via `POST /fcm-token`. Remote push uses `POST /notify`.

Local call reminders in the Flutter apps still work without this.
## Chat sync (member ↔ trainer)

Realtime chat uses **Socket.IO** on this server (send / receive / typing / read / presence).
REST endpoints remain for history sync and offline fallback:

```
Socket.IO  message:send | message:new | message:read | typing:* | presence:*
POST /chat/messages
GET  /chat/messages?chatId=<id>
POST /chat/read
```

Keep the token server running while testing chat on two emulators.

## TEMPLATE_ID (100ms only — not for chat)

`TEMPLATE_ID` is optional and used only when creating **100ms video rooms**.

1. Open https://dashboard.100ms.live
2. Templates → open your template → copy **Template ID**
3. Put it in `.env` as `TEMPLATE_ID=...`

If empty, 100ms uses the workspace **default** template (usually `host` + `guest`).
