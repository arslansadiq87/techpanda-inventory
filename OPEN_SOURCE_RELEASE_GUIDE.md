# TechPanda Open-Source Monorepo Guide

This repository contains the Flutter inventory client, its FastAPI backend, the ESP32 voice assistant firmware, and TechPanda wake-word tooling.

The source is released under the MIT License. See `LICENSE` and `SECURITY.md` before publishing or deploying.

## First-time setup

### Inventory app and API

For a one-command Linux deployment from the public repository:

```bash
git clone -b main https://github.com/arslansadiq87/techpanda-inventory.git ~/techpanda_inventory && cd ~/techpanda_inventory && chmod +x deploy.sh && ./deploy.sh
```

The script prompts securely for the Cloudflare Tunnel Token and initial application admin password, then builds and starts the deployment.

```powershell
Copy-Item .env.example .env
# Set JWT_SECRET and ADMIN_PASSWORD to long, unique values in .env.
# Set CLOUDFLARE_TUNNEL_TOKEN when using the included tunnel service.
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

For the API, use Python 3.12+, create a virtual environment, install `backend/requirements.txt`, and follow `docs/deployment.md`. Docker users can run `docker compose up --build` from this repository.

Never commit `.env`; production secrets belong in server environment variables or a secret manager. `JWT_SECRET` and `ADMIN_PASSWORD` are required; `CLOUDFLARE_TUNNEL_TOKEN` is optional and enables the Cloudflare profile when provided.

### ESP32 voice assistant

Install PlatformIO and connect an XIAO ESP32S3:

```powershell
cd esp32_voice_assistant
pio run
pio run --target upload
pio device monitor
```

Keep Wi-Fi passwords, API keys, and private URLs in untracked local configuration.

### Wake-word tooling

The tracked model is `TechPandaWakeWord/hi_tech_panda.tflite`. The sample generator is under `TechPandaWakeWord/piper-sample-generator/`. Recreate its Python environment from the tracked requirements; the existing local `env/`, generated samples, and large `microWakeWord/` checkout are intentionally excluded.

## Android, Windows and web releases

Run from `flutter_app/`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
flutter build windows --release
```

Artifacts:

- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Windows bundle: `build/windows/x64/runner/Release/`
- Web bundle: `build/web/`

For production API builds:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://inventory.example.com/api/v1
flutter build windows --release --dart-define=API_BASE_URL=https://inventory.example.com/api/v1
```

Keep signing keystores, passwords, and Windows certificates out of Git.

## GitHub release process

1. Review `git status` and `git diff --stat`.
2. Confirm no secrets, database files, media, build output, caches, or credentials are tracked.
3. Run the relevant Flutter, backend, and firmware checks.
4. Commit the source and documentation and create a tag such as `v1.0.0`.
5. Upload the APK and a ZIP of the Windows Release directory to the GitHub Release.

```powershell
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath TechPandaInventory-windows-v1.0.0.zip
gh release create v1.0.0 build/app/outputs/flutter-apk/app-release.apk TechPandaInventory-windows-v1.0.0.zip --generate-notes
```

The existing Linux deployment helpers remain in this repository. Use them only with credentials supplied securely; never place server passwords or tunnel tokens in commits or documentation.
