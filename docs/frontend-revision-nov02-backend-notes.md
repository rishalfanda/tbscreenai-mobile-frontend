# Revisi frontend 2 November 2026 — catatan untuk backend

**Tindak lanjut 4 November:** permintaan di bawah adalah snapshot 2 November.
Backend telah menambahkan kontrak melalui `537dc90`; penyesuaian APK dan batas
verifikasinya dicatat di [integrasi backend 537dc90](backend537-tablet-integration.md).

Branch frontend: `feat/frontend-revision-nov02`, berbasis `79bc1ce`.
Tidak ada kode backend yang diubah dalam revisi ini.

## Yang dikerjakan frontend

- Belum aktivasi: hanya form kode aktivasi. Sesudah aktivasi: hanya sign-in.
- Login/aktivasi: kartu dua kolom responsif, warna aplikasi, label outline,
  tombol mata untuk field rahasia, indikator koneksi perangkat.
- Dokter: Dasbor, Screening, Validasi, Account. Teknisi: Users, Model, Sync,
  Dataset. Pembatasan diterapkan pada menu dan direct route.
- Session dokter disimpan dalam secure storage, terikat akun, instansi,
  registrasi tablet, dan URL API. Tidak ada batas waktu lokal; logout atau
  penolakan autentikasi server mengakhiri session. Token server tetap mengikuti
  aturan backend. Session teknisi tidak dipulihkan setelah aplikasi dibuka ulang.
- Screening langsung menerima data pasien dan X-ray. Pasien baru, diagnosis,
  X-ray terenkripsi, segmentasi terenkripsi, serta antrean sync disimpan dalam
  transaksi lokal yang sama. Hasil demo tetap tidak bisa disimpan secara klinis.
- Validasi memuat daftar pasien/screening, data pasien, klasifikasi, segmentasi
  yang memang tersimpan dari inference tersebut, skor 0–10 dan komentar.
- Hanya satu tombol New Screening di hasil; data yang sudah tersimpan lokal
  tidak memerlukan konfirmasi pindah halaman. Tombol nonaktif dibuat terbaca.
- Kontrol ambil/konfirmasi gambar berada di sisi kanan pada orientasi landscape.
- Users memakai pencarian, filter status/role, tabel responsif, dan toggle status.
  Dataset diberi penjelasan sebagai kumpulan hasil screening pengguna instansi.
  Restore tidak ditampilkan dalam navigasi/alur aktif.
- Halaman Sync menghitung metadata antrean di SQLite tanpa mendekripsi gambar.
  Serialisasi dan kriptografi arsip dipindahkan ke worker isolate. Salinan hasil
  yang telah diterima server tetap disimpan terenkripsi untuk dokter asal;
  salinan itu tidak dihitung sebagai antrean pengiriman.

## Teks siap kirim ke tim backend

Mas, revisi frontend dibuat di branch `feat/frontend-revision-nov02`.
Mohon verifikasi/konfirmasi hal berikut:

1. **Aktivasi wajib sebelum sign-in.** UI sudah menutup akses login pada tablet
   yang belum diaktivasi. Mohon pastikan login/refresh pada server juga menolak
   perangkat tanpa registrasi aktif, agar aturan ini tidak hanya bergantung UI.
   Kode aktivasi dan administrasi registrasi tablet tetap diterbitkan backend.

2. **Session dokter untuk offline.** Frontend menyimpan identitas dokter secara
   lokal tanpa batas waktu sampai logout. Ini tidak meminta JWT/access token
   berlaku selamanya. Mohon pastikan deactivation, reset password, revocation
   dan tablet nonaktif memberi penolakan autentikasi yang jelas ketika perangkat
   kembali online. Perubahan status server tidak dapat diketahui saat benar-benar
   offline; aturan masa izin offline perlu disepakati jika kelak dibatasi.

3. **Arti slider keputusan.** Kontrak saat ini masih memisahkan `status`
   (`agreed`/`disagreed`) dan `validation_score` (0–10). Frontend tidak menebak
   status dari skor: dokter memilih hasil positif/negatif secara eksplisit,
   lalu memberi skor dan komentar. Mohon tim klinis menetapkan arti 0, 10,
   dan apakah nantinya slider menggantikan pilihan hasil. Jika ya, kontrak
   write/read/sync dan aturan komentar perlu diselaraskan terlebih dahulu.

4. **Pengiriman segmentasi oleh operator.** Segmentasi sudah disimpan dan
   ditampilkan offline di perangkat. API live menyediakan
   `PUT /diagnoses/{id}/heatmap` untuk PNG, sedangkan antrean operator saat ini
   mengirim record dan X-ray melalui `/sync/operator/push` dan `/blobs/*`.
   Mohon konfirmasi jalur/izin teknisi untuk mengunggah heatmap milik dokter
   asal pada tablet yang sama, termasuk receipt/idempotensi, agar pengiriman
   segmentasi ke server bisa diintegrasikan tanpa memakai identitas teknisi
   sebagai validator. Revisi ini belum mengklaim segmentasi telah diunggah.

5. **Versi diagnosis dan penghapusan.** Mohon konfirmasi receipt operator atau
   jalur pull untuk memperoleh versi diagnosis terbaru serta tombstone bagi
   cache dokter. Cache lokal yang sudah tersinkron tetap perlu mengikuti
   keputusan penghapusan/retensi server saat perangkat kembali online.

Endpoint Users sudah menyediakan filter `role` dan `is_active`; frontend
menggunakannya. Kontrak pasien dan diagnosis yang ada dipakai untuk pembuatan
pasien langsung dari screening, sehingga tidak perlu endpoint baru untuk alur itu.

## Batas verifikasi

Tes otomatis memakai identitas, gambar, dan data sintetis. Pemeriksaan UI dan
build APK tidak menggantikan uji perangkat fisik dengan model terpasang.
Perbaikan jalur pemuatan tidak berarti latensi login server telah diukur atau
seluruh masalah performa perangkat sudah dinyatakan selesai.
