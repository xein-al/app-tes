import 'package:workmanager/workmanager.dart';
import 'backup_repository.dart';
import 'backup_section.dart';

/// Service untuk auto periodic backup menggunakan WorkManager.
class PeriodicBackupService {
  static const String taskName = 'periodicBackup';
  static const String uniqueName = 'manga_periodic_backup';

  /// Initialize WorkManager.
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// Schedule periodic backup.
  /// [intervalDays] - Interval dalam hari (minimal 1).
  static Future<void> scheduleBackup(int intervalDays) async {
    if (intervalDays < 1) intervalDays = 1;

    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: Duration(days: intervalDays),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  /// Cancel periodic backup.
  static Future<void> cancelBackup() async {
    await Workmanager().cancelByUniqueName(uniqueName);
  }

  /// Check if periodic backup is scheduled.
  static Future<bool> isScheduled() async {
    // WorkManager tidak punya API untuk check scheduled tasks
    // Kita simpan status di SharedPreferences (akan diimplementasi di settings)
    return false;
  }
}

/// Callback dispatcher untuk WorkManager.
/// Dipanggil di background isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == PeriodicBackupService.taskName) {
      try {
        // Jalankan backup di background
        final repo = BackupRepository();
        await repo.createBackup(
          sections: {
            BackupSection.index,
            BackupSection.comics,
          },
          onProgress: null, // No progress callback di background
        );

        // Optional: cleanup old backups (keep last 5)
        await _cleanupOldBackups(repo);

        return true;
      } catch (e) {
        // Log error tapi return true supaya tidak retry terus
        return false;
      }
    }
    return false;
  });
}

/// Cleanup old backups, keep only last N files.
Future<void> _cleanupOldBackups(BackupRepository repo, {int keep = 5}) async {
  try {
    final backups = await repo.getBackupFiles();
    if (backups.length <= keep) return;

    // Sort by date descending
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Delete old ones
    for (int i = keep; i < backups.length; i++) {
      await repo.deleteBackup(backups[i].path);
    }
  } catch (_) {
    // Ignore cleanup errors
  }
}
