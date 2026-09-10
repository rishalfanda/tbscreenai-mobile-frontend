# Review frontend TBScreenAI — 9 September 2026

> Update 10 September 2026: perbaikan F01–F03 telah diimplementasikan dan diverifikasi dengan test lokal. Lihat [P0_FIXES_2026-09-10.md](P0_FIXES_2026-09-10.md). Isi dan hasil baseline di bawah adalah bukti historis sebelum perbaikan, bukan status test terbaru. Temuan lain tetap terbuka.

**Verdict: Request changes. Layak sebagai demo teknis terbatas; belum memenuhi gate untuk pemakaian klinis.**

Repo: `C:\Users\devel\tbscreenai-mobile-frontend`, HEAD `2a23c8b`. Flutter 3.44.7 / Dart 3.12.2, Windows. Review menggunakan checklist `ecc:flutter-dart-code-review` dan `engineering:code-review`: correctness, security/session, state/lifecycle, kontrak API, database offline, UI, testing, dan konfigurasi platform.

Scope mencakup inventaris 73 file Dart non-generated, seluruh 10 route, semua layer repository/provider, schema Drift dan generated code, konfigurasi Android/iOS/web, dependency lockfile, serta CI. Pembacaan mendalam dan test tambahan difokuskan pada jalur yang membawa data pasien, auth, inference, sync dan hasil. Backend lokal dibaca untuk membandingkan kontrak, bukan diaudit/dijalankan ulang seluruhnya. Tidak ada klaim bahwa setiap kombinasi interaksi UI atau setiap perangkat sudah diuji.

Kode aplikasi tidak diperbaiki pada review ini. Tambahan hanya artefak `audit/`; perubahan pengguna pada `.claude/launch.json` dan `.hermes/` tetap dipertahankan. Tidak ada commit, push, perubahan backend, login produksi, atau data pasien nyata yang dipakai.

## Hasil verifikasi

| Pemeriksaan | Hasil aktual |
|---|---|
| `flutter analyze --no-pub` | PASS, no issues; diperiksa ulang setelah menambahkan test audit |
| `flutter test --no-pub --coverage --reporter expanded` | PASS, 50 test existing, termasuk golden Windows |
| `dart run build_runner build` | PASS; generated Drift tidak menghasilkan diff |
| `flutter build apk --debug --no-pub` | PASS; APK debug 190.208.343 byte, konfigurasi default mock |
| Test regresi tambahan | **15/15 FAIL pada assertion perilaku aman**; mereproduksi isu terbuka, bukan compilation failure |
| Smoke seluruh route, 2 ukuran tablet | **16 PASS / 4 FAIL**; 3 lokasi overflow |
| `flutter pub outdated --no-dev-dependencies` | 4 direct dependency tertinggal; tidak di-upgrade |

15 test gagal dikelompokkan menjadi 12 temuan fungsi/security, ditambah 1 temuan layout: **13 kelompok temuan: 3 P0, 8 P1, 2 P2**. Prioritas mengikuti definisi backlog frontend: P0 termasuk risiko salah atribusi hasil, hasil demo yang tampak klinis, dan kebocoran data lintas sesi. Ini prioritas penyelesaian sebelum release, bukan klaim insiden produksi.

Coverage baseline yang terukur pada LCOV, tanpa `.g.dart`: **1.341 / 3.871 executable lines = 34,6%**. Ini line coverage test lokal, bukan persentase kesiapan produk.

| Area | Covered / instrumented lines | Coverage |
|---|---:|---:|
| app | 52 / 87 | 59,8% |
| core | 81 / 101 | 80,2% |
| data | 193 / 549 | 35,2% |
| domain | 83 / 116 | 71,6% |
| features | 862 / 2.857 | 30,2% |
| state | 70 / 161 | 43,5% |

Kedua `Offline*Repository` memiliki **0 covered lines** pada baseline; `ApiClient` 17/47 dan `AuthProvider` 2/12. Test yang berjudul retry di `test/sync_engine_test.dart` mengubah status failed menjadi pending secara manual. Aplikasi tidak memiliki aksi pemulihan setara. Karena itu 50 test hijau belum membuktikan retry operasional.

