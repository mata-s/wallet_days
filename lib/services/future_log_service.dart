import 'package:saiyome/models/expense.dart';

class FutureLogResult {
  final String title;
  final String message;
  final int? predictedDays;

  const FutureLogResult({
    required this.title,
    required this.message,
    this.predictedDays,
  });
}

class FutureLogService {
  static FutureLogResult? build({
    required int totalBudget,
    required int usedAmount,
    required DateTime cycleStart,
    required DateTime today,
    required DateTime cycleEnd,
    required List<Expense> expenses,
  }) {
    if (expenses.isEmpty) return null;

    final daysPassed = today.difference(cycleStart).inDays + 1;
    if (daysPassed <= 0) return null;

    final dailyAverage = usedAmount / daysPassed;
    if (dailyAverage <= 0) return null;

    final remainingBudget = totalBudget - usedAmount;

    if (remainingBudget <= 0) {
      return const FutureLogResult(
        title: '未来ログ',
        message: 'すでに予算オーバーしています。未来はもう来ています。',
      );
    }

    final predictedDays = (remainingBudget / dailyAverage).floor();

    if (predictedDays <= 0) {
      return const FutureLogResult(
        title: '未来ログ',
        message: 'このペースだと、今日中に予算オーバーします。',
      );
    }

    final predictedDate = today.add(Duration(days: predictedDays));

    if (predictedDate.isAfter(cycleEnd)) {
      return const FutureLogResult(
        title: '未来ログ',
        message: '今のペースなら、今月は乗り切れそうです。',
      );
    }

    return FutureLogResult(
      title: '未来ログ',
      message: 'このペースだと、あと$predictedDays日で予算オーバーします。',
      predictedDays: predictedDays,
    );
  }
}