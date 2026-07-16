# Remote Trackpad

Remote Trackpad is a monorepo containing a Rust desktop backend and a Flutter mobile client for controlling a desktop machine over local Wi-Fi.

## Structure

- backend/: Rust server with UDP/TCP handling, tray-style desktop integration, and input emulation.
- frontend/: Flutter client with gesture-driven controls and hidden settings access.
- artifacts/: CI/CD output directory for release binaries and packages.
- .github/workflows/: GitHub Actions definition for testing and release artifact generation.

## Local Setup

### Backend

From the repository root:

```powershell
cd backend
cargo test
cargo build --release
```

The backend uses `backend/Cargo.toml` and runs on UDP port `8001` for motion/scroll payloads and TCP port `8002` for click/command payloads.

### Frontend

From the repository root:

```powershell
cd frontend
flutter pub get
flutter test
flutter build apk --release
```

The Flutter client sends UDP move/scroll packets to the backend and TCP command packets for clicks, Alt+Tab, and volume control.

### Notes

- Ensure Rust and Cargo are installed for backend development.
- Ensure Flutter is installed and available on your PATH for frontend development.
- Use the hidden tap zone in the app to open server settings and configure the backend IP.
