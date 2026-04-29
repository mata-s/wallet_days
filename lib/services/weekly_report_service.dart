import 'package:saiyome/models/expense.dart';

class WeeklyReport {
  final DateTime start;
  final DateTime end;
  final int totalExpense;
  final int previousWeekExpense;
  final int differenceFromPreviousWeek;
  final double changeRate;
  final String? topCategory;
  final int topCategoryAmount;
  final List<WeeklyCategorySummary> categories;
  final String comment;
  final String commentEn;

  const WeeklyReport({
    required this.start,
    required this.end,
    required this.totalExpense,
    required this.previousWeekExpense,
    required this.differenceFromPreviousWeek,
    required this.changeRate,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.categories,
    required this.comment,
    required this.commentEn,
  });
}

class WeeklyCategorySummary {
  final String category;
  final int amount;
  final double ratio;

  const WeeklyCategorySummary({
    required this.category,
    required this.amount,
    required this.ratio,
  });
}

class WeeklyReportService {
  static WeeklyReport generate({
    required List<Expense> expenses,
    required DateTime start,
    required DateTime end,
  }) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final currentWeekExpenses = expenses
        .where(
          (expense) =>
              !expense.createdAt.isBefore(normalizedStart) &&
              !expense.createdAt.isAfter(normalizedEnd),
        )
        .toList();

    final previousStart = normalizedStart.subtract(const Duration(days: 7));
    final previousEnd = normalizedStart.subtract(const Duration(seconds: 1));

    final previousWeekExpenses = expenses
        .where(
          (expense) =>
              !expense.createdAt.isBefore(previousStart) &&
              !expense.createdAt.isAfter(previousEnd),
        )
        .toList();

    final totalExpense = _sumAmount(currentWeekExpenses);
    final previousTotalExpense = _sumAmount(previousWeekExpenses);
    final difference = totalExpense - previousTotalExpense;
    final double changeRate = previousTotalExpense > 0
        ? difference / previousTotalExpense
        : (totalExpense > 0 ? 1.0 : 0.0);

    final categories = _buildCategorySummaries(currentWeekExpenses, totalExpense);
    final topCategory = categories.isNotEmpty ? categories.first.category : null;
    final topCategoryAmount = categories.isNotEmpty ? categories.first.amount : 0;

    return WeeklyReport(
      start: normalizedStart,
      end: DateTime(end.year, end.month, end.day),
      totalExpense: totalExpense,
      previousWeekExpense: previousTotalExpense,
      differenceFromPreviousWeek: difference,
      changeRate: changeRate,
      topCategory: topCategory,
      topCategoryAmount: topCategoryAmount,
      categories: categories,
      comment: _buildComment(
        totalExpense: totalExpense,
        previousWeekExpense: previousTotalExpense,
        changeRate: changeRate,
        topCategory: topCategory,
        topCategoryAmount: topCategoryAmount,
      ),
      commentEn: _buildCommentEn(
        totalExpense: totalExpense,
        previousWeekExpense: previousTotalExpense,
        changeRate: changeRate,
        topCategory: topCategory,
        topCategoryAmount: topCategoryAmount,
      ),
    );
  }

  static int _sumAmount(List<Expense> expenses) {
    return expenses.fold<int>(0, (sum, expense) => sum + expense.amount);
  }

  static List<WeeklyCategorySummary> _buildCategorySummaries(
    List<Expense> expenses,
    int totalExpense,
  ) {
    final categoryMap = <String, int>{};

    for (final expense in expenses) {
      final category = expense.category.trim().isEmpty ? '未分類' : expense.category;
      categoryMap[category] = (categoryMap[category] ?? 0) + expense.amount;
    }

    final summaries = categoryMap.entries
        .map(
          (entry) => WeeklyCategorySummary(
            category: entry.key,
            amount: entry.value,
            ratio: totalExpense > 0 ? entry.value / totalExpense : 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return summaries;
  }

  static String _buildComment({
    required int totalExpense,
    required int previousWeekExpense,
    required double changeRate,
    required String? topCategory,
    required int topCategoryAmount,
  }) {
    final totalText = _formatYen(totalExpense);

    final topCategoryText = topCategory != null
        ? '「$topCategory」が${_formatYen(topCategoryAmount)}で一番多かったよ。'
        : '';

    if (totalExpense == 0) {
      return '「今週はまだ使ってないね。このペース、一緒に作っていこう。」';
    }

    if (previousWeekExpense == 0) {
      return '「今週は$totalText使ったね。$topCategoryText 少しずつ流れをつかんでいこう。」';
    }

    if (changeRate >= 0.2) {
      return '「今週は$totalTextで、先週より少し増えてるね。$topCategoryText 少しだけ気にしてみようか。」';
    }

    if (changeRate <= -0.2) {
      return '「今週は$totalTextで、いい感じに抑えられてるよ。$topCategoryText この調子でいこう。」';
    }

    return '「今週は$totalTextで、先週といいペースだね。$topCategoryText このままいけそう。」';
  }

  static String _buildCommentEn({
    required int totalExpense,
    required int previousWeekExpense,
    required double changeRate,
    required String? topCategory,
    required int topCategoryAmount,
  }) {
    final totalText = _formatDollar(totalExpense);

    final topCategoryText = topCategory != null
        ? '$topCategory was the biggest one at ${_formatDollar(topCategoryAmount)}.'
        : '';

    if (totalExpense == 0) {
      return '“You haven’t spent anything yet this week. Let’s build this pace together.”';
    }

    if (previousWeekExpense == 0) {
      return '“You spent $totalText this week. $topCategoryText Let’s start getting a feel for your flow.”';
    }

    if (changeRate >= 0.2) {
      return '“You spent $totalText this week, a bit more than last week. $topCategoryText Let’s keep a small eye on it.”';
    }

    if (changeRate <= -0.2) {
      return '“You spent $totalText this week, and kept it nicely lower than last week. $topCategoryText Let’s keep this going.”';
    }

    return '“You spent $totalText this week, about the same pace as last week. $topCategoryText Looks steady.”';
  }

  static String _formatYen(int value) {
    return '${value.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        )}円';
  }

  static String _formatDollar(int value) {
    final dollars = value / 100;
    final fixed = dollars.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '\$$whole.${parts[1]}';
  }
}