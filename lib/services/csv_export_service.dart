import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/app_settings.dart';
import '../models/expense.dart';

class CsvExportService {
  /// Génère le contenu CSV en utilisant les noms de colonnes configurés dans Notion.
  static String generateCsvContent(
    List<Expense> expenses,
    NotionColumns columns,
  ) {
    final rows = <List<dynamic>>[
      [columns.name, columns.date, columns.amount, columns.category, columns.paymentMethod],
    ];
    for (final expense in expenses) {
      rows.add([
        expense.cleanName,
        expense.formattedDate,
        _formatAmount(expense.amount),
        expense.category ?? '',
        expense.paymentMethod,
      ]);
    }
    final csv = Csv(fieldDelimiter: ',');
    return '\uFEFF${csv.encode(rows)}'; // BOM UTF-8 pour Excel/Notion
  }

  /// Sauvegarde le CSV dans le fichier indiqué.
  static Future<void> saveToFile(
    List<Expense> expenses,
    String filePath,
    NotionColumns columns,
  ) async {
    final content = generateCsvContent(expenses, columns);
    await File(filePath).writeAsString(content);
  }

  static String _formatAmount(double amount) =>
      NumberFormat('#0.00', 'fr_FR').format(amount);
}

