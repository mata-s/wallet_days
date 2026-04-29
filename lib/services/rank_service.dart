import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/utils/time_provider.dart';

class RankResult {
  final String rankKey;
  final String rankLabel;
  final String rankLabelEn;
  final int achievedCount;
  final int totalCount;
  final int streak;
  final int bestStreak;
  final double successRate;
  final String comment;
  final String commentEn;

  const RankResult({
    required this.rankKey,
    required this.rankLabel,
    required this.rankLabelEn,
    required this.achievedCount,
    required this.totalCount,
    required this.streak,
    required this.bestStreak,
    required this.successRate,
    required this.comment,
    required this.commentEn,
  });
}

class RankService {
  static RankResult calculate(List<BudgetHistory> histories) {
    if (histories.isEmpty) {
      return const RankResult(
        rankKey: 'starter',
        rankLabel: 'スターター',
        rankLabelEn: 'Starter',
        achievedCount: 0,
        totalCount: 0,
        streak: 0,
        bestStreak: 0,
        successRate: 0,
        comment: 'まずは最初の1ヶ月を達成してみよう。',
        commentEn: '“Start with your first good month. I’ll watch your budget with you.”',
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
    final rankLabelEn = _rankLabelEn(rankKey);
    final comment = _buildComment(
      rankKey: rankKey,
      streak: streak,
      totalCount: totalCount,
      successRate: successRate,
    );
    final commentEn = _buildCommentEn(
      rankKey: rankKey,
      streak: streak,
      totalCount: totalCount,
      successRate: successRate,
    );

    return RankResult(
      rankKey: rankKey,
      rankLabel: rankLabel,
      rankLabelEn: rankLabelEn,
      achievedCount: achievedCount,
      totalCount: totalCount,
      streak: streak,
      bestStreak: bestStreak,
      successRate: successRate,
      comment: comment,
      commentEn: commentEn,
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
  
  static String _rankLabelEn(String rankKey) {
    switch (rankKey) {
      case 'diamond':
        return 'Diamond';
      case 'platinum':
        return 'Platinum';
      case 'gold':
        return 'Gold';
      case 'silver':
        return 'Silver';
      case 'bronze':
        return 'Bronze';
      default:
        return 'Starter';
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
      return '「まずはあと少しデータをためよう。ペース、一緒に見ていこうね。」';
    }

    if (streak >= 3) {
      return '「$streakヶ月連続で守れてるよ。このままいけそうだね。」';
    }

    switch (rankKey) {
      case 'diamond':
        return '「達成率$percent%だね。すごい安定感だよ。」';
      case 'platinum':
        return '「達成率$percent%。かなり上手にやれてるよ。」';
      case 'gold':
        return '「達成率$percent%。いいペースだね。」';
      case 'silver':
        return '「達成率$percent%。だいぶ安定してきたね。」';
      case 'bronze':
        return '「達成率$percent%。いいスタートだよ。」';
      default:
        return '「ここからだね。一緒にペース作っていこう。」';
    }
  }

  static String _buildCommentEn({
    required String rankKey,
    required int streak,
    required int totalCount,
    required double successRate,
  }) {
    final percent = (successRate * 100).round();
    if (totalCount < 3) {
      return '“Let’s collect a little more data first. I’ll watch your pace with you.”';
    }

    if (streak >= 3) {
      return '“You’ve stayed on track for $streak months in a row. I think we can keep this going.”';
    }

    switch (rankKey) {
      case 'diamond':
        return '“Your success rate is $percent%. That consistency is amazing.”';
      case 'platinum':
        return '“$percent% success rate. You’re handling this really well.”';
      case 'gold':
        return '“$percent% success rate. Nice pace.”';
      case 'silver':
        return '“$percent% success rate. You’re getting more stable.”';
      case 'bronze':
        return '“$percent% success rate. Nice start.”';
      default:
        return '“This is where we begin. Let’s build your pace together.”';
    }
  }
}