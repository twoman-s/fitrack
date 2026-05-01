import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch Flutter framework errors and print them so adb logcat shows them
  // in release builds (they're visible under tag "flutter" / "E/flutter").
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());
  };

  // Catch errors outside the Flutter framework (dart:async, isolate, etc.).
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error');
    debugPrint(stack.toString());
    return true;
  };

  // Load environment variables — fail gracefully so release builds don't
  // get stuck if the asset is missing (ApiConfig has a built-in fallback URL).
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env not found or unreadable; ApiConfig.baseUrl fallback will be used.
  }
  
  runApp(
    const ProviderScope(
      child: FitrackApp(),
    ),
  );
}

class FitrackApp extends ConsumerWidget {
  const FitrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Fitrack',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Enforcing dark theme based on UI design
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
