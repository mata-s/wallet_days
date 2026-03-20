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
    final messageParts = <String>[
      mainMessage,
      if (leadMessage != null && leadMessage.isNotEmpty) leadMessage,
    ];

    final subParts = <String>[
      mainSubMessage,
      if (leadSubMessage != null && leadSubMessage.isNotEmpty) leadSubMessage,
    ];

    return RoastResult(
      title: title,
      message: messageParts.join('\n'),
      subMessage: subParts.join('\n'),
      notificationBody: notificationBody,
      scenarioKey: scenarioKey,
    );
  }

  static RoastResult build({
    required int totalBudget,
    required int usedAmount,
    required List<Expense> expenses,
    required List<Map<String, dynamic>> dangerCategories,
    int? latestCategoryBudget,
    int? latestCategoryUsed,
    DateTime? cycleStart,
    DateTime? cycleEnd,
    Map<ExpenseJudgeTag, int>? latestCategoryTagUsedAmounts,
  }) {
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

    int cafeCount = 0;
    int convenienceCount = 0;
    int diningCount = 0;
    int suddenExpenseCount = 0;
    final storeCounts = <String, int>{};

    for (final e in expenses) {
      if (_isCafe(e)) cafeCount++;
      if (_isConvenience(e)) convenienceCount++;
      if (_isDining(e)) diningCount++;
      if (e.category == 'その他') suddenExpenseCount++;

      final name = e.storeName.trim();
      if (name.isNotEmpty) {
        storeCounts[name] = (storeCounts[name] ?? 0) + 1;
      }
    }

    final latestExpense = expenses.first;
    final latestStore = latestExpense.storeName.trim();

    final consecutiveStoreCount =
        ExpenseJudgeService.consecutiveStoreCount(expenses);
    final hasConsecutiveStoreSpending =
        ExpenseJudgeService.hasConsecutiveStoreSpending(expenses);
    final consecutiveCafeCount =
        _consecutiveTagCount(expenses, ExpenseJudgeTag.cafe, totalBudget);
    final consecutiveConvenienceCount = _consecutiveTagCount(
      expenses,
      ExpenseJudgeTag.convenience,
      totalBudget,
    );
    final consecutiveDiningCount =
        _consecutiveTagCount(expenses, ExpenseJudgeTag.dining, totalBudget);

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

    if (judge.tags.contains(ExpenseJudgeTag.supermarket)) {
      return RoastResult(
        title: '財布からひとこと',
        message: '${latestExpense.storeName}での買い物を記録しました。',
        subMessage: 'スーパーの買い物は生活に必要なことも多いので、今回は静かに見守ります。',
        notificationBody: '',
        scenarioKey: 'latest_supermarket',
      );
    }

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
        ? remainingBudget / daysLeft
        : null;

    String? leadMessage;
    String? leadSubMessage;

    if (spendingRate >= 0.25) {
      final variant = _pickVariant('expensive_spending', [
        (
          message: '${latestExpense.storeName}で$amount円ですか。',
          subMessage: '一回の支出としてはかなり大きめです。財布が少し震えています。',
        ),
        (
          message: '${latestExpense.storeName}で$amount円、なかなか大きいですね。',
          subMessage: '今月の予算に対して見ると、かなり存在感のある一撃です。',
        ),
        (
          message: '$amount円の支出を確認しました。',
          subMessage: '${latestExpense.storeName}、今日はちょっと豪華でしたね。',
        ),
        (
          message: '${latestExpense.storeName}での出費、かなりインパクトがあります。',
          subMessage: '一回でここまで動くと、財布もさすがに気づきます。',
        ),
      ]);

      leadMessage = variant.message;
      leadSubMessage = variant.subMessage;
    } else if (spendingRate >= 0.15) {
      final variant = _pickVariant('mid_spending', [
        (
          message: '${latestExpense.storeName}で$amount円ですね。',
          subMessage: '設定予算に対して見ると、じわじわ効いてくるタイプの出費です。',
        ),
        (
          message: '${latestExpense.storeName}で$amount円、少し大きめですね。',
          subMessage: '一回ごとの重さが、あとで効いてきそうです。',
        ),
        (
          message: '$amount円の支出を記録しました。',
          subMessage: '小さすぎない出費なので、少しだけ意識していきたいところです。',
        ),
        (
          message: '${latestExpense.storeName}、今回の支出はやや存在感があります。',
          subMessage: '予算全体から見ると、油断できないサイズです。',
        ),
      ]);

      leadMessage = variant.message;
      leadSubMessage = variant.subMessage;
    } else if (spendingRate >= 0.08) {
      final variant = _pickVariant('light_high_spending', [
        (
          message: '${latestExpense.storeName}で$amount円ですね。',
          subMessage: '一回としては少し重めです。じわじわ効いてくるタイプです。',
        ),
        (
          message: '${latestExpense.storeName}で$amount円、ちょっと存在感あります。',
          subMessage: 'まだ問題ないですが、積み重なるとしっかり効いてきます。',
        ),
        (
          message: '$amount円の支出を確認しました。',
          subMessage: '軽くはない金額なので、少しだけ意識しておきたいところです。',
        ),
        (
          message: '${latestExpense.storeName}ですね。',
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

        return _composeResult(
          title: '財布からひとこと',
          scenarioKey: 'category_danger',
          notificationBody: '$criticalBadge $criticalName が90%を超えました。',
          leadMessage: secondaryMessage,
          leadSubMessage: secondarySubMessage,
          mainMessage: variant.message,
          mainSubMessage: variant.subMessage,
        );
      }

      if (criticalUsageRate >= 0.75) {
        final variant = _pickVariant('category_warning', [
          (
            message: '$criticalBadge $criticalName、そろそろ危険です。',
            subMessage: '今ならまだ引き返せます。財布はまだ助かります。',
          ),
          (
            message: '$criticalBadge $criticalName、少しペースが速いです。',
            subMessage: 'このままだと上限が見えてきます。',
          ),
          (
            message: '$criticalBadge $criticalName、じわじわ効いています。',
            subMessage: 'ここで少し抑えると後半がかなり楽になります。',
          ),
        ]);

        return _composeResult(
          title: '財布からひとこと',
          scenarioKey: 'category_warning',
          notificationBody: '$criticalBadge $criticalName が75%を超えました。',
          leadMessage: secondaryMessage,
          leadSubMessage: secondarySubMessage,
          mainMessage: variant.message,
          mainSubMessage: variant.subMessage,
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'overall_over',
        notificationBody: '今月の予算を使い切りました。',
        leadMessage: secondaryMessage,
        leadSubMessage: secondarySubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'overall_danger',
        notificationBody: '全体予算が90%を超えました。',
        leadMessage: secondaryMessage,
        leadSubMessage: secondarySubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (cafeCount >= 5) {
      final variant = _pickVariant('cafe_repeat', [
        (
          message: '今月カフェ$cafeCount回目です。',
          subMessage: 'もはや習慣になっていますね。',
        ),
        (
          message: '今月カフェ$cafeCount回目ですね。',
          subMessage: '一杯ずつでも、積み重なるとしっかり効いてきます。',
        ),
        (
          message: 'カフェ、今月もう$cafeCount回目です。',
          subMessage: '財布より先に、カフェの店員さんに覚えられそうです。',
        ),
      ]);

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'cafe_repeat',
        notificationBody: '今月カフェ$cafeCount回目です。',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (convenienceCount >= 5) {
      final variant = _pickVariant('convenience_repeat', [
        (
          message: 'コンビニ$convenienceCount回目です。',
          subMessage: '便利さに財布が負けています。',
        ),
        (
          message: '今月コンビニ$convenienceCount回ですね。',
          subMessage: '一回ずつは軽くても、回数で見ると存在感があります。',
        ),
        (
          message: 'コンビニ率、高めです。今月$convenienceCount回目です。',
          subMessage: '気軽に入れる分、財布にはしっかり記録されています。',
        ),
        (
          message: '今月のコンビニ回数は$convenienceCount回です。',
          subMessage: '手軽さの裏で、じわじわ予算が削られています。',
        ),
      ]);

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'convenience_repeat',
        notificationBody: 'コンビニ$convenienceCount回目です。',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (diningCount >= 5) {
      final variant = _pickVariant('dining_repeat', [
        (
          message: '外食$diningCount回目です。',
          subMessage: '満足度は高いですが、予算も見ています。',
        ),
        (
          message: '今月、外食が$diningCount回あります。',
          subMessage: '楽しさはありますが、そろそろ頻度も気になってきます。',
        ),
        (
          message: '外食ペース、やや高めです。今月$diningCount回目です。',
          subMessage: '満足感と引き換えに、財布は少し軽くなっています。',
        ),
        (
          message: '今月の外食は$diningCount回目です。',
          subMessage: '気分転換には良いですが、積み重なると効いてきます。',
        ),
      ]);

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'dining_repeat',
        notificationBody: '外食$diningCount回目です。',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (suddenExpenseCount >= 3) {
      final variant = _pickVariant('sudden_expense_repeat', [
        (
          message: '今月、急な出費が$suddenExpenseCount回あります。',
          subMessage: '予定外のお金が続くと、財布の余命がじわじわ縮みます。',
        ),
        (
          message: '急な出費、今月もう$suddenExpenseCount回目です。',
          subMessage: '急ではなく、少しずつ月の流れになってきているかもしれません。',
        ),
        (
          message: '今月は急な出費が多めですね。',
          subMessage: 'こういう月のために、少し余白のある予算にしておくとかなり楽になります。',
        ),
        (
          message: '急な出費カテゴリが目立ってきました。',
          subMessage: '予定外の支出が重なる月は、思った以上に財布へ効いてきます。',
        ),
      ]);

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'sudden_expense_repeat',
        notificationBody: '今月、急な出費が$suddenExpenseCount回あります。',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (hasConsecutiveStoreSpending && latestStore.isNotEmpty) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'consecutive_store',
        notificationBody: '$latestStore の支出が$consecutiveStoreCount回連続です。',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (latestStore.isNotEmpty) {
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

        return _composeResult(
          title: '財布からひとこと',
          scenarioKey: 'store_repeat',
          notificationBody: '$latestStore の支出が$count回目です。',
          leadMessage: leadMessage,
          leadSubMessage: leadSubMessage,
          mainMessage: variant.message,
          mainSubMessage: variant.subMessage,
        );
      }
    }

    if (judge.tags.contains(ExpenseJudgeTag.kids) ||
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_kids',
        notificationBody: '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.gambling)) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_gambling',
        notificationBody: judge.shouldNotify
            ? '${latestExpense.storeName}でギャンブル系の支出を記録しました。'
            : '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.luxury)) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_luxury',
        notificationBody: judge.shouldNotify
            ? '${latestExpense.storeName}で高級品寄りの支出を記録しました。'
            : '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.sensitive)) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_sensitive',
        notificationBody: '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.cafe)) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_cafe',
        notificationBody: '☕ ${latestExpense.storeName} の支出を記録しました。',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.convenience)) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_convenience',
        notificationBody: '🏪 コンビニ支出を記録しました。',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.dining)) {
      final variant = ruleResult?.categoryFit == CategoryFit.mismatch
          ? _pickVariant('latest_dining_mismatch', [
              (
                message: '${latestExpense.storeName}、${latestExpense.category}に入っていますね。',
                subMessage: '外食は分けておくと、食費との違いがかなり見えやすくなります。',
              ),
              (
                message: '${latestExpense.storeName}が急な出費に入っています。',
                subMessage: '外食は意外と存在感があるので、見える化しておくと管理しやすいです。',
              ),
              (
                message: '${latestExpense.storeName}、今回は${latestExpense.category}扱いなんですね。',
                subMessage: '外食枠として分けると、使い方の傾向がもっと分かりやすくなります。',
              ),
            ])
          : ruleResult?.paceStatus == PaceStatus.danger ||
                  ruleResult?.paceStatus == PaceStatus.over
              ? _pickVariant('latest_dining_danger', [
                  (
                    message: '${latestExpense.storeName}での外食ですね。',
                    subMessage: '外食ペースがかなり速めです。ここからは少し重さが出てきそうです。',
                  ),
                  (
                    message: '${latestExpense.storeName}、おいしかったですか？',
                    subMessage: '満足感はありそうですが、予算の進み方はかなり前のめりです。',
                  ),
                  (
                    message: '外食を記録しました。',
                    subMessage: '今の流れだと、後半の余裕が少し心配です。',
                  ),
                ])
              : ruleResult?.paceStatus == PaceStatus.warning
                  ? _pickVariant('latest_dining_warning', [
                      (
                        message: '${latestExpense.storeName}での外食ですね。',
                        subMessage: 'まだ大丈夫ですが、外食ペースは少し早めです。',
                      ),
                      (
                        message: '${latestExpense.storeName}、今日は外食気分だったんですね。',
                        subMessage: '楽しめていますが、少しずつ予算への存在感が出てきています。',
                      ),
                      (
                        message: '外食を記録しました。',
                        subMessage: '今のうちに少し整えると、後半がかなり楽になります。',
                      ),
                    ])
                  : _pickVariant('latest_dining_fit', [
                      (
                        message: '${latestExpense.storeName}での外食ですね。',
                        subMessage: '今のところは予算の範囲で楽しめています。',
                      ),
                      (
                        message: '${latestExpense.storeName}、おいしかったですか？',
                        subMessage: '外食も予算内なら、まずは落ち着いて見ていけそうです。',
                      ),
                      (
                        message: '外食を記録しました。お店は${latestExpense.storeName}ですね。',
                        subMessage: 'ちゃんと把握できているので、今のところは良い管理です。',
                      ),
                    ]);

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_dining',
        notificationBody: '🍜 ${latestExpense.storeName} の支出を記録しました。',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.hobby)) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_hobby',
        notificationBody: judge.shouldNotify
            ? '${latestExpense.storeName}で趣味系の支出を記録しました。'
            : '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.beauty)) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_beauty',
        notificationBody: judge.shouldNotify
            ? '${latestExpense.storeName}で美容系の支出を記録しました。'
            : '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (ruleResult?.categoryFit == CategoryFit.mismatch) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_rule_mismatch',
        notificationBody: '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (ruleResult?.paceStatus == PaceStatus.danger ||
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_rule_danger',
        notificationBody: '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (ruleResult?.paceStatus == PaceStatus.warning) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_rule_warning',
        notificationBody: '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.ceremony)) {
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_ceremony',
        notificationBody: '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.tags.contains(ExpenseJudgeTag.health) ||
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

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_essential',
        notificationBody: '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

    if (judge.shouldAskAi) {
      final variant = _pickVariant('latest_unknown', [
        (
          message: '${latestExpense.storeName}での支出ですね。',
          subMessage: 'この出費はもう少し意味を見てから判断したいところです。',
        ),
        (
          message: '${latestExpense.storeName}、今回は少し判断が難しい支出です。',
          subMessage: '将来的にはここをAIで補えるようにしていく予定です。',
        ),
        (
          message: '${latestExpense.storeName}での記録を確認しました。',
          subMessage: 'いまはまだ静観ですが、あとで賢く判定できるようにしていきます。',
        ),
      ]);

      return _composeResult(
        title: '財布からひとこと',
        scenarioKey: 'latest_unknown',
        notificationBody: '',
        leadMessage: leadMessage,
        leadSubMessage: leadSubMessage,
        mainMessage: variant.message,
        mainSubMessage: variant.subMessage,
      );
    }

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

    return _composeResult(
      title: '財布からひとこと',
      scenarioKey: 'default',
      notificationBody: '${latestExpense.storeName} の支出を記録しました。',
      leadMessage: leadMessage,
      leadSubMessage: leadSubMessage,
      mainMessage: variant.message,
      mainSubMessage: variant.subMessage,
    );
  }
}