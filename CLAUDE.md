# TBScreen.AI — Flutter Tablet App (Doctor Role)

## Project Identity
Medical AI tablet app for tuberculosis (TB) screening via chest X-ray image analysis.
This repo = DOCTOR role only (tablet app).
Other roles: Admin RS (web, separate repo), Super Admin (web, separate repo).

## Tech Stack
- Flutter + Dart (SDK ^3.11.4)
- go_router: ^15.1.2 — ShellRoute for NavRail persistence
- provider: ^6.1.2 — state management
- camera: ^0.12.0+2 / image_picker — chest X-ray capture and gallery selection
- dio — HTTP client; drift/drift_flutter — local DB + offline sync queue
- flutter_onnxruntime — on-device inference engine for an installed model bundle
- ed25519_edwards + crypto — model-bundle signature/checksum verification
- flutter_secure_storage — session tokens (never plaintext SQLite)
- connectivity_plus, archive, image, path_provider — OTA/model-bundle support
- Material Design 3 (useMaterial3: true)

## Current Phase
HYBRID REPOSITORIES + ON-DEVICE INFERENCE + SIGNED OTA MODEL UPDATES.
- Domain models: lib/domain/models/ (immutable, no Flutter imports)
- Interfaces: lib/domain/repositories/ — screens/providers depend on these only
- Mock impl: lib/data/mock/ (demo flavor; SynchronousFuture = no loading flash)
- Http/offline impl: lib/data/http/, lib/data/offline/, lib/data/local/ (dio + Drift;
  auth/patients/sync are durable offline-first — dashboard/dataset APIs still unavailable)
- On-device impl: lib/data/onnx/ (OnnxInferenceEngine, segmentation overlay) and
  lib/data/models_ota/ (signed bundle download/verify/activate/rollback pipeline)
- `DiagnosisRepository` is `HybridDiagnosisRepository`: tries the on-device ONNX
  bundle first, falls back to HTTP or mock only when no verified bundle is installed.
- `SyncRepository`'s model-update half (`ModelUpdateService`) is real in every flavor,
  including demo (`HybridSyncRepository`) — only the data-backup half stays mock/offline-queued.
- Toggle HTTP/offline vs demo: --dart-define=USE_HTTP=true (+ API_BASE_URL=...), see
  lib/core/config/app_config.dart. Production flavor stays locked regardless.
- Backend repo: C:\Users\devel\tbscreenai-backend (FastAPI, kontrak docs/openapi.json)

## Testing Environment
Fast iteration: `flutter run -d chrome` (web/desktop browser preview).
Real-device debugging also happens on Android now. Since product flavors
(demo/staging/production) were added, `flutter run`/`flutter build apk` on
Android **requires** `--flavor demo --dart-define=APP_ENV=demo` (or `staging`
with its `API_BASE_URL`) — a plain `flutter run` with no flavor fails the
`build.gradle.kts` safety check ("Native artifact flavor must match APP_ENV")
because it implicitly targets every flavor's debug variant at once.
Final deploy target: Android tablet, landscape orientation, 10–12 inch screen.

---

## Layout Rules
- Always use LayoutBuilder; breakpoint ≥ 1024px = tablet layout
- NavRail: 84px wide (AppTheme.railWidth), navy→navyDark vertical gradient, fixed left via Row in AppShell
- ShellRoute wraps all screens that share NavRail (AppShell)
- Screens WITHOUT NavRail: LoginScreen, CameraScreen
- Max content width: 1600px — wrap with Center + ConstrainedBox
- Touch targets: min 48×48px (tablet finger-friendly)
- Scrollable content: always wrap in SingleChildScrollView with padding 24

## Color System (app_theme.dart — source of truth)
- primary: #4FC3F7
- primaryDark: #0288D1
- secondary: #1E3A5F (NavRail background)
- success: #22C55E
- warning: #F59E0B
- error: #EF4444
- background: #F9FAFB
- surface: #FFFFFF
- textPrimary: #111827
- textSecondary: #6B7280

RULE: Never hardcode hex in widgets. Always use Theme.of(context) or AppColors.

## Card Style (standard across all screens)
- borderRadius: 16
- elevation: 2
- padding: EdgeInsets.all(24)
- bg: Colors.white

---

## Screen Directory & NavRail Index

| Route | Screen | NavRail | Index |
|-------|--------|---------|-------|
| /login | LoginScreen | No | - |
| /dashboard | DashboardScreen | Yes | 0 |
| /patients | PatientsScreen | Yes | 1 |
| /diagnosis | DiagnosisScreen (Input Data / Hasil Analisis — no visible tab bar) | Yes | 2 |
| /validation | ValidationScreen | Yes | 3 |
| /dataset | DatasetScreen | Yes | 4 |
| /sync | SyncCenterScreen | Yes | 5 |
| /account | AccountScreen | Yes | 6 |
| /camera | CameraScreen | No (full screen) | - |

