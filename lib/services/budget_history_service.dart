import 'dart:math' as math;
import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/services/budget_history_sync_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:saiyome/utils/time_provider.dart';
import 'package:saiyome/services/budget_setting_sync_service.dart';

class BudgetHistoryService {
  static Future<BudgetHistory?> _findPreviousHistory(BudgetHistory current) async {
    final histories = await IsarService.getBudgetHistories();

    final previousCandidates = histories.where((history) {
      return history.endDate.isBefore(current.startDate) ||
          history.endDate.isAtSameMomentAs(current.startDate);
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

  final budgetSetting = await IsarService.getBudgetSetting();
  if (budgetSetting == null) {
    print('[BudgetHistoryService] skip: no budget setting');
    return;
  }

  final currentHistoryId = budgetSetting.currentBudgetHistoryLocalId;
  if (currentHistoryId == null) {
    print('[BudgetHistoryService] skip: no currentBudgetHistoryLocalId');
    return;
  }

  final currentHistory = await IsarService.getBudgetHistoryById(currentHistoryId);
  if (currentHistory == null) {
    print('[BudgetHistoryService] skip: current history not found');
    return;
  }

  final now = getNow();
  print(
    '[BudgetHistoryService] current history '
    'id=${currentHistory.id} '
    'start=${currentHistory.startDate} '
    'end=${currentHistory.endDate}',
  );

  if (now.isBefore(currentHistory.endDate)) {
    print('[BudgetHistoryService] skip: current period not finished yet');
    return;
  }

  final expenses = await IsarService.getExpenses();

  final currentPeriodExpenses = expenses.where((expense) {
    return !expense.createdAt.isBefore(currentHistory.startDate) &&
        expense.createdAt.isBefore(currentHistory.endDate);
  }).toList();

  final currentTotalExpense = currentPeriodExpenses.fold<int>(
    0,
    (sum, expense) => sum + expense.amount,
  );

  currentHistory
    ..totalBudget = currentHistory.totalBudget
    ..totalExpense = currentTotalExpense;

  await _finalizeHistory(currentHistory);
  await IsarService.saveBudgetHistory(currentHistory);
  print('[BudgetHistoryService] finalized history id=${currentHistory.id}');

  final nextStart = currentHistory.endDate;
  final nextEnd = DateTime(nextStart.year, nextStart.month + 1, nextStart.day);

  final nextPeriodExpenses = expenses.where((expense) {
    return !expense.createdAt.isBefore(nextStart) &&
        expense.createdAt.isBefore(nextEnd);
  }).toList();

  final nextTotalExpense = nextPeriodExpenses.fold<int>(
    0,
    (sum, expense) => sum + expense.amount,
  );

  final nextHistory = BudgetHistory()
    ..startDate = nextStart
    ..endDate = nextEnd
    ..totalBudget = budgetSetting.totalBudget
    ..totalExpense = nextTotalExpense
    ..isAchieved = nextTotalExpense <= budgetSetting.totalBudget
    ..streak = currentHistory.streak
    ..bestStreak = currentHistory.bestStreak
    ..createdAt = now;

  await IsarService.saveBudgetHistory(nextHistory);
  print(
    '[BudgetHistoryService] created next history '
    'id=${nextHistory.id} start=$nextStart end=$nextEnd',
  );

  budgetSetting
    ..currentBudgetHistoryLocalId = nextHistory.id
    ..updatedAt = now;
  await IsarService.saveBudgetSetting(budgetSetting);

  final isPremium = await _isPremiumUser();
  if (isPremium) {
    print('[BudgetHistoryService] sync start');
    await BudgetHistorySyncService.syncBudgetHistory(currentHistory);
    await BudgetHistorySyncService.syncBudgetHistory(nextHistory);
    await BudgetSettingSyncService.syncBudgetSetting(budgetSetting);
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