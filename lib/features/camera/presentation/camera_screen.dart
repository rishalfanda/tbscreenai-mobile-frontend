import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/state/diagnosis_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _captured = false;
  bool _flashOn = false;
  bool _rearCamera = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Text(
                _captured ? 'Captured frame preview' : 'Live camera preview',
                style: const TextStyle(color: Colors.white70, fontSize: 20),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 24,
            child: IconButton.filledTonal(
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white10,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          Center(
            child: SizedBox(
              width: 520,
              height: 520,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white54, width: 2),
                      ),
                    ),
                  ),
                  ...const [
                    Alignment.topLeft,
                    Alignment.topRight,
                    Alignment.bottomLeft,
                    Alignment.bottomRight,
                  ].map(
                    (alignment) => Align(
                      alignment: alignment,
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                                  ? Colors.transparent
                                  : AppTheme.primary,
                              width: 4,
                            ),
                            bottom: BorderSide(
                              color: alignment == Alignment.topLeft || alignment == Alignment.topRight
                                  ? Colors.transparent
                                  : AppTheme.primary,
                              width: 4,
                            ),
                            left: BorderSide(
                              color: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                                  ? Colors.transparent
                                  : AppTheme.primary,
                              width: 4,
                            ),
                            right: BorderSide(
                              color: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                                  ? Colors.transparent
                                  : AppTheme.primary,
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlButton(
                  label: _flashOn ? 'Flash On' : 'Flash Off',
                  icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  onPressed: () => setState(() => _flashOn = !_flashOn),
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: () => setState(() => _captured = true),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: AppTheme.primary, width: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                _ControlButton(
                  label: _rearCamera ? 'Rear' : 'Front',
                  icon: Icons.cameraswitch_rounded,
                  onPressed: () => setState(() => _rearCamera = !_rearCamera),
                ),
              ],
            ),
          ),
          if (_captured)
            Positioned(
              left: 0,
              right: 0,
              bottom: 136,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _captured = false),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Retake'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () {
                      context.read<DiagnosisProvider>().attachMockImage('captured_xray.png');
                      context.pop();
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(160, 56),
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
