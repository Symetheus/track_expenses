import 'package:intl/intl.dart';

class Expense {
  final String id;
  final String rawLabel;
  final String cleanName;
  final DateTime date;
  final double amount;
  final String? category;
  final String paymentMethod;
  final bool isReviewed;
  final bool sentToNotion;
  final bool isIgnored; // exclue de l'export, compte dans la progression

  const Expense({
    required this.id,
    required this.rawLabel,
    required this.cleanName,
    required this.date,
    required this.amount,
    this.category,
    this.paymentMethod = 'Carte bancaire',
    this.isReviewed = false,
    this.sentToNotion = false,
    this.isIgnored = false,
  });

  bool get isDebit => amount < 0;
  bool get isComplete => category != null && isReviewed && !isIgnored;

  /// Compte dans la progression (révisé manuellement ou ignoré)
  bool get isProcessed => isReviewed || isIgnored;

  String get formattedDate => DateFormat('dd/MM/yyyy').format(date);
  String get formattedAmount {
    final abs = amount.abs();
    final formatted = NumberFormat('#,##0.00', 'fr_FR').format(abs);
    return isDebit ? '-$formatted €' : '+$formatted €';
  }

  Map<String, String> toNotionCsvRow() => {
    'Date': formattedDate,
    'Nom': cleanName,
    'Montant': amount.toStringAsFixed(2).replaceAll('.', ','),
    'Catégorie': category ?? '',
    'Moyen de paiement': paymentMethod,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'rawLabel': rawLabel,
    'cleanName': cleanName,
    'date': date.toIso8601String(),
    'amount': amount,
    'category': category,
    'paymentMethod': paymentMethod,
    'isReviewed': isReviewed,
    'sentToNotion': sentToNotion,
    'isIgnored': isIgnored,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    rawLabel: j['rawLabel'] as String,
    cleanName: j['cleanName'] as String,
    date: DateTime.parse(j['date'] as String),
    amount: (j['amount'] as num).toDouble(),
    category: j['category'] as String?,
    paymentMethod: j['paymentMethod'] as String,
    isReviewed: j['isReviewed'] as bool,
    sentToNotion: (j['sentToNotion'] as bool?) ?? false,
    isIgnored: (j['isIgnored'] as bool?) ?? false,
  );

  Expense copyWith({
    String? cleanName,
    String? category,
    String? paymentMethod,
    bool? isReviewed,
    bool? sentToNotion,
    bool? isIgnored,
  }) => Expense(
    id: id,
    rawLabel: rawLabel,
    cleanName: cleanName ?? this.cleanName,
    date: date,
    amount: amount,
    category: category ?? this.category,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    isReviewed: isReviewed ?? this.isReviewed,
    sentToNotion: sentToNotion ?? this.sentToNotion,
    isIgnored: isIgnored ?? this.isIgnored,
  );
}