## Temuan yang direproduksi

### F01 — P0 / Cara coding: hasil lama tetap menempel ke draft pasien yang berubah

Lokasi: [diagnosis_provider.dart:182](C:/Users/devel/tbscreenai-mobile-frontend/lib/state/diagnosis_provider.dart:182), [diagnosis_provider.dart:202](C:/Users/devel/tbscreenai-mobile-frontend/lib/state/diagnosis_provider.dart:202), [result_screen.dart:98](C:/Users/devel/tbscreenai-mobile-frontend/lib/features/result/presentation/result_screen.dart:98).

Hasil dan identitas pasien dibaca dari dua state terpisah: `lastOutcome` dan draft yang masih dapat diedit. `_replace()` tidak menginvalidasi hasil. `resetForNewDiagnosis()` juga tidak membatalkan atau mengabaikan request lama.

Reproduksi **R05**: inference untuk A sukses, ganti nama ke B; outcome A masih ada. **R06**: mulai inference, reset, selesaikan Future lama; outcome lama muncul lagi. Result membaca nama/umur dari draft terbaru, sehingga berpotensi menampilkan skor lama sebagai milik pasien baru. Navigasi melalui rail atau tombol New Screening dashboard tidak otomatis membuat snapshot hasil baru.

Perbaikan: buat examination/result immutable yang menyertakan identitas pasien, snapshot form dan identitas/checksum gambar; invalidasi hasil saat draft berubah dan gunakan request generation/cancellation agar completion lama tidak dapat mengisi state baru. Kaitkan ke FE-002/FE-004.

### F02 — P0 / Arsitektur: data pasien bertahan atau muncul lagi setelah pergantian sesi

Lokasi: [app.dart:106](C:/Users/devel/tbscreenai-mobile-frontend/lib/app/app.dart:106), [http_auth_repository.dart:45](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/http/http_auth_repository.dart:45), [offline_patient_repository.dart:33](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/offline/offline_patient_repository.dart:33).

Provider screening hidup di atas router dan tidak di-reset pada logout. Pembersihan database juga tidak mencegah respons request yang sudah berjalan menulis sesudah `clearAll()`. Schema cache tidak menyimpan owner/session/tenant untuk memfilter akses.

Reproduksi **R10** pada wiring aplikasi sesungguhnya, memakai auth mock: akun A mengisi nama pasien, logout, akun B login; nama A tetap ada. **R04** memakai SQLite in-memory dan respons HTTP tertunda: cache dibersihkan, respons dari sesi lama diterima; jumlah pasien kembali menjadi 1. Jalur logout HTTP menggunakan pembersihan database yang sama dengan skenario kedua. Tidak ada data/akun asli yang diuji.

Perbaikan: lifecycle provider per sesi, reset seluruh PHI saat logout, generation token/cancel untuk semua request, serta partition/cache ownership per user/tenant. Simpan dan validasi identitas session saat restore/login. FE-009/FE-010.

### F03 — P0 / Arsitektur: hasil mock yang sudah dihitung kehilangan penanda demo

Lokasi: [result_screen.dart:27](C:/Users/devel/tbscreenai-mobile-frontend/lib/features/result/presentation/result_screen.dart:27), [http_diagnosis_repository.dart:55](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/http/http_diagnosis_repository.dart:55), [app_config.dart:12](C:/Users/devel/tbscreenai-mobile-frontend/lib/core/config/app_config.dart:12).

Label `DUMMY / DEMO — BUKAN HASIL KLINIS` hanya tampil ketika outcome null. `MockDiagnosisRepository` menghasilkan skor acak, lalu halaman hasil menampilkannya tanpa label tersebut. HTTP mapping juga membuang `is_mock` yang tersedia dalam `InferenceResult` backend. `USE_HTTP` default false, termasuk build release tanpa konfigurasi eksplisit.

Reproduksi **R11**: jalankan mock inference lalu render Result; pencarian label demo menghasilkan nol widget. Ini berbeda dari fallback Result kosong yang sudah diberi label dengan benar.

