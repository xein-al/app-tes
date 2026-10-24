import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models/comic.dart';
import '../db/database_helper.dart';

class DetailScreen extends StatefulWidget {
  static const routeName = '/detail';

  final String? comicId;

  const DetailScreen({super.key, this.comicId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  Comic? _comic;
  bool _loading = true;

  // Controllers for editing
  late TextEditingController _titleCtrl;
  late TextEditingController _aliasCtrl;
  late TextEditingController _coverCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _totalChaptersCtrl;

  double _currentChapter = 0;
  String _status = 'reading';
  String _type = 'manhwa';
  double _rating = 0.0;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _aliasCtrl = TextEditingController();
    _coverCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _totalChaptersCtrl = TextEditingController();

    _titleCtrl.addListener(_onFieldChanged);
    _aliasCtrl.addListener(_onFieldChanged);
    _coverCtrl.addListener(_onFieldChanged);
    _notesCtrl.addListener(_onFieldChanged);
    _totalChaptersCtrl.addListener(_onFieldChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadComic();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _aliasCtrl.dispose();
    _coverCtrl.dispose();
    _notesCtrl.dispose();
    _totalChaptersCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  Future<void> _loadComic() async {
    final id = widget.comicId ?? (ModalRoute.of(context)?.settings.arguments as String?);
    if (id == null) {
      setState(() => _loading = false);
      return;
    }

    final comic = await DatabaseHelper.instance.getComic(id);
    if (comic != null && mounted) {
      setState(() {
        _comic = comic;
        _titleCtrl.text = comic.title;
        _aliasCtrl.text = comic.alias ?? '';
        _coverCtrl.text = comic.coverUrl ?? '';
        _notesCtrl.text = comic.notes ?? '';
        _totalChaptersCtrl.text = comic.totalChapters != null
            ? _formatChapter(comic.totalChapters!)
            : '';
        _currentChapter = comic.currentChapter;
        _status = comic.status;
        _type = comic.type;
        _rating = comic.rating ?? 0.0;
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasUnsavedChanges {
    if (_comic == null) return false;
    final total = double.tryParse(_totalChaptersCtrl.text.trim());
    return _titleCtrl.text.trim() != _comic!.title ||
        _aliasCtrl.text.trim() != (_comic!.alias ?? '') ||
        _coverCtrl.text.trim() != (_comic!.coverUrl ?? '') ||
        _notesCtrl.text.trim() != (_comic!.notes ?? '') ||
        total != _comic!.totalChapters ||
        _currentChapter != _comic!.currentChapter ||
        _status != _comic!.status ||
        _type != _comic!.type ||
        _rating != (_comic!.rating ?? 0.0);
  }

  Future<void> _saveChanges() async {
    if (_comic == null) return;
    if (_titleCtrl.text.trim().isEmpty) {
      _showToast('Judul tidak boleh kosong!');
      return;
    }

    HapticFeedback.mediumImpact();

    final total = _totalChaptersCtrl.text.trim().isNotEmpty
        ? double.tryParse(_totalChaptersCtrl.text.trim())
        : null;

    final bool autoCompleted =
        total != null && total > 0 && _currentChapter >= total;

    final updated = _comic!.copyWith(
      title: _titleCtrl.text.trim(),
      alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
      coverUrl: _coverCtrl.text.trim().isEmpty ? null : _coverCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      totalChapters: total,
      currentChapter: _currentChapter,
      status: autoCompleted ? 'completed' : _status,
      type: _type,
      rating: _rating > 0 ? _rating : null,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseHelper.instance.updateComic(updated);

    if (mounted) {
      setState(() {
        _comic = updated;
        _status = updated.status;
      });
      _showToast('Perubahan berhasil disimpan ✓');
    }
  }

  void _incrementChapter() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentChapter += 1;
      final total = double.tryParse(_totalChaptersCtrl.text.trim());
      if (total != null && total > 0 && _currentChapter >= total) {
        _status = 'completed';
      }
    });
  }

  void _decrementChapter() {
    if (_currentChapter <= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentChapter = (_currentChapter - 1).clamp(0.0, double.infinity);
    });
  }

  Future<void> _confirmDelete() async {
    if (_comic == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Komik?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Hapus "${_comic!.title}" secara permanen?',
          style: const TextStyle(color: AppTheme.textSecondary),
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
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DatabaseHelper.instance.deleteComic(_comic!.id);
      Navigator.pop(context);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.border),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatChapter(double ch) {
    if (ch == ch.roundToDouble()) {
      return ch.toInt().toString();
    }
    return ch.toString();
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$min WIB';
  }

  double get _progressPercent {
    final total = double.tryParse(_totalChaptersCtrl.text.trim());
    if (total == null || total <= 0) return 0.0;
    return (_currentChapter / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundBase,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryAccent),
        ),
      );
    }

    if (_comic == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundBase,
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'Komik tidak ditemukan',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final totalChapters = double.tryParse(_totalChaptersCtrl.text.trim());

    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Visual Progress Ring & Quick Counter ──
                  _buildProgressAndCounterCard(totalChapters),
                  const SizedBox(height: 16),

                  // ── Status Selector (Animated) ──
                  _buildStatusSection(),
                  const SizedBox(height: 16),

                  // ── Rating Section (Half-star support) ──
                  _buildRatingSection(),
                  const SizedBox(height: 16),

                  // ── Comic Info & Inputs ──
                  _buildInfoCard(),
                  const SizedBox(height: 16),

                  // ── Notes Card ──
                  _buildNotesCard(),
                  const SizedBox(height: 16),

                  // ── Metadata & Last Read Timestamp ──
                  _buildMetadataCard(),
                  const SizedBox(height: 24),

                  // ── Delete Button ──
                  Center(
                    child: TextButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline, color: AppTheme.primaryAccent, size: 20),
                      label: const Text(
                        'Hapus Komik Ini',
                        style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: _hasUnsavedChanges ? Offset.zero : const Offset(0, 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _hasUnsavedChanges ? 1.0 : 0.0,
          child: FloatingActionButton.extended(
            onPressed: _hasUnsavedChanges ? _saveChanges : null,
            backgroundColor: AppTheme.primaryAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.backgroundBase,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        if (_hasUnsavedChanges)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.primaryAccent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.check, color: Colors.white, size: 20),
              onPressed: _saveChanges,
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Parallax Hero Cover
            Hero(
              tag: 'cover_${_comic!.id}',
              child: _buildCoverHeaderImage(),
            ),
            // Dramatic Multi-stage Gradient Overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6),
                    AppTheme.backgroundBase.withOpacity(0.95),
                    AppTheme.backgroundBase,
                  ],
                  stops: const [0.0, 0.45, 0.85, 1.0],
                ),
              ),
            ),
            // Header Content (Title, Type, Status Pill)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surface2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          AppTheme.typeLabel(_type),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.statusColor(_status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.statusColor(_status)),
                        ),
                        child: Text(
                          AppTheme.statusLabel(_status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.statusColor(_status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _titleCtrl.text.isNotEmpty ? _titleCtrl.text : _comic!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverHeaderImage() {
    final url = _coverCtrl.text.trim().isNotEmpty ? _coverCtrl.text.trim() : _comic!.coverUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderHeaderCover(),
      );
    }
    return _buildPlaceholderHeaderCover();
  }

  Widget _buildPlaceholderHeaderCover() {
    return Container(
      color: AppTheme.surface1,
      child: Center(
        child: Icon(
          Icons.menu_book,
          size: 72,
          color: AppTheme.border.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildProgressAndCounterCard(double? total) {
    final statusColor = AppTheme.statusColor(_status);
    final pct = _progressPercent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Custom Arc Progress Ring
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(88, 88),
                  painter: _ProgressRingPainter(
                    progress: pct,
                    progressColor: statusColor,
                    backgroundColor: AppTheme.surface2,
                    strokeWidth: 8,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(pct * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const Text(
                      'PROGRESS',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.5,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Chapter Counter & Buttons
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHAPTER SAAT INI',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatChapter(_currentChapter),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (total != null && total > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        ' / ${_formatChapter(total)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStepButton(
                      icon: Icons.remove,
                      onTap: _decrementChapter,
                      disabled: _currentChapter <= 0,
                    ),
                    const SizedBox(width: 10),
                    _buildStepButton(
                      icon: Icons.add,
                      label: '+1',
                      onTap: _incrementChapter,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final ctrl = TextEditingController(text: _formatChapter(_currentChapter));
                          final result = await showDialog<double>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.surface2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              title: const Text('Input Chapter', style: TextStyle(color: AppTheme.textPrimary)),
                              content: TextField(
                                controller: ctrl,
                                autofocus: true,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: AppTheme.textPrimary),
                                decoration: const InputDecoration(labelText: 'Chapter'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                                  onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
                                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (result != null) {
                            setState(() => _currentChapter = result);
                          }
                        },
                        child: const Text('Edit', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: disabled ? AppTheme.surface2.withOpacity(0.5) : AppTheme.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: disabled ? AppTheme.border.withOpacity(0.5) : AppTheme.border),
        ),
        child: Center(
          child: label != null
              ? Text(
                  label,
                  style: TextStyle(
                    color: disabled ? AppTheme.textMuted : AppTheme.primaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                )
              : Icon(
                  icon,
                  size: 18,
                  color: disabled ? AppTheme.textMuted : AppTheme.textPrimary,
                ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final statuses = [
      ('reading', 'Membaca', AppTheme.reading),
      ('plan', 'Rencana', AppTheme.planToRead),
      ('completed', 'Selesai', AppTheme.completed),
      ('hold', 'Ditahan', AppTheme.onHold),
      ('dropped', 'Dropped', AppTheme.dropped),
    ];

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
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((s) {
              final isSelected = _status == s.$1;
              final color = s.$3;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _status = s.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.18) : AppTheme.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : AppTheme.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? color : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? color : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RATING PRIBADI',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _rating > 0 ? '${_rating.toStringAsFixed(1)} / 5.0' : 'Belum dinilai',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _rating > 0 ? AppTheme.planToRead : AppTheme.textMuted,
                ),
              ),
            ],
          ),
          // Interactive 5-Star Row with Half-star tap detection
          Row(
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              IconData icon;
              Color color;

              if (_rating >= starNumber) {
                icon = Icons.star_rounded;
                color = AppTheme.planToRead;
              } else if (_rating >= starNumber - 0.5) {
                icon = Icons.star_half_rounded;
                color = AppTheme.planToRead;
              } else {
                icon = Icons.star_border_rounded;
                color = AppTheme.textMuted;
              }

              return GestureDetector(
                onTapDown: (details) {
                  HapticFeedback.selectionClick();
                  // Check if left or right half
                  final isLeft = details.localPosition.dx < 16;
                  final selected = isLeft ? (index + 0.5) : (index + 1.0);
                  setState(() {
                    if (_rating == selected) {
                      _rating = 0.0; // Toggle off if clicked same
                    } else {
                      _rating = selected;
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(icon, color: color, size: 32),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
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
            'DETAIL INFORMASI',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          // Title
          _buildFieldLabel('Judul'),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Judul komik...',
              prefixIcon: Icon(Icons.title, color: AppTheme.textMuted, size: 20),
            ),
          ),
          const SizedBox(height: 14),

          // Alias
          _buildFieldLabel('Alias / Judul Alternatif'),
          const SizedBox(height: 6),
          TextField(
            controller: _aliasCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Alias (opsional)...',
              prefixIcon: Icon(Icons.label_outline, color: AppTheme.textMuted, size: 20),
            ),
          ),
          const SizedBox(height: 14),

          // Type and Total Chapters Row
          Row(
            children: [
              // Type Selector
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Tipe'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _type,
                          isExpanded: true,
                          dropdownColor: AppTheme.surface2,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          icon: const Icon(Icons.expand_more, color: AppTheme.textMuted),
                          items: ['manhwa', 'manga', 'manhua'].map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(AppTheme.typeLabel(t)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _type = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Total Chapters
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Total Chapter'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _totalChaptersCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Opsional',
                        prefixIcon: Icon(Icons.tag, color: AppTheme.textMuted, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cover URL
          _buildFieldLabel('URL Cover'),
          const SizedBox(height: 6),
          TextField(
            controller: _coverCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'https://...',
              prefixIcon: Icon(Icons.image_outlined, color: AppTheme.textMuted, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
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
            'CATATAN PRIBADI',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.4),
            decoration: const InputDecoration(
              hintText: 'Tulis catatan, sinopsis singkat, atau pengingat chapter di sini...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
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
            'RIWAYAT',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetaRow(Icons.access_time, 'Terakhir Dibaca', _formatDate(_comic!.updatedAt)),
          const SizedBox(height: 8),
          _buildMetaRow(Icons.calendar_today, 'Ditambahkan', _formatDate(_comic!.createdAt)),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

// ─── Custom Arc Painter for Progress Ring ────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  const _ProgressRingPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // Background track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
