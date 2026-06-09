import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/validation_mock.dart';

// TODO: Replace mock data with GET /api/validation/cases
// TODO: Replace local state update with POST /api/validation/cases/:id/agree

class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  late List<ValidationCase> _cases;
  String? _selectedId;
  String _activeTab = "pending";
  String _searchQuery = "";
  bool _isSubmitting = false;
  final TextEditingController _noteController = TextEditingController();
  bool _isHeatmapView = false;

  @override
  void initState() {
    super.initState();
    _cases = List.from(mockCases);
    _autoSelectFirstPending();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _autoSelectFirstPending() {
    try {
      final firstPending = _cases.firstWhere((c) => c.status == "pending");
      _selectedId = firstPending.id;
      _noteController.text = firstPending.doctorNote ?? "";
    } catch (e) {
      _selectedId = _cases.isNotEmpty ? _cases.first.id : null;
      if (_selectedId != null) {
        _noteController.text = _cases.firstWhere((c) => c.id == _selectedId).doctorNote ?? "";
      }
    }
  }

  List<ValidationCase> get _filteredCases {
    return _cases.where((c) {
      final matchesTab = _activeTab == "all" || c.status == _activeTab;
      final matchesSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.id.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesTab && matchesSearch;
    }).toList();
  }

  Map<String, int> get _summaryCounts {
    return {
      "total": _cases.length,
      "pending": _cases.where((c) => c.status == "pending").length,
      "agreed": _cases.where((c) => c.status == "agreed").length,
      "disagreed": _cases.where((c) => c.status == "disagreed").length,
    };
  }

  void _onSelectCase(ValidationCase c) {
    setState(() {
      _selectedId = c.id;
      _noteController.text = c.doctorNote ?? "";
      _isHeatmapView = false;
    });
  }

  Future<void> _handleValidation(String newStatus) async {
    if (_selectedId == null) return;

    if (newStatus == "disagreed" && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add a clinical note before disagreeing."),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate artificial delay
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      final index = _cases.indexWhere((c) => c.id == _selectedId);
      if (index != -1) {
        _cases[index] = _cases[index].copyWith(
          status: newStatus,
          doctorNote: _noteController.text.trim(),
        );
      }
      _isSubmitting = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == "agreed" ? "Marked as Agreed" : "Marked as Disagreed"),
          backgroundColor: AppTheme.success,
        ),
      );

      // Auto-advance
      try {
        final nextPending = _cases.firstWhere((c) => c.status == "pending");
        _onSelectCase(nextPending);
      } catch (e) {
        // No more pending cases
      }
    });
  }

  void _resetStatus() {
    if (_selectedId == null) return;
    setState(() {
      final index = _cases.indexWhere((c) => c.id == _selectedId);
      if (index != -1) {
        _cases[index] = _cases[index].copyWith(status: "pending");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = _summaryCounts;
    final filtered = _filteredCases;
    final selectedCase = _selectedId != null ? _cases.firstWhere((c) => c.id == _selectedId) : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // LEFT PANEL
          Container(
            width: 340,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Doctor Review",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.navy),
                      ),
                      const Text(
                        "Validate AI diagnosis results",
                        style: TextStyle(fontSize: 13, color: AppTheme.subtitleGrey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SummaryItem(label: "Total", count: counts["total"]!, color: AppTheme.subtitleGrey),
                          _SummaryItem(label: "Pending", count: counts["pending"]!, color: AppTheme.warning),
                          _SummaryItem(label: "Agreed", count: counts["agreed"]!, color: AppTheme.success),
                          _SummaryItem(label: "Disagreed", count: counts["disagreed"]!, color: AppTheme.error),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "Search patients...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _TabItem(label: "All", active: _activeTab == "all", onTap: () => setState(() => _activeTab = "all")),
                      _TabItem(
                        label: "Pending",
                        active: _activeTab == "pending",
                        count: counts["pending"],
                        onTap: () => setState(() => _activeTab = "pending"),
                      ),
                      _TabItem(label: "Agreed", active: _activeTab == "agreed", onTap: () => setState(() => _activeTab = "agreed")),
                      _TabItem(label: "Disagreed", active: _activeTab == "disagreed", onTap: () => setState(() => _activeTab = "disagreed")),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return _PatientItem(
                        c: c,
                        isSelected: _selectedId == c.id,
                        onTap: () => _onSelectCase(c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // RIGHT PANEL
          Expanded(
            child: selectedCase == null
                ? const _EmptyState()
                : SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: _getStatusColor(selectedCase.status).withValues(alpha: 0.1),
                              child: Text(
                                selectedCase.initials,
                                style: TextStyle(color: _getStatusColor(selectedCase.status), fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedCase.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.navy),
                                ),
                                Text(
                                  "Patient ID: #${selectedCase.id}",
                                  style: const TextStyle(fontSize: 13, color: AppTheme.subtitleGrey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _MetaField(label: "Age", value: "${selectedCase.age} yrs"),
                            _MetaField(label: "Gender", value: selectedCase.gender),
                            _MetaField(
                              label: "AI Score",
                              value: "TBC ${selectedCase.aiScore}%",
                              valueColor: _getAiScoreColor(selectedCase.aiScore),
                            ),
                            _MetaField(label: "Diagnosis Date", value: selectedCase.diagnosisDate),
                          ],
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          "AI Diagnosis Result",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.navy),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 360,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1117),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              const Center(
                                child: Text(
                                  "CHEST X-RAY VIEW",
                                  style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF9F27).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "TBC ${selectedCase.aiScore}%",
                                    style: const TextStyle(color: Color(0xFFEF9F27), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                left: 16,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (selectedCase.heatmapUrl == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Heatmap not available for this case")),
                                      );
                                    } else {
                                      setState(() => _isHeatmapView = !_isHeatmapView);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white10,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                  child: Text(_isHeatmapView ? "Original View" : "Heatmap View"),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _FindingsRow(findings: selectedCase.findings),
                        const SizedBox(height: 32),
                        const Text(
                          "Doctor's Note",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.navy),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteController,
                          maxLines: 4,
                          maxLength: 500,
                          readOnly: selectedCase.status != "pending",
                          decoration: InputDecoration(
                            hintText: "Add clinical notes or correction reason...",
                            fillColor: Colors.white,
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.cyan),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (selectedCase.status == "pending")
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting ? null : () => _handleValidation("disagreed"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.error,
                                    side: const BorderSide(color: AppTheme.error),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: const Text("Disagree"),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : () => _handleValidation("agreed"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B6EE8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text("Agree with AI Result"),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: (selectedCase.status == "agreed" ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selectedCase.status == "agreed" ? Icons.check_circle : Icons.cancel,
                                      color: selectedCase.status == "agreed" ? AppTheme.success : AppTheme.error,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      selectedCase.status == "agreed" ? "You agreed with the AI result" : "You disagreed with the AI result",
                                      style: TextStyle(
                                        color: selectedCase.status == "agreed" ? AppTheme.success : AppTheme.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _resetStatus,
                                child: const Text("Re-validate", style: TextStyle(color: AppTheme.cyan, decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "agreed":
        return AppTheme.success;
      case "disagreed":
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Color _getAiScoreColor(int score) {
    if (score > 70) return const Color(0xFFE24B4A);
    if (score >= 30) return const Color(0xFFEF9F27);
    return const Color(0xFF1D9E75);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.subtitleGrey)),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool active;
  final int? count;
  final VoidCallback onTap;

  const _TabItem({required this.label, required this.active, this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onHover: (_) {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.cyan.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.cyan : AppTheme.subtitleGrey,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
                child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PatientItem extends StatelessWidget {
  final ValidationCase c;
  final bool isSelected;
  final VoidCallback onTap;

  const _PatientItem({required this.c, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(c.status);
    return InkWell(
      onTap: onTap,
      onHover: (_) {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cyan.withValues(alpha: 0.05) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: statusColor.withValues(alpha: 0.1),
              child: Text(c.initials, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navy)),
                  Text("TBC ${c.aiScore}% · ${c.diagnosisDate}", style: const TextStyle(fontSize: 12, color: AppTheme.subtitleGrey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                c.status[0].toUpperCase() + c.status.substring(1),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: AppTheme.subtitleGrey),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "agreed":
        return AppTheme.success;
      case "disagreed":
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }
}

class _MetaField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaField({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.subtitleGrey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor ?? AppTheme.navy)),
      ],
    );
  }
}

class _FindingsRow extends StatelessWidget {
  final ValidationFindings findings;

  const _FindingsRow({required this.findings});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FindingItem(label: "Consolidation", value: findings.consolidation),
          _divider(),
          _FindingItem(label: "Cavity", value: findings.cavity),
          _divider(),
          _FindingItem(label: "Effusion", value: findings.effusion),
          _divider(),
          _FindingItem(label: "Fibrotic", value: findings.fibrotic),
          _divider(),
          _FindingItem(label: "Calcification", value: findings.calcification),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 24, width: 1, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _FindingItem extends StatelessWidget {
  final String label;
  final double value;

  const _FindingItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    Color color = AppTheme.subtitleGrey;
    if (value > 20) {
      color = const Color(0xFFE24B4A);
    } else if (value >= 5) {
      color = const Color(0xFFEF9F27);
    }

    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.subtitleGrey)),
        Text("${value.toStringAsFixed(1)}%", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Select a patient from the list to review\nthe AI diagnosis result",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.subtitleGrey),
          ),
        ],
      ),
    );
  }
}
