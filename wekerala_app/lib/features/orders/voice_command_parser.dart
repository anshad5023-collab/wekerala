/// Pure, dependency-free parser that turns a spoken order line into structured
/// items. Built Malayalam-first: the speech recogniser runs in `ml_IN`, so the
/// transcription usually arrives in Malayalam script ("രണ്ട് കിലോ അരി") or
/// Manglish ("randu kilo ari"), not English digits. The old inline parser only
/// understood ASCII digits + English units, so every Malayalam quantity silently
/// became qty=1. This handles Malayalam number words, Malayalam-script digits,
/// fractions (അര/കാൽ/മുക്കാൽ), Manglish, and English — falling back gracefully.
///
/// Kept free of any Flutter import so it is fast to unit-test in isolation.
library;

class ParsedVoiceItem {
  final String name;
  final double qty;
  final String unit; // normalised: piece|kg|gram|litre|ml|dozen|packet|box

  const ParsedVoiceItem({required this.name, required this.qty, required this.unit});

  @override
  String toString() => 'ParsedVoiceItem(name: $name, qty: $qty, unit: $unit)';
}

// ── Number words: Malayalam script + Manglish → value ───────────────────────
const Map<String, double> _numberWords = {
  // whole numbers — Malayalam
  'പൂജ്യം': 0,
  'ഒന്ന്': 1, 'ഒരു': 1, 'ഒറ്റ': 1,
  'രണ്ട്': 2, 'രണ്ട': 2,
  'മൂന്ന്': 3, 'മൂന്ന': 3,
  'നാല്': 4, 'നാല': 4,
  'അഞ്ച്': 5, 'അഞ്ച': 5,
  'ആറ്': 6, 'ആറ': 6,
  'ഏഴ്': 7, 'ഏഴ': 7,
  'എട്ട്': 8, 'എട്ട': 8,
  'ഒമ്പത്': 9, 'ഒൻപത്': 9,
  'പത്ത്': 10, 'പത്ത': 10,
  'പന്ത്രണ്ട്': 12,
  // fractions — Malayalam
  'അര': 0.5, 'കാൽ': 0.25, 'മുക്കാൽ': 0.75, 'ഒന്നര': 1.5,
  // whole numbers — Manglish (Latin script Malayalam)
  'onnu': 1, 'oru': 1, 'onn': 1,
  'randu': 2, 'rand': 2, 'rendu': 2,
  'moonu': 3, 'moonnu': 3, 'munnu': 3,
  'naalu': 4, 'naal': 4,
  'anchu': 5, 'anju': 5,
  'aaru': 6, 'aar': 6,
  'ezhu': 7, 'el': 7,
  'ettu': 8, 'ett': 8,
  'ombathu': 9, 'onpathu': 9,
  'pathu': 10, 'patthu': 10,
  // fractions — Manglish
  'ara': 0.5, 'kaal': 0.25, 'mukkaal': 0.75, 'onnara': 1.5,
};

// Malayalam-script digits ൦-൯ → ASCII.
const Map<String, String> _malayalamDigits = {
  '൦': '0', '൧': '1', '൨': '2', '൩': '3', '൪': '4',
  '൫': '5', '൬': '6', '൭': '7', '൮': '8', '൯': '9',
};

// ── Unit words → normalised unit ────────────────────────────────────────────
const Map<String, String> _unitWords = {
  // kg
  'കിലോ': 'kg', 'കിലോഗ്രാം': 'kg', 'കി': 'kg', 'kilo': 'kg', 'kg': 'kg', 'kilogram': 'kg',
  // gram
  'ഗ്രാം': 'gram', 'gram': 'gram', 'g': 'gram', 'gm': 'gram',
  // litre
  'ലിറ്റർ': 'litre', 'litre': 'litre', 'liter': 'litre', 'l': 'litre',
  // ml
  'മില്ലി': 'ml', 'മില്ലിലിറ്റർ': 'ml', 'ml': 'ml',
  // piece
  'എണ്ണം': 'piece', 'എണ്ണ': 'piece', 'piece': 'piece', 'pcs': 'piece', 'pc': 'piece', 'nos': 'piece',
  // dozen
  'ഡസൻ': 'dozen', 'dozen': 'dozen',
  // packet / bundle
  'പാക്കറ്റ്': 'packet', 'പാക്കറ്റ': 'packet', 'കെട്ട്': 'packet', 'packet': 'packet', 'pack': 'packet',
  // box
  'ബോക്സ്': 'box', 'box': 'box',
};

// Connective / filler words to drop from item names ("and", "also", "of").
const Set<String> _fillerWords = {
  'ഉം', 'പിന്നെ', 'പിന്നേ', 'കൂടെ', 'വേണം', 'താ', 'തരൂ', 'ഒക്കെ',
  'and', 'also', 'plus', 'of', 'the', 'a',
};

double? _wordToNumber(String token) {
  if (_numberWords.containsKey(token)) return _numberWords[token];
  // Malayalam-script digits → ASCII, then parse.
  if (_malayalamDigits.keys.any(token.contains)) {
    final ascii = token.split('').map((c) => _malayalamDigits[c] ?? c).join();
    final v = double.tryParse(ascii);
    if (v != null) return v;
  }
  return double.tryParse(token);
}

/// Parses a full spoken order into items. Tolerant of mixed Malayalam/Manglish/
/// English, multiple items, and missing quantities (defaults to qty 1, piece).
List<ParsedVoiceItem> parseVoiceOrder(String text) {
  if (text.trim().isEmpty) return const [];
  // Split on whitespace, commas and Malayalam danda; keep Unicode letters.
  final tokens = text
      .toLowerCase()
      .split(RegExp(r'[\s,।॥]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  final items = <ParsedVoiceItem>[];
  var i = 0;
  while (i < tokens.length) {
    // Skip filler tokens between items.
    if (_fillerWords.contains(tokens[i])) {
      i++;
      continue;
    }

    double? qty;
    var unit = 'piece';

    // A leading number sets the quantity (sum adjacent number words, e.g.
    // "ഒന്ന് അര" = 1 + 0.5 = 1.5).
    while (i < tokens.length && _wordToNumber(tokens[i]) != null) {
      qty = (qty ?? 0) + _wordToNumber(tokens[i])!;
      i++;
    }

    // An optional unit word follows the quantity.
    if (i < tokens.length && _unitWords.containsKey(tokens[i])) {
      unit = _unitWords[tokens[i]]!;
      i++;
    }

    // The item name runs until the next quantity word or end of input.
    final nameParts = <String>[];
    while (i < tokens.length &&
        _wordToNumber(tokens[i]) == null) {
      final tok = tokens[i];
      // A unit word mid-name with no preceding number is noise — skip it.
      if (_unitWords.containsKey(tok) && nameParts.isEmpty) {
        unit = _unitWords[tok]!;
      } else if (!_fillerWords.contains(tok)) {
        nameParts.add(tok);
      }
      i++;
    }

    final name = nameParts.join(' ').trim();
    if (name.isNotEmpty) {
      items.add(ParsedVoiceItem(name: name, qty: qty ?? 1, unit: unit));
    } else if (qty != null) {
      // A number with no name (rare) — attach to previous item's qty instead of
      // dropping it, so "അരി രണ്ട്" still bumps rice to 2.
      if (items.isNotEmpty) {
        final prev = items.removeLast();
        items.add(ParsedVoiceItem(name: prev.name, qty: qty, unit: prev.unit));
      }
    }
  }
  return items;
}
