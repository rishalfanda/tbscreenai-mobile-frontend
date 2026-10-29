import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';

/// Checks if an active model exists on device and is not yet in standby.
/// If an active model exists, shows a non-dismissible loading dialog while
/// preloading and initiating the model into standby memory.
/// If no model exists or model is already ready, returns immediately without showing dialog.
Future<bool> initiateModelStandbyWithDialog(
  BuildContext context,
  OnnxInferenceEngine engine, {
  ModelStore? modelStore,
  String title = 'Menginisialisasi Model AI',
  String message =
      'Menyiapkan dan memuat model AI ke memori agar proses analisis siap digunakan... Mohon tunggu.',
}) async {
  // 1. If already standby ready, nothing to do
  if (engine.isStandbyReady) return true;

  // 2. Check if an active model bundle exists on device
  final store = modelStore ?? ModelStore();
  final activeDir = await store.activeBundleDir();
  if (activeDir == null) {
    // Model does not exist yet. Skip initiation silently.
    return false;
  }

  // Ensure engine is ready (has opened active bundle store/executor)
  final isReady = await engine.ready;
  if (!isReady || !engine.hasBundle) {
    return false;
  }

  if (engine.isStandbyReady) return true;
  if (!context.mounted) return false;

  final navigator = Navigator.of(context, rootNavigator: true);
  var isDialogVisible = true;

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            side: const BorderSide(color: AppTheme.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      isDialogVisible = false;
    }),
  );

  try {
    return await engine.initiateStandby();
  } finally {
    if (isDialogVisible) {
      isDialogVisible = false;
      if (context.mounted && navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}

