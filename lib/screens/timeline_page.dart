import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/widget_sync_service.dart';
import 'package:saiyome/widgets/future_log_item.dart';
import 'package:saiyome/widgets/timeline_item.dart';
import 'package:saiyome/utils/time_provider.dart';
import 'package:saiyome/main.dart' show flutterLocalNotificationsPlugin;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


enum TimelineFilterPeriod {
  all,
  today,
  last7Days,
  customMonth,
}

class TimelinePage extends StatefulWidget {
  final List<Expense> expenses;
  final String Function(int) formatYen;
  final String Function(String) categoryLabel;
  final IconData Function(String) iconForCategory;
  final String Function(DateTime) formatTimelineDate;
  final Future<Expense?> Function(Expense)? onEditExpense;
  final Future<bool> Function(Expense)? onDeleteExpense;

  const TimelinePage({
    super.key,
    required this.expenses,
    required this.formatYen,
    required this.categoryLabel,
    required this.iconForCategory,
    required this.formatTimelineDate,
    this.onEditExpense,
    this.onDeleteExpense,
  });

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late List<Expense> _expenses;
  TimelineFilterPeriod _selectedPeriod = TimelineFilterPeriod.all;
  late int _selectedYear;
  late int _selectedMonth;
  String _selectedCategory = 'すべて';
  String? _languageOverride; // 'ja' or 'en'

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _languageOverride = prefs.getString('app_language');
      if (_selectedCategory == 'すべて' || _selectedCategory == 'All') {
        _selectedCategory = _allCategoryLabel;
      }
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

  String get _allCategoryLabel => _t('すべて', 'All');

