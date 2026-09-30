# Sprint 3: honest live behavior

FE-110: Android demo/staging/production application IDs, labels and colored icons. Persistent synthetic demo watermark. Staging binds HTTP/offline repositories; dashboard/dataset bind explicitly unavailable repositories. Production compile/package gate remains locked; no environment flag can approve clinical review. HTTPS versioned URL and native flavor matching required. Android forbids cleartext traffic.

FE-111: Account identity, email, role and tenant use authenticated session. Statistics and unverified 2FA removed. Dashboard and dataset live UI disabled until agreed aggregation/CRUD contracts and role capabilities exist. Local backend docs/openapi.json contains no dashboard/dataset endpoints. No endpoints invented. Real API loading/403/offline/CRUD coverage remains dependent on those contracts.

FE-112: Disabled model update UI and repository downloads; no simulated install or settings write. Legacy installed-version settings are not treated as verified installation evidence. Resumable download/verification/activation/rollback remain blocked on signed artifacts and security decision.

FE-113: Empty action callbacks disabled. Export PDF and Print remain disabled pending PHI approval; existing durable result Save retained. No share/export implementation enabled.

Android demo: flutter build apk --flavor demo --dart-define=APP_ENV=demo
Android staging: flutter build apk --flavor staging --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://YOUR-STAGING-HOST/api/v1

Only Android has native flavor packaging configured in this sprint. iOS/desktop packaging still requires platform provisioning. Production remains unavailable.

Validation: full Flutter suite passed (148 tests before adding one artifact guard case); staging guard/binding suite passed (6 cases). Analyzer clean. Dart production and missing-config compile probes rejected as expected. Actual Android staging build with insecure HTTP rejected before packaging. APK packaging result recorded separately below.

Demo Android APK built successfully: build/app/outputs/flutter-apk/app-demo-release.apk (57.4 MB). Actual production Android build rejected by clinical gate. Valid staging APK has not been packaged or tested against a live backend. Targeted demo guard/binding/sync widget suite: 11 passed.
Final full suite: 149 tests passed. Final analyzer: no issues.

Review patches complete: production variants removed, direct/indirect packaging blocked, staging empty Result contains no demo values, demo cannot bind HTTP repositories. Full suite now 150 passed; staging guard/binding/result suite 7 passed. Demo APK rebuilt after patches. See sprint-3-patch-checklist.md for evidence.
