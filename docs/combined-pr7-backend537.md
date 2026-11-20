# APK gabungan PR #7 + backend 537dc90 — 5 November 2026

Basis integrasi backend: `f64011b` pada `feat/backend537-tablet-compat`.
PR #7 sudah masuk `main` sebagai `71786b8` dengan head tim `d456721`.
Merge pada branch integrasi ini menggabungkan keduanya tanpa mengubah backend.

## Hasil penggabungan

- Lifecycle model dari PR #7: katalog model, download, checksum/signature dan
  smoke test, aktivasi eksplisit, serta penghapusan dengan kandidat verified
  terbaru. Kandidat gagal tidak ditinggalkan aktif. Jika tidak ada kandidat
  siap, tidak ada model aktif.
- Dokter harus memiliki model aktif sebelum login. Aturan yang sama diterapkan
  saat memulihkan sesi dokter setelah restart. Tanpa model, sesi ditutup,
  antrean tetap diarsip terenkripsi, dan aplikasi meminta bantuan teknisi.
  Login teknisi tidak membutuhkan model. Standby hanya untuk dokter;
  pause/logout melepaskan sesi native dan resume memuat ulang sesuai role.
- Alur revisi 2 November tetap dipakai: aktivasi sebelum login, sesi dokter
  offline, screening langsung berisi data pasien, penyimpanan hasil otomatis
  ke lokal, dan daftar validasi dengan gambar/segmentasi serta skor dokter.
  Navigasi tetap dibatasi per role pada menu dan router.
- Integrasi backend 537dc90 tetap dipakai: penolakan sesi terstruktur, cek sesi
  saat koneksi pulih/resume, heatmap teknisi dengan receipt, baseline op_version,
  state/tombstone cache dan perlindungan antrean yang belum terkirim.
- Live inference tetap on-device; kegagalan atau ketiadaan model tidak berpindah
  ke mock atau inferensi server. Mode demo tetap terpisah.
- Download dari URL eksternal memakai Dio tanpa kredensial. ApiClient berisi
  token dan header tablet hanya dipakai pada jalur bundle API yang sesuai origin
  dan prefix model. Regression test memeriksa header request ke server lokal.
- Tombol kamera menggunakan posisi kanan-tengah dari PR #7; konfirmasi gambar
  tetap di sisi kanan saat landscape. Kontras dan lokalisasi hasil dari PR #7
  digabungkan dengan layout/alur lokal yang sudah dipakai sebelumnya.

## Bukti lokal

- 393 tes non-golden lolos, 5 dilewati (tes khusus staging dan golden terpisah).
- 86 tes konfigurasi staging lolos, termasuk integrasi aktivasi/model/backend.
- Golden diagnosis 1900×982 lolos dengan baseline yang sudah ada; tidak ada
  regenerasi baseline untuk menutupi perbedaan.
- Analyzer bersih. Pemeriksaan build_runner dilakukan sebelum packaging.
- OpenAPI live diperiksa ulang 5 November: OperatorPushResult,
  OperatorStateRequest/Response/Gone dan HeatmapOut sama dengan backend target.

Lingkungan lokal memakai Flutter 3.44.7/Dart 3.12.2. CI PR #7 memakai Flutter
3.47.1. Lockfile hasil merge dipertahankan sesuai sumber tim; resolusi paket
lokal mengikuti pin SDK lokal untuk pengujian/build. Jangan menyamakan bukti
lokal ini dengan CI untuk commit gabungan atau uji tablet fisik.

## Pemeriksaan tim setelah instal update

1. Jangan uninstall/clear data jika ada antrean yang belum terkirim.
2. Tanpa model aktif, dokter ditolak; teknisi tetap bisa masuk.
3. Teknisi mengunduh/verifikasi model lalu mengaktifkannya secara eksplisit.
4. Dokter login, screening dan validasi berskor saat offline; pause/resume tidak
   menghilangkan hasil lokal.
5. Teknisi mengirim record, X-ray dan heatmap; login dokter berikutnya memuat
   versi/status server tanpa mengganti pemilik atau menimpa edit yang tertunda.

APK adalah staging dengan konfigurasi signing debug yang sudah ada. Paket ini
belum membuktikan uji akun live, model klinis, perangkat fisik atau kesiapan produksi.
