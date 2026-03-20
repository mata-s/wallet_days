import 'package:saiyome/models/budget_history.dart';

class RankResult {
  final String rankKey;
  final String rankLabel;
  final int achievedCount;
  final int totalCount;
  final int streak;
  final int bestStreak;
  final double successRate;
  final String comment;

  const RankResult({
    required this.rankKey,
    required this.rankLabel,
    required this.achievedCount,
    required this.totalCount,
    required this.streak,
    required this.bestStreak,
    required this.successRate,
    required this.comment,
  });
}

class RankService {
  static RankResult calculate(List<BudgetHistory> histories) {
    if (histories.isEmpty) {
      return const RankResult(
        rankKey: 'starter',
        rankLabel: 'スターター',
        achievedCount: 0,
        totalCount: 0,
        streak: 0,
        bestStreak: 0,
        successRate: 0,
        comment: 'まずは最初の1ヶ月を達成してみましょう。',
      );
    }

    final sorted = [...histories]
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    final achievedCount = sorted.where((e) => e.isAchieved).length;
    final totalCount = sorted.length;
    final streak = _calculateCurrentStreak(sorted);
    final bestStreak = _calculateBestStreak(sorted);
    final successRate = totalCount == 0 ? 0.0 : achievedCount / totalCount;

    final rankKey = _rankKeyFromStats(
      totalCount: totalCount,
      successRate: successRate,
    );
    final rankLabel = _rankLabel(rankKey);
    final comment = _buildComment(
      rankKey: rankKey,
      streak: streak,
      totalCount: totalCount,
      successRate: successRate,
    );

    return RankResult(
      rankKey: rankKey,
      rankLabel: rankLabel,
      achievedCount: achievedCount,
      totalCount: totalCount,
      streak: streak,
      bestStreak: bestStreak,
      successRate: successRate,
      comment: comment,
    );
  }

  static int calculateNextStreak(List<BudgetHistory> histories, bool nextAchieved) {
    if (!nextAchieved) return 0;

    final current = calculate(histories).streak;
    return current + 1;
  }

  static String _rankKeyFromStats({
    required int totalCount,
    required double successRate,
  }) {
    if (totalCount >= 12 && successRate >= 0.90) return 'diamond';
    if (totalCount >= 9 && successRate >= 0.80) return 'platinum';
    if (totalCount >= 6 && successRate >= 0.70) return 'gold';

    // 初期は緩める
    if (totalCount >= 2 && successRate >= 0.50) return 'silver';
    if (totalCount >= 1 && successRate > 0) return 'bronze';

    return 'starter';
  }

  static String _rankLabel(String rankKey) {
    switch (rankKey) {
      case 'diamond':
        return 'ダイヤ';
      case 'platinum':
        return 'プラチナ';
      case 'gold':
        return 'ゴールド';
      case 'silver':
        return 'シルバー';
      case 'bronze':
        return 'ブロンズ';
      default:
        return 'スターター';
    }
  }

  static int _calculateCurrentStreak(List<BudgetHistory> sorted) {
    int streak = 0;

    for (final history in sorted.reversed) {
      if (!history.isAchieved) {
        break;
      }
      streak += 1;
    }

    return streak;
  }

  static int _calculateBestStreak(List<BudgetHistory> sorted) {
    int best = 0;
    int current = 0;

    for (final history in sorted) {
      if (history.isAchieved) {
        current += 1;
        if (current > best) {
          best = current;
        }
      } else {
        current = 0;
      }
    }

    return best;
  }

  static String _buildComment({
    required String rankKey,
    required int streak,
    required int totalCount,
    required double successRate,
  }) {
    final percent = (successRate * 100).round();

    if (totalCount < 3) {
      return 'まずは3ヶ月分ためると、あなたの予算ペースが見えやすくなります。';
    }

    if (streak >= 3) {
      return '$streakヶ月連続で予算内です。この調子です。';
    }

    switch (rankKey) {
      case 'diamond':
        return '$totalCountヶ月のうち達成率は$percent%です。かなり安定して予算管理できています。';
      case 'platinum':
        return '$totalCountヶ月のうち達成率は$percent%です。予算管理がかなり上手です。';
      case 'gold':
        return '$totalCountヶ月のうち達成率は$percent%です。良いペースで予算内を達成できています。';
      case 'silver':
        return '$totalCountヶ月で達成率は$percent%です。だんだん安定してきています。次はゴールドを目指せそうです。';
      case 'bronze':
        return '$totalCountヶ月で達成率は$percent%です。まずは安定して予算内を増やしていきましょう。';
      default:
        return '$totalCountヶ月で達成率は$percent%です。まずはブロンズを目指していきましょう。';
    }
  }
}