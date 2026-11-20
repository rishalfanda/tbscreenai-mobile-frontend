# Integrasi tablet backend 537dc90 — 4 November 2026

**Pembaruan 5 November:** penggabungan PR #7 dijelaskan pada
[APK gabungan PR #7 dan backend 537dc90](combined-pr7-backend537.md).
Pernyataan basis/PR terpisah di bawah adalah snapshot APK 4 November.

Target: backend `537dc904b2c2099ebab97a10fb41df35b0c9a09d` (merge PR #39).
Basis frontend: `9a80a53`, branch revisi alur 2 November. PR frontend #7
masih terpisah; integrasi ini tidak menggabungkan branch `mlops`.

## Kontrak dan perubahan APK

- Aktivasi tetap wajib sebelum login. Header registrasi tablet dikirim pada
  login, refresh dan request terautentikasi, baik dokter maupun teknisi.
- Penolakan memakai `detail.code`. `account_disabled`, `session_ended`, dan
  `device_session_required` mengakhiri sesi tanpa mencoba refresh yang sia-sia.
  `device_pending`, `device_revoked`, `device_required`, dan
  `device_unauthenticated` juga menutup akses dan mengembalikan form aktivasi.
  Registrasi yang ditolak dibersihkan dari secure storage; antrean terenkripsi,
  identitas pemilik data dan kunci gambar tetap dipertahankan. Reactivation
  memerlukan kode baru dari admin; aplikasi tidak mengaktifkan tablet sendiri.
- Setelah pemulihan sesi, perubahan koneksi ke online atau aplikasi kembali
  aktif, `/auth/me` diperiksa. Timeout/koneksi gagal tidak menghapus izin offline.
  Token kedaluwarsa tetap mengikuti mekanisme refresh server yang sudah ada.
- Skor 0–10 adalah kepercayaan dokter terhadap hasil AI: 0 tidak percaya,
  10 sangat percaya. Konfirmasi mengirim skor, keputusan `agreed`/`disagreed`,
  waktu validasi dan catatan. Tidak setuju tetap membutuhkan catatan.
- Operator mengirim PNG overlay lesi tersimpan ke
  `PUT /diagnoses/{id}/heatmap`. Receipt harus cocok dengan diagnosis,
  SHA-256 dan ukuran lokal. `created: false` diterima sebagai retry idempoten.
  Kegagalan/409/receipt salah menahan antrean; ACK record disimpan agar retry
  media tidak mengirim record ulang. Overlay paru dan X-ray tetap disimpan lokal;
  endpoint heatmap membawa overlay lesi dari inference yang sama.
- Receipt operator menyimpan `op_version` sebagai baseline snapshot lokal.
  `server_version` yang lebih baru tidak dipakai sebagai baseline edit lama.
  Receipt tanpa versi ditahan dari edit klinis sampai snapshot server dibaca.
- Setelah pengiriman, `/sync/operator/state` diminta untuk ID yang dipegang
  perangkat, maksimal 500 ID per jenis per request. Respons lengkap, tenant,
  ID, relasi pasien/diagnosis dan pemilik diagnosis diperiksa sebelum cache diubah.
  Snapshot diterima server diperbarui dengan versi dan validasi server untuk
  ditampilkan saat dokter masuk lagi. Gambar lokal terenkripsi tetap tersedia.
  Edit yang belum terkirim/konflik tidak ditimpa atau dinaikkan baseline-nya.
- Tombstone `deleted` menghapus cache yang diterima server dan mencegah pasien
  beserta diagnosisnya dipulihkan. Jika masih ada edit antrean, arsipnya ditahan
  sebagai konflik `server_deleted`, tanpa menampilkan kembali pasien yang dihapus.
  `not_found` tidak menghapus pekerjaan yang masih mengantre.
- Cache yang telah diterima server tidak dimasukkan kembali ke antrean hanya
  karena dokter logout. Perubahan klinis baru tetap menjadi op baru.

## Verifikasi

OpenAPI live `https://tbscreen.145-79-15-162.sslip.io/openapi.json` diperiksa
pada 4 November 2026: endpoint operator state, `op_version`/`server_version`,
receipt heatmap dan aturan skor sudah tersedia. Ini membuktikan kontrak yang
disajikan, bukan SHA proses server atau uji akun/perangkat fisik.

Tes regresi menggunakan DB memory, gambar sintetis, HTTP adapter dan secure
storage memory. Kasus mencakup late retry, baseline lama, validasi server terbaru,
heatmap retry, tombstone, not-found, tenant lain, sesi dicabut, serta timeout offline.
Tes otomatis, analyzer dan build staging dilaporkan bersama artefak APK.

Hasil lokal: 334 tes umum lolos (3 dilewati); 79 tes konfigurasi staging lolos;
`flutter analyze --no-pub lib test` bersih. Schema live `OperatorPushResult`,
`OperatorStateRequest`, `OperatorStateResponse`, `OperatorStateGone` dan
`HeatmapOut` identik dengan dokumen OpenAPI pada commit backend target.

## Uji tim pada tablet

1. Instal APK staging sebagai pembaruan; jangan clear app data agar antrean lokal tetap ada.
2. Aktivasi/login dokter, putus jaringan, lakukan screening dan validasi berskor.
3. Logout, login teknisi pada tablet yang sama, jalankan Sync dengan jaringan aktif.
4. Baca ulang record, citra dan receipt heatmap di server; pemilik asli tetap dokter.
5. Login dokter lagi: gambar lokal tetap dapat dibuka, nilai/versi server terlihat,
   dan cache yang telah diterima tidak dihitung sebagai antrean baru.
6. Dengan data sintetis, uji perubahan server, penghapusan pasien dan pencabutan
   akun/tablet. Uji live ini belum diklaim selesai oleh tes lokal.
