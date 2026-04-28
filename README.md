# ⚡ CrisisSync — AI-Powered Hotel Emergency Response Platform

> **100% Flutter/Dart stack** — Guest Web App · Staff App · Dart Backend · Gemini 2.5 AI · Firebase Realtime DB · WebSocket broadcast

---

## 📌 Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   GUEST (scans QR code)                  │
│         Flutter Web App  →  http://localhost:5000         │
│   Landing → verify token → Chat → SOS / AI message       │
└────────────────────┬─────────────────────────────────────┘
                     │ POST /guest/message
                     ▼
┌──────────────────────────────────────────────────────────┐
│              DART BACKEND  :8080  (shelf)                 │
│  /auth   /incidents   /guest   /mock   ws://…/ws         │
│  Gemini 2.5 Flash · Firebase REST · 3-tier Escalation    │
└───────┬──────────────────────────┬───────────────────────┘
        │ Firebase RTDB            │ WebSocket broadcast
        ▼                          ▼
┌───────────────┐        ┌──────────────────────────────────┐
│  Firebase DB  │        │   STAFF APP  :4000  (Flutter)    │
│  (incidents,  │        │   Real-time alerts · Map ·       │
│   users, org) │        │   Alerts list · Auth             │
└───────────────┘        └──────────────────────────────────┘
```

---

## 📁 Project Structure

```
CrisisSync/
├── backend_dart/          ← Dart backend (shelf server)
│   ├── bin/server.dart    ← Entry point (port 8080)
│   ├── lib/
│   │   ├── config.dart
│   │   ├── firebase_service.dart
│   │   ├── gemini_service.dart      ← Gemini 2.5 Flash
│   │   ├── websocket_service.dart
│   │   ├── escalation_service.dart  ← 3-tier logic
│   │   └── handlers/
│   │       ├── auth_handler.dart
│   │       ├── incidents_handler.dart
│   │       ├── guest_handler.dart
│   │       └── mock_handler.dart
│   ├── pubspec.yaml
│   └── .env               ← secrets (not in git)
│
├── staff_app_flutter/     ← Staff Flutter Web/Mobile App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart     ← Live incident dashboard
│   │   │   ├── alerts_screen.dart   ← Incident list + actions
│   │   │   ├── map_screen.dart      ← OpenStreetMap + zones
│   │   │   └── auth/                ← Login / Register screens
│   │   ├── services/auth_service.dart
│   │   ├── theme/app_theme.dart
│   │   └── navigation/bottom_nav.dart
│   └── pubspec.yaml
│
└── guest_app_flutter/     ← Guest Web App (opens via QR)
    ├── lib/
    │   ├── main.dart
    │   └── screens/
    │       ├── landing_screen.dart  ← QR token validation
    │       ├── chat_screen.dart     ← AI chat + SOS button
    │       └── expired_screen.dart ← 15-min session expired
    └── pubspec.yaml
```

---

## 🔑 Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | 3.10+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | 3.2+ | bundled with Flutter |
| Chrome | any | for web target |
| Firebase project | — | [console.firebase.google.com](https://console.firebase.google.com) |
| Gemini API key | — | [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey) |

---

## ⚙️ Setup

### 1. Clone the repo

```bash
git clone https://github.com/KoushikKShetty/CrisisSync.git
cd CrisisSync
```

### 2. Configure environment

Create `backend_dart/.env` (copy the template below):

```env
PORT=8080
NODE_ENV=development

FIREBASE_PROJECT_ID="your-project-id"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_DATABASE_URL=https://your-project-default-rtdb.firebaseio.com/

GEMINI_API_KEY="your-gemini-api-key"

JWT_SECRET="your-random-secret-32-chars"
QR_PROPERTY_SECRET="your-property-secret-key"
```

> **Firebase**: In Firebase Console → Project Settings → Service Accounts → Generate new private key  
> **Gemini**: [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey) — `gemini-2.5-flash` is the recommended model

### 3. Install dependencies

```bash
# Dart backend
cd backend_dart && dart pub get && cd ..

# Staff app
cd staff_app_flutter && flutter pub get && cd ..

# Guest app
cd guest_app_flutter && flutter pub get && cd ..
```

---

## 🚀 Running the System

Open **3 terminals** and run one command in each:

### Terminal 1 — Dart Backend
```bash
cd backend_dart
dart run bin/server.dart
```
Expected output:
```
🔥 Firebase REST initialized — project: your-project-id
✦  Gemini AI initialized
🚀 CrisisSync Dart Backend running on http://0.0.0.0:8080
   Health: http://localhost:8080/health
   WebSocket: ws://localhost:8080/ws
