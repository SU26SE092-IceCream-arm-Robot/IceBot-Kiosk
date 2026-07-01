# IceBot Kiosk Real-Device E2E Checklist

This checklist targets the customer-facing Android kiosk app. It must use only
the public kiosk/order APIs exposed by the IceBot backend.

## Runtime Configuration

The app reads compile-time values through `--dart-define`:

| Variable | Purpose | Example |
| --- | --- | --- |
| `ICEBOT_API_BASE_URL` | IceBot backend origin, without a trailing API path | `http://127.0.0.1:5000` or `https://icebot.io.vn` |
| `ICEBOT_KIOSK_ID` | Kiosk GUID used by runtime menu and order APIs | `aec68c48-207d-433d-b2fd-e7ddf7d5346a` |
| `ICEBOT_DEMO_MODE` | Uses isolated local demo repositories when `true` | `false` |

The listed kiosk ID is existing integration-test data. Confirm that its
organization, store, kiosk, menu, and products are active before each E2E run.
Do not put production credentials or payment secrets in Dart defines.

## 1. Start the Local Backend

Open PowerShell:

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Backend\IceBot-Backend

$env:ASPNETCORE_ENVIRONMENT="Development"
$env:ASPNETCORE_URLS="http://localhost:5000"
$env:ConnectionStrings__IceBot_DB="<LOCAL_POSTGRES_CONNECTION_STRING>"

dotnet run --project src\WebAPI\WebAPI.csproj --no-launch-profile
```

Check the backend without exposing credentials:

```powershell
Invoke-RestMethod http://localhost:5000/health
```

Do not manually call payment webhooks, IoT acknowledgement, robot execution,
or management APIs as part of the kiosk E2E flow.

## 2. Connect a Physical Android Device

Enable Developer options and USB debugging, then run:

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices
```

The device must appear as `device`, not `unauthorized`. Save its serial as:

```powershell
$deviceId = "<ANDROID_DEVICE_SERIAL>"
& $adb -s $deviceId reverse tcp:5000 tcp:5000
& $adb -s $deviceId reverse --list
```

With `adb reverse`, Android reaches the host backend through
`http://127.0.0.1:5000`. Cleartext HTTP is permitted only by the debug Android
manifest; release builds remain HTTPS-oriented.

## 3. Run Against the Local Backend

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Kiosk\IceBot-Kiosk

$deviceId = "<ANDROID_DEVICE_SERIAL>"
$kioskId = "aec68c48-207d-433d-b2fd-e7ddf7d5346a"

flutter run -d $deviceId `
  --dart-define=ICEBOT_API_BASE_URL=http://127.0.0.1:5000 `
  --dart-define=ICEBOT_KIOSK_ID=$kioskId `
  --dart-define=ICEBOT_DEMO_MODE=false
```

Remove the port mapping after testing if needed:

```powershell
& $adb -s $deviceId reverse --remove tcp:5000
```

## 4. Run Against the Deployed Backend

No `adb reverse` is required. The device must have Internet access:

```powershell
cd D:\FPT\Capstone\IceBot\Projects_Kiosk\IceBot-Kiosk

$deviceId = "<ANDROID_DEVICE_SERIAL>"
$kioskId = "aec68c48-207d-433d-b2fd-e7ddf7d5346a"

flutter run -d $deviceId `
  --dart-define=ICEBOT_API_BASE_URL=https://icebot.io.vn `
  --dart-define=ICEBOT_KIOSK_ID=$kioskId `
  --dart-define=ICEBOT_DEMO_MODE=false
```

Confirm the deployed environment contains the kiosk and menu data before
testing. Do not assume local database IDs exist in the deployed database.

## 5. Run the Isolated Demo Flow

Demo mode does not call the backend and does not require a kiosk ID:

```powershell
flutter run -d <ANDROID_DEVICE_SERIAL> `
  --dart-define=ICEBOT_DEMO_MODE=true
```

The UI must continue to display the demo label and must never present demo
payment or robot progress as real.

## 6. Customer Flow Checklist

1. Splash loads without configuration or overflow errors.
2. Runtime menu displays real backend items.
3. Product detail uses the selected runtime menu item.
4. Cart quantity and total remain consistent with the refreshed menu.
5. Checkout creates one order after repeated taps.
6. Payment session shows backend QR payload or checkout URL only.
7. Paid navigation enters order tracking, not a fake success screen.
8. Tracking displays the backend order status:
   - `ReadyForExecution`: `Đơn đang chờ xử lý`
   - `Accepted`: `Hệ thống đã nhận đơn`
   - `Preparing`: `Robot đang chuẩn bị`
   - `Ready`: pickup guidance
   - terminal failure/refund states: staff-support guidance
9. `Về menu` resets the kiosk session only from an allowed safe state.
10. A new customer starts with an empty cart and no previous order UI.

## 7. Recovery and Network Scenarios

- Stop the backend on the menu screen: verify a clear retry state.
- Interrupt checkout after order creation: retry must use the same order.
- Interrupt payment-session creation: retry must not create another order.
- Disable networking during payment/tracking: polling must pause and offer a
  retry action without overlapping requests.
- Kill and reopen the app during pending payment: it must recover the order and
  offer payment retry on that same order when the backend permits it.
- Kill and reopen during `Accepted`, `Preparing`, or `Ready`: it must recover
  the order and continue tracking.
- Terminal or recovery-expired data must be cleared.

## 8. Safe Session Reset Policy

Manual reset is allowed only for:

- `Ready`
- `Completed`
- `Failed`
- `Cancelled`
- `ExecutionRejected`
- `RefundRequired`
- `Refunded`
- `Compensated`

Reset is blocked for `Draft`, `PendingPayment`, `Paid`, `ReadyForExecution`,
`Accepted`, and `Preparing`. There is no automatic reset timer: pickup and
staff-support messages must remain visible until the customer explicitly
returns to the menu.

## 9. Verification Before Device Testing

```powershell
flutter analyze
flutter test
flutter build apk --debug
git diff --check
git status --short
```

The debug APK is generated at:

```text
build\app\outputs\flutter-apk\app-debug.apk
```
