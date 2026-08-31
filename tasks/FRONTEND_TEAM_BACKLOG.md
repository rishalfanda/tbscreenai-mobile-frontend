# TBScreenAI — Backlog Tim Frontend Mobile

**Tanggal baseline:** 20 Agustus 2026

**Pemilik:** Flutter/Mobile Team

**Repositori:** `tbscreenai-mobile-frontend`

**Target:** Android tablet 10–12 inci, landscape

**Status aplikasi:** demo UI dengan sebagian integrasi backend; belum layak pilot klinis

Dokumen ini adalah backlog eksekusi frontend. ID `FE-*` wajib dipakai pada branch,
commit, PR, dan koordinasi dengan task backend `BE-*`.

## Batas kepemilikan tim frontend

Frontend memiliki kode Flutter, state/UI, local database, integrasi API, permission,
package metadata, dan test aplikasi. Tim frontend **tidak** menyimpan keystore
production, mengelola secret CI, menerbitkan APK/AAB, menjalankan release pipeline,
atau mendistribusikan aplikasi ke tablet; semuanya dimiliki tim deployment melalui
backlog `DE-*`.

## Aturan prioritas

| Prioritas | Makna |
|---|---|
| **P0** | Risiko hasil klinis palsu, kehilangan data, auth bypass, atau privacy leak. |
| **P1** | Alur utama rusak/tidak lengkap atau release belum aman. |
| **P2** | Kelengkapan fitur, UX, accessibility, dan maintainability. |
| **P3** | Optimasi setelah jalur klinis stabil. |

Ukuran: **XS** ≤ 1 hari, **S** 1–2 hari, **M** 3–5 hari, **L** > 1 minggu.

## Sprint 0 — Safety gate frontend

### FE-001 — Pisahkan flavor demo, staging, dan production

- **Prioritas / ukuran:** P0 / M
- **Masalah:** build tanpa `USE_HTTP` diam-diam memakai mock auth dan verdict TB acak.
- **Dependensi:** BE-001.
- **Acceptance criteria:**
  - Production tidak mengandung atau tidak dapat memilih mock repository.
  - Build gagal jika base URL/konfigurasi production tidak tersedia.
  - Demo memiliki watermark permanen `DEMO — HASIL TIDAK KLINIS`.
  - Nama package, app label, ikon, signing config, dan environment terpisah.
- **Verifikasi:** build ketiga flavor dan assert repository binding masing-masing.

### FE-002 — Jadikan diagnosis form satu source of truth

- **Prioritas / ukuran:** P0 / M
- **Masalah:** controller/dropdown lokal tidak pernah memanggil `updateBasicInfo`/`updateClinical`; Result membaca default provider.
- **Acceptance criteria:**
  - Buat immutable `DiagnosisDraft` dengan patient id, demografi, gejala, klinis, tes, dan image metadata.
  - Semua field mengubah draft yang sama; tidak ada default klinis yang menyamar sebagai input dokter.
  - Nama/patient, umur, gender, dan field wajib divalidasi sebelum inference.
  - Result menampilkan persis snapshot draft yang dikirim.
  - Back/edit mempertahankan draft; New Diagnosis membersihkan seluruh draft.
- **Verifikasi:** widget test isi nilai non-default → Result harus identik.

### FE-003 — Ganti placeholder dengan citra X-ray nyata

- **Prioritas / ukuran:** P0 / M
- **Dependensi:** backend upload validation sudah ada; lanjut BE-010 untuk penyimpanan.
- **Acceptance criteria:**
  - Integrasi `image_picker` dan/atau `camera` sesuai kemampuan tablet.
  - Byte asli, filename, MIME, checksum, ukuran, dan preview dibawa ke repository.
  - PNG/JPEG/DICOM yang didukung tervalidasi; file kosong/terlalu besar ditolak.
  - Placeholder hanya tersedia di flavor demo dan diberi watermark.
  - Permission denied/cancel/retry memiliki UX jelas.
- **Verifikasi:** integration test file nyata serta negative test format palsu.

### FE-004 — Simpan hasil diagnosis secara durable

- **Prioritas / ukuran:** P0 / L
- **Dependensi:** BE-005 dan BE-008.
- **Masalah:** tombol Save/PDF/Print aktif tetapi callback kosong; hasil hilang saat New Diagnosis.
- **Acceptance criteria:**
  - Setelah inference, hasil disimpan ke Drift sebagai draft/pending sebelum dapat ditinggalkan.
  - Save memanggil kontrak inference-provenance backend atau enqueue offline.
  - Status `unsaved`, `pending sync`, `saved`, `conflict`, `failed` terlihat jelas.
  - New Diagnosis meminta konfirmasi jika ada perubahan belum tersimpan.
  - PDF/Print disabled sampai implementasi dan audit policy tersedia.
- **Verifikasi:** restart/offline/retry tidak menghilangkan hasil diagnosis.

### FE-005 — Hubungkan validasi dokter ke backend/offline queue

