import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix: enable resampling to reduce mouse tracker assertion errors
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    GestureBinding.instance.resamplingEnabled = true;
  }

  runApp(const TBScreenApp());
}
