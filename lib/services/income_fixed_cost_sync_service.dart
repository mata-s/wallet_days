import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomeFixedCostSyncService {
  static final _client = Supabase.instance.client;

  static String? get _userId => _client.auth.currentUser?.id;

  static void _log(String message) {
    debugPrint('[IncomeFixedCostSyncService] $message');
  }

  static String _safeError(Object error) {
    return error.toString();
  }

  static Future<void> sync({
    required int monthlyIncome,
    required int fixedCostTotal,
    required List<Map<String, dynamic>> items,
  }) async {
    final userId = _userId;
    if (userId == null) {
      _log('sync skipped: userId is null');
      return;
    }


    final row = {
      'user_id': userId,
      'monthly_income': monthlyIncome,
      'fixed_cost_total': fixedCostTotal,
      'fixed_cost_items_json': items,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      _log('sync start: monthlyIncome=$monthlyIncome, fixedCostTotal=$fixedCostTotal, items=${items.length}');
      await _client.from('income_fixed_cost_settings').upsert(
        row,
        onConflict: 'user_id',
      );
      _log('sync success');
    } catch (e) {
      _log('sync failed: error=${_safeError(e)}');
      rethrow;
    }
  }
}