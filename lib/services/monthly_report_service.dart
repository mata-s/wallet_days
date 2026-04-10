import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:saiyome/utils/time_provider.dart';
import 'package:saiyome/models/isar_service.dart';

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

  static Future<Map<String, dynamic>?> getReportForHistoryLocalId({
    required int localId,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('ログイン情報が見つかりません。');
    }

    final result = await _client
        .from('monthly_reports')
        .select()
        .eq('user_id', userId)
        .eq('budget_history_local_id', localId)
        .maybeSingle();

    if (result == null) return null;
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> shouldGenerateReport({
    required DateTime now,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    await _ensurePremiumUser();

    print('[MonthlyReportService] shouldGenerateReport now=$now periodEnd=$periodEnd');
    if (!now.isAfter(periodEnd)) return false;

    final existing = await getReportForPeriod(
      periodStart: periodStart,
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

  static Future<MonthlyReportResult> getOrCreateReportByLocalId({
    required int localId,
    bool useAi = true,
  }) async {
    await _ensurePremiumUser();

    final existing = await getReportForHistoryLocalId(localId: localId);
    if (existing != null) {
      return MonthlyReportResult(report: existing, created: false);
    }

    final payload = {
      'user_id': _userId,
      'budget_history_local_id': localId,
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

    final createdReport = await getReportForHistoryLocalId(localId: localId);
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
    final effectiveNow = getNow();

    final setting = await IsarService.getBudgetSetting();
    final currentId = setting?.currentBudgetHistoryLocalId;

    if (currentId == null) {
      print('[MonthlyReportService] skip: no currentBudgetHistoryLocalId');
      return;
    }

    final currentHistory = await IsarService.getBudgetHistoryById(currentId);
    if (currentHistory == null) {
      print('[MonthlyReportService] skip: current history not found');
      return;
    }

    final histories = await IsarService.getBudgetHistories();
    final sorted = [...histories]..sort((a, b) => a.startDate.compareTo(b.startDate));
    final currentIndex = sorted.indexWhere((h) => h.id == currentId);

    print('[MonthlyReportService] autoGenerateIfNeeded '
        'now=$effectiveNow currentId=$currentId currentIndex=$currentIndex '
        'currentStart=${currentHistory.startDate} currentEnd=${currentHistory.endDate}');

    if (currentIndex <= 0) {
      print('[MonthlyReportService] skip: no previous history');
      return;
    }

    final previousHistory = sorted[currentIndex - 1];

    // 前月レポートは、current history が始まっている時点で生成対象になる
    if (effectiveNow.isBefore(currentHistory.startDate)) {
      print('[MonthlyReportService] skip: current period has not started yet');
      return;
    }

    final existing = await getReportForHistoryLocalId(localId: previousHistory.id);
    if (existing != null) {
      print('[MonthlyReportService] skip: report already exists for localId=${previousHistory.id}');
      return;
    }

    print('[MonthlyReportService] generate report for previous history '
        'localId=${previousHistory.id} '
        'start=${previousHistory.startDate} end=${previousHistory.endDate}');

    await getOrCreateReportByLocalId(localId: previousHistory.id);
  }

  static String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }
}
