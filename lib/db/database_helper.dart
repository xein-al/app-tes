import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/comic.dart';

enum ComicSortOption {
  lastUpdated,
  titleAZ,
  progress,
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('comics_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE comics (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        alias TEXT,
        type TEXT CHECK(type IN ('manga','manhwa','manhua')) DEFAULT 'manhwa',
        cover_url TEXT,
        current_chapter REAL DEFAULT 0,
        total_chapters REAL,
        status TEXT CHECK(status IN ('reading','plan','completed','hold','dropped')) DEFAULT 'reading',
        rating REAL,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  // ─── CRUD ──────────────────────────────────────────────────────────────────

  Future<int> insertComic(Comic comic) async {
    final db = await database;
    return await db.insert(
      'comics',
      comic.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateComic(Comic comic) async {
    final db = await database;
    final map = comic.toMap();
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'comics',
      map,
      where: 'id = ?',
      whereArgs: [comic.id],
    );
  }

  Future<int> deleteComic(String id) async {
    final db = await database;
    return await db.delete(
      'comics',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Comic?> getComic(String id) async {
    final db = await database;
    final maps = await db.query(
      'comics',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Comic.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Comic>> getAllComics() async {
    final db = await database;
    final result = await db.query('comics', orderBy: 'updated_at DESC');
    return result.map((m) => Comic.fromMap(m)).toList();
  }

  Future<List<Comic>> getComics({
    String? status,
    String? searchQuery,
    ComicSortOption sortOption = ComicSortOption.lastUpdated,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (status != null && status != 'all') {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(title LIKE ? OR alias LIKE ?)');
      final query = '%${searchQuery.trim()}%';
      whereArgs.add(query);
      whereArgs.add(query);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    String orderBy;
    switch (sortOption) {
      case ComicSortOption.titleAZ:
        orderBy = 'title COLLATE NOCASE ASC';
        break;
      case ComicSortOption.progress:
        // Handled in-memory for precision or fallback to updated_at
        orderBy = 'updated_at DESC';
        break;
      case ComicSortOption.lastUpdated:
      default:
        orderBy = 'updated_at DESC';
        break;
    }

    final result = await db.query(
      'comics',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );

    var list = result.map((json) => Comic.fromMap(json)).toList();

    if (sortOption == ComicSortOption.progress) {
      list.sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    }

    return list;
  }

  // ─── Chapter Operations ───────────────────────────────────────────────────

  /// Increments chapter by 1 and auto-completes status if currentChapter >= totalChapters.
  Future<Comic?> incrementChapter(String id) async {
    final comic = await getComic(id);
    if (comic == null) return null;

    final newChapter = comic.currentChapter + 1;
    final bool isCompleted = comic.totalChapters != null &&
        comic.totalChapters! > 0 &&
        newChapter >= comic.totalChapters!;

    final updated = comic.copyWith(
      currentChapter: newChapter,
      status: isCompleted ? 'completed' : comic.status,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await updateComic(updated);
    return updated;
  }

  /// Decrements chapter by 1 (minimum 0).
  Future<Comic?> decrementChapter(String id) async {
    final comic = await getComic(id);
    if (comic == null) return null;

    final newChapter = (comic.currentChapter - 1).clamp(0.0, double.infinity);
    final updated = comic.copyWith(
      currentChapter: newChapter,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await updateComic(updated);
    return updated;
  }

  /// Updates chapter directly to a specified value.
  Future<Comic?> setChapter(String id, double chapter) async {
    final comic = await getComic(id);
    if (comic == null) return null;

    final double validChapter = chapter < 0 ? 0 : chapter;
    final bool isCompleted = comic.totalChapters != null &&
        comic.totalChapters! > 0 &&
        validChapter >= comic.totalChapters!;

    final updated = comic.copyWith(
      currentChapter: validChapter,
      status: isCompleted ? 'completed' : comic.status,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await updateComic(updated);
    return updated;
  }

  // ─── Status Counts ────────────────────────────────────────────────────────

  Future<Map<String, int>> getStatusCounts() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM comics 
      GROUP BY status
    ''');

    final counts = <String, int>{
      'all': 0,
      'reading': 0,
      'plan': 0,
      'completed': 0,
      'hold': 0,
      'dropped': 0,
    };

    int total = 0;
    for (final row in result) {
      final status = (row['status'] as String).toLowerCase();
      final count = (row['count'] as num).toInt();
      counts[status] = count;
      total += count;
    }
    counts['all'] = total;

    return counts;
  }

  // ─── Reading Streak ───────────────────────────────────────────────────────

  Future<int> getReadingStreak() async {
    final db = await database;
    final results = await db.rawQuery('SELECT updated_at FROM comics ORDER BY updated_at DESC');
    if (results.isEmpty) return 0;

    final dates = <DateTime>{};
    for (final row in results) {
      final ms = row['updated_at'] as int?;
      if (ms != null && ms > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        dates.add(DateTime(dt.year, dt.month, dt.day));
      }
    }

    if (dates.isEmpty) return 0;

    final today = DateTime.now();
    var checkDate = DateTime(today.year, today.month, today.day);

    // If no updates today, check if yesterday had updates
    if (!dates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (!dates.contains(checkDate)) {
        return 0;
      }
    }

    int streak = 0;
    while (dates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;

    final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM comics');
    final totalComics = (totalResult.first['total'] as num?)?.toInt() ?? 0;

    final chaptersResult = await db.rawQuery('SELECT SUM(current_chapter) as total_chapters FROM comics');
    final totalChaptersRead = (chaptersResult.first['total_chapters'] as num?)?.toDouble() ?? 0.0;

    final double avgChaptersPerComic = totalComics > 0 ? (totalChaptersRead / totalComics) : 0.0;

    final streak = await getReadingStreak();

    final typeResult = await db.rawQuery('''
      SELECT type, COUNT(*) as count 
      FROM comics 
      GROUP BY type
    ''');
    final typeDistribution = <String, int>{'manga': 0, 'manhwa': 0, 'manhua': 0};
    for (final row in typeResult) {
      final t = (row['type'] as String).toLowerCase();
      if (typeDistribution.containsKey(t)) {
        typeDistribution[t] = (row['count'] as num).toInt();
      }
    }

    final statusResult = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM comics 
      GROUP BY status
    ''');
    final statusDistribution = <String, int>{
      'reading': 0,
      'plan': 0,
      'completed': 0,
      'hold': 0,
      'dropped': 0,
    };
    for (final row in statusResult) {
      final s = (row['status'] as String).toLowerCase();
      if (statusDistribution.containsKey(s)) {
        statusDistribution[s] = (row['count'] as num).toInt();
      }
    }

    return {
      'totalComics': totalComics,
      'totalChaptersRead': totalChaptersRead,
      'avgChaptersPerComic': avgChaptersPerComic,
      'readingStreak': streak,
      'typeDistribution': typeDistribution,
      'statusDistribution': statusDistribution,
    };
  }

  // ─── Export & Backup ───────────────────────────────────────────────────────

  Future<String> exportToJsonString() async {
    final db = await database;
    final records = await db.query('comics', orderBy: 'title ASC');
    final comics = records.map((m) => Comic.fromMap(m)).toList();

    final data = {
      'version': 1,
      'appName': 'Manga Tracker',
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'totalCount': comics.length,
      'comics': comics.map((c) => c.toMap()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  Future<String> exportToJsonFile() async {
    final jsonString = await exportToJsonString();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/manga_backup_$timestamp.json');
    await file.writeAsString(jsonString);
    return file.path;
  }

  // ─── Import & Restore ───────────────────────────────────────────────────────

  Future<int> importFromJsonString(String jsonString, {bool replaceExisting = false}) async {
    final dynamic decoded = jsonDecode(jsonString);
    List<dynamic> comicMaps = [];

    if (decoded is List) {
      comicMaps = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['comics'] is List) {
      comicMaps = decoded['comics'] as List<dynamic>;
    } else {
      throw const FormatException('Format data backup tidak valid.');
    }

    if (comicMaps.isEmpty) return 0;

    final db = await database;
    int importedCount = 0;

    await db.transaction((txn) async {
      if (replaceExisting) {
        await txn.delete('comics');
      }

      final batch = txn.batch();
      for (final item in comicMaps) {
        if (item is Map<String, dynamic>) {
          try {
            final comic = Comic.fromMap(item);
            batch.insert(
              'comics',
              comic.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            importedCount++;
          } catch (_) {
            // Abaikan item yang korup
          }
        }
      }
      await batch.commit(noResult: true);
    });

    return importedCount;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('comics');
  }
}
