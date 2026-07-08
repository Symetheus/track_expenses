import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../utils/project_path.dart';

class SettingsProvider extends ChangeNotifier {
  static const _fileName = 'settings.json';

  AppSettings _settings = AppSettings();
  bool _isLoaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  Future<void> _persist() async {
    try {
      final file = await ProjectPath.file(_fileName);
      final data = {
        'notion_token': _settings.notionToken,
        'notion_database_id': _settings.notionDatabaseId,
        'columns': {
          'name': _settings.notionColumns.name,
          'date': _settings.notionColumns.date,
          'amount': _settings.notionColumns.amount,
          'category': _settings.notionColumns.category,
          'payment_method': _settings.notionColumns.paymentMethod,
        },
        'categories': _settings.categories,
        'payment_methods': _settings.paymentMethods,
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        encoding: utf8,
      );
    } catch (e) {
      debugPrint('[Settings] Erreur sauvegarde : $e');
    }
  }

  Future<void> load() async {
    try {
      final file = await ProjectPath.file(_fileName);
      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        final Map<String, dynamic> data = jsonDecode(content);
        final cols = data['columns'] as Map<String, dynamic>? ?? {};
        _settings = AppSettings(
          notionToken: data['notion_token'] as String? ?? '',
          notionDatabaseId: data['notion_database_id'] as String? ?? '',
          notionColumns: NotionColumns(
            name:          cols['name']           as String? ?? 'Dépense',
            date:          cols['date']           as String? ?? 'Date',
            amount:        cols['amount']         as String? ?? 'Montant',
            category:      cols['category']       as String? ?? 'Catégorie',
            paymentMethod: cols['payment_method'] as String? ?? 'Moyen de paiement',
          ),
          categories: (data['categories'] as List?)?.cast<String>() ?? AppSettings.defaultCategories,
          paymentMethods: (data['payment_methods'] as List?)?.cast<String>() ?? AppSettings.defaultPaymentMethods,
        );
      }
    } catch (e) {
      debugPrint('[Settings] Erreur chargement : $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateNotionConfig({required String token, required String databaseId}) async {
    _settings = _settings.copyWith(notionToken: token, notionDatabaseId: databaseId);
    await _persist();
    notifyListeners();
  }

  Future<void> updateNotionColumns(NotionColumns columns) async {
    _settings = _settings.copyWith(notionColumns: columns);
    await _persist();
    notifyListeners();
  }

  Future<void> addCategory(String category) async {
    if (_settings.categories.contains(category)) return;
    _settings = _settings.copyWith(categories: [..._settings.categories, category]);
    await _persist();
    notifyListeners();
  }

  Future<void> removeCategory(String category) async {
    _settings = _settings.copyWith(
      categories: _settings.categories.where((c) => c != category).toList(),
    );
    await _persist();
    notifyListeners();
  }
}
