import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// UI preference only; does not alter session or clinical data.
class AppLanguage extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  void select(String languageCode) {
    if (!const ['en', 'id'].contains(languageCode) ||
        _locale.languageCode == languageCode) {
      return;
    }
    _locale = Locale(languageCode);
    notifyListeners();
  }
}

/// Explicit display copy for the institution UI, using the same language state.
extension InstitutionLanguage on BuildContext {
  String tr(String indonesian, String english) =>
      watch<AppLanguage?>()?.locale.languageCode == 'id' ? indonesian : english;

  /// Event handlers must not register inherited-provider dependencies.
  String trRead(String indonesian, String english) =>
      read<AppLanguage?>()?.locale.languageCode == 'id' ? indonesian : english;
}

String localize(BuildContext context, String text) {
  final language = context.watch<AppLanguage?>()?.locale.languageCode;
  if (language == null) return text;
  if (language == 'en') {
    final identity = RegExp(r'^(.*) · (\d+) Tahun$').firstMatch(text);
    if (identity != null) {
      final gender = identity.group(1)!;
      return '${_englishLabels[gender] ?? gender} · ${identity.group(2)} years';
    }
    if (text.startsWith('Level Indikasi TB: ')) {
      return 'TB Indication Level: ${text.substring(19)}';
    }
    if (text.startsWith('Terakhir diperiksa: ')) {
      return 'Last checked: ${text.substring(20)}';
    }
    if (text.startsWith('Gagal memeriksa pembaruan model: ')) {
      return 'Failed to check for model updates: ${text.substring(33)}';
    }
    if (text.startsWith('Gagal mengaktifkan model: ')) {
      return 'Failed to activate model: ${text.substring(26)}';
    }
    if (text.startsWith('Verifikasi ulang gagal: ')) {
      return 'Re-verification failed: ${text.substring(24)}';
    }
    final httpErr = RegExp(r'^Gagal menghubungi server \(HTTP (\d+)\)\.$').firstMatch(text);
    if (httpErr != null) {
      return 'Failed to reach server (HTTP ${httpErr.group(1)}).';
    }
    final storedModels = RegExp(r'^Model Tersimpan di Perangkat \((\d+)\)$').firstMatch(text);
    if (storedModels != null) {
      return 'Models Stored on Device (${storedModels.group(1)})';
    }
    final pctDone = RegExp(r'^(\d+)% selesai$').firstMatch(text);
    if (pctDone != null) {
      return '${pctDone.group(1)}% completed';
    }
    final readyVer = RegExp(
      r'^Versi (.+) telah diverifikasi dan siap digunakan tanpa perlu mengunduh ulang\.$',
    ).firstMatch(text);
    if (readyVer != null) {
      return 'Version ${readyVer.group(1)} has been verified and is ready to use without re-downloading.';
    }
    final checksumErr = RegExp(
      r'^Checksum atau tanda tangan digital model v(.+) tidak cocok\.$',
    ).firstMatch(text);
    if (checksumErr != null) {
      return 'Checksum or digital signature for model v${checksumErr.group(1)} did not match.';
    }
    final doneVer = RegExp(
      r'^Model AI versi (.+) berhasil diaktifkan dan siap digunakan\.$',
    ).firstMatch(text);
    if (doneVer != null) {
      return 'AI model version ${doneVer.group(1)} has been activated and is ready to use.';
    }
    final deleteTitle = RegExp(r'^Hapus Model v(.+)\?$').firstMatch(text);
    if (deleteTitle != null) {
      return 'Delete Model v${deleteTitle.group(1)}?';
    }
    final deleteActiveBody = RegExp(
      r'^Model (.+) v(.+) akan dihapus dari penyimpanan perangkat\. PERINGATAN: Model ini sedang aktif digunakan untuk inferensi\.$',
    ).firstMatch(text);
    if (deleteActiveBody != null) {
      return 'Model ${deleteActiveBody.group(1)} v${deleteActiveBody.group(2)} will be deleted from device storage. WARNING: This model is currently active for inference.';
    }
    final deleteInactiveBody = RegExp(
      r'^Model (.+) v(.+) akan dihapus dari penyimpanan perangkat\. Tindakan ini akan membebaskan ruang memori\.$',
    ).firstMatch(text);
    if (deleteInactiveBody != null) {
      return 'Model ${deleteInactiveBody.group(1)} v${deleteInactiveBody.group(2)} will be deleted from device storage. This action will free up storage space.';
    }
    final deletedSwitch = RegExp(
      r'^Model v(.+) berhasil dihapus\. Model (.+) sekarang menjadi model aktif\.$',
    ).firstMatch(text);
    if (deletedSwitch != null) {
      return 'Model v${deletedSwitch.group(1)} deleted. Model ${deletedSwitch.group(2)} is now the active model.';
    }
    final deletedNone = RegExp(
      r'^Model v(.+) berhasil dihapus\. Tidak ada model aktif\.$',
    ).firstMatch(text);
    if (deletedNone != null) {
      return 'Model v${deletedNone.group(1)} deleted. No active model selected.';
    }
    final deletedSimple = RegExp(
      r'^Model v(.+) berhasil dihapus\.$',
    ).firstMatch(text);
    if (deletedSimple != null) {
      return 'Model v${deletedSimple.group(1)} deleted.';
    }
    final patientsCount = RegExp(r'^(\d+) pasien$').firstMatch(text);
    if (patientsCount != null) {
      return '${patientsCount.group(1)} patients';
    }
    final recordsCount = RegExp(r'^(\d+) data$').firstMatch(text);
    if (recordsCount != null) {
      return '${recordsCount.group(1)} records';
    }
    final selectedCount = RegExp(r'^(\d+) dipilih$').firstMatch(text);
    if (selectedCount != null) {
      return '${selectedCount.group(1)} selected';
    }
    final uploadingProgress = RegExp(r'^Mengunggah (\d+)/(\d+) pasien\.\.\.$').firstMatch(text);
    if (uploadingProgress != null) {
      return 'Uploading ${uploadingProgress.group(1)}/${uploadingProgress.group(2)} patients...';
    }
    final uploadedDone = RegExp(r'^(\d+) pasien berhasil diunggah$').firstMatch(text);
    if (uploadedDone != null) {
      return '${uploadedDone.group(1)} patients uploaded successfully';
    }
    final patientSub = RegExp(r'^(\d+) th • (Laki-laki|Perempuan)$').firstMatch(text);
    if (patientSub != null) {
      final g = patientSub.group(2) == 'Laki-laki' ? 'Male' : 'Female';
      return '${patientSub.group(1)} yrs • $g';
    }
    final conflictsMsg = RegExp(
      r'^(\d+) data konflik — versi di server lebih baru\. Data TIDAK ditimpa; perlu ditinjau manual oleh dokter\.$',
    ).firstMatch(text);
    if (conflictsMsg != null) {
      return '${conflictsMsg.group(1)} conflicting records — server version is newer. Data was NOT overwritten; manual doctor review required.';
    }
    final failedMsg = RegExp(
      r'^(\d+) gagal terkirim — tetap tersimpan di antrean, akan dicoba lagi saat sinkronisasi berikutnya\.$',
    ).firstMatch(text);
    if (failedMsg != null) {
      return '${failedMsg.group(1)} failed to send — retained in queue, will retry on next sync.';
    }
    final deleteItemPrompt = RegExp(
      r'^Apakah Anda yakin ingin menghapus (.*)\? Tindakan ini tidak dapat dibatalkan\.$',
    ).firstMatch(text);
    if (deleteItemPrompt != null) {
      return 'Are you sure you want to delete ${deleteItemPrompt.group(1)}? This action cannot be undone.';
    }
    final ditambahkanDate = RegExp(r'^Ditambahkan (.+)$').firstMatch(text);
    if (ditambahkanDate != null) {
      return 'Added ${ditambahkanDate.group(1)}';
    }
    final volId = RegExp(r'^Jumlah skrining, (\d+) hari terakhir$').firstMatch(text);
    if (volId != null) {
      return 'Screening volume, last ${volId.group(1)} days';
    }
    return _stagingEnglish[text] ?? _englishLabels[text] ?? text;
  }
  final translated = _stagingIndonesian[text] ?? _indonesian[text];
  if (translated != null) return translated;
  if (text.startsWith('TB Indication Level: ')) {
    return 'Level Indikasi TB: ${text.substring(21)}';
  }
  final screeningVolume = RegExp(r'^Screening volume, last (\d+) days$').firstMatch(text);
  if (screeningVolume != null) {
    return 'Jumlah skrining, ${screeningVolume.group(1)} hari terakhir';
  }
  final addedDate = RegExp(r'^Added (.+)$').firstMatch(text);
  if (addedDate != null) {
    return 'Ditambahkan ${addedDate.group(1)}';
  }
  final valErr = RegExp(r'^Validation was not saved: (.*)$').firstMatch(text);
  if (valErr != null) {
    return 'Validasi gagal disimpan: ${valErr.group(1)}';
  }
  final confErr = RegExp(r'^Conflict was not resolved: (.*)$').firstMatch(text);
  if (confErr != null) {
    return 'Konflik gagal diselesaikan: ${confErr.group(1)}';
  }
  final verdictMatch = RegExp(r'^Verdict: (.*)$').firstMatch(text);
  if (verdictMatch != null) {
    final st = verdictMatch.group(1)!;
    final stTr = switch (st.toLowerCase()) {
      'agreed' => 'Disetujui',
      'disagreed' => 'Ditolak',
      'pending' => 'Menunggu',
      'unavailable' => 'Tidak tersedia',
      _ => st,
    };
    return 'Keputusan: $stTr';
  }
  if (text.startsWith('Note: ')) {
    return 'Catatan: ${text.substring(6)}';
  }
  // Display templates only; substituted account values are preserved.
  if (text.startsWith('Welcome back, ')) {
    return 'Selamat datang kembali, ${text.substring(14)}';
  }
  if (text.startsWith('Patient ID: #')) {
    return 'ID Pasien: #${text.substring(13)}';
  }
  final age = RegExp(r'^(\d+) (?:yrs|years)$').firstMatch(text);
  if (age != null) {
    return '${age.group(1)} tahun';
  }
  for (final entry in _templates.entries) {
    if (text.startsWith(entry.key)) {
      return '${entry.value}${text.substring(entry.key.length)}';
    }
  }
  if (text.endsWith('% confidence')) {
    return '${text.substring(0, text.length - 11)} keyakinan';
  }
  return text;
}

