# TBScreen.AI — Tablet App (Doctor Role)

> AI-assisted tuberculosis (TB) screening from chest X-ray images, built for medical tablets.

TBScreen.AI is a **Flutter tablet application** for the **doctor role** in a TB
screening workflow. A clinician can register a patient, capture or upload a chest
X-ray, run an AI analysis (on-device when a model is installed, simulated
otherwise), review the result, validate the AI's prediction, manage training
datasets, and sync the model — all from a single tablet-optimized interface.

> **Current status: technical demo / guarded staging, not a clinical release.**
> Demo uses synthetic repositories only; staging uses HTTPS HTTP/offline adapters
> for auth, patients, and sync. Dashboard/dataset APIs and PHI export (PDF/print)
> remain unavailable, and production variants stay disabled until the clinical
> gate is approved. TB screening itself, however, now runs a **real on-device
> ONNX model** when a verified bundle is installed (falling back to a synthetic
> outcome otherwise), and the Sync Center's model update is a **real
> Ed25519-signed download → verify → activate → rollback pipeline** — neither
> is simulated. See [Sprint 3 status](docs/sprint-3-status.md) and the
> [review patch checklist](docs/sprint-3-patch-checklist.md) for the HTTP/staging
> baseline this builds on.

> 📘 **New here / non-developer?** A step-by-step, printable **Setup & Run Guide**
> (clone from GitHub → run on your own computer or tablet → view the interface) is
> available at **[`docs/TBScreenAI-Setup-Guide.pdf`](docs/TBScreenAI-Setup-Guide.pdf)**.

---

## ✨ Features

| Area | What it does |
|------|--------------|
| 🔐 **Login** | Email/password form with validation (mock auth, any valid email works). |
| 📊 **Dashboard** | KPI stat cards, agreement-level bar, diagnosis-trend line chart (custom painter), and case-distribution donuts. |
| 👥 **Patients** | Searchable master–detail list with patient profile, X-ray card, and history timeline. |
| 🩺 **Diagnosis** | Multi-section intake form (basic info, symptoms, clinical background, bacteriology, TB status) + X-ray upload/capture, then runs a real on-device ONNX analysis when a model bundle is installed (synthetic outcome otherwise). |
| 📷 **Camera** | Full-screen capture UI with framing guides, flash & camera-switch controls. |
| 🧾 **Hasil Analisis** | The Diagnosis screen's second view (no separate route, no visible tab bar — it's selected automatically once an analysis completes). Two-column dashboard: X-ray viewer (tap to zoom/pan, lung/lesion segmentation toggle with a per-class area-percentage legend) and patient summary on the left; AI verdict, a dialog-gated clinical-data detail view, recommendations, and analysis metadata on the right. |
| ✅ **Validation** | Doctor reviews AI results case-by-case, agrees/disagrees with a clinical note, auto-advances through the queue. |
| 🗂️ **Dataset** | CRUD over training datasets and their images (list / create / detail / edit, with confirm dialogs). |
| ☁️ **Sync Center** | Real, signed model-update pipeline (download → verify → activate → rollback) plus consent-gated medical-data backup (offline-queued; synthetic in demo mode). |
| 👤 **Account** | Doctor profile, stats, security & notification toggles, sign out. |

### Design highlights
- **Tablet-first, landscape** layout with a persistent left navigation rail.
- **Material 3** theming from a single source of truth (`app_theme.dart`) — no hardcoded colors in screens.
- Consistent, reusable components (`AppCard`, `StatusBadge`, `SectionHeader`, `EmptyState`).
- Accessible status cues (color **plus** icon, ≥44px touch targets, visible focus/hover states, tooltips on nav).
- Smooth 150–320ms micro-interactions; hover/press feedback tuned for touch and web preview.

---

## 🧱 Tech Stack

