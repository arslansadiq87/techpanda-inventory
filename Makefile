.PHONY: backend-test flutter-test flutter-build import-snapshot

backend-test:
	cd backend && .venv/Scripts/python -m pip install -r requirements-test.txt && .venv/Scripts/python -m pytest

flutter-test:
	cd flutter_app && flutter test

flutter-build:
	cd flutter_app && flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

import-snapshot:
	backend/.venv/Scripts/python scripts/import_server_snapshot.py
