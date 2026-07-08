import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/expense.dart';

/// Service pour envoyer les dépenses directement dans une base Notion.
/// Docs : https://developers.notion.com/reference/post-page
class NotionService {
  static const String _baseUrl = 'https://api.notion.com/v1';
  static const String _notionVersion = '2022-06-28';

  final String token;
  final String databaseId;
  final NotionColumns columns;

  NotionService({
    required this.token,
    required this.databaseId,
    NotionColumns? columns,
  }) : columns = columns ?? const NotionColumns();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Notion-Version': _notionVersion,
      };

  /// Teste la connexion à Notion (vérifie que la DB est accessible).
  Future<void> testConnection() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/databases/$databaseId'),
      headers: _headers,
    );
    if (!_isSuccess(response.statusCode)) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Erreur Notion (${response.statusCode})');
    }
  }

  /// Envoie une dépense dans la base Notion.
  Future<void> addExpense(Expense expense) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/pages'),
      headers: _headers,
      body: jsonEncode(_buildPageBody(expense)),
    );
    if (!_isSuccess(response.statusCode)) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Erreur lors de l\'ajout (${response.statusCode})');
    }
  }

  /// Envoie toutes les dépenses de la liste (sans filtrage — la sélection
  /// est de la responsabilité de l'appelant).
  Future<int> addAllExpenses(
    List<Expense> expenses, {
    void Function(int sent, int total)? onProgress,
  }) async {
    int sent = 0;
    for (final expense in expenses) {
      await addExpense(expense);
      sent++;
      onProgress?.call(sent, expenses.length);
    }
    return sent;
  }

  /// Récupère toutes les entrées de la base Notion (avec pagination automatique).
  /// Retourne uniquement les entrées qui ont un champ Date valide.
  Future<List<Expense>> queryAllExpenses({int maxPages = 20}) async {
    final List<Expense> results = [];
    String? cursor;
    int page = 0;

    do {
      final body = <String, dynamic>{
        'page_size': 100,
        'sorts': [
          {'property': columns.date, 'direction': 'descending'},
        ],
      };
      if (cursor != null) body['start_cursor'] = cursor;

      final response = await http.post(
        Uri.parse('$_baseUrl/databases/$databaseId/query'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (!_isSuccess(response.statusCode)) {
        final b = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(b['message'] ?? 'Erreur Notion (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = data['results'] as List<dynamic>;

      for (final p in pages) {
        final expense = _parsePageToExpense(p as Map<String, dynamic>);
        if (expense != null) results.add(expense);
      }

      final hasMore = data['has_more'] as bool? ?? false;
      cursor = hasMore ? data['next_cursor'] as String? : null;
      page++;
    } while (cursor != null && page < maxPages);

    return results;
  }

  /// Parse une page Notion en Expense. Retourne null si les données sont invalides.
  Expense? _parsePageToExpense(Map<String, dynamic> page) {
    try {
      final props = page['properties'] as Map<String, dynamic>;

      // Nom
      final nameProp = props[columns.name] as Map<String, dynamic>?;
      final titleList = nameProp?['title'] as List?;
      final name = (titleList?.isNotEmpty == true)
          ? ((titleList!.first as Map)['plain_text'] as String? ?? '')
          : '';

      // Date
      final dateProp = props[columns.date] as Map<String, dynamic>?;
      final dateStr = (dateProp?['date'] as Map?)?['start'] as String?;
      if (dateStr == null) return null;
      final date = DateTime.parse(dateStr);

      // Montant
      final amountProp = props[columns.amount] as Map<String, dynamic>?;
      final amount = (amountProp?['number'] as num?)?.toDouble() ?? 0.0;

      // Catégorie
      final catProp = props[columns.category] as Map<String, dynamic>?;
      final category = (catProp?['select'] as Map?)?['name'] as String?;

      // Moyen de paiement
      final payProp = props[columns.paymentMethod] as Map<String, dynamic>?;
      final paymentMethod =
          (payProp?['select'] as Map?)?['name'] as String? ?? '';

      return Expense(
        id: page['id'] as String,
        rawLabel: name,
        cleanName: name,
        date: date,
        amount: amount,
        category: category?.isNotEmpty == true ? category : null,
        paymentMethod: paymentMethod,
        isReviewed: true,
        sentToNotion: true,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic> _buildPageBody(Expense expense) => {
        'parent': {'database_id': databaseId},
        'properties': {
          columns.name: {
            'title': [
              {'text': {'content': expense.cleanName}}
            ]
          },
          columns.date: {
            'date': {'start': _toIsoDate(expense.date)}
          },
          columns.amount: {'number': expense.amount},
          columns.category: {
            'select': {'name': expense.category ?? ''}
          },
          columns.paymentMethod: {
            'select': {'name': expense.paymentMethod}
          },
        },
      };

  String _toIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
