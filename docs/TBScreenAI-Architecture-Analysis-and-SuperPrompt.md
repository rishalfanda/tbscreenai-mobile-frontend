# TBScreenAI — Analisis Arsitektur & Super Prompt untuk Claude Code

Dokumen ini berisi (1) analisis proyek berdasarkan kondisi kode aktual, (2) evaluasi terhadap 6 goal yang diajukan, dan (3) super prompt siap-pakai untuk sesi Claude Code berikutnya. Tidak ada kode yang diubah untuk menghasilkan dokumen ini — murni analisis, sesuai permintaan.

## 1. Apa proyek ini

TBScreenAI adalah aplikasi tablet untuk skrining tuberkulosis (TB) berbasis analisis citra rontgen dada, ditujukan untuk dokter di rumah sakit (role "Doctor"). Repo ini hanya mengurus role Doctor; role Admin RS (web) dan Super Admin (web) berada di repo terpisah yang belum terlihat dari sini. Alur inti: dokter memotret/mengunggah rontgen, sistem menjalankan inferensi AI (saat ini disimulasikan), hasil divalidasi oleh dokter, lalu data pasien/diagnosis dapat disinkronkan ke server saat online.

## 2. Kondisi aktual (dari pemeriksaan repo)

Stack: Flutter (SDK ^3.11.4), go_router 15.1.2, provider 6.1.2. Hanya dua dependency runtime di `pubspec.yaml` — tidak ada `camera`, `http`, `dio`, `sqflite`, `hive`, atau `shared_preferences` terpasang, meskipun `CLAUDE.md` menyebut `camera: ^0.10.6` sebagai bagian stack. Ini gap nyata: `CameraScreen` kemungkinan besar masih UI placeholder tanpa akses kamera sungguhan.

Struktur mengikuti pola feature-first (`lib/features/<nama>/presentation/...`), state di `lib/state/` (baru ada `auth_provider`, `dashboard_provider`, `diagnosis_provider` — belum lengkap untuk semua 8 screen). Semua data mock terpusat di `lib/data/` (546 baris gabungan `mock_data.dart`, `dataset_mock.dart`, `validation_mock.dart`). Routing sudah rapi: `ShellRoute` untuk 8 screen ber-NavRail, redirect guard berbasis `AuthProvider.isLoggedIn`.

Belum ada: layer repository/service (abstraksi antara UI dan data source), model domain (data class untuk Patient/Diagnosis/dll — kemungkinan masih `Map` mentah di mock), lapisan penyimpanan lokal (tidak ada DB karena memang dilarang di fase ini), dan tentu saja backend (tidak ada folder `server/`, `api/`, atau konfigurasi client HTTP).

Kesimpulan kondisi: ini murni UI/UX prototype fase "hardcoded mock", secara sengaja dan konsisten dengan `CLAUDE.md`. Fondasi navigasi & tema sudah solid; fondasi arsitektur data (repository pattern, model layer, dependency injection yang jelas) belum ada — ini jadi pekerjaan rumah sebelum backend bisa disambungkan.

## 3. Evaluasi terhadap 6 goal

Konteks tambahan dari Anda: backend Python/FastAPI, model AI TB belum ada (backend hanya perlu expose kontrak API/mock terlebih dulu), target deployment multi-RS multi-tenant di cloud, satu backend dipakai bersama oleh role Doctor/Admin RS/Super Admin, dan timeline solo developer — backend fitur umum dalam 1 minggu, penyempurnaan frontend "sampai lusa" (~2 hari).

Catatan realitas timeline (harus disampaikan jujur, bukan basa-basi): backend multi-tenant + auth + sync engine + kontrak API untuk 3 role berbeda, dikerjakan solo dalam 1 minggu, hanya realistis kalau cakupan "fitur umum" dibatasi ketat ke MVP (auth, CRUD pasien/diagnosis, endpoint sync, kontrak AI mock) — bukan full multi-tenancy production-grade dengan isolasi data RS yang teraudit. Frontend "sampai lusa" (2 hari) hanya cukup untuk polish, bukan untuk membangun ulang layer data (repository/model) dari nol sambil menyambung backend baru. Rekomendasi: goal 2 (arsitektur frontend) dan sebagian goal 4 dieksekusi paralel/tumpang-tindih minggu ini, sedangkan goal 5 (testing) dan hardening offline-sync (goal 6) realistisnya jadi iterasi minggu berikutnya, bukan bagian dari 2 hari pertama.

