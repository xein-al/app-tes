import 'dart:convert';
import 'package:flutter/material.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum ComicStatus { reading, plan, completed, hold, dropped }

enum ComicType { manga, manhwa, manhua }

extension ComicStatusX on ComicStatus {
  String get key {
    switch (this) {
      case ComicStatus.reading:   return 'reading';
      case ComicStatus.plan:      return 'plan';
      case ComicStatus.completed: return 'completed';
      case ComicStatus.hold:      return 'hold';
      case ComicStatus.dropped:   return 'dropped';
    }
  }

  String get label {
    switch (this) {
      case ComicStatus.reading:   return 'Membaca';
      case ComicStatus.plan:      return 'Rencana';
      case ComicStatus.completed: return 'Selesai';
      case ComicStatus.hold:      return 'Ditahan';
      case ComicStatus.dropped:   return 'Dropped';
    }
  }

  Color get color {
    switch (this) {
      case ComicStatus.reading:   return const Color(0xFF38BDF8);
      case ComicStatus.plan:      return const Color(0xFFFBBF24);
      case ComicStatus.completed: return const Color(0xFF34D399);
      case ComicStatus.hold:      return const Color(0xFF94A3B8);
      case ComicStatus.dropped:   return const Color(0xFF94A3B8);
    }
  }
}

extension ComicTypeX on ComicType {
  String get key {
    switch (this) {
      case ComicType.manga:   return 'manga';
      case ComicType.manhwa:  return 'manhwa';
      case ComicType.manhua:  return 'manhua';
    }
  }

  String get label {
    switch (this) {
      case ComicType.manga:   return 'Manga';
      case ComicType.manhwa:  return 'Manhwa';
      case ComicType.manhua:  return 'Manhua';
    }
  }
}

// ─── Model ───────────────────────────────────────────────────────────────────

class Comic {
  final String id;
  final String title;
  final String? alias;
  final String type;     // raw string as stored in DB: 'manga'|'manhwa'|'manhua'
  final String? coverUrl;
  final double currentChapter;
  final double? totalChapters;
  final String status;   // raw string: 'reading'|'plan'|'completed'|'hold'|'dropped'
  final double? rating;
  final String? notes;
  final int createdAt;   // epoch ms
  final int updatedAt;   // epoch ms

  const Comic({
    required this.id,
    required this.title,
    this.alias,
    this.type = 'manhwa',
    this.coverUrl,
    this.currentChapter = 0,
    this.totalChapters,
    this.status = 'reading',
    this.rating,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  ComicStatus get comicStatus {
    switch (status) {
      case 'reading':   return ComicStatus.reading;
      case 'plan':      return ComicStatus.plan;
      case 'completed': return ComicStatus.completed;
      case 'hold':      return ComicStatus.hold;
      case 'dropped':   return ComicStatus.dropped;
      default:          return ComicStatus.reading;
    }
  }

  ComicType get comicType {
    switch (type) {
      case 'manga':   return ComicType.manga;
      case 'manhwa':  return ComicType.manhwa;
      case 'manhua':  return ComicType.manhua;
      default:        return ComicType.manhwa;
    }
  }

  double get progressPercent {
    if (totalChapters == null || totalChapters == 0) return 0.0;
    return (currentChapter / totalChapters!).clamp(0.0, 1.0);
  }

  Color get statusColor => comicStatus.color;
  String get statusLabel => comicStatus.label;
  String get typeLabel   => comicType.label;

  // ── copyWith ────────────────────────────────────────────────────────────────

  Comic copyWith({
    String? id,
    String? title,
    String? alias,
    String? type,
    String? coverUrl,
    double? currentChapter,
    double? totalChapters,
    String? status,
    double? rating,
    String? notes,
    int?    createdAt,
    int?    updatedAt,
  }) {
    return Comic(
      id:             id             ?? this.id,
      title:          title          ?? this.title,
      alias:          alias          ?? this.alias,
      type:           type           ?? this.type,
      coverUrl:       coverUrl       ?? this.coverUrl,
      currentChapter: currentChapter ?? this.currentChapter,
      totalChapters:  totalChapters  ?? this.totalChapters,
      status:         status         ?? this.status,
      rating:         rating         ?? this.rating,
      notes:          notes          ?? this.notes,
      createdAt:      createdAt      ?? this.createdAt,
      updatedAt:      updatedAt      ?? this.updatedAt,
    );
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id':              id,
    'title':           title,
    'alias':           alias,
    'type':            type,
    'cover_url':       coverUrl,
    'current_chapter': currentChapter,
    'total_chapters':  totalChapters,
    'status':          status,
    'rating':          rating,
    'notes':           notes,
    'created_at':      createdAt,
    'updated_at':      updatedAt,
  };

  factory Comic.fromMap(Map<String, dynamic> map) => Comic(
    id:             map['id']              as String,
    title:          map['title']           as String,
    alias:          map['alias']           as String?,
    type:           (map['type']           as String?) ?? 'manhwa',
    coverUrl:       map['cover_url']       as String?,
    currentChapter: (map['current_chapter'] as num?)?.toDouble() ?? 0,
    totalChapters:  (map['total_chapters']  as num?)?.toDouble(),
    status:         (map['status']          as String?) ?? 'reading',
    rating:         (map['rating']          as num?)?.toDouble(),
    notes:          map['notes']           as String?,
    createdAt:      map['created_at']      as int,
    updatedAt:      map['updated_at']      as int,
  );

  /// Returns a JSON string of a list of Comics (used by tests).
  static String toJson(List<Comic> comics) =>
      jsonEncode(comics.map((c) => c.toMap()).toList());
}
