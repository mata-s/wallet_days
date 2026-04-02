import 'package:flutter/foundation.dart';
import 'package:saiyome/models/budget_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetHistorySyncService {
  static final _client = Supabase.instance.client;

  static String? get _userId => _client.auth.currentUser?.id;

  static void _log(String message) {
    debugPrint('[BudgetHistorySyncService] $message');
  }

  static String _safeError(Object error) {
    return error.toString();
  }

  static Future<void> syncBudgetHistory(BudgetHistory history) async {
    final userId = _userId;
    if (userId == null) {
      _log('syncBudgetHistory skipped: userId is null');
      return;
    }

    final row = {
      'user_id': userId,
      'local_id': history.id,
      'start_date': history.startDate.toIso8601String(),
      'end_date': history.endDate.toIso8601String(),
      'total_budget': history.totalBudget,
      'total_expense': history.totalExpense,
      'is_achieved': history.isAchieved,
      'streak': history.streak,
      'best_streak': history.bestStreak,
      'created_at': history.createdAt.toIso8601String(),
    };

    try {
      _log('syncBudgetHistory start: localId=${history.id}');
      await _client.from('budget_histories').upsert(
        row,
        onConflict: 'user_id,local_id',
      );
      _log('syncBudgetHistory success: localId=${history.id}');
    } catch (e) {
      _log('syncBudgetHistory failed: localId=${history.id}, error=${_safeError(e)}');
      rethrow;
    }
  }

  static Future<void> syncBudgetHistories(List<BudgetHistory> histories) async {
    final userId = _userId;
    if (userId == null) {
      _log('syncBudgetHistories skipped: userId is null');
      return;
    }

    if (histories.isEmpty) {
      _log('syncBudgetHistories skipped: histories is empty');
      return;
    }


    final rows = histories
        .map(
          (history) => {
            'user_id': userId,
            'local_id': history.id,
            'start_date': history.startDate.toIso8601String(),
            'end_date': history.endDate.toIso8601String(),
            'total_budget': history.totalBudget,
            'total_expense': history.totalExpense,
            'is_achieved': history.isAchieved,
            'streak': history.streak,
            'best_streak': history.bestStreak,
            'created_at': history.createdAt.toIso8601String(),
          },
        )
        .toList();

    try {
      _log('syncBudgetHistories start: count=${histories.length}');
      await _client.from('budget_histories').upsert(
        rows,
        onConflict: 'user_id,local_id',
      );
      _log('syncBudgetHistories success: count=${histories.length}');
    } catch (e) {
      _log('syncBudgetHistories failed: count=${histories.length}, error=${_safeError(e)}');
      rethrow;
    }
  }
}
