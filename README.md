# TBScreen.AI — Tablet App (Doctor Role)

> AI-assisted tuberculosis (TB) screening from chest X-ray images, built for medical tablets.

TBScreen.AI is a **Flutter tablet application** for the **doctor role** in a TB
screening workflow. A clinician can register a patient, capture or upload a chest
X-ray, run an (simulated) AI analysis, review the result, validate the AI's
prediction, manage training datasets, and sync the model — all from a single
tablet-optimized interface.

> **Current status (31 August 2026): technical demo with partial backend integration,
> not a clinical release.** Default builds use mock repositories. With
> `USE_HTTP=true`, auth and inference use HTTP while patients/sync use offline
> repositories; dashboard, validation and datasets still use mocks.
> See the [current handoff status](docs/handoff/STATUS_2026-08-31.md) for verified
> changes and remaining limitations. Historical UI descriptions below are not
> evidence of end-to-end persistence or clinical readiness.

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
| 🩺 **Diagnosis** | Multi-section intake form (basic info, symptoms, clinical background, bacteriology, TB status) + X-ray upload/capture, then runs a simulated AI analysis. |
| 📷 **Camera** | Full-screen capture UI with framing guides, flash & camera-switch controls. |
| 🧾 **Result** | AI verdict card (positive / normal), confidence, recommendations, patient & clinical summary, export/print actions. |
| ✅ **Validation** | Doctor reviews AI results case-by-case, agrees/disagrees with a clinical note, auto-advances through the queue. |
| 🗂️ **Dataset** | CRUD over training datasets and their images (list / create / detail / edit, with confirm dialogs). |
| ☁️ **Sync Center** | Offline-first model-update flow and consent-gated medical-data backup (both simulated). |
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
- **crypto** — SHA-256 image checksum. Exact resolved versions are in `pubspec.lock`.

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
flutter run -d <device>
```

**HTTP mode on Android emulator (requires a running local backend):**

```bash
flutter run -d emulator-5554 --dart-define=USE_HTTP=true --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

These are build-time settings, not remote config. HTTP mode does not remove all
mock screens and is not sufficient to make a production-safe build.

### Build a demo artifact

```bash
flutter build web       # or: flutter build apk / appbundle
```

Without explicit configuration these commands retain mock mode, even in release.
Do not distribute them for clinical use; production flavor and safety gates remain open.

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
| `/diagnosis` | DiagnosisScreen | ✅ | 2 |
| `/result` | ResultScreen | ✅ | 3 |
| `/validation` | ValidationScreen | ✅ | 4 |
| `/dataset` | DatasetScreen | ✅ | 5 |
| `/sync` | SyncCenterScreen | ✅ | 6 |
| `/account` | AccountScreen | ✅ | 7 |
| `/camera` | CameraScreen | — (full screen) | — |

**Primary flow:** `Login → Dashboard → Screening → (Camera) → Result`, with
`Patients`, `Validation`, `Dataset`, `Sync`, and `Account` reachable any time from
the rail.

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
│   └── config/scroll_behavior.dart
├── data/                        # Repository implementations
│   ├── mock/
│   ├── http/
│   ├── local/
│   ├── offline/
│   └── sync/
├── domain/                      # Models and repository contracts
├── state/                       # Provider ChangeNotifiers
│   ├── auth_provider.dart
│   ├── dashboard_provider.dart
│   └── diagnosis_provider.dart
└── features/                    # One folder per feature, screen in presentation/
    ├── auth/          · login_screen.dart
    ├── dashboard/     · dashboard_screen.dart
    ├── patients/      · patients_screen.dart
    ├── diagnosis/     · diagnosis_screen.dart
    ├── camera/        · camera_screen.dart
    ├── result/        · result_screen.dart
    ├── validation/    · validation_screen.dart
    ├── dataset/       · dataset_screen.dart
    ├── sync/          · sync_center_screen.dart
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

Default mock mode simulates long-running operations:

- **AI screening** → a randomized outcome from `MockDiagnosisRepository`; this is not a clinical model result.
- **Model update / data backup** → timed progress with mock version data (`SyncCenterScreen`).

In HTTP mode `HttpDiagnosisRepository` sends image bytes to `/diagnoses/infer`.
Clinical form metadata is not yet submitted by that inference call. Camera and
gallery supply real bytes; a real image alone does not make mock inference real.

---

## 🛣️ Roadmap

- [x] Partial HTTP backend integration: auth, image inference, patient/sync repositories.
- [x] Drift local storage and offline queue foundation.
- [x] Real camera capture and gallery input.
- [x] Unit/widget/golden tests (50 passing on 31 August 2026).
- [ ] Non-mock clinical inference and full durable screening/validation flow verified end to end.
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

<sub>Built with Flutter · Material 3 · UI-only prototype.</sub>
