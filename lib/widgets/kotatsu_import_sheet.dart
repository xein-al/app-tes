import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../theme.dart';
import '../models/comic.dart';
import '../db/database_helper.dart';

class KotatsuImportSheet extends StatefulWidget {
  const KotatsuImportSheet({super.key});

  /// Opens the Kotatsu import bottom sheet modal.
  /// Returns the number of imported comics, or `null` if canceled.
  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const KotatsuImportSheet(),
    );
  }

  @override
  State<KotatsuImportSheet> createState() => _KotatsuImportSheetState();
}

class _KotatsuImportSheetState extends State<KotatsuImportSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _jsonController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _selectedMode = 'auto'; // 'auto', 'favourites', 'history'
  bool _replaceExisting = false;
  bool _isImporting = false;

  List<Comic> _parsedComics = [];
  String? _errorMessage;

  late AnimationController _previewAnimController;
  late Animation<double> _previewAnimation;

  @override
  void initState() {
    super.initState();
    _previewAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _previewAnimation = CurvedAnimation(
      parent: _previewAnimController,
      curve: Curves.easeOutCubic,
    );
    _jsonController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _jsonController.removeListener(_onTextChanged);
    _jsonController.dispose();
    _focusNode.dispose();
    _previewAnimController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _parseInput(_jsonController.text);
  }

  void _parseInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _parsedComics = [];
        _errorMessage = null;
      });
      return;
    }

    try {
      final dynamic decoded = jsonDecode(trimmed);
      List<dynamic> rawEntries = [];

      if (decoded is List) {
        rawEntries = decoded;
      } else if (decoded is Map) {
        if (decoded['favourites'] is List) {
          rawEntries = decoded['favourites'] as List;
        } else if (decoded['history'] is List) {
          rawEntries = decoded['history'] as List;
        } else if (decoded['manga'] is List) {
          rawEntries = decoded['manga'] as List;
        } else if (decoded['comics'] is List) {
          rawEntries = decoded['comics'] as List;
        } else if (decoded['data'] is List) {
          rawEntries = decoded['data'] as List;
        } else {
          rawEntries = [decoded];
        }
      } else {
        throw const FormatException('Format JSON tidak sesuai array atau object.');
      }

      final List<Comic> comics = [];
      for (final item in rawEntries) {
        if (item is Map) {
          try {
            final entryMap = Map<String, dynamic>.from(item);
            final comic = _convertKotatsuEntry(entryMap, _selectedMode);
            comics.add(comic);
          } catch (_) {}
        }
      }

      setState(() {
        _parsedComics = comics;
        _errorMessage = comics.isEmpty
            ? 'Format data Kotatsu tidak ditemukan dalam JSON.'
            : null;
      });

      if (comics.isNotEmpty) {
        _previewAnimController.forward(from: 0.0);
      }
    } catch (e) {
      setState(() {
        _parsedComics = [];
        _errorMessage = 'JSON tidak valid: ${e.toString().split('\n').first}';
      });
    }
  }

  Comic _convertKotatsuEntry(Map<String, dynamic> entry, String mode) {
    final dynamic mangaRaw = entry['manga'] ?? entry;
    final Map<String, dynamic> manga = mangaRaw is Map
        ? Map<String, dynamic>.from(mangaRaw)
        : <String, dynamic>{};
    final now = DateTime.now().millisecondsSinceEpoch;

    // Detect comic type (manhwa / manhua / manga)
    String type = 'manga';
    final source = (manga['source'] as String? ?? '').toLowerCase();
    final tagsRaw = manga['tags'] as List?;
    final tags = tagsRaw != null
        ? tagsRaw
            .map((t) => (t is Map ? (t['title'] as String? ?? '') : '').toLowerCase())
            .toList()
        : <String>[];

    if (source.contains('manhwa') ||
        source.contains('webtoon') ||
        tags.any((t) => t.contains('manhwa') || t.contains('webtoon') || t.contains('korean'))) {
      type = 'manhwa';
    } else if (source.contains('manhua') ||
        tags.any((t) => t.contains('manhua') || t.contains('chinese'))) {
      type = 'manhua';
    }

    final bool isHistory = mode == 'history' ||
        (mode == 'auto' && (entry.containsKey('percent') || entry.containsKey('chapter_id')));

    // Status mapping
    String status = 'reading';
    final state = (manga['state'] as String? ?? '').toUpperCase();
    if (isHistory) {
      final percent = (entry['percent'] as num?)?.toDouble() ?? 0.0;
      if (percent >= 1.0) {
        status = 'completed';
      } else if (percent > 0) {
        status = 'reading';
      } else {
        status = 'plan';
      }
    } else {
      if (state == 'FINISHED' || state == 'COMPLETED') {
        status = 'completed';
      } else if (state == 'ABANDONED') {
        status = 'dropped';
      } else if (state == 'PAUSED') {
        status = 'hold';
      } else {
        status = 'reading';
      }
    }

    // Current Chapter calculation
    double currentChapter = 0.0;
    if (entry.containsKey('percent') && entry.containsKey('chapters')) {
      final chapters = (entry['chapters'] as num?)?.toDouble() ?? 0.0;
      final percent = (entry['percent'] as num?)?.toDouble() ?? 0.0;
      currentChapter = (chapters * percent).roundToDouble();
    } else if (entry.containsKey('chapter_id') && entry['chapter_id'] is num) {
      currentChapter = (entry['chapter_id'] as num).toDouble();
    }

    double? totalChapters;
    if (entry.containsKey('chapters') && (entry['chapters'] as num?)?.toDouble() != null) {
      totalChapters = (entry['chapters'] as num).toDouble();
      if (totalChapters <= 0) totalChapters = null;
    }

    double? rating = (manga['rating'] as num?)?.toDouble();
    if (rating != null && rating > 0 && rating <= 1.0) {
      rating = double.parse((rating * 5.0).toStringAsFixed(1));
    }

    final id = manga['id']?.toString() ??
        entry['manga_id']?.toString() ??
        '${now}_${math.Random().nextInt(99999)}';

    return Comic(
      id: id,
      title: manga['title'] as String? ?? 'Tanpa Judul',
      alias: manga['alt_title'] as String?,
      type: type,
      coverUrl: manga['cover_url'] as String?,
      currentChapter: currentChapter,
      totalChapters: totalChapters,
      status: status,
      rating: rating,
      notes: 'Diimpor dari Kotatsu (${manga['source'] ?? 'unknown'})',
      createdAt: (entry['created_at'] as num?)?.toInt() ?? now,
      updatedAt: (entry['updated_at'] as num?)?.toInt() ?? now,
    );
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      _jsonController.text = data.text!.trim();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard kosong atau tidak berisi teks'),
          backgroundColor: AppTheme.surface2,
        ),
      );
    }
  }

  Future<void> _importComics() async {
    if (_parsedComics.isEmpty || _isImporting) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final db = await DatabaseHelper.instance.database;
      int importedCount = 0;

      await db.transaction((txn) async {
        if (_replaceExisting) {
          await txn.delete('comics');
        }

        final batch = txn.batch();
        for (final comic in _parsedComics) {
          batch.insert(
            'comics',
            comic.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedCount++;
        }
        await batch.commit(noResult: true);
      });

      if (!mounted) return;
      Navigator.of(context).pop(importedCount);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _errorMessage = 'Gagal menyimpan ke database: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.import_contacts_rounded, color: AppTheme.primaryAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Impor dari Kotatsu',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Tempel JSON dari backup Kotatsu-Redo (.bk.zip)',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.border, height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 16),
                    _buildJsonInputArea(),
                    const SizedBox(height: 14),
                    _buildReplaceSwitch(),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.primaryAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.primaryAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    AnimatedBuilder(
                      animation: _previewAnimation,
                      builder: (context, child) {
                        if (_parsedComics.isEmpty) return const SizedBox.shrink();
                        return Opacity(
                          opacity: _previewAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, (1.0 - _previewAnimation.value) * 10),
                            child: _buildPreviewSection(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Format Data Backup',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildModeChip('auto', 'Otomatis', Icons.auto_awesome_rounded),
            _buildModeChip('favourites', 'Favourites', Icons.favorite_rounded),
            _buildModeChip('history', 'Riwayat Baca', Icons.history_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildModeChip(String mode, String label, IconData icon) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _selectedMode = mode);
        _parseInput(_jsonController.text);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAccent.withOpacity(0.15) : AppTheme.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAccent : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppTheme.primaryAccent : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryAccent : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJsonInputArea() {
    final hasText = _jsonController.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Isi JSON Kotatsu',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                if (hasText)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Hapus', style: TextStyle(fontSize: 12)),
                    onPressed: () => _jsonController.clear(),
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.reading,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.paste_rounded, size: 16),
                  label: const Text('Tempel', style: TextStyle(fontSize: 12)),
                  onPressed: _pasteFromClipboard,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _jsonController,
          focusNode: _focusNode,
          maxLines: 5,
          minLines: 3,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: '[\n  {\n    "manga": { "title": "Horimiya" }\n  }\n]',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'monospace'),
            filled: true,
            fillColor: AppTheme.surface2,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplaceSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ganti data yang ada',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _replaceExisting
                      ? 'Hapus seluruh data komik saat ini sebelum impor'
                      : 'Gabungkan data baru dengan komik yang ada (merge)',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: _replaceExisting,
            activeThumbColor: AppTheme.primaryAccent,
            onChanged: (val) => setState(() => _replaceExisting = val),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    final previewItems = _parsedComics.take(3).toList();
    final remainingCount = _parsedComics.length - previewItems.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.completed, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_parsedComics.length} komik terdeteksi',
                style: const TextStyle(color: AppTheme.completed, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: previewItems.length,
            separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 12),
            itemBuilder: (context, index) {
              final comic = previewItems[index];
              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 44,
                      color: AppTheme.surface1,
                      child: comic.coverUrl != null && comic.coverUrl!.isNotEmpty
                          ? Image.network(
                              comic.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholderInitial(comic.title),
                            )
                          : _buildPlaceholderInitial(comic.title),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comic.title,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _buildBadge(comic.typeLabel, AppTheme.reading),
                            const SizedBox(width: 6),
                            _buildBadge(comic.statusLabel, comic.statusColor),
                            if (comic.currentChapter > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                'Ch. ${comic.currentChapter % 1 == 0 ? comic.currentChapter.toInt() : comic.currentChapter.toStringAsFixed(1)}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (remainingCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '... dan $remainingCount komik lainnya',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderInitial(String title) {
    final initial = title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface1,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.surface2,
            disabledForegroundColor: AppTheme.textMuted,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _parsedComics.isEmpty || _isImporting ? null : _importComics,
          child: _isImporting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Text('Mengimpor komik...', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.file_download_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _parsedComics.isEmpty
                          ? 'Impor Komik'
                          : 'Impor ${_parsedComics.length} Komik',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
