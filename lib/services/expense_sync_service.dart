import 'package:flutter/foundation.dart';
import 'package:saiyome/models/expense.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseSyncService {
  static final _client = Supabase.instance.client;

  static String? get _userId => _client.auth.currentUser?.id;

  static void _log(String message) {
    debugPrint('[ExpenseSyncService] $message');
  }

  static String _safeError(Object error) {
    return error.toString();
  }

  static Future<void> syncExpense(Expense expense) async {
    final userId = _userId;
    if (userId == null) {
      _log('syncExpense skipped: userId is null');
      return;
    }


    final row = {
      'user_id': userId,
      'local_id': expense.id,
      'amount': expense.amount,
      'store_name': expense.storeName,
      'category': expense.category,
      'roast_message': expense.roastMessage,
      'created_at': expense.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      _log('syncExpense start: localId=${expense.id}, storeName=${expense.storeName}, amount=${expense.amount}');
      await _client.from('expenses').upsert(
        row,
        onConflict: 'user_id,local_id',
      );
      _log('syncExpense success: localId=${expense.id}');
    } catch (e) {
      _log('syncExpense failed: localId=${expense.id}, error=${_safeError(e)}');
      rethrow;
    }
  }

  static Future<void> syncExpenses(List<Expense> expenses) async {
    final userId = _userId;
    if (userId == null) {
      _log('syncExpenses skipped: userId is null');
      return;
    }

    if (expenses.isEmpty) {
      _log('syncExpenses skipped: expenses is empty');
      return;
    }


    final rows = expenses
        .map(
          (expense) => {
            'user_id': userId,
            'local_id': expense.id,
            'amount': expense.amount,
            'store_name': expense.storeName,
            'category': expense.category,
            'roast_message': expense.roastMessage,
            'created_at': expense.createdAt.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        )
        .toList();

    try {
      _log('syncExpenses start: count=${expenses.length}');
      await _client.from('expenses').upsert(
        rows,
        onConflict: 'user_id,local_id',
      );
      _log('syncExpenses success: count=${expenses.length}');
    } catch (e) {
      _log('syncExpenses failed: count=${expenses.length}, error=${_safeError(e)}');
      rethrow;
    }
  }

  static Future<void> deleteExpense(int expenseId) async {
    final userId = _userId;
    if (userId == null) {
      _log('deleteExpense skipped: userId is null');
      return;
    }

    try {
      _log('deleteExpense start: localId=$expenseId');
      await _client
          .from('expenses')
          .delete()
          .eq('user_id', userId)
          .eq('local_id', expenseId);
      _log('deleteExpense success: localId=$expenseId');
    } catch (e) {
      _log('deleteExpense failed: localId=$expenseId, error=${_safeError(e)}');
      rethrow;
    }
  }
}