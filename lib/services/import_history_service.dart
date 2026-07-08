import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/import_record.dart';
import '../utils/project_path.dart';

/// Gère l'historique de tous les fichiers CSV importés.
/// - `import_history.json` à la racine du projet
/// - Copie de chaque CSV dans `imports/`
class ImportHistoryService extends ChangeNotifier {
  static const _historyFileName = 'import_history.json';
  static const _importsFolder = 'imports';

  List<ImportRecord> _history = [];

  List<ImportRecord> get history =>
      [..._history]..sort((a, b) => b.importedAt.compareTo(a.importedAt));

  Future<void> load() async {
    try {
      final file = await ProjectPath.file(_historyFileName);
      if (!await file.exists()) return;
      final content = await file.readAsString(encoding: utf8);
      final List<dynamic> list = jsonDecode(content);
      _history = list
          .map((e) => ImportRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[ImportHistory] Erreur chargement : $e');
    }
  }

  Future<ImportRecord> addImport({
    required String csvSourcePath,
    required List<Expense> expenses,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final originalFileName = csvSourcePath.split('/').last;
    final backupRelativePath = '$_importsFolder/${id}_$originalFileName';

    // Copier le CSV dans imports/
    try {
      final projectDir = await ProjectPath.projectDir;
      final importsDir = Directory('${projectDir.path}/$_importsFolder');
      if (!await importsDir.exists()) await importsDir.create(recursive: true);
      final src = File(csvSourcePath);
      if (await src.exists()) {
        await src.copy('${projectDir.path}/$backupRelativePath');
      }
    } catch (e) {
      debugPrint('[ImportHistory] Copie CSV échouée : $e');
    }

    final record = ImportRecord(
      id: id,
      originalFileName: originalFileName,
      csvBackupRelativePath: backupRelativePath,
      importedAt: DateTime.now(),
      expenses: expenses,
    );
    _history.add(record);
    await _save();
    notifyListeners();
    return record;
  }

  Future<void> updateExpenses(String id, List<Expense> expenses) async {
    final idx = _history.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _history[idx] = _history[idx].copyWith(expenses: expenses);
    await _save();
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    await _deleteBackupCsv(id);
    _history.removeWhere((r) => r.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> _deleteBackupCsv(String id) async {
    try {
      final record = _history.firstWhere((r) => r.id == id);
      final projectDir = await ProjectPath.projectDir;
      final f = File('${projectDir.path}/${record.csvBackupRelativePath}');
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[ImportHistory] Suppression CSV échouée : $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = await ProjectPath.file(_historyFileName);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          _history.map((r) => r.toJson()).toList(),
        ),
        encoding: utf8,
      );
    } catch (e) {
      debugPrint('[ImportHistory] Erreur sauvegarde : $e');
    }
  }
}
