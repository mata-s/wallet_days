import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/utils/time_provider.dart';

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

    final now = getNow();
    final closedHistories = sorted.where((history) {
      return !now.isBefore(history.endDate);
    }).toList();

    print('[RankService] histories.length=${histories.length}');
    for (final h in sorted) {
      print(
        '[RankService] history '
        '${h.startDate} ~ ${h.endDate} '
        'achieved=${h.isAchieved} '
        'streak=${h.streak} '
        'bestStreak=${h.bestStreak} '
        'closed=${!now.isBefore(h.endDate)}',
      );
    }

    final achievedCount = closedHistories.where((e) => e.isAchieved).length;
    final closedCount = closedHistories.length;
    final totalCount = sorted.length;
    final latest = sorted.last;
    final streak = latest.streak;
    final bestStreak = latest.bestStreak;
    final successRate =
        closedHistories.isEmpty ? 0.0 : achievedCount / closedHistories.length;

    final rankKey = _rankKeyFromStats(
      closedCount: closedCount,
      achievedCount: achievedCount,
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


  static String _rankKeyFromStats({
    required int closedCount,
    required int achievedCount,
    required double successRate,
  }) {
    if (closedCount >= 12 && successRate >= 0.90) return 'diamond';
    if (closedCount >= 9 && successRate >= 0.80) return 'platinum';
    if (closedCount >= 6 && successRate >= 0.70) return 'gold';

    // 初期は緩める
    if (closedCount >= 2 && successRate >= 0.50) return 'silver';
    if (closedCount >= 1 && achievedCount >= 1) return 'bronze';

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