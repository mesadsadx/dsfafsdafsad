class KeyDictionary {
  final Map<String, String> entries;

  const KeyDictionary({required this.entries});

  String nameFor(String code) => entries[code] ?? code;
  bool get isEmpty => entries.isEmpty;

  List<MapEntry<String, String>> get sortedEntries =>
      entries.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(entries);

  factory KeyDictionary.fromMap(Map<String, dynamic> map) =>
      KeyDictionary(entries: map.map((k, v) => MapEntry(k, v as String)));

  static const empty = KeyDictionary(entries: {});
}