Perbaikan: pertahankan provenance `is_mock` sampai UI, watermark permanen seluruh hasil demo, dan fail-closed production flavor. FE-001; status demo sudah diakui README, tetapi belum dijaga aplikasi.

### F04 — P1 / Cara coding: gambar pada hasil bukan gambar yang dianalisis

Lokasi: [result_screen.dart:86](C:/Users/devel/tbscreenai-mobile-frontend/lib/features/result/presentation/result_screen.dart:86), [xray_preview.dart:36](C:/Users/devel/tbscreenai-mobile-frontend/lib/features/shared/presentation/widgets/xray_preview.dart:36).

`XrayPreview` selalu memakai `assets/images/xray_sample.png`. Result tidak meneruskan bytes/file dari draft. Komponen yang sama dipakai Patients dan Validation. Reproduksi **R15**: lampirkan gambar khusus pasien dan outcome, render Result; tidak ada `MemoryImage`, preview tetap asset contoh.

Perbaikan: preview menerima referensi gambar examination yang dianalisis; jika tidak tersedia, tampilkan status gambar tidak tersedia dan jangan menggantinya dengan citra pasien contoh. FE-003/FE-004.

### F05 — P1 / Cara coding: refresh cache menimpa edit pending dan menghapus record konflik

Lokasi: [app_database.dart:78](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/local/app_database.dart:78), [app_database.dart:110](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/local/app_database.dart:110), [app_database.dart:142](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/local/app_database.dart:142).

Queued ID hanya dikecualikan dari DELETE; `insertAllOnConflictUpdate(rows)` tetap menimpa baris dengan ID yang sama. Daftar protected IDs hanya status pending, sehingga failed/conflict dapat dibuang pada refresh berikutnya.

Reproduksi **R02**: baris `LOCAL EDIT` yang pending berubah menjadi `OLD SERVER`. **R03**: baris berstatus konflik hilang ketika snapshot kosong datang. Test existing hanya menguji baris pending yang tidak ada pada snapshot, sehingga tidak mencakup overwrite ID yang sama. Implementasi diagnosis cache memiliki pola serupa, tetapi R02/R03 secara langsung menguji patient cache.

Perbaikan: simpan server snapshot terpisah dari perubahan lokal atau merge dengan filter unresolved IDs sebelum upsert; lindungi pending/failed/conflict dan review sebelum rekonsiliasi. FE-007/FE-014.

### F06 — P1 / Cara coding: kegagalan jaringan mengeluarkan operasi dari jalur retry

Lokasi: [sync_engine.dart:144](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/sync/sync_engine.dart:144), [app_database.dart:131](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/local/app_database.dart:131).

Network error menandai semua operasi `failed`, sedangkan `push()` hanya membaca `pending`. **R01** memutus jaringan, memulihkannya, lalu memanggil push kedua tanpa manipulasi DB: 0 applied, bukan 1. Payload masih tersimpan di queue, tetapi tidak akan terkirim lewat retry yang tersedia. Backup ulang dapat membuat op ID baru; itu tidak memulihkan jaminan idempotensi operasi lama.

Perbaikan: retryable failure tetap eligible untuk retry dengan client_op_id yang sama; bedakan transient/permanent failure, backoff terbatas dan aksi retry eksplisit. FE-007.

### F07 — P1 / Kontrak/schema: frontend membuang version untuk optimistic locking

Lokasi: [tables.dart:5](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/local/tables.dart:5), [mappers.dart:8](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/local/mappers.dart:8), [sync_engine.dart:130](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/sync/sync_engine.dart:130).

Backend lokal mengembalikan integer `version` dan menerima `base_version`. Frontend tidak menyimpan atau meneruskannya; hanya timestamp. **R07** memasukkan version=7 dari server melalui mapper/cache, lalu menangkap push: `base_version` null. Backend masih mendukung fallback timestamp, sehingga request tidak otomatis 422. Namun fallback membandingkan pada ketelitian detik dan tidak dapat membedakan dua edit dalam detik yang sama; risiko ini dikonfirmasi dari source backend, bukan uji konkurensi backend hidup.

Perbaikan: migrasi schema untuk version, mapper lengkap, bawa base_version dari snapshot edit sampai queue dan push. FE-008.

