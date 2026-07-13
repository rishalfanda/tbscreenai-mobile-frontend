# TBScreen.AI — Tablet App (Doctor Role)

> AI-assisted tuberculosis (TB) screening from chest X-ray images, built for medical tablets.

TBScreen.AI is a **Flutter tablet application** for the **doctor role** in a TB
screening workflow. A clinician can register a patient, capture or upload a chest
X-ray, run an (simulated) AI analysis, review the result, validate the AI's
prediction, manage training datasets, and sync the model — all from a single
tablet-optimized interface.

> **Project status: UI / Front-end only.** There is **no backend yet** — every
> screen runs on hardcoded mock data, and AI / sync operations are simulated with
> timed delays. The app is structured so a real API can be dropped in later without
> reworking the UI. See the [Roadmap](#-roadmap).

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

No networking, database, or cloud packages are used in this phase (see [Roadmap](#-roadmap)).

---

## 🖥️ Screenshots

> Run the app (below) to view it live. The interface targets **landscape tablet**
> at **≥1024px** width. To capture screenshots, use Chrome DevTools device mode
> with a tablet profile (e.g. iPad Pro / Nexus 10, landscape).

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.x** (Dart `^3.11.4`)
- A browser (Chrome recommended) for the quickest preview, **or** an Android tablet / emulator

Verify your setup:

```bash
flutter --version
flutter doctor
```

### Install

```bash
git clone <your-repo-url>
cd myapp
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

### Build a release

```bash
flutter build web       # or: flutter build apk / appbundle
```

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

**Primary flow:** `Login → Dashboard → Diagnosis → (Camera) → Result`, with
`Patients`, `Validation`, `Dataset`, `Sync`, and `Account` reachable any time from
the rail.

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
├── data/                        # Mock data (no backend in this phase)
│   ├── mock_data.dart
│   ├── dataset_mock.dart
│   └── validation_mock.dart
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
- All mock data lives in `lib/data/` — swap these for API calls later.

---

## 🧩 How the "AI" & "Sync" work today

Because this is the UI phase, long-running operations are **simulated**:

- **AI diagnosis** → `Future.delayed(3s)` then a randomized mock outcome (`DiagnosisProvider`).
- **Model update / data backup** → timed progress with mock version data (`SyncCenterScreen`).

Each of these is isolated behind a provider or local state, so replacing the
simulation with a real HTTP call is a localized change.

---

## 🛣️ Roadmap

- [ ] **Backend integration** — replace `lib/data/` mocks with a REST/GraphQL client.
- [ ] Real chest X-ray AI inference endpoint.
- [ ] Real authentication & session handling.
- [ ] Persistent local storage / offline cache for true offline-first sync.
- [ ] Real camera capture pipeline (the `camera` package) on device.
- [ ] Automated widget/integration tests.

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
