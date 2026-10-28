import 'package:myapp/core/localization/app_text.dart';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:go_router/go_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/camera/application/xray_capture_processor.dart';
import 'package:myapp/features/diagnosis/application/prepare_inference_image.dart';
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
  bool _confirming = false;
  bool _flashOn = false;
  bool _isInitializing = false;
  DeviceOrientation _lastKnownLandscape = DeviceOrientation.landscapeLeft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;

    // App state changed before controller finished initializing (e.g. when the
    // Android runtime permission dialog pauses the activity to 'inactive').
    // Disposing the controller here tears down the native FlutterSurfaceProducer
    // while CameraX is waiting for the permission result, triggering an IllegalStateException.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed && _capturedBytes == null) {
      _initializeCamera(selected: cameraController.description);
    }
  }

  Future<void> _initializeCamera({CameraDescription? selected}) async {
    if (_isInitializing) return;
    _isInitializing = true;
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
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      await controller.setFlashMode(FlashMode.off);

      if (controller.value.deviceOrientation ==
              DeviceOrientation.landscapeLeft ||
          controller.value.deviceOrientation ==
              DeviceOrientation.landscapeRight) {
        _lastKnownLandscape = controller.value.deviceOrientation;
      }
      try {
        await controller.lockCaptureOrientation(_lastKnownLandscape);
      } catch (_) {
        // Platform might not support orientation locking.
      }
      if (!mounted || _controller != controller) {
        return;
      }
      controller.addListener(_onCameraValueChanged);
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
    } finally {
      _isInitializing = false;
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
      final rawBytes = await capture.readAsBytes();
      final bytes = processCapturedXray(rawBytes);
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

  Future<void> _confirm() async {
    final bytes = _capturedBytes;
    if (bytes == null || _confirming) return;
    setState(() => _confirming = true);
    try {
      final image = XrayImage.fromBytes(
        bytes: bytes,
        filename: _capturedName,
        source: XrayImageSource.camera,
      );
      final normalized = await prepareInferenceImage(image);
      if (!mounted) return;
      context.read<DiagnosisProvider>().attachImage(normalized);
      context.pop();
    } on XrayImageValidationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _retake() {
    setState(() {
      _capturedBytes = null;
      _error = null;
    });
  }

  void _onCameraValueChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final orientation = controller.value.deviceOrientation;
    if (orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight) {
      if (controller.value.lockedCaptureOrientation != orientation) {
        _lastKnownLandscape = orientation;
        controller.lockCaptureOrientation(orientation).catchError((_) {});
      }
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onCameraValueChanged);
      await controller.dispose();
    }
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
          label: const AppText('Try camera again'),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _coverCameraPreview(_controller!),
        IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final box = maximalCenteredBox(
                constraints.maxWidth * 0.92,
                constraints.maxHeight * 0.92,
                kXrayCropAspectW,
                kXrayCropAspectH,
              );
              return Center(
                child: SizedBox(
                  width: box.width,
                  height: box.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Keys the preview's rotation off the camera's live `deviceOrientation`
  /// (true sensor/accelerometer data) rather than `MediaQuery`, which always
  /// reports landscape here since the activity is orientation-locked and
  /// never actually rotates — that mismatch is why the preview used to look
  /// stretched whenever the tablet was physically held in portrait.
  Widget _coverCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final quarterTurns = _previewQuarterTurns(
          controller.description,
          _effectiveOrientation(
            value.deviceOrientation,
            lockedOrientation: value.lockedCaptureOrientation,
          ),
        );
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: RotatedBox(
              quarterTurns: quarterTurns,
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  /// When the tablet is lying flat on a surface ("posisi tertidur"), the
  /// accelerometer has no horizontal tilt vector, causing the camera plugin's
  /// deviceOrientation to default to portraitUp. In our landscape-locked app,
  /// treating this as portrait erroneously triggers a 90° rotation compensation,
  /// flipping the preview's aspect ratio and causing FittedBox to zoom and
  /// mis-scale the camera feed.
  ///
  /// This helper preserves the active landscape orientation when the device is
  /// flat or vertical-tilted, ensuring the preview renders cleanly without distortion.
  DeviceOrientation _effectiveOrientation(
    DeviceOrientation raw, {
    DeviceOrientation? lockedOrientation,
  }) {
    final effective = effectiveCameraOrientation(
      raw,
      lockedOrientation: lockedOrientation,
      fallbackLandscape: _lastKnownLandscape,
    );
    if (raw == DeviceOrientation.landscapeLeft ||
        raw == DeviceOrientation.landscapeRight) {
      _lastKnownLandscape = raw;
    }
    return effective;
  }

  int _previewQuarterTurns(
    CameraDescription description,
    DeviceOrientation orientation,
  ) {
    return previewQuarterTurns(description, orientation);
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
          onPressed: _confirming ? null : _retake,
          icon: const Icon(Icons.replay_rounded),
          label: const AppText('Retake'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            backgroundColor: Colors.black45,
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _confirming ? null : _confirm,
          icon: _confirming
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: AppText(_confirming ? 'Memproses...' : 'Use this image'),
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
        child: AppText(
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

/// Resolves the effective orientation for the camera preview.
/// When the device is flat on a surface ("posisi tertidur"), the accelerometer
/// reports no horizontal tilt, so Flutter defaults raw orientation to portraitUp.
/// In this landscape-locked app, falling back to the active landscape orientation
/// prevents an unintended 90° rotation that swaps preview aspect ratio.
DeviceOrientation effectiveCameraOrientation(
  DeviceOrientation raw, {
  DeviceOrientation? lockedOrientation,
  DeviceOrientation fallbackLandscape = DeviceOrientation.landscapeLeft,
}) {
  if (lockedOrientation != null) {
    return lockedOrientation;
  }
  if (raw == DeviceOrientation.landscapeLeft ||
      raw == DeviceOrientation.landscapeRight) {
    return raw;
  }
  return fallbackLandscape;
}

/// Standard sensor-orientation compensation formula (the one Google
/// documents for ML Kit camera integration): how many quarter-turns the
/// raw camera buffer needs to appear upright for the device's current
/// physical orientation, independent of the app's own (locked) UI
/// orientation.
int previewQuarterTurns(
  CameraDescription description,
  DeviceOrientation orientation,
) {
  const degreesByOrientation = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  final deviceDegrees = degreesByOrientation[orientation] ?? 0;
  final compensation = description.lensDirection == CameraLensDirection.front
      ? (description.sensorOrientation + deviceDegrees) % 360
      : (description.sensorOrientation - deviceDegrees + 360) % 360;
  return compensation ~/ 90;
}
