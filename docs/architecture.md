# Architecture

Tech Panda Components Inventory is a local-only Flutter and FastAPI application.

- Flutter targets Android and Web/PWA.
- Flutter calls the local API at `http://127.0.0.1:8000/api/v1` by default.
- FastAPI provides authentication, inventory, projects, image upload, reports, and health endpoints.
- SQLite stores all application data in `local_data/inventory.sqlite3`.
- Component media and backups are kept in `local_data/`.

The copied server snapshot is kept separately in `local_data/server_snapshot` for debugging and repeatable imports.
