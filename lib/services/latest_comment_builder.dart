import 'package:saiyome/models/expense.dart';

String _normalizeLang(String languageCode) {
  return languageCode.toLowerCase().startsWith('ja') ? 'ja' : 'en';
}

String _t(String lang, String ja, String en) {
  return lang == 'ja' ? ja : en;
}

String _formatMoney(int amount, String lang) {
  if (lang == 'ja') return '$amount円';
  return '\$$amount';
}

enum CommentPerspective {
  moneyImpact,
  repeatPattern,
  categoryBudget,
  overallBudget,
  remainingPace,
  normal,
}

class LatestComment {
  final String scenarioKey;
  final CommentPerspective perspective;
  final String notificationBody;
  final String message;
  final String subMessage;
  final int priority;

  const LatestComment({
    required this.scenarioKey,
    this.perspective = CommentPerspective.normal,
    required this.notificationBody,
    required this.message,
    required this.subMessage,
    this.priority = 0,
  });
}

class LatestCommentBuilder {
  static LatestComment build({
    required Expense latestExpense,
    required String languageCode,
    required int amount,
    required int totalBudget,
    required int latestStoreCount,
  }) {
    final lang = _normalizeLang(languageCode);
    final storeName = latestExpense.storeName.trim();
    final moneyText = _formatMoney(amount, lang);
    final spendingRate = totalBudget <= 0 ? 0.0 : amount / totalBudget;

    if (spendingRate >= 0.25) {
      return LatestComment(
        scenarioKey: 'latest_money_impact_strong',
        perspective: CommentPerspective.moneyImpact,
        notificationBody: storeName.isNotEmpty
            ? _t(lang, '$storeName、大きめの一撃だよ。', '$storeName made a big impact.')
            : _t(lang, '大きめの支出を記録したよ。', 'A large expense was logged.'),
        message: _t(lang, '$moneyText、でかいね', '$moneyText is a big one'),
        subMessage: _t(
          lang,
          '今回の一撃だよ。財布、ちょっと揺れてるね。',
          'That hit the wallet pretty clearly.',
        ),
        priority: 120,
      );
    }

    if (latestStoreCount >= 3 && storeName.isNotEmpty) {
      return LatestComment(
        scenarioKey: 'latest_store_repeat',
        perspective: CommentPerspective.repeatPattern,
        notificationBody: _t(
          lang,
          '$storeName、記録したよ',
          '$storeName logged',
        ),
        message: _t(
          lang,
          '$storeName、流れが見えてきたね',
          '$storeName is showing a pattern',
        ),
        subMessage: _t(
          lang,
          '今月$latestStoreCount回目。悪くないけど、財布には見えてきたよ。',
          '$latestStoreCount times this month. Not bad, just visible now.',
        ),
        priority: 60,
      );
    }

    return LatestComment(
      scenarioKey: 'latest_normal',
      perspective: CommentPerspective.normal,
      notificationBody: storeName.isNotEmpty
          ? _t(lang, '$storeName、記録したよ', '$storeName logged')
          : _t(lang, '記録したよ', 'Logged'),
      message: storeName.isNotEmpty
          ? _t(lang, '$storeName、記録したよ', '$storeName logged')
          : _t(lang, '記録したよ', 'Logged'),
      subMessage: '',
      priority: 0,
    );
  }
}