// Copy used by the refactored staging screening widgets.
const _stagingEnglish = <String, String>{
  'Dataset diarsipkan. Buka kembali sebelum mengubah item.':
      'This dataset is archived. Reopen it before changing items.',
  'Sebagian hasil screening tidak ditemukan dalam instansi ini. Tidak ada item ditambahkan.':
      'Some screenings were not found in this institution. No items were added.',
  'Perubahan dataset gagal. Periksa koneksi, data dan izin akun lalu coba lagi.':
      'Dataset changes failed. Check your connection, data and account permissions, then retry.',
  'Dataset belum tersedia.': 'Datasets are not available.',
  'Data mengikuti instansi akun yang sedang login.':
      'Data belongs to the signed-in account institution.',
  'Dataset ini belum memiliki hasil screening.':
      'This dataset has no screenings yet.',
  'Tidak ada dataset yang sesuai.': 'No matching datasets.',
  'Akses dataset ditolak untuk akun ini.':
      'Dataset access is denied for this account.',
  'Dataset tidak ditemukan. Muat ulang daftar dataset.':
      'Dataset not found. Refresh the dataset list.',
  'Dataset tidak dapat dimuat. Periksa koneksi dan coba lagi.':
      'Unable to load datasets. Check the connection and try again.',
  'Dashboard tidak dapat dimuat. Periksa koneksi dan coba lagi.':
      'Unable to load the dashboard. Check the connection and try again.',
  'Dashboard belum tersedia.': 'Dashboard is not available.',
  'Belum ada data dashboard.': 'No dashboard data yet.',
  'Belum ada aktivitas screening.': 'No screening activity yet.',
  'Model AI belum terpasang di perangkat ini. Hubungi teknisi instansi untuk memasang model sebelum menjalankan analisis.':
      'No AI model is installed on this device. Contact your institution technician to install a model before analysis.',
  'Identitas Pasien': 'Patient Identity',
  'Screening AI': 'AI Screening',
  'Skor Keyakinan AI': 'AI Confidence Score',
  'Alat bantu skrining awal · Butuh konfirmasi dokter':
      'Initial screening aid · Doctor confirmation required',
  'Detail Klinis (Hide/Unhide)': 'Clinical Details (Show/Hide)',
  'Gejala, komorbiditas, dan riwayat klinis pasien':
      'Patient symptoms, comorbidities, and clinical history',
  'Kontak TB': 'TB Contact',
  'Paparan Sinar Matahari': 'Sunlight Exposure',
  'Segera rujuk ke fasilitas kesehatan untuk di evaluasi dan dilakukan pemeriksaan tambahan oleh dokter':
      'Refer to a healthcare facility for evaluation and further examination by a doctor.',
  'Hasil demo — penyimpanan klinis diblokir.':
      'Demo result — clinical saving is blocked.',
  'Mengenkripsi X-ray dan menyimpan hasil yang ditinjau...':
      'Encrypting the X-ray and saving the reviewed result...',
  'Tersimpan lokal — menunggu sinkronisasi.':
      'Saved locally — awaiting synchronization.',
  'Tersimpan dan terkonfirmasi oleh server.':
      'Saved and confirmed by the server.',
  'Konflik server — diperlukan resolusi oleh dokter.':
      'Server conflict — doctor resolution required.',
  'Penyimpanan lokal gagal. Coba lagi sebelum keluar.':
      'Local saving failed. Retry before leaving.',
  'Belum tersimpan.': 'Not saved yet.',
  'Memeriksa file gambar sebelum ditampilkan.':
      'Checking the image file before displaying it.',
  'PNG/JPEG - Maksimal 25 MB dan 20 juta pixel. Ekspor DICOM dahulu.':
      'PNG/JPEG - Maximum 25 MB and 20 million pixels. Export DICOM first.',
  'Gunakan citra rontgen digital asli jika tersedia. Pengambilan foto dengan kamera dapat menurunkan kualitas gambar.':
      'Use the original digital X-ray when available. Camera capture may reduce image quality.',
  'Memproses...': 'Processing...',
  'Detail Runtime & Aksi': 'Runtime Details & Actions',
  'MOCK / DEMO - bukan hasil model asli':
      'MOCK / DEMO - not a real model result',
  'Hasil model perangkat': 'On-device model result',
  'Hasil model backend': 'Backend model result',
  'Infiltrat': 'Infiltrate',
  'Menyesuaikan kontras dan histogram warna dengan citra referensi acuan.':
      'Adjusting contrast and color histogram to the reference image.',
  'Terenkripsi secara lokal dan dalam antrian sinkronisasi.':
      'Encrypted locally and queued for synchronization.',
  'Hasil ini sudah tersimpan lokal namun masih menunggu sinkronisasi. Memulai screening baru tidak akan menghapusnya.':
      'This result is saved locally and awaiting synchronization. Starting a new screening will not delete it.',
  'Hasil ini belum tersimpan dengan aman. Tinjau atau coba simpan ulang sebelum melanjutkan.':
      'This result is not safely saved. Review or retry saving before continuing.',
  'Level Indikasi TB: Very Low': 'TB Indication Level: Very Low',
  'Level Indikasi TB: Low': 'TB Indication Level: Low',
  'Level Indikasi TB: Grey Area': 'TB Indication Level: Grey Area',
  'Level Indikasi TB: High': 'TB Indication Level: High',
  'Level Indikasi TB: Very High': 'TB Indication Level: Very High',
  'Model memiliki keyakinan sangat rendah terhadap adanya indikasi TB.':
      'The model has very low confidence in the presence of TB indication.',
  'Kemungkinan TB rendah, namun belum dapat sepenuhnya dikesampingkan.':
      'TB likelihood is low, but cannot be ruled out completely.',
  'Model tidak dapat memberikan keputusan dengan keyakinan yang cukup.':
      'The model cannot make a decision with sufficient confidence.',
  'Model menunjukkan indikasi TB dengan keyakinan tinggi.':
      'The model indicates TB with high confidence.',
  'Model menunjukkan indikasi TB dengan keyakinan sangat tinggi.':
      'The model indicates TB with very high confidence.',
  'Hasil skrining negatif. Tetap mempertimbangkan gejala klinis dan faktor risiko pasien.':
      'Negative screening result. Continue considering clinical symptoms and patient risk factors.',
  'Hasil skrining negatif. Pemeriksaan lanjutan bila terdapat gejala atau faktor risiko tinggi.':
      'Negative screening result. Further examination if symptoms or high-risk factors exist.',
  'Wajib dilakukan validasi tambahan oleh dokter, disertai evaluasi klinis dan pemeriksaan penunjang.':
      'Additional doctor validation required, along with clinical evaluation and supporting tests.',
  'Hasil skrining positif. Perlu dilanjutkan dengan pemeriksaan lanjutan.':
      'Positive screening result. Must proceed with further examination.',
  'Model AI Aktif': 'Active AI Model',
  'Belum Ada Model Aktif': 'No Active Model',
  'TIDAK ADA MODEL AKTIF': 'NO ACTIVE MODEL',
  'SIAP INFERENSI': 'READY FOR INFERENCE',
  'Belum Ada Model AI di Server': 'No AI Model on Server Yet',
  'Server belum memiliki berkas model AI yang dirilis untuk channel ini. Hubungi administrator sistem untuk mengunggah bundle model AI ke server.':
      'The server does not have a released AI model bundle for this channel yet. Contact your system administrator to upload an AI model bundle to the server.',
  'Periksa Lagi': 'Check Again',
  'Model versi terbaru terpasang': 'Latest model version installed',
  'Model Terbaru Sudah Tersimpan di Perangkat':
      'Latest Model Already Stored on Device',
  'Aktifkan Model': 'Activate Model',
  'Verifikasi Integritas Model Gagal': 'Model Integrity Verification Failed',
  'Verify Ulang': 'Re-verify',
  'Unduh Ulang': 'Re-download',
  'Versi Baru': 'New Version',
  'Ukuran': 'Size',
  'Tanggal Rilis': 'Release Date',
  'Catatan Pembaruan:': 'Release Notes:',
  'Mengunduh model AI...': 'Downloading AI model...',
  'Memverifikasi integritas model...': 'Verifying model integrity...',
  'Memeriksa checksum SHA256 & tanda tangan digital Ed25519.':
      'Checking SHA256 checksum & Ed25519 digital signature.',
  'Mengaktifkan model & inisialisasi mesin inferensi...':
      'Activating model & initializing inference engine...',
  'Memuat session ONNX Runtime dan menjalankan smoke test.':
      'Loading ONNX Runtime session and running smoke test.',
  'Pembaruan Selesai': 'Update Complete',
  'Gagal menghubungi server': 'Failed to reach server',
  'Belum ada model tersimpan di perangkat.': 'No models stored on device yet.',
  'Aktif': 'Active',
  'Unduh': 'Download',
  'Gunakan': 'Use',
  'Verifikasi': 'Verify',
  'Hapus model': 'Delete model',
  'Terverifikasi': 'Verified',
  'Gagal Verifikasi': 'Verification Failed',
  'Diunduh': 'Downloaded',
  'Belum Diunduh': 'Not Downloaded',
  'Hapus': 'Delete',
  'Unduhan model dibatalkan.': 'Model download cancelled.',
  'Model berhasil diunduh dan diverifikasi. Silakan pilih model untuk menggunakannya.':
      'Model downloaded and verified successfully. Please select the model to use it.',
  'Gagal mengunduh model — periksa koneksi internet Anda.':
      'Failed to download model — check your internet connection.',
  'Verifikasi model gagal — berkas model rusak atau tidak sah.':
      'Model verification failed — model bundle is corrupted or invalid.',
  'Model tidak kompatibel dengan aplikasi ini.':
      'Model is not compatible with this application.',
  'Model gagal uji inferensi (smoke test) — periksa format input/output.':
      'Model failed inference smoke test — check input/output format.',
  'Instalasi model gagal.': 'Model installation failed.',
  'Model berhasil diaktifkan. Menyiapkan model agar siap digunakan...':
      'Model activated successfully. Preparing model for standby...',
  'Verifikasi integritas model berhasil.':
      'Model integrity verification succeeded.',
  'Tidak ada koneksi internet. Periksa koneksi Anda.':
      'No internet connection. Check your connection.',
  'Menginisialisasi Model AI': 'Initializing AI Model',
  'Menyiapkan dan memuat model AI ke memori agar proses analisis siap digunakan... Mohon tunggu.':
      'Preparing and loading the AI model into memory so analysis is ready... Please wait.',
  'Total Pasien': 'Total Patients',
  'Total Diagnosis': 'Total Diagnoses',
  'Estimasi Ukuran': 'Estimated Size',
  'Terakhir Cadang': 'Last Backup',
  'Belum pernah': 'Never',
  'Batal Semua': 'Deselect All',
  'Tidak ada data pasien untuk dicadangkan.': 'No patient data to back up.',
  'Sinkronisasi selesai sebagian': 'Synchronization partially completed',
  'Sinkronisasi selesai': 'Synchronization completed',
  'Data medis pasien (rekam medis dan citra X-Ray) akan diunggah ke server pusat TB Screen AI melalui koneksi terenkripsi (TLS 1.3).':
      'Patient medical data (medical records and X-Ray images) will be uploaded to the central TB Screen AI server over an encrypted connection (TLS 1.3).',
  'Data dide-identifikasi sesuai standar privasi data medis sebelum dikirim.':
      'Data is de-identified in accordance with medical data privacy standards before transmission.',
  'Saya mengonfirmasi bahwa data ini siap dicadangkan ke server pusat dan persetujuan pasien telah diperoleh.':
      'I confirm that this data is ready to be backed up to the central server and patient consent has been obtained.',
  'Pilih Sumber Citra': 'Select Image Source',
  'Flashdisk USB / Berkas': 'USB Flash Drive / Files',
  'Buka pengelola berkas untuk memilih citra dari flashdisk USB atau memori':
      'Open file manager to select image from USB flash drive or storage',
  'Pastikan flashdisk USB sudah terpasang di perangkat':
      'Make sure the USB flash drive is connected to the device',
  'Galeri Foto': 'Photo Gallery',
  'Pilih citra dari galeri foto perangkat':
      'Select an image from device photo gallery',
  'Hapus Rontgen': 'Remove X-Ray',
  'Dinonaktifkan sampai kebijakan PHI untuk hasil tersimpan disetujui.':
      'Disabled until PHI policy for stored results is approved.',
  'Apakah Anda yakin ingin mengatur ulang data? Seluruh data pasien dan citra rontgen yang belum dianalisis akan dihapus.':
      'Are you sure you want to reset? All unanalyzed patient data and X-ray images will be cleared.',
  'Tidak': 'No',
};

