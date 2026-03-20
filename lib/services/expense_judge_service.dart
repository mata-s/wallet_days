import 'package:saiyome/models/expense.dart';

/// 支出の意味合いを、画面表示用の文生成とは分けて判定するサービス。
///
/// まずはローカルルールで軽く判定し、
/// あいまいなケースだけ将来的にAIへ回す前提の設計にしている。

enum ExpenseJudgeSeverity {
  normal,
  warning,
  danger,
}

enum ExpenseJudgeTag {
  repeatStore,
  drinking,
  social,
  fashion,
  dailyGoods,
  entertainment,
  travel,
  cafe,
  convenience,
  supermarket,
  dining,
  hobby,
  beauty,
  health,
  transport,
  essential,
  discretionary,
  bulkBuy,
  ceremony,
  kids,
  family,
  gambling,
  luxury,
  sensitive,
  unknown,
}

class ExpenseJudgeResult {
  final List<ExpenseJudgeTag> tags;
  final ExpenseJudgeSeverity severity;
  final bool shouldNotify;
  final bool shouldAskAi;
  final String reasonCode;

  const ExpenseJudgeResult({
    required this.tags,
    required this.severity,
    required this.shouldNotify,
    required this.shouldAskAi,
    required this.reasonCode,
  });
}

class ExpenseJudgeService {
  static const List<String> _cafeKeywords = [
    'スタバ',
    'スターバックス',
    'starbucks',
    'コメダ',
    'コメダ珈琲',
    'ドトール',
    'doutor',
    'タリーズ',
    'tully',
    'カフェ',
    'cafe',
  ];

  static const List<String> _convenienceKeywords = [
    'セブン',
    'セブンイレブン',
    'ローソン',
    'ファミマ',
    'ファミリーマート',
    'ミニストップ',
  ];

  static const List<String> _supermarketKeywords = [
    'イオン',
    'マックスバリュ',
    '西友',
    'ライフ',
    'サミット',
    'ヤオコー',
    'オーケー',
    '業務スーパー',
    'まいばすけっと',
    'イトーヨーカドー',
    'スーパー',
  ];

  static const List<String> _hobbyKeywords = [
    'アニメイト',
    'ゲオ',
    'tsutaya',
    'ブックオフ',
    'ユニオン',
    '映画',
    'シネマ',
    'ライブ',
    'チケット',
    'ゲーム',
    'ガチャ',
    'カラオケ',
    '推し',
  ];

  static const List<String> _beautyKeywords = [
    'マツキヨ',
    'マツモトキヨシ',
    'ココカラ',
    'ウエルシア',
    'cosme',
    'コスメ',
    '美容',
    'ヘア',
    'サロン',
  ];

  static const List<String> _healthKeywords = [
    '病院',
    'クリニック',
    '薬局',
    'ドラッグ',
    '歯医者',
  ];

  static const List<String> _transportKeywords = [
    'suica',
    'pasmo',
    'jr',
    '地下鉄',
    '電車',
    'バス',
    'タクシー',
    '高速',
    '駐車場',
    'ガソリン',
    'eneos',
  ];

  static const List<String> _ceremonyKeywords = [
    'ご祝儀',
    '祝儀',
    '香典',
    '結婚式',
    '披露宴',
    '二次会',
    '葬儀',
    'お葬式',
    '法事',
    '法要',
    'お祝い',
    '祝い',
    '贈り物',
    'プレゼント',
    'ギフト',
    '祝',
  ];

  static const List<String> _drinkingKeywords = [
    '居酒屋','飲み','飲み会','バー','bar','バル','焼き鳥','串','立ち飲み','酒場'
  ];

  static const List<String> _fashionKeywords = [
    'ユニクロ','gu','しまむら','zara','h&m','wego','abcマート','nike','adidas','ファッション'
  ];

  static const List<String> _dailyGoodsKeywords = [
    'ダイソー','セリア','キャンドゥ','ニトリ','無印','ロフト','ハンズ','カインズ','コーナン','ドンキ'
  ];

  static const List<String> _entertainmentKeywords = [
    'ラウンドワン','ラウワン','カラオケ','ゲーセン','ゲームセンター','映画館','シネマ','温泉','サウナ','ボウリング'
  ];

  static const List<String> _travelKeywords = [
    'ホテル','旅館','airbnb','じゃらん','楽天トラベル','expedia','booking','新幹線','ana','jal'
  ];

  static const List<String> _kidsKeywords = [
    'トイザらス',
    'ベビーザらス',
    '西松屋',
    'アカチャンホンポ',
    'バースデイ',
    'おもちゃ',
    '玩具',
    'ベビー',
    'キッズ',
    '子ども',
    '子供',
  ];

  static const List<String> _gamblingKeywords = [
    'パチンコ',
    'スロット',
    '競馬',
    '競輪',
    'ボート',
    'オートレース',
    '宝くじ',
    'toto',
    'ロト',
    'casino',
    'カジノ',
  ];

  static const List<String> _luxuryKeywords = [
    'louis vuitton',
    'ヴィトン',
    'gucci',
    'prada',
    'hermes',
    'エルメス',
    'chanel',
    'シャネル',
    'tiffany',
    'cartier',
    'ロレックス',
    '高級',
    'ジュエリー',
    'ブランド',
  ];

