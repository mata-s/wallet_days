import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnknownExpenseAiResult {
  final String storeType;
  final String tone;
  final String reason;
  final List<String> suggestedTags;
  final String? suggestedCategory;
  final double? confidence;
  final bool isKnownPattern;

  const UnknownExpenseAiResult({
    required this.storeType,
    required this.tone,
    required this.reason,
    required this.suggestedTags,
    this.suggestedCategory,
    this.confidence,
    this.isKnownPattern = false,
  });

  factory UnknownExpenseAiResult.fromMap(Map<String, dynamic> map) {
    final rawConfidence = map['confidence'];
    final parsedConfidence = rawConfidence is num
        ? rawConfidence.toDouble()
        : double.tryParse(rawConfidence?.toString() ?? '');

    return UnknownExpenseAiResult(
      storeType: (map['store_type'] as String? ?? 'unknown').trim(),
      tone: (map['tone'] as String? ?? 'neutral').trim(),
      reason: (map['reason'] as String? ?? '').trim(),
      suggestedTags: ((map['suggested_tags'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      suggestedCategory: (map['suggested_category'] as String?)?.trim(),
      confidence: parsedConfidence,
      isKnownPattern: map['is_known_pattern'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'store_type': storeType,
      'tone': tone,
      'reason': reason,
      'suggested_tags': suggestedTags,
      'suggested_category': suggestedCategory,
      'confidence': confidence,
      'is_known_pattern': isKnownPattern,
    };
  }
}

class UnknownExpenseAiService {
  UnknownExpenseAiService._();

  static final SupabaseClient _client = Supabase.instance.client;

  // 同じ店名で毎回AIを呼ばないための簡易メモリキャッシュ
  static final Map<String, UnknownExpenseAiResult> _memoryCache = {};

  static const List<String> _knownStoreHints = [
    'セブン',
    'ファミマ',
    'ファミリーマート',
    'ローソン',
    'ミニストップ',
    'イオン',
    '西友',
    'イトーヨーカドー',
    '業務スーパー',
    'ドンキ',
    'ドン・キホーテ',
    'マツキヨ',
    'ココカラ',
    'ウエルシア',
    'ツルハ',
    'スギ薬局',
    'amazon',
    '楽天',
    'rakuten',
    'yahoo',
    'zozo',
    'qoo10',
    'メルカリ',
    'mercari',
    'スタバ',
    'starbucks',
    'マクドナルド',
    'すき家',
    '吉野家',
    '松屋',
    'サイゼリヤ',
    'ガスト',
    'くら寿司',
    'スシロー',
    'イオンシネマ',
    'toho',
    '109シネマズ',
    'カラオケ',
    'ビッグエコー',
    'まねきねこ',
    'ジャンカラ',
    'ラウンドワン',
    'namco',
    'タイトー',
    'suica',
    'pasmo',
    'jr',
    '地下鉄',
    'バス',
    'タクシー',
    'eneos',
    '出光',
    'apollostation',
  ];

  static const List<String> _ambiguousStoreHints = [
    'shop',
    'store',
    'mart',
    'online',
    'payment',
    'pay',
    'square',
    'sq *',
    'visa',
    'mastercard',
    'jcb',
    'amex',
    'stripe',
    'paypal',
    'apple.com',
    'google',
    'gmo',
    'stores',
    'web',
    'svc',
    'service',
  ];

  /// 既存ルールで判定しづらい店名だけをAIで補助判定する。
  ///
  /// Edge Function `classify-unknown-expense` が存在しない/失敗した場合は null を返す。
  static Future<UnknownExpenseAiResult?> classify({
    required String storeName,
    String? category,
    int? amount,
    DateTime? spentAt,
    bool useCache = true,
  }) async {
    final normalizedStoreName = normalizeStoreName(storeName);
    if (normalizedStoreName.isEmpty) return null;

    if (!shouldAskAi(
      storeName: normalizedStoreName,
      category: category,
    )) {
      return null;
    }

    if (useCache && _memoryCache.containsKey(normalizedStoreName)) {
      return _memoryCache[normalizedStoreName];
    }

    try {
      final response = await _client.functions.invoke(
        'classify-unknown-expense',
        body: {
          'store_name': normalizedStoreName,
          'normalized_store_name': normalizedStoreName.toLowerCase(),
          'category': (category ?? '').trim(),
          'amount': amount,
          'spent_at': spentAt?.toIso8601String(),
          'spent_hour': spentAt?.hour,
          'spent_weekday': spentAt?.weekday,
        },
      );

      final data = response.data;
      final resultMap = _extractResultMap(data);
      if (resultMap == null) return null;

      final result = UnknownExpenseAiResult.fromMap(resultMap);
      if (useCache) {
        _memoryCache[normalizedStoreName] = result;
      }
      return result;
    } catch (e) {
      debugPrint('[UnknownExpenseAiService] classify failed: $e');
      return null;
    }
  }

  /// AIに聞くべき候補かどうかの軽い判定。
  /// 明らかに空文字、または既知カテゴリで十分なケースは除外する。
  static bool shouldAskAi({
    required String storeName,
    String? category,
  }) {
    final normalizedStoreName = normalizeStoreName(storeName);
    if (normalizedStoreName.isEmpty) return false;

    if (_looksKnownStore(normalizedStoreName)) {
      return false;
    }

    final normalizedCategory = (category ?? '').trim();
    if (normalizedCategory.isEmpty) {
      return _looksAmbiguousStore(normalizedStoreName);
    }

    const aiCandidateCategories = {
      'その他',
      '未分類',
      '雑費',
      'そのほか',
      'other',
      'unknown',
    };

    final isAiCandidateCategory =
        aiCandidateCategories.contains(normalizedCategory.toLowerCase()) ||
        aiCandidateCategories.contains(normalizedCategory);

    if (!isAiCandidateCategory) {
      return false;
    }

    return _looksAmbiguousStore(normalizedStoreName);
  }

  static String normalizeStoreName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('　', ' ');
  }

  static bool _looksKnownStore(String storeName) {
    final lower = storeName.toLowerCase();
    return _knownStoreHints.any((hint) => lower.contains(hint.toLowerCase()));
  }

  static bool _looksAmbiguousStore(String storeName) {
    final lower = storeName.toLowerCase();
    if (_ambiguousStoreHints.any((hint) => lower.contains(hint.toLowerCase()))) {
      return true;
    }

    final hasFewJapaneseLetters =
        RegExp(r'[ぁ-んァ-ヶ一-龠]').allMatches(storeName).length <= 1;
    final hasFewWordChars = RegExp(r'[A-Za-z0-9]').allMatches(storeName).length <= 4;
    return hasFewJapaneseLetters && hasFewWordChars;
  }

  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  static Map<String, dynamic>? _extractResultMap(dynamic data) {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      if (data['store_type'] != null ||
          data['suggested_tags'] != null ||
          data['suggested_category'] != null ||
          data['confidence'] != null) {
        return data;
      }

      final nested = data['result'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }

      return data;
    }

    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return _extractResultMap(decoded);
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}