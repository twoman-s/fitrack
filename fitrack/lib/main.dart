import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables for API URL
  await dotenv.load(fileName: ".env");
  
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
