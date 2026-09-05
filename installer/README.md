# IceBot Kiosk Windows MSI

The MSI packages the complete Flutter Windows release directory. The runtime API
origin is compiled into the release with `--dart-define`; kiosk identity is linked
after installation through Manager login. The installer does not contain
credentials or payment secrets.

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
  -Version "1.1.0"
```

Use the real backend URL and the management-created kiosk ID for the target
machine. Do not put provider secrets, MQTT credentials, or access tokens in
these arguments.

## Build an offline UI demo

```powershell
.\installer\build-msi.ps1 -DemoMode -Version "1.1.0"
```

Output is written to `dist/windows/IceBot_Kiosk_<version>.msi`. Install with an
administrator account because the package uses a per-machine installation
under Program Files. The MSI creates Start Menu and desktop shortcuts.
