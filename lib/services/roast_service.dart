import 'package:saiyome/models/expense.dart';
import 'package:saiyome/services/expense_judge_service.dart';
import 'package:saiyome/services/spending_rule_service.dart';


class RoastResult {
  final String title;
  final String message;
  final String subMessage;
  final String notificationBody;
  final String scenarioKey;

  const RoastResult({
    required this.title,
    required this.message,
    required this.subMessage,
    required this.notificationBody,
    required this.scenarioKey,
  });
}

class _MonthlyComment {
  final String scenarioKey;
  final String notificationBody;
  final String message;
  final String subMessage;

  const _MonthlyComment({
    required this.scenarioKey,
    required this.notificationBody,
    required this.message,
    required this.subMessage,
  });
}


class _LatestComment {
  final String scenarioKey;
  final String notificationBody;
  final String message;
  final String subMessage;
  final int priority;

  const _LatestComment({
    required this.scenarioKey,
    required this.notificationBody,
    required this.message,
    required this.subMessage,
    this.priority = 0,
  });
}

class _MonthlyCategoryMetrics {
  final int count;
  final int amount;
  final int average;
  final double usageRatio;

  const _MonthlyCategoryMetrics({
    required this.count,
    required this.amount,
    required this.average,
    required this.usageRatio,
  });
}

class _MonthlyCategoryRule {
  final int? heavyHitMaxCount;
  final double? heavyHitMinRatio;
  final int? repeatMinCount;
  final double? repeatMinRatio;
  final int? repeatMinAverage;
  final int? dripMinCount;
  final double? dripMinRatio;
  final int? dripMinAverage;
  final int? dripMaxAverage;

  const _MonthlyCategoryRule({
    this.heavyHitMaxCount,
    this.heavyHitMinRatio,
    this.repeatMinCount,
    this.repeatMinRatio,
    this.repeatMinAverage,
    this.dripMinCount,
    this.dripMinRatio,
    this.dripMinAverage,
    this.dripMaxAverage,
  });
}

class _MonthlyCategoryCopySet {
  final List<({String message, String subMessage})>? heavyHitVariants;
  final List<({String message, String subMessage})>? repeatVariants;
  final List<({String message, String subMessage})>? dripVariants;

  const _MonthlyCategoryCopySet({
    this.heavyHitVariants,
    this.repeatVariants,
    this.dripVariants,
  });
}

class RoastService {
  static String _normalizeLang(String? languageCode) {
    return languageCode == 'en' ? 'en' : 'ja';
  }

  static bool _isEnglish(String languageCode) {
    return _normalizeLang(languageCode) == 'en';
  }

  static String _t(String languageCode, String ja, String en) {
    return _isEnglish(languageCode) ? en : ja;
  }

  static String _noteTitle(String languageCode) {
    return _t(languageCode, '財布からひとこと', 'A note from your wallet');
  }

  static String _formatMoney(int amount, String languageCode) {
    if (_isEnglish(languageCode)) {
      final dollars = amount / 100.0;
      return '\$${dollars.toStringAsFixed(2)}';
    }
    return '$amount円';
  }
  static const List<String> cafeKeywords = [
    'スタバ',
    'スターバックス',
    'starbucks',
    'コメダ',
    'コメダ珈琲',
    'ドトール',
    'タリーズ',
    'tully',
    'doutor',
    'cafe',
    'カフェ',
    'coffee',
    'espresso',
    'latte',
    'cappuccino',
    'costa',
    'peets',
    'blue bottle',
    'tim hortons',
  ];

  static const List<String> convenienceKeywords = [
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
    'convenience',
    'mini stop',
  ];

  static const List<String> onlineShoppingKeywords = [
    'amazon',
    '楽天',
    'rakuten',
    'yahoo',
    'zozo',
    'qoo10',
    'メルカリ',
    'mercari',
    'shop',
    '通販',
    'ebay',
    'aliexpress',
    'shein',
    'temu',
    'etsy',
    'store',
    'online',
  ];

  static bool _isCafe(Expense e) {
    final name = e.storeName.toLowerCase();
    final category = e.category.trim().toLowerCase();
    if (category == 'カフェ' || category == 'cafe' || category == 'coffee') return true;
    return cafeKeywords.any((k) => name.contains(k.toLowerCase()));
  }

  static bool _isConvenience(Expense e) {
    final name = e.storeName.toLowerCase();
    final category = e.category.trim().toLowerCase();
    if (category == 'コンビニ' ||
        category == 'convenience' ||
        category == 'convenience store') {
      return true;
    }
    return convenienceKeywords.any((k) => name.contains(k.toLowerCase()));
  }

  static bool _isDining(Expense e) {
    final category = e.category.trim().toLowerCase();
    return category == '外食' ||
        category == 'dining' ||
        category == 'restaurant' ||
        category == 'restaurants' ||
        category == 'eating out';
  }

  static bool _isOnlineShopping(Expense e) {
    final name = e.storeName.toLowerCase();
    final category = e.category.trim().toLowerCase();
    if (category == 'ネットショッピング' ||
        category == '通販' ||
        category == 'online shopping' ||
        category == 'shopping' ||
        category == 'e-commerce' ||
        category == 'ecommerce') {
      return true;
    }
    return onlineShoppingKeywords.any((k) => name.contains(k.toLowerCase()));
  }

  static int _consecutiveOnlineShoppingCount(List<Expense> expenses) {
    if (expenses.isEmpty) return 0;

    var count = 0;
    for (final expense in expenses) {
      if (!_isOnlineShopping(expense)) break;
      count++;
    }
    return count;
  }

  static int _sumAmountByTag(
    List<Expense> expenses,
    ExpenseJudgeTag tag,
    int totalBudget,
  ) {
    var sum = 0;
    for (final expense in expenses) {
      if (_hasTag(expense, tag, totalBudget)) {
        sum += expense.amount;
      }
    }
    return sum;
  }

  static int _sumAmountByCategory(List<Expense> expenses, String category) {
    var sum = 0;
    for (final expense in expenses) {
      if (expense.category == category) {
        sum += expense.amount;
      }
    }
    return sum;
  }

  static int _averageAmount(int totalAmount, int count) {
    if (count <= 0) return 0;
    return (totalAmount / count).round();
  }

  static double _usageRatio(int amount, int totalBudget) {
    if (totalBudget <= 0) return 0.0;
    return amount / totalBudget;
  }

