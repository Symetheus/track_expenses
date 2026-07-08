import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/project_path.dart';

/// Mémorise les associations marchand → catégorie choisies par l'utilisateur.
class MerchantMemoryService extends ChangeNotifier {
  static const _fileName = 'merchant_categories.json';

  Map<String, String> _memory = {};

  Map<String, String> get allMappings => Map.unmodifiable(_memory);
  int get count => _memory.length;

  Future<void> load() async {
    try {
      final file = await ProjectPath.file(_fileName);
      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        final Map<String, dynamic> decoded = jsonDecode(content);
        _memory = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      debugPrint('[MerchantMemory] Erreur chargement : $e');
    }
  }

  String? getCategory(String merchantName) {
    if (merchantName.isEmpty) return null;
    final key = _normalize(merchantName);
    if (_memory.containsKey(key)) return _memory[key];
    for (final entry in _memory.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) return entry.value;
    }
    return null;
  }

  String? getCategoryForExpense({required String cleanName, required String rawLabel}) =>
      getCategory(cleanName) ?? getCategory(rawLabel);

  Future<void> saveCategory(String merchantName, String category) async {
    if (merchantName.isEmpty || category.isEmpty) return;
    final key = _normalize(merchantName);
    if (_memory[key] == category) return;
    _memory[key] = category;
    await _persist();
    notifyListeners();
  }

  Future<void> removeEntry(String merchantName) async {
    if (_memory.remove(_normalize(merchantName)) != null) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final file = await ProjectPath.file(_fileName);
      final sorted = Map.fromEntries(_memory.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(sorted), encoding: utf8);
    } catch (e) {
      debugPrint('[MerchantMemory] Erreur sauvegarde : $e');
    }
  }

  static String _normalize(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'\s+\d+$'), '');
}