- **Flutter** + **Dart** (SDK `^3.11.4`), Material Design 3 (`useMaterial3: true`)
- **[go_router](https://pub.dev/packages/go_router)** `^15.1.2` — routing via a `ShellRoute` that keeps the nav rail persistent
- **[provider](https://pub.dev/packages/provider)** `^6.1.2` — state management (auth, dashboard filters, diagnosis flow)

- **Dio** — HTTP API client; **Drift / drift_flutter** — local database and offline queue.
- **camera / image_picker** — real camera capture and gallery selection.
- **flutter_onnxruntime** — on-device inference engine for the installed model bundle.
- **archive / image** — model-bundle extraction and lung/lesion segmentation overlay rendering.
- **ed25519_edwards / crypto** — bundle signature verification (pinned public key) and SHA-256 checksums.
- **flutter_secure_storage** — session tokens in platform secure storage, never plaintext SQLite.
- **connectivity_plus / path_provider** — online/offline detection and on-device model-bundle storage.
- Exact resolved versions are in `pubspec.lock`.

---

## 🖥️ Screenshots

> Run the app (below) to view it live. The interface targets **landscape tablet**
> at **≥1024px** width. To capture screenshots, use Chrome DevTools device mode
> with a tablet profile (e.g. iPad Pro / Nexus 10, landscape).

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.44.7** (the CI-pinned version; current dependencies require Dart >=3.12)
- A browser (Chrome recommended) for the quickest preview, **or** an Android tablet / emulator

Verify your setup:

```bash
flutter --version
flutter doctor
```

### Install

```bash
git clone https://github.com/rishalfanda/tbscreenai-mobile-frontend.git
cd tbscreenai-mobile-frontend
flutter pub get
```

### Run

**Browser preview (fastest — no device needed):**

```bash
flutter run -d chrome
```

> 💡 **Make the browser window ≥ 1024px wide** so the tablet layout activates.
> A narrower window is not a bug — it just means the responsive breakpoint hasn't
> been reached.

**On an Android tablet / emulator (final target — landscape, 10–12"):**

```bash
flutter devices          # find your device id
flutter run -d <device> --flavor demo --dart-define=APP_ENV=demo
```

**Staging on Android emulator (requires an approved HTTPS backend):**

```bash
flutter run -d emulator-5554 --flavor staging --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://YOUR-STAGING-HOST/api/v1
```

These are build-time settings. Demo cannot connect to a backend. Staging does
not establish clinical readiness.

### Build a demo artifact

```bash
flutter build web
flutter build apk --flavor demo --dart-define=APP_ENV=demo
```

Demo artifacts contain synthetic data and are not for clinical use. Production
variants are disabled and production builds are rejected.

### Lint / analyze

```bash
flutter analyze
```

---

## 🗺️ Screens & Routes

The app uses `go_router`. All routes except `/login` and `/camera` are wrapped in
the `AppShell` (persistent navigation rail).

| Route | Screen | In nav rail | Rail order |
|-------|--------|:-----------:|:----------:|
| `/login` | LoginScreen | — | — |
| `/dashboard` | DashboardScreen | ✅ | 0 |
| `/patients` | PatientsScreen | ✅ | 1 |
| `/diagnosis` | DiagnosisScreen (Input Data / Hasil Analisis views — no visible tab bar) | ✅ | 2 |
| `/validation` | ValidationScreen | ✅ | 3 |
| `/dataset` | DatasetScreen | ✅ | 4 |
| `/sync` | SyncCenterScreen | ✅ | 5 |
| `/account` | AccountScreen | ✅ | 6 |
| `/camera` | CameraScreen | — (full screen) | — |

**Primary flow:** `Login → Dashboard → Screening → (Camera) → Hasil Analisis`, with
`Patients`, `Validation`, `Dataset`, `Sync`, and `Account` reachable any time from
the rail. The standalone `/result` route was merged into `/diagnosis` as a second
internal view, reachable only automatically (analysis success switches to it;
confirming "Screening Baru" switches back) — there is no visible tab bar, though
swiping the body still moves between the two views and is blocked into Hasil
Analisis until a real outcome exists. See
`lib/features/diagnosis/presentation/diagnosis_screen.dart`.

Internal route/class/API identifiers retain `diagnosis` for compatibility;
user-facing terminology is screening.

---

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── app/
│   ├── app.dart                 # MaterialApp.router + providers
│   └── router/app_router.dart   # go_router config (ShellRoute + routes)
├── core/
│   ├── theme/app_theme.dart     # Colors, spacing, typography, component themes
│   ├── config/                  # app_config.dart (env/flavor gates), scroll_behavior.dart
│   └── connectivity/            # Real online/offline detection (Sync Center, model update)
├── data/                        # Repository implementations
│   ├── mock/
│   ├── http/
│   ├── local/                   # Drift database, settings store
│   ├── offline/                 # Durable offline-first repositories + sync queue
│   ├── sync/                    # SyncEngine (push/pull protocol)
│   ├── secure/                  # Platform secure token storage
│   ├── onnx/                    # On-device inference engine, chain executor, segmentation overlay
│   └── models_ota/              # Signed model-bundle download/verify/activate/rollback pipeline
├── domain/                      # Models and repository contracts
├── state/                       # Provider ChangeNotifiers
│   ├── auth_provider.dart
│   ├── dashboard_provider.dart
│   └── diagnosis_provider.dart
└── features/                    # One folder per feature, screen in presentation/
    ├── auth/          · login_screen.dart
    ├── dashboard/     · dashboard_screen.dart
    ├── patients/      · patients_screen.dart
    ├── diagnosis/     · application/xray_image_picker.dart,
    │                    presentation/diagnosis_screen.dart (tab host, no visible TabBar),
    │                    presentation/widgets/diagnosis_input_tab.dart,
    │                    presentation/widgets/diagnosis_result_tab.dart
    ├── camera/        · application/xray_capture_processor.dart, presentation/camera_screen.dart
    ├── validation/    · validation_screen.dart
    ├── dataset/       · dataset_screen.dart
    ├── sync/          · sync_center_screen.dart (real model-update card + data-backup card)
    ├── account/       · account_screen.dart
    └── shared/presentation/
        ├── app_shell.dart       # Navigation rail + shell
        └── widgets/             # Reusable: AppCard, StatusBadge, SectionHeader, EmptyState
```

### Conventions
- **One screen = one file** under its feature's `presentation/` folder.
- **Never hardcode hex** in a widget — use `AppTheme.*` tokens or `Theme.of(context)`.
- Prefer `const` constructors; extract sub-widgets that grow beyond ~100 lines.
- Repository binding is configured in `lib/app/app.dart`; mock data lives in `lib/data/mock/`.

---

## 🧩 How the "AI" & "Sync" work today

**AI screening** (`HybridDiagnosisRepository`) tries the on-device path first,
falling back only when no verified model bundle is installed:

1. **On-device (real)** — `OnnxInferenceEngine` runs the installed ONNX bundle
   against the captured X-ray, producing a verdict, confidence, and (if the
   bundle supports it) a lung/lesion segmentation overlay with a per-class
   area-percentage legend, shown in Hasil Analisis.
2. **HTTP fallback** — `HttpDiagnosisRepository` sends image bytes to
   `/diagnoses/infer`. Clinical form metadata is not yet submitted by that call.
3. **Mock fallback** — `MockDiagnosisRepository` returns a randomized outcome,
   clearly marked as demo/non-clinical in the UI.

Camera and gallery supply real image bytes in every case; a real image alone
does not make the HTTP/mock paths clinically real.

**Model update** (Sync Center) is a real pipeline, not a timer: `ModelUpdateService`
checks `/models/check`, and on update `ModelUpdatePipeline` downloads the bundle,
verifies its Ed25519 signature against a pinned public key plus every file's
SHA-256 checksum, activates it, runs a smoke test, and automatically rolls back
on any failure. This runs even in demo/mock mode (`HybridSyncRepository`) — only
the medical-data **backup** half of Sync Center stays simulated/offline-queued
there.

---

## 🛣️ Roadmap

- [x] Partial HTTP backend integration: auth, image inference, patient/sync repositories.
- [x] Drift local storage and offline queue foundation.
- [x] Real camera capture and gallery input.
- [x] On-device ONNX inference with lung/lesion segmentation overlay.
- [x] Signed model-bundle OTA pipeline (download/verify/activate/rollback).
- [x] Unit/widget/golden tests (167 non-golden + 1 golden passing as of this writing).
- [ ] Non-mock dashboard/dataset APIs and full durable validation flow verified end to end.
- [ ] Production-safe auth/session/cache handling and reliable offline recovery.
- [ ] Device integration tests and production flavor/release safety gates.

> The two **companion roles** — *Admin RS* and *Super Admin* — are **separate web
> repositories** and are not part of this app.

---

## 🤝 Contributing

1. Fork & branch from `main` (`git checkout -b feature/my-change`).
2. Keep changes UI-only for now; follow the [conventions](#conventions) above.
3. Run `flutter analyze` and make sure it is clean before opening a PR.
4. Open a pull request describing the change and any screens affected.

---

## 📄 License

No license file is currently included. Add one (e.g. MIT) before publishing if you
intend the code to be reused.

---

<sub>Built with Flutter · Material 3 · technical demo, not a clinical release.</sub>