final _stagingIndonesian = <String, String>{
  'Dataset Details': 'Detail Dataset',
  'Screenings in this dataset': 'Hasil screening dalam dataset',
  'AI Positive': 'AI Positif',
  'AI Negative': 'AI Negatif',
  'Previous': 'Sebelumnya',
  'Next': 'Berikutnya',
  'Patients registered': 'Pasien terdaftar',
  'Patients screened': 'Pasien diskrining',
  'No validated screenings': 'Belum ada skrining tervalidasi',
  'Refresh dashboard': 'Muat ulang dashboard',
  'Technician': 'Teknisi',
  'Users': 'Pengguna',
  'Models': 'Model',
  'Tenant': 'Instansi / Tenant',
  'TBScreen.AI': 'TBScreen.AI',
  '© 2026 TBScreen. All rights reserved.':
      '© 2026 TBScreen. Seluruh hak cipta dilindungi.',
  'Close camera': 'Tutup kamera',
  'Turn flash off': 'Matikan lampu kilat',
  'Turn flash on': 'Nyalakan lampu kilat',
  'Switch camera': 'Ganti kamera',
  'The server changed after this device loaded the diagnosis.':
      'Data di server telah berubah setelah perangkat ini memuat diagnosis.',
  'Doctor': 'Dokter',
  'Doctor Review': 'Tinjauan Dokter',
  'Validate AI screening results': 'Validasi hasil skrining AI',
  'AI Screening Result': 'Hasil Skrining AI',
  'Heatmap not available for this case':
      'Peta panas tidak tersedia untuk kasus ini',
  "Doctor's Note": 'Catatan Dokter',
  'Disagree': 'Tidak Setuju',
  'Agree with AI Result': 'Setuju dengan Hasil AI',
  'Re-validate': 'Validasi Ulang',
  'Confirm conflict decision': 'Konfirmasi keputusan konflik',
  'Cancel / keep open': 'Batal / tetap buka',
  'Keep server': 'Gunakan versi server',
  'Reapply local': 'Terapkan versi lokal',
  'Reconnect to fetch the authoritative server snapshot.':
      'Hubungkan kembali untuk mengambil data server terbaru.',
  'Select a patient from the list to review\nthe AI screening result':
      'Pilih pasien dari daftar untuk meninjau\nhasil skrining AI',
  'Conflict details are loading. No clinical value was overwritten.':
      'Detail konflik sedang dimuat. Tidak ada data klinis yang ditimpa.',
  'Online': 'Online',
  'Offline': 'Offline',
  for (final entry in _stagingEnglish.entries) entry.value: entry.key,
};