- **Prioritas / ukuran:** P0 / M
- **Dependensi:** BE-009.
- **Masalah:** `MockValidationRepository` selalu dipakai dan verdict dibuang setelah animasi sukses.
- **Acceptance criteria:**
  - Implementasi HTTP/offline `ValidationRepository` memakai diagnosis nyata.
  - Agreed/disagreed disimpan lokal dahulu dan dikirim dengan `base_version`.
  - Disagreed wajib catatan; failure tidak menampilkan sukses palsu.
  - Reset status juga merupakan operasi durable dan diaudit.
  - Badge pending berasal dari database/API, bukan seed mock.
- **Verifikasi:** E2E agree/disagree/restart/offline/conflict.

### FE-006 — Hapus atau blokir aksi UI palsu

- **Prioritas / ukuran:** P0 / S
- **Cakupan:** Save, Export PDF, Print, Forgot Password, Edit Profile, Change Password, 2FA, notifikasi, dan action dataset yang belum nyata.
- **Acceptance criteria:** aksi belum tersedia disabled dengan label yang jujur; tidak ada `onPressed: () {}` pada kontrol yang terlihat aktif; CI/lint test mendeteksi no-op action kritis.

## Sprint 1 — Offline-first dan keamanan sesi

### FE-007 — Perbaiki retry dan state machine sync

- **Prioritas / ukuran:** P0 / M
- **Dependensi:** BE-004.
- **Masalah:** network failure mengubah `pending` menjadi `failed`, tetapi hanya `pending` yang dikirim ulang.
- **Acceptance criteria:**
  - State machine eksplisit: pending → sending → synced/conflict/retryable/permanent-failure.
  - Transient failure memakai exponential backoff + jitter dan tetap retryable.
  - Permanent validation failure memerlukan tindakan pengguna.
  - App restart melanjutkan antrean tanpa reset manual.
  - UI tidak mengklaim "tetap di antrean" bila status tidak akan diproses.
- **Verifikasi:** matikan jaringan saat push, restart app, hidupkan jaringan; item terkirim tepat sekali.

### FE-008 — Gunakan row `version` untuk optimistic locking

- **Prioritas / ukuran:** P0 / M
- **Dependensi:** BE-006 dan OpenAPI terbaru.
- **Acceptance criteria:**
  - Drift patient/diagnosis menyimpan `version` integer.
  - Sync queue menyimpan `base_version`; timestamp bukan sinyal utama.
  - Mapper pull/push membawa version tanpa kehilangan data.
  - Schema migration Drift aman untuk pengguna existing.
- **Verifikasi:** dua perangkat mengedit record sama; conflict selalu terdeteksi termasuk edit pada detik sama.

### FE-009 — Secure token storage dan session-expired flow

- **Prioritas / ukuran:** P0 / M
- **Dependensi:** BE-012.
- **Masalah:** access/refresh token disimpan plaintext di Drift; refresh failure tidak logout `AuthProvider` atau menutup cache PHI.
- **Acceptance criteria:**
  - Token pindah ke Android Keystore/iOS Keychain; tidak berada di SQLite/log.
  - Satu refresh request untuk 401 bersamaan; request lain menunggu hasilnya.
  - Refresh gagal memicu event logout terpusat, navigasi login, dan kebijakan cache yang eksplisit.
  - Offline access memerlukan local re-auth/PIN/biometric sesuai keputusan produk.
- **Verifikasi:** token tidak terlihat dalam DB dump; expired/revoked account tidak membuka cache tanpa local auth.

### FE-010 — Data ownership per user/tenant/device

- **Prioritas / ukuran:** P1 / M
- **Acceptance criteria:** database lokal di-scope/enkripsi per tenant/user; pergantian akun tidak mencampur cache/queue; logout menunggu clear/rekey selesai sebelum navigasi.
- **Verifikasi:** login tenant A → logout → tenant B tidak melihat data A.

## Sprint 2 — Jalur produk nyata

### FE-011 — Model update yang benar atau disabled

- **Prioritas / ukuran:** P1 / M
- **Dependensi:** endpoint artifact/checksum dari BE-011/BE-019.
- **Masalah:** progress saat ini hanya timer lalu menandai model yang tidak pernah diunduh sebagai installed.
- **Acceptance criteria:** sampai artifact tersedia tombol disabled; implementasi final melakukan download resumable, checksum/signature, ruang disk, atomic activation, rollback, lalu menyimpan versi.
- **Verifikasi:** corrupt/incomplete download tidak pernah menjadi versi aktif.

### FE-012 — Ganti Dashboard, Validation, Dataset, dan Account mock

- **Prioritas / ukuran:** P1 / L
- **Dependensi:** BE-016, BE-017, BE-018.
- **Acceptance criteria:** tidak ada nama `Dr. Anderson`, email, statistik, status 2FA, atau angka rumah sakit hardcoded pada flavor production; loading/empty/offline/error states tersedia.

### FE-013 — Perbaiki UX error inference

