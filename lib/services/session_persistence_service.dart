// DEPRECATED — Plus utilisé depuis l'introduction de ImportHistoryService.
// Ce fichier peut être supprimé manuellement.
// ignore_for_file: unused_element
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';

/// Persiste la session de révision en cours dans un fichier JSON.
/// Permet de reprendre là où on s'était arrêté après un redémarrage.
class SessionPersistenceService {
  static const _fileName = 'current_session.json';

  Future<void> save(List<Expense> expenses, String? fileName) async {
    try {
      final file = await _getFile();
      final data = {
        'fileName': fileName,
        'savedAt': DateTime.now().toIso8601String(),
        'expenses': expenses.map(_expenseToJson).toList(),
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        encoding: utf8,
      );
    } catch (e) {
      debugPrint('[Session] Erreur sauvegarde : $e');
    }
  }

  Future<SavedSession?> load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString(encoding: utf8);
      final Map<String, dynamic> data = jsonDecode(content);
      final expenses = (data['expenses'] as List)
          .map((e) => _expenseFromJson(e as Map<String, dynamic>))
          .toList();
      if (expenses.isEmpty) return null;
      return SavedSession(
        fileName: data['fileName'] as String?,
        savedAt: DateTime.parse(data['savedAt'] as String),
        expenses: expenses,
      );
    } catch (e) {
      debugPrint('[Session] Erreur chargement : $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final file = await _getFile();
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[Session] Erreur suppression : $e');
    }
  }

  Future<File> _getFile() async {
    final executableDir = File(Platform.resolvedExecutable).parent;
    Directory dir = executableDir;
    while (!File('${dir.path}/pubspec.yaml').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) {
        dir = Directory.current;
        break;
      }
      dir = parent;
    }
    return File('${dir.path}/$_fileName');
  }

  Map<String, dynamic> _expenseToJson(Expense e) => {
        'id': e.id,
        'rawLabel': e.rawLabel,
        'cleanName': e.cleanName,
        'date': e.date.toIso8601String(),
        'amount': e.amount,
        'category': e.category,
        'paymentMethod': e.paymentMethod,
        'isReviewed': e.isReviewed,
      };

  Expense _expenseFromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        rawLabel: j['rawLabel'] as String,
        cleanName: j['cleanName'] as String,
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String?,
        paymentMethod: j['paymentMethod'] as String,
        isReviewed: j['isReviewed'] as bool,
      );
}

class SavedSession {
  final String? fileName;
  final DateTime savedAt;
  final List<Expense> expenses;

  SavedSession({
    required this.fileName,
    required this.savedAt,
    required this.expenses,
  });

  int get reviewedCount => expenses.where((e) => e.isReviewed).length;
  int get totalCount => expenses.length;
}
