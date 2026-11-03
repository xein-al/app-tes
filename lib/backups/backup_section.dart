/// Sections yang bisa di-backup/restore secara terpisah.
/// Terinspirasi dari Kotatsu-Redo backup system.
enum BackupSection {
  metadata('index.json', 'Index'),
  comics('comics.json', 'Data Komik'),
  settings('settings.json', 'Pengaturan');

  final String fileName;
  final String displayName;

  const BackupSection(this.fileName, this.displayName);

  static BackupSection? fromFileName(String name) {
    try {
      return BackupSection.values.firstWhere(
        (s) => s.fileName.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
