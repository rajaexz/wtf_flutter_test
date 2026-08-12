# Token Server

Minimal HTTP server for 100ms auth tokens.

## Setup

```bash
cp .env.example .env
# Edit .env and add your 100ms credentials
npm install
npm start
```

## Usage

```
GET http://localhost:3000/token?userId=<id>&role=<trainer|member>
```

**Response:**
```json
{ "token": "eyJ..." }
```

## Roles

| Role | Can mute self | Can end room | Can mute others |
|------|--------------|--------------|-----------------|
| trainer | yes | yes | no (SDK limitation) |
| member | yes | no | no |

## Without Credentials

If `APP_ACCESS_KEY` / `APP_SECRET` are not set, the server returns a mock token.  
The app will fall back gracefully and show a notice in DevPanel logs.

## Getting 100ms Credentials

1. Sign up at https://dashboard.100ms.live
2. Create a workspace → Dev project
3. Copy `APP_ACCESS_KEY` and `APP_SECRET` from Settings → Developer
