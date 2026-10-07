import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  AppConfig.validate();

  // Fix: enable resampling to reduce mouse tracker assertion errors
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    GestureBinding.instance.resamplingEnabled = true;
  }

  // Offline session restore is fail-closed until product approves a local
  // PIN/biometric policy. Secure tokens from an interrupted prior process are
  // removed; owner-scoped cache remains inaccessible behind online login.
  final database = AppDatabase();
  final secureStorage = PlatformSecureTokenStorage();
  if (AppConfig.useHttp) {
    final settings = SettingsStore(database);
    await TokenStore(secureStorage: secureStorage, settings: settings).clear();
  }

  runApp(TBScreenApp(database: database, secureTokenStorage: secureStorage));
}