```

### Terminal 2 — Staff App (Flutter Web)
```bash
cd staff_app_flutter
flutter run -d chrome --web-port 4000
```
Opens Staff Dashboard at → **http://localhost:4000**

### Terminal 3 — Guest App (Flutter Web)
```bash
cd guest_app_flutter
flutter run -d chrome --web-port 5000
```
Guest portal at → **http://localhost:5000** (opened via QR token URL)

---

## 🔗 API Endpoints

### Health
| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Server status + WebSocket client count |

### Auth
| Method | Endpoint | Description |
|---|---|---|
| POST | `/auth/org/register` | Register a new hotel organization |
| POST | `/auth/org/login` | Admin login |
| GET | `/auth/staff/lookup-org?code=XXXX` | Look up org by 6-char code |
| POST | `/auth/staff/register` | Staff member registration |
| POST | `/auth/staff/login` | Staff login |
| POST | `/auth/start-shift` | Start duty shift |
| POST | `/auth/end-shift` | End duty shift |

### Incidents
| Method | Endpoint | Description |
|---|---|---|
| GET | `/incidents` | List all incidents |
| POST | `/incidents` | Create incident |
| POST | `/incidents/:id/accept` | Accept/claim incident |
| POST | `/incidents/:id/resolve` | Resolve incident |
| POST | `/incidents/:id/false-alarm` | Mark false alarm |

### Guest Portal
| Method | Endpoint | Description |
|---|---|---|
| GET | `/guest/scan/:zoneId` | QR redirect → Guest App |
| POST | `/guest/generate-qr` | Generate QR token for a zone |
| POST | `/guest/verify-token` | Validate QR token → session |
| POST | `/guest/verify-location` | GPS proximity check |
| POST | `/guest/message` | Send AI-classified guest message |

### Mock / Demo
| Method | Endpoint | Description |
|---|---|---|
| POST | `/mock/hardware-event` | Simulate a sensor trigger |
| GET | `/mock/report/:id` | Generate incident report |

---

## 🎮 Demo Flow

### 1. Register your organization
```bash
curl -X POST http://localhost:8080/auth/org/register \
  -H "Content-Type: application/json" \
  -d '{
    "orgName": "Grand Thalassa Hotel",
    "location": "Bangalore, India",
    "contactEmail": "admin@thalassa.com",
    "password": "Admin@1234",
    "adminName": "Hotel Admin"
  }'
# → Returns: orgCode (6-char), token
```

### 2. Staff login via app
Open **http://localhost:4000** → Select **Staff Member** → Enter org code → Login

### 3. Generate a guest QR code
```bash
curl -X POST http://localhost:8080/guest/generate-qr \
  -H "Content-Type: application/json" \
  -d '{
    "zoneId": "lobby",
    "zoneName": "Grand Lobby",
    "propertyKey": "your-QR_PROPERTY_SECRET"
  }'
# → Returns: guestUrl (paste in browser or embed in QR code)
```

### 4. Open Guest Portal
Navigate to the `guestUrl` → **http://localhost:5000/?token=JWT&zone=Grand+Lobby**

### 5. Guest sends an emergency message
Type in the chat: _"There's a fire in the lobby!"_
- Gemini 2.5 classifies as **CRITICAL**
- Escalates to **First Responders** (🚒 Fire Dept + 🚑 Ambulance)
- Incident saved to Firebase
- Staff App receives **real-time WebSocket alert**

### 6. Simulate hardware sensor (demo mode)
```bash
curl -X POST http://localhost:8080/mock/hardware-event \
  -H "Content-Type: application/json" \
  -d '{
    "sensorId": "SMK-402",
    "zone": "Kitchen Alpha",
    "zoneId": "kitchen-alpha",
    "type": "fire",
    "confidence": 0.95
  }'
# → 95% confidence → FIRST_RESPONDERS tier
# → Staff app shows CRITICAL red card + Gemini action plan
```

---

## 🔒 Security Features

| Layer | Feature |
|---|---|
| 1 | JWT-signed QR tokens (15-min TTL, single-use nonce) |
| 2 | Per-session rate limiting (5 msg / 10 min) |
| 3 | GPS proximity verification |
| 4 | Spam/abuse scoring + auto-blacklist |
| 5 | Session isolation (each scan = new session) |
| 6 | JWT-signed staff sessions (7-day TTL) |

---

## 🤖 AI — Gemini 2.5 Flash

- **Incident Classification** — severity (`critical` / `warning` / `info`) + category + confidence score
- **Emergency Protocol** — step-by-step action plan for responders
- **Guest Q&A** — answers general hotel questions
- **3-Tier Escalation**:
  - `info` → only BLE-zone nearby staff
  - `warning` → all on-shift staff
  - `critical` (≥80% confidence) → first responders called automatically

---

## 📱 Running on Android / iOS

For staff app on physical device:
1. Find your local IP: `ipconfig getifaddr en0` (Mac)
2. Update `_baseUrl` in `staff_app_flutter/lib/services/auth_service.dart` and `home_screen.dart`:
   ```dart
   static const String _baseUrl = 'http://192.168.x.x:8080';
   ```
3. Run: `flutter run` (connects to USB device)

For guest app, host the Flutter Web build on a public URL and update `GUEST_APP_URL` in `.env`.

---

## 🤝 Contributing

Built for hackathon demonstration. PRs welcome!

---

## 📄 License

MIT © 2025 KoushikKShetty
