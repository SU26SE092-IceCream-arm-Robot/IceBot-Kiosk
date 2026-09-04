# IceBot Kiosk — Windows Customer App

Flutter/Windows customer-facing self-service kiosk application for the IceBot platform.

---

## Table of Contents

1. [Local Development](#1-local-development)
2. [Demo Mode](#2-demo-mode)
3. [Production Smoke Test](#3-production-smoke-test)
4. [Production Windows Build](#4-production-windows-build)
5. [Required Production Configuration](#5-required-production-configuration)
6. [Production Verification Checklist](#6-production-verification-checklist)

---

## 1. Local Development

All runtime values are passed as `--dart-define` at compile time.  
No `.env` file, no secrets, no platform-specific configuration files are needed.

### Prerequisites

- Flutter SDK (see `pubspec.yaml` for the SDK constraint)
- A running IceBot Backend instance
- A Manager account assigned to one store or kiosk

### Run against a local backend

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Kiosk\IceBot-Kiosk

flutter run -d windows `
  --dart-define=ICEBOT_API_BASE_URL=http://localhost:5000
```

On first launch, sign in with the Manager account for the target store. If the
store has more than one kiosk, select this physical machine from the kiosk list.
The app securely stores that binding; it is no longer compiled into the
executable.

> **Note:** `ICEBOT_DEMO_MODE` defaults to `false` and does not need to be specified
> unless you are explicitly testing demo mode.

### Runtime dart-define reference

| Variable | Default | Description |
|---|---|---|
| `ICEBOT_API_BASE_URL` | `http://10.0.2.2:5000` | Backend origin (no trailing slash, no path) |
| `ICEBOT_DEMO_MODE` | `false` | Set to `true` only for isolated offline demo |
| `ICEBOT_PAYMENT_METHOD_CODE` | `payos` | Payment method code registered in the backend |

### Analyze and test

```powershell
flutter analyze
flutter test
```

---

## 2. Demo Mode

Demo mode replaces all backend repositories with local in-memory stubs.
**It does not contact the backend at all.**

Demo mode does **not** require Manager login or a backend URL.

```powershell
flutter run -d windows `
  --dart-define=ICEBOT_DEMO_MODE=true
```

A visible orange "Chế độ demo" badge appears in the bottom-right corner of the app.

> **Important:** Never build a production kiosk with `ICEBOT_DEMO_MODE=true`.
> The `build-production.ps1` script refuses to build if demo mode is enabled.

---

## 3. Production Smoke Test

Use the helper script to run the kiosk in Flutter debug mode against the live production backend.  
Run this **before** cutting a release build to verify Manager login and kiosk resolution.

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Kiosk\IceBot-Kiosk

.\scripts\run-production.ps1 `
  -ApiBaseUrl "https://api.icebot.io.vn"
```

The script defaults `ApiBaseUrl` to `https://api.icebot.io.vn` and `DemoMode` to `false`.

### Manual equivalent

```powershell
flutter run -d windows `
  --dart-define=ICEBOT_API_BASE_URL=https://api.icebot.io.vn `
  --dart-define=ICEBOT_DEMO_MODE=false
```

Use the Manager login screen to link the machine to its production store and
kiosk. Logging out removes that binding and returns the app to setup state.

---

## 4. Production Windows Build

### Using the build script (recommended)

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Kiosk\IceBot-Kiosk

.\scripts\build-production.ps1
```

### Manual equivalent

```powershell
flutter build windows --release `
  --dart-define=ICEBOT_API_BASE_URL=https://api.icebot.io.vn `
  --dart-define=ICEBOT_DEMO_MODE=false
```

### Build output

| Item | Path |
|---|---|
| **Output folder** | `build\windows\x64\runner\Release\` |
| **Executable** | `build\windows\x64\runner\Release\icebot_kiosk.exe` |

### Deployment

> ⚠️ **You must deploy the entire `Release\` folder.**  
> Copying only `icebot_kiosk.exe` is **NOT sufficient**.  
> The application requires the following beside the executable:
> - All `.dll` files (Flutter engine, plugins)
> - `data\` subdirectory (ICU data, AOT snapshot, `flutter_assets\`)

**To start the built app on the target machine:**

```powershell
.\icebot_kiosk.exe
```

### Building an MSI installer

```powershell
.\installer\build-msi.ps1 `
  -ApiBaseUrl "https://api.icebot.io.vn"
```

Output MSI: `dist\windows\IceBot_Kiosk_1.0.0.msi`  
See [`installer\README.md`](installer/README.md) for WiX prerequisites.

---

## 5. Required Production Configuration

| Item | Value |
|---|---|
| `ICEBOT_API_BASE_URL` | `https://api.icebot.io.vn` |
| `ICEBOT_DEMO_MODE` | `false` (must be explicit — never omit) |
| `ICEBOT_PAYMENT_METHOD_CODE` | `payos` (or the code configured in the production backend) |

### Runtime kiosk setup

On an unconfigured machine:

1. Launch the app and sign in with the Manager account for the point of sale.
2. The account must have exactly one Manager scope.
3. If the store has multiple kiosks, choose the kiosk represented by this physical machine.
4. The app stores the resulting session and kiosk binding in secure storage.
5. Use the settings action on the menu to log out and reset the machine.

### What is not stored in the Kiosk

The following must **never** be added to the kiosk source code, dart-defines,
or deployment scripts:

- Backend management credentials / tokens
- PayOS API keys or secrets
- Payment provider webhooks
- Robot control credentials
- Database connection strings

The Kiosk communicates exclusively through the public IceBot Backend customer API.

---

## 6. Production Verification Checklist

Run these checks before every production deployment:

```powershell
# Static analysis
flutter analyze

# Unit tests
flutter test

# Release build
.\scripts\build-production.ps1
```

| Check | Expected |
|---|---|
| `flutter analyze` passes | No errors |
| `flutter test` passes | All tests green |
| Production release build succeeds | Exit code 0 |
| API base URL resolves to `https://api.icebot.io.vn` | ✅ |
| Demo mode is `false` | ✅ |
| Manager login resolves or lets Manager select a production kiosk | ✅ |
| Runtime menu loads for that Kiosk | Splash → Menu screen visible |
| No localhost URL is used at runtime | ✅ (blocked by AppConfig in release) |
| No development fallback is silently used | ✅ (release requires a valid HTTPS API URL) |
| No secret is included in source or CLI examples | ✅ |
| Customer ordering uses existing Backend contract | ✅ |
| Payment flow uses Backend `/api/v1/orders/{id}/payment-sessions` | ✅ |
| No Backend API was invented or modified | ✅ |
