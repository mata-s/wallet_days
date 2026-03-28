import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';

class RoastContext {
  final List<Expense> expenses;
  final int usedAmount;
  final int totalBudget;
  final Expense latestExpense;

  // 追加: カテゴリ別集計
  final Map<String, int> categoryCountMap;
  final Map<String, int> categoryAmountMap;

  RoastContext({
    required this.expenses,
    required this.usedAmount,
    required this.totalBudget,
    required this.latestExpense,
    required this.categoryCountMap,
    required this.categoryAmountMap,
  });
}

class RoastContextBuilder {
  static Future<RoastContext> build(
    Expense latestExpense, {
    List<Expense>? preFetchedExpenses,
  }) async {
    final expenses = preFetchedExpenses ?? await IsarService.getAllExpenses();

    final budgetSetting = await IsarService.getBudgetSetting();

    final totalBudget = budgetSetting?.totalBudget ?? 0;

    final usedAmount = expenses.fold<int>(
      0,
      (sum, e) => sum + e.amount,
    );

    final Map<String, int> categoryCountMap = {};
    final Map<String, int> categoryAmountMap = {};

    for (final e in expenses) {
      final category = e.category ?? 'その他';

      categoryCountMap[category] = (categoryCountMap[category] ?? 0) + 1;
      categoryAmountMap[category] = (categoryAmountMap[category] ?? 0) + e.amount;
    }

    return RoastContext(
      expenses: expenses,
      usedAmount: usedAmount,
      totalBudget: totalBudget,
      latestExpense: latestExpense,
      categoryCountMap: categoryCountMap,
      categoryAmountMap: categoryAmountMap,
    );
  }
}