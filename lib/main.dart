import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'screens/lock_gate.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppState appState;
  try {
    final storage = StorageService();
    await storage.init();
    appState = AppState(storage, NotificationService.instance);
    await appState.load();
  } catch (e) {
    // Never a blank crash: tell the user what happened instead.
    runApp(_StartupError('$e'));
    return;
  }
  runApp(ChangeNotifierProvider.value(value: appState, child: const CaseCraftApp()));
}

ThemeData get _theme {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFC9A66B), brightness: Brightness.light).copyWith(primary: const Color(0xFF102033), secondary: const Color(0xFFC9A66B), surface: Colors.white);
  return ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: const Color(0xFFF6F3ED), fontFamily: 'Inter', pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()}), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))), cardTheme: const CardThemeData(color: Colors.white, elevation: 0), navigationBarTheme: const NavigationBarThemeData(height: 72, backgroundColor: Colors.white, indicatorColor: Color(0x1AC9A66B)));
}

class CaseCraftApp extends StatelessWidget {
  const CaseCraftApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CaseCraft',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
        home: const Shell(),
      );
}

class _StartupError extends StatelessWidget {
  final String message;
  const _StartupError(this.message);
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lock_outline_rounded, size: 40, color: Color(0xFFB65B5B)),
                const SizedBox(height: 16),
                const Text('CaseCraft could not open its secure storage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Text('Your data has not been changed. Restart the phone and open CaseCraft again. If this keeps happening, contact support with the details below.', style: TextStyle(height: 1.4)),
                const SizedBox(height: 16),
                SelectableText(message, style: const TextStyle(fontSize: 12, color: Color(0xFF6A7280))),
              ]),
            ),
          ),
        ),
      );
}
