/// 5-tier risk categorization for chest X-ray screening based on model score.
enum ScreeningLevel {
  veryLow,
  low,
  greyArea,
  high,
  veryHigh;

  /// English classification tier label.
  String get label => switch (this) {
    ScreeningLevel.veryLow => 'Very Low',
    ScreeningLevel.low => 'Low',
    ScreeningLevel.greyArea => 'Grey Area',
    ScreeningLevel.high => 'High',
    ScreeningLevel.veryHigh => 'Very High',
  };

  /// Bahasa Indonesia interpretation of the model's confidence.
  String get interpretation => switch (this) {
    ScreeningLevel.veryLow =>
      'Model memiliki keyakinan sangat rendah terhadap adanya indikasi TB.',
    ScreeningLevel.low =>
      'Kemungkinan TB rendah, namun belum dapat sepenuhnya dikesampingkan.',
    ScreeningLevel.greyArea =>
      'Model tidak dapat memberikan keputusan dengan keyakinan yang cukup.',
    ScreeningLevel.high =>
      'Model menunjukkan indikasi TB dengan keyakinan tinggi.',
    ScreeningLevel.veryHigh =>
      'Model menunjukkan indikasi TB dengan keyakinan sangat tinggi.',
  };

  /// Recommended medical next step / follow-up action.
  String get followUp => switch (this) {
    ScreeningLevel.veryLow =>
      'Hasil skrining negatif. Tetap mempertimbangkan gejala klinis dan faktor risiko pasien.',
    ScreeningLevel.low =>
      'Hasil skrining negatif. Pemeriksaan lanjutan bila terdapat gejala atau faktor risiko tinggi.',
    ScreeningLevel.greyArea =>
      'Wajib dilakukan validasi tambahan oleh dokter, disertai evaluasi klinis dan pemeriksaan penunjang.',
    ScreeningLevel.high =>
      'Hasil skrining positif. Perlu dilanjutkan dengan pemeriksaan lanjutan.',
    ScreeningLevel.veryHigh =>
      'Hasil skrining positif. Perlu dilanjutkan dengan pemeriksaan lanjutan.',
  };

  /// UI status badge text: 'TB', 'Non-TB', or 'Grey Area'.
  String get statusLabel => switch (this) {
    ScreeningLevel.veryLow => 'Non-TB',
    ScreeningLevel.low => 'Non-TB',
    ScreeningLevel.greyArea => 'Grey Area',
    ScreeningLevel.high => 'TB',
    ScreeningLevel.veryHigh => 'TB',
  };

  /// Formatted score range string.
  String get scoreRange => switch (this) {
    ScreeningLevel.veryLow => '0% - 20%',
    ScreeningLevel.low => '20% - 40%',
    ScreeningLevel.greyArea => '40% - 60%',
    ScreeningLevel.high => '60% - 80%',
    ScreeningLevel.veryHigh => '80% - 100%',
  };

  /// Whether this outcome represents a positive screening result.
  bool get isPositive =>
      this == ScreeningLevel.high || this == ScreeningLevel.veryHigh;

  /// Whether this outcome falls in the indeterminate / grey area range.
  bool get isGreyArea => this == ScreeningLevel.greyArea;

  /// Classifies a 0-100 TB indication score into its corresponding tier.
  static ScreeningLevel fromScore(num score) {
    final clamped = score.clamp(0, 100);
    if (clamped <= 20) return ScreeningLevel.veryLow;
    if (clamped <= 40) return ScreeningLevel.low;
    if (clamped <= 60) return ScreeningLevel.greyArea;
    if (clamped <= 80) return ScreeningLevel.high;
    return ScreeningLevel.veryHigh;
  }
}

