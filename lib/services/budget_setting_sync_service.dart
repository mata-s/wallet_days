import 'package:flutter/foundation.dart';
import 'package:saiyome/models/expense.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetSettingSyncService {
  static final _client = Supabase.instance.client;

  static String? get _userId => _client.auth.currentUser?.id;

  static void _log(String message) {
    debugPrint('[BudgetSettingSyncService] $message');
  }

  static String _safeError(Object error) {
    return error.toString();
  }

  static Future<void> syncBudgetSetting(BudgetSetting setting) async {
    final userId = _userId;
    if (userId == null) {
      _log('syncBudgetSetting skipped: userId is null');
      return;
    }

    final categoriesJson = setting.categories
        .map(
          (category) => {
            'name': category.name,
            'badge': category.badge,
            'budget': category.budget,
          },
        )
        .toList();

    final row = {
      'user_id': userId,
      'total_budget': setting.totalBudget,
      'cycle_start_day': setting.cycleStartDay,
      'use_category_budget': setting.useCategoryBudget,
      'current_budget_history_local_id': setting.currentBudgetHistoryLocalId,
      'categories_json': categoriesJson,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      _log('syncBudgetSetting start: totalBudget=${setting.totalBudget}, categories=${setting.categories.length}');
      await _client.from('budget_settings').upsert(
        row,
        onConflict: 'user_id',
      );
      _log('syncBudgetSetting success');
    } catch (e) {
      _log('syncBudgetSetting failed: error=${_safeError(e)}');
      rethrow;
    }
  }
}