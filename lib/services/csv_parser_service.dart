import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import 'category_suggestion_service.dart';

/// Parser spécifique pour les exports CSV de la Société Générale.
///
/// Format réel observé :
/// ```
/// ="00000000000";01/05/2026;31/05/2026;50;29/05/2026;27423,29 EUR   ← à ignorer
///                                                                     ← ligne vide
/// Date de l'opération;Libellé;Détail de l'écriture;Montant de l'opération;Devise
/// 29/05/2026;CARTE X1417 27/05 ;CARTE X1417 27/05 Carte Ticket Restaurant ...;-6,30;EUR
/// ```
class CsvParserService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  // ── Point d'entrée public ──────────────────────────────────────────────────

  static Future<List<Expense>> parseFile(String filePath) async {
    final file = File(filePath);
    String content;
    // SG exporte en Windows-1252 / Latin-1 — on essaie d'abord latin1
    try {
      content = await file.readAsString(encoding: latin1);
    } catch (_) {
      content = await file.readAsString(encoding: utf8);
    }
    return parseContent(content);
  }

  static List<Expense> parseContent(String content) {
    // Normaliser les fins de ligne
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');

    // ── Trouver la ligne d'en-tête des colonnes ────────────────────────────
    // C'est la première ligne qui contient "Date" ET "Libell" (accents perdus ok)
    int headerIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if ((l.contains('date') && l.contains('libell')) ||
          (l.contains('date') && l.contains('montant'))) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == -1) {
      throw Exception(
        'En-tête introuvable.\n'
        'Le fichier doit contenir une ligne avec "Date de l\'opération" et "Libellé".\n'
        'Colonnes trouvées dans les 5 premières lignes :\n'
        '${lines.take(5).join('\n')}',
      );
    }

    // Déterminer le séparateur depuis la ligne d'en-tête
    final headerLine = lines[headerIndex];
    final separator = headerLine.contains(';') ? ';' : ',';

    // Parser l'en-tête pour trouver les indices de colonnes
    final headers = _splitLine(headerLine, separator)
        .map((h) => _normalize(h))
        .toList();

    final dateIdx    = _colIndex(headers, ['date']);
    final labelIdx   = _colIndex(headers, ['libell']);
    final detailIdx  = _colIndex(headers, ['detail', 'criture', 'ecriture']);
    final amountIdx  = _colIndex(headers, ['montant', 'amount']);
    // Devise est optionnelle

    if (dateIdx == -1 || amountIdx == -1) {
      throw Exception(
        'Colonnes "Date" ou "Montant" introuvables.\n'
        'En-têtes détectés : ${headers.join(' | ')}',
      );
    }

    // ── Parser les lignes de données ──────────────────────────────────────
    final expenses = <Expense>[];
    int idCounter = 0;

    for (int i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cells = _splitLine(line, separator);
      if (cells.length < 2) continue;

      // Date
      final rawDate = _cell(cells, dateIdx);
      if (rawDate.isEmpty) continue;
      DateTime? date;
      try {
        date = _dateFormat.parse(rawDate);
      } catch (_) {
        try {
          date = DateTime.parse(rawDate);
        } catch (_) {
          continue; // ligne non-date (ex: pied de page)
        }
      }

      // Libellé court (col Libellé) + Détail long (col Détail)
      final rawLabel  = _cell(cells, labelIdx).trim();
      final rawDetail = detailIdx != -1 ? _cell(cells, detailIdx).trim() : rawLabel;

      // Montant (format français : "-47,00" ou "2975,71")
      final rawAmount = _cell(cells, amountIdx);
      final amount    = _parseAmount(rawAmount);
      if (amount == 0.0 && rawLabel.isEmpty) continue;

      // Moyen de paiement (déduit du libellé)
      final paymentMethod = _detectPaymentMethod(rawLabel);

      // Nom nettoyé depuis le Détail
      final cleanName = _extractMerchantName(rawDetail, rawLabel);

      // Suggestion de catégorie
      final suggested = CategorySuggestionService.suggest('$rawLabel $rawDetail');

      expenses.add(Expense(
        id: 'exp_${idCounter++}',
        rawLabel: rawDetail.isNotEmpty ? rawDetail : rawLabel,
        cleanName: cleanName,
        date: date,
        amount: amount,
        category: suggested,
        paymentMethod: paymentMethod,
        isReviewed: false,
      ));
    }

    if (expenses.isEmpty) {
      throw Exception(
        'Aucune transaction trouvée après la ligne d\'en-tête (index $headerIndex).\n'
        'Vérifiez que le fichier contient bien des lignes de données.',
      );
    }

    // Tri chronologique décroissant
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  // ── Helpers privés ────────────────────────────────────────────────────────

  /// Découpe une ligne CSV en tenant compte des champs entre guillemets.
  static List<String> _splitLine(String line, String sep) {
    // Gère le cas ="valeur" (format Excel)
    final result = <String>[];
    final buf    = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == '=' && i + 1 < line.length && line[i + 1] == '"') {
        // ="valeur" → sauter le =
        continue;
      } else if (!inQuotes && line.substring(i).startsWith(sep)) {
        result.add(buf.toString().trim());
        buf.clear();
        i += sep.length - 1;
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }

  static String _cell(List<String> cells, int idx) {
    if (idx < 0 || idx >= cells.length) return '';
    return cells[idx].replaceAll('"', '').trim();
  }

  /// Normalise un en-tête : minuscules, supprime accents basiques.
  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêëÉÈÊ]'), 'e')
        .replaceAll(RegExp(r'[àâäÀÂÄ]'), 'a')
        .replaceAll(RegExp(r'[îïÎÏ]'), 'i')
        .replaceAll(RegExp(r'[ôöÔÖ]'), 'o')
        .replaceAll(RegExp(r'[ùûüÙÛÜ]'), 'u')
        .replaceAll(RegExp(r'[ç\?ÃéÃ¨Ã\u00c3\u00a9\u00e9\ufffd]'), '')
        .trim();
  }

  static int _colIndex(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].contains(candidate)) return i;
      }
    }
    return -1;
  }

  /// Parse un montant au format français : "-6,30" → -6.30
  static double _parseAmount(String raw) {
    if (raw.isEmpty) return 0.0;
    final cleaned = raw
        .replaceAll('\u00a0', '') // espace insécable
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Détecte le moyen de paiement depuis le libellé court SG.
  static String _detectPaymentMethod(String label) {
    final u = label.toUpperCase();
    if (u.contains('CARTE'))       return 'Carte bancaire';
    if (u.contains('VIR INST'))    return 'Virement';
    if (u.contains('VIR RECU'))    return 'Virement';
    if (u.contains('VIR '))        return 'Virement';
    if (u.contains('PRELEVEMENT')) return 'Prélèvement';
    if (u.contains('COTISATION'))  return 'Prélèvement';
    if (u.contains('VIREMENT'))    return 'Virement';
    if (u.contains('CHEQUE') || u.contains('CHQ')) return 'Chèque';
    if (u.contains('RETRAIT') || u.contains('DAB')) return 'Espèces';
    return 'Carte bancaire';
  }

  /// Extrait le nom du marchand depuis le Détail de l'écriture SG.
  ///
  /// Exemples SG réels :
  ///   "CARTE X1417 27/05 Carte Ticket Restaurant COMMERCE ELECTRONIQUE 23061...IOPD"
  ///     → "Carte Ticket Restaurant"
  ///   "CARTE X1417 27/05 LE JU 10161...IOPD"
  ///     → "Le Ju"
  ///   "VIR RECU    5784...S DE: SNCF CONNECT AND TECH S REF: ... 6142...  "
  ///     → "SNCF Connect And Tech"
  ///   "PRELEVEMENT EUROPEEN 45120... DE: SG MERCER SAS ID: ... MOTIF: PREL MERCER ..."
  ///     → "SG Mercer"
  ///   "COTISATION MENSUELLE SOBRIO"
  ///     → "Sobrio"
  static String _extractMerchantName(String detail, String fallback) {
    var s = detail.trim();
    if (s.isEmpty) s = fallback.trim();
    if (s.isEmpty) return '';

    // 1) Supprimer le préfixe "CARTE X1417 DD/MM " (ou "CARTE X1417 REMBT DD/MM ")
    s = s.replaceAll(RegExp(r'^CARTE\s+\w+\s+(?:REMBT\s+)?\d{2}/\d{2}\s*', caseSensitive: false), '');

    // 2) Cas VIR RECU / VIR INST : extraire "DE: NOM REF:"
    if (RegExp(r'^VIR\s+', caseSensitive: false).hasMatch(s)) {
      final deMatch = RegExp(r'DE:\s*(.+?)(?:\s+(?:REF:|MOTIF:|ID:|DATE:)|$)', caseSensitive: false).firstMatch(s);
      if (deMatch != null) {
        s = deMatch.group(1)!.trim();
      } else {
        // Supprimer le préfixe VIR RECU / VIR INST et les numéros
        s = s.replaceAll(RegExp(r'^VIR\s+\w+\s+\w*\s*', caseSensitive: false), '');
        s = s.replaceAll(RegExp(r'^\d+\w*\s*'), '');
      }
    }

    // 3) Cas PRELEVEMENT / COTISATION : extraire "MOTIF:" ou "DE:"
    if (RegExp(r'^PRELEVEMENT|^COTISATION', caseSensitive: false).hasMatch(s)) {
      final motifMatch = RegExp(r'MOTIF:\s*(.+?)(?:\s+\d|$)', caseSensitive: false).firstMatch(s);
      final deMatch    = RegExp(r'DE:\s*(.+?)(?:\s+(?:ID:|MOTIF:|REF:)|$)', caseSensitive: false).firstMatch(s);
      if (motifMatch != null) {
        s = motifMatch.group(1)!.trim();
      } else if (deMatch != null) {
        s = deMatch.group(1)!.trim();
      } else {
        // Supprimer "PRELEVEMENT EUROPEEN XXXXXXX " ou "COTISATION MENSUELLE "
        s = s.replaceAll(RegExp(r'^(?:PRELEVEMENT\s+\w+|COTISATION\s+\w+)\s+\d*\s*', caseSensitive: false), '');
      }
    }

    // 4) Supprimer " COMMERCE ELECTRONIQUE" et tout ce qui suit
    s = s.replaceAll(RegExp(r'\s+COMMERCE\s+ELECTRONIQUE.*$', caseSensitive: false), '');

    // 5) Supprimer les codes numériques finaux (ex: "110614904163375IOPD", "IOPD", "ILIC")
    s = s.replaceAll(RegExp(r'\s+\d{10,}[A-Z]*\s*$'), '');
    s = s.replaceAll(RegExp(r'\s+[A-Z0-9]{5,}IOPD\s*$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s+[A-Z0-9]{5,}ILIC\s*$', caseSensitive: false), '');

    // 6) Supprimer les montants intégrés (ex: "25,96 EUR PAYS-BAS")
    s = s.replaceAll(RegExp(r'\s+[\d,]+\s+EUR\s+[\w-]+\s*', caseSensitive: false), '');

    // 7) Nettoyer les espaces multiples
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // 8) Capitaliser proprement
    if (s.isNotEmpty) {
      s = s.split(' ').map((word) {
        if (word.isEmpty) return word;
        // Garder les sigles tout en majuscules courts (2-4 lettres)
        if (word.length <= 4 && word == word.toUpperCase() && RegExp(r'^[A-Z]+$').hasMatch(word)) {
          return word;
        }
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    return s.isEmpty ? _cleanFallback(fallback) : s;
  }

  /// Nettoyage minimal du libellé court si le détail est vide.
  static String _cleanFallback(String raw) {
    var s = raw.replaceAll(RegExp(r'^CARTE\s+\w+\s+\d{2}/\d{2}\s*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'^\d+\s*'), '').trim();
    if (s.isEmpty) return raw;
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }
}

