import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../backups/backup_repository.dart';
import '../backups/backup_section.dart';
import 'package:path/path.dart' as p;

/// Screen untuk manage backup files (Kotatsu-style).
class BackupManagementScreen extends StatefulWidget {
  static const String routeName = '/backup-management';

  const BackupManagementScreen({super.key});

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  final _backupRepo = BackupRepository();
  List<BackupFile> _backups = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final backups = await _backupRepo.getBackupFiles();
      if (mounted) {
        setState(() {
          _backups = backups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar('Gagal memuat backup: $e');
      }
    }
  }

  Future<void> _createBackup() async {
    final sections = await _showSectionSelector(
      title: 'Pilih Data untuk Backup',
      subtitle: 'Data yang dipilih akan disimpan dalam file ZIP',
    );

    if (sections == null || sections.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressMessage = 'Memulai backup...';
    });

    try {
      final path = await _backupRepo.createBackup(
        sections: sections,
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _progressMessage = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackbar('✓ Backup berhasil: ${p.basename(path)}');
        _loadBackups();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackbar('Gagal backup: $e');
      }
    }
  }

  Future<void> _restoreBackup(BackupFile backup) async {
    // Get sections dari backup
    final availableSections = await _backupRepo.getBackupSections(backup.path);
    if (availableSections.isEmpty) {
      _showSnackbar('Backup tidak memiliki data yang valid');
      return;
    }

    final sections = await _showSectionSelector(
      title: 'Pilih Data untuk Restore',
      subtitle: 'Hanya data yang dipilih yang akan dipulihkan',
      availableSections: availableSections,
    );

    if (sections == null || sections.isEmpty) return;

    // Tanya mode: replace atau merge
    final replaceMode = await _showModeDialog();
    if (replaceMode == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressMessage = 'Memulai restore...';
    });

    try {
      final count = await _backupRepo.restoreBackup(
        zipPath: backup.path,
        sections: sections,
        replaceExisting: replaceMode,
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _progressMessage = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackbar('✓ Berhasil restore $count komik!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackbar('Gagal restore: $e');
      }
    }
  }

  Future<Set<BackupSection>?> _showSectionSelector({
    required String title,
    required String subtitle,
    List<BackupSection>? availableSections,
  }) async {
    final sections = availableSections ?? BackupSection.values;
    final selected = <BackupSection>{BackupSection.comics};

    return await showDialog<Set<BackupSection>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...sections
                  .where((s) => s != BackupSection.metadata)
                  .map((section) => CheckboxListTile(
                        title: Text(section.displayName),
                        value: selected.contains(section),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selected.add(section);
                            } else {
                              selected.remove(section);
                            }
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed:
                  selected.isEmpty ? null : () => Navigator.pop(ctx, selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showModeDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mode Restore'),
        content: const Text(
          'Pilih cara restore data:\n\n'
          '• Gabung: Tambahkan ke data yang ada\n'
          '• Ganti: Hapus data lama dan ganti dengan backup',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Gabung'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ganti Semua'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBackup(BackupFile backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Backup?'),
        content: Text(
          'File backup "${backup.name}" akan dihapus permanen.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _backupRepo.deleteBackup(backup.path);
      _showSnackbar('✓ Backup dihapus');
      _loadBackups();
    } catch (e) {
      _showSnackbar('Gagal hapus backup: $e');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';

    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: AppBar(
        backgroundColor: AppTheme.surface1,
        title: const Text('Backup & Restore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _isProcessing
                ? null
                : () => Navigator.pushNamed(context, '/backup-settings'),
            tooltip: 'Auto Backup Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isProcessing ? null : _loadBackups,
          ),
        ],
      ),
      body: _isProcessing ? _buildProgressOverlay() : _buildContent(),
      floatingActionButton: _isProcessing
          ? null
          : FloatingActionButton.extended(
              onPressed: _createBackup,
              backgroundColor: AppTheme.primaryAccent,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat Backup'),
            ),
    );
  }

  Widget _buildProgressOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: AppTheme.primaryAccent,
            ),
            const SizedBox(height: 16),
            Text(
              _progressMessage,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_progress > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_backups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backup_outlined,
                size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Belum ada backup',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol + untuk membuat backup',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _backups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final backup = _backups[index];
        return _buildBackupCard(backup);
      },
    );
  }

  Widget _buildBackupCard(BackupFile backup) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _restoreBackup(backup),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_zip_rounded,
                    color: AppTheme.primaryAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(backup.createdAt),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatBytes(backup.size),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.textMuted),
                  onPressed: () => _deleteBackup(backup),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
