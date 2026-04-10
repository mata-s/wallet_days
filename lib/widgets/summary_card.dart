import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryCard extends StatelessWidget {
  final bool isLoading;
  final int remainingBudget;
  final int walletLifeDays;
  final int remainingPeriodDays;
  final int? dailySpendingPaceYen;
  final int? plannedDailyBudgetYen;
  final int? totalBudget;
  final int? usedAmount;
  final String? remainingTitle;
  final String? remainingMessage;
  final String? remainingSubMessage;
  final String? cyclePeriod;

  const SummaryCard({
    super.key,
    required this.isLoading,
    required this.remainingBudget,
    required this.walletLifeDays,
    required this.remainingPeriodDays,
    this.dailySpendingPaceYen,
    this.plannedDailyBudgetYen,
    this.totalBudget,
    this.usedAmount,
    this.remainingTitle,
    this.remainingMessage,
    this.remainingSubMessage,
    this.cyclePeriod,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat('#,###');

    Widget skeleton({double width = 80, double height = 18, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFECE7E2),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Card(
      key: ValueKey(cyclePeriod),
      elevation: 1,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'この期間の残り予算',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (cyclePeriod != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F1EC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: isLoading
                    ? skeleton(width: 132, height: 14, radius: 999)
                    : Text(
                        '$cyclePeriod ・ 残り$remainingPeriodDays日',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 10),
            isLoading
                ? skeleton(width: 180, height: 40, radius: 12)
                : _AnimatedYenText(
                  value: remainingBudget,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                      ),
                    ),
            const SizedBox(height: 6),
            Text(
              'この期間で今使える残りのお金',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            if (totalBudget != null && usedAmount != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Builder(
                  builder: (context) {
                    final progress =
                        totalBudget == 0 ? 0.0 : (usedAmount! / totalBudget!).clamp(0.0, 1.0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '全体の予算状況',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: progress >= 1
                                    ? const Color(0xFFFFEBEE)
                                    : progress >= 0.75
                                        ? const Color(0xFFFFF3E0)
                                        : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: isLoading
                                  ? skeleton(width: 34, height: 12, radius: 999)
                                  : Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: progress >= 1
                                            ? Colors.red
                                            : progress >= 0.75
                                                ? Colors.orange
                                                : Colors.green,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        isLoading
                            ? skeleton(width: 150, height: 22, radius: 8)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _AnimatedYenText(
                                    value: usedAmount!,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    ' / ¥${formatter.format(totalBudget)}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1
                                  ? Colors.red
                                  : progress >= 0.75
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: progress >= 1
                                    ? Colors.red
                                    : progress >= 0.75
                                        ? Colors.orange
                                        : Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: isLoading
                                  ? skeleton(width: 110, height: 16, radius: 8)
                                  : Text(
                                      progress >= 1
                                          ? '予算オーバーしています'
                                          : progress >= 0.75
                                              ? '残りわずかです'
                                              : 'まだ余裕があります',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: progress >= 1
                                            ? Colors.red
                                            : progress >= 0.75
                                                ? Colors.orange
                                                : Colors.green,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EA),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.favorite_outline,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '財布の余命',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            isLoading
                                ? skeleton(width: 120, height: 28, radius: 10)
                                : _AnimatedCountText(
                                       value: walletLifeDays,
                                       prefix: 'あと約',
                                       suffix: '日分',
                                       style: theme.textTheme.headlineSmall?.copyWith(
                                         fontWeight: FontWeight.w800,
                                         letterSpacing: -0.3,
                                      ),
                                    ),
                            const SizedBox(height: 3),
                            Text(
                              'このペースで使った場合の目安',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (dailySpendingPaceYen != null || plannedDailyBudgetYen != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dailySpendingPaceYen != null)
                            isLoading
                                ? skeleton(width: 190, height: 16, radius: 8)
                                : Text(
                                    'あなたの1日平均支出：約¥${formatter.format(dailySpendingPaceYen)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                          if (dailySpendingPaceYen != null && plannedDailyBudgetYen != null)
                            const SizedBox(height: 6),
                          if (plannedDailyBudgetYen != null)
                            isLoading
                                ? skeleton(width: 180, height: 16, radius: 8)
                                : Text(
                                    '日割りで使える目安：約¥${formatter.format(plannedDailyBudgetYen)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (remainingMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '財布のひとこと',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    if (remainingSubMessage != null) ...[
                      const SizedBox(height: 8),
                      isLoading
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                skeleton(width: double.infinity, height: 16, radius: 8),
                                const SizedBox(height: 8),
                                skeleton(width: 180, height: 16, radius: 8),
                              ],
                            )
                          : Text(
                              remainingSubMessage!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.black87,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimatedYenText extends StatefulWidget {
  final int value;
  final TextStyle? style;

  const _AnimatedYenText({
    required this.value,
    required this.style,
  });

  @override
  State<_AnimatedYenText> createState() => _AnimatedYenTextState();
}

class _AnimatedYenTextState extends State<_AnimatedYenText> {
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AnimatedYenText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '¥${formatter.format(value.round())}',
          style: widget.style,
        );
      },
    );
  }
}

class _AnimatedCountText extends StatefulWidget {
  final int value;
  final String prefix;
  final String suffix;
  final TextStyle? style;

  const _AnimatedCountText({
    required this.value,
    required this.prefix,
    required this.suffix,
    required this.style,
  });

  @override
  State<_AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<_AnimatedCountText> {
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AnimatedCountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${widget.prefix}${value.round()}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}