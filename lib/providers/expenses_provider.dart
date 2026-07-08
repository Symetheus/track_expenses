import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/import_record.dart';
import '../services/csv_parser_service.dart';
import '../services/merchant_memory_service.dart';
import '../services/notion_service.dart';
import '../services/import_history_service.dart';

enum LoadingState { idle, loading, success, error }

class ExpensesProvider extends ChangeNotifier {
  final MerchantMemoryService _memory;
  final ImportHistoryService _importHistory;

  ExpensesProvider(this._memory, this._importHistory);

  List<Expense> _expenses = [];
  LoadingState _state = LoadingState.idle;
  String _errorMessage = '';
  String? _activeImportId;
  String? _importedFileName;
  int _notionProgress = 0;
  int _notionTotal = 0;

  List<Expense> get expenses => _expenses;
  LoadingState get state => _state;
  String get errorMessage => _errorMessage;
  String? get importedFileName => _importedFileName;
  int get notionProgress => _notionProgress;
  int get notionTotal => _notionTotal;

  int get totalCount => _expenses.length;
  int get reviewedCount => _expenses.where((e) => e.isProcessed).length;
  int get completeCount => _expenses.where((e) => e.isComplete && !e.sentToNotion).length;
  int get sentCount => _expenses.where((e) => e.sentToNotion).length;
  int get ignoredCount => _expenses.where((e) => e.isIgnored).length;
  bool get allReviewed => _expenses.isNotEmpty && _expenses.every((e) => e.isProcessed);

  /// Restaure un import depuis l'historique.
  Future<void> restoreFromRecord(ImportRecord record) async {
    _expenses = List.from(record.expenses);
    _importedFileName = record.originalFileName;
    _activeImportId = record.id;
    _state = LoadingState.success;
    notifyListeners();
  }

  /// Import depuis un fichier CSV SG.
  Future<void> importFromFile(String filePath) async {
    _state = LoadingState.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final parsed = await CsvParserService.parseFile(filePath);
      _expenses = parsed.map((e) {
        final learned = _memory.getCategoryForExpense(cleanName: e.cleanName, rawLabel: e.rawLabel);
        return learned != null ? e.copyWith(category: learned) : e;
      }).toList();
      _importedFileName = filePath.split('/').last;
      _state = LoadingState.success;

      // Créer l'entrée dans l'historique + copier le CSV
      final record = await _importHistory.addImport(csvSourcePath: filePath, expenses: _expenses);
      _activeImportId = record.id;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _state = LoadingState.error;
      _expenses = [];
    }
    notifyListeners();
  }

  /// Met à jour une dépense et persiste dans l'historique.
  Future<void> updateExpense(
    String id, {
    String? cleanName,
    String? category,
    String? paymentMethod,
    bool? isReviewed,
  }) async {
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final updated = _expenses[idx].copyWith(
      cleanName: cleanName,
      category: category,
      paymentMethod: paymentMethod,
      isReviewed: isReviewed,
    );
    _expenses[idx] = updated;

    // Mémoriser l'association marchand → catégorie si validé
    if ((isReviewed ?? false) && updated.category != null && updated.cleanName.isNotEmpty) {
      await _memory.saveCategory(updated.cleanName, updated.category!);
    }

    // Persister dans l'historique
    if (_activeImportId != null) {
      await _importHistory.updateExpenses(_activeImportId!, _expenses);
    }
    notifyListeners();
  }

  /// Bascule l'état ignoré d'une dépense.
  Future<void> toggleIgnore(String id) async {
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _expenses[idx] = _expenses[idx].copyWith(isIgnored: !_expenses[idx].isIgnored);
    if (_activeImportId != null) {
      await _importHistory.updateExpenses(_activeImportId!, _expenses);
    }
    notifyListeners();
  }

  /// Envoie uniquement les dépenses complètes et pas encore envoyées vers Notion.
  Future<int> exportToNotion(NotionService service) async {
    _notionProgress = 0;
    _notionTotal = 0;
    notifyListeners();

    // Filtrer : complètes ET pas encore envoyées
    final toSend = _expenses.where((e) => e.isComplete && !e.sentToNotion).toList();

    final count = await service.addAllExpenses(
      toSend,
      onProgress: (sent, total) {
        _notionProgress = sent;
        _notionTotal = total;
        notifyListeners();
      },
    );

    // Marquer les dépenses envoyées
    for (final sent in toSend) {
      final idx = _expenses.indexWhere((e) => e.id == sent.id);
      if (idx != -1) _expenses[idx] = _expenses[idx].copyWith(sentToNotion: true);
    }

    // Persister l'état mis à jour
    if (_activeImportId != null) {
      await _importHistory.updateExpenses(_activeImportId!, _expenses);
    }
    notifyListeners();
    return count;
  }

  /// Remet l'état initial (sans toucher à l'historique).
  Future<void> reset() async {
    _expenses = [];
    _state = LoadingState.idle;
    _errorMessage = '';
    _importedFileName = null;
    _activeImportId = null;
    notifyListeners();
  }
}