final _englishLabels = <String, String>{
  for (final entry in _indonesian.entries) entry.value: entry.key,
  ..._englishAliases,
  'Input Data': 'Input Data',
  'Hasil Analisis': 'Analysis Result',
  'Hasil Screening': 'Screening Result',
  'Tampilkan Data Klinis': 'Show Clinical Data',
  'Tutup': 'Close',
  'Terdeteksi TB': 'TB Detected',
  'Screening Baru': 'New Screening',
  'Mulai screening baru?': 'Start a new screening?',
  'Unggah Citra Rontgen': 'Upload X-Ray Image',
  'Rontgen': 'X-ray',
  'Paru': 'Lungs',
  'Lesi': 'Lesions',
  'Fibrotik': 'Fibrotic',
  'Tinggi Badan (cm)': 'Height (cm)',
  'Tinggi Badan': 'Height',
  'Berat Badan': 'Weight',
  'Tidak diisi': 'Not provided',
  'Waktu Proses': 'Processing Time',
  'Berat Badan (kg)': 'Weight (kg)',
  'Jika Usia < 18 Tahun, Skor TB Anak': 'Pediatric TB Score (Age < 18)',
  'Paparan Sinar Matahari Langsung': 'Direct Sunlight Exposure',
  'Pemeriksaan Dahak (BTA):': 'Sputum Examination (BTA):',
  'Xpert MTB/Rif atau NAAT:': 'Xpert MTB/Rif or NAAT:',
  'Kondisi Imun Lemah Lainnya': 'Other Immunocompromised Conditions',
  'Diduga': 'Suspected',
  'Non-Disabilitas': 'Non Disability',
  'Kehilangan Nafsu Makan': 'Loss of Appetite',
  'Batuk Darah (Hemoptisis)': 'Hemoptysis/Coughing Blood',
  'Analisis': 'Analyze',
  'Atur Ulang': 'Reset',
  'Konfirmasi Atur Ulang': 'Confirm Reset',
  'Ya, Atur Ulang': 'Yes, Reset',
  'Menganalisis citra rontgen...': 'Analyzing X-ray image...',
  'Informasi Tambahan (Opsional)': 'Additional Information (Optional)',
  'Gejala, lingkungan, dan hasil pemeriksaan klinis':
      'Symptoms, environment, and clinical examination results',
  'Buka Pusat Sinkronisasi': 'Open Sync Center',
  'Belum ada hasil analisis.': 'No analysis result yet.',
  'Lengkapi data pasien dan jalankan analisis pada tab Input Data.':
      'Complete patient details and run analysis in the Input Data tab.',
  'Pratinjau gambar tidak tersedia': 'Image preview unavailable',
  'Gambar tidak tersedia': 'Image unavailable',
  'Pembaruan Model AI': 'AI Model Update',
  'Periksa Pembaruan Model': 'Check Model Updates',
  'Tidak ada koneksi internet': 'No internet connection',
  'Memeriksa server...': 'Checking server...',
  'Periksa Ulang': 'Check Again',
  'Versi Baru Tersedia': 'New Version Available',
  'Lihat Changelog': 'View Changelog',
  'Perbarui Sekarang': 'Update Now',
  'Lewati': 'Skip',
  'Mengunduh pembaruan model...': 'Downloading model update...',
  'Memverifikasi dan memasang model...': 'Verifying and installing model...',
  'Model sedang diverifikasi keasliannya dan diuji sebelum diaktifkan.':
      'Model authenticity is being verified and tested before activation.',
};

