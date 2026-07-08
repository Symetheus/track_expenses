class NotionColumns {
  final String name;
  final String date;
  final String amount;
  final String category;
  final String paymentMethod;

  const NotionColumns({
    this.name = 'Dépense',
    this.date = 'Date',
    this.amount = 'Montant',
    this.category = 'Catégorie',
    this.paymentMethod = 'Moyen de paiement',
  });

  NotionColumns copyWith({String? name, String? date, String? amount, String? category, String? paymentMethod}) {
    return NotionColumns(
      name: name ?? this.name,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class AppSettings {
  final String notionToken;
  final String notionDatabaseId;
  final NotionColumns notionColumns;
  final List<String> categories;
  final List<String> paymentMethods;

  AppSettings({
    this.notionToken = '',
    this.notionDatabaseId = '',
    NotionColumns? notionColumns,
    List<String>? categories,
    List<String>? paymentMethods,
  }) : notionColumns = notionColumns ?? const NotionColumns(),
       categories = categories ?? defaultCategories,
       paymentMethods = paymentMethods ?? defaultPaymentMethods;

  static const List<String> defaultCategories = [
    'Loyer',
    'Abonnement',
    'Coffee',
    'Course',
    'Loisirs',
    'Restaurant',
    'Santé',
    'Shopping',
    'Transports',
    'Voyage',
  ];

  static const List<String> defaultPaymentMethods = ['Carte bancaire', 'Virement', 'Prélèvement', 'Espèces', 'Chèque'];

  bool get isNotionConfigured => notionToken.isNotEmpty && notionDatabaseId.isNotEmpty;

  AppSettings copyWith({
    String? notionToken,
    String? notionDatabaseId,
    NotionColumns? notionColumns,
    List<String>? categories,
    List<String>? paymentMethods,
  }) {
    return AppSettings(
      notionToken: notionToken ?? this.notionToken,
      notionDatabaseId: notionDatabaseId ?? this.notionDatabaseId,
      notionColumns: notionColumns ?? this.notionColumns,
      categories: categories ?? List.from(this.categories),
      paymentMethods: paymentMethods ?? List.from(this.paymentMethods),
    );
  }
}
