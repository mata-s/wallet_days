import 'dart:math';
import 'package:flutter/material.dart';
import 'package:saiyome/models/expense.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/services/expense_sync_service.dart';
import 'package:saiyome/widget_sync_service.dart';
import 'package:saiyome/services/roast_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saiyome/main.dart' show flutterLocalNotificationsPlugin;
import 'package:saiyome/utils/time_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:saiyome/screens/receipt_scan_page.dart';

class ThousandsFormatter extends TextInputFormatter {
  final _formatter = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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

class AddExpensePage extends StatefulWidget {
  final Expense? initialExpense;

  const AddExpensePage({
    super.key,
    this.initialExpense,
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  final NumberFormat _yenFormatter = NumberFormat('#,###');

  String? _selectedCategory;
  List<BudgetCategory> _categories = [];
  List<String> _frequentStores = [];
  
  Map<String, List<int>> _storeAmounts = {};
  Map<String, String> _storeCategories = {};
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
      return _yenFormatter.format(amount);
    }

    final dollars = amount / 100;
    return NumberFormat('#,##0.00').format(dollars);
  }
  void _formatMoneyControllerOnBlur(TextEditingController controller) {
    if (_currentLang() == 'ja') return;

    final amount = _parseMoneyInput(controller.text);
    controller.text = _formatMoneyInput(amount);
  }

  String _formatMoneyDisplay(int amount) {
    if (_currentLang() == 'ja') {
      return '${_yenFormatter.format(amount)}円';
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

bool _didApplyInitialExpense = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔥 AddExpensePage opened');
    _loadLanguagePreference();
    _amountFocusNode.addListener(() {
      if (!_amountFocusNode.hasFocus) {
        _formatMoneyControllerOnBlur(_amountController);
      }
    });

    _loadCategories();
    _loadFrequentStores();
  }

  @override
void didChangeDependencies() {
  super.didChangeDependencies();

  if (_didApplyInitialExpense) return;
  _didApplyInitialExpense = true;

  final initialExpense = widget.initialExpense;
  if (initialExpense == null) return;

  _amountController.text = _formatMoneyInput(initialExpense.amount);
  _storeController.text = initialExpense.storeName;
  _selectedCategory = initialExpense.category;
}

  Future<void> _loadCategories() async {
    final budgetSetting = await IsarService.getBudgetSetting();
    if (!mounted) return;

    final categories = budgetSetting?.categories ?? [];

    setState(() {
      _categories = categories;

      if (!_categories.any((c) => c.name == _t('その他', 'Other'))) {
        _categories = [
          ..._categories,
          BudgetCategory()
            ..name = _t('その他', 'Other')
            ..badge = '✨'
            ..budget = 0,
        ];
      }
      if (_selectedCategory == null && _categories.isNotEmpty) {
        _selectedCategory = _categories.first.name;
      }
    });
  }

Future<void> _loadFrequentStores() async {
  final expenses = await IsarService.getExpenses();
  if (!mounted) return;

  final Map<String, int> countMap = {};
  final Map<String, Map<int, int>> amountCountMap = {};
  final Map<String, Map<String, int>> categoryCountMap = {};

  for (final expense in expenses) {
    final store = expense.storeName.trim();
    if (store.isEmpty) continue;

    countMap[store] = (countMap[store] ?? 0) + 1;

    amountCountMap[store] ??= {};
    amountCountMap[store]![expense.amount] =
        (amountCountMap[store]![expense.amount] ?? 0) + 1;

    final category = expense.category.trim();
    if (category.isNotEmpty) {
      categoryCountMap[store] ??= {};
      categoryCountMap[store]![category] =
          (categoryCountMap[store]![category] ?? 0) + 1;
    }
  }

  final sortedStores = countMap.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });

  final Map<String, List<int>> storeAmounts = {};
  for (final entry in amountCountMap.entries) {
    final sortedAmounts = entry.value.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    storeAmounts[entry.key] = sortedAmounts
        .map((amountEntry) => amountEntry.key)
        .take(4)
        .toList();
  }

  final Map<String, String> storeCategories = {};
  for (final entry in categoryCountMap.entries) {
    final sortedCategories = entry.value.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    if (sortedCategories.isNotEmpty) {
      storeCategories[entry.key] = sortedCategories.first.key;
    }
  }

