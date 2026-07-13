# TBScreen.AI — Flutter Tablet App (Doctor Role)

## Project Identity
Medical AI tablet app for tuberculosis (TB) screening via chest X-ray image analysis.
This repo = DOCTOR role only (tablet app).
Other roles: Admin RS (web, separate repo), Super Admin (web, separate repo).

## Tech Stack
- Flutter + Dart (SDK ^3.11.4)
- go_router: ^15.1.2 — ShellRoute for NavRail persistence
- provider: ^6.1.2 — state management
- camera: ^0.10.6 — chest X-ray capture
- Material Design 3 (useMaterial3: true)

## Current Phase
UI-ONLY. No backend, no API calls, no HTTP, no Firebase, no Supabase, no SQLite.
All data: hardcoded mock in lib/mock/ or inline in screen.
AI simulation: Future.delayed(Duration(seconds: 3)).
Sync simulation: Future.delayed(Duration(seconds: 2)) with mock version data.

## Testing Environment
Running on: flutter run -d chrome (web/desktop browser preview)
Reason: No tablet emulator hardware available.
Final deploy target: Android tablet, landscape orientation, 10–12 inch screen.

---

## Layout Rules
- Always use LayoutBuilder; breakpoint ≥ 1024px = tablet layout
- NavRail: 80px wide, bg #1E3A5F, fixed left via Row in AppShell
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
| /diagnosis | DiagnosisScreen | Yes | 2 |
| /camera | CameraScreen | No (full screen) | - |
| /result | ResultScreen | Yes | 3 |
| /dataset | DatasetScreen | Yes | 4 |
| /sync | SyncCenterScreen | Yes | 5 |
| /account | AccountScreen | Yes | 6 |

NavRail icons (in order):
0: Icons.dashboard_rounded
1: Icons.people_rounded
2: Icons.medical_services_rounded
3: Icons.analytics_rounded
4: Icons.folder_rounded
5: Icons.cloud_sync_rounded
6: Icons.person_rounded

---

## SyncCenterScreen — Spec Detail

### Purpose
Allow doctor to: (1) check & update AI model version, (2) optionally backup medical data to server.
Offline-first: app works without internet. Sync is always user-initiated, never automatic.

### Layout (tablet landscape)
```
AppShell(navIndex: 5)
└── SingleChildScrollView
    └── Column
        ├── Header Row
        │   ├── Text "Sync Center" (titleLarge)
        │   └── Chip: status koneksi (Online/Offline, icon dot)
        └── Row(crossAxisAlignment: start, gap: 24)
            ├── Expanded — ModelUpdateCard
            └── Expanded — DataBackupCard
```

### ModelUpdateCard — States & UI
State machine: idle → checking → upToDate | updateAvailable → downloading → done | error

- **idle**: Button [Periksa Pembaruan Model], info versi saat ini, last checked timestamp
- **checking**: CircularProgressIndicator + "Memeriksa server..."
- **upToDate**: Icon check_circle hijau + "Model sudah versi terbaru (v{current})"
- **updateAvailable**: 
  - Badge chip "Versi Baru Tersedia"
  - Tabel: Versi Saat Ini vs Versi Baru, Ukuran File, Tanggal Rilis
  - Ekspandable changelog (mock: list string)
  - Row buttons: [Perbarui Sekarang] (primary) + [Lewati] (outlined)
- **downloading**: LinearProgressIndicator + persentase + ukuran downloaded
- **done**: Snackbar "Model berhasil diperbarui ke v{new}"
- **error**: Icon error merah + pesan + Button [Coba Lagi]

Mock data for update:
```dart
const mockModelUpdate = {
  'currentVersion': 'v1.2.0',
  'latestVersion': 'v1.3.1',
  'fileSize': '47.2 MB',
  'releaseDate': '10 Juni 2025',
  'changelog': [
    'Peningkatan akurasi deteksi TB aktif sebesar 3.2%',
    'Perbaikan false positive pada pasien pediatrik',
    'Optimasi kecepatan inferensi pada perangkat low-end',
  ],
};
```

### DataBackupCard — States & UI
Sifat: opsional penuh. Data medis sensitif — perlu consent eksplisit sebelum upload.

- **idle**: 
  - Warning chip merah: "⚠ Data Medis Sensitif"
  - Summary mock: "32 Pasien · 89 Diagnosis · ~128 MB"
  - Button [Pilih Data & Unggah]
  - Last sync info: timestamp atau "Belum pernah disinkronkan"
- **consent dialog** (muncul saat tombol ditekan):
  - AlertDialog, tidak bisa dismiss klik luar
  - Teks penjelasan perlindungan data (singkat)
  - Checkbox: "Saya menyetujui pengiriman data medis ke server"
  - Buttons: [Batal] + [Lanjutkan] (disabled sampai checkbox dicentang)
- **selection** (setelah consent):
  - List pasien mock dengan Checkbox per baris
  - Button [Pilih Semua] / [Batal Pilih]
  - Footer: "X pasien dipilih" + Button [Mulai Unggah]
- **uploading**: LinearProgressIndicator + "Mengunggah X/Y pasien..."
- **done**: Summary: X berhasil, Y gagal. Tombol [Coba Ulang Gagal] jika ada.
- **error / offline**: Pesan "Tidak ada koneksi internet. Hubungkan perangkat dan coba lagi."

---

## Code Rules
- Extract reusable widgets ke lib/widgets/
- Use const constructors wherever possible
- Theme-driven: Theme.of(context), never hardcoded hex in widget files
- Mouse hover (web preview): MouseRegion + AnimatedContainer
  GUARD PATTERN (wajib): if (!mounted) return; sebelum setState di onEnter/onExit
- No hardcoded strings in UI — gunakan variable atau constants file
- Comment sections: // === Section: SectionName ===
- One screen = one file. Sub-widgets boleh di file terpisah jika >100 baris.

## Packages FORBIDDEN in this phase
http, dio, supabase, firebase_core, sqflite, hive, shared_preferences
(Semua data = mock. Sync = simulasi Future.delayed)

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

---

## File Structure Convention
```
lib/
├── main.dart
├── app_theme.dart          ← color & typography constants
├── router.dart             ← go_router config, semua routes
├── screens/
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── patients_screen.dart
│   ├── diagnosis_screen.dart
│   ├── camera_screen.dart
│   ├── result_screen.dart
│   ├── dataset_screen.dart
│   ├── sync_center_screen.dart   ← NEW
│   └── account_screen.dart
├── widgets/
│   ├── app_shell.dart      ← NavRail + ShellRoute wrapper
│   ├── nav_rail.dart
│   └── [reusable widgets]
└── mock/
    └── mock_data.dart      ← semua mock data terpusat
```
