import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'backup_section.dart';
import 'backup_index.dart';

/// Repository untuk backup/restore dalam format ZIP (Kotatsu-style).
class BackupRepository {
  static const String backupDirName = 'manga_backups';
  static const String backupPrefix = 'manga_backup_';

  /// Buat backup ZIP dengan progress callback.
  Future<String> createBackup({
    required Set<BackupSection> sections,
    Function(double progress, String message)? onProgress,
  }) async {
    onProgress?.call(0.0, 'Memulai backup...');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupDir = await _getBackupDirectory();
    final zipPath = p.join(backupDir.path, '$backupPrefix$timestamp.zip');

    final archive = Archive();
    int currentStep = 0;
    final totalSteps = sections.length + 1; // +1 untuk index

    // 1. Buat index.json
    if (sections.contains(BackupSection.index) || sections.length > 1) {
      onProgress?.call(currentStep / totalSteps, 'Membuat index...');

      final comics = await DatabaseHelper.instance.getAllComics();
      final index = BackupIndex(
        version: 1,
        appName: 'Manga Tracker',
        createdAt: timestamp,
        totalComics: comics.length,
        sections: sections.map((s) => s.fileName).toList(),
      );

      final indexJson = index.toJson();
      archive.addFile(
        ArchiveFile(BackupSection.index.fileName, indexJson.length, indexJson),
      );
      currentStep++;
    }

    // 2. Backup comics.json
    if (sections.contains(BackupSection.comics)) {
      onProgress?.call(currentStep / totalSteps, 'Backup data komik...');

      final jsonString = await DatabaseHelper.instance.exportToJsonString();
      archive.addFile(
        ArchiveFile(
            BackupSection.comics.fileName, jsonString.length, jsonString),
      );
      currentStep++;
    }

    // 3. Backup settings.json
    if (sections.contains(BackupSection.settings)) {
      onProgress?.call(currentStep / totalSteps, 'Backup pengaturan...');

      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'version': 1,
        'autoBackupEnabled': prefs.getBool('auto_backup_enabled') ?? false,
        'backupInterval': prefs.getInt('backup_interval_days') ?? 7,
        'keepBackups': prefs.getInt('keep_backups_count') ?? 5,
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
      };
      final settingsJson = jsonEncode(settings);
      archive.addFile(
        ArchiveFile(
            BackupSection.settings.fileName, settingsJson.length, settingsJson),
      );
      currentStep++;
    }

    // Encode ZIP
    onProgress?.call(0.9, 'Menyimpan file...');
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('Gagal membuat ZIP file');
    }

    final file = File(zipPath);
    await file.writeAsBytes(zipData);

    onProgress?.call(1.0, 'Backup selesai!');
    return zipPath;
  }

  /// Restore dari backup ZIP dengan selective sections.
  Future<int> restoreBackup({
    required String zipPath,
    required Set<BackupSection> sections,
    required bool replaceExisting,
    Function(double progress, String message)? onProgress,
  }) async {
    onProgress?.call(0.0, 'Membaca backup...');

    final file = File(zipPath);
    if (!await file.exists()) {
      throw Exception('File backup tidak ditemukan');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    int totalImported = 0;
    int currentStep = 0;
    final totalSteps = sections.length;

    for (final section in sections) {
      final archiveFile = archive.findFile(section.fileName);
      if (archiveFile == null) continue;

      onProgress?.call(
        currentStep / totalSteps,
        'Restore ${section.displayName}...',
      );

      final content = archiveFile.content as List<int>;
      final jsonString = utf8.decode(content);

      switch (section) {
        case BackupSection.comics:
          final count = await DatabaseHelper.instance.importFromJsonString(
            jsonString,
            replaceExisting: replaceExisting,
          );
          totalImported += count;
          break;

        case BackupSection.settings:
          final settingsMap = jsonDecode(jsonString) as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();

          if (settingsMap['autoBackupEnabled'] != null) {
            await prefs.setBool('auto_backup_enabled',
                settingsMap['autoBackupEnabled'] as bool);
          }
          if (settingsMap['backupInterval'] != null) {
            await prefs.setInt(
                'backup_interval_days', settingsMap['backupInterval'] as int);
          }
          if (settingsMap['keepBackups'] != null) {
            await prefs.setInt(
                'keep_backups_count', settingsMap['keepBackups'] as int);
          }
          break;

        case BackupSection.index:
          // Index tidak perlu di-restore
          break;
      }

      currentStep++;
    }

    onProgress?.call(1.0, 'Restore selesai!');
    return totalImported;
  }

  /// Get list backup files yang ada.
  Future<List<BackupFile>> getBackupFiles() async {
    final backupDir = await _getBackupDirectory();
    if (!await backupDir.exists()) {
      return [];
    }

    final files = await backupDir
        .list()
        .where((e) => e is File && e.path.endsWith('.zip'))
        .cast<File>()
        .toList();

    final backupFiles = <BackupFile>[];
    for (final file in files) {
      final stat = await file.stat();
      final name = p.basename(file.path);

      // Parse timestamp dari nama file
      int? timestamp;
      if (name.startsWith(backupPrefix)) {
        final timestampStr =
            name.substring(backupPrefix.length).replaceAll('.zip', '');
        timestamp = int.tryParse(timestampStr);
      }

      backupFiles.add(BackupFile(
        path: file.path,
        name: name,
        size: stat.size,
        createdAt: timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.fromMillisecondsSinceEpoch(
                stat.modified.millisecondsSinceEpoch),
      ));
    }

    backupFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backupFiles;
  }

  /// Hapus backup file.
  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get backup directory.
  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, backupDirName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Parse backup sections dari ZIP.
  Future<List<BackupSection>> getBackupSections(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) return [];

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final sections = <BackupSection>[];
    for (final file in archive) {
      final section = BackupSection.fromFileName(file.name);
      if (section != null && section != BackupSection.index) {
        sections.add(section);
      }
    }

    return sections;
  }
}

/// Model untuk backup file.
class BackupFile {
  final String path;
  final String name;
  final int size;
  final DateTime createdAt;

  BackupFile({
    required this.path,
    required this.name,
    required this.size,
    required this.createdAt,
  });
}
