# AutoService — Local Setup Guide (Windows + VS Code)

This walks you through installing everything needed and running the whole
stack (Postgres + API + Flutter app) locally in VS Code.

## 0. What's already on this machine

Confirmed already installed and working:

| Tool | Version found |
|---|---|
| Git | 2.54.0 |
| Node.js | v24.15.0 |
| npm | 11.12.1 |
| Flutter | 3.41.9 (stable) |

**Not installed yet: Docker Desktop.** That's the one thing you need to add — instructions below.

---

## 1. Install Docker Desktop for Windows

The database (and, when you want a full production-like test, the API too) runs in Docker containers, so Postgres never has to be installed directly on Windows.

1. Make sure WSL2 is enabled (Docker Desktop needs it):
   - Open PowerShell **as Administrator** and run:
     ```powershell
     wsl --install
     ```
   - If it says WSL is already installed, you're set. Otherwise, let it finish and **restart your computer** when prompted.
2. Download Docker Desktop for Windows from the official site: https://www.docker.com/products/docker-desktop/
3. Run the installer. Keep "Use WSL 2 instead of Hyper-V" checked (the default on modern Windows 10/11).
4. Restart your computer if the installer asks you to.
5. Launch **Docker Desktop** from the Start menu. Wait for the whale icon in the system tray to say "Docker Desktop is running."
6. Verify it from a **new** terminal (close and reopen any open terminal/VS Code window so it picks up the updated PATH):
   ```powershell
   docker --version
   docker compose version
   ```
   Both should print version numbers without error.

If `docker` still isn't recognized after restarting Docker Desktop, restart VS Code entirely (not just the terminal panel) — VS Code's integrated terminal sometimes caches the old PATH.

---

## 2. Open the project in VS Code

```powershell
code C:\GitHub\AutoService
```

When prompted, install the recommended extensions (VS Code will show a notification, or open the Extensions panel — it reads `.vscode/extensions.json`):
- **Dart** and **Flutter** (Dart-Code) — for the frontend
- **ESLint** — for the backend
- **Docker** — to see/manage containers from the sidebar
- **PostgreSQL** (optional) — to browse the database from VS Code

---

## 3. Configure secrets

The root `.env` file holds the database password and JWT signing secret. It's git-ignored on purpose — never commit it.

```powershell
Copy-Item .env.example .env
```

Open `.env` and replace the placeholder values:
- `DB_PASSWORD` — any password you like for local use.
- `JWT_SECRET` — a long random string. Generate one with:
  ```powershell
  node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
  ```
  Paste the output in as `JWT_SECRET`.

---

## 4. Start Postgres + the API with Docker Compose

From the project root:

```powershell
docker compose up --build
```

First run will take a minute or two (downloading the `postgres:16-alpine` and `node:20-alpine` images, then building the API image). You should see:

```
repairshop_db   | ... database system is ready to accept connections
repairshop_api  | {"time":"...","level":"info","message":"AutoService API listening on port 3000",...}
```

Leave this terminal running. In a **second** terminal, verify the API is up:

```powershell
curl http://localhost:3000/health
```
Expected: `{"status":"ok"}`

The `db/init/*.sql` scripts run automatically the very first time the `postgres` container creates its data volume — that's what creates all 7 tables (`shops`, `users`, `clients`, `vehicles`, `catalog_items`, `work_orders`, `work_order_items`), the enums, indexes, triggers, and row-level-security policies. You don't need to run any SQL by hand.

To double check the schema landed correctly:
```powershell
docker exec -it repairshop_db psql -U repairshop_admin -d repairshop -c "\dt"
```
(Use whatever `DB_USER`/`DB_NAME` you set in `.env` if you changed the defaults.)

To stop everything: `Ctrl+C` in that terminal, then `docker compose down` (add `-v` only if you also want to wipe the database volume and start fresh).

---

## 5. Run the Flutter app

