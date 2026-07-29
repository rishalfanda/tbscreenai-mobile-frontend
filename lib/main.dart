import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix: enable resampling to reduce mouse tracker assertion errors
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    GestureBinding.instance.resamplingEnabled = true;
  }

  // Open the local database once and restore any saved session before the
  // first frame, so a returning user is not bounced to the login screen.
  final database = AppDatabase();
  String? accessToken;
  String? refreshToken;
  if (AppConfig.useHttp) {
    final settings = SettingsStore(database);
    accessToken = await settings.readAccessToken();
    refreshToken = await settings.readRefreshToken();
  }

  runApp(TBScreenApp(
    database: database,
    restoredAccessToken: accessToken,
    restoredRefreshToken: refreshToken,
  ));
}
