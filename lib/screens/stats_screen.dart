import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../theme.dart';

class StatsScreen extends StatefulWidget {
  static const routeName = '/stats';

  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isExporting = false;

  int _totalComics = 0;
  double _totalChapters = 0.0;
  double _avgChapters = 0.0;
  int _readingStreak = 0;

  Map<String, int> _typeDist = {'manga': 0, 'manhwa': 0, 'manhua': 0};
  Map<String, int> _statusDist = {
    'reading': 0,
    'plan': 0,
    'completed': 0,
    'hold': 0,
    'dropped': 0,
  };

  late AnimationController _animController;
  late Animation<double> _countAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _countAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    refresh();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final stats = await DatabaseHelper.instance.getStats();
    if (mounted) {
      setState(() {
        _totalComics = stats['totalComics'] as int;
        _totalChapters = (stats['totalChaptersRead'] as num).toDouble();
        _avgChapters = (stats['avgChaptersPerComic'] as num).toDouble();
        _readingStreak = stats['readingStreak'] as int;
        _typeDist = Map<String, int>.from(stats['typeDistribution'] as Map);
        _statusDist = Map<String, int>.from(stats['statusDistribution'] as Map);
        _isLoading = false;
      });
      _animController.forward(from: 0.0);
    }
  }

  Future<void> _exportJson() async {
    HapticFeedback.lightImpact();
    setState(() => _isExporting = true);
    try {
      final filePath = await DatabaseHelper.instance.exportToJsonFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.completed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data berhasil diekspor:\n$filePath',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: AppTheme.surface2,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor data: $e'),
            backgroundColor: AppTheme.surface2,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Animation<double> _createStaggerAnimation(double begin, double end) {
    return CurvedAnimation(
      parent: _animController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: AppBar(
        title: const Text(
          'Profil & Statistik',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : RefreshIndicator(
              color: AppTheme.primaryAccent,
              backgroundColor: AppTheme.surface2,
              onRefresh: refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Reading Streak Banner ──
                    _buildAnimatedCard(
                      animation: _createStaggerAnimation(0.0, 0.4),
                      child: _buildStreakCard(),
                    ),
                    const SizedBox(height: 14),

                    // ── 2x2 Metric Grid ──
                    _buildAnimatedCard(
                      animation: _createStaggerAnimation(0.15, 0.55),
                      child: _buildMetricsGrid(),
                    ),
                    const SizedBox(height: 14),

                    // ── Type Distribution Chart ──
                    _buildAnimatedCard(
                      animation: _createStaggerAnimation(0.3, 0.7),
                      child: _buildTypeDistributionCard(),
                    ),
                    const SizedBox(height: 14),

                    // ── Status Distribution Card ──
                    _buildAnimatedCard(
                      animation: _createStaggerAnimation(0.45, 0.85),
                      child: _buildStatusDistributionCard(),
                    ),
                    const SizedBox(height: 20),

                    // ── Export JSON Button ──
                    _buildAnimatedCard(
                      animation: _createStaggerAnimation(0.6, 1.0),
                      child: _buildExportButton(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAnimatedCard({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1.0 - value)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surface1,
            AppTheme.primaryAccent.withOpacity(0.08),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryAccent.withOpacity(0.15),
            ),
            child: const Center(
              child: Icon(
                Icons.local_fire_department_rounded,
                color: AppTheme.primaryAccent,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'READING STREAK',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _countAnimation,
                  builder: (context, _) {
                    final streak = (_readingStreak * _countAnimation.value).toInt();
                    return Text(
                      '$streak Hari Berturut-turut',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              _readingStreak > 0 ? 'Aktif 🔥' : 'Mulai Hari Ini',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _readingStreak > 0 ? AppTheme.primaryAccent : AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildMetricTile(
                title: 'TOTAL JUDUL',
                value: _totalComics.toDouble(),
                icon: Icons.book_outlined,
                iconColor: AppTheme.primaryAccent,
                isDecimal: false,
              ),
              const SizedBox(height: 12),
              _buildMetricTile(
                title: 'RATA-RATA / JUDUL',
                value: _avgChapters,
                icon: Icons.speed_rounded,
                iconColor: AppTheme.planToRead,
                isDecimal: true,
                suffix: ' ch',
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildMetricTile(
                title: 'CHAPTER DIBACA',
                value: _totalChapters,
                icon: Icons.auto_stories_outlined,
                iconColor: AppTheme.reading,
                isDecimal: false,
              ),
              const SizedBox(height: 12),
              _buildMetricTile(
                title: 'KOMIK SELESAI',
                value: (_statusDist['completed'] ?? 0).toDouble(),
                icon: Icons.check_circle_outline,
                iconColor: AppTheme.completed,
                isDecimal: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required double value,
    required IconData icon,
    required Color iconColor,
    bool isDecimal = false,
    String suffix = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textSecondary,
                ),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _countAnimation,
            builder: (context, _) {
              final current = value * _countAnimation.value;
              final formatted = isDecimal
                  ? current.toStringAsFixed(1)
                  : current.toInt().toString();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatted,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (suffix.isNotEmpty)
                    Text(
                      suffix,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDistributionCard() {
    final mangaCount = _typeDist['manga'] ?? 0;
    final manhwaCount = _typeDist['manhwa'] ?? 0;
    final manhuaCount = _typeDist['manhua'] ?? 0;
    final total = _totalComics == 0 ? 1 : _totalComics;

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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISTRIBUSI TIPE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary,
                ),
              ),
              Icon(Icons.donut_large_rounded, size: 16, color: AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnimatedBarRow('Manhwa', manhwaCount, manhwaCount / total, AppTheme.reading),
          const SizedBox(height: 12),
          _buildAnimatedBarRow('Manga', mangaCount, mangaCount / total, AppTheme.completed),
          const SizedBox(height: 12),
          _buildAnimatedBarRow('Manhua', manhuaCount, manhuaCount / total, AppTheme.planToRead),
        ],
      ),
    );
  }

  Widget _buildAnimatedBarRow(String label, int count, double fraction, Color barColor) {
    return AnimatedBuilder(
      animation: _countAnimation,
      builder: (context, _) {
        final animatedFraction = (fraction * _countAnimation.value).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$count (${(fraction * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: animatedFraction,
                minHeight: 7,
                backgroundColor: AppTheme.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusDistributionCard() {
    final statusList = [
      {'key': 'reading', 'label': 'Sedang Membaca', 'color': AppTheme.reading},
      {'key': 'plan', 'label': 'Rencana Baca', 'color': AppTheme.planToRead},
      {'key': 'completed', 'label': 'Selesai', 'color': AppTheme.completed},
      {'key': 'hold', 'label': 'Ditahan', 'color': AppTheme.onHold},
      {'key': 'dropped', 'label': 'Dropped', 'color': AppTheme.dropped},
    ];

    final total = _totalComics == 0 ? 1 : _totalComics;

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
          const Text(
            'STATUS BACAAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...statusList.map((item) {
            final key = item['key'] as String;
            final label = item['label'] as String;
            final color = item['color'] as Color;
            final count = _statusDist[key] ?? 0;
            final percent = ((count / total) * 100).round();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : _exportJson,
        icon: _isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded, color: Colors.white, size: 20),
        label: Text(
          _isExporting ? 'Mengekspor...' : 'Ekspor Data ke JSON',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.surface2,
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}