### F08 — P1 / Cara coding: upload inference gagal sesudah refresh token berhasil

Lokasi: [api_client.dart:85](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/http/api_client.dart:85), [http_diagnosis_repository.dart:33](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/http/http_diagnosis_repository.dart:33).

Retry menggunakan RequestOptions dengan FormData yang sudah dikonsumsi. Dio terkunci versi 5.10.0 menolak finalize dua kali. **R13** memakai HTTP server loopback: infer pertama 401, refresh mengembalikan token valid, endpoint siap menerima retry 200; flow tetap menghasilkan false. Seluruh traffic hanya fixture lokal.

Perbaikan: rebuild/clone FormData dan MultipartFile sebelum replay, simpan request bytes yang sama, dan tambah regression test expired-token untuk multipart. FE-009.

### F09 — P1 / Cara coding: refresh token tidak dibatasi satu percobaan

Lokasi: [api_client.dart:66](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/http/api_client.dart:66).

Retry masuk lagi ke interceptor tanpa flag already-retried. **R12** mengembalikan 401 sebanyak tiga kali dan akhirnya 403 agar test selesai: terjadi 3 refresh, bukan maksimal 1. Apabila 401 terus terjadi, siklus dapat berulang. Bare Dio untuk refresh juga tidak membawa timeout client utama; refresh paralel tidak dikoordinasikan.

Perbaikan: single-flight refresh, flag batas retry per request, timeout eksplisit, dan propagasi session-expired ke AuthProvider. FE-009. Batas retry direproduksi; timeout/refresh paralel merupakan observasi source yang belum diuji tersendiri.

### F10 — P1 / Arsitektur: refresh token tersimpan sebagai teks SQLite biasa

Lokasi: [settings_store.dart:27](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/local/settings_store.dart:27), [tables.dart:88](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/local/tables.dart:88).

**R08** menyimpan token sintetis melalui TokenStore lalu membaca kembali `app_settings.refresh_token` sebagai string utuh. Database memakai driftDatabase tanpa enkripsi yang dikonfigurasi. Ini membuktikan plaintext at rest, bukan bahwa aplikasi lain dapat membaca sandbox Android tanpa akses tambahan. Nilai sebenarnya/credential user tidak dibaca.

Perbaikan: platform secure storage untuk token dan kebijakan at-rest/cache untuk PHI; pisahkan session dari device settings. FE-009/FE-010.

### F11 — P1 / Kontrak API: daftar pasien berhenti pada 100 record

Lokasi: [offline_patient_repository.dart:35](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/offline/offline_patient_repository.dart:35); pembanding backend [patients.py:49](C:/Users/devel/tbscreenai-backend/app/api/routes/patients.py:49).

Backend default `limit=100`, maximum 500, dengan offset. Frontend mengirim GET sekali tanpa pagination lalu memperlakukan hasil sebagai snapshot lengkap. **R14** menyediakan fixture berisi 101 pasien dengan default paging server: repository hanya mengembalikan 100. Pasien sisanya tidak dapat dicari dalam list; replace cache juga dapat membuang cached record di luar halaman tersebut.

Perbaikan: pagination lengkap atau UI paging/server search, jangan jalankan replacement snapshot dari satu halaman. Tambahkan acceptance dataset >100 dan >500 pasien pada FE-007/FE-019.

### F12 — P2 / Cara coding: respons push tidak lengkap dilaporkan tanpa masalah

Lokasi: [sync_engine.dart:150](C:/Users/devel/tbscreenai-mobile-frontend/lib/data/sync/sync_engine.dart:150).

`results` kosong/null dianggap daftar kosong. **R09** mengirim satu operasi lalu menerima HTTP 200 dengan results kosong: `hasProblems=false`, meskipun operasi tetap pending. Backend lokal normal menghasilkan result per item, jadi skenario ini menguji ketahanan terhadap response tidak lengkap/versi kontrak berbeda, bukan perilaku backend saat ini.

Perbaikan: cocokkan semua client_op_id sent vs returned; ID hilang/unknown/duplicate harus menghasilkan error protokol yang tidak terlihat sukses. FE-007.

