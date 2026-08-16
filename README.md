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
- A valid Kiosk ID registered in the local database

### Run against a local backend

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Kiosk\IceBot-Kiosk

flutter run -d windows `
  --dart-define=ICEBOT_API_BASE_URL=http://localhost:5000 `
  --dart-define=ICEBOT_KIOSK_ID=<LOCAL_KIOSK_ID>
```

> **Note:** `ICEBOT_DEMO_MODE` defaults to `false` and does not need to be specified
> unless you are explicitly testing demo mode.

### Runtime dart-define reference

| Variable | Default | Description |
|---|---|---|
| `ICEBOT_API_BASE_URL` | `http://10.0.2.2:5000` | Backend origin (no trailing slash, no path) |
| `ICEBOT_KIOSK_ID` | *(empty)* | Kiosk GUID registered in the backend database |
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

Demo mode does **not** require a Kiosk ID or a backend URL.

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
Run this **before** cutting a release build to verify the production Kiosk ID is valid.

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Kiosk\IceBot-Kiosk

.\scripts\run-production.ps1 `
  -KioskId "<PRODUCTION_KIOSK_ID>"
```

The script defaults `ApiBaseUrl` to `https://api.icebot.io.vn` and `DemoMode` to `false`.

### Manual equivalent

```powershell
flutter run -d windows `
  --dart-define=ICEBOT_API_BASE_URL=https://api.icebot.io.vn `
  --dart-define=ICEBOT_KIOSK_ID=<PRODUCTION_KIOSK_ID> `
  --dart-define=ICEBOT_DEMO_MODE=false
```

> **`<PRODUCTION_KIOSK_ID>`** must be obtained from the **IceBot Admin Web → Kiosk Management**
> for the production environment. Do not assume local database IDs exist in production.

---

## 4. Production Windows Build

### Using the build script (recommended)

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Kiosk\IceBot-Kiosk

.\scripts\build-production.ps1 `
  -KioskId "<PRODUCTION_KIOSK_ID>"
```

### Manual equivalent

```powershell
flutter build windows --release `
  --dart-define=ICEBOT_API_BASE_URL=https://api.icebot.io.vn `
  --dart-define=ICEBOT_KIOSK_ID=<PRODUCTION_KIOSK_ID> `
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
  -ApiBaseUrl "https://api.icebot.io.vn" `
  -KioskId "<PRODUCTION_KIOSK_ID>"
```

Output MSI: `dist\windows\IceBot_Kiosk_1.0.0.msi`  
See [`installer\README.md`](installer/README.md) for WiX prerequisites.

---

## 5. Required Production Configuration

| Item | Value |
|---|---|
| `ICEBOT_API_BASE_URL` | `https://api.icebot.io.vn` |
| `ICEBOT_KIOSK_ID` | Obtain from IceBot Admin Web → Kiosk Management (production) |
| `ICEBOT_DEMO_MODE` | `false` (must be explicit — never omit) |
| `ICEBOT_PAYMENT_METHOD_CODE` | `payos` (or the code configured in the production backend) |

### ⚠️ Production Kiosk ID

**The local Kiosk ID used during development (`019fb380-5502-7b35-a6e0-dacfa5d42687`)
was created against the local development database.**

It **cannot** be assumed to exist in the production database.

**Before the first production deployment:**
1. Log in to the IceBot Admin Web (production environment).
2. Navigate to **Kiosk Management**.
3. Create or select the kiosk entry for this physical machine.
4. Copy the Kiosk GUID and use it as `ICEBOT_KIOSK_ID`.

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

# Release build (dry-run — supply a real Kiosk ID)
.\scripts\build-production.ps1 -KioskId "<PRODUCTION_KIOSK_ID>"
```

| Check | Expected |
|---|---|
| `flutter analyze` passes | No errors |
| `flutter test` passes | All tests green |
| Production release build succeeds | Exit code 0 |
| API base URL resolves to `https://api.icebot.io.vn` | ✅ |
| Demo mode is `false` | ✅ |
| A real production Kiosk ID is configured | ✅ |
| Runtime menu loads for that Kiosk | Splash → Menu screen visible |
| No localhost URL is used at runtime | ✅ (blocked by AppConfig in release) |
| No development fallback is silently used | ✅ (AppConfig halts on missing Kiosk ID) |
| No secret is included in source or CLI examples | ✅ |
| Customer ordering uses existing Backend contract | ✅ |
| Payment flow uses Backend `/api/v1/orders/{id}/payment-sessions` | ✅ |
| No Backend API was invented or modified | ✅ |
