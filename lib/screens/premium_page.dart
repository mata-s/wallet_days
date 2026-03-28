import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:saiyome/services/expense_sync_service.dart';
import 'package:saiyome/services/budget_setting_sync_service.dart';
import 'package:saiyome/services/income_fixed_cost_sync_service.dart';
import 'package:saiyome/services/budget_history_sync_service.dart';
import 'package:saiyome/screens/backup_restore_page.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool _shouldShowRegisterPrompt() {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return false;
    return authUser.isAnonymous;
  }

  Package? _monthlyPackage;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isCompletingPurchase = false;
  bool _isPremium = false;
  String? _errorMessage;
  String? _lastBackupFailedStep;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offerings = await Purchases.getOfferings();
      final monthly = offerings.current?.monthly;
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.containsKey('premium');

      setState(() {
        _monthlyPackage = monthly;
        _isPremium = isPremium;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'プラン情報の取得に失敗しました';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchase() async {
    final package = _monthlyPackage;
    if (package == null) return;

    setState(() {
      _isPurchasing = true;
      _isCompletingPurchase = false;
      _errorMessage = null;
      _lastBackupFailedStep = null;
    });

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final isPremium =
          customerInfo.entitlements.active.containsKey('premium');

      if (!mounted) return;

      if (!isPremium) {
        setState(() {
          _errorMessage = '購入は完了しましたが、プレミアム状態を確認できませんでした';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _isCompletingPurchase = true;
        _isPremium = true;
      });

      final backupSucceeded = await _runInitialBackup();

      if (!mounted) return;

      if (backupSucceeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プレミアム登録が完了しました')),
        );
        if (_shouldShowRegisterPrompt()) {
          await _showRegisterPrompt();
        }
      } else {
        await _showBackupFailedDialog();
        if (!mounted) return;
        if (_shouldShowRegisterPrompt()) {
          await _showRegisterPrompt();
        }
      }

      Navigator.pop(context, true);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        setState(() {
          _errorMessage = '購入を完了できませんでした';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'エラーが発生しました';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isCompletingPurchase = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
      _isCompletingPurchase = false;
      _errorMessage = null;
      _lastBackupFailedStep = null;
    });

    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremium =
          customerInfo.entitlements.active.containsKey('premium');

      if (!mounted) return;

      if (isPremium) {
        setState(() {
          _isCompletingPurchase = true;
        });
        final backupSucceeded = await _runInitialBackup();

        if (!mounted) return;

        if (backupSucceeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('購入情報を復元しました')),
          );
          if (_shouldShowRegisterPrompt()) {
            await _showRegisterPrompt();
          }
        } else {
          await _showBackupFailedDialog();
          if (!mounted) return;
          if (_shouldShowRegisterPrompt()) {
            await _showRegisterPrompt();
          }
        }

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('復元できる購入情報がありませんでした')),
        );
      }
    } on PlatformException catch (_) {
      setState(() {
        _errorMessage = '復元に失敗しました';
      });
    } catch (e) {
      setState(() {
        _errorMessage = '復元に失敗しました';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isCompletingPurchase = false;
        });
      }
    }
  }

  Future<bool> _runInitialBackup() async {
    _lastBackupFailedStep = null;

    Future<bool> runStep(
      String stepName,
      Future<void> Function() action,
    ) async {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await action().timeout(const Duration(seconds: 12));
          return true;
        } catch (_) {
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 600));
          }
        }
      }

      _lastBackupFailedStep = stepName;
      return false;
    }

    final expensesSucceeded = await runStep('支出データ', () async {
      final expenses = await IsarService.getExpenses();
      await ExpenseSyncService.syncExpenses(expenses);
    });
    if (!expensesSucceeded) return false;

    final budgetSucceeded = await runStep('予算設定', () async {
      final budgetSetting = await IsarService.getBudgetSetting();
      if (budgetSetting != null) {
        await BudgetSettingSyncService.syncBudgetSetting(budgetSetting);
      }
    });
    if (!budgetSucceeded) return false;

    final incomeFixedCostSucceeded = await runStep('収入・固定費設定', () async {
      final incomeFixedCostSetting =
          await IsarService.getIncomeFixedCostSetting();
      if (incomeFixedCostSetting != null) {
        await IncomeFixedCostSyncService.sync(
          monthlyIncome: incomeFixedCostSetting.income,
          fixedCostTotal: incomeFixedCostSetting.fixedCostTotal,
          items: incomeFixedCostSetting.items
              .map((e) => {
                    'title': e.name,
                    'amount': e.amount,
                  })
              .toList(),
        );
      }
    });
    if (!incomeFixedCostSucceeded) return false;

    final historiesSucceeded = await runStep('予算履歴', () async {
      final histories = await IsarService.getBudgetHistories();
      await BudgetHistorySyncService.syncBudgetHistories(histories);
    });
    if (!historiesSucceeded) return false;

    return true;
  }

  Future<void> _showBackupFailedDialog() async {
    final failedStepText = _lastBackupFailedStep == null
        ? ''
        : '\n\n失敗した項目: $_lastBackupFailedStep';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('プレミアム登録は完了しました'),
          content: Text(
            '購入自体は完了していますが、初回バックアップに失敗しました。'
            '$failedStepText\n\n'
            '通信状況をご確認のうえ、もう一度お試しください。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _priceText() {
    final package = _monthlyPackage;
    if (package == null) return '月額 120円';
    return package.storeProduct.priceString;
  }

  String _periodText() {
    final package = _monthlyPackage;
    if (package == null) return '1ヶ月ごと';

    final period = package.storeProduct.subscriptionPeriod;
    if (period == null) return '1ヶ月ごと';

    final normalized = period.trim().toUpperCase();
    if (normalized.isEmpty) return '1ヶ月ごと';

    switch (normalized) {
      case 'P1W':
        return '1週間ごと';
      case 'P1M':
        return '1ヶ月ごと';
      case 'P2M':
        return '2ヶ月ごと';
      case 'P3M':
        return '3ヶ月ごと';
      case 'P6M':
        return '6ヶ月ごと';
      case 'P1Y':
        return '1年ごと';
      default:
        return period;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プレミアム'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'もっと便利に、もっと続けやすく',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'レポート・バッヂ・バックアップ・レシート機能を解放',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _priceText(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFEDEDED)),
                    ),
                    child: Text(
                      '自動更新サブスク ・ ${_periodText()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _featureCard(
              context,
              icon: Icons.insert_chart_outlined_rounded,
              title: 'レポート',
              description: '週・月の振り返りを見やすく確認できます',
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.emoji_events_outlined,
              title: 'バッヂ',
              description: 'やりくりの達成状況に応じて解放されます',
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.cloud_outlined,
              title: 'バックアップ',
              description: '大切なデータを保存して引き継げます',
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.receipt_long_outlined,
              title: 'レシート読み込み',
              description: '入力の手間を減らして、より続けやすくなります',
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (_isLoading || _isPurchasing || _monthlyPackage == null || _isPremium)
                    ? null
                    : _purchase,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isPremium
                            ? '登録中'
                            : _isCompletingPurchase
                                ? '登録中'
                                : _isPurchasing
                                    ? '購入中...'
                                    : '${_priceText()}で始める',
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '購入について',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '自動更新サブスクリプションです（${_periodText()}）\n'
                    'お支払いは購入確定時に、ご利用のアカウントに請求されます。\n'
                    '現在の期間終了の24時間以上前に解約しない限り自動で更新されます。\n'
                    '解約や管理は、ご利用端末のサブスクリプション設定画面から行えます。\n'
                    '表示価格は目安であり、実際の請求額や通貨はご利用のストアにより異なる場合があります。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isPurchasing ? null : _restorePurchases,
              child: const Text('購入を復元'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _showRegisterPrompt() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 38,
                    color: Color(0xFF4E6EF2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'メールアドレスを登録しよう',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'アカウントを作成して、\nデータを引き継げるようにしましょう。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '後で登録できます',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '※端末を変更する際は、事前に登録が必要です',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black45,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BackupRestorePage(
                            showSignUpTab: true,
                            initialIsSignUp: true,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E6EF2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '登録する',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('あとで'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}