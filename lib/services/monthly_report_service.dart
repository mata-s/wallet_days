import 'package:supabase_flutter/supabase_flutter.dart';

class MonthlyReportResult {
  final Map<String, dynamic> report;
  final bool created;

  const MonthlyReportResult({
    required this.report,
    required this.created,
  });
}

class MonthlyReportService {
  static final _client = Supabase.instance.client;

  static String? get _userId => _client.auth.currentUser?.id;

  static Future<void> _ensurePremiumUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('ログイン情報が見つかりません。');
    }

    final profile = await _client
        .from('profiles')
        .select('is_premium_cached')
        .eq('id', user.id)
        .maybeSingle();

    final isPremium = (profile?['is_premium_cached'] as bool?) ?? false;
    if (!isPremium) {
      throw Exception('この機能はプレミアム限定です。');
    }
  }

  static Future<Map<String, dynamic>?> getReportForPeriod({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('ログイン情報が見つかりません。');
    }
    final result = await _client
        .from('monthly_reports')
        .select()
        .eq('user_id', userId)
        .eq('period_start', _dateKey(periodStart))
        .eq('period_end', _dateKey(periodEnd))
        .maybeSingle();

    if (result == null) return null;
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> shouldGenerateReport({
    required DateTime now,
    required DateTime periodEnd,
    required int cycleStartDay,
  }) async {
    await _ensurePremiumUser();

    if (!now.isAfter(periodEnd)) return false;

    final existing = await getReportForPeriod(
      periodStart: periodStartFromEnd(periodEnd, cycleStartDay),
      periodEnd: periodEnd,
    );

    return existing == null;
  }

  static Future<MonthlyReportResult> getOrCreateReport({
    required DateTime periodStart,
    required DateTime periodEnd,
    bool useAi = true,
  }) async {
    await _ensurePremiumUser();

    final existing = await getReportForPeriod(
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    if (existing != null) {
      return MonthlyReportResult(report: existing, created: false);
    }

    final payload = {
      'user_id': _userId,
      'period_start': _dateKey(periodStart),
      'period_end': _dateKey(periodEnd),
      'use_ai': useAi,
    };

    final response = await _client.functions.invoke(
      'generate-monthly-report',
      body: payload,
    );

    if (response.status != 200 && response.status != 201) {
      throw Exception('月次レポートの生成に失敗しました。');
    }

    if (response.data is Map<String, dynamic>) {
      return MonthlyReportResult(
        report: Map<String, dynamic>.from(response.data as Map),
        created: true,
      );
    }

    final createdReport = await getReportForPeriod(
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    if (createdReport == null) {
      throw Exception('月次レポートの保存確認に失敗しました。');
    }

    return MonthlyReportResult(report: createdReport, created: true);
  }

  static Future<void> autoGenerateIfNeeded({
    required DateTime now,
    required DateTime currentCycleStart,
    required int cycleStartDay,
  }) async {
    final previousEnd = currentCycleStart.subtract(const Duration(days: 1));

    final previousStart = periodStartFromEnd(previousEnd, cycleStartDay);

    final should = await shouldGenerateReport(
      now: now,
      periodEnd: previousEnd,
      cycleStartDay: cycleStartDay,
    );

    if (!should) return;

    await getOrCreateReport(
      periodStart: previousStart,
      periodEnd: previousEnd,
    );
  }
  static DateTime periodStartFromEnd(DateTime periodEnd, int cycleStartDay) {
    final safeStartDay = cycleStartDay.clamp(1, 28);
    final nextCycleStart = DateTime(
      periodEnd.year,
      periodEnd.month,
      periodEnd.day + 1,
    );

    return DateTime(
      nextCycleStart.year,
      nextCycleStart.month - 1,
      safeStartDay,
    );
  }

  static String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }
}