NOTE: the old standalone `/result` route/NavRail item was merged into
`/diagnosis` as its second internal view ("Hasil Analisis"). There is no
visible `TabBar` — the view switches automatically right after a successful
analysis, and back again on "Screening Baru"/reset; a `TabController` +
`TabBarView` still back it, so swiping the body also moves between views
(blocked into Hasil Analisis until a real outcome exists). See
`lib/features/diagnosis/presentation/diagnosis_screen.dart`. The result view
itself (`widgets/diagnosis_result_tab.dart`) is a two-column dashboard: X-ray
viewer (tap to zoom/pan; lung/lesion segmentation toggle with a per-class
area-percentage legend) + patient summary on the left; AI verdict, a
dialog-gated clinical-data button, recommendations, and analysis metadata on
the right.

NavRail icons (in order) — source of truth: `lib/features/shared/presentation/app_shell.dart`:
0: Icons.space_dashboard_rounded   (Dashboard)
1: Icons.people_alt_rounded        (Patients)
2: Icons.biotech_rounded           (Diagnose)
3: Icons.verified_user_rounded     (Validation, shows a pending-count badge)
4: Icons.table_chart_rounded       (Dataset)
5: Icons.cloud_sync_rounded        (Sync)
6: Icons.person_rounded            (Account)

---

## SyncCenterScreen — Current Implementation

Purpose unchanged: (1) check & update the AI model, (2) optionally back up
medical data. Offline-first — sync is always user-initiated, never automatic.
`lib/features/sync/presentation/sync_center_screen.dart`: header with a real
`_ConnectionChip` (backed by `ConnectivityService`), then `_ModelUpdateCard` and
`_DataBackupCard` side by side (stacked below 880px).

- **`_ModelUpdateCard`** is real, not mock: `idle → checking → upToDate |
  updateAvailable → downloading → installing → done | error`. Calls
  `SyncRepository.checkForUpdate()`/`downloadModel()`, backed by
  `ModelUpdateService` (`/models/check`) and `ModelUpdatePipeline`
  (download → Ed25519 signature + per-file SHA-256 verification →
  activate → smoke-test → automatic rollback on failure). See
  `lib/data/models_ota/` and `lib/data/onnx/bundle_verifier.dart`.
- **`_DataBackupCard`** stays the simulated/offline-queued flow described
  before: consent dialog (non-dismissible, checkbox-gated "Lanjutkan"),
  patient selection, upload progress, done/error summary.

---

## Code Rules
- Extract reusable widgets ke lib/features/shared/presentation/widgets/
- Use const constructors wherever possible
- Theme-driven: Theme.of(context), never hardcoded hex in widget files
- Mouse hover (web preview): MouseRegion + AnimatedContainer
  GUARD PATTERN (wajib): if (!mounted) return; sebelum setState di onEnter/onExit
- No hardcoded strings in UI — gunakan variable atau constants file
- Comment sections: // === Section: SectionName ===
- One screen = one file. Sub-widgets boleh di file terpisah jika >100 baris.

## Packages FORBIDDEN in this phase
supabase, firebase_core, sqflite, hive, shared_preferences
(dio sudah dipakai di lib/data/http/; drift sudah dipakai di lib/data/local/
untuk DB lokal + offline queue. Jangan tambah paket storage lain tanpa izin.)

---

## Known Issues & Patterns

### Mouse tracker assertion (RESOLVED)
Error: assertion di mouse_tracker.dart saat hover di browser.
Fix: tambahkan guard sebelum semua setState di hover handler.
```dart
void _setHovered(bool value) {
  if (!mounted) return; // WAJIB
  setState(() => _isHovered = value);
}
```

### Web preview sizing
Saat test di browser, set window width ≥ 1024px agar layout tablet aktif.
Jika layout mobile muncul, bukan bug — itu LayoutBuilder bekerja benar.

### Android Gradle flavor gotchas (RESOLVED)
- `A problem occurred configuring project ':app' > ... contains custom
  resource values, but the feature is disabled` — AGP 8+ defaults
  `android.buildFeatures.resValues` to `false`, but `android/app/build.gradle.kts`'s
  product flavors call `resValue(...)` to set a per-environment app name. Fixed
  by adding `buildFeatures { resValues = true }` there.
- `Native artifact flavor must match APP_ENV` — see Testing Environment above;
  always pass `--flavor <demo|staging>` on Android.

---

## File Structure Convention
Feature-first, not screen-first — there is no `lib/screens/`, `lib/widgets/`,
or `lib/mock/` at the top level. Each feature owns a folder under
`lib/features/<name>/`, with its screen(s) in `presentation/` (and
`application/` for feature-local non-UI logic, e.g. `diagnosis/application/
xray_image_picker.dart`). Shared data/domain/state layers live in
`lib/data/`, `lib/domain/`, `lib/state/`. See the "Project Structure" tree in
`README.md` for the full, current layout — keep that tree in sync instead of
duplicating it here.