### F13 — P2 / UI: tiga Row overflow pada ukuran tablet yang didukung

| Route | 1900×982 | 1024×768 | Source |
|---|---|---|---|
| /validation | overflow 4,8 px | overflow 4,8 px | [validation_screen.dart:191](C:/Users/devel/tbscreenai-mobile-frontend/lib/features/validation/presentation/validation_screen.dart:191) |
| /dashboard | pass | overflow 42 px | [dashboard_screen.dart:396](C:/Users/devel/tbscreenai-mobile-frontend/lib/features/dashboard/presentation/dashboard_screen.dart:396) |
| /dataset | pass | overflow 100 px | [dataset_screen.dart:83](C:/Users/devel/tbscreenai-mobile-frontend/lib/features/dataset/presentation/dataset_screen.dart:83) |

Tujuh route lainnya lolos smoke di kedua ukuran: login, patients, diagnosis, result fallback, sync, account, camera error fallback. Result dengan outcome diuji terpisah oleh baseline dan R11/R15 pada 1600×1000; hasil smoke /result tidak mewakili seluruh layout outcome. Kamera memakai fake `availableCameras=[]`, sehingga PASS berarti UI no-camera dapat dirender, bukan hardware capture lolos.

Perbaikan: gunakan constraints ruang yang tersisa setelah nav rail, Wrap/Flexible untuk title/actions/legend, dan simpan kedua ukuran sebagai regression layout. FE-020.

## Status seluruh fitur dan gap yang memang sudah dikenal

Gap berikut dikonfirmasi dari source dan sebagian sudah tercatat pada backlog. Tidak dihitung lagi sebagai temuan baru yang direproduksi di atas.

| Fitur | Implementasi yang ada | Gap / acceptance berikutnya |
|---|---|---|
| Login/session | HTTP login, token mirror DB, redirect auth | Role/profile tidak dimodelkan penuh pada AuthProvider; restore hanya memeriksa token nonempty; kegagalan refresh tidak mengubah isLoggedIn; tampilkan session-expired dan identitas yang benar |
| Dashboard | Provider + mock metrics/seed/chart | Selalu mock pada kedua mode; filter waktu/institusi hanya delay/loading, tidak mengambil data terfilter; greeting hardcoded |
| Patients | Offline read + background HTTP refresh | Paging F11; UI tidak subscribe perubahan cache sehingga background refresh tidak segera tercermin; empty/loading/network failure belum dibedakan |
| Screening form | Draft bersama, validasi UI, gallery/camera bytes, SHA-256, signature dan ukuran | Inference contract hanya menerima image; demografi, clinical metadata dan pilihan model tidak dikirim; runDiagnosis sendiri tidak memeriksa keseluruhan validasi draft |
| Camera/gallery | Plugins dan permission Android/iOS ada; controller di-dispose | Race lifecycle selama initialization perlu device test; gallery memakai image_picker, bukan picker berkas DICOM; signature Part-10 tidak berarti decode DICOM didukung |
| Result | Outcome di memory + ringkasan draft | Save/PDF/Print mempunyai callback kosong di result_screen.dart:431; tidak ada penulisan patient/diagnosis/result snapshot dari alur screening; restart kehilangan outcome |
| Validation | Selalu MockValidationRepository, UI agree/disagree + wajib note | submit hanya delay; verdict UI hilang saat remount; reset hanya setState. Selection/note dibaca lagi setelah await sehingga perpindahan kasus ketika submit berpotensi salah update UI; perlu test race dan integrasi durable FE-005 |
| Dataset | Selalu mock read; create/edit/delete di state halaman | Interface hanya getDatasets/getRecords, tidak punya write; download callback kosong; ID berbasis panjang list dapat bentrok sesudah delete; form controller dibuat di builder dan tidak disposed |
| Sync data | Queue, push/pull engine, consent UI, counts lokal | Temuan F05–F07/F11/F12; tidak ada UI conflict-resolution; push seluruh pending tidak dibatasi max 500 backend; pull engine tidak dipanggil oleh flow UI normal |
| Sync model | Check endpoint HTTP + simpan string version | downloadModel hanya timer lalu saveInstalledModelVersion; tidak mengunduh/verify/install binary. UI mengklaim update sukses. FE-011 |
| Account | Display name dari AuthProvider | Email/institusi/statistik hardcoded; Edit/Password/toggle tidak melakukan perubahan; 2FA switch ditampilkan true tanpa implementasi. FE-006/FE-012 |

