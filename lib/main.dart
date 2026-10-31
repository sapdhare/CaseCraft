import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  final appState = AppState(storage, NotificationService.instance);
  await appState.load();
  runApp(ChangeNotifierProvider.value(value: appState, child: const CaseCraftApp()));
}

class CaseCraftApp extends StatelessWidget {
  const CaseCraftApp({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFC9A66B), brightness: Brightness.light).copyWith(primary: const Color(0xFF102033), secondary: const Color(0xFFC9A66B), surface: Colors.white);
    return MaterialApp(
      title: 'CaseCraft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: const Color(0xFFF6F3ED), fontFamily: 'Inter', pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()}), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))), cardTheme: const CardThemeData(color: Colors.white, elevation: 0), navigationBarTheme: const NavigationBarThemeData(height: 72, backgroundColor: Colors.white, indicatorColor: Color(0x1AC9A66B))),
      home: const Shell(),
    );
  }
}
