# AutoService — Auto Repair Shop Management System

A small multi-tenant shop-management app: clients, vehicles, a service/parts catalog,
work orders (repair slips) with PDF printing, and basic revenue/parts reporting.

**Stack:** Flutter (Web + Mobile) · Node.js/TypeScript (Express) · PostgreSQL · Docker Compose

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
cp .env.example .env        # then edit .env with real secrets
docker compose up --build   # starts Postgres + the API
```

API health check: `http://localhost:3000/health`

Frontend (dev mode, outside Docker):

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Full details, prerequisites, and troubleshooting: [`SETUP.md`](./SETUP.md).
