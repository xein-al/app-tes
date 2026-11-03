import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
// import '../backups/periodic_backup_service.dart'; // Temporary disabled

/// Screen untuk settings auto backup.
class BackupSettingsScreen extends StatefulWidget {
  static const String routeName = '/backup-settings';

  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyBackupInterval = 'backup_interval_days';
  static const String _keyKeepBackups = 'keep_backups_count';

  bool _autoBackupEnabled = false;
  int _intervalDays = 7;
  int _keepBackupsCount = 5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoBackupEnabled = prefs.getBool(_keyAutoBackupEnabled) ?? false;
      _intervalDays = prefs.getInt(_keyBackupInterval) ?? 7;
      _keepBackupsCount = prefs.getInt(_keyKeepBackups) ?? 5;
      _isLoading = false;
    });
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackupEnabled, enabled);

    if (enabled) {
      // TODO: Re-enable when workmanager is fixed
      // await PeriodicBackupService.scheduleBackup(_intervalDays);
      if (mounted) {
        _showSnackbar('⚠️ Auto backup akan diaktifkan di update berikutnya');
      }
    } else {
      // TODO: Re-enable when workmanager is fixed
      // await PeriodicBackupService.cancelBackup();
      if (mounted) {
        _showSnackbar('Auto backup dinonaktifkan');
      }
    }

    setState(() => _autoBackupEnabled = enabled);
  }

  Future<void> _updateInterval(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBackupInterval, days);
    setState(() => _intervalDays = days);

    if (_autoBackupEnabled) {
      // TODO: Re-enable when workmanager is fixed
      // await PeriodicBackupService.scheduleBackup(days);
      _showSnackbar('✓ Interval backup diubah ke $days hari');
    }
  }

  Future<void> _updateKeepCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyKeepBackups, count);
    setState(() => _keepBackupsCount = count);
    _showSnackbar('✓ Simpan $count backup terakhir');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundBase,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: AppBar(
        backgroundColor: AppTheme.surface1,
        title: const Text('Pengaturan Auto Backup'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Auto Backup',
            icon: Icons.backup_rounded,
            children: [
              SwitchListTile(
                title: const Text('Aktifkan Auto Backup'),
                subtitle: const Text('Backup otomatis secara berkala'),
                value: _autoBackupEnabled,
                onChanged: _toggleAutoBackup,
                activeColor: AppTheme.primaryAccent,
              ),
              if (_autoBackupEnabled) ...[
                const Divider(),
                ListTile(
                  title: const Text('Interval Backup'),
                  subtitle: Text('Setiap $_intervalDays hari'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showIntervalPicker(),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Jumlah Backup Tersimpan'),
                  subtitle: Text('Simpan $_keepBackupsCount backup terakhir'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showKeepCountPicker(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tentang Auto Backup',
                  style: TextStyle(
                    color: AppTheme.primaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '⚠️ Auto backup sementara dinonaktifkan karena kompatibilitas Kotlin. Fitur manual backup tetap berfungsi normal. Update akan datang segera!',
                  style: TextStyle(
                    color: AppTheme.textPrimary.withOpacity(0.8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showIntervalPicker() async {
    final intervals = [1, 3, 7, 14, 30];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Interval Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: intervals.map((days) {
            return RadioListTile<int>(
              title: Text('Setiap $days hari'),
              value: days,
              groupValue: _intervalDays,
              onChanged: (val) => Navigator.pop(ctx, val),
              activeColor: AppTheme.primaryAccent,
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null && selected != _intervalDays) {
      await _updateInterval(selected);
    }
  }

  Future<void> _showKeepCountPicker() async {
    final counts = [3, 5, 10, 15, 20];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Jumlah Backup Tersimpan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: counts.map((count) {
            return RadioListTile<int>(
              title: Text('Simpan $count backup terakhir'),
              value: count,
              groupValue: _keepBackupsCount,
              onChanged: (val) => Navigator.pop(ctx, val),
              activeColor: AppTheme.primaryAccent,
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null && selected != _keepBackupsCount) {
      await _updateKeepCount(selected);
    }
  }
}
