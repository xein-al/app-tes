import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_tracker/models/comic.dart';

void main() {
  test('Comic serialization and increment self-check', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final comic = Comic(
      id: '1',
      title: 'Solo Leveling',
      alias: 'Na Honjaman Rebeleob',
      type: 'manhwa',
      currentChapter: 10,
      totalChapters: 179,
      status: 'reading',
      rating: 5.0,
      notes: 'Bagus banget',
      createdAt: now,
      updatedAt: now,
    );

    // Map serialization
    final map = comic.toMap();
    assert(map['id'] == '1', 'ID must match');
    assert(map['title'] == 'Solo Leveling', 'Title must match');
    assert(map['type'] == 'manhwa', 'Type must match');
    assert(map['current_chapter'] == 10.0, 'Chapter must be 10');

    // Deserialization
    final deserialized = Comic.fromMap(map);
    assert(deserialized.id == comic.id, 'Deserialized ID must match');
    assert(deserialized.currentChapter == 10.0, 'Deserialized chapter must match');

    // Increment
    final updated = deserialized.copyWith(currentChapter: deserialized.currentChapter + 1);
    assert(updated.currentChapter == 11.0, 'Incremented chapter must be 11');

    // JSON export check
    final jsonList = Comic.toJson([comic, updated]);
    final decoded = jsonDecode(jsonList) as List;
    assert(decoded.length == 2, 'Export list must contain 2 items');
  });
}
