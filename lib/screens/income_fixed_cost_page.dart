import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/services/income_fixed_cost_sync_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoneyThousandsFormatter extends TextInputFormatter {
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

class MoneyDecimalFormatter extends TextInputFormatter {
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

class IncomeFixedCostPage extends StatefulWidget {
  final int initialIncome;
  final int initialFixedCost;

  const IncomeFixedCostPage({
    super.key,
    this.initialIncome = 0,
    this.initialFixedCost = 0,
  });

  @override
  State<IncomeFixedCostPage> createState() => _IncomeFixedCostPageState();
}

class _IncomeFixedCostPageState extends State<IncomeFixedCostPage> {
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _fixedCostTotalController = TextEditingController();
  final TextEditingController _fixedCostManualController = TextEditingController();
  final FocusNode _incomeFocusNode = FocusNode();
  final FocusNode _fixedCostTotalFocusNode = FocusNode();
  final List<Map<String, dynamic>> _fixedCostControllers = [];
  final NumberFormat _formatter = NumberFormat('#,###');

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
      return _formatter.format(amount);
    }

    final dollars = amount / 100;
    return NumberFormat('#,##0.00').format(dollars);
  }
  void _formatMoneyControllerOnBlur(TextEditingController controller) {
    if (_currentLang() == 'ja') return;

    final amount = _parseMoneyInput(controller.text);
    controller.text = _formatMoneyInput(amount);
  }

  void _formatAllMoneyInputsOnBlur() {
    _formatMoneyControllerOnBlur(_incomeController);
    _formatMoneyControllerOnBlur(_fixedCostTotalController);
    _formatMoneyControllerOnBlur(_fixedCostManualController);
    for (final item in _fixedCostControllers) {
      final controller = item['amount'] as TextEditingController;
      _formatMoneyControllerOnBlur(controller);
    }
  }

  String _formatMoneyDisplay(int amount) {
    if (_currentLang() == 'ja') {
      return '¥${_formatter.format(amount)}';
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
        MoneyThousandsFormatter(),
      ];
    }

    return [MoneyDecimalFormatter()];
  }

  int get _income => _parseMoneyInput(_incomeController.text);

  int get _manualFixedCostAmount => _parseMoneyInput(_fixedCostManualController.text);

  int get _itemizedFixedCostTotal {
    int total = 0;
    for (final item in _fixedCostControllers) {
      final controller = item['amount']!;
      total += _parseMoneyInput(controller.text);
    }
    return total;
  }

  int get _fixedCost => _manualFixedCostAmount + _itemizedFixedCostTotal;

  void _syncManualFixedCostFromDisplayedTotal() {
    final displayedTotal = _parseMoneyInput(_fixedCostTotalController.text);
    final manualAmount = displayedTotal - _itemizedFixedCostTotal;
    _fixedCostManualController.text = _formatMoneyInput(manualAmount);
  }

  int get _usableAmount {
    final value = _income - _fixedCost;
    return value < 0 ? 0 : value;
  }

  int get _usableAmountRaw {
    return _income - _fixedCost;
  }

  bool get _isOverIncomeBase {
    return _income > 0 && _usableAmountRaw < 0;
  }

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();

    _incomeController.addListener(_handleChanged);
    _fixedCostTotalController.addListener(_handleChanged);
    _fixedCostManualController.addListener(_handleChanged);

    _incomeFocusNode.addListener(() {
      if (!_incomeFocusNode.hasFocus) {
        _formatMoneyControllerOnBlur(_incomeController);
      }
    });
    _fixedCostTotalFocusNode.addListener(() {
      if (!_fixedCostTotalFocusNode.hasFocus) {
        _formatMoneyControllerOnBlur(_fixedCostTotalController);
        _syncManualFixedCostFromDisplayedTotal();
        _syncFixedCostTotalFromSources();
      }
    });

    _fixedCostControllers.add(_createFixedCostItem());

    _loadSavedValues();
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _createFixedCostItem({
    String name = '',
    String amount = '',
  }) {
    final amountController = TextEditingController(text: amount);
    final amountFocusNode = FocusNode();
    final item = {
      'name': TextEditingController(text: name),
      'amount': amountController,
      'amountFocusNode': amountFocusNode,
    };
    item['name']!.addListener(_handleChanged);
    amountController.addListener(_handleChanged);
    amountFocusNode.addListener(() {
      if (!amountFocusNode.hasFocus) {
        _formatMoneyControllerOnBlur(amountController);
        _syncFixedCostTotalFromSources();
      }
    });
    return item;
  }

  void _disposeFixedCostItem(Map<String, dynamic> item) {
    final nameController = item['name'] as TextEditingController;
    final amountController = item['amount'] as TextEditingController;
    final amountFocusNode = item['amountFocusNode'] as FocusNode;
    nameController.removeListener(_handleChanged);
    amountController.removeListener(_handleChanged);
    nameController.dispose();
    amountController.dispose();
    amountFocusNode.dispose();
  }

  Future<void> _loadSavedValues() async {
    final saved = await IsarService.getIncomeFixedCostSetting();
    if (!mounted) return;

    for (final item in _fixedCostControllers) {
      _disposeFixedCostItem(item);
    }
    _fixedCostControllers.clear();

    final initialIncome = widget.initialIncome > 0
        ? widget.initialIncome
        : (saved?.income ?? 0);
    final initialFixedCost = widget.initialFixedCost > 0
        ? widget.initialFixedCost
        : (saved?.fixedCostTotal ?? 0);

    _incomeController.text = _formatMoneyInput(initialIncome);

    if (saved != null && saved.items.isNotEmpty) {
      for (final entry in saved.items) {
        _fixedCostControllers.add(
          _createFixedCostItem(
            name: entry.name,
            amount: _formatMoneyInput(entry.amount),
          ),
        );
      }
    }

    if (_fixedCostControllers.isEmpty) {
      _fixedCostControllers.add(_createFixedCostItem());
    }

    final itemizedTotal = _fixedCostControllers.fold<int>(
      0,
      (sum, item) => sum + _parseMoneyInput((item['amount'] as TextEditingController).text),
    );
    final manualAmount = initialFixedCost - itemizedTotal;
    _fixedCostManualController.text = _formatMoneyInput(manualAmount);
    _syncFixedCostTotalFromSources();

    setState(() {});
  }

  Future<void> _persistValues() async {
    await IsarService.saveIncomeFixedCostSetting(
      income: _income,
      fixedCostTotal: _fixedCost,
      items: _fixedCostControllers
          .map(
            (item) => {
              'name': (item['name'] as TextEditingController).text.trim(),
              'amount': _parseMoneyInput((item['amount'] as TextEditingController).text),
            },
          )
          .toList(),
    );
  }

  Future<bool> _isPremiumUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _incomeController.removeListener(_handleChanged);
    _fixedCostTotalController.removeListener(_handleChanged);
    _fixedCostManualController.removeListener(_handleChanged);
    _incomeFocusNode.dispose();
    _fixedCostTotalFocusNode.dispose();
    _incomeController.dispose();
    _fixedCostTotalController.dispose();
    _fixedCostManualController.dispose();
    for (final item in _fixedCostControllers) {
      _disposeFixedCostItem(item);
    }
    super.dispose();
  }

  void _syncFixedCostTotalFromSources() {
    // Do not rewrite the total field while the user is typing in it.
    // In English mode this would turn `1` into `1.00` immediately and block normal input.
    if (_fixedCostTotalFocusNode.hasFocus) return;

    final total = _fixedCost;
    _fixedCostTotalController.text = _formatMoneyInput(total);
  }

  void _resetSingleFixedCostItem(Map<String, dynamic> item) {
    (item['name'] as TextEditingController).clear();
    (item['amount'] as TextEditingController).clear();
  }

  Widget _buildFixedCostItem(ThemeData theme, Map<String, dynamic> item) {
    final nameController = item['name'] as TextEditingController;
    final amountController = item['amount'] as TextEditingController;
    final amountFocusNode = item['amountFocusNode'] as FocusNode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: _t('固定費名', 'Fixed cost name'),
                    hintText: _t('家賃', 'Rent'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (_fixedCostControllers.length == 1) {
                      _resetSingleFixedCostItem(item);
                    } else {
                      _disposeFixedCostItem(item);
                      _fixedCostControllers.remove(item);
                    }
                    _syncFixedCostTotalFromSources();
                  });
                },
                icon: const Icon(Icons.delete_outline),
                tooltip: _t('固定費を削除', 'Delete fixed cost'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountController,
            focusNode: amountFocusNode,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _moneyInputFormatters(),
            onChanged: (_) {
              setState(() {
                _syncFixedCostTotalFromSources();
              });
            },
            decoration: InputDecoration(
              labelText: _t('金額', 'Amount'),
              hintText: _t('80,000', '1,200.00'),
              suffixText: _currentLang() == 'ja' ? '円' : null,
              prefixText: _currentLang() == 'ja' ? null : '\$',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _formatAllMoneyInputsOnBlur();
    await _persistValues();

    final isPremium = await _isPremiumUser();
    if (isPremium) {
      await IncomeFixedCostSyncService.sync(
        monthlyIncome: _income,
        fixedCostTotal: _fixedCost,
        items: _fixedCostControllers
            .map(
              (item) => {
                'name': (item['name'] as TextEditingController).text.trim(),
                'amount': _parseMoneyInput((item['amount'] as TextEditingController).text),
              },
            )
            .toList(),
      );
    }

    if (!mounted) return;

    Navigator.pop(context, {
      'income': _income,
      'fixedCost': _fixedCost,
      'usableAmount': _usableAmount,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_t('収入と固定費・貯金', 'Income, fixed costs & savings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  _t('今月の前提を決める', 'Set this month\'s base'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    '収入は任意です。固定費や貯金を引いたあとに、今月使えるお金を表示します。',
                    'Income is optional. We show how much you can spend this month after fixed costs and savings.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _incomeController,
                  focusNode: _incomeFocusNode,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: _moneyInputFormatters(),
                  decoration: InputDecoration(
                    labelText: _t('収入（任意）', 'Income (optional)'),
                    hintText: _t('200,000', '3,000.00'),
                    suffixText: _currentLang() == 'ja' ? '円' : null,
                    prefixText: _currentLang() == 'ja' ? null : '\$',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fixedCostTotalController,
                  focusNode: _fixedCostTotalFocusNode,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: _moneyInputFormatters(),
                  onChanged: (_) {
                    setState(() {
                      _syncManualFixedCostFromDisplayedTotal();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: _t('固定費・貯金（合計）', 'Fixed costs & savings (total)'),
                    hintText: _t('70,000', '1,000.00'),
                    suffixText: _currentLang() == 'ja' ? '円' : null,
                    prefixText: _currentLang() == 'ja' ? null : '\$',
                    border: const OutlineInputBorder(),
                    helperText: _itemizedFixedCostTotal > 0
                        ? _t(
                            '内訳合計 ${_formatMoneyDisplay(_itemizedFixedCostTotal)}',
                            'Itemized total ${_formatMoneyDisplay(_itemizedFixedCostTotal)}',
                          )
                        : _t('合計で入力できます', 'You can enter a total amount'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('固定費・貯金', 'Fixed costs & savings'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    'まとめて入力した金額と、下の内訳の合計を足して管理できます。',
                    'You can manage a total amount together with the itemized costs below.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ..._fixedCostControllers.map((item) => _buildFixedCostItem(theme, item)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _fixedCostControllers.add(_createFixedCostItem());
                        _syncFixedCostTotalFromSources();
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(_t('固定費を追加', 'Add fixed cost')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5EF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1E0D7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_isOverIncomeBase) ...[
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _isOverIncomeBase
                          ? _t('固定費・貯金が収入を超えています', 'Fixed costs exceed income')
                          : _t('今月使えるお金', 'Available this month'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _isOverIncomeBase ? Colors.red : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isOverIncomeBase
                      ? '-${_formatMoneyDisplay(_usableAmountRaw.abs())}'
                      : _formatMoneyDisplay(_usableAmount),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: _isOverIncomeBase ? Colors.red : null,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          '収入 ${_formatMoneyDisplay(_income)}',
                          'Income ${_formatMoneyDisplay(_income)}',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                          '固定費・貯金 ${_formatMoneyDisplay(_fixedCost)}',
                          'Fixed costs & savings ${_formatMoneyDisplay(_fixedCost)}',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _save,
              child: Text(_t('保存する', 'Save')),
            ),
          ),
        ],
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
                      onTap: () => FocusScope.of(context).unfocus(),
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