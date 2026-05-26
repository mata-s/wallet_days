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
  final int? repeatMinCount;
  final double? repeatMinRatio;
  final int? dripMinCount;
  final double? dripMinRatio;
  final int? dripMaxAverage;

  const _MonthlyCategoryRule({
    this.repeatMinCount,
    this.repeatMinRatio,
    this.dripMinCount,
    this.dripMinRatio,
    this.dripMaxAverage,
  });
}

class _MonthlyCategoryCopySet {
  final List<({String message, String subMessage})>? repeatVariants;
  final List<({String message, String subMessage})>? dripVariants;

  const _MonthlyCategoryCopySet({
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
final resolvedMainSubMessage = [
  monthly.subMessage,
  latest.message,
  latest.subMessage,
].where((text) => text.trim().isNotEmpty).join('\n');

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
      mainSubMessage: resolvedMainSubMessage,
    );
  }

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
    required Expense latestExpense,
    required String latestStore,
    required int latestStoreCount,
    required int amount,
    required double overallUsageRate,
    required double spendingRate,
    required int remainingBudget,
    required int? remainingPerDay,
    required int? daysLeft,
  }) {
    final lang = _normalizeLang(languageCode);
    final isEn = _isEnglish(lang);
    _LatestComment? best;

    if (latestStore.isNotEmpty && latestStoreCount >= 10 && overallUsageRate >= 0.7) {
      final variant = _pickVariant('priority_store_repeat_strong_$latestStore', isEn
          ? [
              (
                message: '$latestStore is showing up clearly',
                subMessage: '$latestStoreCount times this month. Not judging, just visible in the budget now.',
              ),
              (
                message: '$latestStore has a real rhythm',
                subMessage: '$latestStoreCount visits already. The wallet has started taking notes.',
              ),
              (
                message: '$latestStore is part of the month now',
                subMessage: '$latestStoreCount times this month. It is not bad, just not invisible anymore.',
              ),
            ]
          : [
              (
                message: '$latestStore、かなり見えてきたね',
                subMessage: '今月$latestStoreCount回目。責めてないよ、予算に顔を出してきただけ。',
              ),
              (
                message: '$latestStore、流れができてるね',
                subMessage: '$latestStoreCount回目だよ。財布は静かにメモしてる。',
              ),
              (
                message: '$latestStore、今月の常連枠だね',
                subMessage: '今月$latestStoreCount回。悪いわけじゃないけど、もう見えない支出ではないね。',
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
          priority: 88,
        ),
      );
    } else if (latestStore.isNotEmpty && latestStoreCount >= 5 && overallUsageRate >= 0.7) {
      final variant = _pickVariant('priority_store_repeat_mid_$latestStore', isEn
          ? [
              (
                message: '$latestStore is becoming a pattern',
                subMessage: '$latestStoreCount visits this month. Still fine, just worth keeping visible.',
              ),
              (
                message: '$latestStore has a visible rhythm',
                subMessage: '$latestStoreCount times this month. The wallet is not judging, just noticing.',
              ),
              (
                message: '$latestStore is starting to stand out',
                subMessage: '$latestStoreCount visits. Small routine, now visible in the month.',
              ),
            ]
          : [
              (
                message: '$latestStore、流れが見えてきたね',
                subMessage: '今月$latestStoreCount回目。悪くないけど、予算には少し顔を出してきたよ。',
              ),
              (
                message: '$latestStore、リズム出てきたね',
                subMessage: '$latestStoreCount回目。財布は責めずに、静かに見てるよ。',
              ),
              (
                message: '$latestStore、少し目立ってきたね',
                subMessage: '今月$latestStoreCount回。小さな習慣が、見える形になってきたよ。',
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
          priority: 84,
        ),
      );
    } else if (latestStore.isNotEmpty && latestStoreCount >= 3 && overallUsageRate >= 0.85) {
      final variant = _pickVariant('priority_store_repeat_light_$latestStore', isEn
          ? [
              (
                message: '$latestStore again',
                subMessage: '$latestStoreCount times so far. Not huge, just noticeable.',
              ),
              (
                message: '$latestStore is popping up',
                subMessage: '$latestStoreCount visits. The wallet marked it with a tiny sticker.',
              ),
              (
                message: '$latestStore looks familiar',
                subMessage: '$latestStoreCount times this month. Just keeping it visible.',
              ),
            ]
          : [
              (
                message: '$latestStore、また出たね',
                subMessage: '今月$latestStoreCount回目。大事件じゃないけど、見えてきたよ。',
              ),
              (
                message: '$latestStore、ちょい多めだね',
                subMessage: '$latestStoreCount回目。財布が小さな付箋貼ってるよ。',
              ),
              (
                message: '$latestStore、見覚えあるね',
                subMessage: '今月$latestStoreCount回目。ちゃんと見えるところに置いとこう。',
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
          priority: 72,
        ),
      );
    }


    if (spendingRate >= 0.25) {
      final moneyText = _formatMoney(amount, lang);

      final variant = _pickVariant('priority_expensive_spending_$lang', isEn
          ? [
              (
                message: '$moneyText made a dent',
                subMessage: '${latestExpense.storeName} hit the wallet pretty clearly.',
              ),
              (
                message: 'That one had weight',
                subMessage: '$moneyText in one go. The wallet sat down for a second.',
              ),
              (
                message: '${latestExpense.storeName} came in heavy',
                subMessage: '$moneyText. No need to panic, but it definitely counts.',
              ),
            ]
          : [
              (
                message: '$amount円、へこんだね',
                subMessage: '${latestExpense.storeName}の一撃。財布、ちゃんと揺れてるよ。',
              ),
              (
                message: 'これは重いね',
                subMessage: '$amount円。財布が一回座り込むサイズだよ。',
              ),
              (
                message: '${latestExpense.storeName}、強めに来たね',
                subMessage: '$amount円。ちゃんと効くサイズだよ。',
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
          priority: 122,
        ),
      );
    } else if (spendingRate >= 0.15) {
      final moneyText = _formatMoney(amount, lang);

      final variant = _pickVariant('priority_mid_spending_$lang', isEn
          ? [
              (
                message: '$moneyText is not tiny',
                subMessage: '${latestExpense.storeName} left a clear little mark.',
              ),
              (
                message: 'That one will stay visible',
                subMessage: '$moneyText. Not huge, but the wallet noticed.',
              ),
              (
                message: '${latestExpense.storeName} has presence',
                subMessage: '$moneyText. Light in the moment, visible later.',
              ),
            ]
          : [
              (
                message: '$amount円、ちょい重めだね',
                subMessage: '${latestExpense.storeName}の跡、財布にはちゃんと見えてるよ。',
              ),
              (
                message: 'これは少し効くね',
                subMessage: '$amount円。大事件じゃないけど、見逃すほど小さくもないね。',
              ),
              (
                message: '${latestExpense.storeName}、存在感あるね',
                subMessage: '今回の$amount円、あとでじわっと思い出すかも。',
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
          priority: 102,
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
                  message: 'The wallet is getting thin',
                  subMessage: '$remainingBudget left for $daysLeft days. Tiny room now.',
                ),
                (
                  message: 'Careful steps from here',
                  subMessage: '$remainingBudget for $daysLeft days. Every tap has weight.',
                ),
                (
                  message: 'Is the wallet still breathing?',
                  subMessage: '$daysLeft days left. $remainingBudget has to stretch.',
                ),
              ]
            : [
                (
                  message: '財布、だいぶ薄いね',
                  subMessage: 'あと$daysLeft日で$remainingBudget円。余白はかなり細いよ。',
                ),
                (
                  message: 'ここから慎重モードだね',
                  subMessage: '残り$remainingBudget円であと$daysLeft日。一回ずつ重くなるよ。',
                ),
                (
                  message: '財布、息してる…？',
                  subMessage: 'あと$daysLeft日。$remainingBudget円には伸びてもらうしかないね。',
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
                  subMessage: '$remainingBudget left for $daysLeft days. The wallet is watching the pace.',
                ),
                (
                  message: 'The room is shrinking',
                  subMessage: '$remainingBudget for $daysLeft days. Still workable, just not sleepy.',
                ),
                (
                  message: 'Feels like the endgame',
                  subMessage: '$daysLeft days left. Playing it safe may help.',
                ),
              ]
            : [
                (
                  message: '残り、細めだね',
                  subMessage: 'あと$daysLeft日で$remainingBudget円。財布がペース見てるよ。',
                ),
                (
                  message: '余白、少し狭くなってきたね',
                  subMessage: '残り$remainingBudget円であと$daysLeft日。まだいけるけど、油断は薄めで。',
                ),
                (
                  message: '終盤戦っぽくなってきたね',
                  subMessage: 'あと$daysLeft日。少し守り気味でちょうどいいかも。',
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
              message: 'You’re on track',
              subMessage: 'Spending looks calm. The wallet is not side-eyeing you yet.',
            ),
            (
              message: 'Things look steady',
              subMessage: 'No major drama so far. The wallet can breathe.',
            ),
            (
              message: 'Looking balanced',
              subMessage: 'Nothing unusual yet. Keep it visible and you are fine.',
            ),
          ]
        : [
            (
              message: 'いい流れだね',
              subMessage: '今のところ財布は横目で見てないよ。',
            ),
            (
              message: '安定してるね',
              subMessage: '大きな事件はなし。財布も深呼吸できてるよ。',
            ),
            (
              message: 'バランスいいね',
              subMessage: '変な偏りはまだないよ。このまま見えるところに置いとこう。',
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
    final repeatMatched =
        rule.repeatMinCount != null &&
        rule.repeatMinRatio != null &&
        metrics.count >= rule.repeatMinCount! &&
        metrics.usageRatio >= rule.repeatMinRatio!;

    final dripMatched =
        rule.dripMinCount != null &&
        rule.dripMinRatio != null &&
        metrics.count >= rule.dripMinCount! &&
        metrics.usageRatio >= rule.dripMinRatio! &&
        (rule.dripMaxAverage == null || metrics.average <= rule.dripMaxAverage!);

    return repeatMatched || dripMatched;
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

    final isDrip =
        rule.dripMinCount != null &&
        rule.dripMinRatio != null &&
        metrics.count >= rule.dripMinCount! &&
        metrics.usageRatio >= rule.dripMinRatio! &&
        (rule.dripMaxAverage == null || metrics.average <= rule.dripMaxAverage!);

    final scenarioKey =
        isDrip ? '${baseKey}_drip' : '${baseKey}_repeat';

    final variants =
        isDrip ? copySet.dripVariants : copySet.repeatVariants;

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
                    'This month’s limit is already used up. From here, it is about keeping the landing soft.',
              ),
              (
                message: 'The line has been crossed',
                subMessage:
                    'No need to panic, but extra spending from here can echo into next month.',
              ),
              (
                message: 'This month is in overtime',
                subMessage:
                    'Budget-wise, the main game is over. Now the goal is to limit the aftershock.',
              ),
              (
                message: 'Past the limit now',
                subMessage:
                    'The wallet is not angry. It is just asking for a softer landing from here.',
              ),
            ]
          : [
              (
                message: 'もうオーバーしてるね',
                subMessage:
                    '今月の予算は使い切ってるよ。ここからは、来月に響かせない動きが大事だね。',
              ),
              (
                message: '完全に越えてるね',
                subMessage:
                    'ここからの支出は、あとで効いてくるやつだよ。焦らず着地を考えたいね。',
              ),
              (
                message: '今月、延長戦だね',
                subMessage:
                    '予算的にはもう本編終了。ここからはダメージを広げない時間だね。',
              ),
              (
                message: 'ライン超えてるね',
                subMessage:
                    '財布は怒ってないけど、ここからの支出はちゃんと響くゾーンだね。',
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

    Map<String, dynamic>? criticalCategory;

    if (dangerCategories.isNotEmpty) {
      final sortedDangerCategories = [...dangerCategories]
        ..sort((a, b) {
          final aUsage = (a['usageRate'] as double? ?? 0.0);
          final bUsage = (b['usageRate'] as double? ?? 0.0);

          final aOver = aUsage >= 1.0;
          final bOver = bUsage >= 1.0;

          // over-budget categories always win
          if (aOver != bOver) {
            return bOver ? 1 : -1;
          }

          // otherwise highest usageRate first
          return bUsage.compareTo(aUsage);
        });

      criticalCategory = sortedDangerCategories.first;
    }

    if (criticalCategory != null) {
      final criticalName = criticalCategory['name'] as String? ?? 'カテゴリ';
      final criticalBadge = criticalCategory['badge'] as String? ?? '⚠️';
      final criticalUsageRate = criticalCategory['usageRate'] as double? ?? 0.0;

            if (criticalUsageRate >= 1.0) {
        final variant = _pickVariant('category_over_$lang', isEn
            ? [
                (
                  message: '$criticalBadge $criticalName is over budget',
                  subMessage: 'The limit is already crossed. From here, each expense will echo into next month.',
                ),
                (
                  message: '$criticalBadge $criticalName went past the line',
                  subMessage: 'No more buffer here. Slowing down now will make the landing softer.',
                ),
                (
                  message: '$criticalBadge $criticalName is in overtime',
                  subMessage: 'The budget is already exceeded. Now it is about controlling the damage.',
                ),
              ]
            : [
                (
                  message: '$criticalBadge $criticalName、もう超えてるね',
                  subMessage: '上限はすでに越えてるよ。ここからは来月に響きやすいゾーンだね。',
                ),
                (
                  message: '$criticalBadge $criticalName、ライン越えたね',
                  subMessage: 'もう余白はないよ。ここからは少し落ち着かせたいところだね。',
                ),
                (
                  message: '$criticalBadge $criticalName、延長戦だね',
                  subMessage: '予算はオーバーしてるよ。ここからはダメージコントロールだね。',
                ),
              ]);

        return _MonthlyComment(
          scenarioKey: 'category_over',
          notificationBody: _t(
            lang,
            '$criticalBadge $criticalName が予算オーバーしているよ。',
            '$criticalName is over its budget.',
          ),
          message: variant.message,
          subMessage: variant.subMessage,
        );
      }


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


    int suddenExpenseCount = 0;
    final storeCounts = <String, int>{};

    for (final e in sortedExpenses) {
      if (e.category == 'その他') suddenExpenseCount++;

      final name = e.storeName.trim();
      if (name.isNotEmpty) {
        storeCounts[name] = (storeCounts[name] ?? 0) + 1;
      }
    }

    final latestExpense = sortedExpenses.first;
    final latestStore = latestExpense.storeName.trim();

    final suddenExpenseAmount = _sumAmountByCategory(sortedExpenses, 'その他');

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
      latestExpense: latestExpense,
      latestStore: latestStore,
      latestStoreCount: latestStoreCount,
      amount: amount,
      overallUsageRate: overallUsageRate,
      spendingRate: spendingRate,
      remainingBudget: remainingBudget,
      remainingPerDay: remainingPerDay,
      daysLeft: daysLeft,
    );

    String? secondaryMessage;
    String? secondarySubMessage;

    if (remainingPerDay != null &&
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
      suddenExpenseCount: suddenExpenseCount,
      suddenExpenseAmount: suddenExpenseAmount,
    );


    _LatestComment latestComment;
    // === BEGIN REORDERED BRANCHES ===
    if (judge.tags.contains(ExpenseJudgeTag.supermarket)) {
      if (overallUsageRate >= 1.0) {
        final variant = _pickVariant(
          'latest_supermarket_overall_over_$lang',
          isEn
              ? [
                  (
                    message: 'Groceries are essentials',
                    subMessage: 'Food matters. The overall budget is over, so from here it is about landing softly.',
                  ),
                  (
                    message: 'Groceries came in',
                    subMessage: 'Necessary spending. The month is already over budget, so the next moves just need a little care.',
                  ),
                  (
                    message: 'Food is necessary',
                    subMessage: 'No blame here. The overall budget is simply past the line now.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、生活の土台だね',
                    subMessage: '食べるのは大事だよ。ただ今月全体はもうオーバーしてるから、ここからは静かに着地したいね。',
                  ),
                  (
                    message: 'スーパー、必要枠だね',
                    subMessage: '必要な支出だよ。今月はもう予算を越えてるから、ここからの一手だけ少し丁寧に見たいね。',
                  ),
                  (
                    message: '食費、避けられないね',
                    subMessage: '責めるところじゃないよ。ただ全体予算はラインを越えてる状態だね。',
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
                    message: 'Groceries are getting tight',
                    subMessage: 'Necessary spending, but this category has very little room left.',
                  ),
                  (
                    message: 'Food spending is near the edge',
                    subMessage: 'No blame here. It just needs a little more visibility from here.',
                  ),
                  (
                    message: 'Groceries are carrying weight',
                    subMessage: 'Essentials are showing up clearly in the budget now.',
                  ),
                ]
              : [
                  (
                    message: '食費、かなり使ってるね',
                    subMessage: '必要なお金だからこそ、ここからは配分を少し見たいところだね。',
                  ),
                  (
                    message: '${latestExpense.storeName}、必要枠だね',
                    subMessage: '責める支出じゃないよ。ただこのカテゴリは余白がかなり少なくなってるね。',
                  ),
                  (
                    message: 'スーパー、重み出てきたね',
                    subMessage: '生活には必要だよ。だからこそ、見えるところに置いておきたいね。',
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
                    message: 'Groceries are moving a bit fast',
                    subMessage: 'Necessary shopping, but the food category is starting to stand out.',
                  ),
                  (
                    message: 'Food spending is showing up',
                    subMessage: 'Normal life spending. Still, the pace is worth keeping visible.',
                  ),
                  (
                    message: 'Groceries have presence now',
                    subMessage: 'Nothing to blame. It may just affect the room you have later in the month.',
                  ),
                ]
              : [
                  (
                    message: '食費、少しペース出てきたね',
                    subMessage: '必要な買い物だけど、後半の余裕には少し効いてきそうだよ。',
                  ),
                  (
                    message: 'スーパー、じわっと見えてきたね',
                    subMessage: '生活費として自然だよ。ただ、ここからは配分も少し見ておきたいね。',
                  ),
                  (
                    message: '食費、存在感出てきたね',
                    subMessage: '責める場面じゃないよ。ただ後半の余白にはちゃんと関わってくるね。',
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
                    message: 'Groceries are essentials',
                    subMessage: 'Food is the foundation. The wallet will keep this one quietly visible.',
                  ),
                  (
                    message: 'A grocery run',
                    subMessage: 'Normal life spending. Keeping it visible is enough.',
                  ),
                  (
                    message: 'Food spending noted',
                    subMessage: 'This makes sense. No drama here, just a useful record.',
                  ),
                ]
              : [
                  (
                    message: '${latestExpense.storeName}、生活の土台だね',
                    subMessage: 'スーパーは必要な支出だよ。今日は静かに見守るね。',
                  ),
                  (
                    message: 'スーパー、必要枠だね',
                    subMessage: '生活の一部だね。見える形で残っているだけで十分いいよ。',
                  ),
                  (
                    message: '食費、ちゃんと見えてるね',
                    subMessage: '必要な支出だね。こういう土台のお金こそ、見える形にしておくと安心だよ。',
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
    else if (latestStore.isNotEmpty) {
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
    // === END REORDERED BRANCHES ===

final baseLatestComment = latestComment;
final latestIsSupermarket = judge.tags.contains(ExpenseJudgeTag.supermarket);

final uiLatestComment = latestIsSupermarket
    ? baseLatestComment
    : _higherPriorityLatestComment(baseLatestComment, priorityLatestComment) ??
        baseLatestComment;

_LatestComment notificationSource = baseLatestComment;

final priorityIsLatestExpenseContext =
    priorityLatestComment != null &&
    !priorityLatestComment.scenarioKey.contains('remaining_per_day');

if (!latestIsSupermarket && priorityIsLatestExpenseContext) {
  notificationSource = priorityLatestComment;
}

// Avoid duplicate headline between primary and secondary comment
if (uiLatestComment.message == secondaryMessage) {
  secondaryMessage = '';
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