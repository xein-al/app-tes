import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/library_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/storage_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Make status bar transparent and match theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.backgroundBase,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MangaTrackerApp());
}

class MangaTrackerApp extends StatelessWidget {
  const MangaTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LibraryScreen(),
        DetailScreen.routeName: (context) => const DetailScreen(),
        StatsScreen.routeName: (context) => const StatsScreen(),
        StorageScreen.routeName: (context) => const StorageScreen(),
      },
    );
  }
}
