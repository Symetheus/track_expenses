import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/expense.dart';
import '../services/notion_service.dart';

enum AnalyticsLoadState { idle, loading, success, error }

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsLoadState _state = AnalyticsLoadState.idle;
  List<Expense> _expenses = [];
  String _errorMessage = '';
  int? _selectedYear;

  AnalyticsLoadState get state => _state;
  String get errorMessage => _errorMessage;
  int? get selectedYear => _selectedYear;

  // Toutes les dépenses (montants positifs ou négatifs, on prend la valeur absolue)
  List<Expense> get _debits => _expenses.where((e) => e.amount != 0).toList();

  List<int> get availableYears {
    final years = _debits.map((e) => e.date.year).toSet().toList()..sort((a, b) => b.compareTo(a));
    return years;
  }

  List<Expense> get filteredExpenses {
    if (_selectedYear == null) return _debits;
    return _debits.where((e) => e.date.year == _selectedYear).toList();
  }

  /// Totaux mensuels sur toutes les années — clé : "YYYY-MM"
  Map<String, double> get monthlyTotals {
    final map = <String, double>{};
    for (final e in _debits) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + e.amount.abs();
    }
    return map;
  }

  /// Totaux par catégorie sur la période filtrée
  Map<String, double> get categoryTotals {
    final map = <String, double>{};
    for (final e in filteredExpenses) {
      final cat = (e.category?.isNotEmpty == true) ? e.category! : 'Autre';
      map[cat] = (map[cat] ?? 0) + e.amount.abs();
    }
    return map;
  }

  double get totalSpending => filteredExpenses.fold(0.0, (s, e) => s + e.amount.abs());

  int get transactionCount => filteredExpenses.length;

  String? get topCategory {
    if (categoryTotals.isEmpty) return null;
    return categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Charge les données depuis Notion
  Future<void> fetchFromNotion(AppSettings settings) async {
    _state = AnalyticsLoadState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final service = NotionService(
        token: settings.notionToken,
        databaseId: settings.notionDatabaseId,
        columns: settings.notionColumns,
      );
      _expenses = await service.queryAllExpenses();

      // Sélectionner l'année la plus récente par défaut
      if (_selectedYear == null && availableYears.isNotEmpty) {
        _selectedYear = availableYears.first;
      }
      _state = AnalyticsLoadState.success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _state = AnalyticsLoadState.error;
    }
    notifyListeners();
  }

  void setSelectedYear(int? year) {
    _selectedYear = year;
    notifyListeners();
  }
}
