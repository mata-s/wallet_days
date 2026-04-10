import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/income_fixed_cost_setting.dart';
import 'package:saiyome/models/budget_history.dart';


class IsarService {
  static late Isar isar;

  static Future<void> init() async {
    if (Isar.instanceNames.isNotEmpty) {
      isar = Isar.getInstance()!;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();

    isar = await Isar.open(
      [ExpenseSchema, BudgetSettingSchema, IncomeFixedCostSettingSchema, BudgetHistorySchema],
      directory: dir.path,
    );
  }

  static Future<void> _recalculateBudgetHistoryForDate(DateTime targetDate) async {
    final histories = await isar.budgetHistorys.where().findAll();

    BudgetHistory? matchedHistory;
    for (final history in histories) {
      final isInRange =
          !targetDate.isBefore(history.startDate) && !targetDate.isAfter(history.endDate);
      if (isInRange) {
        matchedHistory = history;
        break;
      }
    }

    if (matchedHistory == null) return;

    final expenses = await isar.expenses.where().findAll();
    final totalExpense = expenses
        .where(
          (expense) =>
              !expense.createdAt.isBefore(matchedHistory!.startDate) &&
              !expense.createdAt.isAfter(matchedHistory.endDate),
        )
        .fold<int>(0, (sum, expense) => sum + expense.amount.toInt());

    matchedHistory.totalExpense = totalExpense;
    matchedHistory.isAchieved = matchedHistory.totalBudget > 0
        ? totalExpense <= matchedHistory.totalBudget
        : false;

    await isar.writeTxn(() async {
      await isar.budgetHistorys.put(matchedHistory!);
    });
  }

  static Future<void> _recalculateBudgetHistoryForDateRange(
    DateTime? previousDate,
    DateTime currentDate,
  ) async {
    if (previousDate != null) {
      await _recalculateBudgetHistoryForDate(previousDate);
    }
    await _recalculateBudgetHistoryForDate(currentDate);
  }

  static Future<void> saveExpense(Expense expense) async {
    DateTime? previousCreatedAt;
    if (expense.id != Isar.autoIncrement) {
      final existing = await isar.expenses.get(expense.id);
      previousCreatedAt = existing?.createdAt;
    }

    await isar.writeTxn(() async {
      await isar.expenses.put(expense);
    });

    await _recalculateBudgetHistoryForDateRange(previousCreatedAt, expense.createdAt);
  }

  static Future<void> deleteExpense(int id) async {
    final existing = await isar.expenses.get(id);

    await isar.writeTxn(() async {
      await isar.expenses.delete(id);
    });

    if (existing != null) {
      await _recalculateBudgetHistoryForDate(existing.createdAt);
    }
  }

static Future<Expense?> getExpenseById(int id) async {
  return await isar.expenses.get(id);
}

  static Future<List<Expense>> getExpenses() async {
    return isar.expenses.where().sortByCreatedAtDesc().findAll();
  }

  static Future<void> saveBudgetSetting(BudgetSetting budgetSetting) async {
    final existing = await getBudgetSetting();

    // 既存の currentBudgetHistoryLocalId を保持（新しい値が null の場合）
    if (budgetSetting.currentBudgetHistoryLocalId == null &&
        existing?.currentBudgetHistoryLocalId != null) {
      budgetSetting.currentBudgetHistoryLocalId =
          existing!.currentBudgetHistoryLocalId;
    }

    print('[IsarService] saveBudgetSetting '
        'currentBudgetHistoryLocalId=${budgetSetting.currentBudgetHistoryLocalId}');

    await isar.writeTxn(() async {
      await isar.budgetSettings.clear();
      await isar.budgetSettings.put(budgetSetting);
    });

    final reloaded = await getBudgetSetting();
    print('[IsarService] reloaded currentBudgetHistoryLocalId=${reloaded?.currentBudgetHistoryLocalId}');
  }

  static Future<BudgetSetting?> getBudgetSetting() async {
    return isar.budgetSettings.where().findFirst();
  }
  static Future<IncomeFixedCostSetting?> getIncomeFixedCostSetting() async {
    return isar.incomeFixedCostSettings.where().findFirst();
  }

  static Future<void> saveIncomeFixedCostSetting({
    required int income,
    required int fixedCostTotal,
    required List<Map<String, dynamic>> items,
  }) async {
    final setting = IncomeFixedCostSetting()
      ..id = 1
      ..income = income
      ..fixedCostTotal = fixedCostTotal
      ..updatedAt = DateTime.now();

    setting.items = items
        .map(
          (item) => IncomeFixedCostItem()
            ..name = (item['name'] as String?) ?? ''
            ..amount = (item['amount'] as int?) ?? 0,
        )
        .toList();

    await isar.writeTxn(() async {
      await isar.incomeFixedCostSettings.put(setting);
    });
  }

  static Future<BudgetHistory?> getBudgetHistoryByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final all = await isar.budgetHistorys.where().findAll();

    for (final item in all) {
      final sameStart =
          item.startDate.year == startDate.year &&
          item.startDate.month == startDate.month &&
          item.startDate.day == startDate.day;
      final sameEnd =
          item.endDate.year == endDate.year &&
          item.endDate.month == endDate.month &&
          item.endDate.day == endDate.day;

      if (sameStart && sameEnd) {
        return item;
      }
    }

    return null;
  }

  static Future<List<BudgetHistory>> getBudgetHistories() async {
    return isar.budgetHistorys.where().sortByEndDateDesc().findAll();
  }

  static Future<void> saveBudgetHistory(BudgetHistory history) async {
    await isar.writeTxn(() async {
      await isar.budgetHistorys.put(history);
    });
  }

  static Future<BudgetHistory?> getBudgetHistoryById(int id) async {
  return await isar.budgetHistorys.get(id);
}

  static Future<void> deleteBudgetHistoriesByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    await isar.writeTxn(() async {
      await isar.budgetHistorys.deleteAll(ids);
    });
  }

  static Future<void> replaceAllData({
    required List<Expense> expenses,
    required BudgetSetting? budgetSetting,
    required IncomeFixedCostSetting? incomeFixedCostSetting,
    required List<BudgetHistory> budgetHistories,
  }) async {
    await isar.writeTxn(() async {
      await isar.expenses.clear();
      await isar.budgetSettings.clear();
      await isar.incomeFixedCostSettings.clear();
      await isar.budgetHistorys.clear();

      if (expenses.isNotEmpty) {
        await isar.expenses.putAll(expenses);
      }

      if (budgetSetting != null) {
        await isar.budgetSettings.put(budgetSetting);
      }

      if (incomeFixedCostSetting != null) {
        await isar.incomeFixedCostSettings.put(incomeFixedCostSetting);
      }

      if (budgetHistories.isNotEmpty) {
        await isar.budgetHistorys.putAll(budgetHistories);
      }
    });
  }
}