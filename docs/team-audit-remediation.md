# Remediasi audit APK - 12 November 2026

Branch: feat/backend537-tablet-compat. Target: APK staging, API HTTP nyata.

## Perubahan

- Inferensi: alias lesi Indonesia/Inggris, termasuk infiltrat; persentase dari piksel lesi terhadap area paru. Output mask/manifest tidak valid gagal jelas, tidak diganti angka dummy.
- Provenance: schema_version, bundle_version, rf_model, inferred_at, image_sha256 dan probabilitas asli p_fused/p_cnn/p_rf yang tersedia. Nilai cabang yang tidak tersedia dihilangkan. lesion_confidence adalah rata-rata max-softmax piksel lesi dalam area paru. APP_VERSION opsional melalui dart-define.
- Sinkron teknisi: unggah X-ray asli lebih dahulu, lalu heatmap lesi dan lung-map. Setiap jenis memiliki ACK sendiri; gagal satu jenis tidak menghapus antrean. Endpoint lung-map diperiksa melalui OpenAPI. Refresh queue juga menyiapkan pemeriksaan ulang gambar arsip APK lama tanpa mengulang perubahan klinis.
- Backup & Restore: menu khusus teknisi; backup memakai versi record dan checksum, ditolak bila data/gambar belum tersinkron. Restore hanya pada perangkat kosong; checksum snapshot/gambar, tenant, perangkat dan pemilik dokter diperiksa. X-ray dan arsip dienkripsi lokal; dokter hanya memulihkan arsip miliknya. Impor memakai transaksi; kegagalan konfirmasi server setelah impor dapat dilanjutkan tanpa mengimpor dua kali. URL asing dan redirect download ditolak.
- Logout: POST /auth/logout memakai sesi lama tanpa refresh token; batas tunggu tiga detik. Pembersihan lokal tetap berjalan bila offline. Login baru menunggu proses logout selesai.
- Status pasien: hasil AI positif memberi status Suspected, bukan diagnosis pasti Positive. Hasil negatif tidak menurunkan status pasien yang sebelumnya Suspected/Positive.
- Konflik validasi: pertahankan lesion_rating dan tombstone server. Operasi lama yang hanya menyimpan skor harus diberi rating eksplisit oleh dokter. Reapply menggunakan versi terbaru; validasi yang sudah dihapus server tidak dihidupkan kembali. Dialog pemulihan tersedia dari halaman validasi.

## Pemeriksaan backend

OpenAPI live https://tbscreen.145-79-15-162.sslip.io/openapi.json pada 12 November 2026 sudah memuat PUT /api/v1/diagnoses/{diagnosis_id}/lung-map, /backups dan /restores/pending. /health menjawab ok. Pemeriksaan ini read-only; tidak ada sinkron pasien atau restore ke VPS selama pengujian lokal.

## Cara uji pada perangkat

1. Pasang APK sebagai update aplikasi staging yang sama; jangan uninstall/hapus data.
2. Masuk teknisi, buka Sync, Refresh queue, setujui sinkron lalu Sync to server. Arsip gambar lama yang belum memiliki ACK akan muncul sebagai pekerjaan sinkron.
3. Lakukan skrining sintetis baru; cek lesi dan provenance di server, lalu validasi/rating, edit dan hapus. Hasil hapus harus hilang dari daftar validasi.
4. Setelah antrean habis, buka Backup & Restore dan buat backup. Jadwalkan restore dari web untuk perangkat pengganti yang kosong, lalu pulihkan dari akun teknisi. Masuk dokter pemilik data dan buka kembali X-ray.
5. Uji koneksi putus, retry, pergantian akun dan logout; pastikan tidak ada data dokter lain yang tampil.

## Batas yang perlu diketahui

- Sinkron dokter mengirim metadata; sinkron teknisi tetap diperlukan untuk unggahan gambar. UI tidak menyatakan unggahan gambar selesai sebelum ACK teknisi.
- Probabilitas/lesi yang sudah telanjur hilang pada hasil lama tidak direkayasa atau dihitung ulang otomatis. Perbaikan inferensi berlaku pada skrining baru.
- Kontrak snapshot restore saat ini memasok X-ray asli, bukan file overlay segmentasi. Restore tidak membuat mask palsu; pemulihan file lung/lesion ke perangkat pengganti membutuhkan perluasan kontrak backend bila diwajibkan.
- Snapshot pasien tanpa satu pun skrining tidak memberi identitas dokter pemilik. Backup/restore kasus itu ditolak agar data tidak dialihkan ke teknisi. Backend perlu menyediakan pemilik pasien untuk mendukung kasus tersebut.
- Bukti lokal meliputi tes synthetic HTTP, database lokal, widget, golden, analyzer dan build APK. Belum ada uji perangkat fisik atau E2E klinis/VPS dengan akun operasional.
