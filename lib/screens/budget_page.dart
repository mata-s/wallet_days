import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/screens/income_fixed_cost_page.dart';
import 'package:saiyome/services/budget_setting_sync_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:saiyome/models/budget_history.dart';
import 'package:saiyome/services/budget_history_sync_service.dart';
import 'package:saiyome/utils/time_provider.dart';
import 'package:saiyome/widget_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThousandsFormatter extends TextInputFormatter {
  final _formatter = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(',', '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) return newValue;

    final newText = _formatter.format(number);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class DecimalMoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    final normalized = text.replaceAll(',', '');
    final valid = RegExp(r'^\d*\.?\d{0,2}$').hasMatch(normalized);
    if (!valid) {
      return oldValue;
    }

    return newValue;
  }
}

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  Map<String, List<String>> _badgeGroups() {
    return {
      _t('食費・飲食', 'Food & drinks'): ['🍚', '🍜', '☕️', '🍔', '🍺', '🍰'],
      _t('買い物・生活', 'Shopping & daily life'): ['🏪', '🛒', '🧻', '🧴', '👕', '💄'],
      _t('移動・住まい', 'Transport & home'): ['🚃', '🚗', '⛽️', '🏠', '💡', '📱'],
      _t('健康・美容', 'Health & beauty'): ['💊', '💇‍♀️'],
      _t('趣味・娯楽', 'Hobbies & fun'): ['🎮', '🎬', '🎵', '📚', '🎨', '🎯'],
      _t('お金・その他', 'Money & other'): ['🎁', '💰', '💳', '✨'],
    };
  }

  String? _languageOverride; // 'ja' or 'en'

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

  String _defaultCategoryBadge() {
    return _currentLang() == 'ja' ? '🍚' : '🛒';
  }

  int _parseMoneyInput(String text) {
    final normalized = text.replaceAll(',', '').trim();
    if (normalized.isEmpty) return 0;

    if (_currentLang() == 'ja') {
      return int.tryParse(normalized) ?? 0;
    }

    final value = double.tryParse(normalized);
    if (value == null) return 0;
    return (value * 100).round();
  }

  String _formatMoneyInput(int amount) {
    if (amount <= 0) return '';

    if (_currentLang() == 'ja') {
      return NumberFormat('#,###').format(amount);
    }

    final dollars = amount / 100;
    return NumberFormat('#,##0.00').format(dollars);
  }

  String _formatMoneyDisplay(int amount) {
    if (_currentLang() == 'ja') {
      return '¥${NumberFormat('#,###').format(amount)}';
    }

    final dollars = amount / 100;
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(dollars);
  }

  List<TextInputFormatter> _moneyInputFormatters() {
    if (_currentLang() == 'ja') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        ThousandsFormatter(),
      ];
    }

    return [DecimalMoneyFormatter()];
  }

  void _formatMoneyControllerOnBlur(TextEditingController controller) {
  if (_currentLang() == 'ja') return;

  final amount = _parseMoneyInput(controller.text);
  controller.text = _formatMoneyInput(amount);
}

  final TextEditingController _totalBudgetController =
      TextEditingController();
  final TextEditingController _extraAmountController =
      TextEditingController();

  final List<Map<String, dynamic>> _categoryControllers = [
    {
      'nameController': TextEditingController(),
      'budgetController': TextEditingController(),
      'badge': '🛒',
    },
  ];

  bool _useCategoryBudget = true;

  int _cycleStartDay = 1;
  DateTime? _currentOpenPeriodStart;
  int _manualBudgetBuffer = 0;
  int _usableBudgetBase = 0;
  
  Future<bool> _isPremiumUser() async {
  try {
    final customerInfo = await Purchases.getCustomerInfo();
    return customerInfo.entitlements.active.containsKey('premium');
  } catch (_) {
    return false;
  }
}

  @override
void initState() {
  super.initState();
  _loadLanguagePreference();
  _loadBudgetSetting();
  _loadIncomeFixedCostSetting();
}

