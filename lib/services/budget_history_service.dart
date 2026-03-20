import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/services/rank_service.dart';

class BudgetHistoryService {
  static Future<void> syncIfNeeded({
    required int cycleStartDay,
    required int totalBudget,
  }) async {
    final safeStartDay = cycleStartDay.clamp(1, 28);
    final now = DateTime.now();

    final currentCycleStart = _currentCycleStart(now, safeStartDay);
    final previousCycleStart = DateTime(
      currentCycleStart.year,
      currentCycleStart.month - 1,
      safeStartDay,
    );
    final previousCycleEnd = currentCycleStart;

    final existing = await IsarService.getBudgetHistoryByPeriod(
      previousCycleStart,
      previousCycleEnd,
    );
    if (existing != null) return;

    final expenses = await IsarService.getExpenses();
    final previousExpenses = expenses.where((expense) {
      return !expense.createdAt.isBefore(previousCycleStart) &&
          expense.createdAt.isBefore(previousCycleEnd);
    }).toList();

    if (previousExpenses.isEmpty) return;

    final totalExpense = previousExpenses.fold<int>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    final histories = await IsarService.getBudgetHistories();
    final isAchieved = totalExpense <= totalBudget;

    final history = BudgetHistory()
      ..startDate = previousCycleStart
      ..endDate = previousCycleEnd
      ..totalBudget = totalBudget
      ..totalExpense = totalExpense
      ..isAchieved = isAchieved
      ..streak = RankService.calculateNextStreak(histories, isAchieved)
      ..createdAt = DateTime.now();

    await IsarService.saveBudgetHistory(history);
  }

  static DateTime currentCycleStart({
    required DateTime now,
    required int cycleStartDay,
  }) {
    final safeStartDay = cycleStartDay.clamp(1, 28);
    return _currentCycleStart(now, safeStartDay);
  }

  static DateTime _currentCycleStart(DateTime now, int cycleStartDay) {
    if (now.day >= cycleStartDay) {
      return DateTime(now.year, now.month, cycleStartDay);
    }
    return DateTime(now.year, now.month - 1, cycleStartDay);
  }

  static List<Expense> filterExpensesForPeriod({
    required List<Expense> expenses,
    required DateTime start,
    required DateTime end,
  }) {
    return expenses.where((expense) {
      return !expense.createdAt.isBefore(start) &&
          expense.createdAt.isBefore(end);
    }).toList();
  }
}