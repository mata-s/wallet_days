import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/services/weekly_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportPage extends StatefulWidget {
  final List<Expense> expenses;

  const ReportPage({
    super.key,
    required this.expenses,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String? _languageOverride; // 'ja' or 'en'

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _languageOverride = prefs.getString('app_language');
    });
  }

  String _currentLang() {
    if (_languageOverride != null) return _languageOverride!;
    final device = Localizations.localeOf(context).languageCode;
    return device == 'ja' ? 'ja' : 'en';
  }

  String _t(String ja, String en) {
    return _currentLang() == 'ja' ? ja : en;
  }

  String _formatMoney(int amount) {
    if (_currentLang() == 'ja') {
      return '¥${NumberFormat('#,###').format(amount)}';
    }
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount / 100);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = _startOfWeek(now);
    final end = start.add(const Duration(days: 6));
    final report = WeeklyReportService.generate(
      expenses: widget.expenses,
      start: start,
      end: end,
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('今週のまとめ', 'Weekly summary')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('今週のふりかえり', 'This week review'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatDate(start)} 〜 ${_formatDate(end)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEDEDED)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('今週の支出', 'This week spending'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatMoney(report.totalExpense),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _t('先週との差', 'Difference from last week'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDifference(report.differenceFromPreviousWeek),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: report.differenceFromPreviousWeek > 0
                              ? Colors.red
                              : (report.differenceFromPreviousWeek < 0
                                  ? Colors.green
                                  : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Image.asset(
                        'assets/images/usually.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _t('財布のひとこと', 'Wallet says'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _currentLang() == 'ja' ? report.comment : report.commentEn,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('よく使ったカテゴリ', 'Top categories'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                if (report.categories.isEmpty)
                  Text(
                    _t('今週はまだ支出データがありません。', 'No spending data yet this week'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  )
                else
                  ...report.categories.take(3).map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.category,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(category.ratio * 100).toStringAsFixed(0)}%',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatMoney(category.amount),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('先週との比較', 'Comparison with last week'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _ComparisonRow(
                  label: _t('今週', 'This week'),
                  value: _formatMoney(report.totalExpense),
                ),
                const SizedBox(height: 10),
                _ComparisonRow(
                  label: _t('先週', 'Last week'),
                  value: _formatMoney(report.previousWeekExpense),
                ),
                const SizedBox(height: 10),
                _ComparisonRow(
                  label: _t('前週比', 'Week over week'),
                  value: _formatChangeRate(report.changeRate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final diff = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: diff));
  }

  String _formatDate(DateTime date) {
    return DateFormat('M/d').format(date);
  }

  String _formatDifference(int value) {
    if (value > 0) {
      return '+${_formatMoney(value)}';
    }
    if (value < 0) {
      return '-${_formatMoney(value.abs())}';
    }
    return _currentLang() == 'ja' ? '±¥0' : '\$0.00';
  }

  String _formatChangeRate(double value) {
    final percent = (value * 100).toStringAsFixed(0);
    if (value > 0) return '+$percent%';
    if (value < 0) return '$percent%';
    return '0%';
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String value;

  const _ComparisonRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}