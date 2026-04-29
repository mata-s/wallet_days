import 'package:flutter/material.dart';

class StreakInsightCard extends StatelessWidget {
  final int? bestPercent;
  final int? currentPercent;
  final int? cohortPercent;
  final int? nextGoal;
  final String? streakType;
  final String? nextStepMessage;
  final String? encouragementMessage;
  final VoidCallback? onTap;
  final String? languageCode;

  const StreakInsightCard({
    super.key,
    this.bestPercent,
    this.currentPercent,
    this.cohortPercent,
    this.nextGoal,
    this.streakType,
    this.nextStepMessage,
    this.encouragementMessage,
    this.onTap,
    this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final currentLang = languageCode ?? Localizations.localeOf(context).languageCode;

    String t(String ja, String en) {
      return currentLang == 'ja' ? ja : en;
    }

    String topPercentLabel(int percent) {
      return currentLang == 'ja' ? '上位$percent%' : 'Top $percent%';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F2F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: Color(0xFFFF8A65),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t('あなたの継続力', 'Your streak power'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              if (streakType != null && streakType!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEE7).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      streakType!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF8A65),
                      ),
                    ),
                  ),
                ),
              ],
              if (currentPercent != null || bestPercent != null || cohortPercent != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (currentPercent != null)
                      _StatChip(label: t('現在', 'Current'), value: topPercentLabel(currentPercent!)),
                    if (bestPercent != null)
                      _StatChip(label: t('最高', 'Best'), value: topPercentLabel(bestPercent!)),
                    if (cohortPercent != null)
                      _StatChip(label: t('同期', 'Cohort'), value: topPercentLabel(cohortPercent!)),
                  ],
                ),
              ],
              if (nextGoal != null) ...[
                const SizedBox(height: 14),
                Text(
                  t('次の目標：あと$nextGoal回', 'Next goal: $nextGoal more'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
              if (nextStepMessage != null && nextStepMessage!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  nextStepMessage!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ],
              if (encouragementMessage != null && encouragementMessage!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  encouragementMessage!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
                    height: 1.55,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatefulWidget {
  final String label;
  final String value;

  const _StatChip({
    required this.label,
    required this.value,
  });

  @override
  State<_StatChip> createState() => _StatChipState();
}

class _StatChipState extends State<_StatChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowAnimation = Tween<double>(begin: 0.18, end: 0.34).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int? percent;
    final match = RegExp(r'(\d+)').firstMatch(widget.value);
    if (match != null) {
      percent = int.tryParse(match.group(1)!);
    }

    Color backgroundColor = Colors.white;
    Color borderColor = const Color(0xFFEDEDED);

    if (percent != null) {
      if (percent <= 10) {
        backgroundColor = const Color(0xFFFFF4CC); // ゴールド
        borderColor = const Color(0xFFFFD54F);
      } else if (percent <= 30) {
        backgroundColor = const Color(0xFFFFE5D9); // オレンジ
        borderColor = const Color(0xFFFF8A65);
      } else if (percent <= 40) {
        backgroundColor = const Color(0xFFF1F2F6); // グレー
        borderColor = const Color(0xFFDADCE0);
      }
    }
    final shouldGlow = percent != null && percent <= 10;
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: shouldGlow
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD54F)
                          .withOpacity(_glowAnimation.value),
                      blurRadius: 14,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}