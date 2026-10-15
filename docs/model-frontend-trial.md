# Trial Flutter dengan model ONNX backend

Staging memakai `HttpDiagnosisRepository` secara langsung, meskipun bundle
on-device sudah terpasang. Backend menjalankan model; Flutter mengirim multipart
`image` ke `POST /diagnoses/infer` dengan bearer dari sesi login doctor yang ada.
Tombol analisis staging tidak memerlukan unduhan model ke perangkat.

## Menjalankan

Aktifkan Developer Mode Windows jika Flutter melaporkan symlink tidak tersedia.
Jalankan backend sesuai `CONFIG-MODEL-AI/docs/model-frontend-trial.md`, termasuk
PostgreSQL, storage, migrasi, bundle dan akun doctor. Kemudian dari root frontend:

```powershell
./scripts/run-model-trial.ps1
```

Default Android emulator: `http://10.0.2.2:8000/api/v1`, device `emulator-5554`.
Untuk perangkat fisik, backend harus listen pada `0.0.0.0`, port 8000 dapat
diakses di LAN, dan gunakan IP privat komputer backend melalui konfigurasi:

```powershell
./scripts/run-model-trial.ps1 -ApiBaseUrl 'http://192.168.1.10:8000/api/v1' -Device '<device-id>'
```

Login lewat layar yang sudah ada menggunakan akun doctor. Gunakan X-ray uji
tanpa identitas pasien: PNG/JPEG, maksimal 25 MiB dan 20 juta pixel. Ekspor DICOM
ke PNG/JPEG dahulu. Nama file multipart dinormalisasi menjadi `xray.png`/`xray.jpg`.
Tidak ada logger request/response baru. HTTP cleartext hanya di flavor staging;
konfigurasi membatasi HTTP ke localhost/private IPv4, HTTPS tetap didukung.

## Kontrak hasil dan penyimpanan

- Parse `is_positive`, confidence kelas keputusan, `processing_time_ms`,
  `model_version`, `is_mock`, enam persentase findings, `image_id`, `provenance`.
- Respons lama tanpa infiltrate/provenance tetap diterima. `is_mock` wajib bool;
  nilai yang hilang tidak boleh dianggap hasil asli. Persentase tidak valid ditolak.
- Hasil mock ditandai MOCK/DEMO dan tidak disimpan sebagai diagnosis.
  API gagal menghapus hasil lama dan tidak menggantinya dengan dummy.
- Payload diagnosis dalam antrean `/sync/push` menyertakan `image_id` dan
  provenance backend tanpa mengubah nilainya. Provenance disimpan di kolom yang
  sudah ada; image ID disimpan dalam JSON snapshot klinis yang sudah ada.
  Tidak ada migrasi schema, reset database, atau perubahan account/tenant binding.
- Gambar tetap disimpan terenkripsi lokal. Referensi lokal tidak diganti image ID
  server sehingga restore tetap bisa berjalan. Sesi/token refresh menggunakan
  mekanisme yang sudah ada, termasuk pembuatan ulang body multipart saat retry.
- Error jaringan, 401, 403, 413, 415/422, dan 503 memberikan langkah tindak lanjut.
  Timeout respons inferensi 5 menit mengakomodasi load pertama model backend.

## Pemeriksaan pada 2026-10-10

- Analyzer: `flutter analyze --no-pub`, no issues.
- 67 tes relevan lokal lulus: inferensi, hasil/form/tab, persistence/reopen,
  environment/binding, P0 safety, dan session security.
- 8 tes dengan `--flavor staging`, `APP_ENV=staging`, `USE_HTTP=true`, dan URL
  emulator lulus. Binding HTTP dan tombol analisis tanpa model lokal diuji.
- Widget hasil ONNX diuji pada 400x900 dan 1600x1000 dengan text scale 200%,
  termasuk infiltrate dan confidence negatif tanpa pembalikan.
- `git diff --check` bersih. Tidak ada commit/push.
- Backend `http://127.0.0.1:8000/health` tidak dapat dihubungi; POST nyata dengan
  X-ray dan akun doctor belum dilakukan. Nilai `is_mock=false` dan
  `model_version=onnx-2026.09.04` baru diverifikasi melalui fixture kontrak lokal.
- Build APK, emulator/perangkat fisik, serta penyimpanan diagnosis di backend
  belum diuji. Setup plugin awal terhambat symlink/Developer Mode Windows.
  Dependency lock repository dipertahankan; verifikasi memakai dependency yang
  di-resolve oleh Flutter SDK lokal.

## Acceptance E2E yang masih diperlukan

Dengan backend aktif, jalankan launcher, login doctor, pilih pasien uji tersinkron,
unggah X-ray anonim. Pastikan respons nyata `is_mock=false`, versi
`onnx-2026.09.04`, temuan tampil, dan sinkronisasi menyimpan image/provenance yang
sama. Ulangi pada perangkat fisik dengan IP LAN. Bukti unit/widget/integrasi lokal
bukan validasi akurasi ataupun kesiapan klinis.

