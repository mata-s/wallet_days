import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/income_fixed_cost_setting.dart';
import 'package:saiyome/models/isar_service.dart';

class AccountDataSyncResult {
  final int expenseCount;
  final int historyCount;
  final bool hasBudgetSetting;
  final bool hasIncomeFixedCostSetting;

  const AccountDataSyncResult({
    required this.expenseCount,
    required this.historyCount,
    required this.hasBudgetSetting,
    required this.hasIncomeFixedCostSetting,
  });
}

class AccountDataSyncService {
  static final _client = Supabase.instance.client;

  static Future<AccountDataSyncResult> syncFromCloudToLocal() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('ログインユーザーが見つかりません');
    }

    final userId = user.id;
    debugPrint('[AccountDataSyncService] sync start: userId=$userId');

    final expenseRows = await _client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .order('created_at');

    final budgetSettingRow = await _client
        .from('budget_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    final incomeFixedCostRow = await _client
        .from('income_fixed_cost_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    final historyRows = await _client
        .from('budget_histories')
        .select()
        .eq('user_id', userId)
        .order('end_date');

    debugPrint(
      '[AccountDataSyncService] fetched: '
      'expenses=${expenseRows.length}, '
      'histories=${historyRows.length}, '
      'hasBudgetSetting=${budgetSettingRow != null}, '
      'hasIncomeFixedCostSetting=${incomeFixedCostRow != null}',
    );

    final expenses = _mapExpenses(expenseRows);
    final budgetSetting = _mapBudgetSetting(budgetSettingRow);
    final incomeFixedCostSetting =
        _mapIncomeFixedCostSetting(incomeFixedCostRow);
    final histories = _mapBudgetHistories(historyRows);

    await IsarService.replaceAllData(
      expenses: expenses,
      budgetSetting: budgetSetting,
      incomeFixedCostSetting: incomeFixedCostSetting,
      budgetHistories: histories,
    );

    debugPrint(
      '[AccountDataSyncService] sync success: '
      'expenses=${expenses.length}, '
      'histories=${histories.length}',
    );

    return AccountDataSyncResult(
      expenseCount: expenses.length,
      historyCount: histories.length,
      hasBudgetSetting: budgetSetting != null,
      hasIncomeFixedCostSetting: incomeFixedCostSetting != null,
    );
  }

  static List<Expense> _mapExpenses(dynamic rows) {
    if (rows is! List) return [];

    return rows
        .whereType<Map>()
        .map((row) {
          final map = Map<String, dynamic>.from(row);

          final expense = Expense()
            ..id = (map['local_id'] as num?)?.toInt() ?? 0
            ..amount = (map['amount'] as num?)?.toInt() ?? 0
            ..storeName = map['store_name']?.toString() ?? ''
            ..category = map['category']?.toString() ?? ''
            ..roastMessage = map['roast_message']?.toString() ?? ''
            ..createdAt =
                DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                    DateTime.now();

          return expense;
        })
        .toList();
  }

  static BudgetSetting? _mapBudgetSetting(dynamic row) {
    if (row == null || row is! Map) return null;

    final map = Map<String, dynamic>.from(row);

    final setting = BudgetSetting()
      ..totalBudget = (map['total_budget'] as num?)?.toInt() ?? 0
      ..cycleStartDay = (map['cycle_start_day'] as num?)?.toInt() ?? 1
      ..useCategoryBudget = (map['use_category_budget'] as bool?) ?? false
      ..updatedAt = DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now();

    final categories = map['categories_json'];
    if (categories is List) {
      setting.categories = categories
          .whereType<Map>()
          .map((item) {
            final c = Map<String, dynamic>.from(item);
            return BudgetCategory()
              ..name = c['name']?.toString() ?? ''
              ..badge = c['badge']?.toString() ?? ''
              ..budget = (c['budget'] as num?)?.toInt() ?? 0;
          })
          .toList();
    } else {
      setting.categories = [];
    }

    return setting;
  }

  static IncomeFixedCostSetting? _mapIncomeFixedCostSetting(dynamic row) {
    if (row == null || row is! Map) return null;

    final map = Map<String, dynamic>.from(row);

    final setting = IncomeFixedCostSetting()
      ..income = (map['monthly_income'] as num?)?.toInt() ?? 0
      ..fixedCostTotal = (map['fixed_cost_total'] as num?)?.toInt() ?? 0;

    final itemsJson = map['fixed_cost_items_json'];
    if (itemsJson is List) {
      setting.items = itemsJson
          .whereType<Map>()
          .map((item) {
            final m = Map<String, dynamic>.from(item);
            return IncomeFixedCostItem()
              ..name = m['title']?.toString() ?? ''
              ..amount = (m['amount'] as num?)?.toInt() ?? 0;
          })
          .toList();
    } else {
      setting.items = <IncomeFixedCostItem>[];
    }

    return setting;
  }

  static List<BudgetHistory> _mapBudgetHistories(dynamic rows) {
    if (rows is! List) return [];

    return rows
        .whereType<Map>()
        .map((row) {
          final map = Map<String, dynamic>.from(row);

          final history = BudgetHistory()
            ..id = (map['local_id'] as num?)?.toInt() ?? 0
            ..startDate =
                DateTime.tryParse(map['start_date']?.toString() ?? '') ??
                    DateTime.now()
            ..endDate = DateTime.tryParse(map['end_date']?.toString() ?? '') ??
                DateTime.now()
            ..totalBudget = (map['total_budget'] as num?)?.toInt() ?? 0
            ..totalExpense = (map['total_expense'] as num?)?.toInt() ?? 0
            ..isAchieved = (map['is_achieved'] as bool?) ?? false
            ..streak = (map['streak'] as num?)?.toInt() ?? 0
            ..createdAt =
                DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                    DateTime.now();

          return history;
        })
        .toList();
  }
}