# IceBot Kiosk Windows MSI

The MSI packages the complete Flutter Windows release directory. Runtime API
and kiosk identity values are compiled into the Flutter release with
`--dart-define`; the installer does not contain credentials or payment secrets.

## One-time WiX setup

Install the pinned WiX command-line tool outside the repository:

```powershell
dotnet tool install wix `
  --tool-path "$env:LOCALAPPDATA\IceBot\Tools\wix" `
  --version 6.0.2
```

## Build for an edge kiosk

```powershell
.\installer\build-msi.ps1 `
  -ApiBaseUrl "https://backend.example" `
  -KioskId "00000000-0000-0000-0000-000000000000" `
  -Version "1.0.0"
```

Use the real backend URL and the management-created kiosk ID for the target
machine. Do not put provider secrets, MQTT credentials, or access tokens in
these arguments.

## Build an offline UI demo

```powershell
.\installer\build-msi.ps1 -DemoMode -Version "1.0.0"
```

Output is written to `dist/windows/IceBot_Kiosk_<version>.msi`. Install with an
administrator account because the package uses a per-machine installation
under Program Files. The MSI creates Start Menu and desktop shortcuts.
