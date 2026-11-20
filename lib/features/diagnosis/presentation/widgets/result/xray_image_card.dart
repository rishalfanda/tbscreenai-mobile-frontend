import 'package:myapp/core/localization/app_text.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/segmentation_overlays.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'result_theme.dart';

/// X-ray preview with an optional lung/lesion segmentation toggle. Falls
/// back to a plain image (today's behavior) when no segmentation was
/// produced — mock/HTTP outcomes never carry pixel-level mask data.
class XrayImageCard extends StatefulWidget {
  const XrayImageCard({
    super.key,
    required this.image,
    required this.segmentation,
  });

  final XrayImage? image;
  final SegmentationOverlays? segmentation;

  @override
  State<XrayImageCard> createState() => _XrayImageCardState();
}

class _XrayImageCardState extends State<XrayImageCard> {
  int _view = 0; // 0 = X-ray, 1 = Lung, 2 = Lesion
  late Set<String> _selectedLesions = _allDetectedLesions(widget.segmentation);

  @override
  void didUpdateWidget(covariant XrayImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.segmentation, widget.segmentation)) {
      _selectedLesions = _allDetectedLesions(widget.segmentation);
    }
  }

  Set<String> _allDetectedLesions(SegmentationOverlays? segmentation) {
    if (segmentation == null) return <String>{};
    return {
      for (final entry in segmentation.legend)
        if (entry.pixelCount > 0) entry.name.toLowerCase(),
    };
  }

  void _toggleLesion(String key) {
    setState(() {
      if (_selectedLesions.contains(key)) {
        _selectedLesions.remove(key);
      } else {
        _selectedLesions.add(key);
      }
    });
  }

  ({Uint8List baseBytes, List<Uint8List> overlayPngs}) _resolveVisuals(
    SegmentationOverlays segmentation,
    Set<String> detected,
  ) {
    if (_view == 0) {
      return (baseBytes: segmentation.xrayPng, overlayPngs: const []);
    }
    if (_view == 1) {
      return (baseBytes: segmentation.lungPng, overlayPngs: const []);
    }
    final allSelected =
        detected.isNotEmpty &&
        _selectedLesions.length == detected.length &&
        detected.every(_selectedLesions.contains);
    if (detected.isEmpty || allSelected) {
      return (baseBytes: segmentation.lesionPng, overlayPngs: const []);
    }
    if (segmentation.lesionLayerPngs.isEmpty) {
      return (baseBytes: segmentation.lesionPng, overlayPngs: const []);
    }
    if (_selectedLesions.isEmpty) {
      return (baseBytes: segmentation.xrayPng, overlayPngs: const []);
    }
    final overlays = <Uint8List>[
      for (final entry in segmentation.legend)
        if (_selectedLesions.contains(entry.name.toLowerCase()))
          ?segmentation.layerFor(entry.name),
    ];
    return (baseBytes: segmentation.xrayPng, overlayPngs: overlays);
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final segmentation = widget.segmentation;

    if (image?.canPreview != true) {
      return const SizedBox(
        height: 320,
        child: Center(
          child: AppText(
            'Pratinjau gambar tidak tersedia',
            style: TextStyle(color: kResultTextLoColor),
          ),
        ),
      );
    }

    if (segmentation == null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const Key('xray-image-viewer-trigger'),
          behavior: HitTestBehavior.opaque,
          onTap: () => openImageViewer(context, image.bytes),
          child: SizedBox(
            height: 320,
            width: double.infinity,
            child: _LayeredSegmentationImage(baseBytes: image!.bytes),
          ),
        ),
      );
    }

    final detected = _allDetectedLesions(segmentation);
    final visuals = _resolveVisuals(segmentation, detected);
    final canFilterLesions =
        _view == 2 &&
        detected.isNotEmpty &&
        segmentation.lesionLayerPngs.isNotEmpty;
    final allSelected =
        detected.isNotEmpty &&
        _selectedLesions.length == detected.length &&
        detected.every(_selectedLesions.contains);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Vertical view mode buttons in a column
            IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildViewButton(0, 'Rontgen', Icons.image_outlined),
                  const SizedBox(height: 8),
                  _buildViewButton(1, 'Paru', Icons.air_outlined),
                  const SizedBox(height: 8),
                  _buildViewButton(2, 'Lesi', Icons.bubble_chart_outlined),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Right: Enlarged X-ray image preview
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: const Key('xray-image-viewer-trigger'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openImageViewer(
                    context,
                    visuals.baseBytes,
                    overlayPngs: visuals.overlayPngs,
                  ),
                  child: SizedBox(
                    height: 320,
                    width: double.infinity,
                    child: _LayeredSegmentationImage(
                      baseBytes: visuals.baseBytes,
                      overlayPngs: visuals.overlayPngs,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (segmentation.legend.isNotEmpty) ...[
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (canFilterLesions)
                  _buildAllLesionsButton(
                    selected: allSelected,
                    onTap: () => setState(() => _selectedLesions = detected),
                  ),
                for (final entry in segmentation.legend)
                  () {
                    final lesionKey = entry.name.toLowerCase();
                    final interactive =
                        canFilterLesions &&
                        entry.pixelCount > 0 &&
                        segmentation.layerFor(entry.name) != null;
                    final selected =
                        !canFilterLesions ||
                        _selectedLesions.contains(lesionKey);
                    return LesionLegendChip(
                      key: interactive ? Key('lesion-filter-$lesionKey') : null,
                      entry: entry,
                      lungAreaPx: segmentation.lungAreaPx,
                      interactive: interactive,
                      selected: selected,
                      onTap: interactive ? () => _toggleLesion(lesionKey) : null,
                    );
                  }(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAllLesionsButton({
    required bool selected,
    required VoidCallback onTap,
  }) {
    final fg = selected ? Colors.white : kResultTextHiColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('lesion-filter-all'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : kResultSurfaceAltColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.primary : kResultBorderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_outlined, size: 13, color: fg),
              const SizedBox(width: 5),
              AppText(
                'Semua',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewButton(int value, String label, IconData icon) {
    final isSelected = _view == value;
    final unselectedFg = kResultTextHiColor.withValues(alpha: 0.85);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _view = value),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : kResultSurfaceAltColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primary : const Color(0x33FFFFFF),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : unselectedFg,
              ),
              const SizedBox(width: 6),
              AppText(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : unselectedFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayeredSegmentationImage extends StatelessWidget {
  const _LayeredSegmentationImage({
    required this.baseBytes,
    this.overlayPngs = const [],
  });

  final Uint8List baseBytes;
  final List<Uint8List> overlayPngs;

  @override
  Widget build(BuildContext context) {
    final base = Image.memory(
      baseBytes,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const Center(
        child: AppText(
          'Gambar tidak tersedia',
          style: TextStyle(color: kResultTextLoColor),
        ),
      ),
    );
    if (overlayPngs.isEmpty) return Center(child: base);
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        for (final layer in overlayPngs)
          Image.memory(
            layer,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
      ],
    );
  }
}

/// Opens the currently-selected X-ray view (Rontgen/Paru/Lesi) full-size,
/// with pinch/drag zoom and pan, over a dark modal overlay.
void openImageViewer(
  BuildContext context,
  Uint8List bytes, {
  List<Uint8List> overlayPngs = const [],
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      key: const Key('xray-image-viewer-dialog'),
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: SizedBox.expand(
                child: _LayeredSegmentationImage(
                  baseBytes: bytes,
                  overlayPngs: overlayPngs,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              key: const Key('xray-image-viewer-close-button'),
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

class LesionLegendChip extends StatelessWidget {
  const LesionLegendChip({
    super.key,
    required this.entry,
    required this.lungAreaPx,
    this.interactive = false,
    this.selected = true,
    this.onTap,
  });

  final LesionLegendEntry entry;
  final int lungAreaPx;
  final bool interactive;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = entry.pixelCount == 0 || (interactive && !selected);
    final proportion = lungAreaPx == 0
        ? 0.0
        : entry.pixelCount / lungAreaPx * 100;
    final color = Color.fromARGB(255, entry.red, entry.green, entry.blue);
    final fg = muted ? kResultTextLoColor : color;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: muted ? kResultSurfaceAltColor : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: muted
              ? kResultBorderColor
              : color.withValues(alpha: interactive ? 0.70 : 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (interactive) ...[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 13,
              color: fg,
            ),
            const SizedBox(width: 5),
          ],
          AppText(
            '${kLesionNameLabels[entry.name.toLowerCase()] ?? entry.name} · '
            '${proportion.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
    if (!interactive) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: pill,
      ),
    );
  }
}
