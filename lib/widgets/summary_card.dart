import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryCard extends StatelessWidget {
  final String? languageCode;

  bool _isJa(BuildContext context) {
    return (languageCode ?? Localizations.localeOf(context).languageCode) == 'ja';
  }

  String _t(BuildContext context, String ja, String en) {
    return _isJa(context) ? ja : en;
  }

  String _formatMoney(BuildContext context, int amount) {
    final isJa = _isJa(context);
    final formatter = NumberFormat('#,###');
    if (isJa) {
      return '¥${formatter.format(amount)}';
    }
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount / 100);
  }
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
  final String? characterImagePath;

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
    this.characterImagePath,
    this.languageCode,
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
              _t(context, 'この期間の残り予算', 'Remaining budget for this period'),
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
                        _t(context, '$cyclePeriod ・ 残り$remainingPeriodDays日', '$cyclePeriod ・ $remainingPeriodDays days left'),
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
                    clampNegativeToZeroDisplay: true,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                    languageCode: languageCode,
                  ),
            const SizedBox(height: 6),
            Text(
              _t(context, 'この期間で今使える残りのお金', 'Money you can still use in this period'),
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
                    final hasBudget = totalBudget != null && totalBudget! > 0;
                    final progress = !hasBudget
                        ? 0.0
                        : (usedAmount! / totalBudget!).clamp(0.0, 1.0);
                    final showCharacter =
                        !isLoading && characterImagePath != null;

                    String _getAdvice(double progress) {
                      if (!hasBudget) {
                        final advices = [
                          _t(context, 'まずは予算を決めると、財布の余命が見えてくるよ', 'Set a budget first, then your wallet life will become visible.'),
                          _t(context, '予算を入れると、ここからペースを見られるようになるよ', 'Add a budget to start tracking your pace from here.'),
                          _t(context, 'まだ作戦前だね。予算を決めたら一緒に見ていこう', 'No plan yet. Set a budget and we’ll track it together.'),
                          _t(context, '比較する予算がまだないから、今は準備中だね', 'There is no budget to compare yet, so this is still setup mode.'),
                        ];
                        advices.shuffle();
                        return advices.first;
                      }
                      final List<String> advices = progress >= 1
                          ? [
                              _t(context, '来月に期待だね', 'Let’s reset next month.'),
                              _t(context, '今月はここまでだね', 'That may be it for this month.'),
                              _t(context, '今回はちょっと使いすぎたね', 'You spent a little too much this time.'),
                              _t(context, '次の期間に向けて作戦を変えよう', 'Let’s change the plan for the next period.'),
                            ]
                          : progress >= 0.9
                              ? [
                                  _t(context, 'ここからは少し慎重にいこう', 'Let’s be careful from here.'),
                                  _t(context, 'あと少し、バランス大事だよ', 'Just a little left. Balance matters.'),
                                  _t(context, '終盤戦、ちょっとだけ意識しよう', 'Final stretch. Spend with care.'),
                                  _t(context, '残り日数を見ながら整えていこう', 'Keep an eye on the days left.'),
                                ]
                              : progress >= 0.75
                                  ? [
                                      _t(context, 'ここから少し意識していこう', 'Start paying a little more attention.'),
                                      _t(context, '油断は禁物', 'Don’t let your guard down.'),
                                      _t(context, 'ここから少しだけ引き締めよう', 'Time to tighten things up a bit.'),
                                    ]
                                  : progress >= 0.5
                                      ? [
                                          _t(context, '予定外の支出だけ見張っておこう', 'Watch out for unexpected spending.'),
                                          _t(context, 'この調子なら無理なく進めそう', 'This pace looks manageable.'),
                                          _t(context, '必要なものはちゃんと買って大丈夫', 'It’s okay to buy what you need.'),
                                          _t(context, 'このままいこう', 'Keep it going.'),
                                        ]
                                      : [
                                          _t(context, '今のうちに少し貯金側へ回せるかも', 'You might be able to save a little now.'),
                                          _t(context, '使う日と抑える日の差をつけやすいね', 'You have room to balance spend days and quiet days.'),
                                          _t(context, '後半に備えて余力を残しておこう', 'Keep some room for later.'),
                                        ];
                      advices.shuffle();
                      return advices.first;
                    }

                    String _getStatusLabel(double progress) {
                      if (!hasBudget) {
                        final labels = [
                          _t(context, '予算未設定だよ', 'No budget set'),
                          _t(context, 'まずは予算決めから', 'Start with a budget'),
                          _t(context, '作戦準備中だね', 'Plan setup mode'),
                        ];
                        labels.shuffle();
                        return labels.first;
                      }
                      final List<String> labels = progress >= 1
                          ? [
                              _t(context, '作戦変更だ…', 'Time to change the plan...'),
                              _t(context, '予算オーバー中だよ', 'Over budget'),
                            ]
                          : progress >= 0.9
                              ? [
                                  _t(context, '残りわずか', 'Almost out'),
                                  _t(context, 'もうすぐ限界かも…', 'Almost at the limit...'),
                                ]
                              : progress >= 0.75
                                  ? [
                                      _t(context, '注意ゾーンだよ', 'Caution zone'),
                                      _t(context, '慎重にいこう', 'Go carefully'),
                                    ]
                                  : progress >= 0.5
                                      ? [
                                          _t(context, '安定ペースだよ', 'Steady pace'),
                                          _t(context, 'いいペースだね', 'Good pace'),
                                        ]
                                      : [
                                          _t(context, '余裕ゾーンだね', 'Comfort zone'),
                                          _t(context, 'かなり余裕あるよ', 'Plenty of room'),
                                        ];
                      labels.shuffle();
                      return labels.first;
                    }

                    final statusLabel = _getStatusLabel(progress);
                    final advice = _getAdvice(progress);

                    return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _t(context, '全体の予算状況', 'Overall budget status'),
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
                      languageCode: languageCode,
                    ),
                    Text(
                      ' / ${_formatMoney(context, totalBudget!)}',
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
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: progress >= 1
                          ? const Color(0xFFFFCDD2)
                          : progress >= 0.75
                              ? const Color(0xFFFFE0B2)
                              : const Color(0xFFC8E6C9),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isLoading
                      ? skeleton(width: 110, height: 16, radius: 8)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: progress >= 1
                                    ? Colors.red
                                    : progress >= 0.75
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              advice,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (showCharacter) ...[
                const SizedBox(width: 10),
                IgnorePointer(
                  child: Image.asset(
                    characterImagePath!,
                    width: 76,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
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
                        child: Text(
                          _t(context, '財布の余命', 'Wallet life'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  isLoading
                      ? skeleton(width: 120, height: 28, radius: 10)
                      : _AnimatedCountText(
                          value: walletLifeDays,
                          prefix: _t(context, 'あと約', 'About '),
                          suffix: _t(context, '日分', ' days left'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                  const SizedBox(height: 3),
                  Text(
                    _t(
                      context,
                      'このペースで使った場合の目安',
                      'Estimated at your current pace',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
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
                                    _isJa(context)
                                      ? 'あなたの1日平均支出：約¥${formatter.format(dailySpendingPaceYen)}'
                                      : 'Your daily average: ${_formatMoney(context, dailySpendingPaceYen!)}',
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
                                    _isJa(context)
                                      ? '日割りで使える目安：約¥${formatter.format(plannedDailyBudgetYen)}'
                                      : 'Daily budget: ${_formatMoney(context, plannedDailyBudgetYen!)}',
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
                          _t(context, '財布のひとこと', 'Wallet note'),
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
  final bool clampNegativeToZeroDisplay;
  final String? languageCode;

  const _AnimatedYenText({
    required this.value,
    required this.style,
    this.clampNegativeToZeroDisplay = false,
    this.languageCode,
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
        final rounded = value.round();
        final isJa = (widget.languageCode ?? Localizations.localeOf(context).languageCode) == 'ja';

        String format(int v) {
          if (isJa) return '¥${formatter.format(v)}';
          return NumberFormat.currency(
            locale: 'en_US',
            symbol: '\$',
            decimalDigits: 2,
          ).format(v / 100);
        }

        final text = widget.clampNegativeToZeroDisplay && rounded < 0
            ? isJa
                ? '¥0（-${format(rounded.abs())}）'
                : '${format(0)} (-${format(rounded.abs())})'
            : format(rounded);

        return Text(
          text,
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