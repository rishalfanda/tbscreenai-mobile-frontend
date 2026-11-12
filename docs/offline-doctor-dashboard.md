# Dashboard dokter dari database perangkat

Dashboard pada mode API/staging memakai OfflineDashboardRepository (SQLite), tanpa request /dashboard/summary maupun /dashboard/activity. Mode demo tetap terpisah.

- Data dibatasi tenant, akun dokter, dan ID lokal perangkat aktif. Arsip terenkripsi dokter lain tidak dibuka untuk dashboard.
- Kartu pasien menghitung seluruh pasien lokal akun ini. Tabel pasien belum memiliki created_at, sehingga tidak membuat klaim jumlah pendaftaran pasien per periode.
- Skrining, validasi, pending, distribusi dan aktivitas mengikuti periode 30/60/90/180 hari yang dipilih berdasarkan diagnosed_at, dengan batas hari di zona waktu perangkat. Grafik pasien berarti pasien unik yang diskrining pada hari tersebut.
- Pekerjaan yang belum diunggah tetap dihitung. Mock dan tombstone record tidak dihitung. Validasi yang dihapus tidak dihitung sebagai validasi maupun pending; skrining aslinya masih termasuk total skrining dan distribusi AI.
- Distribusi keputusan dokter mengikuti agree/disagree atas hasil AI biner. Persentase tanpa data ditampilkan sebagai tidak tersedia, bukan angka hasil rekaan.
- Perubahan SQLite memperbarui dashboard otomatis; tombol refresh membaca ulang SQLite. Logout mengosongkan state dashboard dan membuang hasil pembacaan sesi lama.

Verifikasi menggunakan data sintetis: agregasi, periode/zona waktu, pemisahan akun/tenant/perangkat, validasi terhapus, perubahan lokal dan logout; navigasi aplikasi staging menolak request dashboard HTTP dan tetap menampilkan ringkasan lokal.