    static String _timeTone(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 22 || hour <= 2) return 'late_night';
    if (hour >= 5 && hour <= 10) return 'morning';
    if (hour >= 18 && hour <= 21) return 'evening';
    return 'daytime';
  }

  static bool _isWeekend(DateTime dateTime) {
    return dateTime.weekday == DateTime.saturday ||
        dateTime.weekday == DateTime.sunday;
  }

  static bool _hasTag(Expense expense, ExpenseJudgeTag tag, int totalBudget) {
    final judge = ExpenseJudgeService.judge(
      expense: expense,
      totalBudget: totalBudget,
    );
    return judge.tags.contains(tag);
  }

  static int _consecutiveTagCount(
    List<Expense> expenses,
    ExpenseJudgeTag tag,
    int totalBudget,
  ) {
    if (expenses.isEmpty) return 0;

    var count = 0;
    for (final expense in expenses) {
      if (!_hasTag(expense, tag, totalBudget)) break;
      count++;
    }
    return count;
  }

  static int _dailyVariantIndex(String scenarioKey, int length) {
    if (length <= 1) return 0;
    final now = DateTime.now();
    final seed = '${now.year}-${now.month}-${now.day}-$scenarioKey'.hashCode;
    return seed.abs() % length;
  }

  static ({String message, String subMessage}) _pickVariant(
    String scenarioKey,
    List<({String message, String subMessage})> variants,
  ) {
    final index = _dailyVariantIndex(scenarioKey, variants.length);
    return variants[index];
  }

  static RoastResult _composeResult({
    required String title,
    required String scenarioKey,
    required String notificationBody,
    String? leadMessage,
    String? leadSubMessage,
    required String mainMessage,
    required String mainSubMessage,
  }) {
    return RoastResult(
      title: title,
      message: mainMessage,
      subMessage: [
        mainSubMessage,
        if (leadMessage != null && leadMessage.isNotEmpty) leadMessage,
        if (leadSubMessage != null && leadSubMessage.isNotEmpty) leadSubMessage,
      ].join('\n'),
      notificationBody: notificationBody,
      scenarioKey: scenarioKey,
    );
  }

  static RoastResult _composeLayeredResult({
    required String languageCode,
    String? title,
    String? leadMessage,
    String? leadSubMessage,
    required _MonthlyComment monthly,
    required _LatestComment latest,
    required _LatestComment notificationSource,
  }) {
    final lang = _normalizeLang(languageCode);
    return _composeResult(
      title: title ?? _noteTitle(lang),
      scenarioKey: '${monthly.scenarioKey}_${latest.scenarioKey}',
      notificationBody: [
        notificationSource.message,
        if (notificationSource.subMessage.isNotEmpty)
          notificationSource.subMessage,
      ].join('\n'),
      leadMessage: leadMessage,
      leadSubMessage: leadSubMessage,
      mainMessage: monthly.message,
      mainSubMessage:
          '${monthly.subMessage}\n${latest.message}\n${latest.subMessage}',
    );
  }


  //       static bool _shouldOverrideLatestWithOverallOver(String scenarioKey) {
  //   return scenarioKey == 'default' ||
  //       scenarioKey == 'latest_unknown' ||
  //       scenarioKey == 'latest_ai_suggested' ||
  //       scenarioKey == 'latest_cafe' ||
  //       scenarioKey == 'latest_convenience' ||
  //       scenarioKey == 'latest_dining' ||
  //       scenarioKey == 'latest_online_shopping' ||
  //       scenarioKey == 'latest_movie' ||
  //       scenarioKey == 'latest_karaoke' ||
  //       scenarioKey == 'latest_arcade' ||
  //       scenarioKey == 'store_repeat' ||
  //       scenarioKey == 'consecutive_store';
  // }

  static _LatestComment? _higherPriorityLatestComment(
    _LatestComment? current,
    _LatestComment? candidate,
  ) {
    if (candidate == null) return current;
    if (current == null) return candidate;
    return candidate.priority > current.priority ? candidate : current;
  }

  static _LatestComment? _buildPriorityLatestComment({
    required String languageCode,
    required int convenienceCount,
    required int cafeCount,
    required int diningCount,
    required int onlineShoppingCount,
    required Expense latestExpense,
    required String latestStore,
    required int latestStoreCount,
    required int amount,
    required double spendingRate,
    required int remainingBudget,
    required int? remainingPerDay,
    required int? daysLeft,
  }) {
    final lang = _normalizeLang(languageCode);
    final isEn = _isEnglish(lang);
    _LatestComment? best;

    if (latestStore.isNotEmpty && latestStoreCount >= 10) {
      final variant = _pickVariant('priority_store_repeat_strong_$latestStore', isEn
          ? [
              (
                message: '$latestStore again, huh',
                subMessage: '$latestStoreCount times this month. That is basically a routine now.',
              ),
              (
                message: 'You really like $latestStore',
                subMessage: 'Already $latestStoreCount visits. This is turning into a habit.',
              ),
              (
                message: '$latestStore shows up a lot',
                subMessage: '$latestStoreCount times this month. Even the wallet memorized it.',
              ),
            ]
          : [
              (
                message: 'また$latestStoreだね',
                subMessage: '今月$latestStoreCount回目だよ。かなりおなじみだね。',
              ),
              (
                message: '$latestStore、好きだね',
                subMessage: 'もう$latestStoreCount回目だよ。ここまで来ると常連ペースだね。',
              ),
              (
                message: '$latestStore、よく見るよ',
                subMessage: '今月$latestStoreCount回目。財布もさすがに覚えてきたよ。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_store_repeat_strong',
          notificationBody: _t(
            lang,
            '$latestStore の支出が今月$latestStoreCount回あるね。',
            '$latestStore has $latestStoreCount visits this month.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 102,
        ),
      );
    } else if (latestStore.isNotEmpty && latestStoreCount >= 5) {
      final variant = _pickVariant('priority_store_repeat_mid_$latestStore', isEn
          ? [
              (
                message: '$latestStore again, huh',
                subMessage: '$latestStoreCount visits already. It is becoming your go-to spot.',
              ),
              (
                message: '$latestStore shows up a lot',
                subMessage: 'You are at $latestStoreCount times. Might be worth noticing the pattern.',
              ),
              (
                message: '$latestStore is getting familiar',
                subMessage: '$latestStoreCount visits this month. The wallet is starting to recognize it.',
              ),
            ]
          : [
              (
                message: '$latestStore、また来たね',
                subMessage: '今月$latestStoreCount回目だよ。ちょっと通い慣れてきたね。',
              ),
              (
                message: '$latestStore、出番多いね',
                subMessage: '$latestStoreCount回まで来たよ。そろそろクセになってるかもね。',
              ),
              (
                message: '$latestStore、見覚えあるね',
                subMessage: '今月$latestStoreCount回目。財布もだんだん覚えてきたよ。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_store_repeat_mid',
          notificationBody: _t(
            lang,
            '$latestStore の支出が今月$latestStoreCount回あるね。',
            '$latestStore shows up $latestStoreCount times this month.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 92,
        ),
      );
    } else if (latestStore.isNotEmpty && latestStoreCount >= 3) {
      final variant = _pickVariant('priority_store_repeat_light_$latestStore', isEn
          ? [
              (
                message: '$latestStore again',
                subMessage: '$latestStoreCount times so far. A small pattern is forming.',
              ),
              (
                message: '$latestStore is popping up',
                subMessage: '$latestStoreCount visits. Not big yet, but noticeable.',
              ),
              (
                message: '$latestStore, I have seen this',
                subMessage: '$latestStoreCount times this month. Just keeping an eye on it.',
              ),
            ]
          : [
              (
                message: '$latestStore、また出たね',
                subMessage: '今月$latestStoreCount回目だよ。少し流れ見えてきたね。',
              ),
              (
                message: '$latestStore、ちょい多めだね',
                subMessage: '$latestStoreCount回目。まだ軽いけど、ちゃんと残るやつだね。',
              ),
              (
                message: '$latestStore、よく見るね',
                subMessage: '今月$latestStoreCount回目。少しずつ存在感出てきたね。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_store_repeat_light',
          notificationBody: _t(
            lang,
            '$latestStore の支出が今月$latestStoreCount回あるね。',
            '$latestStore has appeared $latestStoreCount times this month.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 82,
        ),
      );
    }

    if (convenienceCount >= 4) {
      final variant = _pickVariant('priority_convenience_repeat_$lang', isEn
          ? [
              (
                message: 'Convenience stores are adding up',
                subMessage: '$convenienceCount visits this month. Easy stops have a way of quietly becoming a pattern.',
              ),
              (
                message: 'Convenience store again, huh',
                subMessage: '$convenienceCount times already. Small trips, not-so-small footprint.',
              ),
              (
                message: 'The convenience store is showing up a lot',
                subMessage: '$convenienceCount visits this month. Handy, yes. Invisible, not anymore.',
              ),
            ]
          : [
              (
                message: 'コンビニ、積み上がってるね',
                subMessage: '今月$convenienceCount回だよ。手軽さって、静かにクセになるね。',
              ),
              (
                message: 'またコンビニだね',
                subMessage: '$convenienceCount回目だよ。小さく見えて、ちゃんと残るやつだね。',
              ),
              (
                message: 'コンビニ、よく見るね',
                subMessage: '今月$convenienceCount回。便利だけど、もう見えない支出ではないね。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_convenience_repeat',
          notificationBody: _t(
            lang,
            'コンビニ支出が今月$convenienceCount回あるよ。',
            'Convenience store spending showed up $convenienceCount times this month.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 100,
        ),
      );
    }

    if (onlineShoppingCount >= 3) {
      final variant = _pickVariant('priority_online_repeat_$lang', isEn
          ? [
              (
                message: 'Online orders are stacking up',
                subMessage: '$onlineShoppingCount times this month. One tap is light, the trail is not.',
              ),
              (
                message: 'Another online purchase pattern',
                subMessage: '$onlineShoppingCount orders so far. The cart is starting to leave footprints.',
              ),
              (
                message: 'Online shopping is getting loud',
                subMessage: '$onlineShoppingCount times this month. The screen was quick, but the budget remembers.',
              ),
            ]
          : [
              (
                message: 'ネット購入、増えてきたね',
                subMessage: '今月$onlineShoppingCount回だよ。ワンタップは軽いけど、跡はちゃんと残るね。',
              ),
              (
                message: 'またポチったね',
                subMessage: '$onlineShoppingCount回目だよ。カートの足あと、少し見えてきたね。',
              ),
              (
                message: 'ネット率、高めだね',
                subMessage: '今月$onlineShoppingCount回。画面では一瞬でも、予算はちゃんと覚えてるよ。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_online_repeat',
          notificationBody: _t(
            lang,
            'ネットショッピング支出が今月$onlineShoppingCount回あるよ。',
            'Online shopping showed up $onlineShoppingCount times this month.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 98,
        ),
      );
    }

    if (cafeCount >= 4) {
      final variant = _pickVariant('priority_cafe_repeat_$lang', isEn
          ? [
              (
                message: 'Cafes are adding up',
                subMessage: '$cafeCount visits this month. Small comfort, steady impact.',
              ),
              (
                message: 'Cafe again, huh',
                subMessage: '$cafeCount times already. Feels routine now, doesn’t it?',
              ),
              (
                message: 'You really like cafes',
                subMessage: '$cafeCount visits this month. The habit is starting to show.',
              ),
            ]
          : [
              (
                message: 'カフェ、多いね',
                subMessage: '今月$cafeCount回だよ。ちょっとした余裕が、そのままクセになってるね。',
              ),
              (
                message: 'またカフェだね',
                subMessage: '$cafeCount回目だよ。気づいたらルーティンっぽくなってきたね。',
              ),
              (
                message: 'カフェ、好きだね',
                subMessage: '今月$cafeCount回。心地よさのぶん、ちゃんと残るやつだね。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_cafe_repeat',
          notificationBody: _t(
            lang,
            'カフェ支出が今月$cafeCount回あるよ。',
            'Cafe spending showed up $cafeCount times this month.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 96,
        ),
      );
    }

    if (diningCount >= 3) {
      final variant = _pickVariant('priority_dining_repeat_$lang', isEn
          ? [
              (
                message: 'Eating out is picking up',
                subMessage: '$diningCount times this month. Fun now, but it adds up quietly.',
              ),
              (
                message: 'Dining out again, huh',
                subMessage: '$diningCount visits already. The pace is getting noticeable.',
              ),
              (
                message: 'Dining is becoming a pattern',
                subMessage: '$diningCount times this month. Enjoyable, but not invisible anymore.',
              ),
            ]
          : [
              (
                message: '外食、増えてきたね',
                subMessage: '今月$diningCount回だよ。楽しいけど、ちゃんと積み上がってるね。',
              ),
              (
                message: 'また外食だね',
                subMessage: '$diningCount回目だよ。少しペース出てきてるね。',
              ),
              (
                message: '外食、流れできてるね',
                subMessage: '今月$diningCount回。楽しさのぶん、財布にも残ってるよ。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_dining_repeat',
          notificationBody: _t(
            lang,
            '外食支出が今月$diningCount回あるよ。',
            'Dining out showed up $diningCount times this month.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 94,
        ),
      );
    }

    if (spendingRate >= 0.25) {
      final moneyText = _formatMoney(amount, lang);

      final variant = _pickVariant('priority_expensive_spending_$lang', isEn
          ? [
              (
                message: '$moneyText, that is a big hit',
                subMessage: '${latestExpense.storeName} just made a noticeable dent. This could shift the month’s flow.',
              ),
              (
                message: 'That one is heavy',
                subMessage: '$moneyText carries weight. The wallet definitely felt that.',
              ),
              (
                message: '${latestExpense.storeName} hit hard',
                subMessage: '$moneyText in one go. Big enough to change the rhythm this month.',
              ),
            ]
          : [
              (
                message: '$amount円、でかいね',
                subMessage: '${latestExpense.storeName}の一撃だよ。今月の流れにもけっこう響きそうだね。',
              ),
              (
                message: 'これは重いね',
                subMessage: '$amount円はなかなかの存在感だよ。財布もちゃんと反応してる。',
              ),
              (
                message: '${latestExpense.storeName}、一撃強めだね',
                subMessage: '$amount円。単発でも、今月の流れを変えそうなサイズだよ。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_expensive_spending',
          notificationBody: _t(
            lang,
            '${latestExpense.storeName}、大きめの一撃だよ。',
            '${latestExpense.storeName} made a big impact.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 82,
        ),
      );
    } else if (spendingRate >= 0.15) {
      final moneyText = _formatMoney(amount, lang);

      final variant = _pickVariant('priority_mid_spending_$lang', isEn
          ? [
              (
                message: '$moneyText, not small',
                subMessage: '${latestExpense.storeName} has some weight. This will linger a bit.',
              ),
              (
                message: 'That one will stick',
                subMessage: '$moneyText is not huge, but it will quietly add up.',
              ),
              (
                message: '${latestExpense.storeName} has presence',
                subMessage: '$moneyText. Feels light now, but might hit later.',
              ),
            ]
          : [
              (
                message: '$amount円、ちょい重めだね',
                subMessage: '${latestExpense.storeName}の支出だよ。今月の余裕にじわっと効きそうだね。',
              ),
              (
                message: 'これは少し効くね',
                subMessage: '$amount円。小さくはないから、財布も見逃してないね。',
              ),
              (
                message: '${latestExpense.storeName}、存在感あるね',
                subMessage: '今回の$amount円は、あとで効いてくるタイプかもね。',
              ),
            ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_mid_spending',
          notificationBody: _t(
            lang,
            '${latestExpense.storeName}でやや大きめの支出を記録したよ。',
            'A moderately large expense at ${latestExpense.storeName}.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 78,
        ),
      );
    }

    if (remainingPerDay != null &&
        daysLeft != null &&
        daysLeft > 0 &&
        remainingBudget > 0) {
      if (remainingPerDay <= 150) {
        final variant = _pickVariant('priority_remaining_per_day_critical_$lang', isEn
            ? [
                (
                  message: 'Running thin now',
                  subMessage: '$remainingBudget left for $daysLeft days. There is almost no room per day.',
                ),
                (
                  message: 'This is survival mode',
                  subMessage: '$remainingBudget over $daysLeft days. Every move counts now.',
                ),
                (
                  message: 'Is the wallet still breathing?',
                  subMessage: '$daysLeft days left with $remainingBudget. Each expense hits hard now.',
                ),
              ]
            : [
                (
                  message: '残り、かなり薄いね',
                  subMessage: 'あと$daysLeft日で$remainingBudget円だよ。1日ごとの余白はほぼないね。',
                ),
                (
                  message: 'ここから耐久戦だね',
                  subMessage: '残り$remainingBudget円であと$daysLeft日。かなり慎重モードだよ。',
                ),
                (
                  message: '財布、息してる…？',
                  subMessage: 'あと$daysLeft日あるのに残り$remainingBudget円だよ。ここからは一回ずつ重いね。',
                ),
              ]);

        best = _higherPriorityLatestComment(
          best,
          _LatestComment(
            scenarioKey: 'priority_remaining_per_day_critical',
            notificationBody: _t(
              lang,
              '残り予算がかなり厳しくなっているよ。',
              'Your remaining budget is getting very tight.',
            ),
            message: variant.message,
            subMessage: variant.subMessage,
            priority: 92,
          ),
        );
      } else if (remainingPerDay <= 300) {
        final variant = _pickVariant('priority_remaining_per_day_warning_$lang', isEn
            ? [
                (
                  message: 'Getting a bit tight',
                  subMessage: '$remainingBudget left for $daysLeft days. Might need to pace things now.',
                ),
                (
                  message: 'Distribution matters now',
                  subMessage: '$remainingBudget across $daysLeft days. Spending loosely could hurt later.',
                ),
                (
                  message: 'Feels like endgame',
                  subMessage: '$daysLeft days left, $remainingBudget remaining. Playing it safe might help.',
                ),
              ]
            : [
                (
                  message: '残り、細めだね',
                  subMessage: 'あと$daysLeft日で$remainingBudget円だよ。ここからは少し慎重にいこう。',
                ),
                (
                  message: '配分、ちょい大事だね',
                  subMessage: '残り$remainingBudget円であと$daysLeft日。雑に使うとすぐ苦しくなりそうだよ。',
                ),
                (
                  message: '終盤戦っぽくなってきたね',
                  subMessage: 'あと$daysLeft日、残り$remainingBudget円。少し守り気味でちょうどいいかもね。',
                ),
              ]);

        best = _higherPriorityLatestComment(
          best,
          _LatestComment(
            scenarioKey: 'priority_remaining_per_day_warning',
            notificationBody: _t(
              lang,
              '残り予算の配分を意識したい状態だね。',
              'You may want to watch how you pace your remaining budget.',
            ),
            message: variant.message,
            subMessage: variant.subMessage,
            priority: 76,
          ),
        );
      }
    }

    return best;
  }

  static _MonthlyComment _defaultMonthlyComment(String languageCode) {
    final lang = _normalizeLang(languageCode);
    final isEn = _isEnglish(lang);

    final variant = _pickVariant('monthly_normal_$lang', isEn
        ? [
            (
              message: 'Nothing is falling apart this month',
              subMessage: 'The flow is stable. A bit of awareness should be enough to keep things on track.',
            ),
            (
              message: 'Still holding steady',
              subMessage: 'No major issues so far. Just keep an eye on the pace.',
            ),
            (
              message: 'Looking balanced so far',
              subMessage: 'No big swings. A little attention will go a long way.',
            ),
          ]
        : [
            (
              message: '今月は大きく崩れてはないよ。',
              subMessage: 'このまま流れを見ながら、ゆるく整えていけそうだね。',
            ),
            (
              message: 'まだ安定してるね',
              subMessage: '大きな乱れはないよ。このまま少しだけ意識していこう。',
            ),
            (
              message: 'バランスいい感じだね',
              subMessage: '今のところ大きな偏りはないよ。この流れキープしたいね。',
            ),
          ]);

    return _MonthlyComment(
      scenarioKey: 'monthly_normal',
      notificationBody: '',
      message: variant.message,
      subMessage: variant.subMessage,
    );
  }

  static _MonthlyCategoryMetrics _buildMonthlyCategoryMetrics({
    required int count,
    required int amount,
    required int totalBudget,
  }) {
    return _MonthlyCategoryMetrics(
      count: count,
      amount: amount,
      average: _averageAmount(amount, count),
      usageRatio: _usageRatio(amount, totalBudget),
    );
  }

  static bool _matchesMonthlyCategoryRule(
    _MonthlyCategoryMetrics metrics,
    _MonthlyCategoryRule rule,
  ) {
    final heavyHitMatched =
        rule.heavyHitMaxCount != null &&
        rule.heavyHitMinRatio != null &&
        metrics.count <= rule.heavyHitMaxCount! &&
        metrics.usageRatio >= rule.heavyHitMinRatio!;

    final repeatMatched =
        rule.repeatMinCount != null &&
        rule.repeatMinRatio != null &&
        metrics.count >= rule.repeatMinCount! &&
        metrics.usageRatio >= rule.repeatMinRatio! &&
        (rule.repeatMinAverage == null ||
            metrics.average >= rule.repeatMinAverage!);

    final dripMatched =
        rule.dripMinCount != null &&
        rule.dripMinRatio != null &&
        metrics.count >= rule.dripMinCount! &&
        metrics.usageRatio >= rule.dripMinRatio! &&
        (rule.dripMinAverage == null || metrics.average >= rule.dripMinAverage!) &&
        (rule.dripMaxAverage == null || metrics.average <= rule.dripMaxAverage!);

    return heavyHitMatched || repeatMatched || dripMatched;
  }

  static _MonthlyComment? _buildCategoryMonthlyComment({
    required String baseKey,
    required String notificationBody,
    required _MonthlyCategoryMetrics metrics,
    required _MonthlyCategoryRule rule,
    required _MonthlyCategoryCopySet copySet,
  }) {
    if (!_matchesMonthlyCategoryRule(metrics, rule)) {
      return null;
    }

    final percentText = (metrics.usageRatio * 100).toStringAsFixed(0);

    final isHeavyHit =
        rule.heavyHitMaxCount != null &&
        rule.heavyHitMinRatio != null &&
        metrics.count <= rule.heavyHitMaxCount! &&
        metrics.usageRatio >= rule.heavyHitMinRatio!;

    final isDrip =
        !isHeavyHit &&
        rule.dripMinCount != null &&
        rule.dripMinRatio != null &&
        metrics.count >= rule.dripMinCount! &&
        metrics.usageRatio >= rule.dripMinRatio! &&
        (rule.dripMinAverage == null || metrics.average >= rule.dripMinAverage!) &&
        (rule.dripMaxAverage == null || metrics.average <= rule.dripMaxAverage!);

    final scenarioKey = isHeavyHit
        ? '${baseKey}_heavy_hit'
        : isDrip
            ? '${baseKey}_drip'
            : '${baseKey}_repeat';

    final variants = isHeavyHit
        ? copySet.heavyHitVariants
        : isDrip
            ? copySet.dripVariants
            : copySet.repeatVariants;

    if (variants == null || variants.isEmpty) {
      return null;
    }

    final resolvedVariants = variants
        .map(
          (variant) => (
            message: variant.message
                .replaceAll('{count}', '${metrics.count}')
                .replaceAll('{amount}', '${metrics.amount}')
                .replaceAll('{average}', '${metrics.average}')
                .replaceAll('{percent}', percentText),
            subMessage: variant.subMessage
                .replaceAll('{count}', '${metrics.count}')
                .replaceAll('{amount}', '${metrics.amount}')
                .replaceAll('{average}', '${metrics.average}')
                .replaceAll('{percent}', percentText),
          ),
        )
        .toList();

    final variant = _pickVariant(scenarioKey, resolvedVariants);

    return _MonthlyComment(
      scenarioKey: scenarioKey,
      notificationBody: notificationBody
          .replaceAll('{count}', '${metrics.count}')
          .replaceAll('{amount}', '${metrics.amount}')
          .replaceAll('{average}', '${metrics.average}')
          .replaceAll('{percent}', percentText),
      message: variant.message,
      subMessage: variant.subMessage,
    );
  }

  static _MonthlyComment _buildMonthlyComment({
    required String languageCode,
    required double overallUsageRate,
    required int totalBudget,
    required List<Map<String, dynamic>> dangerCategories,
    required int cafeCount,
    required int convenienceCount,
    required int diningCount,
    required int onlineShoppingCount,
    required int onlineShoppingAmount,
    required int movieCount,
    required int movieAmount,
    required int karaokeCount,
    required int karaokeAmount,
    required int arcadeCount,
    required int arcadeAmount,
    required int suddenExpenseCount,
    required int suddenExpenseAmount,
  }) {
    final lang = _normalizeLang(languageCode);
    final isEn = _isEnglish(lang);

    if (overallUsageRate >= 1.0) {
      final variant = _pickVariant('overall_over_$lang', isEn
          ? [
              (
                message: 'You are over budget now',
                subMessage:
                    'This month’s limit is already used up. From here, every extra expense will echo into the next month.',
              ),
              (
                message: 'The line has been crossed',
                subMessage:
                    'The budget is already past its limit. Not panic time, but definitely landing-carefully time.',
              ),
              (
                message: 'This month is in overtime',
                subMessage:
                    'Budget-wise, the main game is over. Now it is all about how softly you can land.',
              ),
              (
                message: 'Past the limit now',
                subMessage:
                    'The wallet is not yelling, but it is very much staring. Time to calm the pace down.',
              ),
            ]
          : [
              (
                message: 'もうオーバーしてるね',
                subMessage:
                    '今月の予算は使い切ってるよ。ここからは来月に響きやすいゾーンだね。',
              ),
              (
                message: '完全に越えてるね',
                subMessage:
                    'ここからの支出は、あとで効いてくるやつだよ。焦らず着地を考えたいね。',
              ),
              (
                message: '今月、延長戦だね',
                subMessage:
                    '予算的にはもう本編終了。ここからはどうやわらかく着地させるかだね。',
              ),
              (
                message: 'ライン超えてるね',
                subMessage:
                    '財布は叫んでないけど、かなり見てるよ。少しペースを落ち着かせたいところだね。',
              ),
            ]);

      return _MonthlyComment(
        scenarioKey: 'overall_over',
        notificationBody: _t(
          lang,
          '今月の予算を使い切ったよ。',
          'You have used up this month’s budget.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    final criticalCategory =
        dangerCategories.isNotEmpty ? dangerCategories.first : null;

    if (criticalCategory != null) {
      final criticalName = criticalCategory['name'] as String? ?? 'カテゴリ';
      final criticalBadge = criticalCategory['badge'] as String? ?? '⚠️';
      final criticalUsageRate = criticalCategory['usageRate'] as double? ?? 0.0;

      if (criticalUsageRate >= 0.9) {
        final variant = _pickVariant('category_danger_$lang', isEn
            ? [
                (
                  message: '$criticalBadge $criticalName is pushing the limit',
                  subMessage: 'Almost at the cap. From here, every move carries weight.',
                ),
                (
                  message: '$criticalBadge $criticalName is on the edge',
                  subMessage: 'Very little room left. Each expense will hit harder now.',
                ),
                (
                  message: '$criticalBadge $criticalName is nearly maxed out',
                  subMessage: 'Still recoverable, but this is where things get tight.',
                ),
              ]
            : [
                (
                  message: '$criticalBadge $criticalName、かなり攻めてるね',
                  subMessage: 'もう少しで上限だね。ここからは慎重モードだよ。',
                ),
                (
                  message: '$criticalBadge $criticalName、ギリギリだね',
                  subMessage: 'ここから先は一回ずつ重いね。少し守りたいところだよ。',
                ),
                (
                  message: '$criticalBadge $criticalName、限界近いね',
                  subMessage: 'まだ止められるラインだね。少し落ち着かせたいところだよ。',
                ),
              ]);

        return _MonthlyComment(
          scenarioKey: 'category_danger',
          notificationBody: _t(
            lang,
            '$criticalBadge $criticalName が90%を超えたよ。',
            '$criticalName has exceeded 90% of its budget.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
        );
      }

      if (criticalUsageRate >= 0.75) {
        final variant = _pickVariant('category_warning_$lang', isEn
            ? [
                (
                  message: '$criticalBadge $criticalName is getting close',
                  subMessage: 'This category is starting to show weight. Still time to adjust.',
                ),
                (
                  message: '$criticalBadge $criticalName is moving fast',
                  subMessage: 'Not one big hit, but the buildup is becoming visible.',
                ),
                (
                  message: '$criticalBadge $criticalName is kicking in',
                  subMessage: 'Slowing down now could make the rest of the month much easier.',
                ),
              ]
            : [
                (
                  message: '$criticalBadge $criticalName、そろそろ危ないね',
                  subMessage: 'このカテゴリ、じわっと効いてきてるよ。今ならまだ調整できるよ。',
                ),
                (
                  message: '$criticalBadge $criticalName、ペース早めだね',
                  subMessage: '一回より積み重ねが見えてきたよ。上限が近づいてるよ。',
                ),
                (
                  message: '$criticalBadge $criticalName、効いてきたね',
                  subMessage: 'ここで少し抑えると、後半かなり楽になりそうだよ。',
                ),
              ]);

        return _MonthlyComment(
          scenarioKey: 'category_warning',
          notificationBody: _t(
            lang,
            '$criticalBadge $criticalName が75%を超えたよ。',
            '$criticalName has exceeded 75% of its budget.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
        );
      }
    }


    final cafeComment = _buildCategoryMonthlyComment(
      baseKey: 'cafe_$lang',
      notificationBody: _t(
        lang,
        '今月カフェ{count}回目だよ。',
        'Cafe spending showed up {count} times this month.',
      ),
      metrics: _buildMonthlyCategoryMetrics(
        count: cafeCount,
        amount: cafeCount * 500,
        totalBudget: totalBudget,
      ),
      rule: const _MonthlyCategoryRule(
        repeatMinCount: 5,
        repeatMinRatio: 0.05,
        dripMinCount: 7,
        dripMinRatio: 0.04,
      ),
      copySet: _MonthlyCategoryCopySet(
        repeatVariants: isEn
            ? [
                (
                  message: 'Cafes are showing up a lot',
                  subMessage: '{count} visits and {percent}% of the budget. Small comfort is starting to count.',
                ),
                (
                  message: 'Cafe habit forming',
                  subMessage: '{count} visits so far. It is not loud, but it is definitely present.',
                ),
                (
                  message: 'Cafe rhythm detected',
                  subMessage: 'Already {percent}% of the budget. This is starting to look like a routine.',
                ),
              ]
            : [
                (
                  message: 'カフェ、{count}回だね',
                  subMessage: '予算の{percent}%まで来てるよ。小さな休憩も、ちゃんと積み上がってるね。',
                ),
                (
                  message: 'カフェ習慣、できてきたね',
                  subMessage: '{count}回で{percent}%。静かだけど、ちゃんと存在感あるよ。',
                ),
                (
                  message: 'カフェ、流れできてるね',
                  subMessage: 'ここまでで{percent}%。気づいたらルーティンっぽくなってきてるよ。',
                ),
              ],
        dripVariants: isEn
            ? [
                (
                  message: 'Cafes are quietly stacking up',
                  subMessage: '{count} visits and {percent}% of the budget. Each one feels light, but the pattern is not.',
                ),
                (
                  message: 'Cafe spending is dripping in',
                  subMessage: 'It has reached {percent}% little by little. Quiet, but real.',
                ),
                (
                  message: 'The cafe streak is not stopping',
                  subMessage: '{count} visits. Small comforts are leaving a visible trail.',
                ),
              ]
            : [
                (
                  message: 'カフェ、静かに積んでるね',
                  subMessage: '{count}回で{percent}%。一回ずつは軽いけど、流れとしては見えてきたよ。',
                ),
                (
                  message: 'カフェ、じわっと来てるね',
                  subMessage: '少しずつで{percent}%まで来てるよ。静かだけど、ちゃんと効いてるね。',
                ),
                (
                  message: 'カフェ、止まってないね',
                  subMessage: '{count}回。小さな余白が、そのまま足あとになってるよ。',
                ),
              ],
      ),
    );
    if (cafeComment != null) return cafeComment;

    final convenienceComment = _buildCategoryMonthlyComment(
      baseKey: 'convenience_$lang',
      notificationBody: _t(
        lang,
        'コンビニ{count}回目だよ。',
        'Convenience store spending showed up {count} times this month.',
      ),
      metrics: _buildMonthlyCategoryMetrics(
        count: convenienceCount,
        amount: convenienceCount * 400,
        totalBudget: totalBudget,
      ),
      rule: const _MonthlyCategoryRule(
        repeatMinCount: 5,
        repeatMinRatio: 0.05,
        dripMinCount: 7,
        dripMinRatio: 0.04,
      ),
      copySet: _MonthlyCategoryCopySet(
        repeatVariants: isEn
            ? [
                (
                  message: 'Convenience stores are showing up a lot',
                  subMessage: '{count} visits and {percent}% of the budget. Easy stops are starting to leave a mark.',
                ),
                (
                  message: 'Convenience habit detected',
                  subMessage: '{count} visits so far. Small trips, but the pattern is getting visible.',
                ),
                (
                  message: 'Convenience store rhythm forming',
                  subMessage: 'Already {percent}% of the budget. Quick stops are not so invisible anymore.',
                ),
              ]
            : [
                (
                  message: 'コンビニ、{count}回だね',
                  subMessage: '気軽だけど{percent}%まで来てるよ。小さく見えて、ちゃんと残るやつだね。',
                ),
                (
                  message: 'コンビニ習慣、見えてきたね',
                  subMessage: '{count}回で{percent}%。手軽さって、静かに積み上がるね。',
                ),
                (
                  message: 'コンビニ、流れできてるね',
                  subMessage: 'ここまでで{percent}%。ちょい寄りの積み重ね、見える形になってきたよ。',
                ),
              ],
        dripVariants: isEn
            ? [
                (
                  message: 'Convenience stores are quietly stacking up',
                  subMessage: '{count} visits and {percent}% of the budget. Each one feels small, but the trail is real.',
                ),
                (
                  message: 'Convenience spending is dripping in',
                  subMessage: 'It has reached {percent}% little by little. Quiet, but definitely there.',
                ),
                (
                  message: 'The convenience streak is not stopping',
                  subMessage: '{count} visits. Quick stops are leaving a visible trail.',
                ),
              ]
            : [
                (
                  message: 'コンビニ、静かに積んでるね',
                  subMessage: '{count}回で{percent}%。一回ずつは軽いけど、流れとしては見えてきたよ。',
                ),
                (
                  message: 'コンビニ、じわっと来てるね',
                  subMessage: '少しずつで{percent}%まで来てるよ。軽いけど、ちゃんと効いてるね。',
                ),
                (
                  message: 'コンビニ、止まってないね',
                  subMessage: '{count}回。ちょい寄りの積み重ねが、そのまま足あとになってるよ。',
                ),
              ],
      ),
    );
    if (convenienceComment != null) return convenienceComment;

    final diningComment = _buildCategoryMonthlyComment(
      baseKey: 'dining_$lang',
      notificationBody: _t(
        lang,
        '外食{count}回目だよ。',
        'Dining out showed up {count} times this month.',
      ),
      metrics: _buildMonthlyCategoryMetrics(
        count: diningCount,
        amount: diningCount * 1200,
        totalBudget: totalBudget,
      ),
      rule: const _MonthlyCategoryRule(
        repeatMinCount: 4,
        repeatMinRatio: 0.08,
        dripMinCount: 5,
        dripMinRatio: 0.06,
      ),
      copySet: _MonthlyCategoryCopySet(
        repeatVariants: isEn
            ? [
                (
                  message: 'Eating out is showing up a lot',
                  subMessage: '{count} times and {percent}% of the budget. Fun meals are starting to leave a mark.',
                ),
                (
                  message: 'Dining habit forming',
                  subMessage: '{count} times so far. Enjoyable, yes. Invisible, not anymore.',
                ),
                (
                  message: 'Dining out rhythm detected',
                  subMessage: 'Already {percent}% of the budget. The fun is real, and so is the footprint.',
                ),
              ]
            : [
                (
                  message: '外食、{count}回だね',
                  subMessage: '予算の{percent}%まで来てるよ。楽しい時間も、ちゃんと積み上がってるね。',
                ),
                (
                  message: '外食習慣、見えてきたね',
                  subMessage: '{count}回で{percent}%。楽しさのぶん、ちゃんと存在感あるよ。',
                ),
                (
                  message: '外食、流れできてるね',
                  subMessage: 'ここまでで{percent}%。後半の余裕は少し見ておきたいね。',
                ),
              ],
        dripVariants: isEn
            ? [
                (
                  message: 'Dining out is quietly stacking up',
                  subMessage: '{count} times and {percent}% of the budget. Each meal feels worth it, but the pattern is visible.',
                ),
                (
                  message: 'Eating out is dripping in',
                  subMessage: 'It has reached {percent}% little by little. Good meals, real footprint.',
                ),
                (
                  message: 'The dining streak is not stopping',
                  subMessage: '{count} times. The good food trail is getting easier to see.',
                ),
              ]
            : [
                (
                  message: '外食、じわっと来てるね',
                  subMessage: '{count}回で{percent}%。一回ずつの満足感、ちゃんと効いてるね。',
                ),
                (
                  message: '外食、回数で来てるね',
                  subMessage: 'ここまでで{percent}%。積み重ねるとけっこう見えてくるね。',
                ),
                (
                  message: '外食、止まってないね',
                  subMessage: '{count}回。楽しい流れだけど、予算にもちゃんと足あと残ってるよ。',
                ),
              ],
      ),
    );
    if (diningComment != null) return diningComment;

    final onlineShoppingMetrics = _buildMonthlyCategoryMetrics(
      count: onlineShoppingCount,
      amount: onlineShoppingAmount,
      totalBudget: totalBudget,
    );
    final movieMetrics = _buildMonthlyCategoryMetrics(
      count: movieCount,
      amount: movieAmount,
      totalBudget: totalBudget,
    );
    final karaokeMetrics = _buildMonthlyCategoryMetrics(
      count: karaokeCount,
      amount: karaokeAmount,
      totalBudget: totalBudget,
    );
    final arcadeMetrics = _buildMonthlyCategoryMetrics(
      count: arcadeCount,
      amount: arcadeAmount,
      totalBudget: totalBudget,
    );

    final onlineShoppingComment = _buildCategoryMonthlyComment(
      baseKey: 'online_shopping_$lang',
      notificationBody: _t(
        lang,
        'ネットショッピングが今月{count}回、合計{amount}円あるよ。',
        'Online shopping showed up {count} times this month, totaling {amount}.',
      ),
      metrics: onlineShoppingMetrics,
      rule: const _MonthlyCategoryRule(
        heavyHitMaxCount: 2,
        heavyHitMinRatio: 0.15,
        repeatMinCount: 3,
        repeatMinRatio: 0.10,
        dripMinCount: 6,
        dripMinRatio: 0.04,
        dripMinAverage: 800,
        dripMaxAverage: 1499,
      ),
      copySet: _MonthlyCategoryCopySet(
        heavyHitVariants: isEn
            ? [
                (
                  message: 'Online shopping hit hard',
                  subMessage: '{count} orders and {amount} total. Not many taps, but they carried real weight.',
                ),
                (
                  message: 'The cart landed heavy',
                  subMessage: '{count} orders for {amount}. A few clicks, a noticeable budget footprint.',
                ),
                (
                  message: 'Online spending has presence',
                  subMessage: 'Already {percent}% of the budget. The screen was quick, but the impact stayed.',
                ),
              ]
            : [
                (
                  message: 'ネット、一撃重めだね',
                  subMessage: '今月{count}回で{amount}円だよ。回数は少なくても、予算の{percent}%まで来てるよ。',
                ),
                (
                  message: '通販、重いやつ来たね',
                  subMessage: '{count}回で{amount}円。少ないクリックでも、予算にはしっかり残るタイプだね。',
                ),
                (
                  message: 'ネット購入、存在感あるね',
                  subMessage: 'ここまでで予算の{percent}%だよ。気軽さより、今回は重さが出てるね。',
                ),
              ],
        repeatVariants: isEn
            ? [
                (
                  message: 'Online shopping is showing up a lot',
                  subMessage: '{count} orders and {amount} total. Convenience is starting to leave a clear trail.',
                ),
                (
                  message: 'Online purchases are adding up',
                  subMessage: '{count} orders for {amount}. Easy taps, not-so-invisible footprint.',
                ),
                (
                  message: 'The cart has a rhythm now',
                  subMessage: '{amount} so far. Fast on the screen, very real in the budget.',
                ),
                (
                  message: 'Online spending is creeping in',
                  subMessage: 'About {average} per order. It has climbed to {percent}% of the budget.',
                ),
              ]
            : [
                (
                  message: 'ネット、{count}回だね',
                  subMessage: '合計{amount}円。予算の{percent}%まで来てて、ちゃんと存在感あるね。',
                ),
                (
                  message: 'ネット購入、多めだね',
                  subMessage: '{count}回で{amount}円。便利さの積み重ね、けっこう効いてるね。',
                ),
                (
                  message: '通販、流れできてるね',
                  subMessage: 'ここまでで{amount}円。画面では一瞬でも、予算にはちゃんと残るやつだね。',
                ),
                (
                  message: 'ネット、じわっと来てるね',
                  subMessage: '1回あたり約{average}円。積み重ねて予算の{percent}%まで届いてるよ。',
                ),
              ],
        dripVariants: isEn
            ? [
                (
                  message: 'Online orders are quietly stacking up',
                  subMessage: '{count} orders and {amount} total. One order feels light, but the pattern is visible.',
                ),
                (
                  message: 'Online shopping is dripping in',
                  subMessage: 'Small orders have still reached {percent}% of the budget.',
                ),
                (
                  message: 'The cart is not stopping',
                  subMessage: '{count} orders for {amount}. Convenience is leaving footprints.',
                ),
              ]
            : [
                (
                  message: 'ネット、回数で来てるね',
                  subMessage: '{count}回で{amount}円。じわじわ型だけど、けっこう残ってるね。',
                ),
                (
                  message: 'ネット購入、止まってないね',
                  subMessage: '一回ごとは軽めでも、予算の{percent}%まで来てるよ。',
                ),
                (
                  message: '通販、積み上がってるね',
                  subMessage: '{count}回で{amount}円。便利さの反復がそのまま出てるね。',
                ),
              ],
      ),
    );
    if (onlineShoppingComment != null) return onlineShoppingComment;

    final movieComment = _buildCategoryMonthlyComment(
      baseKey: 'movie_$lang',
      notificationBody: _t(
        lang,
        '映画の支出が今月{count}回、合計{amount}円あるよ。',
        'Movie spending showed up {count} times this month, totaling {amount}.',
      ),
      metrics: movieMetrics,
      rule: const _MonthlyCategoryRule(
        heavyHitMaxCount: 1,
        heavyHitMinRatio: 0.12,
        repeatMinCount: 2,
        repeatMinRatio: 0.08,
        repeatMinAverage: 1000,
        dripMinCount: 3,
        dripMinRatio: 0.05,
        dripMinAverage: 1000,
      ),
      copySet: _MonthlyCategoryCopySet(
        heavyHitVariants: isEn
            ? [
                (
                  message: 'Movie spending hit hard',
                  subMessage: '{count} movie expense and {amount} total. A good screen break, but a noticeable budget hit.',
                ),
                (
                  message: 'That movie had weight',
                  subMessage: '{amount} in one go. The ticket may be gone, but the budget remembers.',
                ),
                (
                  message: 'Movie night left a footprint',
                  subMessage: 'Already {percent}% of the budget. Good time, real impact.',
                ),
              ]
            : [
                (
                  message: '映画、一撃重めだね',
                  subMessage: '今月{count}回で{amount}円だよ。いい気分転換だけど、予算にはしっかり響いてるね。',
                ),
                (
                  message: '映画、けっこう効いてるね',
                  subMessage: '今回は{amount}円。チケットは消えても、予算にはちゃんと残るやつだね。',
                ),
                (
                  message: '映画、存在感あるね',
                  subMessage: '予算の{percent}%まで来てるよ。楽しい時間だけど、重さも少しあるね。',
                ),
              ],
        repeatVariants: isEn
            ? [
                (
                  message: 'Movies are showing up',
                  subMessage: '{count} movie expenses and {amount} total. Fun nights are starting to leave a mark.',
                ),
                (
                  message: 'Movie habit forming',
                  subMessage: '{count} times so far. Good entertainment, but not invisible anymore.',
                ),
                (
                  message: 'Movie rhythm detected',
                  subMessage: '{amount} so far. A nice escape, with a real budget footprint.',
                ),
              ]
            : [
                (
                  message: '映画、{count}回だね',
                  subMessage: '合計{amount}円。予算の{percent}%まで来てて、けっこう存在感あるね。',
                ),
                (
                  message: '映画、多めだね',
                  subMessage: '{count}回で{amount}円。楽しさのぶん、予算にもちゃんと残ってるね。',
                ),
                (
                  message: '映画、流れできてるね',
                  subMessage: 'ここまでで{amount}円。気分転換の支出も見える形になってきたね。',
                ),
              ],
        dripVariants: isEn
            ? [
                (
                  message: 'Movies are quietly stacking up',
                  subMessage: '{count} movie expenses and {amount} total. Each one feels like a break, but the pattern is visible.',
                ),
                (
                  message: 'Movie spending is dripping in',
                  subMessage: 'It has reached {percent}% little by little. Good stories, real footprint.',
                ),
                (
                  message: 'The movie streak is not stopping',
                  subMessage: '{count} times. The screen time is leaving a visible trail.',
                ),
              ]
            : [
                (
                  message: '映画、じわっと来てるね',
                  subMessage: '{count}回で{amount}円。一本ずつは楽しいけど、流れとしては見えてきたよ。',
                ),
                (
                  message: '映画、回数で来てるね',
                  subMessage: 'ここまでで{percent}%。積み重なるとけっこう存在感出るね。',
                ),
                (
                  message: '映画、止まってないね',
                  subMessage: '{count}回。いい時間だけど、予算にもちゃんと足あと残ってるよ。',
                ),
              ],
      ),
    );
    if (movieComment != null) return movieComment;

    final karaokeComment = _buildCategoryMonthlyComment(
      baseKey: 'karaoke_$lang',
      notificationBody: _t(
        lang,
        'カラオケの支出が今月{count}回、合計{amount}円あるよ。',
        'Karaoke spending showed up {count} times this month, totaling {amount}.',
      ),
      metrics: karaokeMetrics,
      rule: const _MonthlyCategoryRule(
        repeatMinCount: 2,
        repeatMinRatio: 0.10,
        dripMinCount: 4,
        dripMinRatio: 0.04,
        dripMinAverage: 0,
        dripMaxAverage: 700,
      ),
      copySet: _MonthlyCategoryCopySet(
        repeatVariants: isEn
            ? [
                (
                  message: 'Karaoke is showing up',
                  subMessage: '{count} visits and {amount} total. Good stress relief, with a visible budget footprint.',
                ),
                (
                  message: 'Karaoke habit forming',
                  subMessage: '{count} times so far. The voice is free, but the room is not.',
                ),
                (
                  message: 'Karaoke rhythm detected',
                  subMessage: 'Already {percent}% of the budget. Fun release, real trail.',
                ),
              ]
            : [
                (
                  message: 'カラオケ、{count}回だね',
                  subMessage: '合計{amount}円。予算の{percent}%まで来てて、しっかり楽しんでるね。',
                ),
                (
                  message: 'カラオケ習慣、見えてきたね',
                  subMessage: '{count}回で{percent}%。声は無料でも、部屋代はちゃんと残るね。',
                ),
                (
                  message: 'カラオケ、流れできてるね',
                  subMessage: 'ここまでで{amount}円。発散はいいけど、予算にも足あと残ってるよ。',
                ),
              ],
        dripVariants: isEn
            ? [
                (
                  message: 'Karaoke is quietly stacking up',
                  subMessage: '{count} visits and {amount} total. Each one feels light, but the pattern is visible.',
                ),
                (
                  message: 'Karaoke spending is dripping in',
                  subMessage: 'About {average} per visit. Small sessions still reached {percent}% of the budget.',
                ),
                (
                  message: 'The karaoke streak is not stopping',
                  subMessage: '{count} visits. The fun is leaving a trail, one song at a time.',
                ),
              ]
            : [
                (
                  message: 'カラオケ、じわっと来てるね',
                  subMessage: '{count}回で{amount}円。軽くても回数でちゃんと効いてるね。',
                ),
                (
                  message: 'カラオケ、回数型だね',
                  subMessage: '1回あたり約{average}円。積み重ねで{percent}%まで来てるよ。',
                ),
                (
                  message: 'カラオケ、止まってないね',
                  subMessage: '{count}回。楽しさの流れが、そのまま足あとになってるね。',
                ),
              ],
      ),
    );
    if (karaokeComment != null) return karaokeComment;

    final arcadeComment = _buildCategoryMonthlyComment(
      baseKey: 'arcade_$lang',
      notificationBody: _t(
        lang,
        'ゲーセン系の支出が今月{count}回、合計{amount}円あるよ。',
        'Arcade spending showed up {count} times this month, totaling {amount}.',
      ),
      metrics: arcadeMetrics,
      rule: const _MonthlyCategoryRule(
        heavyHitMaxCount: 2,
        heavyHitMinRatio: 0.10,
        repeatMinCount: 3,
        repeatMinRatio: 0.05,
        dripMinCount: 4,
        dripMinRatio: 0.035,
        dripMinAverage: 700,
      ),
      copySet: _MonthlyCategoryCopySet(
        heavyHitVariants: isEn
            ? [
                (
                  message: 'Arcade spending hit hard',
                  subMessage: '{count} visits and {amount} total. Not frequent, but each hit carries weight.',
                ),
                (
                  message: 'That play session had weight',
                  subMessage: '{amount} in total. Fun, but clearly visible in the budget.',
                ),
                (
                  message: 'Arcade time left a mark',
                  subMessage: 'About {average} per visit. Not exactly light.',
                ),
              ]
            : [
                (
                  message: 'ゲーセン、一撃重めだね',
                  subMessage: '今月{count}回で{amount}円。少ない回数でもしっかり残るタイプだね。',
                ),
                (
                  message: '遊び、一発効いてるね',
                  subMessage: '予算の{percent}%まで来てるよ。楽しさのぶん、ちゃんと効いてるね。',
                ),
                (
                  message: 'ゲーセン、存在感あるね',
                  subMessage: '1回あたり約{average}円。軽くはない一撃だね。',
                ),
              ],
        repeatVariants: isEn
            ? [
                (
                  message: 'Arcades are showing up a lot',
                  subMessage: '{count} visits and {amount} total. Fun stacking up into something visible.',
                ),
                (
                  message: 'Arcade habit forming',
                  subMessage: '{count} visits so far. Not just a one-off anymore.',
                ),
                (
                  message: 'Arcade rhythm detected',
                  subMessage: '{amount} so far. The playtime is leaving a clear footprint.',
                ),
              ]
            : [
                (
                  message: 'ゲーセン、{count}回だね',
                  subMessage: '合計{amount}円。予算の{percent}%まで来てて、じわっと効いてるね。',
                ),
                (
                  message: 'ゲーセン多めだね',
                  subMessage: '{count}回で{amount}円。遊びの積み重ね、ちゃんと残ってるね。',
                ),
                (
                  message: 'ゲーセン、流れできてるね',
                  subMessage: 'ここまでで{amount}円。気づいたら効いてるタイプだね。',
                ),
              ],
        dripVariants: isEn
            ? [
                (
                  message: 'Arcade visits are quietly stacking up',
                  subMessage: '{count} visits and {amount} total. Each play feels light, but the pattern is visible.',
                ),
                (
                  message: 'Arcade spending is dripping in',
                  subMessage: 'It has reached {percent}% little by little.',
                ),
                (
                  message: 'The arcade streak is not stopping',
                  subMessage: '{count} visits. Fun is leaving a trail.',
                ),
              ]
            : [
                (
                  message: 'ゲーセン、じわっと来てるね',
                  subMessage: '{count}回で{amount}円。軽くても回数でちゃんと効いてるね。',
                ),
                (
                  message: 'ゲーセン、回数型だね',
                  subMessage: '積み重ねで{percent}%まで来てるよ。',
                ),
                (
                  message: 'ゲーセン、止まってないね',
                  subMessage: '{count}回。楽しさの流れが、そのまま足あとになってるね。',
                ),
              ],
      ),
    );
    if (arcadeComment != null) return arcadeComment;

    final suddenMetrics = _buildMonthlyCategoryMetrics(
      count: suddenExpenseCount,
      amount: suddenExpenseAmount,
      totalBudget: totalBudget,
    );

    final suddenComment = _buildCategoryMonthlyComment(
      baseKey: 'sudden_expense_$lang',
      notificationBody: _t(
        lang,
        '今月、急な出費が{count}回あるよ。',
        'Unexpected expenses showed up {count} times this month.',
      ),
      metrics: suddenMetrics,
      rule: const _MonthlyCategoryRule(
        repeatMinCount: 3,
        repeatMinRatio: 0.08,
        dripMinCount: 5,
        dripMinRatio: 0.05,
        dripMaxAverage: 1500,
      ),
      copySet: _MonthlyCategoryCopySet(
        repeatVariants: isEn
            ? [
                (
                  message: 'Unexpected costs are showing up',
                  subMessage: '{count} times and already {percent}% of the budget. These are starting to add up.',
                ),
                (
                  message: 'Unplanned spending is building',
                  subMessage: '{count} hits so far. Each one looks small, but the pattern is real.',
                ),
                (
                  message: 'Surprises are stacking up',
                  subMessage: 'Already {percent}% of the budget. Unplanned does not mean invisible.',
                ),
              ]
            : [
                (
                  message: '急な出費、{count}回だね',
                  subMessage: '予定外で予算の{percent}%まで来てるよ。じわっと効いてるね。',
                ),
                (
                  message: '急な出費、多めだね',
                  subMessage: '{count}回で{percent}%。単発っぽく見えて、流れになってきてるね。',
                ),
                (
                  message: '想定外、積み上がってるね',
                  subMessage: 'ここまでで予算の{percent}%だよ。予定外って意外と残るね。',
                ),
              ],
        dripVariants: isEn
            ? [
                (
                  message: 'Unexpected expenses are quietly stacking up',
                  subMessage: '{count} times and {percent}% of the budget. Each one feels minor, but together they are not.',
                ),
                (
                  message: 'Unplanned spending is dripping in',
                  subMessage: 'It has reached {percent}% little by little.',
                ),
                (
                  message: 'The surprises are not stopping',
                  subMessage: '{count} times. Small hits are leaving a real footprint.',
                ),
              ]
            : [
                (
                  message: '急な出費、回数で来てるね',
                  subMessage: '今月{count}回で予算の{percent}%。軽く見えても積み重なるね。',
                ),
                (
                  message: '予定外、続いてるね',
                  subMessage: '1回ごとは小さくても、財布にはちゃんと残ってるよ。',
                ),
                (
                  message: '急な出費、じわっと来てるね',
                  subMessage: '気づきにくいけど、予算の{percent}%まで来てるよ。',
                ),
              ],
      ),
    );

    if (suddenComment != null) return suddenComment;

    return _defaultMonthlyComment(languageCode);
  }

  static Future<RoastResult> build({
    String languageCode = 'ja',
    required int totalBudget,
    required int usedAmount,
    required List<Expense> expenses,
    required List<Map<String, dynamic>> dangerCategories,
    int? latestCategoryBudget,
    int? latestCategoryUsed,
    DateTime? cycleStart,
    DateTime? cycleEnd,
    Map<ExpenseJudgeTag, int>? latestCategoryTagUsedAmounts,
  }) async {
    final lang = _normalizeLang(languageCode);
    final isEn = _isEnglish(lang);
    if (totalBudget == 0) {
      final variant = _pickVariant('no_budget_$lang', isEn
          ? [
              (
                message: 'No budget set yet',
                subMessage:
                    'Your wallet is basically walking around without a map. Set a rough limit and things get much easier to read.',
              ),
              (
                message: 'No guardrails yet',
                subMessage:
                    'Without a line in the sand, every expense gets a little too mysterious.',
              ),
              (
                message: 'Your budget is still blank',
                subMessage:
                    'Even a rough monthly limit gives your money somewhere to stand.',
              ),
              (
                message: 'The wallet has no mission yet',
                subMessage:
                    'Give it a monthly limit and it can finally start judging things properly.',
              ),
            ]
          : [
              (
                message: '予算、まだないね',
                subMessage: '上限がないと、どこまでいくか分からないよ。まずはざっくりで大丈夫。',
              ),
              (
                message: '今月、ノーガードだね',
                subMessage: '基準がないままだと、気づいた時にはけっこう来てるやつだよ。',
              ),
              (
                message: '予算、空欄のままだね',
                subMessage: 'とりあえずでもいいから、線を引いておくとかなり楽になるよ。',
              ),
              (
                message: '上限、決めとくといいかもね',
                subMessage: 'あるだけで、お金の動きがかなり見えやすくなるよ。',
              ),
            ]);

      return RoastResult(
        title: _noteTitle(lang),
        message: variant.message,
        subMessage: variant.subMessage,
        notificationBody: _t(lang, 'まずは予算を設定しよう。', 'Set a budget first.'),
        scenarioKey: 'no_budget',
      );
    }

    if (expenses.isEmpty) {
      final variant = _pickVariant('no_expense_$lang', isEn
          ? [
              (
                message: 'No spending yet',
                subMessage:
                    'Quiet start. The wallet is still relaxing, which is honestly a pretty good opening move.',
              ),
              (
                message: 'Still at zero',
                subMessage:
                    'Nothing has moved yet. That is the kind of calm budgets dream about.',
              ),
              (
                message: 'No activity so far',
                subMessage:
                    'Suspiciously peaceful. Let’s keep an eye on it, in a good way.',
              ),
              (
                message: 'Nothing spent yet',
                subMessage:
                    'A clean start. Future you might appreciate this quiet little moment.',
              ),
            ]
          : [
              (
                message: 'まだ使ってないね',
                subMessage: 'かなり静かだね。このままなら余裕あるね。',
              ),
              (
                message: '今のところゼロだね',
                subMessage: 'いい入り方してるね。まだ全然減ってないね。',
              ),
              (
                message: '動き、まだないね',
                subMessage: 'かなり落ち着いてる。この感じ、なかなかいいね。',
              ),
              (
                message: 'まだ何も来てないね',
                subMessage: 'ここからどう使うかで流れが変わるね。いいスタートだよ。',
              ),
            ]);

      return RoastResult(
        title: _noteTitle(lang),
        message: variant.message,
        subMessage: variant.subMessage,
        notificationBody: _t(
          lang,
          'まだ支出はないね。いいスタートだよ。',
          'No spending yet. Nice start.',
        ),
        scenarioKey: 'no_expense',
      );
    }

    final overallUsageRate = totalBudget == 0 ? 0.0 : usedAmount / totalBudget;

    final sortedExpenses = [...expenses]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int cafeCount = 0;
    int convenienceCount = 0;
    int diningCount = 0;
    int onlineShoppingCount = 0;
    int movieCount = 0;
    int karaokeCount = 0;
    int arcadeCount = 0;
    int suddenExpenseCount = 0;
    final storeCounts = <String, int>{};

    for (final e in sortedExpenses) {
      if (_isCafe(e)) cafeCount++;
      if (_isConvenience(e)) convenienceCount++;
      if (_isDining(e)) diningCount++;
      if (_isOnlineShopping(e)) onlineShoppingCount++;
      if (_hasTag(e, ExpenseJudgeTag.movie, totalBudget)) movieCount++;
      if (_hasTag(e, ExpenseJudgeTag.karaoke, totalBudget)) karaokeCount++;
      if (_hasTag(e, ExpenseJudgeTag.arcade, totalBudget)) arcadeCount++;
      if (e.category == 'その他') suddenExpenseCount++;

      final name = e.storeName.trim();
      if (name.isNotEmpty) {
        storeCounts[name] = (storeCounts[name] ?? 0) + 1;
      }
    }

    final latestExpense = sortedExpenses.first;
    final latestStore = latestExpense.storeName.trim();

    final consecutiveStoreCount =
        ExpenseJudgeService.consecutiveStoreCount(sortedExpenses);
    final hasConsecutiveStoreSpending =
        ExpenseJudgeService.hasConsecutiveStoreSpending(sortedExpenses);
    final consecutiveCafeCount = _consecutiveTagCount(
      sortedExpenses,
      ExpenseJudgeTag.cafe,
      totalBudget,
    );
    final consecutiveConvenienceCount = _consecutiveTagCount(
      sortedExpenses,
      ExpenseJudgeTag.convenience,
      totalBudget,
    );
    final consecutiveDiningCount = _consecutiveTagCount(
      sortedExpenses,
      ExpenseJudgeTag.dining,
      totalBudget,
    );

    final consecutiveOnlineShoppingCount =
        _consecutiveOnlineShoppingCount(sortedExpenses);

    final onlineShoppingAmount = _sumAmountByTag(
      sortedExpenses,
      ExpenseJudgeTag.onlineShopping,
      totalBudget,
    );
    final movieAmount =
        _sumAmountByTag(sortedExpenses, ExpenseJudgeTag.movie, totalBudget);
    final karaokeAmount = _sumAmountByTag(
      sortedExpenses,
      ExpenseJudgeTag.karaoke,
      totalBudget,
    );
    final arcadeAmount =
        _sumAmountByTag(sortedExpenses, ExpenseJudgeTag.arcade, totalBudget);
    final suddenExpenseAmount = _sumAmountByCategory(sortedExpenses, 'その他');

    final latestTimeTone = _timeTone(latestExpense.createdAt);
    final latestIsWeekend = _isWeekend(latestExpense.createdAt);
    final latestOnlineShoppingAverage = _averageAmount(
      onlineShoppingAmount,
      onlineShoppingCount,
    );
    final latestMovieAverage = _averageAmount(movieAmount, movieCount);

    final judge = ExpenseJudgeService.judge(
      expense: latestExpense,
      totalBudget: totalBudget,
    );

    final ruleResult = latestCategoryBudget != null &&
            latestCategoryUsed != null &&
            cycleStart != null &&
            cycleEnd != null
        ? SpendingRuleService.evaluate(
            expense: latestExpense,
            judgeResult: judge,
            categoryBudget: latestCategoryBudget,
            categoryUsed: latestCategoryUsed,
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            tagUsedAmounts: latestCategoryTagUsedAmounts,
          )
        : null;




    final amount = latestExpense.amount;
    final spendingRate = totalBudget == 0 ? 0.0 : amount / totalBudget;
    final remainingBudget = totalBudget - usedAmount;
    final now = DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final normalizedCycleEnd = cycleEnd == null
        ? null
        : DateTime(cycleEnd.year, cycleEnd.month, cycleEnd.day);
    final daysLeft = normalizedCycleEnd == null
        ? null
        : normalizedCycleEnd.difference(normalizedToday).inDays;
    final remainingPerDay = daysLeft != null && daysLeft > 0
        ? (remainingBudget / daysLeft).round()
        : null;

    final latestStoreCount = latestStore.isEmpty ? 0 : (storeCounts[latestStore] ?? 0);

    final priorityLatestComment = _buildPriorityLatestComment(
      languageCode: lang,
      convenienceCount: convenienceCount,
      cafeCount: cafeCount,
      diningCount: diningCount,
      onlineShoppingCount: onlineShoppingCount,
      latestExpense: latestExpense,
      latestStore: latestStore,
      latestStoreCount: latestStoreCount,
      amount: amount,
      spendingRate: spendingRate,
      remainingBudget: remainingBudget,
      remainingPerDay: remainingPerDay,
      daysLeft: daysLeft,
    );

    //通知
bool _isSameContext(_LatestComment latest, _LatestComment? priority) {
  if (priority == null) return false;

  // 🏪 店ベース（repeat系）
  if (priority.scenarioKey.contains('store') &&
      latest.scenarioKey.contains('store')) {
    return true;
  }

  // ☕ カフェ
  if (priority.scenarioKey.contains('cafe') &&
      latest.scenarioKey.contains('cafe')) {
    return true;
  }

  // 🏪 コンビニ
  if (priority.scenarioKey.contains('convenience') &&
      latest.scenarioKey.contains('convenience')) {
    return true;
  }

  // 🍽 外食
  if (priority.scenarioKey.contains('dining') &&
      latest.scenarioKey.contains('dining')) {
    return true;
  }

  // 📦 ネット
  if (priority.scenarioKey.contains('online') &&
      latest.scenarioKey.contains('online')) {
    return true;
  }

  // 💸 金額系は常に優先OK
  if (priority.scenarioKey.contains('expensive') ||
      priority.scenarioKey.contains('mid_spending')) {
    return true;
  }

  return false;
}

    String? leadMessage;
    String? leadSubMessage;

    if (spendingRate >= 0.25) {
      final moneyText = _formatMoney(amount, lang);
      final variant = _pickVariant('expensive_spending_$lang', isEn
          ? [
              (
                message: 'That was a big one',
                subMessage: '${latestExpense.storeName} just hit hard. The wallet definitely felt that.',
              ),
              (
                message: 'Heavy spending there',
                subMessage: '$moneyText. Even as a one-off, that carries weight.',
              ),
              (
                message: '${latestExpense.storeName} came in strong',
                subMessage: 'A single move like this leaves a clear footprint.',
              ),
              (
                message: 'That was a solid hit',
                subMessage: '$moneyText. This could shift the flow of the month a bit.',
              ),
            ]
          : [
              (
                message: '$moneyText、でかいね',
                subMessage: '${latestExpense.storeName}の一撃だよ。財布、ちょっと揺れてるね。',
              ),
              (
                message: 'これは重いね',
                subMessage: '$moneyText。単発でもけっこう効くやつだね。',
              ),
              (
                message: '${latestExpense.storeName}、強めだね',
                subMessage: '一回でここまで動くと、さすがに存在感あるね。',
              ),
              (
                message: '一撃、来たね',
                subMessage: '$moneyText。今月の流れ、ちょっと変わりそうだね。',
              ),
            ]);

      leadMessage = variant.message;
      leadSubMessage = variant.subMessage;
    } else if (spendingRate >= 0.15) {
      final moneyText = _formatMoney(amount, lang);

      final variant = _pickVariant('mid_spending_$lang', isEn
          ? [
              (
                message: '$moneyText, not small',
                subMessage: '${latestExpense.storeName} has some weight. This may linger a bit.',
              ),
              (
                message: 'That one will stick',
                subMessage: '$moneyText is not huge, but it is not invisible either.',
              ),
              (
                message: '${latestExpense.storeName} has presence',
                subMessage: '$moneyText. It feels fine now, but it may show up later.',
              ),
              (
                message: 'A quiet hit there',
                subMessage: '$moneyText. Small enough to miss, big enough to matter.',
              ),
            ]
          : [
              (
                message: '$moneyText、ちょい重めだね',
                subMessage: '${latestExpense.storeName}の支出だよ。あとでじわっと効きそうだね。',
              ),
              (
                message: 'これは少し効くね',
                subMessage: '$moneyText。小さくはないから、財布も見逃してないよ。',
              ),
              (
                message: '${latestExpense.storeName}、存在感あるね',
                subMessage: '今回の$moneyText、あとで効いてくるタイプかもね。',
              ),
              (
                message: 'じわっと来るやつだね',
                subMessage: '$moneyText。今は平気でも、積み重なると効いてくるよ。',
              ),
            ]);

      leadMessage = variant.message;
      leadSubMessage = variant.subMessage;
    } else if (spendingRate >= 0.08) {
      final moneyText = _formatMoney(amount, lang);

      final variant = _pickVariant('light_high_spending_$lang', isEn
          ? [
              (
                message: '$moneyText stands out a bit',
                subMessage: '${latestExpense.storeName} is not a major hit, but it is worth noticing.',
              ),
              (
                message: 'A little presence there',
                subMessage: '$moneyText. Still okay, but repeated moves like this can add up.',
              ),
              (
                message: '${latestExpense.storeName} is not tiny',
                subMessage: '$moneyText is the kind of expense worth remembering.',
              ),
              (
                message: 'This one may add up later',
                subMessage: '$moneyText. If this size keeps repeating, it will start to matter.',
              ),
            ]
          : [
              (
                message: '$moneyText、少し目立つね',
                subMessage: '${latestExpense.storeName}の支出だよ。じわっと効いてくるタイプだね。',
              ),
              (
                message: 'ちょっと存在感あるね',
                subMessage: '$moneyText。まだ大丈夫だけど、積み重なると効いてくるよ。',
              ),
              (
                message: '${latestExpense.storeName}、軽くはないね',
                subMessage: '今回の$moneyText、少しだけ覚えておきたいやつだね。',
              ),
              (
                message: 'じわっと来そうだね',
                subMessage: '$moneyText。このくらいが続くと、あとで効いてくるよ。',
              ),
            ]);

      leadMessage = variant.message;
      leadSubMessage = variant.subMessage;
    }

    String? secondaryMessage = leadMessage;
    String? secondarySubMessage = leadSubMessage;

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        hasConsecutiveStoreSpending &&
        latestStore.isNotEmpty) {
      final variant = _pickVariant('secondary_consecutive_store_${latestStore}_$lang', isEn
          ? [
              (
                message: '$latestStore again',
                subMessage: '$consecutiveStoreCount times in a row. This is becoming a pattern.',
              ),
              (
                message: '$latestStore streak going',
                subMessage: '$consecutiveStoreCount visits straight. Even the wallet remembers now.',
              ),
              (
                message: '$latestStore is not stopping',
                subMessage: 'At this point, it is more habit than coincidence.',
              ),
            ]
          : [
              (
                message: '$latestStore、連続だね',
                subMessage: '$consecutiveStoreCount回続いてるよ。もうレシートも見覚えあるね。',
              ),
              (
                message: 'また$latestStoreだね',
                subMessage: 'ここまで来ると、偶然じゃなくて流れだね。'
              ),
              (
                message: '$latestStore、止まってないね',
                subMessage: '$consecutiveStoreCount回連続。財布もカウント係になってるよ。',
              ),
            ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        consecutiveCafeCount >= 2) {
      final variant = _pickVariant('secondary_consecutive_cafe_$lang', isEn
          ? [
              (
                message: 'Cafe streak going',
                subMessage: '$consecutiveCafeCount times in a row. This is becoming a routine.',
              ),
              (
                message: 'Another cafe stop',
                subMessage: 'This is less a break, more a pattern now.',
              ),
              (
                message: 'Cafes are not stopping',
                subMessage: '$consecutiveCafeCount in a row. Habit is taking over.',
              ),
            ]
          : [
              (
                message: 'カフェ、連続だね',
                subMessage: '$consecutiveCafeCount回続いてるよ。カフェインより習慣が効いてるね。',
              ),
              (
                message: 'またカフェだね',
                subMessage: '気分転換が、ほぼ定常運転になってるね。',
              ),
              (
                message: 'カフェ、止まってないね',
                subMessage: '$consecutiveCafeCount回連続。ポイントカードと仲良くなりそうだね。',
              ),
            ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        consecutiveConvenienceCount >= 2) {
      final variant = _pickVariant('secondary_consecutive_convenience_$lang', isEn
          ? [
              (
                message: 'Convenience streak going',
                subMessage: 'Those quick stops are stacking up now.',
              ),
              (
                message: 'Another convenience stop',
                subMessage: 'Easy wins are quietly adding up.',
              ),
              (
                message: 'Convenience visits not stopping',
                subMessage: 'Small trips, real impact.',
              ),
            ]
          : [
              (
                message: 'コンビニ、連続だね',
                subMessage: '“ちょっとだけ”がちゃんと積み上がってるね。',
              ),
              (
                message: 'またコンビニだね',
                subMessage: '近さが勝ってるね。財布はちょっと押され気味だよ。',
              ),
              (
                message: 'コンビニ、止まってないね',
                subMessage: '手軽さの勝利だね。予算はじわっと削られてるよ。',
              ),
            ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        consecutiveDiningCount >= 2) {
      final variant = _pickVariant('secondary_consecutive_dining_$lang', isEn
          ? [
              (
                message: 'Dining streak going',
                subMessage: '$consecutiveDiningCount times in a row. Great meals, but the pattern is real.',
              ),
              (
                message: 'Another meal out',
                subMessage: 'Cooking is taking a quiet break now.',
              ),
              (
                message: 'Eating out is not stopping',
                subMessage: '$consecutiveDiningCount in a row. Good taste, visible footprint.',
              ),
            ]
          : [
              (
                message: '外食、連続だね',
                subMessage: '満足度は高いね。財布はちょっと低姿勢だよ。',
              ),
              (
                message: 'また外食だね',
                subMessage: '自炊は今、静かに休暇中だね。',
              ),
              (
                message: '外食、止まってないね',
                subMessage: '美味しさの勝利だね。後半の余裕は少し前借り気味だよ。',
              ),
            ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        consecutiveOnlineShoppingCount >= 2) {
      final variant = _pickVariant('secondary_consecutive_online_shopping_$lang', isEn
          ? [
              (
                message: 'Online orders again',
                subMessage: 'Things keep arriving. This is becoming a flow.',
              ),
              (
                message: 'Another quick order',
                subMessage: 'Fingertips are light. The budget feels it though.',
              ),
              (
                message: 'Online shopping not stopping',
                subMessage: 'Convenience is winning. The footprint is real.',
              ),
            ]
          : [
              (
                message: 'ネット、連続だね',
                subMessage: '気づいたら届く流れになってるね。',
              ),
              (
                message: 'またポチったね',
                subMessage: '指先は軽いね。財布の減りはしっかり重いよ。',
              ),
              (
                message: 'ネット、止まってないね',
                subMessage: '便利さの勝利だね。予算は静かに削られてるよ。',
              ),
            ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        remainingPerDay != null &&
        daysLeft != null &&
        daysLeft > 0 &&
        remainingBudget > 0) {
      final remainingText = _formatMoney(remainingBudget, lang);

      if (remainingPerDay <= 150) {
        final variant = _pickVariant('secondary_remaining_per_day_critical_$lang', isEn
            ? [
                (
                  message: 'Running thin now',
                  subMessage: 'About $remainingText left for $daysLeft days. This is basically hard mode.',
                ),
                (
                  message: 'Decision point unlocked',
                  subMessage: 'From here, each expense feels like a story branch.',
                ),
                (
                  message: 'Survival mode started',
                  subMessage: '$remainingText left and $daysLeft days to go. Random shots will hurt now.',
                ),
              ]
            : [
                (
                  message: '残り、かなり薄いね',
                  subMessage: '1日あたりハードモードだよ。ほぼ修行だね。',
                ),
                (
                  message: 'ここから分岐だね',
                  subMessage: '一回の判断が、ほぼストーリー分岐になってるよ。',
                ),
                (
                  message: '耐久戦に入ったよ',
                  subMessage: '残り$remainingTextであと$daysLeft日。無駄撃ちはけっこう痛いね。',
                ),
              ]);
        secondaryMessage = variant.message;
        secondarySubMessage = variant.subMessage;
      } else if (remainingPerDay <= 300) {
        final variant = _pickVariant('secondary_remaining_per_day_warning_$lang', isEn
            ? [
                (
                  message: 'Still in the fight',
                  subMessage: 'Use it loosely and it can disappear fast.',
                ),
                (
                  message: 'This is where pacing matters',
                  subMessage: 'From here, it is a distribution game. Planning would be a premium skill.',
                ),
                (
                  message: 'The endgame is getting heavier',
                  subMessage: 'A few light moves in a row can make the landing rough.',
                ),
              ]
            : [
                (
                  message: 'まだ戦えるね',
                  subMessage: 'ただし雑に使うと一瞬で終わるやつだよ。',
                ),
                (
                  message: '腕の見せ所だね',
                  subMessage: 'ここからは配分ゲーだよ。計画性に課金したいところだね。',
                ),
                (
                  message: '終盤、重くなってきたね',
                  subMessage: '軽い一手の連打で、あとが重くなるよ。',
                ),
              ]);
        secondaryMessage = variant.message;
        secondarySubMessage = variant.subMessage;
      }
    }

    final monthlyComment = _buildMonthlyComment(
      languageCode: lang,
      overallUsageRate: overallUsageRate,
      totalBudget: totalBudget,
      dangerCategories: dangerCategories,
      cafeCount: cafeCount,
      convenienceCount: convenienceCount,
      diningCount: diningCount,
      onlineShoppingCount: onlineShoppingCount,
      onlineShoppingAmount: onlineShoppingAmount,
      movieCount: movieCount,
      movieAmount: movieAmount,
      karaokeCount: karaokeCount,
      karaokeAmount: karaokeAmount,
      arcadeCount: arcadeCount,
      arcadeAmount: arcadeAmount,
      suddenExpenseCount: suddenExpenseCount,
      suddenExpenseAmount: suddenExpenseAmount,
    );

    final shouldUseLeadForMonthly =
        monthlyComment.scenarioKey == 'monthly_normal' ||
        monthlyComment.scenarioKey == 'overall_danger' ||
        monthlyComment.scenarioKey == 'overall_over';

    if (!shouldUseLeadForMonthly) {
      leadMessage = null;
      leadSubMessage = null;
    }

    _LatestComment latestComment;

    if (judge.tags.contains(ExpenseJudgeTag.supermarket)) {
      if (overallUsageRate >= 1.0) {
        final variant = _pickVariant(
          'latest_supermarket_overall_over_$lang',
          isEn
              ? [
                  (
                    message: '${latestExpense.storeName} is essentials',
                    subMessage: 'Food matters. But the overall budget is already over this month.',
                  ),
                  (
                    message: 'Groceries came in',
                    subMessage: 'Necessary spend, but this is extra innings now for the month.',
                  ),
                  (
                    message: 'Food is unavoidable',
                    subMessage: 'True, but the overall budget has already been pushed past the limit.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、必要枠だね',
                    subMessage: '食べるのは大事だよ。ただ、今月全体はもうオーバーしてるね。',
                  ),
                  (
                    message: 'スーパー、来たね',
                    subMessage: '必要な支出でも、今月は追加ラウンドだね。財布は延長戦に入ってるよ。',
                  ),
                  (
                    message: '食費、避けられないね',
                    subMessage: '生活には必要だよ。ただ、全体予算はもう限界突破してるね。',
                  ),
                ],
        );

        latestComment = _LatestComment(
          scenarioKey: 'latest_supermarket_overall_over_$lang',
          notificationBody: _t(
            lang,
            '🛒 ${latestExpense.storeName} の支出を記録したよ。今月全体はすでに予算オーバーだね。',
            '🛒 ${latestExpense.storeName} logged. The overall budget is already over this month.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
        );
      } else if (ruleResult?.paceStatus == PaceStatus.danger ||
          ruleResult?.paceStatus == PaceStatus.over) {
        final variant = _pickVariant(
          'latest_supermarket_category_danger_$lang',
          isEn
              ? [
                  (
                    message: '${latestExpense.storeName} is pushing it',
                    subMessage: 'Essentials, yes. But this category is getting tight.',
                  ),
                  (
                    message: 'Groceries are getting heavy',
                    subMessage: 'Necessary, but the pace here is pretty aggressive now.',
                  ),
                  (
                    message: 'Food spending is near the limit',
                    subMessage: 'Not something to blame, but each move will feel heavier from here.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、食費が攻めてるね',
                    subMessage: '生活には必要だよ。ただ、このカテゴリはかなりギリギリだね。',
                  ),
                  (
                    message: 'スーパー、重くなってきたね',
                    subMessage: '必要枠でも、食費ペースはだいぶ前のめりだよ。後半ちょっと心配だね。',
                  ),
                  (
                    message: '食費、限界近いなね',
                    subMessage: '責めるやつじゃないけど、ここからは一回ずつ重くなるよ。',
                  ),
                ],
        );

        latestComment = _LatestComment(
          scenarioKey: 'latest_supermarket_category_danger_$lang',
          notificationBody: _t(
            lang,
            '🛒 ${latestExpense.storeName} の支出を記録したよ。食費カテゴリの予算ペースがかなり速めだね。',
            '🛒 ${latestExpense.storeName} logged. Food category spending is moving fast.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
        );
      } else if (ruleResult?.paceStatus == PaceStatus.warning) {
        final variant = _pickVariant(
          'latest_supermarket_category_warning_$lang',
          isEn
              ? [
                  (
                    message: '${latestExpense.storeName} is moving a bit fast',
                    subMessage: 'Necessary shopping, but the food category is starting to stand out.',
                  ),
                  (
                    message: 'Groceries are starting to show',
                    subMessage: 'This is normal life spending. Still, the pace is worth watching from here.',
                  ),
                  (
                    message: 'Food spending has presence now',
                    subMessage: 'Not something to blame, but it may affect the room you have later in the month.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、食費ペース早めだね',
                    subMessage: '必要な買い物だけど、カテゴリの減り方は少し目立ってきたね。',
                  ),
                  (
                    message: 'スーパー、じわっと効いてるね',
                    subMessage: '生活費として自然だよ。ただ、ここからは配分も少し見ておきたいね。',
                  ),
                  (
                    message: '食費、存在感出てきたね',
                    subMessage: '責める場面じゃないけど、後半の余裕にはちゃんと効いてくるよ。',
                  ),
                ],
        );

        latestComment = _LatestComment(
          scenarioKey: 'latest_supermarket_category_warning_$lang',
          notificationBody: _t(
            lang,
            '🛒 ${latestExpense.storeName} の支出を記録したよ。食費カテゴリが少し早めのペースだね。',
            '🛒 ${latestExpense.storeName} logged. Food category spending is moving a bit fast.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
        );
      } else {
        final variant = _pickVariant(
          'latest_supermarket_$lang',
          isEn
              ? [
                  (
                    message: '${latestExpense.storeName} is essentials',
                    subMessage: 'Groceries are the foundation. The wallet will quietly watch this one.',
                  ),
                  (
                    message: 'Another grocery run',
                    subMessage: 'Nothing dramatic. Just the kind of spending that quietly shapes the month.',
                  ),
                  (
                    message: 'Food spending noted',
                    subMessage: 'This is the kind of spending that makes sense. Keeping it visible still helps.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、必要枠だね',
                    subMessage: 'スーパーは生活の土台だよ。今日は静かに見守るね。',
                  ),
                  (
                    message: 'スーパーだね',
                    subMessage: '生活の一部だね。こういうのが今月の流れを作っていくよ。',
                  ),
                  (
                    message: '食費、ちゃんと見えてるね',
                    subMessage: '必要な支出だね。こういう土台の支出こそ、見える形にしておくと安心だよ。',
                  ),
                ],
        );

        latestComment = _LatestComment(
          scenarioKey: 'latest_supermarket_$lang',
          notificationBody: _t(
            lang,
            '🛒 ${latestExpense.storeName} の支出を記録したよ。',
            '🛒 ${latestExpense.storeName} logged.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
        );
      }
    }

    else if (judge.tags.contains(ExpenseJudgeTag.movie)) {
      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? _pickVariant('latest_movie_danger_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} movie time',
                    subMessage: 'Great experience, but at this pace it is starting to hit the wallet a bit harder.',
                  ),
                  (
                    message: 'Movies are coming in strong',
                    subMessage: 'Nice refresh, but this month is leaning forward a bit.',
                  ),
                  (
                    message: 'That was a good use of time',
                    subMessage: 'About ${latestMovieAverage}. It adds up quietly. Might be worth pacing a bit.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、映画だね',
                    subMessage: '満足度は高そうだね。ただ今のペースだと、財布にはちょっと重めに効いてるよ。',
                  ),
                  (
                    message: '映画、来てるね',
                    subMessage: 'リフレッシュにはいいね。でも今月は少し前のめりな流れだね。',
                  ),
                  (
                    message: 'その時間、いい使い方だね',
                    subMessage: 'ただ平均${latestMovieAverage}円、じわっと効いてるね。ここからは少し慎重でもいいかもね。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? _pickVariant('latest_movie_warning_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} movie day',
                        subMessage: 'Nice break. The pace is starting to show a little though.',
                      ),
                      (
                        message: 'Movies in a good flow',
                        subMessage: 'Enjoyable, but repeated visits will start to show later.',
                      ),
                      (
                        message: 'Looks like a movie day',
                        subMessage: 'Around ${latestMovieAverage}. Adjusting now could make the rest of the month easier.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、映画だね',
                        subMessage: 'いい気分転換だね。ただ少しペースは出てきてるよ。',
                      ),
                      (
                        message: '映画、いい流れだね',
                        subMessage: '楽しめてるね。ただ回数が重なると、あとで効いてくるタイプだよ。',
                      ),
                      (
                        message: '映画の日だね',
                        subMessage: '平均${latestMovieAverage}円。今のうちに少し整えると、後半かなり楽になるよ。',
                      ),
                    ])
              : _pickVariant('latest_movie_fit_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} movie time',
                        subMessage: 'Nice balance so far. Still well within budget.',
                      ),
                      (
                        message: 'Good way to spend time',
                        subMessage: 'Entertainment like this is great when it stays visible.',
                      ),
                      (
                        message: 'That was a good call',
                        subMessage: 'Everything looks balanced right now. This can keep going smoothly.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、映画だね',
                        subMessage: 'ちゃんと楽しめてるね。今のところは予算内でいい流れだよ。',
                      ),
                      (
                        message: '映画、いい使い方だね',
                        subMessage: 'こういう支出も見えてるのがいいね。平均${latestMovieAverage}円。',
                      ),
                      (
                        message: 'いい時間の使い方だね',
                        subMessage: '今はバランスも取れてるね。このままいけそうだよ。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_movie_$lang',
        notificationBody: _t(
          lang,
          '🎬 ${latestExpense.storeName} の映画系支出を記録したよ。',
          '🎬 ${latestExpense.storeName} movie spending logged.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.karaoke)) {
      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? _pickVariant('latest_karaoke_danger_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} karaoke time',
                    subMessage: 'Good release, but at this pace it is starting to hit the wallet a bit harder.',
                  ),
                  (
                    message: 'Looks like a singing day',
                    subMessage: 'The mood is probably better now. The budget, maybe slightly less so.',
                  ),
                  (
                    message: 'Karaoke came in strong',
                    subMessage: 'Fun is real. But if the visits stack up, the wallet will remember the chorus.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、カラオケだね',
                    subMessage: 'しっかり発散してるね。ただ今のペースだと、財布には少し強めに効いてるよ。',
                  ),
                  (
                    message: '歌ってきたね',
                    subMessage: '気分は良さそうだね。でも今月はちょっと前のめりな流れだよ。',
                  ),
                  (
                    message: 'カラオケ、強めに来てるね',
                    subMessage: '楽しさはあるね。ただ回数が重なると、財布もサビを覚えそうだよ。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? _pickVariant('latest_karaoke_warning_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} karaoke day',
                        subMessage: 'Nice release. The pace is starting to show a little though.',
                      ),
                      (
                        message: 'Karaoke is in a good flow',
                        subMessage: 'Enjoyable, but repeated sessions can start to echo later.',
                      ),
                      (
                        message: 'Singing day unlocked',
                        subMessage: 'Keeping the pace in view now should make the rest of the month easier.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、カラオケだね',
                        subMessage: 'いい発散だね。ただ少しペースは出てきてるよ。',
                      ),
                      (
                        message: 'カラオケ、いい流れだね',
                        subMessage: '楽しめてるね。ただ回数が増えるとじわっと響いてくるタイプだよ。',
                      ),
                      (
                        message: '今日は歌う日だね',
                        subMessage: '今のうちに少し整えると、後半も気持ちよく遊べるよ。',
                      ),
                    ])
              : _pickVariant('latest_karaoke_fit_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} karaoke time',
                        subMessage: 'Nice release. So far, the balance looks fine.',
                      ),
                      (
                        message: 'Good use of fun money',
                        subMessage: 'Spending like this is easier to enjoy when it stays visible.',
                      ),
                      (
                        message: 'That sounds like a good break',
                        subMessage: 'There is still room for this kind of fun right now.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、カラオケだね',
                        subMessage: 'ちゃんと発散できてるね。今のところは予算内でいい流れだよ。',
                      ),
                      (
                        message: 'カラオケ、いい使い方だね',
                        subMessage: 'こういう支出も見えてるのがいいね。バランス取れてるよ。',
                      ),
                      (
                        message: 'いい時間の使い方だね',
                        subMessage: '今は余裕もあるね。このまま楽しんでいけそうだよ。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_karaoke_$lang',
        notificationBody: _t(
          lang,
          '🎤 ${latestExpense.storeName} のカラオケ支出を記録したよ。',
          '🎤 ${latestExpense.storeName} karaoke spending logged.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.arcade)) {
      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? _pickVariant('latest_arcade_danger_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} arcade time',
                    subMessage: 'Fun is real, but at this pace it is starting to hit the wallet a bit harder.',
                  ),
                  (
                    message: 'Arcades are coming in strong',
                    subMessage: 'Great break, though the month is leaning forward a bit.',
                  ),
                  (
                    message: 'That play hit a bit heavy',
                    subMessage: 'Enjoyable, but repeated sessions will leave a clear footprint.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、遊び枠だね',
                    subMessage: '楽しそうだね。ただ今のペースだと、財布には少し強めに効いてるよ。',
                  ),
                  (
                    message: 'ゲーセン、来たね',
                    subMessage: '気分転換にはいいね。でも今月は少し前のめりな流れだよ。',
                  ),
                  (
                    message: '遊び、一発効いてるね',
                    subMessage: '楽しさの勝利だね。財布は静かに焦ってるよ。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? _pickVariant('latest_arcade_warning_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} arcade day',
                        subMessage: 'Nice break. The pace is starting to show a little though.',
                      ),
                      (
                        message: 'Arcades in a good flow',
                        subMessage: 'Fun, but repeated visits can start to show later.',
                      ),
                      (
                        message: 'Looks like a play day',
                        subMessage: 'Keeping the pace in view now should make the rest of the month easier.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、遊んできたね',
                        subMessage: 'まだ大丈夫だよ。ただ娯楽系としては少し存在感が出てきたよ。',
                      ),
                      (
                        message: 'ゲーセン、いい流れだね',
                        subMessage: '楽しい支出だね。でも積み重なると、あとで効いてくるタイプだよ。',
                      ),
                      (
                        message: '今日は遊びの日だね',
                        subMessage: '今のうちに少し整えると、後半も気持ちよく遊べるよ。',
                      ),
                    ])
              : _pickVariant('latest_arcade_fit_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} arcade time',
                        subMessage: 'Nice balance so far. Still within budget.',
                      ),
                      (
                        message: 'Good use of fun money',
                        subMessage: 'Spending like this is easier to enjoy when it stays visible.',
                      ),
                      (
                        message: 'That was a good break',
                        subMessage: 'There is still room for this kind of fun right now.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、遊び枠だね',
                        subMessage: '今のところは予算内で楽しめてるよ。いい流れだな。',
                      ),
                      (
                        message: '遊びのお金、見えてるね',
                        subMessage: 'こういう支出も見えてるのがいいね。管理しやすいよ。',
                      ),
                      (
                        message: 'いい時間の使い方だね',
                        subMessage: '今は落ち着いて見られるペースだよ。このまま楽しめそうだね。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_arcade_$lang',
        notificationBody: _t(
          lang,
          '🎮 ${latestExpense.storeName} の遊び系支出を記録したよ。',
          '🎮 ${latestExpense.storeName} arcade spending logged.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (hasConsecutiveStoreSpending && latestStore.isNotEmpty) {
      final variant = _pickVariant(
        'consecutive_store_${latestStore}_$lang',
        isEn
            ? [
                (
                  message: '$latestStore again',
                  subMessage: '$consecutiveStoreCount times in a row. This is becoming a pattern.',
                ),
                (
                  message: '$latestStore streak going',
                  subMessage: '$consecutiveStoreCount visits straight. Even the wallet remembers now.',
                ),
                (
                  message: '$latestStore is not stopping',
                  subMessage: 'At this point, it feels more like routine than coincidence.',
                ),
              ]
            : [
                (
                  message: '$latestStore、続いてるね',
                  subMessage: '$consecutiveStoreCount回続いてるよ。もう流れになってきてるね。',
                ),
                (
                  message: 'また$latestStoreだね',
                  subMessage: 'ここまで来ると、好きというより習慣に近いね。',
                ),
                (
                  message: '$latestStore、止まってないね',
                  subMessage: '$consecutiveStoreCount回連続。生活の一部っぽくなってきたね。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'consecutive_store_$lang',
        notificationBody: _t(
          lang,
          '$latestStore の支出が$consecutiveStoreCount回続いてるね。',
          '$latestStore spending $consecutiveStoreCount times in a row.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

else if (latestStore.isNotEmpty) {
  final count = storeCounts[latestStore] ?? 0;
  if (count >= 3) {
    final variant = _pickVariant(
      'store_repeat_${latestStore}_$lang',
      isEn
          ? [
              (
                message: '$latestStore shows up again',
                subMessage: '$count times this month. This is turning into a regular spot.',
              ),
              (
                message: 'Back to $latestStore',
                subMessage: 'Already $count visits. This is basically part of your routine now.',
              ),
              (
                message: '$latestStore frequency is high',
                subMessage: 'The pattern is clear. The wallet sees it too.',
              ),
            ]
          : [
              (
                message: '$latestStore、よく来てるね',
                subMessage: '今月$count回目だよ。もう定番ルートっぽいね。',
              ),
              (
                message: 'また$latestStoreだね',
                subMessage: '$count回目まで来てるよ。習慣になりつつあるね。',
              ),
              (
                message: '$latestStore率、高めだね',
                subMessage: '好きなのは伝わってるよ。財布にもちゃんと伝わってるけどね。',
              ),
            ],
    );

    latestComment = _LatestComment(
      scenarioKey: 'store_repeat_$lang',
      notificationBody: _t(
        lang,
        '$latestStore に今月$count回行ってるね。',
        '$latestStore visited $count times this month.',
      ),
      message: variant.message,
      subMessage: variant.subMessage,
    );
  } else {
    final variant = _pickVariant(
      'default_$lang',
      isEn
          ? [
              (
                message: '${latestExpense.storeName} this time',
                subMessage: 'Nothing dramatic. Just a small move in the month.',
              ),
              (
                message: 'A stop at ${latestExpense.storeName}',
                subMessage: 'One expense at a time. This is how the flow stays visible.',
              ),
              (
                message: '${latestExpense.storeName} in the flow',
                subMessage: 'Looks normal. Keeping it visible is what matters.',
              ),
            ]
          : [
              (
                message: '${latestExpense.storeName}だね',
                subMessage: '特に大きな動きではないね。でもこういうのが流れを作るよ。',
              ),
              (
                message: '${latestExpense.storeName}寄ったね',
                subMessage: '一つずつ見えてるの、かなりいい状態だよ。',
              ),
              (
                message: '${latestExpense.storeName}の流れだね',
                subMessage: '今のところは自然な動きだよ。ちゃんと追えてるね。',
              ),
            ],
    );

      latestComment = _LatestComment(
        scenarioKey: 'default_$lang',
        notificationBody: _t(
          lang,
          '支出を確認したよ。',
          'Spending noted.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
  }
}

    else if (judge.tags.contains(ExpenseJudgeTag.kids) ||
        judge.tags.contains(ExpenseJudgeTag.family)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_kids_mismatch_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} feels like family spending',
                    subMessage: 'It is under ${latestExpense.category}. Keeping family-related expenses separate can make the month much easier to read.',
                  ),
                  (
                    message: '${latestExpense.storeName} looks meaningful',
                    subMessage: 'If this was for kids or family, putting it in a clearer place can help later.',
                  ),
                  (
                    message: '${latestExpense.storeName} may be a bit broad',
                    subMessage: 'The more important the expense, the more helpful it is to keep it visible.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、家族枠っぽいね',
                    subMessage: '${latestExpense.category}に入ってるよ。分けておくと、あとでかなり見やすいよ。',
                  ),
                  (
                    message: '${latestExpense.storeName}、意味ある支出だね',
                    subMessage: '子どもや家族向けなら、ちゃんと見える場所に置くと安心だね。',
                  ),
                  (
                    message: '${latestExpense.storeName}、少し広めに入ってるね',
                    subMessage: '大事な支出ほど、あとで分かる形にしておくと助かるね。',
                  ),
                ])
          : _pickVariant('latest_kids_fit_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} is family spending',
                    subMessage: 'Some expenses matter beyond the number. This one can be watched gently.',
                  ),
                  (
                    message: '${latestExpense.storeName} feels necessary',
                    subMessage: 'Money for kids or family is not something to scold. Keeping it visible is what matters.',
                  ),
                  (
                    message: '${latestExpense.storeName} is worth noting',
                    subMessage: 'Looks like an important expense. The wallet will keep this one quiet and visible.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、家族枠だね',
                    subMessage: 'こういう支出は大事な場面もあるね。今日はやさしく見守るね。',
                  ),
                  (
                    message: '${latestExpense.storeName}、必要枠かもね',
                    subMessage: '子どもや家族向けのお金は、責めるよりちゃんと見えることが大事だね。',
                  ),
                  (
                    message: '${latestExpense.storeName}、大事な支出っぽいね',
                    subMessage: 'まずは静かに見守っておくね。こういうお金もちゃんと残しておくと安心だよ。',
                  ),
                ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_kids_$lang',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.gambling)) {
      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? _pickVariant('latest_gambling_danger_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} was a risky move',
                    subMessage: 'At this pace, it is hitting the wallet pretty hard. This is a good point to step back and check the flow.',
                  ),
                  (
                    message: 'The gambling pace is showing',
                    subMessage: 'There may be fun in it, but this month is leaning forward now.',
                  ),
                  (
                    message: 'That move carried weight',
                    subMessage: 'One round can shift the whole month. This is a good place to slow the flow down.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、勝負してきたね',
                    subMessage: '今のペースだと、財布にはかなり強めに効いてるよ。一度流れ、見たいところだね。',
                  ),
                  (
                    message: 'ギャンブル、来てるね',
                    subMessage: '楽しさはあるかもね。ただ今月はちょっと前のめりな流れだよ。',
                  ),
                  (
                    message: 'その一手、重めだね',
                    subMessage: '一回でも流れ変えるやつだよ。ここは少し落ち着きたいところだね。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? _pickVariant('latest_gambling_warning_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} was a gamble',
                        subMessage: 'Still manageable, but this category can build momentum quickly.',
                      ),
                      (
                        message: 'This is starting to show',
                        subMessage: 'Watching the flow now could make the rest of the month much easier.',
                      ),
                      (
                        message: 'That move is worth remembering',
                        subMessage: 'It can look light once, but repeated rounds tend to hit harder than expected.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、勝負したね',
                        subMessage: 'まだ大丈夫だよ。ただこのカテゴリは流れが出やすいからね。',
                      ),
                      (
                        message: 'ちょっと来てるね',
                        subMessage: '今のうちに流れ見ておくと、後半かなり楽になるよ。',
                      ),
                      (
                        message: 'その一手、覚えておきたいね',
                        subMessage: '軽く見えても、重なるとしっかり効いてくるタイプだよ。',
                      ),
                    ])
              : _pickVariant('latest_gambling_fit_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} is noted',
                        subMessage: 'So far, it is visible and under control. Keep watching the flow.',
                      ),
                      (
                        message: 'A betting day, then',
                        subMessage: 'The important part is that it is visible. From here, the flow matters.',
                      ),
                      (
                        message: 'One move made',
                        subMessage: 'There is still room for now. Just do not lose sight of the pattern.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、見えてるね',
                        subMessage: '今のところは把握できてるね。この流れ、ちゃんと見ていこうね。',
                      ),
                      (
                        message: '勝負の日だったね',
                        subMessage: 'まずは見えてるのがいいね。ここからどう動くかだね。',
                      ),
                      (
                        message: '一手打ったね',
                        subMessage: '今はまだ余裕あるね。流れだけは見失わないようにね。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_gambling_$lang',
        notificationBody: judge.shouldNotify
            ? _t(
                lang,
                '${latestExpense.storeName}でギャンブル系の支出を確認したよ。',
                '${latestExpense.storeName} gambling-related spending noted.',
              )
            : '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.luxury)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_luxury_mismatch_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} feels like a premium spend',
                    subMessage: 'It is under ${latestExpense.category}. Splitting this out can make the month much easier to read.',
                  ),
                  (
                    message: '${latestExpense.storeName} has presence',
                    subMessage: 'Big moves are easier to track when they are clearly placed.',
                  ),
                  (
                    message: '${latestExpense.storeName} might be a bit broad',
                    subMessage: 'Keeping larger expenses visible helps the wallet later.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、高級枠っぽいね',
                    subMessage: '${latestExpense.category}に入ってるよ。分けておくと、あとでかなり見やすいよ。',
                  ),
                  (
                    message: '${latestExpense.storeName}、存在感あるね',
                    subMessage: 'こういう支出は分けておくと、あとでかなり追いやすいよ。',
                  ),
                  (
                    message: '${latestExpense.storeName}、少し広めに入ってるね',
                    subMessage: '大きめの一手ほど、見える形にしておくと助かるよ。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_luxury_danger_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} came in strong',
                        subMessage: 'High satisfaction, but at this pace it is hitting the wallet quite hard.',
                      ),
                      (
                        message: 'That one has weight',
                        subMessage: 'A larger move like this can echo through the rest of the month.',
                      ),
                      (
                        message: 'A bold purchase there',
                        subMessage: 'Could be a great buy. From here, pacing might help.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、強めだね',
                        subMessage: '満足感は高そうだね。ただ今のペースだと、財布にはかなり重めに効いてるよ。',
                      ),
                      (
                        message: 'これは存在感あるね',
                        subMessage: '大きめの一手だね。今の流れだと、あとでかなり響きそうだね。',
                      ),
                      (
                        message: '${latestExpense.storeName}、一撃来たね',
                        subMessage: 'いい買い物かもしれないよ。ただここからは少し慎重でもよさそうだよ。',
                      ),
                    ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_luxury_warning_$lang', isEn
                      ? [
                          (
                            message: '${latestExpense.storeName} stands out a bit',
                            subMessage: 'Not risky yet, but the wallet is noticing this.',
                          ),
                          (
                            message: 'A slightly heavy move',
                            subMessage: 'Watching the pace now could make the rest easier.',
                          ),
                          (
                            message: '${latestExpense.storeName} looks like a good pick',
                            subMessage: 'Satisfying, just worth keeping an eye on the budget side.',
                          ),
                        ]
                      : [
                          (
                            message: '${latestExpense.storeName}、存在感あるね',
                            subMessage: 'まだ危険ではないよ。ただ財布はちゃんと反応してるね。',
                          ),
                          (
                            message: 'ちょっと強めの一手だね',
                            subMessage: '今のうちにペースを見ておくと、後半かなり楽になるよ。',
                          ),
                          (
                            message: '${latestExpense.storeName}、いいやつ買ったね',
                            subMessage: '満足感はありそうだね。予算面では少しだけ見ておきたいところだよ。',
                          ),
                        ])
                  : _pickVariant('latest_luxury_fit_$lang', isEn
                      ? [
                          (
                            message: '${latestExpense.storeName} noted',
                            subMessage: 'A bigger spend, but still clearly visible and under control.',
                          ),
                          (
                            message: '${latestExpense.storeName} has presence',
                            subMessage: 'Tracking these clearly is what keeps the balance healthy.',
                          ),
                          (
                            message: 'Looks like a good buy',
                            subMessage: 'For now, everything still feels balanced.',
                          ),
                        ]
                      : [
                          (
                            message: '${latestExpense.storeName}、見えてるね',
                            subMessage: '大きめの支出も見えてるね。今のところは落ち着いて見られるよ。',
                          ),
                          (
                            message: '${latestExpense.storeName}、存在感あるね',
                            subMessage: 'こういう一手も見える化できてるの、かなり大事だね。',
                          ),
                          (
                            message: 'いい買い物っぽいね',
                            subMessage: '今はまず、ちゃんと把握できてるのがいい状態だよ。',
                          ),
                        ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_luxury_$lang',
        notificationBody: judge.shouldNotify
            ? _t(
                lang,
                '${latestExpense.storeName}で少し大きめの支出を確認したよ。',
                '${latestExpense.storeName} premium spending noted.',
              )
            : '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.sensitive)) {
      final variant = _pickVariant(
        'latest_sensitive_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName}, noted quietly',
                  subMessage: 'This is something to keep on record, without going deeper.',
                ),
                (
                  message: '${latestExpense.storeName} is visible',
                  subMessage: 'No need to say much here. Just keeping it quietly in view.',
                ),
                (
                  message: '${latestExpense.storeName}, leaving it as is',
                  subMessage: 'Not everything needs a comment. This one stays gently recorded.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、静かに残しておくね',
                  subMessage: 'ここは深く触れないでおくよ。記録だけそっと置いておくね。',
                ),
                (
                  message: '${latestExpense.storeName}、見えてるよ',
                  subMessage: '今回は多くは言わない。静かに置いておくね。',
                ),
                (
                  message: '${latestExpense.storeName}、だね',
                  subMessage: 'ここは踏み込まないでおくよ。そっと見守っておくね。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_sensitive',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.cafe)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_cafe_mismatch_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} feels like a cafe stop',
                    subMessage: 'It is under ${latestExpense.category}. Splitting it out can make your habits much clearer.',
                  ),
                  (
                    message: '${latestExpense.storeName} might be grouped too broadly',
                    subMessage: 'Keeping cafe spending separate helps reveal the flow.',
                  ),
                  (
                    message: '${latestExpense.storeName} leans cafe',
                    subMessage: 'Separating this can make your patterns easier to see later.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、カフェ枠っぽいね',
                    subMessage: '${latestExpense.category}に入ってるよ。分けておくと、あとでかなり見やすいよ。',
                  ),
                  (
                    message: '${latestExpense.storeName}、ちょっと広めに入ってるね',
                    subMessage: 'カフェは分けておくと、流れがかなり見えるようになるよ。',
                  ),
                  (
                    message: '${latestExpense.storeName}、カフェ寄りだね',
                    subMessage: 'ちゃんと分けると、使い方のクセも見えてくるよ。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_cafe_danger_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} cafe stop',
                        subMessage: 'Relaxing, but this pace is starting to weigh on the wallet.',
                      ),
                      (
                        message: 'Cafe visits are adding up',
                        subMessage: 'Each one feels light, but together they are building a pattern.',
                      ),
                      (
                        message: 'That cup is stacking now',
                        subMessage: 'Individually small, but clearly noticeable at this point.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、カフェだね',
                        subMessage: 'ちょっとペース速いね。このままだと、財布にじわっと効いてくるよ。',
                      ),
                      (
                        message: 'カフェ、来てるね',
                        subMessage: 'リラックスは大事だね。ただ今月は少し前のめりな流れだよ。',
                      ),
                      (
                        message: 'その一杯、重なってきてるね',
                        subMessage: '一回は軽いけど、ここまで来るとちゃんと効いてるよ。',
                      ),
                    ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_cafe_warning_$lang', isEn
                      ? [
                          (
                            message: '${latestExpense.storeName} cafe time',
                            subMessage: 'Still fine, but the pace is starting to show a bit.',
                          ),
                          (
                            message: 'Cafe flow is forming',
                            subMessage: 'This could build up later if it keeps going like this.',
                          ),
                          (
                            message: 'A cafe kind of day',
                            subMessage: 'Light spending, but repetition is what matters here.',
                          ),
                        ]
                      : [
                          (
                            message: '${latestExpense.storeName}、カフェだね',
                            subMessage: 'まだ大丈夫だよ。ただ少しペースは出てきてるね。',
                          ),
                          (
                            message: 'カフェ、いい流れだね',
                            subMessage: 'このままいくと後半ちょっと効いてきそうだね。今のうちに見ておくといいよ。',
                          ),
                          (
                            message: '今日はカフェ気分だね',
                            subMessage: '軽い支出でも、積み重なるとちゃんと残るタイプだよ。',
                          ),
                        ])
                  : _pickVariant('latest_cafe_fit_$lang', isEn
                      ? [
                          (
                            message: '${latestExpense.storeName} cafe time',
                            subMessage: 'Nice balance so far. Still under control.',
                          ),
                          (
                            message: 'A good cafe break',
                            subMessage: 'Spending like this is easy to enjoy when it stays visible.',
                          ),
                          (
                            message: 'That cup looks right',
                            subMessage: 'Everything still feels balanced at this pace.',
                          ),
                        ]
                      : [
                          (
                            message: '${latestExpense.storeName}、カフェだね',
                            subMessage: 'ちゃんと楽しめてるね。今のところはいいバランスだよ。',
                          ),
                          (
                            message: 'カフェ、いい使い方だね',
                            subMessage: 'こういう支出も見えてるのがいいね。ちゃんとコントロールできてるよ。',
                          ),
                          (
                            message: 'その一杯、いい時間だね',
                            subMessage: '今は余裕あるね。このまま気持ちよくいけそうだよ。',
                          ),
                        ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_cafe_$lang',
        notificationBody: _t(
          lang,
          '☕ ${latestExpense.storeName} の支出を確認したよ。',
          '☕ ${latestExpense.storeName} cafe spending noted.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.convenience)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_convenience_mismatch_$lang', isEn
              ? [
                  (
                    message: '${latestExpense.storeName} feels like a convenience stop',
                    subMessage: 'It is under ${latestExpense.category}. Splitting this out can make your habits much clearer.',
                  ),
                  (
                    message: '${latestExpense.storeName} might be grouped too broadly',
                    subMessage: 'Separating convenience spending helps reveal frequency and flow.',
                  ),
                  (
                    message: '${latestExpense.storeName} leans convenience',
                    subMessage: 'This is easier to track when it stands on its own.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、コンビニ枠っぽいね',
                    subMessage: '${latestExpense.category}に入ってるよ。分けておくと、あとでかなり見やすいよ。',
                  ),
                  (
                    message: '${latestExpense.storeName}、ちょっと広めに入ってるね',
                    subMessage: 'コンビニは分けると、回数と流れがかなり見えるようになるよ。',
                  ),
                  (
                    message: '${latestExpense.storeName}、コンビニ寄りだね',
                    subMessage: 'ここを分けると、使い方のクセがはっきり出てくるよ。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_convenience_danger_$lang', isEn
                  ? [
                      (
                        message: '${latestExpense.storeName} again',
                        subMessage: 'Easy stops are stacking up. At this pace, it is clearly hitting the budget.',
                      ),
                      (
                        message: 'Convenience visits are adding up',
                        subMessage: 'Each one is small, but together they are leaving a mark.',
                      ),
                      (
                        message: 'That quick stop is not so light now',
                        subMessage: 'Small by itself, but repetition is doing the damage.',
                      ),
                    ]
                  : [
                      (
                        message: '${latestExpense.storeName}、また来たね',
                        subMessage: '今のペースだと、手軽さがそのまま予算に強めに効いてるよ。',
                      ),
                      (
                        message: 'コンビニ、来てるね',
                        subMessage: '一回は軽いね。ただここまで来ると、ちゃんと重なってるよ。',
                      ),
                      (
                        message: 'その一手、地味に効くやつだね',
                        subMessage: '小さいけど回数で来るタイプだよ。ここは少し流れ見たいところだね。',
                      ),
                    ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_convenience_warning_$lang', isEn
                      ? [
                          (
                            message: '${latestExpense.storeName} stop',
                            subMessage: 'Still fine, but the frequency is starting to show.',
                          ),
                          (
                            message: 'Convenience flow is forming',
                            subMessage: 'This could build up later if it keeps going like this.',
                          ),
                          (
                            message: 'Another quick stop',
                            subMessage: 'Easy spending like this tends to accumulate quietly.',
                          ),
                        ]
                      : [
                          (
                            message: '${latestExpense.storeName}、コンビニだね',
                            subMessage: 'まだ大丈夫だよ。ただ回数は少し出てきてるよ。',
                          ),
                          (
                            message: 'コンビニ、いい流れだね',
                            subMessage: 'このままいくと後半じわっと効いてきそうだね。今のうちに見ておくといいよ。',
                          ),
                          (
                            message: 'また寄ったね',
                            subMessage: '手軽さは強いね。積み重なるとしっかり残るタイプだよ。',
                          ),
                        ])
                  : _pickVariant('latest_convenience_fit_$lang', isEn
                      ? [
                          (
                            message: '${latestExpense.storeName} stop',
                            subMessage: 'Still balanced. Small moves like this are fine when visible.',
                          ),
                          (
                            message: 'A quick stop there',
                            subMessage: 'Easy spending, but still under control right now.',
                          ),
                          (
                            message: 'That was a light move',
                            subMessage: 'Everything still feels manageable at this pace.',
                          ),
                        ]
                      : [
                          (
                            message: '${latestExpense.storeName}、コンビニだね',
                            subMessage: '今のところはバランス取れてるね。ちゃんと見えてるのがいいよ。',
                          ),
                          (
                            message: 'コンビニ、いい使い方だね',
                            subMessage: 'こういう支出も見える化できてるの、かなり大事だね。',
                          ),
                          (
                            message: 'その一手、軽やかだね',
                            subMessage: '今は余裕あるね。このまま流れ見ていけそうだよ。',
                          ),
                        ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_convenience_$lang',
        notificationBody: _t(
          lang,
          '🏪 ${latestExpense.storeName} の支出を確認したよ。',
          '🏪 ${latestExpense.storeName} convenience spending noted.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.dining)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_dining_mismatch_$lang', isEn
              ? [
                  (
                    message: latestIsWeekend
                        ? 'Looks like a weekend meal out'
                        : 'This feels like dining out',
                    subMessage: 'It is under ${latestExpense.category}. Separating dining from groceries can make the month much easier to read.',
                  ),
                  (
                    message: 'This has meal-out energy',
                    subMessage: 'It may be easier to track as dining rather than a broad expense.',
                  ),
                  (
                    message: 'Dining out looks a bit mixed in',
                    subMessage: 'Putting it where the meaning is clear helps the wallet read the flow later.',
                  ),
                ]
              : [
                  (
                    message: latestIsWeekend
                        ? '週末外食っぽいね'
                        : 'これ、外食寄りだね',
                    subMessage: '${latestExpense.category}に入ってるよ。外食で分けると、食費との違いがかなり見やすいよ。',
                  ),
                  (
                    message: '食べに出た感じあるね',
                    subMessage: '急な出費より、外食として置いた方が流れを追いやすいよ。',
                  ),
                  (
                    message: '外食っぽいのに少し曖昧だね',
                    subMessage: '意味が見える場所に置いておくと、あとで財布も助かるよ。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_dining_danger_$lang', isEn
                  ? [
                      (
                        message: latestIsWeekend
                            ? 'Weekend dining is getting heavy'
                            : 'Dining out is coming in strong',
                        subMessage: 'Good food is valid. The dining pace, though, is moving pretty fast.',
                      ),
                      (
                        message: 'Looks like a good meal day',
                        subMessage: 'The satisfaction is probably high. The budget is leaning forward a bit too.',
                      ),
                      (
                        message: 'Dining out is starting to hit',
                        subMessage: 'Enjoyable, but the footprint is clearly showing now. Pacing from here might help.',
                      ),
                    ]
                  : [
                      (
                        message: latestIsWeekend
                            ? '週末外食、重めだね'
                            : '外食、流れ強めだね',
                        subMessage: 'おいしいのは正義だね。ただ外食枠の進み方はかなり速いよ。',
                      ),
                      (
                        message: 'おいしい日の流れだね',
                        subMessage: '満足度は高そうだよ。ただ予算の減り方は少し前のめりだね。',
                      ),
                      (
                        message: '外食、効いてきてるね',
                        subMessage: '楽しさのぶん、財布にもちゃんと残ってるよ。ここからは少し慎重でもいいね。',
                      ),
                    ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_dining_warning_$lang', isEn
                      ? [
                          (
                            message: latestIsWeekend
                                ? 'Weekend meal out, makes sense'
                                : 'Looks like a dining-out day',
                            subMessage: 'The category fits. The dining pace is just starting to show a little.',
                          ),
                          (
                            message: 'A proper meal-out move',
                            subMessage: 'Cleanly tracked. Keeping an eye on the pace now can make the second half easier.',
                          ),
                          (
                            message: 'A natural way to enjoy the day',
                            subMessage: 'Good spending if it fits the month. It is starting to have some presence though.',
                          ),
                        ]
                      : [
                          (
                            message: latestIsWeekend
                                ? '週末外食、それっぽいね'
                                : '今日は外食気分だね',
                            subMessage: 'カテゴリは合ってるよ。ただ外食枠は少しペース出てきてるよ。',
                          ),
                          (
                            message: '外食らしい一手だね',
                            subMessage: '記録はきれいだよ。ペースだけ少し見ておくと後半かなり楽だね。',
                          ),
                          (
                            message: '楽しみ方としては自然だね',
                            subMessage: 'いい使い方だよ。ただ今月の流れとしては少し存在感出てきたよ。',
                          ),
                        ])
                  : _pickVariant('latest_dining_fit_$lang', isEn
                      ? [
                          (
                            message: latestIsWeekend
                                ? 'Weekend meal out sounds right'
                                : 'Looks like a dining-out day',
                            subMessage: 'The category fits. So far, this is still a balanced way to enjoy the month.',
                          ),
                          (
                            message: 'Dining out is nicely separated',
                            subMessage: 'Keeping it apart from groceries makes the wallet much easier to read.',
                          ),
                          (
                            message: 'Good meal-out energy',
                            subMessage: 'At this pace, it still feels calm enough to enjoy.',
                          ),
                        ]
                      : [
                          (
                            message: latestIsWeekend
                                ? '週末に外で食べるの、いいね'
                                : '今日は外食の日だね',
                            subMessage: 'カテゴリも自然だよ。今のところは予算内で楽しめてるね。',
                          ),
                          (
                            message: '外食として見えてるね',
                            subMessage: '食費と分けて見えてるの、かなりいいよ。財布も追いやすい。',
                          ),
                          (
                            message: '食べに出る日の空気だね',
                            subMessage: '今はまだ落ち着いて見られるペースだよ。このまま楽しめそうだね。',
                          ),
                        ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_dining_$lang',
        notificationBody: _t(
          lang,
          '🍜 ${latestExpense.storeName} の支出を確認したよ。',
          '🍜 ${latestExpense.storeName} dining spending noted.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (_isOnlineShopping(latestExpense)) {
      final isHeavyHitOnline =
          onlineShoppingCount <= 2 && latestOnlineShoppingAverage >= 5000;
      final onlineAverageText = _formatMoney(latestOnlineShoppingAverage, lang);

      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? isHeavyHitOnline
              ? _pickVariant('latest_online_shopping_heavy_danger_$lang', isEn
                  ? [
                      (
                        message: latestTimeTone == 'late_night'
                            ? 'Late-night cart hit hard'
                            : 'Online shopping hit hard',
                        subMessage: 'The category fits, but about $onlineAverageText per order is hitting the wallet pretty strongly.',
                      ),
                      (
                        message: 'Your finger was light',
                        subMessage: 'The amount was not. Online shopping is leaning forward this month.',
                      ),
                      (
                        message: 'It has presence before it even arrives',
                        subMessage: 'The category is right. From here, slowing the pace may help.',
                      ),
                    ]
                  : [
                      (
                        message: latestTimeTone == 'late_night'
                            ? '深夜に大きめポチりだね'
                            : '通販、一撃重めだね',
                        subMessage: 'カテゴリは合ってるよ。ただ1回あたり約$onlineAverageText、財布にはかなり強めに効いてるよ。',
                      ),
                      (
                        message: '指先は軽いね',
                        subMessage: 'でも金額は軽くないよ。今月の通販枠、だいぶ前のめりだね。',
                      ),
                      (
                        message: '届く前から存在感あるね',
                        subMessage: 'カテゴリはぴったりだよ。ただここからは少し慎重でもよさそうだね。',
                      ),
                    ])
              : _pickVariant('latest_online_shopping_repeat_danger_$lang', isEn
                  ? [
                      (
                        message: latestTimeTone == 'late_night'
                            ? 'Late-night orders are becoming a flow'
                            : 'Online orders are adding up',
                        subMessage: 'The category fits. Convenience is clearly showing up in the budget now.',
                      ),
                      (
                        message: 'Things keep arriving',
                        subMessage: 'The tracking is clean, but the online shopping pace is getting tight.',
                      ),
                      (
                        message: 'This buying rhythm is leaning forward',
                        subMessage: 'The category is right. This month’s online shopping pace is worth watching.',
                      ),
                    ]
                  : [
                      (
                        message: latestTimeTone == 'late_night'
                            ? '深夜ポチり、流れ出てるね'
                            : '通販、回数で来てるね',
                        subMessage: 'カテゴリは合ってるよ。便利さの反復が予算にしっかり出てるよ。',
                      ),
                      (
                        message: '気づいたら届く流れだね',
                        subMessage: '記録は自然だよ。ただ通販枠の減り方は少し厳しめだね。',
                      ),
                      (
                        message: 'その買い方、前のめりだね',
                        subMessage: 'カテゴリはぴったりだよ。今月の通販ペースは少し見ておきたいね。',
                      ),
                    ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? isHeavyHitOnline
                  ? _pickVariant('latest_online_shopping_heavy_warning_$lang', isEn
                      ? [
                          (
                            message: latestTimeTone == 'late_night'
                                ? 'A larger night purchase'
                                : 'That one had weight',
                            subMessage: 'The category fits. About $onlineAverageText per order has real presence for online shopping.',
                          ),
                          (
                            message: 'Not many orders, but still heavy',
                            subMessage: 'The amount is stepping forward. Watching the pace now can make the rest easier.',
                          ),
                          (
                            message: 'More than just a quick tap',
                            subMessage: 'The category is natural. A little adjustment now could help later.',
                          ),
                        ]
                      : [
                          (
                            message: latestTimeTone == 'late_night'
                                ? '夜に大きめ買い物だね'
                                : '単発の重み、出てるね',
                            subMessage: 'カテゴリは合ってるよ。1回あたり約$onlineAverageText、通販枠では存在感あるよ。',
                          ),
                          (
                            message: '回数は少ないね',
                            subMessage: 'でも金額は前に出てるよ。ペースだけ見ておくと後半楽だね。',
                          ),
                          (
                            message: 'ポチりというより、しっかり買った日だね',
                            subMessage: 'カテゴリは自然だよ。今のうちに少し整えると楽になりそうだね。',
                          ),
                        ])
                  : _pickVariant('latest_online_shopping_repeat_warning_$lang', isEn
                      ? [
                          (
                            message: latestTimeTone == 'late_night'
                                ? 'Night orders are starting to show'
                                : 'Online order frequency is showing',
                            subMessage: 'The category fits. Online shopping is moving a little fast.',
                          ),
                          (
                            message: 'Each order may be light',
                            subMessage: 'But the frequency is starting to matter. Worth watching for the second half.',
                          ),
                          (
                            message: 'The delivery trail is getting visible',
                            subMessage: 'The category is clean. The month’s flow is just starting to lean forward.',
                          ),
                        ]
                      : [
                          (
                            message: latestTimeTone == 'late_night'
                                ? '夜ポチ、少し流れ出てるね'
                                : '通販の回数、目立ってきたね',
                            subMessage: 'カテゴリは合ってるよ。ただ通販枠は少し早めのペースだね。',
                          ),
                          (
                            message: '一回ごとは軽めだね',
                            subMessage: 'でも回数で効いてきてるよ。後半のために少し見ておきたいね。',
                          ),
                          (
                            message: '届く系、存在感出てきたね',
                            subMessage: 'カテゴリはきれいだよ。ただ今月の流れとしては少し前に出てるね。',
                          ),
                        ])
              : isHeavyHitOnline
                  ? _pickVariant('latest_online_shopping_heavy_fit_$lang', isEn
                      ? [
                          (
                            message: latestTimeTone == 'late_night'
                                ? 'A solid night purchase'
                                : 'Online shopping, clearly chosen',
                            subMessage: 'The category fits. Still within budget, though the single-order weight is visible.',
                          ),
                          (
                            message: 'That was a proper purchase',
                            subMessage: 'It is easy to read as online shopping. Low frequency, but solid unit price.',
                          ),
                          (
                            message: 'Not just a light tap today',
                            subMessage: 'Looks like a chosen purchase. The pace is still calm for now.',
                          ),
                        ]
                      : [
                          (
                            message: latestTimeTone == 'late_night'
                                ? '夜にしっかり買った日だね'
                                : '通販、ちゃんと選んだ日だね',
                            subMessage: 'カテゴリも自然だよ。今は予算内で見られてるけど、一撃の存在感はあるね。',
                          ),
                          (
                            message: 'かなり買った感あるね',
                            subMessage: '通販として見やすく残せてるよ。回数は少なくても単価はしっかりめだね。',
                          ),
                          (
                            message: '指先が軽い日じゃないね',
                            subMessage: 'ちゃんと選んだ日だね。今はまだ落ち着いて見られるペースだね。',
                          ),
                        ])
                  : _pickVariant('latest_online_shopping_repeat_fit_$lang', isEn
                      ? [
                          (
                            message: latestTimeTone == 'late_night'
                                ? 'Night shopping, that kind of day'
                                : 'Online shopping fits here',
                            subMessage: 'The category fits. So far, this is still within a manageable pace.',
                          ),
                          (
                            message: 'Online spending is clearly placed',
                            subMessage: 'Delivery-type spending is easy to follow when it is separated like this.',
                          ),
                          (
                            message: 'The delivery side of the month',
                            subMessage: 'The category fits. For now, the pace still looks calm.',
                          ),
                        ]
                      : [
                          (
                            message: latestTimeTone == 'late_night'
                                ? '夜ポチ、そういう日だね'
                                : '通販として自然だね',
                            subMessage: 'カテゴリも合ってるよ。今のところは予算内で見られてるね。',
                          ),
                          (
                            message: '通販として見えてるね',
                            subMessage: '届く系の支出として見やすく残せてるよ。財布も追いやすいね。',
                          ),
                          (
                            message: '気づいたら届く側だね',
                            subMessage: 'カテゴリは合ってるよ。今はまだ落ち着いて見られるペースだね。',
                          ),
                        ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_online_shopping_$lang',
        notificationBody: _t(
          lang,
          '🛒 ${latestExpense.storeName} の支出を確認したよ。',
          '🛒 ${latestExpense.storeName} online shopping noted.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.hobby)) {
      final variant = _pickVariant(
        'latest_hobby_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName} hobby time',
                  subMessage: 'Good use of fun money. The enjoyable stuff is exactly what tends to add up by repetition.',
                ),
                (
                  message: '${latestExpense.storeName} is something you like',
                  subMessage: 'Spending on things you enjoy matters. The wallet is just keeping the pattern visible.',
                ),
                (
                  message: '${latestExpense.storeName} is becoming a thing',
                  subMessage: 'Nice flow. Just the kind of spending that quietly stacks up when it keeps showing up.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、趣味の時間だね',
                  subMessage: 'いい使い方だね。ただ楽しいやつほど、回数でちゃんと効いてくるね。',
                ),
                (
                  message: '${latestExpense.storeName}、好きなやつだね',
                  subMessage: '好きなことに使うお金は大事だね。財布は流れだけ静かに見てるよ。',
                ),
                (
                  message: '${latestExpense.storeName}、ハマってきてるね',
                  subMessage: 'いい流れだね。ただこの手の支出、気づいたら積み上がってるやつだね。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_hobby_$lang',
        notificationBody: judge.shouldNotify
            ? _t(
                lang,
                '${latestExpense.storeName}で趣味系の支出を確認したよ。',
                '${latestExpense.storeName} hobby spending noted.',
              )
            : '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.beauty)) {
      final variant = _pickVariant(
        'latest_beauty_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName} self-care time',
                  subMessage: 'Good kind of spending. It can lift the mood, and it still deserves to stay visible.',
                ),
                (
                  message: '${latestExpense.storeName} was a nice reset',
                  subMessage: 'Spending on yourself can be healthy. Repetition is the only part worth watching.',
                ),
                (
                  message: '${latestExpense.storeName} polished things up',
                  subMessage: 'Satisfaction is probably high. Just keep a gentle eye on the pace.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、整えてきたね',
                  subMessage: 'いい使い方だね。見た目だけじゃなくて、気分も上がるやつだね。',
                ),
                (
                  message: '${latestExpense.storeName}、いいリセットだね',
                  subMessage: 'ちゃんと自分に使ってるね。ただ積み重なると、財布には静かに効いてくるね。',
                ),
                (
                  message: '${latestExpense.storeName}、仕上げてきたね',
                  subMessage: '満足感は高そうだね。そのぶん、ペースだけ少し見ておきたいところだね。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_beauty_$lang',
        notificationBody: judge.shouldNotify
            ? _t(
                lang,
                '${latestExpense.storeName}で美容系の支出を確認したよ。',
                '${latestExpense.storeName} beauty spending noted.',
              )
            : '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (ruleResult?.categoryFit == CategoryFit.mismatch) {
      final variant = _pickVariant(
        'latest_rule_mismatch_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName} might be too broad',
                  subMessage: 'It is under ${latestExpense.category}. Splitting it out can make the month much easier to read.',
                ),
                (
                  message: '${latestExpense.storeName} may be in the wrong spot',
                  subMessage: 'This expense will be much easier to follow later if it has a clearer place.',
                ),
                (
                  message: '${latestExpense.storeName} looks a bit vague',
                  subMessage: 'Putting it where the meaning is clear helps the wallet stay organized.',
                ),
                (
                  message: '${latestExpense.storeName} feels like an unplanned expense',
                  subMessage: 'If it was truly unexpected, that is fine. If it repeats, a separate category may help.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、少し広めに入ってるね',
                  subMessage: '${latestExpense.category}に入ってるよ。分けておくと、あとでかなり見やすいね。',
                ),
                (
                  message: '${latestExpense.storeName}、置き場所迷子かもね',
                  subMessage: 'この支出、分けておくと後からかなり追いやすくなるよ。',
                ),
                (
                  message: '${latestExpense.storeName}、ちょっと曖昧だね',
                  subMessage: '意味が見える場所に置くと、財布もだいぶ整理しやすいね。',
                ),
                (
                  message: '${latestExpense.storeName}、急な出費枠だね',
                  subMessage: '本当に予定外ならOKだね。続くならカテゴリ作った方が見やすいね。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_rule_mismatch_$lang',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (ruleResult?.paceStatus == PaceStatus.danger ||
        ruleResult?.paceStatus == PaceStatus.over) {
      final variant = _pickVariant(
        'latest_rule_danger_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName} is moving fast',
                  subMessage: 'This category is leaning forward pretty hard. The wallet is trying to keep up.',
                ),
                (
                  message: '${latestExpense.storeName} is starting to hit',
                  subMessage: 'At this pace, this category may be pushing a little too far.',
                ),
                (
                  message: '${latestExpense.storeName} has weight now',
                  subMessage: 'Enjoying it is fine. The budget pace, though, is getting pretty tight.',
                ),
                (
                  message: 'This category is heating up',
                  subMessage: '${latestExpense.storeName} is not alone here. The overall pace in this category needs a look.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、ペース速いね',
                  subMessage: 'このカテゴリ、かなり前のめりだね。財布が少し追いかけてるよ。',
                ),
                (
                  message: '${latestExpense.storeName}、効いてきてるね',
                  subMessage: '今の流れだと、このカテゴリはちょっと攻めすぎかもね。',
                ),
                (
                  message: '${latestExpense.storeName}、少し重いね',
                  subMessage: '楽しめてるならいいね。ただ予算の進み方はなかなか厳しめだね。',
                ),
                (
                  message: 'このカテゴリ、熱くなってるね',
                  subMessage: '${latestExpense.storeName}だけじゃなくて、全体のペースも少し見たいところだね。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_rule_danger_$lang',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (ruleResult?.paceStatus == PaceStatus.warning) {
      final variant = _pickVariant(
        'latest_rule_warning_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName} is moving a bit fast',
                  subMessage: 'Still within budget, but this category is starting to lean forward.',
                ),
                (
                  message: '${latestExpense.storeName} is forming a flow',
                  subMessage: 'Still okay for now. Watching it here can make the second half much easier.',
                ),
                (
                  message: '${latestExpense.storeName} is worth noticing',
                  subMessage: 'The single expense may be fine, but the pace is starting to matter.',
                ),
                (
                  message: 'This category is warming up',
                  subMessage: 'Not a problem yet. Just a good moment to keep the pace visible.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、少し早めだね',
                  subMessage: 'まだ予算内だね。ただこのカテゴリ、ちょっと前のめりになってきたね。',
                ),
                (
                  message: '${latestExpense.storeName}、流れ出てきたね',
                  subMessage: 'まだ大丈夫だね。でも今のうちに見ておくと後半かなり楽だね。',
                ),
                (
                  message: '${latestExpense.storeName}、ちょい意識だね',
                  subMessage: '一回ごとの重さとペースを見ると、少しだけ気にしておきたいところだね。',
                ),
                (
                  message: 'このカテゴリ、少し温まってきたね',
                  subMessage: 'まだ問題ではないよ。ただ今のうちに流れを見ておくと安心だね。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_rule_warning_$lang',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.ceremony)) {
      final variant = _pickVariant(
        'latest_ceremony_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName} feels meaningful',
                  subMessage: 'Some spending belongs to important moments. The wallet will keep this one gently visible.',
                ),
                (
                  message: '${latestExpense.storeName} is for an important occasion',
                  subMessage: 'Gifts, ceremonies, and obligations are not something to scold. Just keeping it in view.',
                ),
                (
                  message: '${latestExpense.storeName}, noted with care',
                  subMessage: 'Money spent for people or important moments can matter beyond the number. No extra comment needed.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、大事な場面だね',
                  subMessage: 'お祝いごとや必要な付き合いもあるね。ここは静かに見守るよ。',
                ),
                (
                  message: '${latestExpense.storeName}、意味ある支出だね',
                  subMessage: '冠婚葬祭や贈り物なら、責めるところじゃないね。やさしく受け止めるよ。',
                ),
                (
                  message: '${latestExpense.storeName}、そっと残しておくね',
                  subMessage: '大事な人や場面に使うお金もあるね。今回は多くは言わないよ。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_ceremony_$lang',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

else if (judge.tags.contains(ExpenseJudgeTag.health) ||
        judge.tags.contains(ExpenseJudgeTag.transport)) {
      final variant = _pickVariant(
        'latest_essential_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName} is essential',
                  subMessage: 'Health and mobility come first. This is not where you force cuts.',
                ),
                (
                  message: '${latestExpense.storeName} is necessary',
                  subMessage: 'This is tied to daily life. The wallet will just keep it quietly visible.',
                ),
                (
                  message: '${latestExpense.storeName} sits on an important line',
                  subMessage: 'Spending what is needed here is fine. Just keep an eye on the flow.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、必要枠だね',
                  subMessage: '体や移動に関わるやつだね。ここは無理に削る場面じゃないよ。',
                ),
                (
                  message: '${latestExpense.storeName}、外せないやつだね',
                  subMessage: '生活に直結する支出だね。今回は静かに見守っておくよ。',
                ),
                (
                  message: '${latestExpense.storeName}、大事なラインだね',
                  subMessage: '必要な分はちゃんと使っていいところだね。流れだけ軽く見ておこう。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_essential_$lang',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }
    else {
      final variant = _pickVariant(
        'latest_fallback_$lang',
        isEn
            ? [
                (
                  message: '${latestExpense.storeName} is in view',
                  subMessage: 'Nothing dramatic for now. Keeping each expense visible is already doing the work.',
                ),
                (
                  message: '${latestExpense.storeName} showed up',
                  subMessage: 'One small move in the month. The wallet can follow the flow better when it stays visible.',
                ),
                (
                  message: '${latestExpense.storeName} this time',
                  subMessage: 'Looks calm for now. These small records are what keep the month readable.',
                ),
              ]
            : [
                (
                  message: '${latestExpense.storeName}、見えてるね',
                  subMessage: '今のところは落ち着いて見られてるね。一つずつ見えるのが大事だよ。',
                ),
                (
                  message: '${latestExpense.storeName}、流れに入ったね',
                  subMessage: '小さな一手でも、見えてるだけで財布はかなり追いやすいよ。',
                ),
                (
                  message: '${latestExpense.storeName}だね',
                  subMessage: 'ちゃんと把握できてるね。この積み重ねがあとで効いてくるよ。',
                ),
              ],
      );

      latestComment = _LatestComment(
        scenarioKey: 'latest_fallback_$lang',
        notificationBody: _t(
          lang,
          '支出を確認したよ。',
          'Spending noted.',
        ),
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    //     if (overallUsageRate >= 1.0 &&
    //     _shouldOverrideLatestWithOverallOver(latestComment.scenarioKey)) {
    //   final variant = _pickVariant('latest_overall_over', [
    //     (
    //       message: '今のところ大丈夫、ではもうないです。',
    //       subMessage: '全体ではすでに予算オーバーです。直近の一件も、追加ラウンドとして見た方が自然です。',
    //     ),
    //     (
    //       message: '今回の支出、もう延長戦の一手です。',
    //       subMessage: 'カテゴリ単体では軽く見えても、全体ではすでに上限を越えています。',
    //     ),
    //     (
    //       message: 'この支出、今月の追加ラウンド側ですね。',
    //       subMessage: '直近だけ見ると普通でも、全体ではもう余裕が残っていない状態です。',
    //     ),
    //   ]);

    //   latestComment = _LatestComment(
    //     scenarioKey: 'latest_overall_over',
    //     notificationBody: latestComment.notificationBody,
    //     message: variant.message,
    //     subMessage: variant.subMessage,
    //     priority: latestComment.priority,
    //   );
    // }

final baseLatestComment = latestComment;

final uiLatestComment =
    _higherPriorityLatestComment(baseLatestComment, priorityLatestComment) ??
        baseLatestComment;

_LatestComment notificationSource = baseLatestComment;

if (_isSameContext(baseLatestComment, priorityLatestComment)) {
  notificationSource = priorityLatestComment!;
}


return _composeLayeredResult(
  languageCode: lang,
  title: latestExpense.storeName.isNotEmpty
      ? _t(
          lang,
          '${latestExpense.storeName}、記録したよ',
          '${latestExpense.storeName} logged',
        )
      : _t(lang, '動きあったね', 'Something moved'),
  leadMessage: secondaryMessage,
  leadSubMessage: secondarySubMessage,
  monthly: monthlyComment,
  latest: uiLatestComment,
  notificationSource: notificationSource,
);
  }
}