Hal lain yang perlu ditutup: teks consent menyebut enkripsi end-to-end, sedangkan source hanya request Dio dengan base URL default HTTP dan tidak memiliki protokol E2EE; revisi klaim sesuai implementasi. Model update/check/upload tidak melengkapi catch/onError sehingga kegagalan dapat meninggalkan loading aktif. Initial avatar Patients mengakses `part[0]` dan Account `substring(0,2)` tanpa menangani nama kosong/1 huruf. Temuan-temuan source ini belum mendapat PoC terpisah pada review ini.

## Review schema dan kontrak

Drift `schemaVersion=1`, empat tabel, dan generated code sinkron dengan deklarasi. Tidak ada bukti mismatch generated code. Masalah ada pada field/semantik yang belum dimodelkan, bukan kegagalan code generation.

| Tabel | Key dan data inti | Kekurangan untuk alur yang diharapkan |
|---|---|---|
| LocalPatients | PK id; code, name, age, gender, status, confidence, lastVisit, JSON history, updatedAt, hasConflict | Tidak ada owner/tenant, server version, atau tombstone; unresolved edits tidak dilindungi dengan benar; domain Patient.id memakai code, UUID tidak dibawa ke domain |
| LocalDiagnoses | PK id; patientId, outcome, findings JSON, status/note, timestamps/conflict | patientId tidak dideklarasikan sebagai FK; tidak ada server version, creator, is_mock, image ref/checksum, snapshot clinical input; alur inference tidak menulis tabel ini |
| SyncQueue | PK clientOpId; entity/operation/payload JSON, baseUpdatedAt, status/detail/time | Tidak ada owner/tenant, base_version, retry count/next attempt; gagal tidak eligible retry; payload tanpa typed contract |
| AppSettings | PK key, value text | Token + profil + device facts bercampur; logout clearAll juga menghapus installed model version dan last sync perangkat |

Kolom enum/range (misalnya age, confidence, status) belum memiliki check constraints lokal; JSON juga tidak divalidasi schema DB. Karena setiap masukan tidak melewati DB validator, validasi perlu konsisten pada boundary domain/API. Migration test belum ada; saat menambahkan version/owner, naikkan schema version dan uji upgrade dari v1 dengan queued data yang belum terkirim.

Kontrak backend pembanding:

| API | Kompatibilitas saat ini |
|---|---|
| POST /auth/login, /auth/refresh | Token response cocok; user.id/tenant_id tidak dipertahankan frontend, role tidak dipakai guard |
| GET /patients | List JSON cocok, tetapi pagination hilang; version/tenant/deleted_at dibuang mapper |
| POST /diagnoses/infer | Multipart `image` dan skor/findings cocok; is_mock dibuang; tidak ada clinical metadata atau durable result dalam request ini |
| POST /diagnoses | Ada pada backend lokal; tidak dipanggil alur screening frontend |
| PATCH /diagnoses/{id}/status | Ada pada backend lokal; Validation masih mock |
| POST /sync/push | Nama field dasar cocok, fallback timestamp masih diterima; base_version/max500/result completeness belum ditangani |
| GET /sync/pull | Engine memakai full snapshot tanpa since, sehingga tidak sedang menggunakan delta tombstone; jangan menambahkan since tanpa implementasi delta-merge/deletion |
| GET /sync/model-version | Metadata cocok; download_url tidak digunakan untuk instalasi binary |

Backend yang dibaca adalah checkout lokal `C:\Users\devel\tbscreenai-backend`; kontrak deployment aktif belum diverifikasi. Backend memiliki perubahan dokumentasi pengguna yang tidak disentuh.

## Arsitektur, platform, dependency dan proses

