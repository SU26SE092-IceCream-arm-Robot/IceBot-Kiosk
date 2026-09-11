# Runtime Client Device and MSI Checklist

- [x] Confirm the runtime REST contract against local OpenAPI, backend source, and production Swagger.
- [x] Provision a ClientDevice through the existing Manager setup flow.
- [x] Exchange the installation credential for a short-lived runtime token.
- [x] Authenticate every `/api/v1/runtime/*` request and retry once after HTTP 401.
- [x] Align menu, order, and payment routes and payloads with the runtime contract.
- [x] Preserve kiosk selection, order recovery, TTS, demo mode, and setup reset behavior.
- [x] Add MSI license agreement and installation-directory wizard pages.
- [x] Update focused tests and documentation.
- [x] Pass `dart format`, `flutter analyze`, and `flutter test`.
- [x] Build the Windows release and validate the MSI package.
