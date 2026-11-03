import 'dart:convert';

/// Metadata backup file (index.json).
class BackupIndex {
  final int version;
  final String appName;
  final int createdAt;
  final int totalComics;
  final List<String> sections;

  BackupIndex({
    required this.version,
    required this.appName,
    required this.createdAt,
    required this.totalComics,
    required this.sections,
  });

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'appName': appName,
      'createdAt': createdAt,
      'totalComics': totalComics,
      'sections': sections,
    };
  }

  factory BackupIndex.fromMap(Map<String, dynamic> map) {
    return BackupIndex(
      version: map['version'] as int? ?? 1,
      appName: map['appName'] as String? ?? 'Manga Tracker',
      createdAt: map['createdAt'] as int? ?? 0,
      totalComics: map['totalComics'] as int? ?? 0,
      sections: List<String>.from(map['sections'] as List? ?? []),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BackupIndex.fromJson(String source) =>
      BackupIndex.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
