import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models/comic.dart';
import '../db/database_helper.dart';

class QuickAddSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const QuickAddSheet({super.key, required this.onSaved});

  static Future<void> show(BuildContext context, {required VoidCallback onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheet(onSaved: onSaved),
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();

  String _selectedType = 'manhwa';
  String _selectedStatus = 'reading';
  bool _saving = false;
  bool _showSuccess = false;

  late AnimationController _successAnimCtrl;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _successAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successAnimCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _aliasCtrl.dispose();
    _coverCtrl.dispose();
    _totalCtrl.dispose();
    _successAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _save({bool andContinue = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final now = DateTime.now().millisecondsSinceEpoch;
    final comic = Comic(
      id: '${now}_${Random().nextInt(99999)}',
      title: _titleCtrl.text.trim(),
      alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
      type: _selectedType,
      coverUrl: _coverCtrl.text.trim().isEmpty ? null : _coverCtrl.text.trim(),
      currentChapter: 0,
      totalChapters: _totalCtrl.text.trim().isNotEmpty
          ? double.tryParse(_totalCtrl.text.trim())
          : null,
      status: _selectedStatus,
      createdAt: now,
      updatedAt: now,
    );

    await DatabaseHelper.instance.insertComic(comic);
    widget.onSaved();

    setState(() {
      _saving = false;
      _showSuccess = true;
    });
    _successAnimCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    if (andContinue) {
      _titleCtrl.clear();
      _aliasCtrl.clear();
      _coverCtrl.clear();
      _totalCtrl.clear();
      setState(() => _showSuccess = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // ── Title ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: AppTheme.primaryAccent, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Tambah Komik Baru',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // ── Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _showSuccess ? _buildSuccessView() : _buildFormView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return SizedBox(
      key: const ValueKey('success'),
      height: 200,
      child: Center(
        child: ScaleTransition(
          scale: _successScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.completed.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.completed,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Berhasil ditambahkan!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          _buildLabel('Judul *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Contoh: Solo Leveling',
              prefixIcon: Icon(Icons.book_outlined, color: AppTheme.textMuted, size: 20),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul tidak boleh kosong' : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          // Alias
          _buildLabel('Alias'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _aliasCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Nama alternatif (opsional)',
              prefixIcon: Icon(Icons.label_outline, color: AppTheme.textMuted, size: 20),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          // Type + Total chapters
          Row(
            children: [
              // Type Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Tipe'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isExpanded: true,
                          dropdownColor: AppTheme.surface2,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          icon: const Icon(Icons.expand_more, color: AppTheme.textMuted, size: 20),
                          items: ['manhwa', 'manga', 'manhua'].map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  _typeIcon(t),
                                  const SizedBox(width: 8),
                                  Text(AppTheme.typeLabel(t)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedType = v);
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
                    _buildLabel('Total Chapter'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _totalCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Opsional',
                        prefixIcon: Icon(Icons.tag, color: AppTheme.textMuted, size: 20),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cover URL
          _buildLabel('URL Cover'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _coverCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'https://... (opsional)',
              prefixIcon: Icon(Icons.image_outlined, color: AppTheme.textMuted, size: 20),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          // Status
          _buildLabel('Status'),
          const SizedBox(height: 8),
          _buildStatusSelector(),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              // Tambah & Lanjut
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save(andContinue: true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah & Lanjut', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Simpan
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : () => _save(),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(
                    _saving ? 'Menyimpan...' : 'Simpan',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _typeIcon(String type) {
    IconData icon;
    switch (type) {
      case 'manga':
        icon = Icons.auto_stories;
        break;
      case 'manhua':
        icon = Icons.menu_book;
        break;
      default:
        icon = Icons.chrome_reader_mode;
        break;
    }
    return Icon(icon, size: 16, color: AppTheme.textSecondary);
  }

  Widget _buildStatusSelector() {
    final statuses = [
      ('reading', 'Membaca', AppTheme.reading),
      ('plan', 'Rencana', AppTheme.planToRead),
      ('completed', 'Selesai', AppTheme.completed),
      ('hold', 'Ditahan', AppTheme.onHold),
      ('dropped', 'Dropped', AppTheme.dropped),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((s) {
        final selected = _selectedStatus == s.$1;
        final color = s.$3;
        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = s.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.15) : AppTheme.surface1,
              border: Border.all(
                color: selected ? color : AppTheme.border,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? color : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  s.$2,
                  style: TextStyle(
                    color: selected ? color : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
