import 'package:saiyome/models/expense.dart';
import 'package:saiyome/services/expense_judge_service.dart';

enum CategoryFit {
  fit,
  acceptable,
  mismatch,
}

enum PaceStatus {
  safe,
  warning,
  danger,
  over,
}

enum RatioStatus {
  unknown,
  balanced,
  noticeable,
  dominant,
}

class SpendingRuleResult {
  final CategoryFit categoryFit;
  final PaceStatus paceStatus;
  final double usageRate;
  final double progressRate;
  final bool isTooFast;
  final bool isCategoryOver;
  final double tagUsageRatio;
  final RatioStatus ratioStatus;
  final bool isTagDominant;

  const SpendingRuleResult({
    required this.categoryFit,
    required this.paceStatus,
    required this.usageRate,
    required this.progressRate,
    required this.isTooFast,
    required this.isCategoryOver,
    required this.tagUsageRatio,
    required this.ratioStatus,
    required this.isTagDominant,
  });
}

class SpendingRuleService {
  static SpendingRuleResult evaluate({
    required Expense expense,
    required ExpenseJudgeResult judgeResult,
    required int categoryBudget,
    required int categoryUsed,
    required DateTime cycleStart,
    required DateTime cycleEnd,
    Map<ExpenseJudgeTag, int>? tagUsedAmounts,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    final usageRate = categoryBudget <= 0 ? 0.0 : categoryUsed / categoryBudget;
    final isCategoryOver = categoryBudget > 0 && categoryUsed > categoryBudget;

    final totalDays = cycleEnd.difference(cycleStart).inDays + 1;
    final elapsedDays = _clampInt(
      current.difference(cycleStart).inDays + 1,
      min: 1,
      max: totalDays <= 0 ? 1 : totalDays,
    );
    final progressRate = totalDays <= 0 ? 0.0 : elapsedDays / totalDays;

    final isTooFast = usageRate > progressRate + 0.2;

    final tagUsageRatio = _calculateTagUsageRatio(
      judgeResult: judgeResult,
      categoryUsed: categoryUsed,
      tagUsedAmounts: tagUsedAmounts,
    );

    final ratioStatus = _evaluateRatioStatus(tagUsageRatio);
    final isTagDominant = ratioStatus == RatioStatus.dominant;

    final categoryFit = _evaluateCategoryFit(
      categoryName: expense.category.trim(),
      judgeResult: judgeResult,
    );

    final paceStatus = _evaluatePaceStatus(
      usageRate: usageRate,
      isCategoryOver: isCategoryOver,
      isTooFast: isTooFast,
    );

    return SpendingRuleResult(
      categoryFit: categoryFit,
      paceStatus: paceStatus,
      usageRate: usageRate,
      progressRate: progressRate,
      isTooFast: isTooFast,
      isCategoryOver: isCategoryOver,
      tagUsageRatio: tagUsageRatio,
      ratioStatus: ratioStatus,
      isTagDominant: isTagDominant,
    );
  }

  static double _calculateTagUsageRatio({
    required ExpenseJudgeResult judgeResult,
    required int categoryUsed,
    Map<ExpenseJudgeTag, int>? tagUsedAmounts,
  }) {
    if (categoryUsed <= 0 || tagUsedAmounts == null || tagUsedAmounts.isEmpty) {
      return 0.0;
    }

    var matchedAmount = 0;
    for (final tag in judgeResult.tags) {
      matchedAmount += tagUsedAmounts[tag] ?? 0;
    }

    if (matchedAmount <= 0) return 0.0;
    return matchedAmount / categoryUsed;
  }

  static RatioStatus _evaluateRatioStatus(double ratio) {
    if (ratio <= 0) return RatioStatus.unknown;
    if (ratio >= 0.7) return RatioStatus.dominant;
    if (ratio >= 0.4) return RatioStatus.noticeable;
    return RatioStatus.balanced;
  }

  static CategoryFit _evaluateCategoryFit({
    required String categoryName,
    required ExpenseJudgeResult judgeResult,
  }) {
    final normalizedCategory = categoryName.trim();
    final tags = judgeResult.tags;

    if (tags.contains(ExpenseJudgeTag.cafe)) {
      if (normalizedCategory == 'カフェ') return CategoryFit.fit;
      if (normalizedCategory == '食費') return CategoryFit.acceptable;
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.convenience)) {
      if (normalizedCategory == 'コンビニ') return CategoryFit.fit;
      if (normalizedCategory == '食費') return CategoryFit.acceptable;
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.dining)) {
      if (normalizedCategory == '外食') return CategoryFit.fit;
      if (normalizedCategory == '食費') return CategoryFit.acceptable;
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.supermarket)) {
      if (normalizedCategory == '食費' || normalizedCategory == 'スーパー') {
        return CategoryFit.fit;
      }
      if (normalizedCategory == '日用品') return CategoryFit.acceptable;
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.drinking)) {
      if (normalizedCategory == '飲み' || normalizedCategory == '居酒屋') {
        return CategoryFit.fit;
      }
      if (normalizedCategory == '外食' || normalizedCategory == '交際費') {
        return CategoryFit.acceptable;
      }
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.fashion)) {
      if (normalizedCategory == '服' || normalizedCategory == 'ファッション') {
        return CategoryFit.fit;
      }
      if (normalizedCategory == '美容' || normalizedCategory == '趣味') {
        return CategoryFit.acceptable;
      }
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.dailyGoods)) {
      if (normalizedCategory == '日用品') return CategoryFit.fit;
      if (normalizedCategory == '食費' || normalizedCategory == 'スーパー') {
        return CategoryFit.acceptable;
      }
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.entertainment)) {
      if (normalizedCategory == '娯楽' || normalizedCategory == '趣味') {
        return CategoryFit.fit;
      }
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.travel)) {
      if (normalizedCategory == '旅行') return CategoryFit.fit;
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.hobby)) {
      if (normalizedCategory == '趣味') return CategoryFit.fit;
      if (normalizedCategory == '娯楽') return CategoryFit.acceptable;
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.beauty)) {
      if (normalizedCategory == '美容') return CategoryFit.fit;
      if (normalizedCategory == '日用品') return CategoryFit.acceptable;
      if (normalizedCategory == 'その他') return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.health)) {
      if (normalizedCategory == '医療') return CategoryFit.fit;
      if (normalizedCategory == 'その他') return CategoryFit.acceptable;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.transport)) {
      if (normalizedCategory == '交通') return CategoryFit.fit;
      if (normalizedCategory == '旅行') return CategoryFit.acceptable;
      if (normalizedCategory == 'その他') return CategoryFit.acceptable;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.ceremony)) {
      if (normalizedCategory == '冠婚葬祭' ||
          normalizedCategory == 'お祝い' ||
          normalizedCategory == '贈り物') {
        return CategoryFit.fit;
      }
      if (normalizedCategory == 'その他') return CategoryFit.acceptable;
      return CategoryFit.acceptable;
    }

    return normalizedCategory == 'その他'
        ? CategoryFit.mismatch
        : CategoryFit.acceptable;
  }

  static PaceStatus _evaluatePaceStatus({
    required double usageRate,
    required bool isCategoryOver,
    required bool isTooFast,
  }) {
    if (isCategoryOver || usageRate >= 1.0) {
      return PaceStatus.over;
    }

    if (usageRate >= 0.9 || isTooFast && usageRate >= 0.75) {
      return PaceStatus.danger;
    }

    if (usageRate >= 0.75 || isTooFast) {
      return PaceStatus.warning;
    }

    return PaceStatus.safe;
  }

  static int _clampInt(int value, {required int min, required int max}) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}