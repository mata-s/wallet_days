import 'dart:math' as math;
import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/services/budget_history_sync_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class BudgetHistoryService {
  static Future<BudgetHistory?> _findPreviousHistory(BudgetHistory current) async {
    final histories = await IsarService.getBudgetHistories();

    final previousCandidates = histories.where((history) {
      return history.endDate.isBefore(current.startDate);
    }).toList();

    if (previousCandidates.isEmpty) return null;

    previousCandidates.sort((a, b) => b.endDate.compareTo(a.endDate));
    return previousCandidates.first;
  }

  static Future<void> _finalizeHistory(BudgetHistory history) async {
    history.isAchieved = history.totalBudget > 0
        ? history.totalExpense <= history.totalBudget
        : false;

    final previousHistory = await _findPreviousHistory(history);

    if (history.isAchieved) {
      history.streak = (previousHistory?.streak ?? 0) + 1;
    } else {
      history.streak = 0;
    }

    history.bestStreak = math.max(
      history.streak,
      previousHistory?.bestStreak ?? 0,
    );

    await IsarService.saveBudgetHistory(history);
  }

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

    final history = existing ?? BudgetHistory()
      ..startDate = previousCycleStart
      ..endDate = previousCycleEnd
      ..totalBudget = totalBudget
      ..totalExpense = totalExpense
      ..createdAt = existing?.createdAt ?? DateTime.now();

    await _finalizeHistory(history);
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