Future<void> _loadBudgetSetting() async {
  final budgetSetting = await IsarService.getBudgetSetting();
  print('[BudgetPage] load budgetSetting exists=${budgetSetting != null}');
  print('[BudgetPage] load cycleStartDay=${budgetSetting?.cycleStartDay}');
  print('[BudgetPage] load pendingCycleStartDay=${budgetSetting?.pendingCycleStartDay}');
  if (!mounted) return;
  DateTime? currentOpenPeriodStart;
  if (budgetSetting?.currentBudgetHistoryLocalId != null) {
    final currentHistory = await IsarService.getBudgetHistoryById(
      budgetSetting!.currentBudgetHistoryLocalId!,
    );
    currentOpenPeriodStart = currentHistory?.startDate;
  }

  if (currentOpenPeriodStart == null) {
    final now = getNow();
    final histories = await IsarService.getBudgetHistories();
    for (final history in histories) {
      if (!now.isBefore(history.startDate) && now.isBefore(history.endDate)) {
        currentOpenPeriodStart = history.startDate;
        break;
      }
    }
  }
  if (budgetSetting == null) {
    setState(() {
      _cycleStartDay = 1;
      _currentOpenPeriodStart = currentOpenPeriodStart;
    });
    return;
  }

  for (final item in _categoryControllers) {
    (item['nameController'] as TextEditingController).dispose();
    (item['budgetController'] as TextEditingController).dispose();
  }
  _categoryControllers.clear();

  _totalBudgetController.text = _formatMoneyInput(budgetSetting.totalBudget);

  _useCategoryBudget = budgetSetting.useCategoryBudget;
  _manualBudgetBuffer = (budgetSetting.totalBudget -
          budgetSetting.categories.fold<int>(
            0,
            (sum, category) => sum + category.budget,
          ))
      .clamp(0, 1 << 30);
  _extraAmountController.text = _formatMoneyInput(_manualBudgetBuffer);

  _cycleStartDay =
      budgetSetting.cycleStartDay == 0 ? 1 : budgetSetting.cycleStartDay;

  if (budgetSetting.categories.isEmpty) {
    _categoryControllers.add({
      'nameController': TextEditingController(),
      'budgetController': TextEditingController(),
      'badge': _defaultCategoryBadge(),
    });
  } else {
    for (final category in budgetSetting.categories) {
      _categoryControllers.add({
        'nameController': TextEditingController(text: category.name),
        'budgetController': TextEditingController(
          text: _formatMoneyInput(category.budget),
        ),
        'badge': category.badge,
      });
    }
  }

  setState(() {
    _currentOpenPeriodStart = currentOpenPeriodStart;
  });
}

Future<void> _loadIncomeFixedCostSetting() async {
  final setting = await IsarService.getIncomeFixedCostSetting();
  if (!mounted) return;

  setState(() {
    if (setting == null) {
      _usableBudgetBase = 0;
    } else {
      _usableBudgetBase = setting.income - setting.fixedCostTotal;
      if (_usableBudgetBase < 0) {
        _usableBudgetBase = 0;
      }
    }
  });
}

DateTime _currentPeriodStart(DateTime now) {
  final startDay = _cycleStartDay.clamp(1, 28);
  if (now.day >= startDay) {
    return DateTime(now.year, now.month, startDay);
  }
  return DateTime(now.year, now.month - 1, startDay);
}

