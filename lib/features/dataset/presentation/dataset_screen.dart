import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/dataset_mock.dart';

enum DatasetView { list, create, detail, edit }

class DatasetScreen extends StatefulWidget {
  const DatasetScreen({super.key});

  @override
  State<DatasetScreen> createState() => _DatasetScreenState();
}

class _DatasetScreenState extends State<DatasetScreen> {
  DatasetView _currentView = DatasetView.list;
  DatasetModel? _selectedDataset;
  List<DatasetModel> _datasets = List.from(mockDatasets);
  final _searchController = TextEditingController();

  void _navigate(DatasetView view, [DatasetModel? dataset]) {
    setState(() {
      _currentView = view;
      _selectedDataset = dataset;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: switch (_currentView) {
        DatasetView.list => _buildListView(),
        DatasetView.create => _buildCreateView(),
        DatasetView.detail => _buildDetailView(),
        DatasetView.edit => _buildEditView(),
      },
    );
  }

  Widget _buildListView() {
    final filtered = _datasets.where((d) =>
      d.name.toLowerCase().contains(_searchController.text.toLowerCase())
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Datasets",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage and organize your training datasets",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.subtitleGrey,
                  ),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () => _navigate(DatasetView.create),
              icon: const Icon(Icons.add),
              label: const Text("Create Dataset"),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 400,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search datasets by name",
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            side: const BorderSide(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
                  border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Text(
                        "DATASET NAME",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.subtitleGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "TOTAL IMAGES",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.subtitleGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "SIZE",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.subtitleGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "LAST UPDATED",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.subtitleGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "STATUS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.subtitleGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "ACTIONS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.subtitleGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...filtered.map((dataset) => _buildDatasetRow(dataset)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatasetRow(DatasetModel dataset) {
    final statusColor = dataset.status == "ACTIVE" ? AppTheme.success : AppTheme.subtitleGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dataset.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dataset.description,
                        style: TextStyle(
                          color: AppTheme.subtitleGrey,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "${dataset.totalImages}",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.navy,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              dataset.size,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.navy,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              dataset.lastUpdated,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.subtitleGrey,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                dataset.status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  onPressed: () => _navigate(DatasetView.detail, dataset),
                  icon: const Icon(Icons.visibility_outlined, color: AppTheme.primary),
                  tooltip: "View",
                ),
                IconButton(
                  onPressed: () => _navigate(DatasetView.edit, dataset),
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.navy),
                  tooltip: "Edit",
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined, color: AppTheme.subtitleGrey),
                  tooltip: "Download",
                ),
                IconButton(
                  onPressed: () => _showConfirmDeleteDialog(
                    dataset.name,
                    () {
                      setState(() {
                        _datasets.removeWhere((d) => d.id == dataset.id);
                      });
                    },
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                  tooltip: "Delete",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateView() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedStatus = "ACTIVE";

    return StatefulBuilder(
      builder: (context, setFormState) {
        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _navigate(DatasetView.list),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text("Back to Datasets"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.borderLight),
                      foregroundColor: AppTheme.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                "Create New Dataset",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  side: const BorderSide(color: AppTheme.borderLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Dataset Name",
                          labelStyle: const TextStyle(color: AppTheme.subtitleGrey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                        validator: (value) => value?.isEmpty == true ? "Required" : null,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: "Description",
                          alignLabelWithHint: true,
                          labelStyle: const TextStyle(color: AppTheme.subtitleGrey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: "Status",
                          labelStyle: const TextStyle(color: AppTheme.subtitleGrey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                        items: const ["ACTIVE", "ARCHIVED"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) => setFormState(() => selectedStatus = value!),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _navigate(DatasetView.list),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.borderLight),
                              foregroundColor: AppTheme.navy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                              ),
                            ),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                final newDataset = DatasetModel(
                                  id: "DS${(_datasets.length + 1).toString().padLeft(3, '0')}",
                                  name: nameController.text,
                                  description: descController.text,
                                  totalImages: 0,
                                  size: "0 B",
                                  lastUpdated: DateTime.now().toString().split(' ')[0],
                                  status: selectedStatus,
                                  images: const [],
                                );
                                setState(() {
                                  _datasets.add(newDataset);
                                });
                                _navigate(DatasetView.list);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                              ),
                            ),
                            child: const Text("Create Dataset"),
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
      },
    );
  }

  Widget _buildDetailView() {
    if (_selectedDataset == null) return const SizedBox.shrink();
    final dataset = _selectedDataset!;
    final statusColor = dataset.status == "ACTIVE" ? AppTheme.success : AppTheme.subtitleGrey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () => _navigate(DatasetView.list),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text("Back to Datasets"),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.borderLight),
                foregroundColor: AppTheme.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                ),
              ),
            ),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _showUploadImageDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Images"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _navigate(DatasetView.edit, dataset),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text("Edit Dataset"),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderLight),
                    foregroundColor: AppTheme.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            side: const BorderSide(color: AppTheme.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.folder_rounded, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dataset.name,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    dataset.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dataset.description,
                              style: TextStyle(
                                color: AppTheme.subtitleGrey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Images",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtitleGrey,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${dataset.totalImages}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Size",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtitleGrey,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dataset.size,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Last Updated",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtitleGrey,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dataset.lastUpdated,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "Dataset Images",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: dataset.images.length,
          itemBuilder: (context, index) {
            final image = dataset.images[index];
            final diagColor = image.diagnosis == "Positive / TBC" ? AppTheme.error : AppTheme.success;
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.borderLight),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: const Icon(Icons.image_outlined, size: 48, color: AppTheme.subtitleGrey),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              image.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Added ${image.addedDate}",
                              style: TextStyle(
                                color: AppTheme.subtitleGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 80,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: diagColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        image.diagnosis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.error,
                      ),
                      onPressed: () => _showConfirmDeleteDialog(
                        image.code,
                        () {
                          setState(() {
                            final index = _datasets.indexWhere((d) => d.id == dataset.id);
                            if (index != -1) {
                              final updated = _datasets[index].images.where((i) => i.code != image.code).toList();
                              _datasets[index] = DatasetModel(
                                id: _datasets[index].id,
                                name: _datasets[index].name,
                                description: _datasets[index].description,
                                totalImages: updated.length,
                                size: _datasets[index].size,
                                lastUpdated: DateTime.now().toString().split(' ')[0],
                                status: _datasets[index].status,
                                images: updated,
                              );
                              _selectedDataset = _datasets[index];
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEditView() {
    if (_selectedDataset == null) return const SizedBox.shrink();
    final dataset = _selectedDataset!;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: dataset.name);
    final descController = TextEditingController(text: dataset.description);
    String selectedStatus = dataset.status;

    return StatefulBuilder(
      builder: (context, setFormState) {
        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _navigate(DatasetView.detail, dataset),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text("Back to Detail"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.borderLight),
                      foregroundColor: AppTheme.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                "Edit Dataset",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  side: const BorderSide(color: AppTheme.borderLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Dataset Name",
                          labelStyle: const TextStyle(color: AppTheme.subtitleGrey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                        validator: (value) => value?.isEmpty == true ? "Required" : null,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: "Description",
                          alignLabelWithHint: true,
                          labelStyle: const TextStyle(color: AppTheme.subtitleGrey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: "Status",
                          labelStyle: const TextStyle(color: AppTheme.subtitleGrey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                        items: const ["ACTIVE", "ARCHIVED"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) => setFormState(() => selectedStatus = value!),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _navigate(DatasetView.detail, dataset),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.borderLight),
                              foregroundColor: AppTheme.navy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                              ),
                            ),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                final index = _datasets.indexWhere((d) => d.id == dataset.id);
                                if (index != -1) {
                                  setState(() {
                                    _datasets[index] = DatasetModel(
                                      id: dataset.id,
                                      name: nameController.text,
                                      description: descController.text,
                                      totalImages: dataset.totalImages,
                                      size: dataset.size,
                                      lastUpdated: DateTime.now().toString().split(' ')[0],
                                      status: selectedStatus,
                                      images: dataset.images,
                                    );
                                    _selectedDataset = _datasets[index];
                                  });
                                  _navigate(DatasetView.detail, _datasets[index]);
                                }
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                              ),
                            ),
                            child: const Text("Save Changes"),
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
      },
    );
  }

  void _showConfirmDeleteDialog(String itemName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 40, color: AppTheme.error),
              ),
              const SizedBox(height: 24),
              Text(
                "Hapus Item Ini?",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Apakah Anda yakin ingin menghapus $itemName? Tindakan ini tidak dapat dibatalkan.",
                style: TextStyle(
                  color: AppTheme.subtitleGrey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.borderLight),
                        foregroundColor: AppTheme.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        ),
                      ),
                      child: const Text("Tidak"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        onConfirm();
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        ),
                      ),
                      child: const Text("Ya, Hapus"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadImageDialog() {
    if (_selectedDataset == null) return;
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    String selectedDiagnosis = "Positive / TBC";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(child: Text("Upload Image")),
          content: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderLight, width: 2, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 64, color: AppTheme.subtitleGrey),
                        const SizedBox(height: 16),
                        Text(
                          "Click to upload or drag and drop",
                          style: TextStyle(
                            color: AppTheme.subtitleGrey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "SVG, PNG, JPG or DICOM (max. 50MB)",
                          style: TextStyle(
                            color: AppTheme.subtitleGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: selectedDiagnosis,
                    decoration: InputDecoration(
                      labelText: "Diagnosis",
                      labelStyle: const TextStyle(color: AppTheme.subtitleGrey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    items: const ["Positive / TBC", "Negative / Normal"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) => setDialogState(() => selectedDiagnosis = value!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: "Image Code",
                      hintText: "e.g. XRAY-8892",
                      labelStyle: const TextStyle(color: AppTheme.subtitleGrey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    validator: (value) => value?.isEmpty == true ? "Required" : null,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderLight),
                            foregroundColor: AppTheme.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            ),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final newImage = DatasetImage(
                                code: codeController.text,
                                addedDate: DateTime.now().toString().split(' ')[0],
                                diagnosis: selectedDiagnosis,
                              );
                              final index = _datasets.indexWhere((d) => d.id == _selectedDataset!.id);
                              if (index != -1) {
                                setState(() {
                                  _datasets[index] = DatasetModel(
                                    id: _datasets[index].id,
                                    name: _datasets[index].name,
                                    description: _datasets[index].description,
                                    totalImages: _datasets[index].totalImages + 1,
                                    size: _datasets[index].size,
                                    lastUpdated: DateTime.now().toString().split(' ')[0],
                                    status: _datasets[index].status,
                                    images: [..._datasets[index].images, newImage],
                                  );
                                  _selectedDataset = _datasets[index];
                                });
                              }
                              Navigator.of(context).pop();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                            ),
                          ),
                          child: const Text("Upload Image"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
