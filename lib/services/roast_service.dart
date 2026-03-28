import 'package:saiyome/models/expense.dart';
import 'package:saiyome/services/expense_judge_service.dart';
import 'package:saiyome/services/spending_rule_service.dart';
import 'package:saiyome/services/unknown_expense_ai_service.dart';


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
  ];

  static const List<String> convenienceKeywords = [
    'セブン',
    'セブンイレブン',
    'ローソン',
    'ファミマ',
    'ファミリーマート',
    'ミニストップ',
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
  ];

  static bool _isCafe(Expense e) {
    final name = e.storeName.toLowerCase();
    if (e.category == 'カフェ') return true;
    return cafeKeywords.any((k) => name.contains(k.toLowerCase()));
  }

  static bool _isConvenience(Expense e) {
    final name = e.storeName.toLowerCase();
    if (e.category == 'コンビニ') return true;
    return convenienceKeywords.any((k) => name.contains(k.toLowerCase()));
  }

  static bool _isDining(Expense e) {
    return e.category == '外食';
  }

  static bool _isOnlineShopping(Expense e) {
    final name = e.storeName.toLowerCase();
    if (e.category == 'ネットショッピング' || e.category == '通販') {
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
    String title = '財布からひとこと',
    String? leadMessage,
    String? leadSubMessage,
    required _MonthlyComment monthly,
    required _LatestComment latest,
    required _LatestComment notificationSource,
  }) {
    return _composeResult(
      title: title,
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
    _LatestComment? best;

    if (latestStore.isNotEmpty && latestStoreCount >= 10) {
      final variant = _pickVariant('priority_store_repeat_strong_$latestStore', [
        (
          message: '$latestStore、今月$latestStoreCount回です。',
          subMessage: 'ここまで来ると、カテゴリより店の方が主役です。かなり強い習慣になっています。',
        ),
        (
          message: '$latestStore、今月もう$latestStoreCount回目です。',
          subMessage: '好きなお店の域を超えて、生活の一部になっています。財布もしっかり覚えています。',
        ),
        (
          message: '$latestStore率、かなり高いです。',
          subMessage: '今回は直近1件より、この店への通い方の方がかなり重要そうです。完全に流れができています。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_store_repeat_strong',
          notificationBody: '$latestStore の支出が今月$latestStoreCount回あります。',
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 102,
        ),
      );
    } else if (latestStore.isNotEmpty && latestStoreCount >= 5) {
      final variant = _pickVariant('priority_store_repeat_mid_$latestStore', [
        (
          message: '$latestStore、今月$latestStoreCount回目です。',
          subMessage: 'かなり通っていますね。カテゴリより、この店の存在感の方が前に出てきています。',
        ),
        (
          message: '$latestStore、今月もう$latestStoreCount回あります。',
          subMessage: '好みがかなりはっきりしています。ここまで来ると、ちゃんと傾向です。',
        ),
        (
          message: '$latestStore率、今月は高めです。',
          subMessage: '今回は直近の1件より、この店への偏りの方がかなり見えてきます。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_store_repeat_mid',
          notificationBody: '$latestStore の支出が今月$latestStoreCount回あります。',
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 92,
        ),
      );
    } else if (latestStore.isNotEmpty && latestStoreCount >= 3) {
      final variant = _pickVariant('priority_store_repeat_light_$latestStore', [
        (
          message: '$latestStore、今月$latestStoreCount回目ですね。',
          subMessage: '少しずつですが、この店に通う流れが見えてきています。',
        ),
        (
          message: '$latestStore、今月$latestStoreCount回あります。',
          subMessage: 'カテゴリより、この店の登場回数の方が少し気になってきました。',
        ),
        (
          message: '$latestStore、今月はよく見かけます。',
          subMessage: 'まだ強すぎるわけではありませんが、傾向としてはかなり見えやすくなっています。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_store_repeat_light',
          notificationBody: '$latestStore の支出が今月$latestStoreCount回あります。',
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 82,
        ),
      );
    }

    if (convenienceCount >= 4) {
      final variant = _pickVariant('priority_convenience_repeat', [
        (
          message: 'コンビニ、今月$convenienceCount回ですね。',
          subMessage: '直近の1件より、回数の方がかなり流れを作っています。手軽さがそのまま積み上がっています。',
        ),
        (
          message: '今月、コンビニが$convenienceCount回あります。',
          subMessage: '1回ずつは軽くても、ここまで来ると完全に傾向です。財布もしっかり気づいています。',
        ),
        (
          message: 'コンビニ率、今月は高めです。',
          subMessage: '単発よりも反復が目立っています。流れとして見るなら、いま一番前に出ている支出です。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_convenience_repeat',
          notificationBody: 'コンビニ支出が今月$convenienceCount回あります。',
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 100,
        ),
      );
    }

    if (onlineShoppingCount >= 3) {
      final variant = _pickVariant('priority_online_repeat', [
        (
          message: 'ネットショッピング、今月$onlineShoppingCount回です。',
          subMessage: '直近の1件より、今月の反復の方がかなり目立っています。便利さが流れになっています。',
        ),
        (
          message: '通販の回数、今月は少し強めです。',
          subMessage: '単発よりも積み重ねの存在感が前に出ています。気づいたら届く流れになっています。',
        ),
        (
          message: '今月のネット購入は$onlineShoppingCount回あります。',
          subMessage: '今回は直近1件より、この回数の方がかなり重要そうです。反復が財布に効いています。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_online_repeat',
          notificationBody: 'ネットショッピング支出が今月$onlineShoppingCount回あります。',
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 98,
        ),
      );
    }

    if (cafeCount >= 4) {
      final variant = _pickVariant('priority_cafe_repeat', [
        (
          message: 'カフェ、今月$cafeCount回ですね。',
          subMessage: '直近の1件より、回数の方がかなり傾向を作っています。気分転換が習慣になっています。',
        ),
        (
          message: '今月、カフェが$cafeCount回あります。',
          subMessage: '一杯ずつでも、ここまで来るとしっかり流れです。単発よりも反復が前に出ています。',
        ),
        (
          message: 'カフェ率、今月は高めです。',
          subMessage: '今回は直近1件より、この回数の方が見えてきます。じわじわ効くタイプです。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_cafe_repeat',
          notificationBody: 'カフェ支出が今月$cafeCount回あります。',
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 96,
        ),
      );
    }

    if (diningCount >= 3) {
      final variant = _pickVariant('priority_dining_repeat', [
        (
          message: '外食、今月$diningCount回ですね。',
          subMessage: '直近の1件より、外食の流れの方がかなり見えてきます。満足感のぶん、存在感もあります。',
        ),
        (
          message: '今月の外食は$diningCount回あります。',
          subMessage: '単発よりも回数の方が前に出ています。今月の使い方としては、かなり流れができています。',
        ),
        (
          message: '外食ペース、今月は少し高めです。',
          subMessage: '今回は直近1件より、この反復の方が重要そうです。後半の余裕に効いてきそうです。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_dining_repeat',
          notificationBody: '外食支出が今月$diningCount回あります。',
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 94,
        ),
      );
    }

    if (spendingRate >= 0.25) {
      final variant = _pickVariant('priority_expensive_spending', [
        (
          message: '${latestExpense.storeName}で$amount円、今回はかなり大きいですね。',
          subMessage: '回数よりもまずこの一撃の重さが前に出ています。今月の流れに対してもかなり存在感があります。',
        ),
        (
          message: '$amount円の支出、かなり効いています。',
          subMessage: '今回は直近の店名より、この金額の重さの方が重要そうです。財布もしっかり反応しています。',
        ),
        (
          message: '${latestExpense.storeName}、今回は一回の重みが強いです。',
          subMessage: '単発でも、ここまで大きいと今月の流れを変えやすい支出です。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_expensive_spending',
          notificationBody: '${latestExpense.storeName}で大きめの支出を記録しました。',
          message: variant.message,
          subMessage: variant.subMessage,
          priority: 82,
        ),
      );
    } else if (spendingRate >= 0.15) {
      final variant = _pickVariant('priority_mid_spending', [
        (
          message: '${latestExpense.storeName}で$amount円、今回は少し重ためです。',
          subMessage: '回数よりも、この一回の存在感の方が今は前に出ています。積み重なるとかなり効いてきそうです。',
        ),
        (
          message: '$amount円の支出、じわっと大きいですね。',
          subMessage: '今回は店名より、この金額感の方がかなり重要そうです。今月の余裕に効いてきます。',
        ),
        (
          message: '${latestExpense.storeName}、今回の支出は存在感があります。',
          subMessage: '単発でも軽くはないサイズなので、今月の流れとして少し意識したいところです。',
        ),
      ]);

      best = _higherPriorityLatestComment(
        best,
        _LatestComment(
          scenarioKey: 'priority_mid_spending',
          notificationBody: '${latestExpense.storeName}でやや大きめの支出を記録しました。',
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
        final variant = _pickVariant('priority_remaining_per_day_critical', [
          (
            message: '残り$daysLeft日で$remainingBudget円です。',
            subMessage: '今回は店名より、ここからの厳しさの方がかなり重要です。1日ごとの余白がほぼありません。',
          ),
          (
            message: 'あと$daysLeft日、残り$remainingBudget円ですね。',
            subMessage: '直近1件より、この先の配分の方が前に出ています。かなり慎重にいきたいところです。',
          ),
          (
            message: '残り$remainingBudget円で、あと$daysLeft日です。',
            subMessage: '今月の流れとしてはかなりハードです。ここからは一回ごとの判断が重くなります。',
          ),
        ]);

        best = _higherPriorityLatestComment(
          best,
          _LatestComment(
            scenarioKey: 'priority_remaining_per_day_critical',
            notificationBody: '残り予算がかなり厳しくなっています。',
            message: variant.message,
            subMessage: variant.subMessage,
            priority: 92,
          ),
        );
      } else if (remainingPerDay <= 300) {
        final variant = _pickVariant('priority_remaining_per_day_warning', [
          (
            message: '残り$daysLeft日で$remainingBudget円です。',
            subMessage: '今回は店名より、残り配分の方がかなり大事そうです。後半を楽にするなら少し整えたいところです。',
          ),
          (
            message: 'あと$daysLeft日、残り$remainingBudget円ですね。',
            subMessage: '直近1件よりも、この先の使い方の方が前に出ています。少し慎重なくらいがちょうどよさそうです。',
          ),
          (
            message: '残り$remainingBudget円で、あと$daysLeft日です。',
            subMessage: '今月の余白は少し細めです。ここからの配分を意識していきたいところです。',
          ),
        ]);

        best = _higherPriorityLatestComment(
          best,
          _LatestComment(
            scenarioKey: 'priority_remaining_per_day_warning',
            notificationBody: '残り予算の配分を意識したい状態です。',
            message: variant.message,
            subMessage: variant.subMessage,
            priority: 76,
          ),
        );
      }
    }

    return best;
  }

  static _MonthlyComment _defaultMonthlyComment() {
    return const _MonthlyComment(
      scenarioKey: 'monthly_normal',
      notificationBody: '',
      message: '今月は大きく崩れてはいません。',
      subMessage: 'このまま流れを見ながら、ゆるく整えていけそうです。',
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
    if (overallUsageRate >= 1.0) {
      final variant = _pickVariant('overall_over', [
        (
          message: '今月の予算、もう終わってます。',
          subMessage: 'ここから先は、完全に未来の自分へのツケです。',
        ),
        (
          message: '全体予算、使い切りました。',
          subMessage: 'ここから先の支出は、すべて延長戦です。',
        ),
        (
          message: '予算オーバーです。',
          subMessage: '財布はすでに今月の役目を終えた顔をしています。',
        ),
        (
          message: '今月の上限を突破しました。',
          subMessage: '少しどころではなく、しっかり次月に影響しそうです。',
        ),
      ]);

      return _MonthlyComment(
        scenarioKey: 'overall_over',
        notificationBody: '今月の予算を使い切りました。',
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
        final variant = _pickVariant('category_danger', [
          (
            message: '$criticalBadge $criticalName、かなり攻めてます。',
            subMessage: 'もう少しで上限です。次の一手は慎重にいきましょう。',
          ),
          (
            message: '$criticalBadge $criticalName、かなりギリギリです。',
            subMessage: 'ここから先は少し慎重なくらいでちょうどよさそうです。',
          ),
          (
            message: '$criticalBadge $criticalName、だいぶ限界が近いです。',
            subMessage: '今ならまだ持ち直せます。少しだけ抑えていきましょう。',
          ),
        ]);

        return _MonthlyComment(
          scenarioKey: 'category_danger',
          notificationBody: '$criticalBadge $criticalName が90%を超えました。',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      }

      if (criticalUsageRate >= 0.75) {
        final variant = _pickVariant('category_warning', [
          (
            message: '$criticalBadge $criticalName、そろそろ危険です。',
            subMessage: 'このカテゴリの積み重ねが効いてきています。今ならまだ引き返せます。',
          ),
          (
            message: '$criticalBadge $criticalName、少しペースが速いです。',
            subMessage: '直近の一件というより、このカテゴリ全体の積み重ねで上限が見えてきています。',
          ),
          (
            message: '$criticalBadge $criticalName、じわじわ効いています。',
            subMessage: 'このカテゴリの反復が効いてきています。ここで少し抑えると後半がかなり楽になります。',
          ),
        ]);

        return _MonthlyComment(
          scenarioKey: 'category_warning',
          notificationBody: '$criticalBadge $criticalName が75%を超えました。',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      }
    }

    if (overallUsageRate >= 1.0) {
      final variant = _pickVariant('overall_over', [
        (
          message: '今月の予算、もう終わってます。',
          subMessage: 'ここから先は、完全に未来の自分へのツケです。',
        ),
        (
          message: '全体予算、使い切りました。',
          subMessage: 'ここから先の支出は、すべて延長戦です。',
        ),
        (
          message: '予算オーバーです。',
          subMessage: '財布はすでに今月の役目を終えた顔をしています。',
        ),
        (
          message: '今月の上限を突破しました。',
          subMessage: '少しどころではなく、しっかり次月に影響しそうです。',
        ),
      ]);

      return _MonthlyComment(
        scenarioKey: 'overall_over',
        notificationBody: '今月の予算を使い切りました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    if (overallUsageRate >= 0.9) {
      final variant = _pickVariant('overall_danger', [
        (
          message: '財布の余命、かなり短いです。',
          subMessage: '今月は節約モードに切り替えた方がよさそうです。',
        ),
        (
          message: '全体予算、かなりギリギリです。',
          subMessage: 'ここから先は、慎重なくらいでちょうどよさそうです。',
        ),
        (
          message: '予算の終盤戦に入っています。',
          subMessage: '残りの期間は少し守り重視でいきたいところです。',
        ),
        (
          message: '全体的にかなり使っています。',
          subMessage: '今のペースだと、油断した一回が大きく響きそうです。',
        ),
      ]);

      return _MonthlyComment(
        scenarioKey: 'overall_danger',
        notificationBody: '全体予算が90%を超えました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    final cafeComment = _buildCategoryMonthlyComment(
      baseKey: 'cafe',
      notificationBody: '今月カフェ{count}回目です。',
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
      copySet: const _MonthlyCategoryCopySet(
        repeatVariants: [
          (
            message: '今月カフェ{count}回目です。',
            subMessage: '回数もですが、予算の{percent}%を使っています。習慣としてしっかり残るタイプです。',
          ),
          (
            message: 'カフェ、今月{count}回ですね。',
            subMessage: '一杯ずつでも、予算比では{percent}%。じわじわ効いています。',
          ),
          (
            message: 'カフェ率、今月はやや高めです。',
            subMessage: 'ここまでで予算の{percent}%。気分転換が習慣寄りになっています。',
          ),
        ],
        dripVariants: [
          (
            message: '今月カフェ{count}回目です。',
            subMessage: '回数もですが、予算の{percent}%を使っています。習慣としてしっかり残るタイプです。',
          ),
          (
            message: 'カフェ、今月{count}回ですね。',
            subMessage: '一杯ずつでも、予算比では{percent}%。じわじわ効いています。',
          ),
          (
            message: 'カフェ率、今月はやや高めです。',
            subMessage: 'ここまでで予算の{percent}%。気分転換が習慣寄りになっています。',
          ),
        ],
      ),
    );
    if (cafeComment != null) return cafeComment;

    final convenienceComment = _buildCategoryMonthlyComment(
      baseKey: 'convenience',
      notificationBody: 'コンビニ{count}回目です。',
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
      copySet: const _MonthlyCategoryCopySet(
        repeatVariants: [
          (
            message: 'コンビニ{count}回目です。',
            subMessage: '手軽さの積み重ねで、予算の{percent}%を使っています。',
          ),
          (
            message: '今月コンビニ{count}回ですね。',
            subMessage: '一回ずつは軽くても、予算比で見ると{percent}%。しっかり残っています。',
          ),
          (
            message: 'コンビニ率、高めです。',
            subMessage: '今月ここまでで予算の{percent}%。気軽さがそのまま数字に出ています。',
          ),
        ],
        dripVariants: [
          (
            message: 'コンビニ{count}回目です。',
            subMessage: '手軽さの積み重ねで、予算の{percent}%を使っています。',
          ),
          (
            message: '今月コンビニ{count}回ですね。',
            subMessage: '一回ずつは軽くても、予算比で見ると{percent}%。しっかり残っています。',
          ),
          (
            message: 'コンビニ率、高めです。',
            subMessage: '今月ここまでで予算の{percent}%。気軽さがそのまま数字に出ています。',
          ),
        ],
      ),
    );
    if (convenienceComment != null) return convenienceComment;

    final diningComment = _buildCategoryMonthlyComment(
      baseKey: 'dining',
      notificationBody: '外食{count}回目です。',
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
      copySet: const _MonthlyCategoryCopySet(
        repeatVariants: [
          (
            message: '外食{count}回目です。',
            subMessage: '満足感は高いですが、予算の{percent}%を使っています。しっかり効いています。',
          ),
          (
            message: '今月、外食が{count}回あります。',
            subMessage: '楽しさに対して、合計は予算比{percent}%。存在感が出てきています。',
          ),
          (
            message: '外食ペース、やや高めです。',
            subMessage: '今月ここまでで予算の{percent}%。後半の余裕を少し意識したいところです。',
          ),
        ],
        dripVariants: [
          (
            message: '外食{count}回目です。',
            subMessage: '満足感は高いですが、予算の{percent}%を使っています。しっかり効いています。',
          ),
          (
            message: '今月、外食が{count}回あります。',
            subMessage: '楽しさに対して、合計は予算比{percent}%。存在感が出てきています。',
          ),
          (
            message: '外食ペース、やや高めです。',
            subMessage: '今月ここまでで予算の{percent}%。後半の余裕を少し意識したいところです。',
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
      baseKey: 'online_shopping',
      notificationBody: 'ネットショッピングが今月{count}回、合計{amount}円あります。',
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
      copySet: const _MonthlyCategoryCopySet(
        heavyHitVariants: [
          (
            message: 'ネットショッピング、回数は少ないですが一撃が重めです。',
            subMessage: '今月は{count}回で合計{amount}円。1回あたり約{average}円で、予算の{percent}%を使っています。',
          ),
          (
            message: '通販系、回数より金額の重さが目立っています。',
            subMessage: '今月{count}回で{amount}円。少回数でも、予算比で見るとしっかり残るタイプです。',
          ),
          (
            message: 'ネット購入、少ない回数でも存在感があります。',
            subMessage: '今月ここまでで予算の{percent}%を使っています。気軽さより重みが前に出ています。',
          ),
        ],
        repeatVariants: [
          (
            message: 'ネットショッピング、今月{count}回です。',
            subMessage: '合計{amount}円、1回あたり約{average}円。予算の{percent}%を使っていて、もうちゃんと存在感があります。',
          ),
          (
            message: '今月のネット購入は{count}回あります。',
            subMessage: '合計{amount}円で、予算比では{percent}%。一回ごとの軽さに対して、全体はかなり素直です。',
          ),
          (
            message: '通販系の支出、今月はやや多めです。',
            subMessage: '今月ここまでで{amount}円。画面の中では一瞬でも、予算比で見るとしっかり残ります。',
          ),
          (
            message: 'ネットでの買い物が今月{count}回あります。',
            subMessage: '1回あたり約{average}円。便利さの積み重ねが、予算の{percent}%まで届いています。',
          ),
        ],
        dripVariants: [
          (
            message: 'ネットショッピング、今月{count}回です。',
            subMessage: '合計{amount}円、1回あたり約{average}円。予算の{percent}%を使っていて、じわじわ型としてはかなり残っています。',
          ),
          (
            message: '今月のネット購入は{count}回あります。',
            subMessage: '一回ごとは軽めでも、積み重ねで予算比{percent}%まで来ています。',
          ),
          (
            message: '通販系の支出、今月は回数で効いています。',
            subMessage: '少額寄りでも回数が多く、ここまでで{amount}円。便利さの反復が数字に出ています。',
          ),
        ],
      ),
    );
    if (onlineShoppingComment != null) return onlineShoppingComment;

    final movieComment = _buildCategoryMonthlyComment(
      baseKey: 'movie',
      notificationBody: '映画の支出が今月{count}回、合計{amount}円あります。',
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
      copySet: const _MonthlyCategoryCopySet(
        heavyHitVariants: [
          (
            message: '映画、1回でもちょっと重ためでしたね。',
            subMessage: '今月ここまでで{amount}円。1回で予算の{percent}%を使っていて、満足感と一緒に存在感も大きめです。',
          ),
          (
            message: '映画系支出、回数より一撃の重さが目立っています。',
            subMessage: '今回は1回で{amount}円。こういう支出は回数が少なくても、予算比で見ると印象に残ります。',
          ),
          (
            message: '映画、少回数でもちゃんと効いています。',
            subMessage: '今月は1回で予算の{percent}%を使っています。気分転換としては良いですが、重みはあります。',
          ),
        ],
        repeatVariants: [
          (
            message: '映画、今月{count}回です。',
            subMessage: '合計{amount}円、1回あたり約{average}円で、予算の{percent}%を使っています。楽しみとしては良いですが、ちゃんと残るタイプです。',
          ),
          (
            message: '今月の映画は{count}回あります。',
            subMessage: '一本ずつは良くても、合計{amount}円・予算比{percent}%になると存在感が出てきます。',
          ),
          (
            message: '映画ペース、今月は少し高めです。',
            subMessage: '今月ここまでで{amount}円。気分転換としては最高ですが、財布も本数まで覚えています。',
          ),
        ],
      ),
    );
    if (movieComment != null) return movieComment;

    final karaokeComment = _buildCategoryMonthlyComment(
      baseKey: 'karaoke',
      notificationBody: 'カラオケの支出が今月{count}回、合計{amount}円あります。',
      metrics: karaokeMetrics,
      rule: const _MonthlyCategoryRule(
        repeatMinCount: 2,
        repeatMinRatio: 0.10,
        dripMinCount: 4,
        dripMinRatio: 0.04,
        dripMinAverage: 0,
        dripMaxAverage: 700,
      ),
      copySet: const _MonthlyCategoryCopySet(
        repeatVariants: [
          (
            message: 'カラオケ、今月{count}回です。',
            subMessage: '合計{amount}円、1回あたり約{average}円で、予算の{percent}%を使っています。しっかり楽しんだぶん、財布もその熱量を感じています。',
          ),
          (
            message: '今月のカラオケは{count}回あります。',
            subMessage: '一回ずつの楽しさに対して、合計{amount}円・予算比{percent}%は意外と存在感があります。',
          ),
          (
            message: '歌うペース、今月は少し高めです。',
            subMessage: '今月ここまでで{amount}円。予算の{percent}%を使っていて、発散力も予算への反映も強めです。',
          ),
        ],
        dripVariants: [
          (
            message: 'カラオケ、1回ごとは軽めでも回数で効いています。',
            subMessage: '今月{count}回で合計{amount}円。1回あたり約{average}円の、じわじわ型です。予算比では{percent}%です。',
          ),
          (
            message: 'カラオケ、少額反復タイプですね。',
            subMessage: '1回ごとは軽くても、今月ここまでで{amount}円。予算の{percent}%まで来ると回数の力が出ています。',
          ),
          (
            message: '歌うたびに少しずつ、ちゃんと効いています。',
            subMessage: '今月{count}回、合計{amount}円。軽い出費の積み重ねとしては十分強めです。',
          ),
        ],
      ),
    );
    if (karaokeComment != null) return karaokeComment;

    final arcadeComment = _buildCategoryMonthlyComment(
      baseKey: 'arcade',
      notificationBody: 'ゲーセン系の支出が今月{count}回、合計{amount}円あります。',
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
      copySet: const _MonthlyCategoryCopySet(
        heavyHitVariants: [
          (
            message: '遊び系支出、回数より一撃の重さが出ています。',
            subMessage: '今月{count}回で合計{amount}円。1回あたり約{average}円で、予算の{percent}%を使っています。',
          ),
          (
            message: 'ゲームセンター系、少回数でも存在感があります。',
            subMessage: '一回ごとの楽しさは大きいですが、予算比で見るとちゃんと大きめです。今月ここまでで{amount}円です。',
          ),
          (
            message: '遊びの支出、今回は一撃重めでしたね。',
            subMessage: '少ない回数でも予算の{percent}%まで来ると、かなり印象に残る使い方です。',
          ),
        ],
        repeatVariants: [
          (
            message: 'ゲームセンター系の支出、今月{count}回です。',
            subMessage: '合計{amount}円、1回あたり約{average}円で、予算の{percent}%を使っています。遊びとしては良いですが、積み重なるとしっかり効いてきます。',
          ),
          (
            message: '今月のゲーセン系支出は{count}回あります。',
            subMessage: 'その一回の楽しさに対して、合計{amount}円・予算比{percent}%はちゃんと存在感があります。',
          ),
          (
            message: '遊びのペース、今月は少し高めです。',
            subMessage: '今月ここまでで{amount}円。後半の余裕は少し意識したいところです。',
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
      baseKey: 'sudden_expense',
      notificationBody: '今月、急な出費が{count}回あります。',
      metrics: suddenMetrics,
      rule: const _MonthlyCategoryRule(
        repeatMinCount: 3,
        repeatMinRatio: 0.08,
        dripMinCount: 5,
        dripMinRatio: 0.05,
        dripMaxAverage: 1500,
      ),
      copySet: const _MonthlyCategoryCopySet(
        repeatVariants: [
          (
            message: '今月、急な出費が{count}回あります。',
            subMessage: '予定外のお金で、予算の{percent}%を使っています。じわじわ効いています。',
          ),
          (
            message: '急な出費、今月{count}回目です。',
            subMessage: '単発に見えて、合計では予算の{percent}%。流れになりつつあります。',
          ),
          (
            message: '今月は急な出費が多めですね。',
            subMessage: 'ここまでで予算の{percent}%。想定外が積み重なっています。',
          ),
        ],
        dripVariants: [
          (
            message: '急な出費、回数で効いています。',
            subMessage: '今月{count}回で、予算の{percent}%。軽く見えて積み重なっています。',
          ),
          (
            message: '予定外の出費が続いていますね。',
            subMessage: '1回ごとは小さくても、合計ではしっかり残っています。',
          ),
          (
            message: '急な出費、少額反復タイプです。',
            subMessage: '気づきにくいですが、予算の{percent}%まで来ています。',
          ),
        ],
      ),
    );

    if (suddenComment != null) return suddenComment;

    return _defaultMonthlyComment();
  }

  static Future<RoastResult> build({
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
    if (totalBudget == 0) {
      final variant = _pickVariant('no_budget', [
        (
          message: 'まずは予算を決めましょう。',
          subMessage: '予算がないと、財布の余命も測れません。',
        ),
        (
          message: '今月の予算がまだ未設定です。',
          subMessage: '最初に上限を決めるだけで、かなり見え方が変わります。',
        ),
        (
          message: '予算、まだ空欄ですね。',
          subMessage: '財布も、とりあえずの目安を待っています。',
        ),
        (
          message: '予算を先に決めておくのがおすすめです。',
          subMessage: '基準があるだけで、使いすぎに気づきやすくなります。',
        ),
      ]);

      return RoastResult(
        title: '財布からひとこと',
        message: variant.message,
        subMessage: variant.subMessage,
        notificationBody: 'まずは予算を設定しましょう。',
        scenarioKey: 'no_budget',
      );
    }

    if (expenses.isEmpty) {
      final variant = _pickVariant('no_expense', [
        (
          message: 'まだ支出がありません。優秀です。',
          subMessage: 'このままなら、財布はかなり長生きしそうです。',
        ),
        (
          message: '今のところ支出はゼロです。',
          subMessage: '静かなスタートです。この調子でいきましょう。',
        ),
        (
          message: 'まだ何も使っていませんね。',
          subMessage: '財布も落ち着いています。かなり平和です。',
        ),
        (
          message: '支出記録はまだありません。',
          subMessage: '出だしとしてはかなり好調です。',
        ),
      ]);

      return RoastResult(
        title: '財布からひとこと',
        message: variant.message,
        subMessage: variant.subMessage,
        notificationBody: 'まだ支出がありません。かなり優秀です。',
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

        
    final aiResult = judge.shouldAskAi
        ? await UnknownExpenseAiService.classify(
            storeName: latestExpense.storeName,
            category: latestExpense.category,
            amount: latestExpense.amount,
            spentAt: latestExpense.createdAt,
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
      final variant = _pickVariant('expensive_spending', [
        (
          message: '今回の支出は${latestExpense.category}の${latestExpense.storeName}で$amount円です。',
          subMessage: '一回の支出としてはかなり大きめです。財布が少し震えています。',
        ),
        (
          message: '今回は${latestExpense.category}の${latestExpense.storeName}で$amount円。なかなか大きいですね。',
          subMessage: '今月の予算に対して見ると、かなり存在感のある一撃です。',
        ),
        (
          message: '今回は${latestExpense.category}で$amount円の支出を確認しました。',
          subMessage: '${latestExpense.storeName}、今日はちょっと豪華でしたね。',
        ),
        (
          message: '${latestExpense.category}の${latestExpense.storeName}での出費、かなりインパクトがあります。',
          subMessage: '一回でここまで動くと、財布もさすがに気づきます。',
        ),
      ]);

      leadMessage = variant.message;
      leadSubMessage = variant.subMessage;
    } else if (spendingRate >= 0.15) {
      final variant = _pickVariant('mid_spending', [
        (
          message: '今回の支出は${latestExpense.category}の${latestExpense.storeName}で$amount円です。',
          subMessage: '設定予算に対して見ると、じわじわ効いてくるタイプの出費です。',
        ),
        (
          message: '今回は${latestExpense.category}の${latestExpense.storeName}で$amount円。少し大きめですね。',
          subMessage: '一回ごとの重さが、あとで効いてきそうです。',
        ),
        (
          message: '今回は${latestExpense.category}で$amount円の支出を記録しました。',
          subMessage: '小さすぎない出費なので、少しだけ意識していきたいところです。',
        ),
        (
          message: '${latestExpense.category}の${latestExpense.storeName}、今回の支出はやや存在感があります。',
          subMessage: '予算全体から見ると、油断できないサイズです。',
        ),
      ]);

      leadMessage = variant.message;
      leadSubMessage = variant.subMessage;
    } else if (spendingRate >= 0.08) {
      final variant = _pickVariant('light_high_spending', [
        (
          message: '今回の支出は${latestExpense.category}の${latestExpense.storeName}で$amount円です。',
          subMessage: '一回としては少し重めです。じわじわ効いてくるタイプです。',
        ),
        (
          message: '今回は${latestExpense.category}の${latestExpense.storeName}で$amount円。ちょっと存在感あります。',
          subMessage: 'まだ問題ないですが、積み重なるとしっかり効いてきます。',
        ),
        (
          message: '今回は${latestExpense.category}で$amount円の支出を確認しました。',
          subMessage: '軽くはない金額なので、少しだけ意識しておきたいところです。',
        ),
        (
          message: '今回は${latestExpense.category}の${latestExpense.storeName}ですね。',
          subMessage: 'このくらいの出費が続くと、あとで効いてくるタイプです。',
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
      final variant = _pickVariant('secondary_consecutive_store_$latestStore', [
        (
          message: '$latestStoreが$consecutiveStoreCount回連続ですね。',
          subMessage: 'もう常連です。レシートの顔パス、通りそうです。',
        ),
        (
          message: 'また$latestStoreですね。',
          subMessage: 'ここまで来ると偶然じゃないです。好みが強いです。',
        ),
        (
          message: '$latestStore、連続記録更新中です。',
          subMessage: '財布はカウント係、あなたはリピーターです。役割分担できてます。',
        ),
      ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        consecutiveCafeCount >= 2) {
      final variant = _pickVariant('secondary_consecutive_cafe', [
        (
          message: 'カフェ、$consecutiveCafeCount連続ですね。',
          subMessage: 'カフェインよりも習慣が効いてます。',
        ),
        (
          message: 'またカフェですね。これで$consecutiveCafeCount連続です。',
          subMessage: '気分転換が、もはや定常運転です。',
        ),
        (
          message: 'カフェ連続記録、更新中です。',
          subMessage: 'ポイントカードと友情が芽生えそうです。',
        ),
      ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        consecutiveConvenienceCount >= 2) {
      final variant = _pickVariant('secondary_consecutive_convenience', [
        (
          message: 'コンビニ、$consecutiveConvenienceCount連続ですね。',
          subMessage: '“ちょっとだけ”が綺麗に積み上がっています。',
        ),
        (
          message: 'またコンビニですね。これで$consecutiveConvenienceCount連続です。',
          subMessage: '近さが勝ち続けています。財布は負け続けています。',
        ),
        (
          message: 'コンビニ連続記録、更新中です。',
          subMessage: '手軽さの勝利。予算の敗北。',
        ),
      ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        consecutiveDiningCount >= 2) {
      final variant = _pickVariant('secondary_consecutive_dining', [
        (
          message: '外食、$consecutiveDiningCount連続ですね。',
          subMessage: '満足度は高いです。残高は低くなります。',
        ),
        (
          message: 'また外食ですね。これで$consecutiveDiningCount連続です。',
          subMessage: '自炊は今、静かに休暇中です。',
        ),
        (
          message: '外食連続記録、更新中です。',
          subMessage: '美味しさと引き換えに、後半の余裕を前借りしています。',
        ),
      ]);
      secondaryMessage = variant.message;
      secondarySubMessage = variant.subMessage;
    }

    if ((secondaryMessage == null || secondaryMessage.isEmpty) &&
        consecutiveOnlineShoppingCount >= 2) {
      final variant = _pickVariant('secondary_consecutive_online_shopping', [
        (
          message: 'ネットショッピング、$consecutiveOnlineShoppingCount連続ですね。',
          subMessage: '気づいたら届くタイプの流れになっています。',
        ),
        (
          message: 'またネットで買っていますね。これで$consecutiveOnlineShoppingCount連続です。',
          subMessage: '指先の軽さに対して、財布の減りはしっかりしています。',
        ),
        (
          message: 'ネットショッピング連続記録、更新中です。',
          subMessage: '便利さの裏で、予算は静かに削られています。',
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
      if (remainingPerDay <= 150) {
        final variant = _pickVariant('secondary_remaining_per_day_critical', [
          (
            message: '残り$daysLeft日で$remainingBudget円です。',
            subMessage: '1日あたりかなりハードモードです。ほぼ修行です。',
          ),
          (
            message: 'あと$daysLeft日、残り$remainingBudget円ですね。',
            subMessage: '一回の判断が、ほぼストーリー分岐です。慎重にどうぞ。',
          ),
          (
            message: '残り$remainingBudget円で、あと$daysLeft日です。',
            subMessage: '財布は耐久戦に入りました。無駄撃ちは致命傷です。',
          ),
        ]);
        secondaryMessage = variant.message;
        secondarySubMessage = variant.subMessage;
      } else if (remainingPerDay <= 300) {
        final variant = _pickVariant('secondary_remaining_per_day_warning', [
          (
            message: '残り$daysLeft日で$remainingBudget円です。',
            subMessage: 'まだ戦えます。ただし雑に使うと一瞬で終わります。',
          ),
          (
            message: 'あと$daysLeft日、残り$remainingBudget円ですね。',
            subMessage: 'ここからが腕の見せ所。計画性に課金していきましょう。',
          ),
          (
            message: '残り$remainingBudget円で、あと$daysLeft日です。',
            subMessage: '軽い一手の連打で、終盤が重くなります。配分ゲーです。',
          ),
        ]);
        secondaryMessage = variant.message;
        secondarySubMessage = variant.subMessage;
      }
    }

    final monthlyComment = _buildMonthlyComment(
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
        final variant = _pickVariant('latest_supermarket_overall_over', [
          (
            message: '${latestExpense.storeName}での買い物を記録しました。',
            subMessage: '生活に必要な買い物でも、全体ではすでに予算オーバーです。今回は静観より、現実を直視するターンです。',
          ),
          (
            message: '${latestExpense.storeName}ですね。',
            subMessage: '必要な支出のこともありますが、今月全体ではもう上限を越えています。これ以上は追加ラウンドです。',
          ),
          (
            message: 'スーパーでの支出を確認しました。',
            subMessage: '食費として自然でも、全体予算はもう終わっています。ここから先はかなり慎重に見たいところです。',
          ),
        ]);

        latestComment = _LatestComment(
          scenarioKey: 'latest_supermarket_overall_over',
          notificationBody: '🛒 ${latestExpense.storeName} の支出を記録しました。今月全体はすでに予算オーバーです。',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      } else if (ruleResult?.paceStatus == PaceStatus.danger ||
          ruleResult?.paceStatus == PaceStatus.over) {
        final variant = _pickVariant('latest_supermarket_category_danger', [
          (
            message: '${latestExpense.storeName}での買い物を記録しました。',
            subMessage: '生活に必要な買い物でも、このカテゴリ予算の進み方としてはかなり厳しめです。静かに見守る段階は過ぎています。',
          ),
          (
            message: '${latestExpense.storeName}ですね。',
            subMessage: '必要な支出のこともありますが、カテゴリ予算はかなりギリギリです。ここからは少し慎重にいきたいところです。',
          ),
          (
            message: 'スーパーでの支出を確認しました。',
            subMessage: '食費として自然でも、今月のカテゴリ枠としてはかなり前のめりです。後半が少し心配な流れです。',
          ),
        ]);

        latestComment = _LatestComment(
          scenarioKey: 'latest_supermarket_category_danger',
          notificationBody: '🛒 ${latestExpense.storeName} の支出を記録しました。食費カテゴリの予算ペースがかなり速めです。',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      } else if (ruleResult?.paceStatus == PaceStatus.warning) {
        final variant = _pickVariant('latest_supermarket_category_warning', [
          (
            message: '${latestExpense.storeName}での買い物を記録しました。',
            subMessage: '必要な買い物のことも多いですが、このカテゴリの進み方は少し早めです。今のうちに整えると後半が楽です。',
          ),
          (
            message: '${latestExpense.storeName}ですね。',
            subMessage: '生活費として自然でも、カテゴリ予算は少し速めに進んでいます。ここからは配分を少し意識したいところです。',
          ),
          (
            message: 'スーパーでの支出を確認しました。',
            subMessage: '今回は責める場面ではありませんが、カテゴリ予算の減り方としては少し存在感が出てきています。',
          ),
        ]);

        latestComment = _LatestComment(
          scenarioKey: 'latest_supermarket_category_warning',
          notificationBody: '🛒 ${latestExpense.storeName} の支出を記録しました。食費カテゴリが少し早めのペースです。',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      } else {
        latestComment = _LatestComment(
          scenarioKey: 'latest_supermarket',
          notificationBody: '🛒 ${latestExpense.storeName} の支出を記録しました。',
          message: '${latestExpense.storeName}での買い物を記録しました。',
          subMessage: 'スーパーの買い物は生活に必要なことも多いので、今回は静かに見守ります。',
        );
      }
    }

    else if (judge.tags.contains(ExpenseJudgeTag.movie)) {
      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? _pickVariant('latest_movie_danger', [
              (
                message: '${latestExpense.storeName}、映画の支出ですね（平均${latestMovieAverage}円）。',
                subMessage: '楽しさはありますが、今の予算ペースだと少し重ためです。平均${latestMovieAverage}円で、今月のエンタメ枠は慎重めでいきたいところです。',
              ),
              (
                message: '${latestExpense.storeName}、映画の記録を確認しました。',
                subMessage: 'リフレッシュには良いですが、今の流れだと財布には少し強めに効いています。平均${latestMovieAverage}円。',
              ),
              (
                message: '${latestExpense.storeName}ですね。映画時間だったんですね。',
                subMessage: '満足感は高そうですが、予算の進み方としては少し前のめりです。平均${latestMovieAverage}円。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? _pickVariant('latest_movie_warning', [
                  (
                    message: '${latestExpense.storeName}、映画の支出ですね（平均${latestMovieAverage}円）。',
                    subMessage: 'まだ大丈夫ですが、エンタメ系としては少しペースが出てきています。平均${latestMovieAverage}円。',
                  ),
                  (
                    message: '${latestExpense.storeName}、映画の記録を確認しました。',
                    subMessage: '気分転換としては良いですが、回数が重なるとじわじわ効いてきそうです。平均${latestMovieAverage}円。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: 'いまのうちに少し整えておくと、後半も気持ちよく楽しめそうです。平均${latestMovieAverage}円。',
                  ),
                ])
              : _pickVariant('latest_movie_fit', [
                  (
                    message: '${latestExpense.storeName}、映画の支出ですね（平均${latestMovieAverage}円）。',
                    subMessage: '今のところは予算の範囲で楽しめています。こういう支出も見える化できているのがかなり良いです。平均${latestMovieAverage}円。',
                  ),
                  (
                    message: '${latestExpense.storeName}、映画の記録を確認しました。',
                    subMessage: '楽しみのお金として、今はきれいに把握できています。平均${latestMovieAverage}円。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: '気分転換の支出も、見えていればかなり管理しやすいです。平均${latestMovieAverage}円。',
                  ),
                ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_movie',
        notificationBody: '🎬 ${latestExpense.storeName} の映画系支出を記録しました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.karaoke)) {
      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? _pickVariant('latest_karaoke_danger', [
              (
                message: '${latestExpense.storeName}でカラオケですね。',
                subMessage: '楽しさは伝わりますが、今の予算ペースだと少し強めに響いています。',
              ),
              (
                message: '${latestExpense.storeName}、歌ってきましたか。',
                subMessage: 'ストレス発散には良さそうですが、財布は少し真顔になっています。',
              ),
              (
                message: '${latestExpense.storeName}ですね。',
                subMessage: '楽しい支出ですが、今の流れだと予算への存在感は大きめです。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? _pickVariant('latest_karaoke_warning', [
                  (
                    message: '${latestExpense.storeName}でカラオケですね。',
                    subMessage: 'まだ大丈夫ですが、娯楽系の支出としては少し目立ってきています。',
                  ),
                  (
                    message: '${latestExpense.storeName}、いいですね。',
                    subMessage: '気分転換としては良いですが、回数が増えるとじわっと効いてきそうです。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: '今のうちに少し整えると、後半も気持ちよく遊べそうです。',
                  ),
                ])
              : _pickVariant('latest_karaoke_fit', [
                  (
                    message: '${latestExpense.storeName}でカラオケですね。',
                    subMessage: '今のところは予算の範囲で楽しめています。',
                  ),
                  (
                    message: '${latestExpense.storeName}、いいリフレッシュですね。',
                    subMessage: 'こういう支出も、見えていればかなり管理しやすいです。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: '楽しみのお金として、今は落ち着いて見られています。',
                  ),
                ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_karaoke',
        notificationBody: '🎤 ${latestExpense.storeName} のカラオケ支出を記録しました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.arcade)) {
      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? _pickVariant('latest_arcade_danger', [
              (
                message: '${latestExpense.storeName}で遊んできたんですね。',
                subMessage: '楽しそうですが、今の予算ペースだと少し効き方が強めです。',
              ),
              (
                message: '${latestExpense.storeName}を確認しました。',
                subMessage: '遊びのお金としては、今の流れだと少し前のめりかもしれません。',
              ),
              (
                message: '${latestExpense.storeName}ですね。',
                subMessage: '気分転換には良さそうですが、財布は少し静かに焦っています。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? _pickVariant('latest_arcade_warning', [
                  (
                    message: '${latestExpense.storeName}で遊んできたんですね。',
                    subMessage: 'まだ大丈夫ですが、娯楽系としては少し存在感が出てきています。',
                  ),
                  (
                    message: '${latestExpense.storeName}を確認しました。',
                    subMessage: '楽しい支出ですが、積み重なるとあとで効いてきそうです。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: '今のうちに少し整えておくと、後半もかなり楽になりそうです。',
                  ),
                ])
              : _pickVariant('latest_arcade_fit', [
                  (
                    message: '${latestExpense.storeName}で遊んできたんですね。',
                    subMessage: '今のところは予算の範囲で楽しめています。',
                  ),
                  (
                    message: '${latestExpense.storeName}を確認しました。',
                    subMessage: '遊びのお金も、見えていればかなり管理しやすいです。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: '楽しみの支出として、今は落ち着いて見られています。',
                  ),
                ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_arcade',
        notificationBody: '🎮 ${latestExpense.storeName} の遊び系支出を記録しました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (hasConsecutiveStoreSpending && latestStore.isNotEmpty) {
      final variant = _pickVariant('consecutive_store_$latestStore', [
        (
          message: '$latestStoreが$consecutiveStoreCount回連続ですね。',
          subMessage: 'かなり気に入っているのが伝わってきます。',
        ),
        (
          message: 'また$latestStoreですね。これで$consecutiveStoreCount回連続です。',
          subMessage: '好きなお店があるのは良いですが、財布はしっかり見ています。',
        ),
        (
          message: '$latestStore、連続記録更新中です。',
          subMessage: 'ここまで来ると、もはや生活の一部かもしれません。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'consecutive_store',
        notificationBody: '$latestStore の支出が$consecutiveStoreCount回連続です。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (latestStore.isNotEmpty) {
      final count = storeCounts[latestStore] ?? 0;
      if (count >= 3) {
        final variant = _pickVariant('store_repeat_$latestStore', [
          (
            message: '$latestStore、今月$count回目です。',
            subMessage: 'かなり通っていますね。ポイントカードがあなたを覚えています。',
          ),
          (
            message: '$latestStore、今月もう$count回目です。',
            subMessage: 'ここまで来ると常連です。店員さんの方が先に気づきます。',
          ),
          (
            message: '$latestStore率が高めです。今月$count回目です。',
            subMessage: '好きなのは伝わります。財布にも伝わっています。',
          ),
        ]);

        latestComment = _LatestComment(
          scenarioKey: 'store_repeat',
          notificationBody: '$latestStore の支出が$count回目です。',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      } else {
        final variant = _pickVariant('default', [
          (
            message: '直近の支出は${latestExpense.storeName}ですね。',
            subMessage: '今のところは大丈夫ですが、油断は禁物です。',
          ),
          (
            message: '${latestExpense.storeName}での支出を確認しました。',
            subMessage: '一回ずつ記録していくのは、とても良い習慣です。',
          ),
          (
            message: '${latestExpense.storeName}ですね。',
            subMessage: '少しずつでも把握できているのはかなり良い状態です。',
          ),
        ]);

        latestComment = _LatestComment(
          scenarioKey: 'default',
          notificationBody: '${latestExpense.storeName} の支出を記録しました。',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      }
    }

    else if (judge.tags.contains(ExpenseJudgeTag.kids) ||
        judge.tags.contains(ExpenseJudgeTag.family)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_kids_mismatch', [
              (
                message: '${latestExpense.storeName}、${latestExpense.category}に入っていますね。',
                subMessage: '子ども関連の支出は分けておくと、あとでかなり振り返りやすくなります。',
              ),
              (
                message: '${latestExpense.storeName}が${latestExpense.category}扱いになっています。',
                subMessage: '育児や子ども向けの出費は、見えるようにしておくと管理しやすいです。',
              ),
              (
                message: '${latestExpense.storeName}、今回はカテゴリが少し広めかもしれません。',
                subMessage: '大事な支出だからこそ、意味が見えるようにしておくと安心です。',
              ),
            ])
          : _pickVariant('latest_kids_fit', [
              (
                message: '${latestExpense.storeName}での支出を記録しました。',
                subMessage: '子どもや家族に関わるお金のこともあるので、今回はやさしく見守ります。',
              ),
              (
                message: '${latestExpense.storeName}ですね。',
                subMessage: '家族や子ども向けの支出は大事な場面も多いので、ここは静かに見ていきます。',
              ),
              (
                message: '${latestExpense.storeName}での記録を確認しました。',
                subMessage: '必要な出費のことも多いので、まずは責めずに把握していきましょう。',
              ),
            ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_kids',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.gambling)) {
      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? _pickVariant('latest_gambling_danger', [
              (
                message: '${latestExpense.storeName}での支出ですね。',
                subMessage: 'このカテゴリの進み方としてはかなり重めです。少し立ち止まって見たいところです。',
              ),
              (
                message: '${latestExpense.storeName}を確認しました。',
                subMessage: '今のペースだと、あとで響きやすい使い方になっています。',
              ),
              (
                message: '${latestExpense.storeName}ですね。',
                subMessage: '楽しさはあるかもしれませんが、予算の減り方としてはかなり強めです。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? _pickVariant('latest_gambling_warning', [
                  (
                    message: '${latestExpense.storeName}での支出ですね。',
                    subMessage: 'まだすぐ危険ではありませんが、少しペースは意識しておきたいところです。',
                  ),
                  (
                    message: '${latestExpense.storeName}を記録しました。',
                    subMessage: '今のうちに流れを見ておくと、後半がかなり楽になります。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: 'いまは軽めでも、重なると存在感が出やすい支出です。',
                  ),
                ])
              : _pickVariant('latest_gambling_fit', [
                  (
                    message: '${latestExpense.storeName}での支出を記録しました。',
                    subMessage: '今のところは記録を続けて、流れを見ていくのが良さそうです。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: 'まずは見える化できていることが大事です。ここから使い方を見ていきましょう。',
                  ),
                  (
                    message: '${latestExpense.storeName}を確認しました。',
                    subMessage: '強く言う段階ではありませんが、流れは把握しておきたい支出です。',
                  ),
                ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_gambling',
        notificationBody: judge.shouldNotify
            ? '${latestExpense.storeName}でギャンブル系の支出を記録しました。'
            : '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.luxury)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_luxury_mismatch', [
              (
                message: '${latestExpense.storeName}、${latestExpense.category}に入っていますね。',
                subMessage: '高級品寄りの支出は、分けておくとかなり見えやすくなります。',
              ),
              (
                message: '${latestExpense.storeName}が${latestExpense.category}扱いになっています。',
                subMessage: '存在感のある支出なので、カテゴリを分けると管理しやすそうです。',
              ),
              (
                message: '${latestExpense.storeName}、今回はカテゴリが少し広めです。',
                subMessage: 'こういう支出は見えるようにしておくと、あとでかなり振り返りやすいです。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_luxury_danger', [
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: '満足感は高そうですが、予算の進み方としてはかなり強めです。',
                  ),
                  (
                    message: '${latestExpense.storeName}を確認しました。',
                    subMessage: 'こうした大きめの支出が、今のペースだとかなり響きやすい状態です。',
                  ),
                  (
                    message: '${latestExpense.storeName}での支出ですね。',
                    subMessage: '今の流れだと、少し慎重なくらいでちょうどよさそうです。',
                  ),
                ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_luxury_warning', [
                      (
                        message: '${latestExpense.storeName}ですね。',
                        subMessage: 'まだ危険ではありませんが、少し存在感のある使い方です。',
                      ),
                      (
                        message: '${latestExpense.storeName}を記録しました。',
                        subMessage: '今のうちにペースを見ておくと、あとでかなり楽になります。',
                      ),
                      (
                        message: '${latestExpense.storeName}での支出ですね。',
                        subMessage: '満足感はありそうですが、予算面では少し意識しておきたいところです。',
                      ),
                    ])
                  : _pickVariant('latest_luxury_fit', [
                      (
                        message: '${latestExpense.storeName}ですね。',
                        subMessage: '今のところは予算の範囲で把握できています。',
                      ),
                      (
                        message: '${latestExpense.storeName}での支出を記録しました。',
                        subMessage: '大きめの支出でも、見える化できていればかなり違います。',
                      ),
                      (
                        message: '${latestExpense.storeName}を確認しました。',
                        subMessage: '今はまず、把握できていること自体がかなり良い状態です。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_luxury',
        notificationBody: judge.shouldNotify
            ? '${latestExpense.storeName}で高級品寄りの支出を記録しました。'
            : '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.sensitive)) {
      final variant = _pickVariant('latest_sensitive', [
        (
          message: '${latestExpense.storeName}での支出を記録しました。',
          subMessage: '今回は内容に踏み込まず、静かに記録だけしておきます。',
        ),
        (
          message: '${latestExpense.storeName}ですね。',
          subMessage: 'ここは強く触れず、落ち着いて記録だけ残しておきます。',
        ),
        (
          message: '${latestExpense.storeName}での記録を確認しました。',
          subMessage: '今回はコメントを控えめにして、静かに見守ります。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_sensitive',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.cafe)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_cafe_mismatch', [
              (
                message: '${latestExpense.storeName}、急な出費に入っていますね。',
                subMessage: 'カフェ系の支出は、分けておくとかなり見やすくなります。',
              ),
              (
                message: '${latestExpense.storeName}が${latestExpense.category}に入っています。',
                subMessage: '少しカテゴリが広めなので、見直すと管理しやすくなりそうです。',
              ),
              (
                message: '${latestExpense.storeName}、今回は${latestExpense.category}扱いなんですね。',
                subMessage: 'カフェとして分けると、使い方の傾向がもっと見えやすくなります。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_cafe_danger', [
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: 'カフェ予算のペースがかなり速めです。ここからは少し慎重にいきたいところです。',
                  ),
                  (
                    message: '${latestExpense.storeName}、見えています。',
                    subMessage: 'カフェ枠がかなり減ってきています。後半に響きそうです。',
                  ),
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: '楽しめてはいますが、今のペースだと上限がかなり近いです。',
                  ),
                ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_cafe_warning', [
                      (
                        message: '${latestExpense.storeName}ですね。',
                        subMessage: '今のところは大丈夫ですが、カフェ予算は少し早めのペースです。',
                      ),
                      (
                        message: '${latestExpense.storeName}、今日もカフェ気分ですね。',
                        subMessage: 'まだ余裕はありますが、少しずつ効いてきそうです。',
                      ),
                      (
                        message: '${latestExpense.storeName}ですね。',
                        subMessage: '後半を楽にするなら、ここで少しだけ抑えるのもありです。',
                      ),
                    ])
                  : _pickVariant('latest_cafe_fit', [
                      (
                        message: '${latestExpense.storeName}ですね。',
                        subMessage: '今のところは予算の範囲で楽しめています。',
                      ),
                      (
                        message: '${latestExpense.storeName}、今日はカフェ気分だったんですね。',
                        subMessage: 'ちゃんと把握できているので、今のところは落ち着いて見られます。',
                      ),
                      (
                        message: '${latestExpense.storeName}での支出を記録しました。',
                        subMessage: '予算の中で楽しめているなら、そこまで強く言う場面ではなさそうです。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_cafe',
        notificationBody: '☕ ${latestExpense.storeName} の支出を記録しました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.convenience)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_convenience_mismatch', [
              (
                message: '${latestExpense.storeName}、${latestExpense.category}に入っていますね。',
                subMessage: 'コンビニ支出は見えにくくなりやすいので、分けるとかなり把握しやすくなります。',
              ),
              (
                message: '${latestExpense.storeName}が急な出費に入りがちですね。',
                subMessage: 'ここが見えるようになると、使い方の傾向がかなり分かりやすくなります。',
              ),
              (
                message: '${latestExpense.storeName}、カテゴリが少し広めです。',
                subMessage: 'コンビニ系を分けると、予算の減り方がもっと見やすくなりそうです。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_convenience_danger', [
                  (
                    message: '${latestExpense.storeName}ですね。',
                    subMessage: '予算が減ってきている中でコンビニ比率が高めです。後半が少し心配です。',
                  ),
                  (
                    message: 'またコンビニですね。',
                    subMessage: '今のペースだと、手軽さがそのまま予算に響いてきそうです。',
                  ),
                  (
                    message: '${latestExpense.storeName}を確認しました。',
                    subMessage: '食費の中でもコンビニ寄りが続いていて、少し厳しめの流れです。',
                  ),
                ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_convenience_warning', [
                      (
                        message: '${latestExpense.storeName}ですね。',
                        subMessage: '今のところ予算内ですが、コンビニ比率は少し高めです。',
                      ),
                      (
                        message: 'またコンビニですね。',
                        subMessage: 'まだ大丈夫ですが、回数が増えるとじわじわ効いてきます。',
                      ),
                      (
                        message: '${latestExpense.storeName}での支出を確認しました。',
                        subMessage: '食費の使い方としては少し手軽寄りかもしれません。',
                      ),
                    ])
                  : _pickVariant('latest_convenience_fit', [
                      (
                        message: '${latestExpense.storeName}ですね。',
                        subMessage: '今のところは予算の範囲で収まっています。',
                      ),
                      (
                        message: '${latestExpense.storeName}での支出を確認しました。',
                        subMessage: '普段の食費として使っているなら、今は大きく責める場面ではなさそうです。',
                      ),
                      (
                        message: 'コンビニ支出を記録しました。',
                        subMessage: '予算内で管理できているなら、まずは把握できているのが大事です。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_convenience',
        notificationBody: '🏪 コンビニ支出を記録しました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.dining)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_dining_mismatch', [
              (
                message: latestIsWeekend
                    ? '週末外食っぽい支出ですね。'
                    : 'その支出、かなり外食寄りです。',
                subMessage: 'ただ、カテゴリは少し広めです。外食として分けると食費との違いがかなり見えやすくなります。',
              ),
              (
                message: '食べに出た感じはかなり伝わります。',
                subMessage: '急な出費より、外食として分けた方が使い方の流れを追いやすいです。',
              ),
              (
                message: '外食なのにカテゴリだけ少し曖昧ですね。',
                subMessage: '意味が見えるように分けておくと、予算管理がかなり楽になります。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_dining_danger', [
                  (
                    message: latestIsWeekend
                        ? '週末外食、今月は少し重ためです。'
                        : '外食としては自然ですが、今月の流れが少し強めです。',
                    subMessage: 'カテゴリは合っています。ただ、外食枠の進み方はかなり速めです。満足感のぶん、予算にもちゃんと出ています。',
                  ),
                  (
                    message: 'おいしい日の流れ、ありますね。',
                    subMessage: '記録は自然です。ただ、カテゴリ予算の減り方としては少し前のめりです。',
                  ),
                  (
                    message: '食べる方の満足感は高そうです。',
                    subMessage: 'カテゴリはぴったりですが、今月ペースとしては慎重に見ておきたいところです。',
                  ),
                ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_dining_warning', [
                      (
                        message: latestIsWeekend
                            ? '週末外食、かなりそれっぽいですね。'
                            : '今日は外食気分だったんですね。',
                        subMessage: 'カテゴリは合っています。ただ、外食枠は少し早めのペースです。',
                      ),
                      (
                        message: 'その支出、かなり外食らしいです。',
                        subMessage: '記録はきれいです。ペース面だけ少し意識しておくと後半がかなり楽です。',
                      ),
                      (
                        message: '楽しみ方としては自然です。',
                        subMessage: 'カテゴリ適合はきれいですが、今月の進み方としては少し存在感が出ています。',
                      ),
                    ])
                  : _pickVariant('latest_dining_fit', [
                      (
                        message: latestIsWeekend
                            ? '週末に外で食べる感じ、いいですね。'
                            : '今日は外食の日だったんですね。',
                        subMessage: 'カテゴリも自然ですし、今のところは予算の範囲で楽しめています。',
                      ),
                      (
                        message: 'その支出、かなり外食らしく記録できています。',
                        subMessage: '食費と分けて見やすく残せているのがかなり良いです。',
                      ),
                      (
                        message: '食べに出る日の空気、ちゃんと出ています。',
                        subMessage: 'カテゴリは合っていますし、今はまだ落ち着いて見られるペースです。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_dining',
        notificationBody: '🍜 ${latestExpense.storeName} の支出を記録しました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (_isOnlineShopping(latestExpense)) {
      final isHeavyHitOnline =
          onlineShoppingCount <= 2 && latestOnlineShoppingAverage >= 5000;

      final variant = ruleResult?.paceStatus == PaceStatus.danger ||
              ruleResult?.paceStatus == PaceStatus.over
          ? isHeavyHitOnline
              ? _pickVariant('latest_online_shopping_heavy_danger', [
                  (
                    message: latestTimeTone == 'late_night'
                        ? '深夜に大きめのポチり、来ましたね。'
                        : '今回は一撃重めの買い方ですね。',
                    subMessage: 'カテゴリは合っていますが、今月の通販枠としてはかなり強めです。1回あたり約${latestOnlineShoppingAverage}円で、予算への効き方も大きめです。',
                  ),
                  (
                    message: '指先の軽さに対して、金額は軽くないです。',
                    subMessage: '記録は自然です。ただ、カテゴリ予算の進み方としてはかなり前のめりです。',
                  ),
                  (
                    message: '届く前から存在感がある支出ですね。',
                    subMessage: 'カテゴリはぴったりですが、今月ペースとしては慎重に見ておきたいところです。',
                  ),
                ])
              : _pickVariant('latest_online_shopping_repeat_danger', [
                  (
                    message: latestTimeTone == 'late_night'
                        ? '深夜ポチりの流れ、今月はかなり出ています。'
                        : '通販の回数が今月しっかり効いています。',
                    subMessage: 'カテゴリは合っていますが、今月の通販枠はかなり速めです。便利さの反復が予算に強く出ています。',
                  ),
                  (
                    message: '気づいたら届く流れが続いていますね。',
                    subMessage: '記録は自然です。ただ、カテゴリ予算の減り方としては少し厳しめです。',
                  ),
                  (
                    message: 'その買い方、今月は少し前のめりです。',
                    subMessage: 'カテゴリはぴったりです。今の通販ペースは慎重に見ておきたいところです。',
                  ),
                ])
          : ruleResult?.paceStatus == PaceStatus.warning
              ? isHeavyHitOnline
                  ? _pickVariant('latest_online_shopping_heavy_warning', [
                      (
                        message: latestTimeTone == 'late_night'
                            ? '夜にちょっと大きめの買い物でしたね。'
                            : '今回は単発の重みが少し出ていますね。',
                        subMessage: 'カテゴリは合っています。ただ、1回あたり約${latestOnlineShoppingAverage}円で、今月の通販枠としては少し存在感があります。',
                      ),
                      (
                        message: '回数は少なくても、金額はちゃんと前に出ています。',
                        subMessage: '記録はきれいです。ペース面だけ、少し意識しておくと後半が楽です。',
                      ),
                      (
                        message: 'ポチりというより、しっかり買った日ですね。',
                        subMessage: 'カテゴリ適合は自然です。今のうちに少し整えるとかなり楽になります。',
                      ),
                    ])
                  : _pickVariant('latest_online_shopping_repeat_warning', [
                      (
                        message: latestTimeTone == 'late_night'
                            ? '夜ポチの流れ、少し出てきていますね。'
                            : '通販の回数が今月ちょっと目立ってきましたね。',
                        subMessage: 'カテゴリは合っています。ただ、通販枠は少し早めのペースです。',
                      ),
                      (
                        message: '一回ごとは軽めでも、回数が効いてきています。',
                        subMessage: '記録はきれいです。ペース面だけ少し意識しておくと後半がかなり楽です。',
                      ),
                      (
                        message: '届く系の支出、今月は少し存在感があります。',
                        subMessage: 'カテゴリ適合はきれいですが、今月の進み方としては少し前に出ています。',
                      ),
                    ])
              : isHeavyHitOnline
                  ? _pickVariant('latest_online_shopping_heavy_fit', [
                      (
                        message: latestTimeTone == 'late_night'
                            ? '夜にしっかり買い物した日だったんですね。'
                            : '今回は少回数でも重みのある買い方ですね。',
                        subMessage: 'カテゴリも自然ですし、今のところは予算の範囲で見られています。ただ、1回あたり約${latestOnlineShoppingAverage}円で一撃の存在感はあります。',
                      ),
                      (
                        message: 'その支出、かなり“買った感”があります。',
                        subMessage: '通販として見やすく記録できています。回数は少なくても、単価はしっかりめです。',
                      ),
                      (
                        message: '指先が軽い日というより、ちゃんと選んだ日ですね。',
                        subMessage: 'カテゴリは合っていますし、今はまだ落ち着いて見られるペースです。',
                      ),
                    ])
                  : _pickVariant('latest_online_shopping_repeat_fit', [
                      (
                        message: latestTimeTone == 'late_night'
                            ? '夜ポチ、今日はそういう日だったんですね。'
                            : '通販の使い方としてはかなり自然です。',
                        subMessage: 'カテゴリも合っていますし、今のところは予算の範囲で見られています。',
                      ),
                      (
                        message: 'その支出、かなり通販らしく記録できています。',
                        subMessage: '届く系の支出として見やすく残せています。',
                      ),
                      (
                        message: '気づいたら届く側の使い方、ちゃんと出ています。',
                        subMessage: 'カテゴリは合っていますし、今はまだ落ち着いて見られるペースです。',
                      ),
                    ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_online_shopping',
        notificationBody: '🛒 ${latestExpense.storeName} の支出を記録しました。',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.hobby)) {
      final variant = _pickVariant('latest_hobby', [
        (
          message: '${latestExpense.storeName}での支出ですね。',
          subMessage: '趣味の出費は満足感がありますが、回数が増えると効いてきます。',
        ),
        (
          message: '${latestExpense.storeName}、今回は趣味寄りの出費ですね。',
          subMessage: '好きなことに使うお金は大事ですが、財布もちゃんと見ています。',
        ),
        (
          message: '${latestExpense.storeName}での買い物を記録しました。',
          subMessage: '楽しさのある支出ですが、積み重なると存在感が出てきます。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_hobby',
        notificationBody: judge.shouldNotify
            ? '${latestExpense.storeName}で趣味系の支出を記録しました。'
            : '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.beauty)) {
      final variant = _pickVariant('latest_beauty', [
        (
          message: '${latestExpense.storeName}での支出ですね。',
          subMessage: '美容系の出費は気分も上がりますが、財布も静かに見ています。',
        ),
        (
          message: '${latestExpense.storeName}、今回は美容寄りの出費ですね。',
          subMessage: '整えるための支出も、積み重なるとしっかり効いてきます。',
        ),
        (
          message: '${latestExpense.storeName}での買い物を記録しました。',
          subMessage: '満足感は高そうですが、予算とのバランスも見ていきたいところです。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_beauty',
        notificationBody: judge.shouldNotify
            ? '${latestExpense.storeName}で美容系の支出を記録しました。'
            : '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (ruleResult?.categoryFit == CategoryFit.mismatch) {
      final variant = _pickVariant('latest_rule_mismatch', [
        (
          message: '${latestExpense.storeName}、${latestExpense.category}に入っていますね。',
          subMessage: '少しカテゴリが広めなので、見直すとかなり管理しやすくなりそうです。',
        ),
        (
          message: '${latestExpense.storeName}が${latestExpense.category}扱いになっています。',
          subMessage: 'この支出は分けておくと、あとで振り返りやすくなります。',
        ),
        (
          message: '${latestExpense.storeName}、今回はカテゴリが少し曖昧かもしれません。',
          subMessage: '支出の意味が見えるようになると、予算の使い方もかなり整いやすいです。',
        ),
        (
          message: '${latestExpense.storeName}、急な出費として入っていますね。',
          subMessage: '本当に予定外ならOKですが、続くようならカテゴリを分けるとかなり見やすくなります。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_rule_mismatch',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (ruleResult?.paceStatus == PaceStatus.danger ||
        ruleResult?.paceStatus == PaceStatus.over) {
      final variant = _pickVariant('latest_rule_danger', [
        (
          message: '${latestExpense.storeName}での支出ですね。',
          subMessage: 'このカテゴリの予算ペース、かなり速めです。',
        ),
        (
          message: '${latestExpense.storeName}を確認しました。',
          subMessage: '今の流れだと、このカテゴリはかなり前のめりです。',
        ),
        (
          message: '${latestExpense.storeName}ですね。',
          subMessage: '楽しめてはいますが、予算の進み方は少し厳しめです。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_rule_danger',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (ruleResult?.paceStatus == PaceStatus.warning) {
      final variant = _pickVariant('latest_rule_warning', [
        (
          message: '${latestExpense.storeName}での支出ですね。',
          subMessage: '今のところ予算内ですが、このカテゴリは少し早めのペースです。',
        ),
        (
          message: '${latestExpense.storeName}を確認しました。',
          subMessage: 'まだ大丈夫ですが、今の流れは少し前のめりです。',
        ),
        (
          message: '${latestExpense.storeName}ですね。',
          subMessage: '一回ごとの重さとペースを見ると、少しだけ意識しておきたいところです。',
        ),
        (
          message: '${latestExpense.storeName}での支出を記録しました。',
          subMessage: '予算内ではありますが、このカテゴリの進み方はやや速めです。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_rule_warning',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.ceremony)) {
      final variant = _pickVariant('latest_ceremony', [
        (
          message: '${latestExpense.storeName}での支出を記録しました。',
          subMessage: 'お祝いごとや大切な場面のお金は、今回は静かに見守ります。',
        ),
        (
          message: '${latestExpense.storeName}ですね。',
          subMessage: '冠婚葬祭や贈り物に関わる出費のこともあるので、ここはやさしく受け止めます。',
        ),
        (
          message: '${latestExpense.storeName}での記録を確認しました。',
          subMessage: '大事な人や場面に使うお金もあります。今回は何も言わずに見守ります。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_ceremony',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

    else if (judge.tags.contains(ExpenseJudgeTag.health) ||
        judge.tags.contains(ExpenseJudgeTag.transport)) {
      final variant = _pickVariant('latest_essential', [
        (
          message: '${latestExpense.storeName}での支出を記録しました。',
          subMessage: '生活に必要な出費もあるので、今回は静かに見守ります。',
        ),
        (
          message: '${latestExpense.storeName}ですね。',
          subMessage: '必要な支出のことも多いので、ここは落ち着いて見ていきましょう。',
        ),
        (
          message: '${latestExpense.storeName}での記録を確認しました。',
          subMessage: '必需品寄りの支出は、無理に責めず把握するのが大事です。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'latest_essential',
        notificationBody: '',
        message: variant.message,
        subMessage: variant.subMessage,
      );
    }

        else if (judge.shouldAskAi) {
      if (aiResult != null &&
          (aiResult.confidence ?? 0) >= 0.75 &&
          (aiResult.suggestedCategory?.isNotEmpty ?? false)) {
        final suggestedCategory = aiResult.suggestedCategory!;
        final reasonText = aiResult.reason.trim();

        final variant = aiResult.storeType == 'online_shopping'
            ? _pickVariant('latest_ai_online_suggested', [
                (
                  message: latestTimeTone == 'late_night'
                      ? '${latestExpense.storeName}、深夜ポチり系の気配がありますね。'
                      : '${latestExpense.storeName}、かなり通販寄りに見えます。',
                  subMessage: reasonText.isNotEmpty
                      ? '$reasonText 今回は $suggestedCategory として見るのが自然そうです。'
                      : '今回は $suggestedCategory として見るのが自然そうです。',
                ),
                (
                  message: 'この支出、$suggestedCategory として見るとかなり自然です。',
                  subMessage: reasonText.isNotEmpty
                      ? reasonText
                      : 'まだ断定はしませんが、AI補助だとその見方がかなり近そうです。',
                ),
              ])
            : _pickVariant('latest_ai_suggested', [
                (
                  message: '${latestExpense.storeName}、かなり$suggestedCategory寄りに見えます。',
                  subMessage: reasonText.isNotEmpty
                      ? '$reasonText 今回は $suggestedCategory として見るのが自然そうです。'
                      : '今回は $suggestedCategory として見るのが自然そうです。',
                ),
                (
                  message: 'この支出、$suggestedCategoryとして見ると自然です。',
                  subMessage: reasonText.isNotEmpty
                      ? reasonText
                      : 'まだ断定はしませんが、今回はその見方がかなり近そうです。',
                ),
                (
                  message: '${latestExpense.storeName}、今回は$suggestedCategoryの可能性が高そうです。',
                  subMessage: reasonText.isNotEmpty
                      ? reasonText
                      : 'いまは補助判定ですが、かなりそれっぽい支出です。',
                ),
              ]);

        latestComment = _LatestComment(
          scenarioKey: 'latest_ai_suggested',
          notificationBody: '',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      } else {
        final variant = _pickVariant('latest_unknown', [
          (
            message: '${latestExpense.storeName}、今回は少し正体がつかみにくいですね。',
            subMessage: 'この出費はもう少し意味を見てから判断したいところです。',
          ),
          (
            message: '今はまだ、どの流れの支出か決めきれません。',
            subMessage: '似た記録が増えると、かなり人っぽく見えてきそうです。',
          ),
          (
            message: '${latestExpense.storeName}、今回は静観寄りで見ています。',
            subMessage: 'いまは判断を急がず、もう少しデータが揃うのを待ちたい支出です。',
          ),
        ]);

        latestComment = _LatestComment(
          scenarioKey: 'latest_unknown',
          notificationBody: '',
          message: variant.message,
          subMessage: variant.subMessage,
        );
      }
    }
    else {
      final variant = _pickVariant('default', [
        (
          message: '直近の支出は${latestExpense.storeName}ですね。',
          subMessage: '今のところは大丈夫ですが、油断は禁物です。',
        ),
        (
          message: '${latestExpense.storeName}での支出を確認しました。',
          subMessage: '一回ずつ記録していくのは、とても良い習慣です。',
        ),
        (
          message: '${latestExpense.storeName}ですね。',
          subMessage: '少しずつでも把握できているのはかなり良い状態です。',
        ),
      ]);

      latestComment = _LatestComment(
        scenarioKey: 'default',
        notificationBody: '${latestExpense.storeName} の支出を記録しました。',
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

final notificationPreviewBody = [
  notificationSource.message,
  if (notificationSource.subMessage.isNotEmpty)
    notificationSource.subMessage,
].join('\n');

print('======== ROAST DEBUG ========');
print('🔥 priority: ${priorityLatestComment?.scenarioKey}');
print('🔥 latest(base): ${baseLatestComment.scenarioKey}');
print('🔥 latest(ui): ${uiLatestComment.scenarioKey}');
print('🔥 selected(notification): ${notificationSource.scenarioKey}');
print('🔥 body: $notificationPreviewBody');
print('================================');


return _composeLayeredResult(
  title: latestExpense.storeName.isNotEmpty
    ? '${latestExpense.storeName} の支出を記録しました。'
    : '支出を記録しました。',
  leadMessage: secondaryMessage,
  leadSubMessage: secondarySubMessage,
  monthly: monthlyComment,
  latest: uiLatestComment,
  notificationSource: notificationSource,
);
  }
}