- Fondasi yang baik: domain/repository terpisah, Provider injection memungkinkan test, login/inference punya penanganan error dasar, SHA-256/image format metadata tersedia, UUID operasi memakai Random.secure, dan CI memverifikasi generated Drift.
- Ownership lifecycle perlu diperjelas: GoRouter dibuat ulang pada setiap notify AuthProvider, DB dibuat di build bila tidak di-inject, provider DB/API tidak punya disposer. Jangan refactor massal sebelum state/session bugs ditutup.
- Lima screen besar: dataset 1.564, diagnosis 1.226, dashboard 918, sync 918, validation 902 baris. Prioritaskan pemisahan application logic, form state dan rendering setelah bug utama. Panjang file sendiri bukan bukti bug.
- Android main manifest sudah memiliki INTERNET dan CAMERA; activity sensorLandscape. iOS sudah punya deskripsi camera/photo library. Release Android masih `com.example.myapp` dan signing debug; ini belum build release terverifikasi. Web memiliki sqlite3.wasm/drift_worker.js; runtime web tidak diuji.
- CI existing menjalankan analyze, codegen dan functional tests di Linux, golden di Windows. Test audit di luar `test/` ini belum menjadi gate CI; butuh pemindahan/pemanggilan eksplisit pada pekerjaan remediasi. Tidak ada integration_test perangkat pada inventory.
- `pub outdated` saat review: camera 0.12.0+2 → 0.12.1; dio 5.10.0 → 5.11.1; drift 2.34.2 → 2.34.4; go_router 15.1.3 → 18.0.1 (perubahan constraint/major). Ini informasi versi, bukan bukti kerentanan. Tidak dilakukan upgrade, audit advisory CVE penuh, atau perubahan SDK.
- Penelusuran token/secret pada source menemukan implementasi token storage; tidak menyimpulkan seluruh git history bebas rahasia. Accessibility screen reader, text scaling, color contrast, performa profile/release dan perangkat kamera fisik belum diverifikasi.

## Urutan perbaikan

1. FE-001/002/004/009/010: provenance demo, snapshot hasil-pasien-gambar, reset/session ownership dan cancellation. Jadikan R04/R05/R06/R10/R11/R15 gate.
2. FE-007/008/014: queue retry, cache merge, version migration, pagination dan conflict resolution. Jadikan R01/R02/R03/R07/R09/R14 gate.
3. FE-009: secure token storage, single-flight bounded refresh dan multipart replay. Jadikan R08/R12/R13 gate.
4. FE-004/005/011/012: durable screening/validation, model install sungguhan atau disabled, hilangkan klaim/aksi palsu.
5. FE-019/020/021: 3 layout overflow, screen reader/text-scale checks, device camera, persistence/restart dan HTTP integration terhadap environment test terkontrol.

## Menjalankan ulang bukti

```powershell
cd "C:\Users\devel\tbscreenai-mobile-frontend"
& "C:\Users\devel\flutter\bin\flutter.bat" test --no-pub audit\frontend_regression_review_test.dart --reporter expanded
& "C:\Users\devel\flutter\bin\flutter.bat" test --no-pub audit\frontend_screen_smoke_test.dart --reporter expanded
```

Test regresi sengaja memeriksa perilaku yang seharusnya aman, sehingga tetap merah sampai bug diperbaiki. Tidak ada expected-failure/skip yang menyembunyikan hasilnya. Fixture menggunakan SQLite in-memory, data/token sintetis, fake adapter, dan HTTP loopback port acak; tidak memerlukan backend produksi. Camera smoke memalsukan tidak adanya kamera.

Raw output: [regression-results.txt](C:/Users/devel/tbscreenai-mobile-frontend/audit/regression-results.txt), [screen-results.txt](C:/Users/devel/tbscreenai-mobile-frontend/audit/screen-results.txt). Coverage baseline tersimpan di `coverage/lcov.info` dan APK debug di `build/app/outputs/flutter-apk/app-debug.apk` (keduanya ignored build artifacts).

Langkah review berikutnya di bawah 2 menit: buka F01–F03 dan jadikan tiga kelompok P0 tersebut prioritas tiket pertama; detail reproduksi sudah siap untuk coding partner.
