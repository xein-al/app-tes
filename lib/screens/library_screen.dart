import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models/comic.dart';
import '../db/database_helper.dart';
import '../widgets/quick_add_sheet.dart';
import 'detail_screen.dart';
import 'stats_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  List<Comic> _comics = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  String _selectedStatus = 'all';
  String _searchQuery = '';
  ComicSortOption _sortOption = ComicSortOption.lastUpdated;
  bool _isGridView = false;
  bool _isSearchExpanded = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  late AnimationController _fabAnimController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _fabScale = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeOutBack,
    );
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final comics = await DatabaseHelper.instance.getComics(
      status: _selectedStatus == 'all' ? null : _selectedStatus,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      sortOption: _sortOption,
    );
    final counts = await DatabaseHelper.instance.getStatusCounts();
    if (mounted) {
      setState(() {
        _comics = comics;
        _counts = counts;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
      });
      _loadData();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchCtrl.clear();
        _searchQuery = '';
        _loadData();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _incrementChapter(Comic comic) async {
    HapticFeedback.lightImpact();
    final prevChapter = comic.currentChapter;
    final newChapter = prevChapter + 1;
    final isCompleted = comic.totalChapters != null &&
        comic.totalChapters! > 0 &&
        newChapter >= comic.totalChapters!;

    // Optimistic UI update for zero lag
    final index = _comics.indexWhere((c) => c.id == comic.id);
    if (index != -1) {
      setState(() {
        _comics[index] = _comics[index].copyWith(
          currentChapter: newChapter,
          status: isCompleted ? 'completed' : _comics[index].status,
        );
      });
    }

    final updated = await DatabaseHelper.instance.incrementChapter(comic.id);
    if (updated != null && mounted) {
      _showUndoToast(
        message: '${comic.title} Ch. ${_formatChapter(newChapter)} ✓',
        onUndo: () async {
          await DatabaseHelper.instance.setChapter(comic.id, prevChapter);
          if (comic.status != 'completed') {
            await DatabaseHelper.instance.updateComic(comic);
          }
          _loadData();
        },
      );
      final counts = await DatabaseHelper.instance.getStatusCounts();
      if (mounted) setState(() => _counts = counts);
    }
  }

  Future<void> _decrementChapter(Comic comic) async {
    if (comic.currentChapter <= 0) return;
    HapticFeedback.lightImpact();
    final prevChapter = comic.currentChapter;
    final newChapter = (prevChapter - 1).clamp(0.0, double.infinity);

    // Optimistic UI update
    final index = _comics.indexWhere((c) => c.id == comic.id);
    if (index != -1) {
      setState(() {
        _comics[index] = _comics[index].copyWith(
          currentChapter: newChapter,
        );
      });
    }

    final updated = await DatabaseHelper.instance.decrementChapter(comic.id);
    if (updated != null && mounted) {
      _showUndoToast(
        message: '${comic.title} Ch. ${_formatChapter(newChapter)}',
        onUndo: () async {
          await DatabaseHelper.instance.setChapter(comic.id, prevChapter);
          _loadData();
        },
      );
      final counts = await DatabaseHelper.instance.getStatusCounts();
      if (mounted) setState(() => _counts = counts);
    }
  }

  void _showUndoToast({required String message, required VoidCallback onUndo}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        action: SnackBarAction(
          label: 'URUNGKAN',
          textColor: AppTheme.primaryAccent,
          onPressed: onUndo,
        ),
        backgroundColor: AppTheme.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.border),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openManualChapterDialog(Comic comic) async {
    final ctrl = TextEditingController(text: _formatChapter(comic.currentChapter));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Atur Chapter - ${comic.title}',
          style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
          decoration: const InputDecoration(
            labelText: 'Chapter saat ini',
            prefixIcon: Icon(Icons.bookmark_outline, color: AppTheme.reading),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await DatabaseHelper.instance.setChapter(comic.id, result);
      _showToast('${comic.title} diubah ke Ch.${_formatChapter(result)} ✓');
      _loadData();
    }
  }

  void _showQuickActions(Comic comic) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          comic.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: comic.statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: comic.statusColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          comic.statusLabel,
                          style: TextStyle(fontSize: 11, color: comic.statusColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppTheme.textPrimary),
                  title: const Text('Buka Detail / Edit', style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToDetail(comic);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_border, color: AppTheme.reading),
                  title: const Text('Input Chapter Manual', style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openManualChapterDialog(comic);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: AppTheme.planToRead),
                  title: const Text('Ubah Status', style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showChangeStatusDialog(comic);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppTheme.primaryAccent),
                  title: const Text('Hapus Komik', style: TextStyle(color: AppTheme.primaryAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(comic);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangeStatusDialog(Comic comic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ubah Status',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ComicStatus.values.map((status) {
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status.color,
                ),
              ),
              title: Text(
                status.label,
                style: TextStyle(
                  color: comic.comicStatus == status ? status.color : AppTheme.textPrimary,
                  fontWeight: comic.comicStatus == status ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () async {
                final updated = comic.copyWith(status: status.key);
                await DatabaseHelper.instance.updateComic(updated);
                if (mounted) {
                  Navigator.pop(ctx);
                  _showToast('Status diubah ke ${status.label}');
                  _loadData();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Comic comic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Komik?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus "${comic.title}" dari library?',
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
      await DatabaseHelper.instance.deleteComic(comic.id);
      _showToast('"${comic.title}" telah dihapus');
      _loadData();
    }
  }

  void _navigateToDetail(Comic comic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(comicId: comic.id)),
    );
    _loadData();
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

  Color _progressTextColor(Comic comic) {
    if (comic.totalChapters == null || comic.totalChapters! <= 0) {
      return AppTheme.textPrimary;
    }
    final pct = comic.progressPercent;
    if (pct >= 0.75) return AppTheme.completed;
    if (pct >= 0.50) return AppTheme.planToRead;
    return AppTheme.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo is ScrollUpdateNotification) {
            // Dismiss keyboard on scroll
            FocusScope.of(context).unfocus();
            if (scrollInfo.scrollDelta != null) {
              if (scrollInfo.scrollDelta! > 10 && _fabAnimController.value > 0) {
                _fabAnimController.reverse();
              } else if (scrollInfo.scrollDelta! < -10 && _fabAnimController.value < 1) {
                _fabAnimController.forward();
              }
            }
          }
          return false;
        },
        child: Column(
          children: [
            _buildFilterChips(),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryAccent,
                backgroundColor: AppTheme.surface2,
                onRefresh: _loadData,
                child: _loading
                    ? _buildShimmerLoading()
                    : _comics.isEmpty
                        ? _buildEmptyState()
                        : _isGridView
                            ? _buildGridView()
                            : _buildListView(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton(
          backgroundColor: AppTheme.primaryAccent,
          onPressed: () {
            QuickAddSheet.show(context, onSaved: _loadData);
          },
          child: const Icon(Icons.add, size: 28, color: Colors.white),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: AnimatedCrossFade(
        duration: const Duration(milliseconds: 250),
        crossFadeState: _isSearchExpanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book, color: AppTheme.primaryAccent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Manga Tracker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        secondChild: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Cari judul komik...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
              onPressed: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              },
            ),
            filled: true,
            fillColor: AppTheme.surface1,
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearchExpanded ? Icons.close : Icons.search,
            color: _isSearchExpanded ? AppTheme.primaryAccent : AppTheme.textPrimary,
          ),
          onPressed: _toggleSearch,
        ),
        IconButton(
          icon: Icon(
            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () {
            setState(() => _isGridView = !_isGridView);
          },
        ),
        PopupMenuButton<ComicSortOption>(
          icon: const Icon(Icons.sort_rounded, color: AppTheme.textPrimary),
          color: AppTheme.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          onSelected: (option) {
            setState(() => _sortOption = option);
            _loadData();
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: ComicSortOption.lastUpdated,
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: AppTheme.textSecondary),
                  SizedBox(width: 10),
                  Text('Terakhir Diupdate', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: ComicSortOption.titleAZ,
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha, size: 18, color: AppTheme.textSecondary),
                  SizedBox(width: 10),
                  Text('Judul (A-Z)', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: ComicSortOption.progress,
              child: Row(
                children: [
                  Icon(Icons.pie_chart_outline, size: 18, color: AppTheme.textSecondary),
                  SizedBox(width: 10),
                  Text('Progress Baca (%)', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.analytics_outlined, color: AppTheme.textPrimary),
          onPressed: () {
            Navigator.pushNamed(context, StatsScreen.routeName);
          },
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'Semua', null),
      ('reading', 'Membaca', AppTheme.reading),
      ('plan', 'Rencana', AppTheme.planToRead),
      ('completed', 'Selesai', AppTheme.completed),
      ('hold', 'Ditahan', AppTheme.onHold),
      ('dropped', 'Dropped', AppTheme.dropped),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedStatus == filter.$1;
          final count = _counts[filter.$1] ?? 0;
          final color = filter.$3 ?? AppTheme.primaryAccent;

          return GestureDetector(
            onTap: () {
              if (_selectedStatus != filter.$1) {
                setState(() => _selectedStatus = filter.$1);
                _loadData();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.18) : AppTheme.surface1,
                border: Border.all(
                  color: isSelected ? color : AppTheme.border,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter.$3 != null) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? color : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    filter.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? color : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.25) : AppTheme.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _comics.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comic = _comics[index];
        return _buildDismissibleCard(comic, isGrid: false);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _comics.length,
      itemBuilder: (context, index) {
        final comic = _comics[index];
        return _buildDismissibleCard(comic, isGrid: true);
      },
    );
  }

  Widget _buildDismissibleCard(Comic comic, {required bool isGrid}) {
    return Dismissible(
      key: Key(comic.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.primaryAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.5)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppTheme.primaryAccent, size: 28),
            SizedBox(height: 4),
            Text('Hapus', style: TextStyle(color: AppTheme.primaryAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (dir) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Hapus Komik?', style: TextStyle(color: AppTheme.textPrimary)),
            content: Text('Hapus "${comic.title}"?', style: const TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hapus', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await DatabaseHelper.instance.deleteComic(comic.id);
        _showToast('"${comic.title}" telah dihapus');
        _loadData();
      },
      child: isGrid ? _buildGridCard(comic) : _buildListCard(comic),
    );
  }

  Widget _buildListCard(Comic comic) {
    return GestureDetector(
      onTap: () => _navigateToDetail(comic),
      onLongPress: () => _showQuickActions(comic),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: comic.statusColor.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with Hero
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 100,
                child: Hero(
                  tag: 'cover_${comic.id}',
                  child: _buildCoverImage(comic.coverUrl, comic.title),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge & status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surface2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          comic.typeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Dot
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: comic.statusColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        comic.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: comic.statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    comic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (comic.alias != null && comic.alias!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      comic.alias!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Chapter progress text
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Text(
                          'Ch. ${_formatChapter(comic.currentChapter)}',
                          key: ValueKey('ch_${comic.id}_${comic.currentChapter}'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _progressTextColor(comic),
                          ),
                        ),
                      ),
                      if (comic.totalChapters != null && comic.totalChapters! > 0)
                        Text(
                          ' / ${_formatChapter(comic.totalChapters!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Linear progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: comic.progressPercent,
                      minHeight: 5,
                      backgroundColor: AppTheme.surface2,
                      valueColor: AlwaysStoppedAnimation<Color>(comic.statusColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Chapter Control Buttons
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // -1 Button (small)
                _ChapterMiniButton(
                  label: '−1',
                  enabled: comic.currentChapter > 0,
                  onTap: () => _decrementChapter(comic),
                ),
                const SizedBox(height: 6),
                // +1 Button (main)
                _IncrementButton(
                  onTap: () => _incrementChapter(comic),
                  onLongPress: () => _openManualChapterDialog(comic),
                ),
                const SizedBox(height: 4),
                // Hint text
                const Text(
                  'tahan\natur',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color: AppTheme.textMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(Comic comic) {
    return GestureDetector(
      onTap: () => _navigateToDetail(comic),
      onLongPress: () => _showQuickActions(comic),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: comic.statusColor.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Header
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'cover_${comic.id}',
                    child: _buildCoverImage(comic.coverUrl, comic.title),
                  ),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                  // Type badge top-left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        comic.typeLabel,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  // Status dot top-right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: comic.statusColor,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                  // +1 & -1 Buttons bottom-right
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Row(
                      children: [
                        _ChapterMiniButton(
                          label: '−',
                          enabled: comic.currentChapter > 0,
                          onTap: () => _decrementChapter(comic),
                        ),
                        const SizedBox(width: 4),
                        _IncrementButton(
                          mini: true,
                          onTap: () => _incrementChapter(comic),
                          onLongPress: () => _openManualChapterDialog(comic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Info Footer
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      comic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            'Ch. ${_formatChapter(comic.currentChapter)}',
                            key: ValueKey('g_ch_${comic.id}_${comic.currentChapter}'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _progressTextColor(comic),
                            ),
                          ),
                        ),
                        if (comic.totalChapters != null)
                          Text(
                            '/${_formatChapter(comic.totalChapters!)}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: comic.progressPercent,
                        minHeight: 4,
                        backgroundColor: AppTheme.surface2,
                        valueColor: AlwaysStoppedAnimation<Color>(comic.statusColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(String? url, String title) {
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderCover(title),
      );
    }
    return _buildPlaceholderCover(title);
  }

  Widget _buildPlaceholderCover(String title) {
    final initials = title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return Container(
      color: AppTheme.surface2,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _ShimmerCard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surface1,
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(
                  Icons.auto_stories_outlined,
                  size: 44,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Belum Ada Komik',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mulai lacak komik favoritmu sekarang\ndengan menekan tombol di bawah.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Tambah Komik'),
                onPressed: () {
                  QuickAddSheet.show(context, onSaved: _loadData);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Shimmer Skeleton (No 3rd-party package) ──────────────────────────

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              _buildShimmerBox(width: 72, height: 100, radius: 10),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(width: 80, height: 14, radius: 4),
                    const SizedBox(height: 10),
                    _buildShimmerBox(width: double.infinity, height: 16, radius: 4),
                    const SizedBox(height: 8),
                    _buildShimmerBox(width: 120, height: 12, radius: 4),
                    const SizedBox(height: 14),
                    _buildShimmerBox(width: double.infinity, height: 6, radius: 3),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({required double width, required double height, required double radius}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + (_controller.value * 2), -0.3),
          end: Alignment(1.0 + (_controller.value * 2), 0.3),
          colors: const [
            AppTheme.surface1,
            AppTheme.surface2,
            AppTheme.surface1,
          ],
        ),
      ),
    );
  }
}

// ─── Quick Increment & Decrement Buttons ──────────────────────────────────────

class _IncrementButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool mini;

  const _IncrementButton({
    required this.onTap,
    this.onLongPress,
    this.mini = false,
  });

  @override
  State<_IncrementButton> createState() => _IncrementButtonState();
}

class _IncrementButtonState extends State<_IncrementButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.15), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _handleTap() {
    _anim.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.mini ? 32.0 : 42.0;

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF5757),
                Color(0xFFE62E2E),
              ],
            ),
            borderRadius: BorderRadius.circular(widget.mini ? 8 : 12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryAccent.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '+1',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: widget.mini ? 11 : 14,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterMiniButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ChapterMiniButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          width: 32,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
