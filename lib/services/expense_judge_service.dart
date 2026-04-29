import 'package:saiyome/models/expense.dart';

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
  movie,
  karaoke,
  arcade,
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
  onlineShopping,
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
    'coffee',
    'coffee shop',
    'coffeehouse',
    'espresso',
    'latte',
    'blue bottle',
    'peets',
    "peet's",
    'costa coffee',
    'costa',
    'coffee bean',
    'tim hortons',
    'dunkin',
    'dunkin donuts',
    'dutch bros',
    'luckin coffee',
    'mccafe'
  ];

  static const List<String> _convenienceKeywords = [
    'セブン',
    'セブンイレブン',
    'ローソン',
    'ファミマ',
    'ファミリーマート',
    'ミニストップ',
    '7-eleven',
    'seven eleven',
    'lawson',
    'familymart',
    'family mart',
    'ministop',
    'convenience',
    'convenience store',
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
    'aeon',
    'maxvalu',
    'seiyu',
    'life supermarket',
    'summit',
    'yaoko',
    'ok store',
    'costco',
    'whole foods',
    'trader joe',
    'walmart',
    'target',
    'grocery',
    'groceries',
    'supermarket',
    'kroger',
    'publix',
    'safeway',
    'albertsons',
    'aldi',
    'heb',
    'h-e-b',
    'instacart',
    'amazon fresh',
  ];

  static const List<String> _hobbyKeywords = [
    'アニメイト',
    'ゲオ',
    'tsutaya',
    'ブックオフ',
    'ユニオン',
    'ライブ',
    'チケット',
    'ゲーム',
    'ガチャ',
    'カラオケ',
    '推し',
    'hobby',
    'hobbies',
    'anime',
    'manga',
    'comic',
    'comics',
    'bookoff',
    'book off',
    'games',
    'gaming',
    'steam',
    'nintendo',
    'playstation',
    'xbox',
    'concert',
    'ticket',
    'tickets',
    'merch',
    'merchandise',
    'collectible',
    'collectibles',
    'gacha',
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
    'matsukiyo',
    'welcia',
    'cosmetics',
    'beauty',
    'hair salon',
    'salon',
    'skincare',
    'makeup',
    'nail',
  ];

  static const List<String> _healthKeywords = [
    '病院',
    'クリニック',
    '薬局',
    'ドラッグ',
    '歯医者',
    'hospital',
    'clinic',
    'pharmacy',
    'dentist',
    'medical',
    'health',
    'drugstore',
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
    'train',
    'subway',
    'metro',
    'bus',
    'taxi',
    'uber',
    'lyft',
    'parking',
    'gas',
    'gasoline',
    'fuel',
    'shell',
    'exxon',
    'chevron',
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
    'wedding',
    'funeral',
    'ceremony',
    'celebration',
    'gift',
    'gifts',
    'present',
    'presents',
    'donation',
    'condolence',
    'memorial',
    'anniversary',
    'birthday gift',
    'bridal',
  ];

  static const List<String> _drinkingKeywords = [
    '居酒屋',
    '飲み',
    '飲み会',
    'バー',
    'bar',
    'pub',
    'izakaya',
    'bal',
    'バル',
    '焼き鳥',
    'やきとり',
    'yakitori',
    '串',
    '立ち飲み',
    '酒場',
    'beer',
    'wine',
    'cocktail',
    'drinking',
    'happy hour',
  ];

  static const List<String> _fashionKeywords = [
    'ユニクロ',
    'uniqlo',
    'gu',
    'しまむら',
    'shimamura',
    'zara',
    'h&m',
    'wego',
    'abcマート',
    'abc mart',
    'nike',
    'adidas',
    'puma',
    'new balance',
    'converse',
    'vans',
    'gap',
    'hm',
    'shein',
    'ファッション',
    'fashion',
    'clothing',
    'clothes',
    'apparel',
    'shoes',
    'sneakers',
  ];

  static const List<String> _dailyGoodsKeywords = [
    'ダイソー',
    'daiso',
    'セリア',
    'seria',
    'キャンドゥ',
    'cando',
    'can do',
    'ニトリ',
    'nitori',
    '無印',
    'muji',
    'ロフト',
    'loft',
    'ハンズ',
    'hands',
    'tokyu hands',
    'カインズ',
    'cainz',
    'コーナン',
    'kohnan',
    'ドンキ',
    'donki',
    'don quijote',
    'dollar store',
    'home goods',
    'household',
    'household goods',
    'daily goods',
    'home center',
    'home depot',
    'lowes',
    'ikea',
    'drugstore',
  ];

  static const List<String> _movieKeywords = [
    '映画館',
    'シネマ',
    'toho',
    'イオンシネマ',
    'movix',
    '109シネマ',
    'ユナイテッドシネマ',
    '映画',
    'movie',
    'movies',
    'cinema',
    'theater',
    'theatre',
    'amc',
    'regal',
  ];

  static const List<String> _karaokeKeywords = [
    'カラオケ',
    'ジャンカラ',
    'ビッグエコー',
    'まねきねこ',
    'joysound',
    'コートダジュール',
    'karaoke',
    'big echo',
    'manekineko',
  ];

  static const List<String> _arcadeKeywords = [
    'ゲーセン',
    'ゲームセンター',
    'ラウンドワン',
    'ラウワン',
    'gigo',
    'タイトー',
    'namco',
    'arcade',
    'game center',
    'round1',
    'round one',
    'taito',
  ];

  static const List<String> _entertainmentKeywords = [
    '温泉',
    '銭湯',
    'サウナ',
    'スパ',
    '岩盤浴',
    'ボウリング',
    '遊園地',
    'テーマパーク',
    '水族館',
    '動物園',
    '美術館',
    '博物館',
    '温浴',
    'onsen',
    'hot spring',
    'spa',
    'sauna',
    'bowling',
    'theme park',
    'amusement park',
    'aquarium',
    'zoo',
    'museum',
    'gallery',
    'disney',
    'disneyland',
    'universal studios',
    'netflix',
    'spotify',
    'hulu',
    'disney+',
    'youtube premium',
    'prime video',
  ];

  static const List<String> _travelKeywords = [
    'ホテル',
    '旅館',
    '民宿',
    '宿泊',
    '旅行',
    'ツアー',
    'airbnb',
    'じゃらん',
    '楽天トラベル',
    'expedia',
    'booking',
    '新幹線',
    'ana',
    'jal',
    'hotel',
    'hotels',
    'motel',
    'inn',
    'hostel',
    'resort',
    'lodging',
    'travel',
    'trip',
    'tour',
    'flight',
    'airline',
    'airport',
    'delta',
    'united airlines',
    'american airlines',
    'southwest',
    'skyscanner',
    'agoda',
    'trip.com',
    'tripadvisor',
    'google travel',
    'vrbo',
  ];

  static const List<String> _onlineShoppingKeywords = [
    'amazon',
    '楽天',
    'rakuten',
    'yahoo',
    'zozo',
    'qoo10',
    'メルカリ',
    'mercari',
    '通販',
    'online shopping',
    'e-commerce',
    'ecommerce',
    'shopping',
    'etsy',
    'shein',
    'temu',
    'aliexpress',
    'ebay',
    'whatnot',
    'shopify',
    'shop app',
    'depop',
    'poshmark',
    'asos',
    'instacart',
    'groupon',
    'klarna',
    'affirm',
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
    'toys r us',
    'babies r us',
    'akachan honpo',
    'nishimatsuya',
    'toy',
    'toys',
    'baby',
    'babies',
    'kids',
    'children',
    'child',
    'childcare',
    'nursery',
    'diaper',
    'diapers',
    'stroller',
    'school supplies',
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
    'gambling',
    'betting',
    'sportsbook',
    'sports betting',
    'pachinko',
    'slot',
    'slots',
    'lottery',
    'lotto',
    'horse racing',
    'racecourse',
    'keiba',
    'boat race',
    'keirin',
    'bet365',
    'draftkings',
    'fanduel',
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
    'rolex',
    'balenciaga',
    'dior',
    'celine',
    'loewe',
    'fendi',
    'bvlgari',
    'bulgari',
    'coach',
    'michael kors',
    'ysl',
    'saint laurent',
    'luxury',
    'premium',
    'jewelry',
    'jewellery',
    'watch',
    'watches',
  ];

  static const List<String> _sensitiveKeywords = [
    'デリヘル',
    'ソープ',
    'ヘルス',
    'ホスト',
    'キャバクラ',
    '風俗',
    'メンズエステ',
    'adult',
    'adult entertainment',
    'host club',
    'cabaret',
    'girls bar',
    'soapland',
    'massage parlor',
    'men\'s esthetic',
    'mens esthetic',
    'escort',
    'night club',
    'strip club',
  ];

  static ExpenseJudgeResult judge({
    required Expense expense,
    required int totalBudget,
  }) {
    final store = expense.storeName.trim().toLowerCase();
    final category = expense.category.trim();
    final categoryLower = category.toLowerCase();
    final amount = expense.amount;
    final spendingRate = totalBudget <= 0 ? 0.0 : amount / totalBudget;

    final tags = <ExpenseJudgeTag>[];

    if (_matchesAnyCategory(categoryLower, store, const ['カフェ', 'cafe', 'coffee'], _cafeKeywords)) {
      tags.addAll([ExpenseJudgeTag.cafe, ExpenseJudgeTag.discretionary]);
      return ExpenseJudgeResult(
        tags: tags,
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'cafe_detected',
      );
    }

    if (_matchesAnyCategory(categoryLower, store, const ['コンビニ', 'convenience', 'convenience store'], _convenienceKeywords)) {
      tags.addAll([ExpenseJudgeTag.convenience, ExpenseJudgeTag.discretionary]);
      return ExpenseJudgeResult(
        tags: tags,
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'convenience_detected',
      );
    }

    if (_matchesAnyCategory(categoryLower, store, const ['スーパー', 'supermarket', 'grocery', 'groceries'], _supermarketKeywords)) {
      tags.addAll([
        ExpenseJudgeTag.supermarket,
        ExpenseJudgeTag.essential,
        if (amount >= 3000) ExpenseJudgeTag.bulkBuy,
      ]);
      return ExpenseJudgeResult(
        tags: tags,
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'supermarket_detected',
      );
    }

    if (_containsAny(store, _ceremonyKeywords) ||
        _categoryIn(categoryLower, const ['冠婚葬祭', 'お祝い', '贈り物', 'ceremony', 'gift', 'gifts', 'celebration'])) {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.ceremony, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'ceremony_detected',
      );
    }

    if (_containsAny(store, _drinkingKeywords) || _categoryIn(categoryLower, const ['飲み', '居酒屋', 'drinking', 'bar', 'pub'])) {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.drinking, ExpenseJudgeTag.social, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'drinking_detected',
      );
    }

    if (_containsAny(store, _fashionKeywords) || _categoryIn(categoryLower, const ['服', 'ファッション', 'fashion', 'clothes', 'clothing', 'apparel'])) {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.fashion, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'fashion_detected',
      );
    }

    if (_containsAny(store, _dailyGoodsKeywords) || _categoryIn(categoryLower, const ['日用品', 'daily goods', 'household', 'household goods'])) {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.dailyGoods, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'daily_goods_detected',
      );
    }

    if (_containsAny(store, _movieKeywords) ||
        _categoryIn(categoryLower, const ['映画', '娯楽', 'エンタメ', 'レジャー', 'movie', 'movies', 'cinema', 'entertainment', 'leisure'])) {
      return ExpenseJudgeResult(
        tags: const [
          ExpenseJudgeTag.movie,
          ExpenseJudgeTag.entertainment,
          ExpenseJudgeTag.discretionary,
        ],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'movie_detected',
      );
    }

    if (_containsAny(store, _karaokeKeywords) ||
        _categoryIn(categoryLower, const ['カラオケ', '娯楽', 'エンタメ', 'レジャー', 'ストレス発散', 'karaoke', 'entertainment', 'leisure', 'stress relief'])) {
      return ExpenseJudgeResult(
        tags: const [
          ExpenseJudgeTag.karaoke,
          ExpenseJudgeTag.entertainment,
          ExpenseJudgeTag.discretionary,
        ],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'karaoke_detected',
      );
    }

    if (_containsAny(store, _arcadeKeywords) ||
        _categoryIn(categoryLower, const ['ゲームセンター', '娯楽', 'エンタメ', 'レジャー', '遊び', 'arcade', 'game center', 'entertainment', 'leisure', 'play'])) {
      return ExpenseJudgeResult(
        tags: const [
          ExpenseJudgeTag.arcade,
          ExpenseJudgeTag.entertainment,
          ExpenseJudgeTag.discretionary,
        ],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'arcade_detected',
      );
    }

    if (_containsAny(store, _entertainmentKeywords) || _categoryIn(categoryLower, const ['娯楽', 'エンタメ', 'レジャー', 'entertainment', 'leisure'])) {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.entertainment, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'entertainment_detected',
      );
    }

    if (_containsAny(store, _travelKeywords) || _categoryIn(categoryLower, const ['旅行', 'travel', 'trip', 'hotel'])) {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.travel, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'travel_detected',
      );
    }

    if (_containsAny(store, _onlineShoppingKeywords) ||
        _categoryIn(categoryLower, const ['ネットショッピング', '通販', '日用品', '服', 'online shopping', 'shopping', 'e-commerce', 'ecommerce', 'daily goods', 'clothing', 'fashion'])) {
      return ExpenseJudgeResult(
        tags: const [
          ExpenseJudgeTag.onlineShopping,
          ExpenseJudgeTag.discretionary,
        ],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'online_shopping_detected',
      );
    }

    if (_containsAny(store, _kidsKeywords) ||
        _categoryIn(categoryLower, const ['子ども', '子供', '育児', 'kids', 'children', 'childcare', 'family'])) {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.kids, ExpenseJudgeTag.family, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'kids_detected',
      );
    }

    if (_containsAny(store, _sensitiveKeywords) ||
        _categoryIn(
          categoryLower,
          const [
            'センシティブ',
            'sensitive',
            'adult',
            'adult entertainment',
          ],
        )) {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.sensitive],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'sensitive_detected',
      );
    }

    if (_containsAny(store, _gamblingKeywords) || _categoryIn(categoryLower, const ['ギャンブル', 'gambling', 'casino', 'betting'])) {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.gambling, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'gambling_detected',
      );
    }

    if (_containsAny(store, _luxuryKeywords) ||
        _categoryIn(categoryLower, const ['高級品', 'ブランド', 'luxury', 'brand', 'premium'])) {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.luxury, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'luxury_detected',
      );
    }

    if (_matchesAnyCategory(categoryLower, store, const ['外食', 'dining', 'restaurant', 'restaurants', 'eating out'], const [])) {
      tags.addAll([ExpenseJudgeTag.dining, ExpenseJudgeTag.discretionary]);
      return ExpenseJudgeResult(
        tags: tags,
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'dining_detected',
      );
    }

    if (_containsAny(store, _hobbyKeywords) || _categoryIn(categoryLower, const ['趣味', 'hobby', 'hobbies'])) {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.hobby, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'hobby_detected',
      );
    }

    if (_containsAny(store, _beautyKeywords) || _categoryIn(categoryLower, const ['美容', 'beauty', 'self-care', 'self care', 'cosmetics'])) {
      return ExpenseJudgeResult(
        tags: const [ExpenseJudgeTag.beauty, ExpenseJudgeTag.discretionary],
        severity: _severityFromRate(spendingRate),
        shouldNotify: true,
        shouldAskAi: false,
        reasonCode: 'beauty_detected',
      );
    }

    if (_containsAny(store, _healthKeywords) ||
        _categoryIn(categoryLower, const ['医療', '健康', '薬', 'health', 'medical', 'medicine', 'pharmacy'])) {
      return const ExpenseJudgeResult(
        tags: [ExpenseJudgeTag.health, ExpenseJudgeTag.essential],
        severity: ExpenseJudgeSeverity.normal,
        shouldNotify: false,
        shouldAskAi: false,
        reasonCode: 'health_detected',
      );
    }

    if (_containsAny(store, _transportKeywords) ||
        _categoryIn(categoryLower, const ['交通', '交通費', '電車', 'バス', 'ガソリン', '駐車場', 'transport', 'transportation', 'train', 'bus', 'taxi', 'gas', 'parking'])) {
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

  static bool _matchesAnyCategory(
    String categoryLower,
    String store,
    List<String> exactCategories,
    List<String> keywords,
  ) {
    if (_categoryIn(categoryLower, exactCategories)) return true;
    return _containsAny(store, keywords);
  }

  static bool _categoryIn(String categoryLower, List<String> candidates) {
    return candidates.any((c) => categoryLower == c.toLowerCase());
  }

  static bool _containsAny(String value, List<String> keywords) {
    final normalizedValue = _normalizeForMatch(value);
    final tokens = _tokenizeForMatch(normalizedValue);

    return keywords.any((keyword) {
      final normalizedKeyword = _normalizeForMatch(keyword);
      if (normalizedKeyword.isEmpty) return false;

      if (_requiresTokenMatch(normalizedKeyword)) {
        return tokens.contains(normalizedKeyword);
      }

      return normalizedValue.contains(normalizedKeyword);
    });
  }

  static String _normalizeForMatch(String value) {
    return value
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Set<String> _tokenizeForMatch(String value) {
    return value
        .split(RegExp(r'[^a-z0-9ぁ-んァ-ン一-龥ー]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  static bool _requiresTokenMatch(String keyword) {
    return const {
      'bar',
      'gas',
      'inn',
      'bus',
      'jr',
      'gu',
      'hm',
      'gap',
      'pub',
      'spa',
      'zoo',
      'ana',
      'jal',
      'slot',
      'watch',
      'gift',
      'gifts',
      'toy',
      'toys',
    }.contains(keyword);
  }

  static ExpenseJudgeSeverity _severityFromRate(double rate) {
    if (rate >= 0.2) return ExpenseJudgeSeverity.danger;
    if (rate >= 0.1) return ExpenseJudgeSeverity.warning;
    return ExpenseJudgeSeverity.normal;
  }
}
