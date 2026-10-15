import 'package:flutter/material.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

class DashedUploadPanel extends StatelessWidget {
  const DashedUploadPanel({
    super.key,
    required this.image,
    required this.loading,
    this.loadingMessage = 'Sedang memproses citra rontgen...',
    required this.onUpload,
    required this.onCamera,
    required this.onRemove,
  });

  final XrayImage? image;
  final bool loading;
  final String loadingMessage;
  final VoidCallback onUpload;
  final VoidCallback onCamera;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedBorderPainter(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: diagnosisInput,
          child: loading
              ? _loadingState()
              : (image == null ? _emptyState() : _preview()),
        ),
      ),
    );
  }

  Widget _loadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          key: const Key('upload-normalizing-state'),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                key: Key('upload-loading-indicator'),
                color: diagnosisAccent,
                strokeWidth: 3.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              loadingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: diagnosisText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Menyesuaikan kontras dan histogram warna dengan citra referensi acuan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: diagnosisMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            size: 52,
            color: diagnosisMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unggah Citra Rontgen',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: diagnosisMuted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'PNG/JPEG - Maksimal 25 MB dan 20 juta pixel. Ekspor DICOM dahulu.',
            style: TextStyle(color: Color(0xFF71809A), fontSize: 12),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const Key('upload-xray'),
                onPressed: onUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 19),
                label: const Text('Pilih Gambar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: diagnosisAccent,
                  side: const BorderSide(color: diagnosisAccent),
                ),
              ),
              FilledButton.icon(
                key: const Key('capture-xray'),
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera_rounded, size: 19),
                label: const Text('Gunakan Kamera'),
                style: FilledButton.styleFrom(backgroundColor: diagnosisAction),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Gunakan citra rontgen digital asli jika tersedia. Pengambilan foto '
            'dengan kamera dapat menurunkan kualitas gambar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: diagnosisMuted, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final current = image!;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (current.canPreview)
          Image.memory(
            current.bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _fileFallback(current),
          )
        else
          _fileFallback(current),
        Positioned(
          left: 12,
          right: 58,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${current.filename} · ${_formatBytes(current.sizeBytes)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            tooltip: 'Hapus Rontgen',
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.72),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }

  Widget _fileFallback(XrayImage current) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monitor_heart_outlined,
            size: 64,
            color: diagnosisMuted,
          ),
          const SizedBox(height: 12),
          Text(
            current.filename,
            textAlign: TextAlign.center,
            style: const TextStyle(color: diagnosisText),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 7.0;
    const gap = 5.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final paint = Paint()
      ..color = diagnosisBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
