import 'package:flutter/material.dart';

/// Shared dark palette for the diagnosis screen's tab host and its "Input
/// Data" tab. Kept in its own file (rather than file-private consts) since
/// both `diagnosis_screen.dart` and `widgets/diagnosis_input_tab.dart` need
/// to paint the same theme. The "Hasil Analisis" tab uses its own, separate
/// dark palette (`widgets/diagnosis_result_tab.dart`) — the two tabs have
/// always looked visually distinct, and this merge doesn't change that.
const Color diagnosisPage = Color(0xFF111827);
const Color diagnosisPanel = Color(0xFF1E293B);
const Color diagnosisInput = Color(0xFF0F172A);
const Color diagnosisBorder = Color(0xFF475569);
const Color diagnosisText = Color(0xFFF8FAFC);
const Color diagnosisMuted = Color(0xFF94A3B8);
const Color diagnosisAccent = Color(0xFF4F9BFF);
const Color diagnosisAction = Color(0xFF2463EB);
