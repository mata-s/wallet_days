import 'package:isar/isar.dart';

part 'expense.g.dart';

@collection
class Expense {
  Id id = Isar.autoIncrement;

  late int amount;
  late String storeName;
  late String category;
  late DateTime createdAt;

  String? roastMessage;
  DateTime? futureLogDate;
  String? futureLogMessage;
}

@embedded
class BudgetCategory {
  late String name;
  late int budget;
  late String badge;
}

@collection
class BudgetSetting {
  Id id = Isar.autoIncrement;

  late int totalBudget;
  late bool useCategoryBudget;
  late int cycleStartDay;
  int? pendingCycleStartDay;
  int? currentBudgetHistoryLocalId;
  late DateTime updatedAt;
  List<BudgetCategory> categories = [];
}