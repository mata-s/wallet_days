import 'package:isar/isar.dart';

part 'budget_history.g.dart';

@collection
class BudgetHistory {
  Id id = Isar.autoIncrement;

  late DateTime startDate;
  late DateTime endDate;

  // 設定していた予算
  late int totalBudget;

  // 実際に使った金額
  late int totalExpense;

  // 達成したか（予算内か）
  late bool isAchieved;

  // 何ヶ月連続か（保存しておくと便利）
  int streak = 0;

  // 作成日時
  late DateTime createdAt;
}