Docker Compose can also serve a compiled Flutter Web build via the `web` container (see `docker-compose.yml`), but for day-to-day development it's much faster to run Flutter directly with hot reload, pointed at the API container from step 4.

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

This boots to the **login screen**. Since there's no shop yet, click **"New shop? Create an account"** and fill in the form — this calls `POST /api/v1/auth/register`, which creates your shop and the first `owner` user in one step.

Other devices you can target instead of Chrome (see `flutter devices`):
```powershell
flutter run -d windows   # native Windows desktop app
flutter run -d edge      # Edge instead of Chrome
```

### Connecting to a different API host

The app's API base URL defaults to `http://localhost:3000/api/v1`. Override it at launch if needed:
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```
If you ever run this on an **Android emulator**, `localhost` refers to the emulator itself, not your PC — use `http://10.0.2.2:3000/api/v1` instead.

---

## 6. Day-to-day development workflow

You don't have to rebuild the Docker API image on every backend code change. Two common setups:

**A. Full stack in Docker (closest to production)**
```powershell
docker compose up --build
```
Rebuilds the API image each time — good for a final check before committing, or the Phase-4.4-style full walkthrough (register → client → vehicle → work order → paid → report), but slower per iteration.

**B. Postgres in Docker, API running natively with hot reload (faster iteration)**
```powershell
docker compose up postgres    # just the database, in one terminal
```
```powershell
cd backend
copy .env.example .env        # first time only; already points at localhost:5432
npm install                   # first time only
npm run dev                   # ts-node-dev, restarts on save
```
Then run the Flutter app as in step 5, pointed at `http://localhost:3000/api/v1` either way.

Frontend hot reload: with `flutter run -d chrome` active, press `r` in that terminal for hot reload or `R` for hot restart after saving Dart files — or just save in VS Code with the Dart/Flutter extension, which does it automatically.

---

## 7. Verifying things work end-to-end

A full walkthrough to confirm the whole system is wired correctly:

1. Register a shop (step 5) → you land on the Work Orders screen.
2. Go to **Clients** → add a client.
3. Go to **Vehicles** → add a vehicle for that client (license plate, make/model).
4. Go to **Catalog** → add a service (e.g. "Oil Change", $25) and a part (e.g. "Oil Filter", $8).
5. Go to **Work Orders** → **+** → pick the client/vehicle, add both catalog items as line items, save. Totals (subtotal/tax/grand total) should compute automatically.
6. Open the new work order → **Mark as completed** → **Mark as paid** (pick a payment method).
7. Click the print icon → a PDF slip should open in a new browser tab.
8. Go to **Reports** → **Revenue** tab → the amount you just got paid should show up.
9. Try the search bar in the top app bar with the license plate you entered — it should show the vehicle at the top of the results.

If every step above works, the full stack (Postgres → Express API → Flutter UI) is correctly connected.

---

## 8. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `docker` not recognized | Docker Desktop not running, or terminal opened before install finished — restart terminal/VS Code |
| `docker compose up` fails with "DB_PASSWORD... error" | `.env` wasn't created/filled in (step 3) |
| API container keeps restarting | Check logs: `docker compose logs api` — usually a missing/invalid env var |
| Flutter app shows a network error on login | Backend isn't running, or `API_BASE_URL` doesn't match where it's listening |
| `flutter run -d chrome` can't find Chrome | Make sure Chrome is installed; otherwise use `-d edge` or `-d windows` |
| Port 3000 or 5432 already in use | Something else on the machine is using it — stop that process, or change the host-side port in `docker-compose.yml` (the part before the `:`) |
| Want a clean slate | `docker compose down -v` — **this deletes all data** in the Postgres volume, use only for local testing resets |

---

## 9. Project structure recap

See [`README.md`](./README.md) for the directory layout, and
`C:\Users\Farzad\Desktop\logs\auto-repair-shop-architecture.md` for the full
architecture/design document this implementation follows.
