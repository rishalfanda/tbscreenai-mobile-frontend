/// One point on the diagnosis-trends chart.
class TrendDataPoint {
  const TrendDataPoint({
    required this.date,
    required this.totalDiagnoses,
    required this.totalPatients,
  });

  final String date;
  final int totalDiagnoses;
  final int totalPatients;
}
