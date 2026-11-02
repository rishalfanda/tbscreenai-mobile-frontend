import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  AppConfig.validate();

  // Fix: enable resampling to reduce mouse tracker assertion errors
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) {
    GestureBinding.instance.resamplingEnabled = true;
  }

  final database = AppDatabase();
  final secureStorage = PlatformSecureTokenStorage();

  runApp(TBScreenApp(database: database, secureTokenStorage: secureStorage));
}
