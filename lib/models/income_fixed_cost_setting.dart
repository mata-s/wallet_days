import 'package:isar/isar.dart';

part 'income_fixed_cost_setting.g.dart';

@collection
class IncomeFixedCostSetting {
  Id id = 1;

  int income = 0;
  int fixedCostTotal = 0;
  DateTime updatedAt = DateTime.now();

  List<IncomeFixedCostItem> items = [];
}

@embedded
class IncomeFixedCostItem {
  String name = '';
  int amount = 0;
}