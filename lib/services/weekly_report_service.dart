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
    if (totalExpense == 0) {
      return '今週はまだ支出が記録されていません。無理のないペースで続けていきましょう。';
    }

    final topCategoryText = topCategory != null
        ? '特に「$topCategory」が${_formatYen(topCategoryAmount)}と多めでした。'
        : '';

    if (previousWeekExpense == 0) {
      return '今週は${_formatYen(totalExpense)}の支出でした。$topCategoryText';
    }

    if (changeRate >= 0.2) {
      return '先週より支出が増えています。今週は${_formatYen(totalExpense)}でした。$topCategoryText';
    }

    if (changeRate <= -0.2) {
      return '先週よりいいペースで抑えられています。今週は${_formatYen(totalExpense)}でした。$topCategoryText';
    }

    return '先週と近いペースで使えています。今週は${_formatYen(totalExpense)}でした。$topCategoryText';
  }

  static String _formatYen(int value) {
    return '${value.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        )}円';
  }
}