const _templates = {
  'Agreed ': 'Sepakat ',
  'Disagreed ': 'Tidak sepakat ',
  'Positive ': 'Positif ',
  'Negative ': 'Negatif ',
};

const _englishAliases = <String, String>{
  'Login gagal — belum ada model AI yang aktif. Silakan aktifkan model terlebih dahulu atau hubungi teknisi.':
      'Login failed — no active AI model found. Please activate a model first or contact a technician.',
  'Hapus Item Ini?': 'Delete this item?',
  'Ya, Hapus': 'Yes, Delete',
  'DUMMY / DEMO ? BUKAN HASIL KLINIS': 'DUMMY / DEMO ? NOT A CLINICAL RESULT',
  'Contoh ini hanya untuk mempresentasikan layout halaman. ':
      'This example demonstrates the page layout only. ',
  'Login gagal ? periksa email/password atau koneksi server':
      'Login failed ? check your email/password or server connection',
  'Data pasien akan dikirimkan ke server menggunakan enkripsi end-to-end. ':
      'Patient data will be sent to the server using end-to-end encryption. ',
  'Instansi akun': 'Account institution',
  'Belum tersedia': 'Not available',
  'Instansi demo (data sintetis)': 'Demo institution (synthetic data)',
  'Instansi mengikuti akun dan ditetapkan oleh admin.':
      'Your institution is assigned to your account by an administrator.',
  'Mulai Screening': 'Start Screening',
  'Batal': 'Cancel',
  'Lanjutkan': 'Continue',
  'Selesai': 'Done',
  'Coba Lagi': 'Retry',
  'Konfirmasi Pengiriman Data': 'Confirm Data Transfer',
  'Saya menyetujui pengiriman data medis ini ke server':
      'I agree to send this medical data to the server',
  'Cadangan Data Medis': 'Medical Data Backup',
  'Data Medis Sensitif': 'Sensitive Medical Data',
  'Pilih Data & Unggah': 'Select Data & Upload',
  'Pilih Pasien untuk Dicadangkan': 'Select Patients to Back Up',
  'Pilih Semua': 'Select All',
  'Batal Pilih': 'Deselect All',
  'Mulai Unggah': 'Start Upload',
  'Mengunggah data pasien...': 'Uploading patient data...',
};

