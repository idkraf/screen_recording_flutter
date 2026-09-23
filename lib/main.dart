import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/services/analytics_service.dart';
import 'core/services/crashlytics_service.dart';
import 'features/recorder/providers/recorder_provider.dart';
import 'features/recorder/views/home_recorder_screen.dart';
import 'features/recordings_list/providers/recordings_provider.dart';
import 'core/providers/drive_sync_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase menggunakan DefaultFirebaseOptions dari FlutterFire CLI
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully with DefaultFirebaseOptions.');

    // Inisialisasi Crashlytics error handlers setelah Firebase aktif
    await CrashlyticsService.instance.initializeErrorHandlers();
  } catch (e) {
    debugPrint('Firebase initialization warning (offline fallback mode): $e');
  }

  // Mengunci orientasi aplikasi secara potret untuk perekaman layar yang konsisten
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ScreenRecorderApp());
}

class ScreenRecorderApp extends StatelessWidget {
  const ScreenRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final observer = AnalyticsService.instance.observer;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RecorderProvider()),
        ChangeNotifierProvider(create: (_) => RecordingsProvider()),
        ChangeNotifierProvider(create: (_) => DriveSyncProvider()),
      ],
      child: MaterialApp(
        title: 'REKAM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        navigatorObservers: observer != null ? [observer] : const [],
        home: const HomeRecorderScreen(),
      ),
    );
  }
}