// DateTime _currentPeriodEnd(DateTime periodStart) {
//   return DateTime(
//     periodStart.year,
//     periodStart.month + 1,
//     periodStart.day,
//   ).subtract(const Duration(days: 1));
// }

  int get _categoryBudgetSum {
    int total = 0;
    for (final item in _categoryControllers) {
      final budgetController = item['budgetController'] as TextEditingController;
      total += _parseMoneyInput(budgetController.text);
    }
    return total;
  }

  int get _currentTotalBudgetValue {
    return _parseMoneyInput(_totalBudgetController.text);
  }

  int get _remainingUsableBudget {
    return _usableBudgetBase - _currentTotalBudgetValue;
  }

  bool get _isOverUsableBudget {
    return _hasUsableBudgetBase && _remainingUsableBudget < 0;
  }
  
  bool get _hasUsableBudgetBase {
    return _usableBudgetBase > 0;
  }

  int get _budgetExtraAmount {
    return _parseMoneyInput(_extraAmountController.text);
  }

  void _setExtraAmountValue(int value) {
    final safeValue = value < 0 ? 0 : value;
    _manualBudgetBuffer = safeValue;
    _extraAmountController.text = _formatMoneyInput(safeValue);
  }

  void _syncExtraAmountFromTotalBudget() {
    final extra = _currentTotalBudgetValue - _categoryBudgetSum;
    _setExtraAmountValue(extra < 0 ? 0 : extra);
  }

  void _syncTotalBudgetFromExtraAmount() {
    if (!_useCategoryBudget) return;

    final nextTotal = _categoryBudgetSum + _budgetExtraAmount;
    _totalBudgetController.text = _formatMoneyInput(nextTotal);
  }

  void _syncTotalBudgetWithCategorySum({bool preserveCurrentDifference = true}) {
    if (!_useCategoryBudget) return;

    if (preserveCurrentDifference) {
      _syncExtraAmountFromTotalBudget();
    }

    final nextTotal = _categoryBudgetSum + _budgetExtraAmount;
    _totalBudgetController.text = _formatMoneyInput(nextTotal);
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    _extraAmountController.dispose();
    for (final item in _categoryControllers) {
      item['nameController'].dispose();
      item['budgetController'].dispose();
    }
    super.dispose();
  }

  Future<void> _saveBudget() async  {
    final totalBudgetText = _totalBudgetController.text.trim();

    if (!_useCategoryBudget && totalBudgetText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('全体予算を入力してください', 'Enter your total budget.'))),
      );
      return;
    }

    final validCategories = <Map<String, String>>[];

    for (final item in _categoryControllers) {
      final nameController = item['nameController'] as TextEditingController;
      final budgetController = item['budgetController'] as TextEditingController;
      final badge = item['badge'] as String;

      final name = nameController.text.trim();
      final budgetText = budgetController.text.trim();

      final isNameEmpty = name.isEmpty;
      final isBudgetEmpty = budgetText.isEmpty;

      if (isNameEmpty && isBudgetEmpty) {
        continue;
      }

      if (isNameEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('カテゴリー名を入力してください', 'Enter a category name.'))),
        );
        return;
      }

      if (isBudgetEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('「$name」の予算を入力してください', 'Enter a budget for "$name".'))),
        );
        return;
      }

      validCategories.add({
        'name': name,
        'budget': budgetText,
        'badge': badge,
      });
    }

final totalBudget = _parseMoneyInput(totalBudgetText);

final budgetSetting = BudgetSetting()
  ..totalBudget = totalBudget
  ..useCategoryBudget = _useCategoryBudget
  ..cycleStartDay = _cycleStartDay
  ..pendingCycleStartDay = null
  ..updatedAt = DateTime.now();

print('[BudgetPage] save selectedCycleStartDay=$_cycleStartDay');
print('[BudgetPage] save cycleStartDay=${budgetSetting.cycleStartDay}');
print('[BudgetPage] save pendingCycleStartDay=${budgetSetting.pendingCycleStartDay}');

