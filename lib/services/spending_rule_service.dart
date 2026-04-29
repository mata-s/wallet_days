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
    final categoryLower = normalizedCategory.toLowerCase();
    final tags = judgeResult.tags;

    if (tags.contains(ExpenseJudgeTag.cafe)) {
      if (_categoryIn(categoryLower, const ['カフェ', 'cafe', 'coffee'])) return CategoryFit.fit;
      if (_categoryIn(categoryLower, const ['食費', 'food', 'groceries'])) return CategoryFit.acceptable;
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.convenience)) {
      if (_categoryIn(categoryLower, const ['コンビニ', 'convenience', 'convenience store'])) return CategoryFit.fit;
      if (_categoryIn(categoryLower, const ['食費', 'food', 'groceries'])) return CategoryFit.acceptable;
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.dining)) {
      if (_categoryIn(categoryLower, const ['外食', 'dining', 'restaurant', 'restaurants', 'eating out'])) return CategoryFit.fit;
      if (_categoryIn(categoryLower, const ['食費', 'food', 'groceries'])) return CategoryFit.acceptable;
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.supermarket)) {
      if (_categoryIn(categoryLower, const ['食費', 'スーパー', 'food', 'grocery', 'groceries', 'supermarket'])) {
        return CategoryFit.fit;
      }
      if (_categoryIn(categoryLower, const ['日用品', 'daily goods', 'household', 'household goods'])) return CategoryFit.acceptable;
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.drinking)) {
      if (_categoryIn(categoryLower, const ['飲み', '居酒屋', 'drinking', 'bar', 'pub'])) {
        return CategoryFit.fit;
      }
      if (_categoryIn(categoryLower, const ['外食', '交際費', 'dining', 'social', 'socializing'])) {
        return CategoryFit.acceptable;
      }
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.fashion)) {
      if (_categoryIn(categoryLower, const ['服', 'ファッション', 'fashion', 'clothes', 'clothing', 'apparel'])) {
        return CategoryFit.fit;
      }
      if (_categoryIn(categoryLower, const ['美容', '趣味', 'beauty', 'hobby', 'hobbies'])) {
        return CategoryFit.acceptable;
      }
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.dailyGoods)) {
      if (_categoryIn(categoryLower, const ['日用品', 'daily goods', 'household', 'household goods'])) return CategoryFit.fit;
      if (_categoryIn(categoryLower, const ['食費', 'スーパー', 'food', 'grocery', 'groceries', 'supermarket'])) {
        return CategoryFit.acceptable;
      }
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.onlineShopping)) {
      if (_categoryIn(categoryLower, const ['ネットショッピング', '通販', 'online shopping', 'e-commerce', 'ecommerce'])) {
        return CategoryFit.fit;
      }
      if (_categoryIn(categoryLower, const ['日用品', '服', 'daily goods', 'household', 'clothing', 'fashion'])) {
        return CategoryFit.acceptable;
      }
      if (_categoryIn(categoryLower, const ['趣味', 'hobby', 'hobbies']) || _categoryIsOther(categoryLower)) {
        return CategoryFit.mismatch;
      }
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.movie)) {
      if (_categoryIn(categoryLower, const ['映画', '娯楽', 'エンタメ', 'レジャー', 'movie', 'movies', 'cinema', 'entertainment', 'leisure'])) {
        return CategoryFit.fit;
      }
      if (_categoryIn(categoryLower, const ['趣味', 'デート', 'hobby', 'hobbies', 'date'])) {
        return CategoryFit.acceptable;
      }
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.karaoke)) {
      if (_categoryIn(categoryLower, const ['カラオケ', '娯楽', 'エンタメ', 'レジャー', 'karaoke', 'entertainment', 'leisure'])) {
        return CategoryFit.fit;
      }
      if (_categoryIn(categoryLower, const ['趣味', 'ストレス発散', 'hobby', 'hobbies', 'stress relief'])) {
        return CategoryFit.acceptable;
      }
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.arcade)) {
      if (_categoryIn(categoryLower, const ['ゲームセンター', '娯楽', 'エンタメ', 'レジャー', '遊び', 'arcade', 'game center', 'entertainment', 'leisure', 'play'])) {
        return CategoryFit.fit;
      }
      if (_categoryIn(categoryLower, const ['趣味', 'デート', 'hobby', 'hobbies', 'date'])) {
        return CategoryFit.acceptable;
      }
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.entertainment)) {
      if (_categoryIn(categoryLower, const ['娯楽', '趣味', 'エンタメ', 'レジャー', 'entertainment', 'leisure', 'hobby', 'hobbies'])) {
        return CategoryFit.fit;
      }
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.travel)) {
      if (_categoryIn(categoryLower, const ['旅行', 'travel', 'trip', 'hotel'])) return CategoryFit.fit;
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.hobby)) {
      if (_categoryIn(categoryLower, const ['趣味', 'hobby', 'hobbies'])) return CategoryFit.fit;
      if (_categoryIn(categoryLower, const ['娯楽', 'エンタメ', 'entertainment', 'leisure'])) return CategoryFit.acceptable;
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.beauty)) {
      if (_categoryIn(categoryLower, const ['美容', 'beauty', 'self-care', 'self care', 'cosmetics'])) return CategoryFit.fit;
      if (_categoryIn(categoryLower, const ['日用品', 'daily goods', 'household'])) return CategoryFit.acceptable;
      if (_categoryIsOther(categoryLower)) return CategoryFit.mismatch;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.health)) {
      if (_categoryIn(categoryLower, const ['医療', '健康', '薬', 'health', 'medical', 'medicine', 'pharmacy'])) return CategoryFit.fit;
      if (_categoryIsOther(categoryLower)) return CategoryFit.acceptable;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.transport)) {
      if (_categoryIn(categoryLower, const ['交通', '交通費', '電車', 'バス', 'ガソリン', '駐車場', 'transport', 'transportation', 'train', 'bus', 'taxi', 'gas', 'parking'])) return CategoryFit.fit;
      if (_categoryIn(categoryLower, const ['旅行', 'travel', 'trip'])) return CategoryFit.acceptable;
      if (_categoryIsOther(categoryLower)) return CategoryFit.acceptable;
      return CategoryFit.acceptable;
    }

    if (tags.contains(ExpenseJudgeTag.ceremony)) {
      if (_categoryIn(categoryLower, const ['冠婚葬祭', 'お祝い', '贈り物', 'ceremony', 'gift', 'gifts', 'celebration'])) {
        return CategoryFit.fit;
      }
      if (_categoryIsOther(categoryLower)) return CategoryFit.acceptable;
      return CategoryFit.acceptable;
    }

    return _categoryIsOther(categoryLower)
        ? CategoryFit.mismatch
        : CategoryFit.acceptable;
  }

  static bool _categoryIn(String categoryLower, List<String> candidates) {
    return candidates.any((c) => categoryLower == c.toLowerCase());
  }

  static bool _categoryIsOther(String categoryLower) {
    return _categoryIn(categoryLower, const ['その他', 'other', 'misc', 'miscellaneous']);
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