## File yang diubah atau ditambahkan

- `lib/app/app.dart`: staging langsung menggunakan adapter HTTP.
- `lib/core/config/app_config.dart`: URL trial emulator/LAN.
- `android/app/build.gradle.kts`: guard URL staging konsisten dengan Dart.
- `android/app/src/staging/AndroidManifest.xml`: cleartext staging.
- `lib/data/http/http_diagnosis_repository.dart`: batas input, parse hasil,
  referensi/provenance, timeout dan nama file upload.
- `lib/domain/models/diagnosis_outcome.dart`: infiltrate, image ID, provenance.
- `lib/data/offline/offline_screening_store.dart`: payload sync dan restore.
- `lib/state/diagnosis_provider.dart`: error yang bisa ditindaklanjuti.
- `lib/features/diagnosis/presentation/widgets/diagnosis_input_tab.dart`:
  analisis backend tanpa bundle lokal dan batas format input.
- `lib/features/diagnosis/presentation/widgets/diagnosis_result_tab.dart`:
  persentase temuan, provenance model, label mock dan layout adaptif.
- `test/diagnosis_inference_test.dart`
- `test/diagnosis_result_tab_test.dart`
- `test/diagnosis_form_test.dart`
- `test/sprint2_clinical_test.dart`
- `test/sprint3_binding_test.dart`
- `test/sprint3_guard_test.dart`
- `scripts/run-model-trial.ps1`: launcher emulator/LAN.
- `docs/model-frontend-trial.md`: panduan dan bukti verifikasi ini.

## Integrasi main pada 15 Oktober 2026

- Branch Staging-Mode di-fast-forward dari 5ac3a3c ke 5ac9e92cefd60a2fdf11060a173c7720dee20c17. Perubahan staging dipulihkan dan tiga konflik diselesaikan. Integrasi disiapkan sebagai commit lokal; push terpisah.
- Snapshot sebelum integrasi tetap tersedia di Git stash dengan label snapshot Staging-Mode before main integration 2026-10-15.
- Refactor UI, kamera dan DAG ONNX dari main dipertahankan. Binding staging tetap langsung HTTP; normalisasi Reinhard pada input galeri dilewati untuk HTTP agar unggahan backend tetap memakai gambar asli. Preprocessing model backend belum diverifikasi E2E.
- Label sumber model, findings termasuk infiltrate, image_id/provenance, dan confidence backend dipertahankan. Layout hasil diperbaiki untuk teks 200% pada layar 400x900 dan 1600x1000.
- Verifikasi baru: 8 tes hasil, 66 tes regresi inferensi/form/persistence/environment/kamera/DAG/Reinhard, dan 5 tes dengan flavor serta defines staging lulus. Flutter analyze --no-pub: no issues. Git diff --check bersih.
- Verifikasi lokal ini belum mencakup build APK, golden Windows, server staging hidup, atau E2E perangkat. Gate model nyata, clinical payload dan device auth pada handoff tetap perlu dituntaskan.

## Payload clinical — 15 Oktober 2026

Diagnosis create pada antrean sync sekarang menyertakan clinical schema_version=1, tinggi/berat, gejala terurut, dan jawaban klinis yang diisi sesuai OpenAPI main c58db5c. Nama file, metadata citra lokal, device_id dan selected_model tidak disertakan di clinical. Snapshot lokal dan schema database tetap dipertahankan; perubahan hanya berlaku untuk diagnosis yang baru diantrekan, bukan backfill antrean lama.

Tes regresi membuktikan clinical sebelumnya tidak terkirim (red), lalu memeriksa reopen database, respons 503, retry ber-client_op_id sama, respons skipped dan payload identik. Tes tambahan mencakup seluruh field klinis dan perubahan draft sesudah enqueue. Total 18 tes clinical/sync lulus; round-trip penyimpanan server masih menunggu staging aktif.

## Perbaikan CI PR #6

Lockfile kini mengikuti Flutter 3.44.7 / Dart 3.12.2 yang dipakai CI, bukan dependency hasil SDK Dart 3.13. Kode Drift diregenerasi tanpa perubahan tabel atau migrasi; regenerasi kedua menghasilkan nol perubahan. Baseline golden Windows ditinjau terhadap gambar pembanding dan diperbarui untuk teks batas unggahan, tanpa mengubah comparator/toleransi. Ekspektasi pesan error pada tes flow mengikuti pesan Indonesia yang sudah ada.

Validasi lokal: 209 tes non-golden lulus, satu tes golden Windows lulus setelah update baseline, analyzer bersih. Hasil CI remote dilaporkan terpisah setelah push.
