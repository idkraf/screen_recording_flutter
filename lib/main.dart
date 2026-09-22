import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'features/recorder/providers/recorder_provider.dart';
import 'features/recorder/views/home_recorder_screen.dart';
import 'features/recordings_list/providers/recordings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RecorderProvider()),
        ChangeNotifierProvider(create: (_) => RecordingsProvider()),
      ],
      child: MaterialApp(
        title: 'Screen Recorder Pro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeRecorderScreen(),
      ),
    );
  }
}
