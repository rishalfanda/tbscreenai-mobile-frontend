# Teknisi pada tablet dokter yang sama (PR #37)

Kontrak backend: PR #37, head `650c3054c3353f020046d4c4c0976a1b382ca599`, merged sebagai `3e587fad520e44a57f9c185b1f726abdbfc35b9c`. Dokumen ini menggantikan batas Models/Sync dalam catatan integrasi PR #36.

## Alur aplikasi

1. Administrator menerbitkan kode aktivasi tablet. Pada layar login, buka **Aktivasi tablet** dan masukkan kode langsung di perangkat. Nonce retry dan kredensial perangkat disimpan di secure storage; tidak masuk SQLite, log, atau UI.
2. Login dokter. Antrean data klinis tetap dimiliki dokter. Saat beralih akun/logout atau login setelah restart, pekerjaan yang belum selesai disegel dalam outbox perangkat terenkripsi sebelum cache akun dibersihkan.
3. Login teknisi pada tablet yang sama. Headers perangkat ikut login/refresh sehingga sesi terikat pada tablet tersebut.
4. **Models**: periksa kebijakan versi server, download bundle yang disetujui, verifikasi, aktivasi, dan smoke test. Versi model berlaku per perangkat dan tetap tersedia setelah pergantian akun. Kegagalan tidak dinyatakan sukses.
5. **Sync**: setelah konfirmasi operator, kirim antrean melalui `POST /sync/operator/push`, dengan `owner_user_id` dokter asli dan `client_op_id` yang sama pada retry. Teknisi tidak memakai `/sync/push` atau `/sync/pull` dokter.
6. Citra diagnosis dikirim setelah record diterima, menggunakan `/blobs/init`, chunk, dan complete. Antrean baru dihapus setelah record dan citra yang diperlukan dikonfirmasi server. Retry upload memakai chunk yang sudah diterima.
7. Konflik/kegagalan disimpan terenkripsi. Ketika dokter asal kembali login, antrean dan snapshot miliknya dipulihkan untuk koreksi; pengguna lain tidak menerima cache klinisnya.

## Batas keamanan dan perilaku

- Cache klinis yang terlihat tetap per akun. Outbox handoff disaring tenant, perangkat lokal, dan pemilik; plaintext tidak disimpan di settings. Tidak ada pengambilan semua data RS melalui akun teknisi.
- Identitas tablet dan operator pada respons operator harus cocok; hasil per item diperiksa terhadap operasi dan pemilik asal. Respons sesi lama tidak boleh menghapus antrean.
- Unduhan model memakai token/kredensial hanya untuk origin API dan namespace `/api/vN/models/`. Redirect ditolak untuk download terautentikasi. URL CDN menggunakan client tanpa kredensial API.
- Pembaruan ditolak jika aplikasi tidak didukung atau server tidak mengizinkan update. Receipt aktivasi/versi terpasang diperiksa sebelum notifikasi sukses.
- Teknisi tetap tidak boleh inferensi, membuat diagnosis lewat endpoint klinis, atau melakukan validasi AI. Manajemen tetap ditunda.
- Pengelolaan akun dokter dan dataset dari integrasi PR #36 tetap tersedia.

## Pengujian dan build

```powershell
flutter analyze --no-pub lib test
flutter test
flutter test test/staging_technician_navigation_test.dart test/staging_doctor_navigation_test.dart test/operator_sync_test.dart test/operator_model_update_test.dart --flavor staging --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://synthetic.invalid/api/v1
flutter build apk --release --split-per-abi --flavor staging --dart-define=APP_ENV=staging --dart-define=USE_HTTP=true --dart-define=API_BASE_URL=https://tbscreen.145-79-15-162.sslip.io/api/v1
```

Flavor tetap **staging**, termasuk pada build release. Konfigurasi signing proyek saat ini memakai debug key untuk distribusi uji internal; ini bukan rilis produksi.

## Prasyarat uji live

Pada pemeriksaan awal 30 Oktober 2026, endpoint operator belum terlihat. Pada pemeriksaan ulang di sesi yang sama, `/api/v1/sync/operator/push` sudah muncul dan menolak permintaan tanpa perangkat terdaftar dengan `401 device_required`. Cek model stable untuk aplikasi `1.0.0` menjawab 200, versi `2026.09.04`, update tersedia dan URL bundle tersedia. Ini belum membuktikan migrasi/SHA deployment, instalasi model, atau uji operator terautentikasi pada tablet.

Prasyarat berikutnya adalah kode aktivasi tablet uji dari administrator/backend. Masukkan kode langsung pada tablet; jangan kirim kredensial perangkat ke Git/chat.

Pemeriksaan read-only tambahan pada model `2026.09.04`: signature 64-byte SHA256SUMS cocok dengan pinned public key APK; checksum manifest cocok; schema manifest 1 didukung APK. Bundle berukuran 504.175.256 byte. Pemeriksaan ini tidak mengunduh semua model, tidak mengaktifkannya, dan tidak menjalankan smoke test/inferensi. Record yang sudah diterima server tetapi citranya belum dikonfirmasi tetap dipertahankan dalam outbox untuk upload teknisi.

Tes lokal memakai data sintetis dan respons API terkontrol. Uji operator live, pemasangan bundle server sesungguhnya, dan uji tablet fisik belum boleh dianggap lolos hanya berdasarkan merge, build APK, atau tes emulator.
