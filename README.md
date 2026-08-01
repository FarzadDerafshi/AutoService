# AutoService — Auto Repair Shop Management System

A multi-tenant shop-management app: clients, vehicles, a service/parts catalog,
work orders (repair slips) with PDF printing, and basic revenue/parts reporting.

**Stack:** Flutter (Web + Mobile + PWA) · Node.js/TypeScript (Express) · PostgreSQL · Docker Compose

**Features:** English / Turkish language switching · Corporate/Garage voice toggle (two full copy sets per language) · Installable as a PWA on any device · LAN access from any browser

See [`SETUP.md`](./SETUP.md) for a full step-by-step guide to installing prerequisites and
running the project locally in VS Code.

## Project layout

```
AutoService/
├── docker-compose.yml     # postgres + api + (optional) nginx web
├── .env.example            # copy to .env and fill in secrets
├── db/init/                 # SQL schema, run automatically on first Postgres boot
├── backend/                 # Node.js + Express + TypeScript REST API
├── frontend/                 # Flutter app (web + mobile)
└── nginx/                     # static-file/reverse-proxy config for the web container
```

## Quick start

```bash
cp .env.example .env        # edit — use alphanumeric DB_PASSWORD (no # @ / ?)
docker compose up -d --build postgres api
```

Build and serve the Flutter web frontend:

```bash
cd frontend
flutter pub get
flutter gen-l10n          # regenerate localisation files if ARBs changed
flutter build web --release
docker compose up -d web
```

| URL | Purpose |
|---|---|
| `http://localhost:8080` | Flutter web app (via nginx) |
| `http://localhost:3000/health` | API health check |

### LAN access from other devices

Because the Flutter web build uses `Uri.base.origin` as its API base URL, any
device on the same network can open `http://<your-machine-ip>:8080` and the
app will work without any extra configuration — API calls are proxied by nginx
at the same origin.

> **Note:** plain HTTP is used. `flutter_secure_storage` requires HTTPS for its
> Web Crypto encryption, so the web build falls back to `localStorage` for JWT
> persistence on LAN. This is acceptable for an internal tool; add TLS for
> production use.

### Installing as a PWA

Open `http://<your-machine-ip>:8080` in any modern browser and use the
browser's **"Add to Home Screen"** / **"Install app"** option. The service
worker caches all app assets for offline use after the first load.

### Switching language

Use the **`[EN] [TR]`** toggle on the login or registration screen, or open the
user menu (top-right inside the app) and select *Language → English / Türkçe*.
The choice is persisted between sessions.

### Switching voice (Corporate ↔ Garage)

Independent of language, the app has two complete copy sets: the default
playful "Garage" voice and a neutral "Corporate" voice. Toggle with the 💼/🔧
control next to the language selector (login/registration screens), or via
*Voice → Corporate / Garage* in the user menu. Persisted independently of the
language choice, so any language + voice combination is possible.

### Rebuilding after changes

```bash
# Backend code change
docker compose up -d --build api

# Frontend code change
cd frontend && flutter build web --release
docker restart repairshop_web

# .env change (restart alone does NOT re-read .env)
docker compose up -d --force-recreate <service>

# Full reset (wipes database volume)
docker compose down -v && docker compose up -d --build
```

Frontend (dev hot-reload, outside Docker):

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Full details, prerequisites, and troubleshooting: [`SETUP.md`](./SETUP.md).

## Documentation

| File | Contents |
|---|---|
| [`SETUP.md`](./SETUP.md) | Prerequisites and step-by-step setup |
| [`CHANGELOG.md`](./CHANGELOG.md) | What changed and when |
| [`DECISIONS.md`](./DECISIONS.md) | Architecture decisions and known gotchas |