  setState(() {
    _frequentStores = sortedStores
        .map((entry) => entry.key)
        .take(8)
        .toList();
    _storeAmounts = storeAmounts;
    _storeCategories = storeCategories;
  });
}

  Future<bool> _isPremiumUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
  }

  Future<void> _showSavedExpenseNotification(Expense expense) async {
    final budgetSetting = await IsarService.getBudgetSetting();
    final totalBudget = budgetSetting?.totalBudget ?? 0;

    final latestCategoryBudget = budgetSetting?.categories
        .where((category) => category.name == expense.category)
        .map((category) => category.budget)
        .cast<int?>()
        .firstWhere((_) => true, orElse: () => null);

    final expenses = await IsarService.getExpenses();
    final usedAmount = expenses.fold<int>(
      0,
      (sum, item) => sum + item.amount,
    );
    final latestCategoryUsed = expenses
        .where((item) => item.category == expense.category)
        .fold<int>(0, (sum, item) => sum + item.amount);

    final lang = _currentLang();

    final roastResult = await RoastService.build(
      languageCode: lang,
      totalBudget: totalBudget,
      usedAmount: usedAmount,
      expenses: expenses,
      dangerCategories: const [],
      latestCategoryBudget: latestCategoryBudget,
      latestCategoryUsed: latestCategoryUsed,
      latestCategoryTagUsedAmounts: const {},
    );

    final title = roastResult.title;
    final body = roastResult.notificationBody;

    const androidDetails = AndroidNotificationDetails(
      'saiyome_channel',
      'Wallet notifications',
      channelDescription: 'Notifications after recording expenses',
      importance: Importance.max,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      var permissionGranted = await androidPlugin.areNotificationsEnabled();

      if (permissionGranted == false) {
        await androidPlugin.requestNotificationsPermission();
        permissionGranted = await androidPlugin.areNotificationsEnabled();
      }

      debugPrint('[AddExpensePage] notification permissionGranted=$permissionGranted');

      if (permissionGranted == false) {
        debugPrint('[AddExpensePage] notification skipped because permission is denied');
        return;
      }
    } else {
      debugPrint('[AddExpensePage] iOS/macOS: skip Android permission check');
    }

   const notificationId = 900001;

    debugPrint('[AddExpensePage] scheduled notification for 15 minutes later');
    debugPrint('[AddExpensePage] title=$title');
    debugPrint('[AddExpensePage] body=$body');
debugPrint('[AddExpensePage] notificationId=$notificationId');

await flutterLocalNotificationsPlugin.cancel(id: notificationId);

await flutterLocalNotificationsPlugin.zonedSchedule(
  id: notificationId,
  title: title,
  body: body,
  scheduledDate: tz.TZDateTime.now(tz.local).add(
    const Duration(minutes: 15),
  ),
  notificationDetails: details,
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
);
  }
  // Future<void> _openReceiptScanPage() async {
  //   final isPremium = await _isPremiumUser();

  //   if (!isPremium) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('プレミアム機能です')),
  //     );
  //     return;
  //   }

  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => const ReceiptScanPage(),
  //     ),
  //   );

  //   if (result == null) return;

  //   final store = result['store'];
  //   final amount = result['amount'];

  //   if (store != null) {
  //     _storeController.text = store;
  //   }

  //   if (amount != null) {
  //     _amountController.text = amount.toString();
  //   }
  // }

  Future<void> _saveExpense() async {
    _formatMoneyControllerOnBlur(_amountController);
    final amountText = _amountController.text.trim();
    final store = _storeController.text.trim();

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('カテゴリを設定してください', 'Select a category.'))),
      );
      return;
    }

    if (amountText.isEmpty || store.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('金額と店名を入力してください', 'Enter an amount and store name.'))),
      );
      return;
    }

    final amount = _parseMoneyInput(amountText);

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('金額は数字で入力してください', 'Enter a valid amount.'))),
      );
      return;
    }

    final expense = Expense()
      ..amount = amount
      ..storeName = store
      ..category = _selectedCategory!
      ..createdAt = getNow()
      ..roastMessage = _t('昨日の$store、見ましたよ。', 'I saw yesterday\'s $store expense.');

    if (widget.initialExpense != null) {
      expense.id = widget.initialExpense!.id;
      expense.createdAt = widget.initialExpense!.createdAt;
      expense.futureLogMessage = widget.initialExpense!.futureLogMessage;
      expense.roastMessage = widget.initialExpense!.roastMessage;
    }
    await IsarService.saveExpense(expense);
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
      final categoryCandidates = budgetSetting!.categories
          .where((category) => category.budget > 0)
          .map((category) {
            final used = savedExpenses
                .where((item) => item.category == category.name)
                .fold<int>(0, (sum, item) => sum + item.amount);
            final remainingBudget = category.budget - used;
            final usageRate = category.budget <= 0
                ? 0.0
                : used / category.budget;

            return {
              'name': category.name,
              'badge': category.badge,
              'remaining': remainingBudget,
              'usageRate': usageRate,
              'budget': category.budget,
            };
          })
          .toList();

      final widgetDangerCategories = categoryCandidates
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
        final randomNormalCategories = categoryCandidates
            .where((category) => !widgetCategories.any(
                  (selected) => selected['name'] == category['name'],
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

    final isPremium = await _isPremiumUser();
    if (isPremium) {
      await ExpenseSyncService.syncExpense(expense);
    }
    debugPrint('[AddExpensePage] calling notification after save');
    await _showSavedExpenseNotification(expense);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _amountController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialExpense == null ? _t('支出を追加', 'Add expense') : _t('支出を編集', 'Edit expense')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 一旦非表示（レシート機能）
              // TextButton.icon(
              //   onPressed: _openReceiptScanPage,
              //   icon: const Icon(Icons.receipt_long),
              //   label: const Text('レシートを読み込む（プレミアム）'),
              // ),
              // const SizedBox(height: 12),
              Text(_t('店名・サービス名', 'Store or service'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _storeController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _t('例: カフェ', 'Example: Cafe'),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_frequentStores.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _t('よく使うお店', 'Frequent stores'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _frequentStores.map((store) {
                    return ActionChip(
                      label: Text(store),
                      onPressed: () {
                        setState(() {
                          _storeController.text = store;
                          _storeController.selection = TextSelection.collapsed(
                            offset: _storeController.text.length,
                          );

                          final suggestedCategory = _storeCategories[store];
                          if (suggestedCategory != null &&
                              _categories.any((category) => category.name == suggestedCategory)) {
                            _selectedCategory = suggestedCategory;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
                const SizedBox(height: 20),
                 Text(_t('金額', 'Amount'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                focusNode: _amountFocusNode,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _moneyInputFormatters(),
                onEditingComplete: () {
                  _formatMoneyControllerOnBlur(_amountController);
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  hintText: _t('例: 700', 'Example: 7.00'),
                  border: const OutlineInputBorder(),
                  suffixText: _currentLang() == 'ja' ? '円' : null,
                  prefixText: _currentLang() == 'ja' ? null : '\$',
                ),
              ),
              if (_storeController.text.trim().isNotEmpty &&
    (_storeAmounts[_storeController.text.trim()] ?? []).isNotEmpty) ...[
  const SizedBox(height: 10),
  Text(
    _t('よく使う金額', 'Frequent amounts'),
    style: theme.textTheme.bodySmall?.copyWith(
      color: Colors.black54,
      fontWeight: FontWeight.w600,
    ),
  ),
  const SizedBox(height: 8),
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: (_storeAmounts[_storeController.text.trim()] ?? [])
        .map((amount) {
      return ActionChip(
        label: Text(_formatMoneyDisplay(amount)),
        onPressed: () {
          setState(() {
            _amountController.text = _formatMoneyInput(amount);
            _amountController.selection = TextSelection.collapsed(
              offset: _amountController.text.length,
            );
          });
        },
      );
    }).toList(),
  ),
],
              const SizedBox(height: 20),
              Text(_t('カテゴリ', 'Category'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_categories.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Text(
                    _t('先に予算設定でカテゴリを登録してください', 'Create categories in Budget settings first.'),
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._categories.map((category) {
                      final isSelected = _selectedCategory == category.name;

                      return ChoiceChip(
                        label: Text('${category.badge} ${category.name}'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category.name;
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              if (_selectedCategory == _t('その他', 'Other'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _t('※ その他は、カテゴリーにない急な出費のときに使います', 'Use Other for unexpected expenses that do not fit a category.'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  child: Text(_t('保存', 'Save')),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: 44,
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _formatMoneyControllerOnBlur(_amountController);
                        FocusScope.of(context).unfocus();
                      },
                      child: Text(
                        _t('完了', 'Done'),
                        style: const TextStyle(
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