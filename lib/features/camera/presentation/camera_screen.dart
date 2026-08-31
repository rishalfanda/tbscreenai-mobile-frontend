import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:provider/provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  Uint8List? _capturedBytes;
  String _capturedName = 'captured_xray.jpg';
  String? _error;
  bool _loading = true;
  bool _takingPicture = false;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed && _capturedBytes == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera({CameraDescription? selected}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      _cameras = _cameras.isEmpty ? await availableCameras() : _cameras;
      if (_cameras.isEmpty) {
        throw CameraException('noCamera', 'No camera is available.');
      }

      final description = selected ?? _preferredCamera(_cameras);
      await _disposeController();
      final controller = CameraController(
        description,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _flashOn = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cameraMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The camera could not be started. Try again or upload a file.';
      });
    }
  }

  CameraDescription _preferredCamera(List<CameraDescription> cameras) {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _takingPicture) {
      return;
    }

    setState(() => _takingPicture = true);
    try {
      final capture = await controller.takePicture();
      final bytes = await capture.readAsBytes();
      XrayImage.fromBytes(
        bytes: bytes,
        filename: capture.name,
        source: XrayImageSource.camera,
      );
      if (!mounted) return;
      setState(() {
        _capturedBytes = bytes;
        _capturedName = capture.name;
        _error = null;
      });
    } on XrayImageValidationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _error = _cameraMessage(error));
    } finally {
      if (mounted) setState(() => _takingPicture = false);
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final next = !_flashOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashOn = next);
    } on CameraException {
      if (mounted) {
        setState(() => _error = 'Flash is not available on this camera.');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final current = _controller?.description;
    final index = _cameras.indexWhere((camera) => camera == current);
    await _initializeCamera(selected: _cameras[(index + 1) % _cameras.length]);
  }

  void _confirm() {
    final bytes = _capturedBytes;
    if (bytes == null) return;
    try {
      final image = XrayImage.fromBytes(
        bytes: bytes,
        filename: _capturedName,
        source: XrayImageSource.camera,
      );
      context.read<DiagnosisProvider>().attachImage(image);
      context.pop();
    } on XrayImageValidationException catch (error) {
      setState(() => _error = error.message);
    }
  }

  void _retake() {
    setState(() {
      _capturedBytes = null;
      _error = null;
    });
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080E1B),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _preview()),
            Positioned(
              top: 20,
              left: 20,
              child: _roundButton(
                tooltip: 'Close camera',
                icon: Icons.close_rounded,
                onPressed: () => context.pop(),
              ),
            ),
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: const IgnorePointer(
                child: Text(
                  'Align the complete chest X-ray inside the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
            ),
            if (_error != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 132,
                child: _ErrorBanner(message: _error!),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: _capturedBytes == null
                  ? _captureControls()
                  : _confirmationControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (_capturedBytes != null) {
      return ColoredBox(
        color: Colors.black,
        child: Image.memory(_capturedBytes!, fit: BoxFit.contain),
      );
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    if (_error != null || _controller == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _initializeCamera,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try camera again'),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _coverCameraPreview(_controller!),
        IgnorePointer(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.64,
              heightFactor: 0.72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _coverCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final width = landscape ? previewSize.height : previewSize.width;
    final height = landscape ? previewSize.width : previewSize.height;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: width,
          height: height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _captureControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundButton(
          tooltip: _flashOn ? 'Turn flash off' : 'Turn flash on',
          icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          onPressed: _toggleFlash,
        ),
        const SizedBox(width: 36),
        Semantics(
          button: true,
          label: 'Capture X-ray image',
          child: InkResponse(
            onTap: _takingPicture ? null : _takePicture,
            radius: 48,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppTheme.primary, width: 7),
              ),
              child: _takingPicture
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 36),
        _roundButton(
          tooltip: 'Switch camera',
          icon: Icons.cameraswitch_rounded,
          onPressed: _cameras.length > 1 ? _switchCamera : null,
        ),
      ],
    );
  }

  Widget _confirmationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _retake,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Retake'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            backgroundColor: Colors.black45,
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Use this image'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
        ),
      ],
    );
  }

  Widget _roundButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(52, 52),
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white30,
      ),
      icon: Icon(icon),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _cameraMessage(CameraException error) {
  return switch (error.code) {
    'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
      'Camera access is denied. Enable it in device Settings, then try again.',
    'CameraAccessRestricted' =>
      'Camera access is restricted on this device. Upload an X-ray file instead.',
    _ =>
      error.description ??
          'The camera could not be started. Try again or upload a file.',
  };
}
