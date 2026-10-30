# Koreksi kebutuhan role teknisi: pembaruan model dan sinkronisasi

**Pembaruan:** user menetapkan tablet yang sama, berganti operator. Kontrak lanjutan tersedia di backend PR #37; implementasi frontend dan prasyarat uji tercatat dalam [TECHNICIAN_PR37_INTEGRATION.md](TECHNICIAN_PR37_INTEGRATION.md). Isi di bawah dipertahankan sebagai riwayat permintaan.

## Kebutuhan bisnis yang dikonfirmasi

Teknisi bertanggung jawab memperbarui model yang digunakan pengguna TBScreen dan menyinkronkan data pengguna ke server. Manajemen tetap ditunda. Pengelolaan koleksi dataset dan akun dokter tidak menggantikan sinkronisasi data dari perangkat.

## Status yang sudah dibuktikan

- Frontend `adce393` mengikuti PR backend #36 dan menghilangkan menu Models/Sync dari teknisi. Ini perlu diselaraskan dengan kebutuhan bisnis di atas.
- Tes API staging dengan akun technician: `/sync/pull` dan inferensi menjawab 403. CRUD pengguna dan dataset berhasil.
- OpenAPI staging memuat `/models/check`, `/models/index.json` dan `/sync/model-version`. Request model stable untuk app `1.0.0` saat pemeriksaan menjawab 404; penyebab ketersediaan channel/bundle atau kebijakan versinya perlu diverifikasi sebelum menyebut pembaruan model berfungsi.
- Frontend model updater menggunakan `/models/check`, kemudian verifikasi bundle, aktivasi dan smoke test. Keberadaan UI tidak membuktikan adanya bundle yang dapat dipasang.
- Database lokal saat ini mengikat antrean pada tenant, pengguna dan perangkat. Pergantian owner/logout membersihkan data klinis lokal. Mengaktifkan menu Sync saja tidak menyediakan antrean dokter kepada teknisi dan tidak menyelesaikan risiko kehilangan antrean yang belum terkirim.

## Yang perlu disepakati dan diimplementasikan bersama backend

1. **Target perangkat:** teknisi bekerja di tablet dokter yang sama, dari perangkat lain, atau keduanya. Pertanyaan ini masih menunggu jawaban user; jangan menganggap sudah diputuskan.
2. **Pembaruan model:** izinkan teknisi memeriksa versi dan memasang bundle yang disetujui pada target perangkat. Konfirmasikan channel, versi aplikasi minimum, manifest, checksum/tanda tangan dan URL bundle yang valid. Pengelolaan/publikasi model pusat bukan otomatis bagian dari instalasi model pada tablet.
3. **Sinkronisasi data pengguna:** sediakan otorisasi teknisi untuk mengirim antrean dari perangkat yang sah dan tenant yang sama. Tentukan kontrak endpoint, identitas perangkat dan konteks pemilik data; jangan mengandalkan user_id/tenant_id dari body sebagai sumber kewenangan.
4. **Identitas dan audit:** teknisi dicatat sebagai operator sinkronisasi. Dokter/pemilik asli dan riwayat keputusan klinis tetap dipertahankan; teknisi tidak mendapat izin membuat hasil inferensi atau memvalidasi hasil AI atas nama dokter.
5. **Keutuhan antrean:** frontend harus mempertahankan antrean yang belum terkirim selama alur pergantian operator yang disepakati. Penghapusan lokal hanya dilakukan sesuai kebijakan dan konfirmasi server; jangan membuka cache lintas akun/tenant secara bebas.
6. **Konfirmasi server:** definisikan status applied/skipped/conflict/failed, idempotensi retry, serta penanganan upload parsial/gambar bila termasuk dalam payload. UI tidak boleh menampilkan sukses berdasarkan progres lokal saja.

## Uji penerimaan setelah kontrak disepakati

- Dokter membuat data sintetis offline pada perangkat target.
- Teknisi memperbarui model; aplikasi menunjukkan versi yang benar setelah verifikasi/aktivasi berhasil.
- Teknisi menjalankan sinkronisasi, lalu data dibaca ulang dari server dan pemilik asal tetap benar.
- Retry tidak menggandakan data; kegagalan tidak menghilangkan antrean; tenant/perangkat lain ditolak.
- Teknisi tetap ditolak menjalankan inferensi dan validasi klinis.

Paket APK `adce393` belum mewakili alur teknisi yang dikoreksi ini. Distribusi sebagai implementasi lengkap ditahan sampai kontrak dan perubahan frontend selesai.
