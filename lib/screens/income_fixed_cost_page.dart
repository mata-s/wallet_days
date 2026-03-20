import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saiyome/models/isar_service.dart';

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
  final List<Map<String, TextEditingController>> _fixedCostControllers = [];
  final NumberFormat _formatter = NumberFormat('#,###');

  int get _income =>
      int.tryParse(_incomeController.text.replaceAll(',', '').trim()) ?? 0;

int get _manualFixedCostAmount =>
    int.tryParse(_fixedCostManualController.text.replaceAll(',', '').trim()) ?? 0;

int get _itemizedFixedCostTotal {
  int total = 0;
  for (final item in _fixedCostControllers) {
    final controller = item['amount']!;
    final value = int.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;
    total += value;
  }
  return total;
}

int get _fixedCost => _manualFixedCostAmount + _itemizedFixedCostTotal;

void _syncManualFixedCostFromDisplayedTotal() {
  final displayedTotal =
      int.tryParse(_fixedCostTotalController.text.replaceAll(',', '').trim()) ?? 0;
  final manualAmount = displayedTotal - _itemizedFixedCostTotal;
  _fixedCostManualController.text = manualAmount > 0
      ? _formatter.format(manualAmount)
      : '';
}

  int get _usableAmount {
    final value = _income - _fixedCost;
    return value < 0 ? 0 : value;
  }

  @override
  void initState() {
    super.initState();

    _incomeController.addListener(_handleChanged);
    _fixedCostTotalController.addListener(_handleChanged);
    _fixedCostManualController.addListener(_handleChanged);

    _fixedCostControllers.add(_createFixedCostItem());

    _loadSavedValues();
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  Map<String, TextEditingController> _createFixedCostItem({
    String name = '',
    String amount = '',
  }) {
    final item = {
      'name': TextEditingController(text: name),
      'amount': TextEditingController(text: amount),
    };
    item['name']!.addListener(_handleChanged);
    item['amount']!.addListener(_handleChanged);
    return item;
  }

  void _disposeFixedCostItem(Map<String, TextEditingController> item) {
    item['name']!.removeListener(_handleChanged);
    item['amount']!.removeListener(_handleChanged);
    item['name']!.dispose();
    item['amount']!.dispose();
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

    _incomeController.text =
        initialIncome > 0 ? _formatter.format(initialIncome) : '';

    if (saved != null && saved.items.isNotEmpty) {
      for (final entry in saved.items) {
        _fixedCostControllers.add(
          _createFixedCostItem(
            name: entry.name,
            amount: entry.amount > 0 ? _formatter.format(entry.amount) : '',
          ),
        );
      }
    }

    if (_fixedCostControllers.isEmpty) {
      _fixedCostControllers.add(_createFixedCostItem());
    }

    final itemizedTotal = _fixedCostControllers.fold<int>(
      0,
      (sum, item) =>
          sum +
          (int.tryParse(item['amount']!.text.replaceAll(',', '').trim()) ?? 0),
    );
    final manualAmount = initialFixedCost - itemizedTotal;
    _fixedCostManualController.text = manualAmount > 0
        ? _formatter.format(manualAmount)
        : '';
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
              'name': item['name']!.text.trim(),
              'amount': int.tryParse(
                    item['amount']!.text.replaceAll(',', '').trim(),
                  ) ??
                  0,
            },
          )
          .toList(),
    );
  }

  @override
  void dispose() {
    _incomeController.removeListener(_handleChanged);
    _fixedCostTotalController.removeListener(_handleChanged);
    _fixedCostManualController.removeListener(_handleChanged);
    _incomeController.dispose();
    _fixedCostTotalController.dispose();
    _fixedCostManualController.dispose();
    for (final item in _fixedCostControllers) {
      _disposeFixedCostItem(item);
    }
    super.dispose();
  }

void _syncFixedCostTotalFromSources() {
  final total = _fixedCost;
  _fixedCostTotalController.text =
      total == 0 ? '' : _formatter.format(total);
}

  void _resetSingleFixedCostItem(Map<String, TextEditingController> item) {
    item['name']!.clear();
    item['amount']!.clear();
  }

  Widget _buildFixedCostItem(ThemeData theme, Map<String, TextEditingController> item) {
    final nameController = item['name']!;
    final amountController = item['amount']!;

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
                  decoration: const InputDecoration(
                    labelText: '固定費名',
                    hintText: '家賃',
                    border: OutlineInputBorder(),
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
                tooltip: '固定費を削除',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              MoneyThousandsFormatter(),
            ],
            onChanged: (_) {
              setState(() {
                _syncFixedCostTotalFromSources();
              });
            },
            decoration: const InputDecoration(
              labelText: '金額',
              hintText: '80,000',
              suffixText: '円',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _persistValues();

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
    
  return Scaffold (
      appBar: AppBar(
        centerTitle: true,
        title: const Text('収入と固定費・貯金'),
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
                  '今月の前提を決める',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '収入は任意です。固定費や貯金を引いたあとに、今月使えるお金を表示します。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _incomeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    MoneyThousandsFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: '収入（任意）',
                    hintText: '200,000',
                    suffixText: '円',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fixedCostTotalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    MoneyThousandsFormatter(),
                  ],
                  onChanged: (_) {
                    setState(() {
                      _syncManualFixedCostFromDisplayedTotal();
                      _syncFixedCostTotalFromSources();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: '固定費・貯金（合計）',
                    hintText: '70,000',
                    suffixText: '円',
                    border: const OutlineInputBorder(),
                    helperText: _itemizedFixedCostTotal > 0
                        ? '内訳合計 ¥${_formatter.format(_itemizedFixedCostTotal)}'
                        : '合計で入力できます',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '固定費・貯金',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'まとめて入力した金額と、下の内訳の合計を足して管理できます。',
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
                    label: const Text('固定費を追加'),
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
                Text(
                  '今月使えるお金',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¥${_formatter.format(_usableAmount)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
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
                        '収入 ¥${_formatter.format(_income)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '固定費・貯金 ¥${_formatter.format(_fixedCost)}',
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
              child: const Text('保存する'),
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
                      child: const Text(
                        '完了',
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