import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_input_tab.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_result_tab.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:provider/provider.dart';

/// Combined Screening + Result screen. Tab 1 is the patient/X-ray input
/// form; tab 2 is the AI result. Tab 2 stays disabled until an analysis
/// exists, and the view jumps there automatically right after one succeeds.
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

  // TabBar.onTap fires after the controller's index has already moved —
  // vetoing it back here, in the same event pass, is the standard way to
  // make a tab "disabled" since TabBar/Tab have no first-class API for it.
  void _handleTabTap(int index, bool hasResult) {
    if (index == 1 && !hasResult) _tabController.index = 0;
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

    return Column(
      children: [
        Material(
          color: diagnosisPanel,
          child: TabBar(
            key: const Key('diagnosis-tab-bar'),
            controller: _tabController,
            onTap: (index) => _handleTabTap(index, hasResult),
            indicatorColor: diagnosisAccent,
            labelColor: diagnosisAccent,
            unselectedLabelColor: diagnosisMuted,
            tabs: [
              const Tab(
                key: Key('diagnosis-tab-input'),
                icon: Icon(Icons.edit_note_rounded),
                text: 'Input Data',
              ),
              Tab(
                key: const Key('diagnosis-tab-result'),
                icon: Icon(
                  Icons.analytics_rounded,
                  color: hasResult ? null : diagnosisMuted.withValues(
                    alpha: 0.5,
                  ),
                ),
                child: Opacity(
                  opacity: hasResult ? 1 : 0.45,
                  child: const Text('Hasil Analisis'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
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
          ),
        ),
      ],
    );
  }
}
