# Integrasi teknisi backend PR #36

Kontrak yang digunakan: backend PR #36 (merged), head `a605a92fda583a63d1032b55a91835d12772aaf9`, merge `1c5226026c7fe21de3bc33864eb1805cb9a3a763`.

## Perilaku APK

- Role `technician` berasal dari login server dan tetap terikat tenant akun. Tidak ada pemilihan tenant live atau pemetaan `admin_rs` menjadi teknisi.
- Menu teknisi: ruang kerja, pengguna, dashboard baca, dataset, account. Screening, validasi, camera, models/device, dan sync ditolak oleh router; tidak hanya disembunyikan dari menu.
- Pengguna: daftar dengan pencarian, filter aktif/nonaktif dan pagination; detail sebelum edit; tambah/edit dokter; aktif/nonaktif melalui PATCH; reset password. Teknisi tidak mengubah akunnya sendiri atau role selain dokter. Tidak ada DELETE pengguna.
- Password sementara dari create/reset hanya ditampilkan di dialog sekali; tidak ditulis ke settings, DB, log, atau clipboard otomatis. Dialog menyembunyikan password ketika sesi berubah.
- Login dengan `must_change_password=true` hanya dapat membuka halaman ganti password. POST `/auth/change-password` memvalidasi identitas respons dan memasang token pengganti; respons sesi sebelumnya ditolak. Password baru 8 karakter sampai 72 byte UTF-8, berbeda dari password lama.
- Dataset teknisi: daftar/cari/detail/item, buat/edit, arsip/buka kembali, hapus koleksi, pilih hasil screening dari API dan tambah/keluarkan item. Menghapus koleksi/item tidak menghapus screening asal. Dataset dokter tetap mengikuti alur baca yang sudah diterima sebelumnya. Ekspor belum diintegrasikan dalam perubahan ini.
- Semua request menggunakan ApiClient yang sama, termasuk autentikasi dan penolakan respons sesi lama. Tenant di respons pengguna/dataset diperiksa sebelum ditampilkan. Error tidak diganti data demo.
- Bahasa ID/ENG tetap tersedia; manajemen tetap ditunda. Mode demo tetap menggunakan data sintetis terpisah.

## Build dan pengujian

```powershell
flutter analyze --no-pub lib test
flutter test
flutter test test/staging_technician_navigation_test.dart test/staging_doctor_navigation_test.dart test/technician_integration_test.dart test/role_navigation_test.dart --flavor staging --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://synthetic.invalid/api/v1
flutter build apk --debug --flavor staging --dart-define=APP_ENV=staging --dart-define=USE_HTTP=true --dart-define=API_BASE_URL=https://tbscreen.145-79-15-162.sslip.io/api/v1
```

Tes menggunakan respons HTTP sintetis dan database memory. Ini bukan bukti E2E terhadap akun staging, perangkat tablet atau model klinis.

## Prasyarat tes live

Pada pemeriksaan 30 Oktober 2026, `GET /api/v1/users?limit=1` tanpa autentikasi di host staging menjawab **404**. OpenAPI yang disajikan belum memuat `/api/v1/users` maupun `UserOut.must_change_password`. Merge PR saja belum membuktikan deployment.

Tim backend perlu deploy commit yang mencakup PR #36 beserta migrasi `b7e2c4a9d150`, lalu menyediakan akun teknisi staging sesuai instansi. Jangan mengirim password akun melalui Git atau log pengujian.

Setelah deploy: cek OpenAPI dan SHA deployment, login teknisi pada APK, buat akun dokter uji, ganti password sementara pada login dokter, tes edit/nonaktif/reset, dan baca ulang data server. Verifikasi juga tenant isolation dan bahwa teknisi ditolak pada screening/validation/sync. Gunakan data sintetis; jangan klaim E2E sebelum langkah ini dibuktikan.
