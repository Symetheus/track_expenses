import 'expense.dart';

/// Représente un fichier CSV importé, avec ses dépenses et son statut.
class ImportRecord {
  final String id;
  final String originalFileName;
  final String csvBackupRelativePath;
  final DateTime importedAt;
  final List<Expense> expenses;

  const ImportRecord({
    required this.id,
    required this.originalFileName,
    required this.csvBackupRelativePath,
    required this.importedAt,
    required this.expenses,
  });

  int get totalCount => expenses.length;
  int get reviewedCount => expenses.where((e) => e.isReviewed).length;
  bool get allReviewed => expenses.isNotEmpty && expenses.every((e) => e.isReviewed);
  double get progress => totalCount == 0 ? 0.0 : reviewedCount / totalCount;

  ImportRecord copyWith({List<Expense>? expenses}) => ImportRecord(
        id: id,
        originalFileName: originalFileName,
        csvBackupRelativePath: csvBackupRelativePath,
        importedAt: importedAt,
        expenses: expenses ?? this.expenses,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalFileName': originalFileName,
        'csvBackupRelativePath': csvBackupRelativePath,
        'importedAt': importedAt.toIso8601String(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory ImportRecord.fromJson(Map<String, dynamic> j) => ImportRecord(
        id: j['id'] as String,
        originalFileName: j['originalFileName'] as String,
        csvBackupRelativePath: j['csvBackupRelativePath'] as String,
        importedAt: DateTime.parse(j['importedAt'] as String),
        expenses: (j['expenses'] as List)
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
