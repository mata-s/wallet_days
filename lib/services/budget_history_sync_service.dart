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

  static String _periodDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  static Map<String, dynamic> _rowForHistory(
    BudgetHistory history,
    String userId,
  ) {
    return {
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
  }

  static Future<Map<String, dynamic>?> _findExistingByPeriod(
    String userId,
    BudgetHistory history,
  ) async {
    final start = _periodDate(history.startDate);
    final end = _periodDate(history.endDate);

    final rows = await _client
        .from('budget_histories')
        .select('id, local_id, start_date, end_date')
        .eq('user_id', userId)
        .gte('start_date', '$start 00:00:00')
        .lt('start_date', '$start 23:59:59')
        .gte('end_date', '$end 00:00:00')
        .lt('end_date', '$end 23:59:59')
        .limit(1);

    if (rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first as Map);
    }

    return null;
  }

  static Future<void> syncBudgetHistory(BudgetHistory history) async {
    final userId = _userId;
    if (userId == null) {
      _log('syncBudgetHistory skipped: userId is null');
      return;
    }

    final row = _rowForHistory(history, userId);

    try {
      _log('syncBudgetHistory start: localId=${history.id}');
      final existing = await _findExistingByPeriod(userId, history);

      if (existing != null) {
        await _client
            .from('budget_histories')
            .update(row)
            .eq('id', existing['id']);
        _log(
          'syncBudgetHistory updated existing period: localId=${history.id}, cloudId=${existing['id']}, existingLocalId=${existing['local_id']}',
        );
      } else {
        await _client.from('budget_histories').upsert(
          row,
          onConflict: 'user_id,local_id',
        );
        _log('syncBudgetHistory inserted/upserted: localId=${history.id}');
      }
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

    try {
      _log('syncBudgetHistories start: count=${histories.length}');
      for (final history in histories) {
        final row = _rowForHistory(history, userId);
        final existing = await _findExistingByPeriod(userId, history);

        if (existing != null) {
          await _client
              .from('budget_histories')
              .update(row)
              .eq('id', existing['id']);
          _log(
            'syncBudgetHistories updated existing period: localId=${history.id}, cloudId=${existing['id']}, existingLocalId=${existing['local_id']}',
          );
        } else {
          await _client.from('budget_histories').upsert(
            row,
            onConflict: 'user_id,local_id',
          );
          _log('syncBudgetHistories inserted/upserted: localId=${history.id}');
        }
      }
      _log('syncBudgetHistories success: count=${histories.length}');
    } catch (e) {
      _log('syncBudgetHistories failed: count=${histories.length}, error=${_safeError(e)}');
      rethrow;
    }
  }
}