budgetSetting.categories = validCategories.map((e) {
  return BudgetCategory()
    ..name = e['name'] ?? ''
    ..budget = _parseMoneyInput(e['budget'] ?? '0')
    ..badge = e['badge'] ?? '✨';
}).toList();

    final now = getNow();

    final savedSetting = await IsarService.getBudgetSetting();
    BudgetHistory? history;
    if (savedSetting?.currentBudgetHistoryLocalId != null) {
      history = await IsarService.getBudgetHistoryById(
        savedSetting!.currentBudgetHistoryLocalId!,
      );
    }

    DateTime periodStart;
    DateTime periodEnd;

    if (history != null) {
      // 開始日はそのまま維持して、終了日だけ新しい開始日に合わせる
      periodStart = history.startDate;
      final nextMonth = DateTime(periodStart.year, periodStart.month + 1);
      periodEnd = DateTime(nextMonth.year, nextMonth.month, _cycleStartDay);
    } else {
      // 初回作成時のみ、今日を含む期間を作る
      periodStart = _currentPeriodStart(now);
      periodEnd = DateTime(
        periodStart.year,
        periodStart.month + 1,
        periodStart.day,
      );
      history = BudgetHistory()..createdAt = now;
    }

    final expenses = await IsarService.getExpenses();
    final recalculatedTotalExpense = expenses
        .where((expense) {
          return !expense.createdAt.isBefore(periodStart) &&
              expense.createdAt.isBefore(periodEnd);
        })
        .fold<int>(0, (sum, expense) => sum + expense.amount);

    history
      ..startDate = periodStart
      ..endDate = periodEnd
      ..totalBudget = totalBudget
      ..totalExpense = recalculatedTotalExpense
      ..isAchieved = recalculatedTotalExpense <= totalBudget
      ..streak = history.streak
      ..bestStreak = history.bestStreak
      ..createdAt = history.createdAt;

    await IsarService.saveBudgetHistory(history);

    final refreshedSetting = (savedSetting ?? budgetSetting)
      ..totalBudget = budgetSetting.totalBudget
      ..useCategoryBudget = budgetSetting.useCategoryBudget
      ..cycleStartDay = budgetSetting.cycleStartDay
      ..pendingCycleStartDay = null
      ..currentBudgetHistoryLocalId = history.id
      ..updatedAt = budgetSetting.updatedAt
      ..categories = budgetSetting.categories;

    await IsarService.saveBudgetSetting(refreshedSetting);
    final widgetCategoryCandidates = refreshedSetting.categories
        .where((category) => category.budget > 0)
        .map((category) {
          final used = expenses
              .where((expense) => category.name == expense.category)
              .fold<int>(0, (sum, expense) => sum + expense.amount);
          final usageRate = category.budget <= 0 ? 0.0 : used / category.budget;

          return {
            'name': category.name,
            'remaining': category.budget - used,
            'badge': category.badge,
            'budget': category.budget,
            'usageRate': usageRate,
          };
        })
        .toList();

    final widgetDangerCategories = widgetCategoryCandidates
        .where((category) {
          final remaining = category['remaining'] as int;
          final usageRate = category['usageRate'] as double;
          return remaining < 0 || usageRate >= 0.75;
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

    final widgetCategories = <Map<String, dynamic>>[
      ...widgetDangerCategories.take(2),
    ];

    if (widgetCategories.length < 2) {
      final randomNormalCategories = widgetCategoryCandidates
          .where((category) => !widgetCategories.any(
                (selected) => selected['name'] == category['name'],
              ))
          .toList()
        ..shuffle(Random());

      widgetCategories.addAll(
        randomNormalCategories.take(2 - widgetCategories.length),
      );
    }

    await WidgetSyncService.updateRemainingBudget(
      totalBudget - recalculatedTotalExpense,
      totalBudget: totalBudget,
      dangerCategories: widgetCategories
          .map(
            (category) => WidgetDangerCategory(
              name: category['name'] as String,
              remaining: category['remaining'] as int,
              badge: category['badge'] as String,
              budget: category['budget'] as int,
            ),
          )
          .toList(),
    );

    print(
      '[BudgetPage] saved history id=${history.id} '
      'start=${history.startDate} '
      'end=${history.endDate} '
      'totalBudget=${history.totalBudget} '
      'totalExpense=${history.totalExpense} '
      'currentBudgetHistoryLocalId=${refreshedSetting.currentBudgetHistoryLocalId}',
    );

    final isPremium = await _isPremiumUser();
    if (isPremium) {
      await BudgetSettingSyncService.syncBudgetSetting(refreshedSetting);
      await BudgetHistorySyncService.syncBudgetHistory(history);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _showCycleStartDayPicker() {
    int tempIndex = _cycleStartDay - 1;
    FocusScope.of(context).requestFocus(FocusNode());

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
                      _t('開始日を選択', 'Select start day'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _cycleStartDay = tempIndex + 1;
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
                  children: List.generate(28, (index) {
                    final day = index + 1;
                    return Center(
                      child: Text(
                        _t('毎月 $day 日から', 'From day $day each month'),
                        style: const TextStyle(fontSize: 22),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ({DateTime start, DateTime end}) _previewPeriodRange(
    DateTime now,
    int cycleStartDay,
  ) {
    final safeStartDay = cycleStartDay.clamp(1, 28);

    if (_currentOpenPeriodStart != null) {
      final start = _currentOpenPeriodStart!;
      final nextMonth = DateTime(start.year, start.month + 1);
      final endExclusive = DateTime(nextMonth.year, nextMonth.month, safeStartDay);
      return (
        start: start,
        end: endExclusive.subtract(const Duration(days: 1)),
      );
    }

    final start = now.day >= safeStartDay
        ? DateTime(now.year, now.month, safeStartDay)
        : DateTime(now.year, now.month - 1, safeStartDay);
    final endExclusive = DateTime(start.year, start.month + 1, start.day);

    return (
      start: start,
      end: endExclusive.subtract(const Duration(days: 1)),
    );
  }

  Widget _buildStartDayCard(ThemeData theme) {
    final now = getNow();
    final previewRange = _previewPeriodRange(now, _cycleStartDay);
    final previewText =
        '${previewRange.start.month}/${previewRange.start.day}〜${previewRange.end.month}/${previewRange.end.day}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('開始日', 'Start day'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              '現在の集計期間をこの開始日に合わせて更新します',
              'Update your current period based on this start day',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t('例: $previewText', 'Example: $previewText'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showCycleStartDayPicker,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _t('毎月 $_cycleStartDay 日から', 'From day $_cycleStartDay each month'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('収入と固定費', 'Income & fixed costs'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t('使えるお金の前提', 'Base for your budget'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IncomeFixedCostPage(),
                ),
              );

              if (!mounted) return;

              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();

              if (result != null) {
                await _loadIncomeFixedCostSetting();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDEDED)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t('確認する', 'Check'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

  return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_t('予算設定', 'Budget settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            children: [
              _buildStartDayCard(theme),
              const SizedBox(height: 12),
              _buildIncomeCard(theme),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      _t('今月の全体予算', 'Monthly budget'),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
    const SizedBox(height: 6),
    Text(
      _t(
        'カテゴリを振り分ける前に、今月の上限を決めます。',
        'Set your monthly limit before assigning categories.',
      ),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.black54,
        height: 1.4,
      ),
    ),
    const SizedBox(height: 12),
    if (_hasUsableBudgetBase) ...[
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('今月の使える予算', 'Monthly budget'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMoneyDisplay(_usableBudgetBase),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_isOverUsableBudget) ...[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  _isOverUsableBudget
                      ? _t('予算オーバー', 'Over budget')
                      : _t('あと使える金額', 'Left to spend'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _isOverUsableBudget ? Colors.red : Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _remainingUsableBudget >= 0
                  ? _formatMoneyDisplay(_remainingUsableBudget)
                  : '-${_formatMoneyDisplay(_remainingUsableBudget.abs())}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: _remainingUsableBudget < 0 ? Colors.red : Colors.black87,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ],
    Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          _formatMoneyControllerOnBlur(_totalBudgetController);
        }
      },
      child: TextField(
        controller: _totalBudgetController,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: _moneyInputFormatters(),
        onChanged: (_) {
          if (!_useCategoryBudget) {
            setState(() {});
            return;
          }
          setState(() {
            _syncExtraAmountFromTotalBudget();
          });
        },
        decoration: InputDecoration(
          labelText: _t('予算', 'Budget'),
          hintText: _t('50,000', '2,000.00'),
          suffixText: _currentLang() == 'ja' ? '円' : null,
          prefixText: _currentLang() == 'ja' ? null : '\$',
          border: const OutlineInputBorder(),
          helperText: _useCategoryBudget
              ? _t(
                  'カテゴリ合計 ${_formatMoneyDisplay(_categoryBudgetSum)} を反映中',
                  'Category total: ${_formatMoneyDisplay(_categoryBudgetSum)}',
                )
              : null,
        ),
      ),
    ),
  ],
),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_t('カテゴリ別予算を設定する', 'Enable category budgets')),
                  value: _useCategoryBudget,
                  onChanged: (value) {
                    setState(() {
                      _useCategoryBudget = value;
                      if (_useCategoryBudget) {
                        _syncExtraAmountFromTotalBudget();
                        _syncTotalBudgetWithCategorySum(
                          preserveCurrentDifference: false,
                        );
                      }
                    });
                  },
                ),
                if (_useCategoryBudget) ...[
                  const SizedBox(height: 8),
                  ..._categoryControllers.map((item) {
                    final nameController = item['nameController'] as TextEditingController;
                    final budgetController = item['budgetController'] as TextEditingController;
                    final badge = item['badge'] as String;
                    final isNarrow = MediaQuery.of(context).size.width <= 380;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () async {
                                  FocusScope.of(context).unfocus();
                                  FocusScope.of(context).requestFocus(FocusNode());

                                  final selected = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text(_t('バッジを選択', 'Select badge')),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: _badgeGroups().entries.map((entry) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        entry.key,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 10),
                                                      Wrap(
                                                        spacing: 12,
                                                        runSpacing: 12,
                                                        children: entry.value.map((emoji) {
                                                          return GestureDetector(
                                                            onTap: () =>
                                                                Navigator.pop(context, emoji),
                                                            child: Container(
                                                              width: 52,
                                                              height: 52,
                                                              alignment: Alignment.center,
                                                              decoration: BoxDecoration(
                                                                color: emoji == badge
                                                                    ? const Color(0xFFFFF1EA)
                                                                    : Colors.white,
                                                                borderRadius:
                                                                    BorderRadius.circular(16),
                                                                border: Border.all(
                                                                  color:
                                                                      const Color(0xFFE0E0E0),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                emoji,
                                                                style: const TextStyle(
                                                                    fontSize: 24),
                                                              ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(_t('閉じる', 'Close')),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (selected != null) {
                                    setState(() {
                                      item['badge'] = selected;
                                    });

                                    FocusScope.of(context).unfocus();
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1EA),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE8D9D2),
                                    ),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: nameController,
                                  decoration: InputDecoration(
                                    labelText: _t('カテゴリ名', 'Category name'),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              if (!isNarrow)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_categoryControllers.length == 1) {
                                        nameController.clear();
                                        budgetController.clear();
                                        item['badge'] = _defaultCategoryBadge();
                                      } else {
                                        nameController.dispose();
                                        budgetController.dispose();
                                        _categoryControllers.remove(item);
                                      }

                                      _syncTotalBudgetWithCategorySum(
                                        preserveCurrentDifference: false,
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: _t('カテゴリ削除', 'Delete category'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Focus(
                            onFocusChange: (hasFocus) {
                              if (!hasFocus) {
                                _formatMoneyControllerOnBlur(budgetController);
                              }
                            },
                            child: TextField(
                            controller: budgetController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: _moneyInputFormatters(),
                            onChanged: (_) {
                              setState(() {
                                _syncTotalBudgetWithCategorySum(
                                  preserveCurrentDifference: false,
                                );
                              });
                            },
                            decoration: InputDecoration(
                              labelText: _t('予算', 'Budget'),
                              hintText: _t('2,000', '100.00'),
                              suffixText: _currentLang() == 'ja' ? '円' : null,
                              prefixText: _currentLang() == 'ja' ? null : '\$',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          ),
                          if (isNarrow) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (_categoryControllers.length == 1) {
                                      nameController.clear();
                                      budgetController.clear();
                                      item['badge'] = _defaultCategoryBadge();
                                    } else {
                                      nameController.dispose();
                                      budgetController.dispose();
                                      _categoryControllers.remove(item);
                                    }

                                    _syncTotalBudgetWithCategorySum(
                                      preserveCurrentDifference: false,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: Text(_t('削除', 'Delete'))
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _categoryControllers.add({
                            'nameController': TextEditingController(),
                            'budgetController': TextEditingController(),
                            'badge': _defaultCategoryBadge(),
                          });
                          _syncTotalBudgetWithCategorySum(
                            preserveCurrentDifference: false,
                          );
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: _t('カテゴリ追加', 'Add category'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEDEDED)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('カテゴリ外で使える金額', 'Unassigned budget'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Focus(
                          onFocusChange: (hasFocus) {
                            if (!hasFocus) {
                              _formatMoneyControllerOnBlur(_extraAmountController);
                            }
                          },
                          child: TextField(
                            controller: _extraAmountController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: _moneyInputFormatters(),
                            onChanged: (_) {
                              if (!_useCategoryBudget) return;
                              setState(() {
                                _syncTotalBudgetFromExtraAmount();
                              });
                            },
                            decoration: InputDecoration(
                              labelText: _t('カテゴリ外で使える金額', 'Unassigned budget'),
                              hintText: _t('2,000', '100.00'),
                              suffixText: _currentLang() == 'ja' ? '円' : null,
                              prefixText: _currentLang() == 'ja' ? null : '\$',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saveBudget,
              child: Text(_t('予算を保存', 'Save budget')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: 44,
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Text(
                        _t('完了', 'Done'),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}