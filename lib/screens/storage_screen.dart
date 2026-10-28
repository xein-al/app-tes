import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../theme.dart';
import '../db/database_helper.dart';

class StorageScreen extends StatefulWidget {
  static const String routeName = '/storage';

  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isCleaning = false;

  int _databaseBytes = 0;
  int _cacheBytes = 0;
  int _thumbnailBytes = 0;
  int _availableBytes = 0;
  String _dbPath = '';

  int _totalComics = 0;
  double _totalChapters = 0.0;

  late AnimationController _barAnimController;
  late Animation<double> _barAnimation;

  @override
  void initState() {
    super.initState();
    _barAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnimation = CurvedAnimation(
      parent: _barAnimController,
      curve: Curves.easeOutCubic,
    );
    _loadStorageData();
  }

  @override
  void dispose() {
    _barAnimController.dispose();
    super.dispose();
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int totalSize = 0;
    if (await dir.exists()) {
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      } catch (_) {}
    }
    return totalSize;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<int> _getDatabaseSize(String dbPath) async {
    int size = 0;
    try {
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('$dbPath$suffix');
        if (await f.exists()) size += await f.length();
      }
    } catch (_) {}
    return size;
  }

  Future<int> _getThumbnailCacheSize(Directory tempDir) async {
    int total = 0;
    if (!await tempDir.exists()) return 0;
    try {
      await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (path.contains('thumb') ||
              path.contains('image') ||
              path.endsWith('.jpg') ||
              path.endsWith('.jpeg') ||
              path.endsWith('.png') ||
              path.endsWith('.webp')) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  Future<int> _getAvailableDiskSpace(String dirPath) async {
    try {
      if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('df', ['-k', dirPath]);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).trim().split('\n');
          if (lines.length > 1) {
            final parts = lines.last.split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final availK = int.tryParse(parts[3]);
              if (availK != null && availK > 0) return availK * 1024;
            }
          }
        }
      }
    } catch (_) {}
    return 16 * 1024 * 1024 * 1024; // 16 GB fallback
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheBytes = await _getDirectorySize(tempDir);
      final thumbBytes = await _getThumbnailCacheSize(tempDir);

      final dbDir = await getDatabasesPath();
      final dbPath = p.join(dbDir, 'comics_tracker.db');
      final dbBytes = await _getDatabaseSize(dbPath);
      final availableBytes = await _getAvailableDiskSpace(tempDir.path);

      final stats = await DatabaseHelper.instance.getStats();
      final counts = await DatabaseHelper.instance.getStatusCounts();

      if (!mounted) return;
      setState(() {
        _cacheBytes = cacheBytes;
        _thumbnailBytes = thumbBytes;
        _databaseBytes = dbBytes;
        _availableBytes = availableBytes;
        _dbPath = dbPath;
        _totalComics = counts['all'] ?? 0;
        _totalChapters = (stats['totalChaptersRead'] as num?)?.toDouble() ?? 0.0;
        _isLoading = false;
      });
      _barAnimController.forward(from: 0.0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('Gagal membaca data penyimpanan: $e', isError: true);
    }
  }

  Future<void> _clearAppCache() async {
    setState(() => _isCleaning = true);
    int freedBytes = 0;
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(recursive: false, followLinks: false)) {
          try {
            if (entity is File) {
              freedBytes += await entity.length();
              await entity.delete();
            } else if (entity is Directory) {
              freedBytes += await _getDirectorySize(entity);
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }
      await _loadStorageData();
      if (!mounted) return;
      _showSnackbar('Cache dibersihkan (${_formatBytes(freedBytes)} dibebaskan)');
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Gagal membersihkan cache: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _clearThumbnailCache() async {
    setState(() => _isCleaning = true);
    int freedBytes = 0;
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final path = entity.path.toLowerCase();
            if (path.contains('thumb') || path.contains('image') ||
                path.endsWith('.jpg') || path.endsWith('.jpeg') ||
                path.endsWith('.png') || path.endsWith('.webp')) {
              try {
                freedBytes += await entity.length();
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
      await _loadStorageData();
      if (!mounted) return;
      _showSnackbar('Thumbnail dibersihkan (${_formatBytes(freedBytes)} dibebaskan)');
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Gagal membersihkan thumbnail: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _clearAllComicsData() async {
    setState(() => _isCleaning = true);
    try {
      await DatabaseHelper.instance.clearAllData();
      await _loadStorageData();
      if (!mounted) return;
      _showSnackbar('Seluruh data komik berhasil dihapus dari database');
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Gagal menghapus data komik: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? AppTheme.primaryAccent : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppTheme.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? AppTheme.primaryAccent : AppTheme.border,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showClearCacheDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(children: [
          Icon(Icons.cleaning_services_rounded, color: AppTheme.planToRead, size: 22),
          SizedBox(width: 10),
          Text('Hapus Cache Aplikasi?'),
        ]),
        content: Text(
          'File sementara dan cache (${_formatBytes(_cacheBytes)}) akan dibersihkan.\nData komik tidak terpengaruh.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.planToRead,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Cache', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _clearAppCache();
  }

  Future<void> _showClearThumbnailDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(children: [
          Icon(Icons.photo_library_outlined, color: AppTheme.reading, size: 22),
          SizedBox(width: 10),
          Text('Hapus Thumbnail Cache?'),
        ]),
        content: Text(
          'Cache cover komik (${_formatBytes(_thumbnailBytes)}) dihapus.\nGambar akan diunduh ulang saat dibuka.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.reading,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Thumbnail', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _clearThumbnailCache();
  }

  Future<void> _showClearAllDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.primaryAccent, width: 1.5),
        ),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.primaryAccent, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hapus Seluruh Data?',
              style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.3)),
              ),
              child: const Text(
                'PERINGATAN: Tindakan ini permanen!',
                style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tindakan ini akan menghapus SEMUA $_totalComics judul komik, riwayat chapter, dan status bacaan.\n\nTidak dapat dibatalkan!',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Semua', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _clearAllComicsData();
  }

  void _copyDbPath() {
    Clipboard.setData(ClipboardData(text: _dbPath));
    _showSnackbar('Path database disalin ke clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: AppBar(
        title: const Text('Penyimpanan'),
        backgroundColor: AppTheme.backgroundBase,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'Segarkan',
            onPressed: _isLoading || _isCleaning ? null : _loadStorageData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : RefreshIndicator(
              color: AppTheme.primaryAccent,
              backgroundColor: AppTheme.surface1,
              onRefresh: _loadStorageData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildVisualStorageSection(),
                  const SizedBox(height: 20),
                  _buildDatabaseStatsSection(),
                  const SizedBox(height: 20),
                  _buildActionsSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildVisualStorageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, color: AppTheme.primaryAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Alokasi Penyimpanan',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'App: ${_formatBytes(_databaseBytes + _cacheBytes)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated segmented bar (like Kotatsu-Redo)
          AnimatedBuilder(
            animation: _barAnimation,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final anim = _barAnimation.value;
                  final totalBytes = _databaseBytes + _cacheBytes + _availableBytes;
                  final safeTotal = totalBytes > 0 ? totalBytes : 1;

                  double dbW = (_databaseBytes / safeTotal) * totalWidth;
                  double cacheW = (_cacheBytes / safeTotal) * totalWidth;
                  const minSeg = 8.0;
                  if (_databaseBytes > 0 && dbW < minSeg) dbW = minSeg;
                  if (_cacheBytes > 0 && cacheW < minSeg) cacheW = minSeg;
                  double availW = math.max(0.0, totalWidth - dbW - cacheW);

                  return Container(
                    height: 22,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        children: [
                          if (_databaseBytes > 0)
                            Container(width: dbW * anim, color: AppTheme.reading),
                          if (_cacheBytes > 0)
                            Container(width: cacheW * anim, color: AppTheme.planToRead),
                          if (availW > 0)
                            Expanded(child: Container(color: AppTheme.surface2)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _legendDot(AppTheme.reading, 'Database', _formatBytes(_databaseBytes)),
              _legendDot(AppTheme.planToRead, 'Cache', _formatBytes(_cacheBytes)),
              _legendDot(const Color(0xFF2D333B), 'Tersedia', _formatBytes(_availableBytes)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, String size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text(size, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildDatabaseStatsSection() {
    final chapterText = _totalChapters % 1 == 0
        ? _totalChapters.toInt().toString()
        : _totalChapters.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statistik Database',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _statItem(Icons.menu_book_rounded, AppTheme.reading, '$_totalComics', 'Judul Komik')),
              Container(width: 1, height: 44, color: AppTheme.border),
              Expanded(child: _statItem(Icons.auto_stories_rounded, AppTheme.planToRead, chapterText, 'Total Chapter')),
              Container(width: 1, height: 44, color: AppTheme.border),
              Expanded(child: _statItem(Icons.storage_rounded, AppTheme.completed, _formatBytes(_databaseBytes), 'File DB')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pembersihan & Pengelolaan',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              _actionTile(
                icon: Icons.cleaning_services_rounded,
                iconColor: AppTheme.planToRead,
                title: 'Hapus Cache Aplikasi',
                subtitle: 'File sementara (${_formatBytes(_cacheBytes)})',
                onTap: _isCleaning ? null : _showClearCacheDialog,
              ),
              const Divider(height: 1, color: AppTheme.border),
              _actionTile(
                icon: Icons.photo_library_outlined,
                iconColor: AppTheme.reading,
                title: 'Hapus Thumbnail Cache',
                subtitle: 'Cover komik (${_formatBytes(_thumbnailBytes)})',
                onTap: _isCleaning ? null : _showClearThumbnailDialog,
              ),
              const Divider(height: 1, color: AppTheme.border),
              _actionTile(
                icon: Icons.delete_forever_rounded,
                iconColor: AppTheme.primaryAccent,
                title: 'Hapus Seluruh Data Komik',
                titleColor: AppTheme.primaryAccent,
                subtitle: 'Hapus semua $_totalComics judul dari database',
                onTap: _isCleaning ? null : _showClearAllDataDialog,
              ),
              const Divider(height: 1, color: AppTheme.border),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 20),
                ),
                title: const Text('Info Database',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _dbPath.isNotEmpty ? _dbPath : 'Belum dimuat',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Ukuran: ${_formatBytes(_databaseBytes)}',
                        style: const TextStyle(color: AppTheme.completed, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppTheme.textSecondary, size: 20),
                  onPressed: _dbPath.isNotEmpty ? _copyDbPath : null,
                ),
                onTap: _dbPath.isNotEmpty ? _copyDbPath : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(color: titleColor ?? AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: titleColor ?? AppTheme.textMuted),
      onTap: onTap,
    );
  }
}