  static const List<String> _sensitiveKeywords = [
    'デリヘル',
    'ソープ',
    'ヘルス',
    'ホスト',
    'キャバクラ',
    '風俗',
    'メンズエステ',
  ];

  static ExpenseJudgeResult judge({
    required Expense expense,
    required int totalBudget,
  }) {
    final store = expense.storeName.trim().toLowerCase();
    final category = expense.category.trim();
    final amount = expense.amount;
    final spendingRate = totalBudget <= 0 ? 0.0 : amount / totalBudget;

    final tags = <ExpenseJudgeTag>[];

    if (_matches(category, store, 'カフェ', _cafeKeywords)) {
      tags.addAll([ExpenseJudgeTag.cafe, ExpenseJudgeTag.discretionary]);
      return ExpenseJudgeResult(
        tags: tags,
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'cafe_detected',
      );
    }

    if (_matches(category, store, 'コンビニ', _convenienceKeywords)) {
      tags.addAll([ExpenseJudgeTag.convenience, ExpenseJudgeTag.discretionary]);
      return ExpenseJudgeResult(
        tags: tags,
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'convenience_detected',
      );
    }

    if (_matches(category, store, 'スーパー', _supermarketKeywords)) {
      tags.addAll([
        ExpenseJudgeTag.supermarket,
        ExpenseJudgeTag.essential,
        if (amount >= 3000) ExpenseJudgeTag.bulkBuy,
      ]);
      return const ExpenseJudgeResult(
        tags: [
          ExpenseJudgeTag.supermarket,
          ExpenseJudgeTag.essential,
        ],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'supermarket_detected',
      );
    }

    if (_containsAny(store, _ceremonyKeywords) ||
        category == '冠婚葬祭' ||
        category == 'お祝い' ||
        category == '贈り物') {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.ceremony, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'ceremony_detected',
      );
    }

    if (_containsAny(store, _drinkingKeywords) || category == '飲み' || category == '居酒屋') {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.drinking, ExpenseJudgeTag.social, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'drinking_detected',
      );
    }

    if (_containsAny(store, _fashionKeywords) || category == '服' || category == 'ファッション') {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.fashion, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'fashion_detected',
      );
    }

    if (_containsAny(store, _dailyGoodsKeywords) || category == '日用品') {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.dailyGoods, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'daily_goods_detected',
      );
    }

    if (_containsAny(store, _entertainmentKeywords) || category == '娯楽') {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.entertainment, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'entertainment_detected',
      );
    }

    if (_containsAny(store, _travelKeywords) || category == '旅行') {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.travel, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'travel_detected',
      );
    }

    if (_containsAny(store, _kidsKeywords) ||
        category == '子ども' ||
        category == '子供' ||
        category == '育児') {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.kids, ExpenseJudgeTag.family, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'kids_detected',
      );
    }

    if (_containsAny(store, _gamblingKeywords) || category == 'ギャンブル') {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.gambling, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'gambling_detected',
      );
    }

    if (_containsAny(store, _luxuryKeywords) ||
        category == '高級品' ||
        category == 'ブランド') {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.luxury, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'luxury_detected',
      );
    }

    if (_containsAny(store, _sensitiveKeywords)) {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.sensitive],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'sensitive_detected',
      );
    }

    if (_matches(category, store, '外食', const [])) {
      tags.addAll([ExpenseJudgeTag.dining, ExpenseJudgeTag.discretionary]);
      return ExpenseJudgeResult(
        tags: tags,
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'dining_detected',
      );
    }

    if (_containsAny(store, _hobbyKeywords) || category == '趣味') {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.hobby, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'hobby_detected',
      );
    }

    if (_containsAny(store, _beautyKeywords) || category == '美容') {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.beauty, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'beauty_detected',
      );
    }

    if (_containsAny(store, _healthKeywords) || category == '医療') {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.health, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'health_detected',
      );
    }

    if (_containsAny(store, _transportKeywords) || category == '交通') {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.transport, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'transport_detected',
      );
    }

    return ExpenseJudgeResult(
      tags: const [ExpenseJudgeTag.unknown],
      severity: _severityFromRate(spendingRate),
      shouldNotify: false,
      shouldAskAi: true,
      reasonCode: 'unknown_need_ai',
    );
  }

  static int consecutiveStoreCount(List<Expense> expenses) {
    if (expenses.isEmpty) return 0;

    final latestStore = expenses.first.storeName.trim();
    if (latestStore.isEmpty) return 0;

    var count = 0;
    for (final expense in expenses) {
      final store = expense.storeName.trim();
      if (store != latestStore) break;
      count++;
    }

    return count;
  }

  static bool hasConsecutiveStoreSpending(
    List<Expense> expenses, {
    int minCount = 4,
  }) {
    return consecutiveStoreCount(expenses) >= minCount;
  }

  static bool _matches(
    String category,
    String store,
    String exactCategory,
    List<String> keywords,
  ) {
    if (category == exactCategory) return true;
    return _containsAny(store, keywords);
  }

  static bool _containsAny(String value, List<String> keywords) {
    return keywords.any((k) => value.contains(k.toLowerCase()));
  }

  static ExpenseJudgeSeverity _severityFromRate(double rate) {
    if (rate >= 0.2) return ExpenseJudgeSeverity.danger;
    if (rate >= 0.1) return ExpenseJudgeSeverity.warning;
    return ExpenseJudgeSeverity.normal;
  }
}
