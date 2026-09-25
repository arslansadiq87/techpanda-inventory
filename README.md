# Tech Panda Components Inventory

Local-only electronics inventory for components, modules, boards, tools, consumables, projects, stock movement, images, reports, and backups.

## Stack

- Flutter Android/Web/PWA client
- FastAPI backend
- SQLAlchemy 2.x and Alembic
- SQLite
- Local filesystem media storage

## Local Data

The copied hosted snapshot is stored under `local_data/server_snapshot`.
The app runs from `local_data/inventory.sqlite3` and `local_data/media`.

Rebuild the local runtime data from the copied snapshot:

```powershell
backend\.venv\Scripts\python scripts\import_server_snapshot.py
```

See [LOCAL_ONLY.md](LOCAL_ONLY.md) for run steps.

## Local Checks

```bash
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements-test.txt
.\.venv\Scripts\python -m pytest

cd ../flutter_app
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

## Windows Setup and Deployment

### Run the Flutter application on Windows

Install Git, Flutter stable, and (for Android builds) Android Studio with the Android SDK. Then clone and run the project from PowerShell:

```powershell
git clone -b main https://github.com/arslansadiq87/techpanda-inventory.git
cd techpanda-inventory\flutter_app
flutter doctor
flutter pub get
flutter run -d windows
```

Build the Windows release bundle:

```powershell
flutter build windows --release
```

The bundle is created at `flutter_app\build\windows\x64\runner\Release\`. To build an Android APK, run `flutter build apk --release` after configuring the Android SDK.

### Deploy the backend to a Linux server from Windows

From the repository root, install Python 3.12+ and Paramiko, then run the included remote deployer:

```powershell
py -3.12 -m pip install paramiko
py -3.12 deploy_remote.py
```

You can also double-click `deploy_to_linux.bat` or run:

```powershell
.\deploy_to_linux.ps1
```

The helper asks for the Linux server address, SSH credentials, Cloudflare Tunnel Token, and initial application admin password. It uploads the backend and web build, creates the server environment file, and starts Docker Compose. Keep all passwords and tokens out of command history and source control.

## Linux Server Deployment (Docker + Cloudflare Tunnels)

Deploy the backend to any Ubuntu/Debian Linux VPS or private server with persistent SQLite storage, automatic migrations, and Cloudflare Tunnel for secure HTTPS external access.

### Option 1: 1-Click Remote Deploy from Windows (Recommended)

From your Windows machine, you do not need to manually SSH into the server or run commands.

1. Double-click `deploy_to_linux.bat` (or run in terminal):
   ```powershell
   python deploy_remote.py
   ```
2. When prompted, enter your server details:
   - **Linux Server IP / Hostname:** e.g. `192.168.1.50` or `vps.yourdomain.com`
   - **SSH Username:** e.g. `root` or `ubuntu`
   - **SSH Password:** *(typed securely / hidden)*
   - **Cloudflare Tunnel Token:** *(optional, press Enter to skip or configure later)*

*Alternatively, run non-interactively with arguments:*
```powershell
python deploy_remote.py --host 192.168.1.50 --user root --password "your_password" --token "your_tunnel_token"
```

The script automatically packages the application, uploads it over SFTP, writes production environment variables, and executes the deployment script remotely.
The script automatically packages the application (including the production Flutter Web UI), uploads it over SFTP, writes production environment variables, and executes the deployment script remotely.

---

### Option 2: One-Command Deployment Directly on Linux

On a fresh Ubuntu/Debian server, run this single command:

```bash
git clone -b main https://github.com/arslansadiq87/techpanda-inventory.git ~/techpanda_inventory && cd ~/techpanda_inventory && chmod +x deploy.sh && ./deploy.sh
```

The script fetches the complete repository, installs Docker and Docker Compose if needed, asks for the Cloudflare Tunnel Token and initial application admin password, generates the JWT secret, builds the containers, runs migrations, and starts the application.

For a later update on the same server:

```bash
cd ~/techpanda_inventory && git pull origin main && ./deploy.sh
```

Do not put passwords or tunnel tokens in the command line or in Git. The deployment script stores them in the server-only `.env` file.

The script will automatically:
- Install Docker & Docker Compose if not already present.
- Generate `.env` with a secure random `JWT_SECRET`.
- Build the Python 3.12 backend container.
- Apply database migrations (`alembic upgrade head`).
- Start both the FastAPI backend and Cloudflare Tunnel containers in the background.
- Enable Docker services to automatically start on server boot.
- Generate `.env` with a secure random `JWT_SECRET` (or preserve existing token).
- Build the Python 3.12 backend container with bundled Flutter Web frontend.
- Apply database migrations (`alembic upgrade head || alembic stamp head`).
- Start both the Web App / API backend and Cloudflare Tunnel containers in the background.

---

### Cloudflare Zero Trust Configuration

In your [Cloudflare One / Zero Trust Dashboard](https://one.dash.cloudflare.com) under **Networks** -> **Tunnels**:
1. Open your tunnel -> **Public Hostname** -> **Add a public hostname**.
2. Configure your domain (e.g. `inventory.yourdomain.com`).
3. Set the service target:
   - **Type:** `HTTP`
   - **URL:** `api:8000` *(internal bridge network address)*

---

### Local Network & ESP32 Microcontroller Access

Port `8000` is exposed directly on the Linux host so internal devices (e.g. ESP32 voice assistant, local browsers) can communicate over LAN without passing through external Cloudflare routing:
- **LAN Base URL:** `http://<LINUX_SERVER_IP>:8000/api/v1`
- **Health Check:** `http://<LINUX_SERVER_IP>:8000/api/v1/health`

---

### Server Management Commands

### PostgreSQL for concurrent production use

SQLite remains the default for local development. For concurrent production users, configure PostgreSQL before deployment:

```bash
cat >> .env <<'EOF'
POSTGRES_DB=techpanda
POSTGRES_USER=techpanda
POSTGRES_PASSWORD=<strong-password>
DATABASE_URL=postgresql+psycopg://techpanda:<strong-password>@postgres:5432/techpanda
EOF
docker compose --profile postgres up -d postgres
docker compose --profile postgres run --rm api alembic upgrade head
docker compose --profile postgres up -d --build api tunnel
```

The existing SQLite database must be migrated into PostgreSQL before switching `DATABASE_URL`; take a backup first. Once PostgreSQL is active, the existing `with_for_update()` transaction locks provide row-level concurrency protection.


Run these inside the deployment directory on your Linux server:
```bash
docker compose logs -f api      # View live backend logs
docker compose logs -f tunnel   # View live Cloudflare tunnel logs
docker compose restart          # Restart services
docker compose down             # Stop all containers
```