Berikut breakdown per goal:

**Goal 1 — Tablet Android app.** Sudah pada rel yang benar: target Android tablet landscape 10–12", breakpoint ≥1024px sudah ada di aturan layout. Yang hilang: `camera` package belum terpasang, permission Android (`AndroidManifest.xml`) untuk kamera & storage belum dikonfigurasi, dan belum ada validasi build APK/App Bundle release (signing config, ProGuard/R8 rules).

**Goal 2 — Sempurnakan arsitektur frontend.** Ini prasyarat teknis sebelum backend bisa disambung, bukan pekerjaan kosmetik. Yang perlu ditambahkan: (a) model domain immutable (Patient, Diagnosis, SyncStatus, dll) menggantikan `Map` mentah di mock; (b) repository interface (`PatientRepository`, `DiagnosisRepository`, `SyncRepository`) dengan implementasi mock saat ini, siap diganti implementasi HTTP nanti tanpa mengubah UI; (c) service layer untuk offline queue (antrian aksi yang menunggu sync); (d) state management yang konsisten — provider sudah dipakai, pastikan setiap screen device punya provider-nya, bukan campur state lokal dan global; (e) error/loading state standar (bukan ad-hoc per screen).

**Goal 3 — Analisis kebutuhan backend.** Kebutuhan minimum: auth (login dokter, kemungkinan role-based karena backend dipakai bersama Admin RS/Super Admin), manajemen pasien, manajemen diagnosis/hasil skrining, endpoint inferensi AI (kontrak saja dulu — terima gambar, kembalikan hasil mock terstruktur), endpoint sync (push data lokal → server, pull update model AI/versi), audit log (karena ini data medis), dan multi-tenancy (isolasi data per RS). Karena "satu backend untuk semua role", desain API dan skema DB harus mengakomodasi permission per role sejak awal, bukan ditambal belakangan.

**Goal 4 — Bangun & sempurnakan backend.** FastAPI + PostgreSQL (cocok untuk multi-tenant relational + row-level security), Alembic untuk migration, JWT untuk auth, struktur multi-tenant via `tenant_id`/`hospital_id` di setiap tabel (bukan skema-per-tenant, supaya solo developer tidak kewalahan operasionalnya). Kontrak AI dibuat sebagai interface terpisah (mis. `POST /diagnoses/{id}/infer`) supaya saat model AI sungguhan siap, hanya implementasi di baliknya yang berubah.

**Goal 5 — Skenario testing.** Empat lapis: (a) unit test Flutter untuk provider/repository (mock repository, verifikasi state transitions); (b) widget test untuk komponen kritis (form consent backup, state machine ModelUpdateCard/DataBackupCard yang sudah didefinisikan di `CLAUDE.md`); (c) integration test end-to-end alur utama (login → diagnosis → hasil → sync); (d) backend: unit test tiap endpoint + test khusus isolasi tenant (pastikan RS A tidak bisa lihat data RS B) + test idempotency sync (retry tidak menduplikasi data).

**Goal 6 — Offline-first, online hanya untuk sync.** Ini pengaruh besar ke arsitektur, bukan detail kecil: butuh local storage (akan perlu `sqflite` atau `drift` — ini berarti keluar dari batasan "no local DB" yang berlaku di fase UI-only saat ini; perlu keputusan eksplisit kapan fase itu berakhir), sync queue dengan status per record (`pending`/`synced`/`conflict`/`failed`), strategi resolusi konflik (last-write-wins vs manual review — untuk data medis, manual review lebih aman), dan indikator UI yang jujur soal status sync per data (bukan cuma toggle online/offline global).

## 4. Rekomendasi urutan kerja

Urutan yang disarankan, mengikuti dependensi teknis (bukan urutan permintaan Anda apa adanya): dulukan model domain + repository interface di frontend (fondasi wajib), paralel dengan desain skema DB backend; baru backend endpoint dibangun mengikuti kontrak repository frontend supaya tidak ada rework; local storage & sync queue menyusul setelah backend endpoint sync stabil; testing berjalan menempel di tiap lapis begitu selesai, bukan di akhir sebagai fase terpisah.

