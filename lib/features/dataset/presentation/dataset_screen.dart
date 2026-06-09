import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/mock_data.dart';

class DatasetScreen extends StatefulWidget {
  const DatasetScreen({super.key});

  @override
  State<DatasetScreen> createState() => _DatasetScreenState();
}

class _DatasetScreenState extends State<DatasetScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final rows = MockData.dataset.where((record) {
      final matchesQuery = record.patientId.toLowerCase().contains(query) || record.image.toLowerCase().contains(query);
      final matchesFilter = _filter == 'All' || record.status == _filter;
      return matchesQuery && matchesFilter;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dataset',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                          ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload'),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by patient ID or image',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filter,
                      decoration: const InputDecoration(labelText: 'Filter'),
                      items: const ['All', 'Labeled', 'Pending', 'Reviewed']
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) => setState(() => _filter = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Patient ID')),
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: rows
                          .map(
                            (record) => DataRow(
                              cells: [
                                DataCell(Text(record.date)),
                                DataCell(Text(record.patientId)),
                                DataCell(Text(record.image)),
                                DataCell(Chip(label: Text(record.status))),
                                DataCell(
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      IconButton(onPressed: () {}, icon: const Icon(Icons.remove_red_eye_outlined)),
                                      IconButton(onPressed: () {}, icon: const Icon(Icons.download_rounded)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () {}, child: const Text('Previous')),
                  const SizedBox(width: 8),
                  const Chip(label: Text('Page 1 of 4')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () {}, child: const Text('Next')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
