# Tech Panda Inventory - Local Only

This duplicate is configured to run against local files only.

## Imported Server Snapshot

A read-only snapshot from the hosted app was copied into:

- `local_data/server_snapshot/remote_inventory_postgres.sql`
- `local_data/server_snapshot/media/`

To rebuild the local SQLite database and media folder from that snapshot:

```powershell
python scripts/import_server_snapshot.py
```

The local runtime files are:

- `local_data/inventory.sqlite3`
- `local_data/media/`
- `local_data/backups/`
- `local_data/exports/`

The API is run from `backend/`, so its default relative paths point back to these project-level files with `../local_data/...`.

Settings includes backup controls:

- Download backup creates a `.zip` with the database and all media.
- Restore backup imports that `.zip` and keeps a safety copy in `local_data/backups`.

## Run Locally

Start the API:

```powershell
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
.\.venv\Scripts\uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Start Flutter in another terminal:

```powershell
cd flutter_app
flutter run -d chrome
```

The Flutter app points to `http://127.0.0.1:8000/api/v1` by default. You can still override it for debugging with:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Default local login:

- Username: `admin`
- Password: `admin`
