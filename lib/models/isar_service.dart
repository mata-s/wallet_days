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

  static Future<void> saveExpense(Expense expense) async {
    await isar.writeTxn(() async {
      await isar.expenses.put(expense);
    });
  }

  static Future<void> deleteExpense(int id) async {
  await isar.writeTxn(() async {
    await isar.expenses.delete(id);
  });
}

static Future<Expense?> getExpenseById(int id) async {
  return await isar.expenses.get(id);
}

  static Future<List<Expense>> getExpenses() async {
    return isar.expenses.where().sortByCreatedAtDesc().findAll();
  }

  static Future<void> saveBudgetSetting(BudgetSetting budgetSetting) async {
    await isar.writeTxn(() async {
      await isar.budgetSettings.clear();
      await isar.budgetSettings.put(budgetSetting);
    });
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