## 5. Asumsi yang dibuat (mohon dikoreksi jika salah)

Backend akan pakai PostgreSQL (bukan MySQL/lainnya) — pilihan default paling umum untuk FastAPI + multi-tenant. Multi-tenancy pakai kolom `tenant_id` bersama (shared schema), bukan skema/DB terpisah per RS — lebih sesuai kapasitas solo developer. Auth pakai JWT stateless, bukan session server-side. Local storage Flutter pakai `drift` (SQLite dengan type-safety) bukan raw `sqflite` — lebih aman untuk sync queue kompleks, tapi ini bisa diganti kalau Anda sudah punya preferensi. Model AI TB sungguhan di luar scope backend ini — backend hanya menyediakan kontrak endpoint yang bisa diisi model beneran nanti.

---

## 6. Super Prompt — siap ditempel ke Claude Code

Salin blok di bawah ini sebagai prompt awal sesi Claude Code Anda.

```
Saya sedang mengembangkan TBScreenAI, aplikasi tablet Android untuk skrining TB (role Doctor) berbasis Flutter. Ada dua repo terkait: repo ini (Flutter frontend, sudah ada, fase UI-only dengan mock data) dan backend baru yang perlu dibangun dari nol (Python/FastAPI). Backend ini akan dipakai bersama oleh 3 role: Doctor (repo ini), Admin RS (web, repo terpisah), Super Admin (web, repo terpisah) — jadi desain API dan skema DB harus role-aware sejak awal, bukan ditambal belakangan.

KONTEKS PROYEK (baca CLAUDE.md di root repo Flutter untuk detail lengkap: color system, layout rules, screen directory, spec SyncCenterScreen). Poin penting yang harus dipatuhi:
- 8 screen ber-NavRail (dashboard, patients, diagnosis, result, validation, dataset, sync, account) + login + camera tanpa NavRail.
- Semua state via provider, routing via go_router dengan ShellRoute.
- Style: card border-radius 16, elevation 2, padding 24; warna selalu lewat Theme/AppColors, tidak boleh hardcode hex.
- Saat ini SEMUA data adalah mock (lib/data/). Backend akan menggantikan mock ini secara bertahap tanpa mengubah kontrak yang dilihat UI kalau repository pattern diterapkan dengan benar.

TIMELINE & SCOPE (solo developer): backend MVP dengan fitur umum dalam 1 minggu; penyempurnaan frontend dalam ~2 hari. Karena ini agresif, JANGAN coba build semuanya sekaligus — ikuti urutan fase di bawah, dan di setiap fase konfirmasi ke saya scope minimum yang realistis sebelum lanjut ke fase berikutnya.

FASE 1 — Fondasi arsitektur frontend (prasyarat wajib sebelum sentuh backend):
1. Buat model domain immutable untuk Patient, Diagnosis, ScreeningResult, SyncQueueItem, ModelVersion, dll — menggantikan Map mentah di lib/data/mock_data.dart, dataset_mock.dart, validation_mock.dart. Pertahankan semua data mock yang ada, hanya ubah representasinya.
2. Buat repository interface (abstract class) per domain: PatientRepository, DiagnosisRepository, SyncRepository, AuthRepository. Implementasikan versi Mock* yang mengembalikan data yang sama seperti sekarang (Future.delayed tetap dipertahankan untuk AI/sync simulation).
3. Suntikkan repository via provider (bukan langsung import mock_data di screen). Setiap screen/provider bergantung ke interface, bukan implementasi.
4. Jangan ubah UI/visual apa pun di fase ini — murni refactor layer data. Jalankan flutter analyze setelah tiap langkah, pastikan tidak ada regresi.

FASE 2 — Desain & scaffold backend (FastAPI):
1. Setup FastAPI + PostgreSQL + SQLAlchemy + Alembic. Struktur: app/api/ (routers per resource), app/models/ (SQLAlchemy), app/schemas/ (Pydantic), app/services/, app/core/ (config, security).
2. Auth: JWT (access + refresh token), role-based (doctor, admin_rs, super_admin), tenant_id (hospital) melekat di setiap user dan setiap record data medis.
3. Endpoint MVP: auth (login/refresh), patients (CRUD, scoped by tenant_id), diagnoses (CRUD + status), diagnosis inference (POST endpoint yang menerima gambar, mengembalikan hasil MOCK terstruktur — jangan implementasi model AI sungguhan, itu di luar scope), sync (push local changes, pull server changes + pull versi model AI terbaru).
4. Middleware/dependency yang memastikan setiap query otomatis di-scope ke tenant_id user yang login — cegah kebocoran data antar RS di level kode, bukan cuma di query manual.
5. Tulis OpenAPI schema (otomatis dari FastAPI) sebagai kontrak yang akan dipakai frontend.

FASE 3 — Sambungkan frontend ke backend:
1. Buat implementasi Http*Repository yang mengimplementasikan interface dari Fase 1, memanggil endpoint dari Fase 2. Tambahkan dependency http/dio HANYA di fase ini (sebelumnya dilarang sesuai CLAUDE.md fase mock).
2. Tambahkan mekanisme toggle: repository provider harus bisa switch antara Mock* dan Http* (untuk keperluan development/demo tanpa backend hidup).

FASE 4 — Offline-first & sync engine:
1. Tambahkan local storage (rekomendasi: drift/SQLite) untuk cache read + antrian tulis (sync queue) dengan status pending/synced/conflict/failed per record.
2. Implementasikan SyncCenterScreen sesuai state machine yang sudah didefinisikan di CLAUDE.md (ModelUpdateCard dan DataBackupCard) — sambungkan ke endpoint sync backend, bukan lagi Future.delayed murni.
3. Strategi konflik: untuk data medis, tandai sebagai conflict dan minta review manual dokter, jangan auto-overwrite.

FASE 5 — Testing:
1. Frontend: unit test repository (mock vs kontrak interface), widget test untuk state machine SyncCenterScreen dan consent dialog DataBackupCard, integration test alur login→diagnosis→result→sync.
2. Backend: unit test tiap endpoint, test isolasi tenant (RS A tidak bisa akses data RS B — wajib, ini data medis), test idempotency endpoint sync (retry request yang sama tidak menduplikasi data).
3. Laporkan test yang di-skip atau tidak bisa dijalankan (mis. karena butuh device kamera fisik) alih-alih diam-diam melewatinya.

ATURAN KERJA:
- Kerjakan satu fase sampai selesai dan terverifikasi (flutter analyze / pytest hijau) sebelum lanjut ke fase berikutnya.
- Jangan hardcode hex color di widget Flutter — selalu lewat Theme/AppColors sesuai CLAUDE.md.
- Jangan tambah dependency di luar yang disebutkan tanpa konfirmasi ke saya dulu.
- Kalau scope 1 minggu (backend) atau 2 hari (frontend) ternyata tidak cukup untuk fase yang sedang dikerjakan, katakan secara eksplisit apa yang harus dipotong, jangan diam-diam mengurangi kualitas atau melewati test.
- Mulai dari FASE 1. Tunggu konfirmasi saya sebelum mulai FASE 2.
```