- **Prioritas / ukuran:** P1 / S
- **Masalah:** setelah inference gagal layar tetap navigasi ke Result dan `lastError` tidak ditampilkan.
- **Acceptance criteria:** navigasi hanya jika outcome valid; error tetap di layar diagnosis, menyebut tindakan yang bisa dilakukan, dan menyediakan retry tanpa kehilangan draft.

### FE-014 — Conflict-resolution workflow dokter

- **Prioritas / ukuran:** P1 / M
- **Dependensi:** FE-007/008 dan BE-004/006.
- **Acceptance criteria:** daftar conflict menampilkan nilai lokal vs server, tidak auto-merge data klinis, pilihan keep server/reapply/cancel diaudit, dan tidak ada overwrite diam-diam.

### FE-015 — PDF/print/export yang aman

- **Prioritas / ukuran:** P2 / M
- **Dependensi:** FE-004 dan BE-013.
- **Acceptance criteria:** hanya diagnosis saved dapat diekspor; provenance model, dokter, timestamp, patient identifier policy, watermark mock, dan audit event tercantum; share target dibatasi sesuai kebijakan PHI.

## Sprint 3 — Release quality

### FE-016 — Finalisasi Android release configuration

- **Prioritas / ukuran:** P1 / M
- **Dependensi:** DE-005.
- **Acceptance criteria:** frontend menetapkan applicationId, app label/icon, landscape policy, permission, network security config, dan versioning. Keystore, secret CI, signing, publishing, serta distribusi APK/AAB dimiliki tim deployment.
- **Verifikasi:** instal signed release pada tablet bersih dan jalankan login → infer → save → validate → sync.

### FE-017 — Global error reporting tanpa PHI

- **Prioritas / ukuran:** P1 / M
- **Acceptance criteria:** `FlutterError.onError`, `PlatformDispatcher.onError`, dan repository failures dilaporkan dengan redaction; tidak ada token, nama pasien, atau citra dalam crash report.

### FE-018 — Perketat static analysis

- **Prioritas / ukuran:** P2 / S
- **Acceptance criteria:** aktifkan strict-casts, strict-inference, strict-raw-types, unawaited_futures, avoid_catches_without_on_clauses, always_use_package_imports; seluruh lint suppression punya alasan.

### FE-019 — Test pyramid alur klinis

- **Prioritas / ukuran:** P1 / L
- **Acceptance criteria:**
  - Unit: state machine auth/sync/draft.
  - Widget: form → Result, validation, error, conflict, accessibility.
  - Integration: login → image nyata → infer → save → validate → offline sync.
  - Release smoke test pada emulator/tablet masuk CI atau release checklist.
  - Test tidak boleh memperbaiki state secara manual untuk membuat retry tampak berhasil.

### FE-020 — Accessibility dan responsive tablet QA

- **Prioritas / ukuran:** P2 / M
- **Acceptance criteria:** semantics/labels, keyboard/focus order, contrast, 48dp target, text scaling 200%, screen reader, 1280×800 dan 2560×1600 landscape, serta empty/error states lolos checklist.

### FE-021 — Performance dan lifecycle

- **Prioritas / ukuran:** P3 / M
- **Acceptance criteria:** profiling startup/frame jank/memory; gambar di-decode sesuai ukuran; subscription/controller selalu disposed; list besar lazy/paginated; tidak ada network/file work di `build()`.

## Definition of Done frontend

Task frontend belum selesai sebelum:

- `flutter analyze`, strict lints, unit/widget/integration test relevan hijau.
- Aksi klinis diuji pada build release, bukan hanya debug/widget test.
- Offline, restart, expired session, retry, dan conflict memiliki test.
- Tidak ada mock/no-op/hardcoded clinical data pada production flavor.
- Token/PHI tidak muncul di SQLite plaintext, log, screenshot test, atau crash report.
- API/schema change mengikuti OpenAPI terbaru dan dikoordinasikan dengan task BE terkait.
- Dokumentasi setup, run, dan batasan diperbarui dalam PR yang sama.

## Urutan eksekusi rekomendasi

`FE-001 → FE-002/003/004/005/006 → FE-007/008/009/010 → FE-011/012/013/014 → FE-016/017/018/019/020`

Frontend tidak boleh menyatakan "siap pilot" sebelum FE-001 s.d. FE-019 selesai dan checkpoint lintas tim lulus.

## Checkpoint lintas tim sebelum pilot

1. **Contract gate:** OpenAPI generated sama dengan backend runtime; mapper frontend diuji terhadap fixture kontrak.
2. **Clinical gate:** image nyata → inference non-mock → durable save → verdict dokter durable.
3. **Offline gate:** edit offline → restart → retry → idempotent sync/conflict handling.
4. **Security gate:** tenant isolation, secure token, session revoke, cache ownership, dan audit trail.
5. **Release gate:** signed release APK pada tablet bersih, backend production-like, seluruh mock dinonaktifkan.
