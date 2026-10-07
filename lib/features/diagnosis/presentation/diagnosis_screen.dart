import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_input_tab.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_result_tab.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:provider/provider.dart';

/// Combined Screening + Result screen. Tab 1 is the patient/X-ray input
/// form; tab 2 is the AI result. There's no visible tab bar — the view
/// jumps to tab 2 automatically right after a successful analysis, and
/// back to tab 1 on reset/"Screening Baru", so content stays full-height.
/// Swiping the body still moves between tabs (blocked into tab 2 until a
/// result exists), which is why the `TabController`/`TabBarView` stay.
class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key, this.pickImage, this.hasModelOverride});

  /// Injection point used by widget tests; production uses [XrayImagePicker].
  final PickXrayImage? pickImage;

  /// Test-only override for whether an on-device AI model is installed.
  final bool? hasModelOverride;

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = context.watch<DiagnosisProvider>();
    final hasResult = diagnosis.lastOutcome != null;

    // Snap back to the input tab if the result disappears while tab 2 is
    // active: a confirmed reset, any field edit (DiagnosisProvider._replace
    // already clears lastResult on every edit), or a session/logout reset.
    if (!hasResult && _tabController.index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index == 1) {
          _tabController.animateTo(0);
        }
      });
    }

    return TabBarView(
      key: const Key('diagnosis-tab-view'),
      controller: _tabController,
      // Also blocks swipe-navigation into the disabled tab.
      physics: hasResult
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      children: [
        DiagnosisInputTab(
          pickImage: widget.pickImage,
          hasModelOverride: widget.hasModelOverride,
          onAnalyzeSuccess: () => _tabController.animateTo(1),
        ),
        DiagnosisResultTab(
          onNewScreening: () => _tabController.animateTo(0),
        ),
      ],
    );
  }
}
