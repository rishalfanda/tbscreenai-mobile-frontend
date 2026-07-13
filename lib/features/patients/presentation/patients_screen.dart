import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/mock_data.dart';
import 'package:myapp/features/shared/presentation/widgets/widgets.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  PatientSummary? _selected = MockData.patients.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final patients = MockData.patients
        .where((patient) => patient.name.toLowerCase().contains(query) || patient.id.toLowerCase().contains(query))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adaptive master width so the detail panel always has room to
          // breathe on narrower tablet widths (portrait / split view).
          final listWidth = constraints.maxWidth < 900 ? 300.0 : 420.0;
          return Row(
        children: [
          SizedBox(
            width: listWidth,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search patient or ID',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        itemCount: patients.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final patient = patients[index];
                          final active = _selected?.id == patient.id;
                          return AppCard(
                            selected: active,
                            padding: const EdgeInsets.all(14),
                            onTap: () => setState(() => _selected = patient),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: active ? AppTheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.16),
                                  foregroundColor: AppTheme.primaryDark,
                                  child: Text(
                                    patient.name.split(' ').take(2).map((part) => part[0]).join(),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(patient.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy)),
                                      const SizedBox(height: 4),
                                      Text('${patient.age} yrs • ${patient.gender}',
                                          style: const TextStyle(color: AppTheme.subtitleGrey, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                StatusBadge.forStatus(patient.status, dense: true),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _selected == null
                ? const _EmptyPatientState()
                : SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.16),
                                  foregroundColor: AppTheme.primaryDark,
                                  child: Text(
                                    _selected!.name.split(' ').take(2).map((part) => part[0]).join(),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selected!.name,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.navy,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(_selected!.id),
                                    ],
                                  ),
                                ),
                                StatusBadge.forStatus(_selected!.status),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _InfoBox(label: 'Age', value: '${_selected!.age} years'),
                            _InfoBox(label: 'Gender', value: _selected!.gender),
                            _InfoBox(label: 'Last Visit', value: _selected!.lastVisit),
                            _InfoBox(label: 'Confidence', value: '${_selected!.confidence}%'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'X-ray Card',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 16),
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF111827),
                                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('Latest chest X-ray preview', style: TextStyle(color: Colors.white70)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'History Timeline',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 16),
                                ..._selected!.history.map(
                                  (entry) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.timeline_rounded, color: AppTheme.primaryDark),
                                    title: Text(entry),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
          );
        },
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyPatientState extends StatelessWidget {
  const _EmptyPatientState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.person_search_rounded,
      title: 'Select a patient',
      message: 'Choose a patient from the list to view their profile, latest X-ray and history timeline.',
    );
  }
}
