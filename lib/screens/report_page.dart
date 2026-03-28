

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/services/weekly_report_service.dart';

class ReportPage extends StatelessWidget {
  final List<Expense> expenses;

  const ReportPage({
    super.key,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = _startOfWeek(now);
    final end = start.add(const Duration(days: 6));
    final report = WeeklyReportService.generate(
      expenses: expenses,
      start: start,
      end: end,
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('今週のまとめ'),
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
                  '今週のふりかえり',
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
                        '今週の支出',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatYen(report.totalExpense),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '先週との差',
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
                Text(
                  'ひとこと',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  report.comment,
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
                  'よく使ったカテゴリ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                if (report.categories.isEmpty)
                  Text(
                    '今週はまだ支出データがありません。',
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
                                _formatYen(category.amount),
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
                  '先週との比較',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _ComparisonRow(
                  label: '今週',
                  value: _formatYen(report.totalExpense),
                ),
                const SizedBox(height: 10),
                _ComparisonRow(
                  label: '先週',
                  value: _formatYen(report.previousWeekExpense),
                ),
                const SizedBox(height: 10),
                _ComparisonRow(
                  label: '前週比',
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

  String _formatYen(int value) {
    return '¥${NumberFormat('#,###').format(value)}';
  }

  String _formatDifference(int value) {
    if (value > 0) {
      return '+${_formatYen(value)}';
    }
    if (value < 0) {
      return '-${_formatYen(value.abs())}';
    }
    return '±¥0';
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