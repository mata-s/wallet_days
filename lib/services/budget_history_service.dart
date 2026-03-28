import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/services/rank_service.dart';
import 'package:saiyome/services/budget_history_sync_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class BudgetHistoryService {
  static Future<void> syncIfNeeded({
    required int cycleStartDay,
    required int totalBudget,
  }) async {
    print('[BudgetHistoryService] syncIfNeeded start');
    final safeStartDay = cycleStartDay.clamp(1, 28);
    final now = DateTime.now();

    final currentCycleStart = _currentCycleStart(now, safeStartDay);
    final previousCycleStart = DateTime(
      currentCycleStart.year,
      currentCycleStart.month - 1,
      safeStartDay,
    );
    final previousCycleEnd = currentCycleStart;
    print('[BudgetHistoryService] period=$previousCycleStart ~ $previousCycleEnd');

    final existing = await IsarService.getBudgetHistoryByPeriod(
      previousCycleStart,
      previousCycleEnd,
    );
    print('[BudgetHistoryService] existing=${existing != null}');
    if (existing != null) return;

    final expenses = await IsarService.getExpenses();
    print('[BudgetHistoryService] allExpenses=${expenses.length}');
    if (expenses.isEmpty) {
      print('[BudgetHistoryService] skip: no expenses yet');
      return;
    }

    final firstExpenseDate = expenses
        .map((expense) => expense.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    print('[BudgetHistoryService] firstExpenseDate=$firstExpenseDate');

    if (!firstExpenseDate.isBefore(previousCycleEnd)) {
      print('[BudgetHistoryService] skip: user had not started using the app in this period');
      return;
    }

    final previousExpenses = expenses.where((expense) {
      return !expense.createdAt.isBefore(previousCycleStart) &&
          expense.createdAt.isBefore(previousCycleEnd);
    }).toList();
    print('[BudgetHistoryService] previousExpenses=${previousExpenses.length}');
    // Allow zero-expense periods to still generate a history (totalExpense will be 0)

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
    print('[BudgetHistoryService] save local history');

    final isPremium = await _isPremiumUser();
    print('[BudgetHistoryService] isPremium=$isPremium');
    if (isPremium) {
      print('[BudgetHistoryService] sync start');
      await BudgetHistorySyncService.syncBudgetHistory(history);
      print('[BudgetHistoryService] sync done');
    }
  }

  static Future<bool> _isPremiumUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
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