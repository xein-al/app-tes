import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/library_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/storage_screen.dart';
import 'screens/backup_management_screen.dart';
import 'screens/backup_settings_screen.dart';
// import 'backups/periodic_backup_service.dart'; // Temporary disabled

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WorkManager untuk auto backup
  // TODO: Re-enable when workmanager Kotlin compatibility is fixed
  // await PeriodicBackupService.initialize();

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
        BackupManagementScreen.routeName: (context) =>
            const BackupManagementScreen(),
        BackupSettingsScreen.routeName: (context) =>
            const BackupSettingsScreen(),
      },
    );
  }
}
