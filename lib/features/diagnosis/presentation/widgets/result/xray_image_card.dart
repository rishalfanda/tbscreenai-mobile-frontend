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

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final segmentation = widget.segmentation;

    if (image?.canPreview != true) {
      return const SizedBox(
        height: 320,
        child: Center(
          child: Text(
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
          onTap: () => openImageViewer(context, image.bytes),
          child: SizedBox(
            height: 320,
            child: Center(
              child: Image.memory(
                image!.bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'Gambar tidak tersedia',
                    style: TextStyle(color: kResultTextLoColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final bytes = switch (_view) {
      1 => segmentation.lungPng,
      2 => segmentation.lesionPng,
      _ => segmentation.xrayPng,
    };

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
                  onTap: () => openImageViewer(context, bytes),
                  child: SizedBox(
                    height: 320,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text(
                            'Gambar tidak tersedia',
                            style: TextStyle(color: kResultTextLoColor),
                          ),
                        ),
                      ),
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
              spacing: 8,
              runSpacing: 6,
              children: segmentation.legend
                  .map(
                    (entry) => LesionLegendChip(
                      entry: entry,
                      lungAreaPx: segmentation.lungAreaPx,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildViewButton(int value, String label, IconData icon) {
    final isSelected = _view == value;
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
              color: isSelected ? AppTheme.primary : kResultBorderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : kResultTextLoColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : kResultTextLoColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the currently-selected X-ray view (Rontgen/Paru/Lesi) full-size,
/// with pinch/drag zoom and pan, over a dark modal overlay.
void openImageViewer(BuildContext context, Uint8List bytes) {
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
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
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
  });

  final LesionLegendEntry entry;
  final int lungAreaPx;

  @override
  Widget build(BuildContext context) {
    final dimmed = entry.pixelCount == 0;
    final proportion = lungAreaPx == 0
        ? 0.0
        : entry.pixelCount / lungAreaPx * 100;
    final color = Color.fromARGB(255, entry.red, entry.green, entry.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dimmed ? kResultSurfaceAltColor : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dimmed ? kResultBorderColor : color.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        '${kLesionNameLabels[entry.name.toLowerCase()] ?? entry.name} · '
        '${proportion.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: dimmed ? kResultTextLoColor : color,
        ),
      ),
    );
  }
}

