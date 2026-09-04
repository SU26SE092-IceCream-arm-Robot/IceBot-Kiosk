# Backend confirmation for Manager kiosk setup

The app now treats Manager login as the kiosk setup step. These assumptions must
be confirmed with the backend team before production rollout.

## Implemented contract

- Login uses `POST /api/v1/authentication/login`.
- The successful response must contain `accessToken`, `refreshToken`, and one
  role whose `roleCode` is `Manager`.
- If that role contains `kioskId`, the app binds directly to that kiosk.
- If it only contains `storeId`, the app requests
  `GET /api/v1/management/kiosks?storeId={storeId}`. One kiosk is selected
  automatically; when there are multiple kiosks, the Manager chooses the
  physical kiosk being configured.
- The session is stored in secure storage. On restart, the app restores it and
  refreshes the access token when necessary.
- Manager logout revokes the refresh token on a best-effort basis, clears local
  session data, and returns the machine to the unconfigured login screen.

## Backend questions to confirm

1. Please publish the typed login response in OpenAPI, including a real Manager
   example for `roles[].organizationId`, `storeId`, and `kioskId`.
2. A Manager manages one store and may choose any kiosk in that store. Confirm
   that the list endpoint always enforces this store-level permission.
3. Is `GET /api/v1/management/kiosks?storeId=...` accessible to the Manager
   role, and is its response shape the same as the current management contract?
4. Should the kiosk keep using the Manager access/refresh token after setup, or
   should setup exchange it for a separate long-lived device/kiosk credential?
5. Are `/api/v1/runtime/*` routes the required replacement for the current
   customer ordering routes? Their response schemas and migration timing need
   to be confirmed before the app is switched.
6. Should logout require Manager password/PIN re-authentication? The current UI
   uses a deliberate long press plus confirmation dialog to prevent accidental
   customer logout.
7. Confirm refresh/revoke behavior when the refresh token is expired or the
   device is offline. The app currently clears its local setup even if revoke
   cannot reach the backend.

## Deliberate temporary behavior

After login resolves a kiosk ID, ordering and payment continue through the
existing repositories and endpoints. This preserves current kiosk behavior
until the runtime API contract above is confirmed.