  String _formatMoney(int amount) {
    if (_currentLang() == 'ja') {
      return '¥${widget.formatYen(amount)}';
    }

    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount / 100);
  }

  String _formatYear(int year) {
    return _currentLang() == 'ja' ? '$year年' : '$year';
  }

  String _formatMonth(int month) {
    return _currentLang() == 'ja' ? '$month月' : DateFormat.MMMM('en_US').format(DateTime(2000, month));
  }

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _expenses = List<Expense>.from(widget.expenses);
    // final now = DateTime.now();
    final now = getNow();
    final years = _availableYears;
    _selectedYear = years.contains(now.year)
        ? now.year
        : (years.isNotEmpty ? years.first : now.year);

    final months = _expenses
        .where((expense) => expense.createdAt.year == _selectedYear)
        .map((expense) => expense.createdAt.month)
        .toSet()
        .toList()
      ..sort();

    _selectedMonth = months.contains(now.month)
        ? now.month
        : (months.isNotEmpty ? months.first : now.month);
  }

  @override
  void didUpdateWidget(covariant TimelinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.expenses, widget.expenses)) {
      _expenses = List<Expense>.from(widget.expenses);
    }
  }

  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<int> get _availableYears {
    final years = _expenses
        .map((expense) => expense.createdAt.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    // final nowYear = DateTime.now().year;
    final nowYear = getNow().year;
    if (!years.contains(nowYear)) {
      years.insert(0, nowYear);
    }
    return years;
  }

  List<int> get _availableMonthsForSelectedYear {
    final months = _expenses
        .where((expense) => expense.createdAt.year == _selectedYear)
        .map((expense) => expense.createdAt.month)
        .toSet()
        .toList()
      ..sort();

    return months;
  }

  void _ensureValidSelectedMonth() {
    final months = _availableMonthsForSelectedYear;
    if (months.isEmpty) return;
    if (!months.contains(_selectedMonth)) {
      _selectedMonth = months.first;
    }
  }

  Future<void> _updateHomeWidgetAfterExpenseChange() async {
    final budgetSetting = await IsarService.getBudgetSetting();
    final totalBudget = budgetSetting?.totalBudget ?? 0;
    final savedExpenses = await IsarService.getExpenses();
    final totalExpense = savedExpenses.fold<int>(
      0,
      (sum, item) => sum + item.amount,
    );
    final remaining = totalBudget - totalExpense;

    final dangerCategories = <WidgetDangerCategory>[];

    if ((budgetSetting?.useCategoryBudget ?? false) &&
        (budgetSetting?.categories.isNotEmpty ?? false)) {
      final categoryBudgets = budgetSetting!.categories
          .where((category) => category.budget > 0)
          .map((category) {
            final used = savedExpenses
                .where((item) => item.category == category.name)
                .fold<int>(0, (sum, item) => sum + item.amount);
            final remainingBudget = category.budget - used;
            final usageRate = category.budget <= 0 ? 0.0 : used / category.budget;

            return {
              'name': category.name,
              'badge': category.badge,
              'remaining': remainingBudget,
              'usageRate': usageRate,
              'budget': category.budget,
            };
          })
          .toList()
        ..sort((a, b) {
          final aRemaining = a['remaining'] as int;
          final bRemaining = b['remaining'] as int;
          final aUsageRate = a['usageRate'] as double;
          final bUsageRate = b['usageRate'] as double;

          final byRemaining = aRemaining.compareTo(bRemaining);
          if (byRemaining != 0) return byRemaining;

          return bUsageRate.compareTo(aUsageRate);
        });

      final widgetDangerCategories = categoryBudgets
          .where((item) {
            final remaining = item['remaining'] as int;
            final usageRate = item['usageRate'] as double;
            return remaining < 0 || usageRate >= 0.75;
          })
          .toList();

      final widgetCategories = <Map<String, dynamic>>[
        ...widgetDangerCategories.take(2),
      ];

      if (widgetCategories.length < 2) {
        final randomNormalCategories = categoryBudgets
            .where((item) => !widgetCategories.any(
                  (selected) => selected['name'] == item['name'],
                ))
            .toList()
          ..shuffle(Random());

        widgetCategories.addAll(
          randomNormalCategories.take(2 - widgetCategories.length),
        );
      }

      dangerCategories.addAll(
        widgetCategories.map(
          (item) => WidgetDangerCategory(
            name: item['name'] as String,
            remaining: item['remaining'] as int,
            badge: item['badge'] as String,
            budget: item['budget'] as int,
          ),
        ),
      );
    }

    await WidgetSyncService.updateRemainingBudget(
      remaining,
      totalBudget: totalBudget,
      dangerCategories: dangerCategories,
    );
  }

  List<String> get _availableCategories {
    final categories = _expenses
        .map((expense) => widget.categoryLabel(expense.category))
        .toSet()
        .toList()
      ..sort();

    return [_allCategoryLabel, ...categories];
  }

  bool _matchesPeriod(Expense expense) {
    // final now = DateTime.now();
    final now = getNow();
    final today = _normalize(now);
    final createdAt = _normalize(expense.createdAt);

    switch (_selectedPeriod) {
      case TimelineFilterPeriod.all:
        return true;
      case TimelineFilterPeriod.today:
        return createdAt == today;
      case TimelineFilterPeriod.last7Days:
        final start = today.subtract(const Duration(days: 6));
        return !createdAt.isBefore(start) && !createdAt.isAfter(today);
      case TimelineFilterPeriod.customMonth:
        return createdAt.year == _selectedYear &&
            createdAt.month == _selectedMonth;
    }
  }

  bool _matchesCategory(Expense expense) {
    if (_selectedCategory == _allCategoryLabel || _selectedCategory == 'すべて' || _selectedCategory == 'All') return true;
    return widget.categoryLabel(expense.category) == _selectedCategory;
  }

  String _periodLabel(TimelineFilterPeriod period) {
    switch (period) {
      case TimelineFilterPeriod.all:
        return _t('すべて', 'All');
      case TimelineFilterPeriod.today:
        return _t('今日', 'Today');
      case TimelineFilterPeriod.last7Days:
        return _t('7日間', '7 days');
      case TimelineFilterPeriod.customMonth:
        return _t('年月指定', 'Month');
    }
  }

  void _showYearPicker() {
    final years = _availableYears;
    if (years.isEmpty) return;

    int tempIndex = years.indexOf(_selectedYear);
    if (tempIndex < 0) tempIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        _t('キャンセル', 'Cancel'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      _t('年を選択', 'Select year'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedYear = years[tempIndex];
                          _ensureValidSelectedMonth();
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        _t('決定', 'Done'),
                        style: const TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 40.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: years.map((year) {
                    return Center(
                      child: Text(
                        _formatYear(year),
                        style: const TextStyle(fontSize: 22),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMonthPicker() {
    final months = _availableMonthsForSelectedYear;
    if (months.isEmpty) return;

    int tempIndex = months.indexOf(_selectedMonth);
    if (tempIndex < 0) tempIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        _t('キャンセル', 'Cancel'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      _t('月を選択', 'Select month'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedMonth = months[tempIndex];
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        _t('決定', 'Done'),
                        style: const TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 40.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: months.map((month) {
                    return Center(
                      child: Text(
                        _formatMonth(month),
                        style: const TextStyle(fontSize: 22),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryPicker() {
    final categories = _availableCategories;
    if (categories.isEmpty) return;

    int tempIndex = categories.indexOf(_selectedCategory);
    if (tempIndex < 0) tempIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        _t('キャンセル', 'Cancel'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      _t('カテゴリを選択', 'Select category'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = categories[tempIndex];
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        _t('決定', 'Done'),
                        style: const TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 40.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: categories.map((category) {
                    return Center(
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 22),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Expense> get _filteredExpenses {
    return _expenses
        .where((expense) => _matchesPeriod(expense) && _matchesCategory(expense))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('タイムライン', 'Timeline')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TimelineFilterPeriod.values.map((period) {
                      final isSelected = _selectedPeriod == period;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_periodLabel(period)),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedPeriod = period;
                            });
                          },
                          labelStyle: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          selectedColor: Colors.black87,
                          backgroundColor: const Color(0xFFF4F4F4),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showCategoryPicker,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: _t('カテゴリ', 'Category'),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8F9FC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(_selectedCategory)),
                              const Icon(Icons.expand_more, size: 20, color: Colors.black45),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedPeriod == TimelineFilterPeriod.customMonth) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _showYearPicker,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: _t('年', 'Year'),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8F9FC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(_formatYear(_selectedYear))),
                                const Icon(Icons.expand_more, size: 20, color: Colors.black45),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _showMonthPicker,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: _t('月', 'Month'),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8F9FC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(_formatMonth(_selectedMonth))),
                                const Icon(Icons.expand_more, size: 20, color: Colors.black45),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _filteredExpenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _t('この条件に合う支出はありません。', 'No expenses match these filters.'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
children: _filteredExpenses.expand((expense) => [
  Dismissible(
    key: ValueKey(expense.id),
    direction: widget.onDeleteExpense != null
        ? DismissDirection.endToStart
        : DismissDirection.none,
    background: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    secondaryBackground: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1E1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.delete_outline,
        color: Color(0xFFD64B4B),
        size: 28,
      ),
    ),
    confirmDismiss: widget.onDeleteExpense == null
        ? null
        : (_) async {
            final deleted = await widget.onDeleteExpense!(expense);
            if (deleted == true && mounted) {
              await flutterLocalNotificationsPlugin.cancel(id: expense.id);
              setState(() {
                _expenses.removeWhere((item) => item.id == expense.id);
              });
              await _updateHomeWidgetAfterExpenseChange();
              return true;
            }
            return false;
          },
    child: TimelineItem(
      title: expense.storeName,
      subtitle: widget.categoryLabel(expense.category),
      amount: _formatMoney(expense.amount),
      icon: widget.iconForCategory(expense.category),
      date: widget.formatTimelineDate(expense.createdAt),
      onEdit: widget.onEditExpense != null
          ? () async {
              final updatedExpense = await widget.onEditExpense!(expense);
              if (updatedExpense == null || !mounted) return;

              setState(() {
                final index = _expenses.indexWhere(
                  (item) => item.id == updatedExpense.id,
                );
                if (index != -1) {
                  _expenses[index] = updatedExpense;
                }
              });
              await _updateHomeWidgetAfterExpenseChange();
            }
          : null,
      onDelete: widget.onDeleteExpense != null
          ? () async {
              final deleted = await widget.onDeleteExpense!(expense);
              if (deleted != true || !mounted) return;

              await flutterLocalNotificationsPlugin.cancel(id: expense.id);
              setState(() {
                _expenses.removeWhere((item) => item.id == expense.id);
              });
              await _updateHomeWidgetAfterExpenseChange();
            }
          : null,
    ),
  ),
  if (expense.futureLogMessage != null) ...[
    const SizedBox(height: 10),
    FutureLogItem(message: expense.futureLogMessage!),
  ],
  const SizedBox(height: 10),
]).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}