const _indonesian = <String, String>{
  'Login failed — no active AI model found. Please activate a model first or contact a technician.':
      'Login gagal — belum ada model AI yang aktif. Silakan aktifkan model terlebih dahulu atau hubungi teknisi.',
  'Offline cache': 'Data lokal luring',
  'Check the connection and try again.': 'Periksa koneksi dan coba lagi.',
  'Patient cache could not be refreshed.':
      'Data pasien lokal tidak dapat diperbarui.',
  'Choose a patient from the list to view their profile, latest X-ray and history timeline.':
      'Pilih pasien dari daftar untuk melihat profil, rontgen terbaru, dan linimasa riwayat.',
  'Latest chest X-ray preview': 'Pratinjau rontgen dada terbaru',
  'Initial screening completed': 'Skrining awal selesai',
  'Xpert positive': 'Xpert positif',
  'Follow-up scheduled': 'Tindak lanjut dijadwalkan',
  'No infiltrates detected': 'Tidak ditemukan infiltrat',
  'Monitoring in 30 days': 'Pemantauan dalam 30 hari',
  'Persistent cough reported': 'Dilaporkan batuk menetap',
  'IGRA pending': 'Menunggu hasil IGRA',
  'Pediatric score captured': 'Skor pediatrik tercatat',
  'Image quality acceptable': 'Kualitas gambar memadai',
  'History of smoking': 'Riwayat merokok',
  'Culture sent to lab': 'Kultur dikirim ke laboratorium',
  'Chest pain resolved': 'Nyeri dada teratasi',
  'No active lesion pattern': 'Tidak ada pola lesi aktif',
  'Previous TB history': 'Riwayat TB sebelumnya',
  'Urgent referral recommended': 'Disarankan rujukan segera',
  'Fatigue noted': 'Kelelahan tercatat',
  'Recheck if symptoms persist': 'Periksa ulang jika gejala menetap',
  'Patient Summary': 'Ringkasan Pasien',
  'Name': 'Nama',
  'Height': 'Tinggi',
  'Weight': 'Berat',
  'Clinical Data': 'Data Klinis',
  'Smoking Status': 'Status Merokok',
  'TB Contact': 'Kontak dengan TB',
  'Sputum (BTA)': 'Dahak (BTA)',
  'Culture': 'Kultur',
  'Not provided': 'Belum diisi',
  'Recommendations': 'Rekomendasi',
  'Refer to pulmonologist immediately': 'Segera rujuk ke dokter spesialis paru',
  'Start contact tracing': 'Mulai pelacakan kontak',
  'Order additional screening tests': 'Lakukan pemeriksaan skrining tambahan',
  'Monitor symptoms': 'Pantau gejala',
  'Schedule follow-up in 6 months': 'Jadwalkan tindak lanjut dalam 6 bulan',
  'Maintain healthy lifestyle': 'Pertahankan pola hidup sehat',
  'Analysis Details': 'Detail Analisis',
  'Analysis Date': 'Tanggal Analisis',
  'Model Version': 'Versi Model',
  'Processing Time': 'Waktu Pemrosesan',
  'Export PDF': 'Ekspor PDF',
  'Print': 'Cetak',
  'Saving...': 'Menyimpan...',
  'Queued': 'Dalam Antrean',
  'Saved': 'Tersimpan',
  'Retry Save': 'Coba Simpan Lagi',
  'Encrypted locally and queued for sync.':
      'Dienkripsi secara lokal dan masuk antrean sinkronisasi.',
  'The screening was not saved.': 'Skrining belum tersimpan.',
  'This result is encrypted locally but still pending sync. Starting a new screening will not delete it.':
      'Hasil dienkripsi secara lokal dan menunggu sinkronisasi. Memulai skrining baru tidak menghapusnya.',
  'This result is not safely synced. Review or retry saving before leaving.':
      'Hasil belum tersinkronisasi dengan aman. Tinjau atau coba simpan lagi sebelum keluar.',
  'Disabled until the saved-result PHI policy is approved.':
      'Dinonaktifkan sampai kebijakan data kesehatan untuk hasil tersimpan disetujui.',
  'All': 'Semua',
  'Total': 'Total',
  'Agreed': 'Setuju',
  'Disagreed': 'Tidak Setuju',
  'Conflicts': 'Konflik',
  'Conflict': 'Konflik',
  'AI Score': 'Skor AI',
  'Screening Date': 'Tanggal Skrining',
  'CHEST X-RAY VIEW': 'TAMPILAN RONTGEN DADA',
  'Heatmap View': 'Tampilan Peta Panas',
  'Original View': 'Tampilan Asli',
  'Consolidation': 'Konsolidasi',
  'Cavity': 'Kavitas',
  'Effusion': 'Efusi',
  'Fibrotic': 'Fibrosis',
  'Calcification': 'Kalsifikasi',
  'Add clinical notes or correction reason...':
      'Tambahkan catatan klinis atau alasan koreksi...',
  'You agreed with the AI result': 'Anda setuju dengan hasil AI',
  'You disagreed with the AI result': 'Anda tidak setuju dengan hasil AI',
  'Use the server verdict and discard this local verdict?':
      'Gunakan keputusan server dan buang keputusan lokal ini?',
  'Leave both values unchanged and keep this conflict open?':
      'Pertahankan kedua nilai dan biarkan konflik ini terbuka?',
  'Symptom Type': 'Jenis Gejala',
  'Environment': 'Lingkungan',
  'Select Gender': 'Pilih Jenis Kelamin',
  'Select Comorbidity': 'Pilih Komorbiditas',
  'Select Smoking Status': 'Pilih Status Merokok',
  'Select History': 'Pilih Riwayat',
  'Select Options': 'Pilih Opsi',
  'Select TB History': 'Pilih Riwayat TB',
  'Select TB Status': 'Pilih Status TB',
  'Select Model Type': 'Pilih Jenis Model',
  'Fever': 'Demam',
  'Cough': 'Batuk',
  'Night Sweats': 'Keringat Malam',
  'Weight Loss': 'Penurunan Berat Badan',
  'Shortness of Breath': 'Sesak Napas',
  'Fatigue': 'Kelelahan',
  'Dyspnea': 'Sesak Napas',
  'Hemoptysis': 'Batuk Darah',
  'Anorexia': 'Hilang Nafsu Makan',
  'Loss of Appetite': 'Hilang Nafsu Makan',
  'Chest Pain': 'Nyeri Dada',
  'Hemoptysis/Coughing Blood': 'Hemoptisis/Batuk Darah',
  'Other': 'Lainnya',
  'None': 'Tidak Ada',
  'Diabetes Mellitus': 'Diabetes Melitus',
  'Other Immunocompromised Conditions': 'Kondisi Imunokompromais Lainnya',
  'Never': 'Tidak Pernah',
  'Former': 'Mantan Perokok',
  'Current': 'Perokok Aktif',
  'Suspected': 'Suspek',
  'Follow-up': 'Tindak Lanjut',
  'Disability': 'Disabilitas',
  'Non Disability': 'Tanpa Disabilitas',
  'Required': 'Wajib diisi',
  'Gender is required': 'Jenis kelamin wajib diisi',
  'DATASET NAME': 'NAMA DATASET',
  'TOTAL IMAGES': 'TOTAL GAMBAR',
  'SIZE': 'UKURAN',
  'LAST UPDATED': 'TERAKHIR DIPERBARUI',
  'STATUS': 'STATUS',
  'ACTIONS': 'TINDAKAN',
  'ACTIVE': 'AKTIF',
  'ARCHIVED': 'DIARSIPKAN',
  'AI screening': 'Skrining AI',
  'Doctor review': 'Tinjauan dokter',
  '428 cases': '428 kasus',
  '247 validated': '247 tervalidasi',
  'TB Detected': 'TB Terdeteksi',
  'Male / Female': 'Laki-laki / Perempuan',
  'Datasets': 'Dataset',
  'Manage and organize your training datasets':
      'Kelola dan atur dataset pelatihan',
  'Create Dataset': 'Buat Dataset',
  'Back to Datasets': 'Kembali ke Dataset',
  'Create New Dataset': 'Buat Dataset Baru',
  'Add Images': 'Tambah Gambar',
  'Edit Dataset': 'Edit Dataset',
  'Total Images': 'Total Gambar',
  'Size': 'Ukuran',
  'Last Updated': 'Terakhir Diperbarui',
  'Dataset Images': 'Gambar Dataset',
  'Back to Detail': 'Kembali ke Detail',
  'Save Changes': 'Simpan Perubahan',
  'Upload Image': 'Unggah Gambar',
  'Click to upload or drag and drop':
      'Klik untuk mengunggah atau seret dan lepas',
  'SVG, PNG, JPG or DICOM (max. 50MB)':
      'SVG, PNG, JPG atau DICOM (maks. 50 MB)',
  'PNG, JPG, JPEG ? Maximum 25 MB': 'PNG, JPG, JPEG ? Maksimum 25 MB',
  'Screening Result (Dummy)': 'Hasil Skrining (Demo)',
  'TB Suspected': 'Dugaan TB',
  'Confidence 78% ? Demo Model v0.1': 'Keyakinan 78% ? Model Demo v0.1',
  'Please add a clinical note before disagreeing.':
      'Tambahkan catatan klinis sebelum memilih tidak setuju.',
  'Doctor Review': 'Tinjauan Dokter',
  'Validate AI screening results': 'Validasi hasil skrining AI',
  'AI Screening Result': 'Hasil Skrining AI',
  'Heatmap not available for this case':
      'Peta panas belum tersedia untuk kasus ini',
  'Doctor\'s Note': 'Catatan Dokter',
  'Disagree': 'Tidak Setuju',
  'Agree with AI Result': 'Setuju dengan Hasil AI',
  'Re-validate': 'Validasi Ulang',
  'Select a patient from the list to review\nthe AI screening result':
      'Pilih pasien dari daftar untuk meninjau\nhasil skrining AI',
  'Unvalidated': 'Belum Tervalidasi',
  'of 3,567 total': 'dari total 3.567',
  'awaiting review': 'menunggu tinjauan',
  'AI Screening Distribution': 'Distribusi Skrining AI',
  'Doctor Validation Distribution': 'Distribusi Validasi Dokter',
  'Enter your email': 'Masukkan email',
  'Enter your password': 'Masukkan kata sandi',
  'Search patients...': 'Cari pasien...',
  'Search datasets by name': 'Cari dataset berdasarkan nama',
  'Dataset Name': 'Nama Dataset',
  'Description': 'Deskripsi',
  'Image Code': 'Kode Gambar',
  'e.g. XRAY-8892': 'contoh: XRAY-8892',
  'Search patient or ID': 'Cari pasien atau ID',
  'Last Visit': 'Kunjungan Terakhir',
  'Confidence': 'Tingkat Keyakinan',
  'Name/Initial/NickName': 'Nama/Inisial/Nama Panggilan',
  'Height (cm)': 'Tinggi (cm)',
  'Weight (kg)': 'Berat (kg)',
  'Comorbidity': 'Komorbiditas',
  'Smoking': 'Merokok',
  'History of Contact with TB': 'Riwayat Kontak dengan TB',
  'If Age < 18 years Old Pediatric TB Scoring':
      'Skor TB Anak untuk Usia < 18 Tahun',
  'Presence of Windows': 'Keberadaan Jendela',
  'Direct Sunlight': 'Sinar Matahari Langsung',
  'Expel Sputum:': 'Pemeriksaan Dahak:',
  'Culture:': 'Kultur:',
  'History of TB': 'Riwayat TB',
  'TB Status': 'Status TB',
  'Model Type': 'Jenis Model',
  'Patient data unavailable': 'Data pasien belum tersedia',
  'No patients found': 'Pasien tidak ditemukan',
  'No patient records are available for this account.':
      'Tidak ada data pasien untuk akun ini.',
  'Select a patient': 'Pilih pasien',
  'Validation unavailable': 'Validasi belum tersedia',
  'Yes': 'Ya',
  'No': 'Tidak',
  'Unknown': 'Tidak Diketahui',
  'Dashboard': 'Dasbor',
  'Patients': 'Pasien',
  'Screening': 'Skrining',
  'Result': 'Hasil',
  'Validation': 'Validasi',
  'Dataset': 'Dataset',
  'Sync': 'Sinkronisasi',
  'Account': 'Akun',
  'Role': 'Peran',
  'Instansi akun': 'Instansi akun',
  'Account institution': 'Instansi akun',
  'Not available': 'Belum tersedia',
  'Demo institution (synthetic data)': 'Instansi demo (data sintetis)',
  'New Screening': 'Skrining Baru',
  'Agreement Level': 'Tingkat Kesepakatan',
  'Consistency between AI screening and doctor review':
      'Kesesuaian antara skrining AI dan tinjauan dokter',
  '3,139 validated cases': '3.139 kasus tervalidasi',
  'Screening volume, last 30 days': 'Jumlah skrining, 30 hari terakhir',
  'TB Case Distribution': 'Distribusi Kasus TB',
  'Doctor distribution only includes validated cases.':
      'Distribusi dokter hanya mencakup kasus tervalidasi.',
  'Recent Activity': 'Aktivitas Terbaru',
  'Full history unavailable': 'Riwayat lengkap belum tersedia',
  'Total Screenings': 'Total Skrining',
  'Total Patients': 'Total Pasien',
  'Positive': 'Positif',
  'Negative': 'Negatif',
  'Positive TB': 'TB Positif',
  'Negative TB': 'TB Negatif',
  'All Cases': 'Semua Kasus',
  'Last 30 days': '30 hari terakhir',
  'Last 60 days': '60 hari terakhir',
  'Last 3 months': '3 bulan terakhir',
  'Last 6 months': '6 bulan terakhir',
  'AI Distribution': 'Distribusi AI',
  'Doctor Distribution': 'Distribusi Dokter',
  'AI Screening': 'Skrining AI',
  'Doctor Validation': 'Validasi Dokter',
  'Pending Validation': 'Menunggu Validasi',
  'Welcome Back': 'Selamat Datang Kembali',
  'AI-Powered TB Screening': 'Skrining TB Berbasis AI',
  'Email': 'Email',
  'Password': 'Kata Sandi',
  'Sign In': 'Masuk',
  'Sign Out': 'Keluar',
  'Edit profile unavailable': 'Edit profil belum tersedia',
  'Password / 2FA unavailable': 'Kata sandi / 2FA belum tersedia',
  'Instansi mengikuti akun dan ditetapkan oleh admin.':
      'Instansi mengikuti akun dan ditetapkan oleh admin.',
  'Profile editing and security status unavailable: backend contract pending.':
      'Edit profil dan status keamanan belum tersedia: menunggu kontrak backend.',
  'Sign out cleanup failed. Please retry.':
      'Pembersihan sesi keluar gagal. Silakan coba lagi.',
  'Dashboard aggregation and institution filters unavailable: backend contract pending.':
      'Agregasi dasbor belum tersedia: menunggu kontrak backend.',
  'Dataset access and CRUD unavailable: backend contract and role permissions pending.':
      'Akses dan pengelolaan dataset belum tersedia: menunggu kontrak backend dan izin peran.',
  'Align the complete chest X-ray inside the frame':
      'Posisikan seluruh foto rontgen dada di dalam bingkai',
  'Try camera again': 'Coba kamera lagi',
  'Retake': 'Ambil Ulang',
  'Use this image': 'Gunakan gambar ini',
  'TB X-ray Analysis with AI': 'Analisis Rontgen TB dengan AI',
  'Analyze': 'Analisis',
  'A. Bacteriology': 'A. Bakteriologi',
  'B. Others': 'B. Lainnya',
  'Upload X-Ray Image': 'Unggah Foto Rontgen',
  'Choose Image': 'Pilih Gambar',
  'Use Camera': 'Gunakan Kamera',
  'Use the original digital X-ray when available. Camera capture may reduce image quality.':
      'Gunakan foto rontgen digital asli jika tersedia. Pengambilan dengan kamera dapat mengurangi kualitas gambar.',
  'No matching patients': 'Tidak ada pasien yang cocok',
  'Screen patient': 'Skrining pasien',
  'X-ray Card': 'Kartu Rontgen',
  'History Timeline': 'Linimasa Riwayat',
  'No screening result yet.': 'Belum ada hasil skrining.',
  'Start Screening': 'Mulai Skrining',
  'Screening Result': 'Hasil Skrining',
  'Image unavailable': 'Gambar belum tersedia',
  'Image preview unavailable': 'Pratinjau gambar belum tersedia',
  'AI Confidence': 'Tingkat Keyakinan AI',
  'AI results are screening tools only.\nConfirmation by a qualified medical professional is required.':
      'Hasil AI hanya merupakan alat skrining.\nKonfirmasi oleh tenaga medis yang kompeten diperlukan.',
  'Start a new screening?': 'Mulai skrining baru?',
  'Stay': 'Tetap di Sini',
  'Continue': 'Lanjutkan',
  'Leave this screening?': 'Tinggalkan skrining ini?',
  'This result is not yet synced. Pending local data stays in the queue; an unsaved result needs saving before starting another screening.':
      'Hasil ini belum tersinkronisasi. Data lokal tetap dalam antrean; simpan hasil sebelum memulai skrining lain.',
  'Sync Center': 'Pusat Sinkronisasi',
  'Connection not verified': 'Koneksi belum terverifikasi',
  'Model installation unavailable: signed artifacts and verification contract pending.':
      'Instalasi model belum tersedia: menunggu artefak bertanda tangan dan kontrak verifikasi.',
  'Download unavailable': 'Unduhan belum tersedia',
  'Confirm conflict decision': 'Konfirmasi keputusan konflik',
  'Back': 'Kembali',
  'Confirm': 'Konfirmasi',
  'Retry': 'Coba Lagi',
  'Conflict details are loading. No clinical value was overwritten.':
      'Detail konflik sedang dimuat. Tidak ada nilai klinis yang ditimpa.',
  'Doctor review conflict': 'Konflik tinjauan dokter',
  'Cancel / keep open': 'Batal / tetap terbuka',
  'Keep server': 'Gunakan versi server',
  'Reapply local': 'Terapkan ulang versi lokal',
  'Reconnect to fetch the authoritative server snapshot.':
      'Hubungkan kembali untuk mengambil data acuan dari server.',
  'Cancel': 'Batal',
  'Save': 'Simpan',
  'Search': 'Cari',
  'Add Patient': 'Tambah Pasien',
  'Edit Patient': 'Edit Pasien',
  'Patient Name': 'Nama Pasien',
  'Full Name': 'Nama Lengkap',
  'Gender': 'Jenis Kelamin',
  'Male': 'Laki-laki',
  'Female': 'Perempuan',
  'Age': 'Usia',
  'Date of Birth': 'Tanggal Lahir',
  'Phone': 'Telepon',
  'Address': 'Alamat',
  'Notes': 'Catatan',
  'Status': 'Status',
  'Actions': 'Tindakan',
  'Details': 'Detail',
  'View': 'Lihat',
  'Delete': 'Hapus',
  'Close': 'Tutup',
  'Pending': 'Menunggu',
  'Validated': 'Tervalidasi',
  'Normal': 'Normal',
  'Abnormal': 'Abnormal',
  'Confirm Data Transfer': 'Konfirmasi Pengiriman Data',
  'I agree to send this medical data to the server':
      'Saya menyetujui pengiriman data medis ini ke server',
  'Medical Data Backup': 'Cadangan Data Medis',
  'Sensitive Medical Data': 'Data Medis Sensitif',
  'Select Data & Upload': 'Pilih Data & Unggah',
  'Select Patients to Back Up': 'Pilih Pasien untuk Dicadangkan',
  'Select All': 'Pilih Semua',
  'Deselect All': 'Batal Pilih',
  'Start Upload': 'Mulai Unggah',
  'Uploading patient data...': 'Mengunggah data pasien...',
  'Done': 'Selesai',
  'No internet connection. Connect the device and try again.':
      'Tidak ada koneksi internet. Hubungkan perangkat dan coba lagi.',
};