---

## 7. Reminder tugas terbengkalai / gap yang perlu diputuskan

Tiga hal ini menahan progres kalau tidak diputuskan sekarang: kapan tepatnya fase "UI-only, no backend, no local DB" di `CLAUDE.md` dianggap berakhir (karena Fase 3–4 di atas melanggar batasan itu secara sengaja dan perlu update `CLAUDE.md`); apakah repo Admin RS/Super Admin sudah ada kontrak API atau ekspektasi skema DB yang perlu diselaraskan sebelum backend ini dirancang; dan package `camera` yang disebut di `CLAUDE.md` tapi tidak ada di `pubspec.yaml` — perlu dipastikan apakah CameraScreen memang belum pakai kamera sungguhan atau ada dependency yang belum ter-commit.

## 8. Self-improvement note

Bagian tersulit dari permintaan ini adalah menyeimbangkan cakupan (backend multi-tenant lengkap) dengan timeline (1 minggu solo). Pendekatan yang saya pakai: pisahkan "apa yang diminta" dari "apa yang realistis dalam waktu itu", lalu sampaikan keduanya secara eksplisit alih-alih hanya mengikuti permintaan apa adanya. Untuk sesi berikutnya, kalau timeline serupa muncul lagi, lebih baik menanyakan definisi "fitur umum" secara konkret di awal (daftar endpoint spesifik) daripada menerka — itu akan mempertajam super prompt lebih jauh.
