class RemainingBudgetResult {
  final String title;
  final String message;
  final String subMessage;

  const RemainingBudgetResult({
    required this.title,
    required this.message,
    required this.subMessage,
  });
}

class RemainingBudgetService {
  static String _pick(List<String> list) {
    final now = DateTime.now();
    final index = (now.millisecondsSinceEpoch ~/ 1000) % list.length;
    return list[index];
  }

  static String _normalizeLang(String? languageCode) {
    return languageCode == 'en' ? 'en' : 'ja';
  }

  static bool _isEnglish(String languageCode) {
    return _normalizeLang(languageCode) == 'en';
  }

  static String _t(String languageCode, String ja, String en) {
    return _isEnglish(languageCode) ? en : ja;
  }

  static String _formatMoney(int amount, String languageCode) {
    if (_isEnglish(languageCode)) {
      final dollars = amount / 100.0;
      return '\$${dollars.toStringAsFixed(2)}';
    }
    return '$amount円';
  }

  static String _title(String languageCode) {
    return _t(languageCode, '財布の余命', 'Wallet life');
  }

  static double _cycleProgress({
    required DateTime cycleStart,
    required DateTime cycleEnd,
    required DateTime now,
  }) {
    final start = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
    final end = DateTime(cycleEnd.year, cycleEnd.month, cycleEnd.day);
    final today = DateTime(now.year, now.month, now.day);

    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return 0.0;

    final elapsedDays = today.difference(start).inDays.clamp(0, totalDays);
    return elapsedDays / totalDays;
  }

  static RemainingBudgetResult build({
    String languageCode = 'ja',
    required int totalBudget,
    required int usedAmount,
    DateTime? cycleStart,
    DateTime? cycleEnd,
  }) {
    final lang = _normalizeLang(languageCode);
    final isEn = _isEnglish(lang);

    final remaining = totalBudget - usedAmount;

    final usageRate = totalBudget <= 0 ? 0.0 : usedAmount / totalBudget;
    final now = DateTime.now();
    final progressRate = cycleStart != null && cycleEnd != null
        ? _cycleProgress(
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            now: now,
          )
        : 0.0;

    if (totalBudget == 0) {
      return RemainingBudgetResult(
        title: _title(lang),
        message: _t(lang, '予算、まだないよ', 'No budget set yet'),
        subMessage: _pick(isEn
            ? [
                'Set a rough monthly limit first. Your wallet needs a map before it can complain properly.',
                'No starting line yet. Once you set one, the month gets much easier to read.',
                'A simple limit is enough. The wallet just needs something to measure against.',
                'Start with the foundation. Everything gets clearer after that.',
                'Without a limit, even the wallet life meter has no idea what it is measuring.',
              ]
            : [
                'まずは今月の上限を決めてみるか。',
                'スタート地点がまだ決まってないよ。',
                'ここが決まると、一気に見えやすくなるよ。',
                'まず土台だね。ここから全部決まるよ。',
                '上限がないと、財布も余命を測れないよ。',
              ]),
      );
    }

    if (remaining <= 0) {
      return RemainingBudgetResult(
        title: _title(lang),
        message: _t(lang, 'もうオーバーしてるね', 'You are over budget'),
        subMessage: _pick(isEn
            ? [
                'This month has entered overtime. The wallet noticed.',
                'The line has been crossed. Now it is all about landing softly.',
                'This is officially extra-round spending. Not ideal, but still trackable.',
                'Past the limit now. The goal is damage control, not panic.',
                'That is the over-budget zone. The wallet is not yelling, just staring.',
              ]
            : [
                '来月の自分に少し響きそうだね。',
                '今月はもう延長戦に入ってるよ。',
                'ここからは完全に追加ラウンドだね。',
                '戻れないラインは越えてるね。あとは着地だよ。',
                'ここ、完全にオーバーラインだね。',
              ]),
      );
    }

    if (usageRate >= 0.95) {
      return RemainingBudgetResult(
        title: _title(lang),
        message: _t(lang, '残り${_formatMoney(remaining, lang)}', '${_formatMoney(remaining, lang)} left'),
        subMessage: _pick(isEn
            ? [
                'This is very tight. Basically the final boss of the month.',
                'One wrong move could feel pretty heavy from here.',
                'There is still money left, but the margin is thin.',
                'This is not what anyone would call comfortable anymore.',
                'Late-game budgeting. Definitely hard mode.',
              ]
            : [
                'かなりギリギリだね。ほぼ終盤だよ。',
                'ここまで来ると、一手ミスると重いね。',
                '残りはあるけど、かなりシビアだよ。',
                'もう余裕とは呼べないゾーンだね。',
                '終盤戦、かなりハードだね。',
              ]),
      );
    }

    if (usageRate >= 0.85) {
      return RemainingBudgetResult(
        title: _title(lang),
        message: _t(lang, '残り${_formatMoney(remaining, lang)}', '${_formatMoney(remaining, lang)} left'),
        subMessage: _pick(isEn
            ? [
                'It has been shaved down quite a bit.',
                'The budget is starting to look a little thin.',
                'From here, small choices start to matter more.',
                'The late-month feeling is showing up.',
                'There is still some left, but this is not a place to get casual.',
                'It is not disappearing slowly anymore. The wallet has notes.',
              ]
            : [
                'だいぶ削られてきたね。',
                'もやし生活、少し見えてきたね。',
                'ここから先は慎重にいきたいところだよ。',
                'かなり終盤感が出てきたね。',
                '残りはあるけど、油断できないね。',
                '少しずつじゃなくて、ちゃんと減ってるよ。',
              ]),
      );
    }

    if (usageRate >= 0.7) {
      final isAhead = progressRate > 0 && usageRate > progressRate + 0.15;
      return RemainingBudgetResult(
        title: _title(lang),
        message: _t(lang, '残り${_formatMoney(remaining, lang)}', '${_formatMoney(remaining, lang)} left'),
        subMessage: _pick(
          isAhead
              ? isEn
                  ? [
                      'Your spending pace is a bit ahead of the calendar.',
                      'For this point in the period, it is leaning a little forward.',
                      'It can still last, but this pace is worth watching.',
                      'The spending is slightly ahead of schedule.',
                      'Not zero room, but the pace deserves attention.',
                    ]
                  : [
                      '期間より、使うペースが少し早めだね。',
                      '今の時点としては、やや前のめりだよ。',
                      'まだ持つけど、このペースは少し気になるね。',
                      '使い方としては、少し先行してるね。',
                      '余裕ゼロではないけど、ペースは見ておきたいよ。',
                    ]
              : isEn
                  ? [
                      'What happens from here matters.',
                      'The end of the period is starting to come into view.',
                      'You can still adjust from here.',
                      'The rest of the month can still change the story.',
                      'Still in the fight. This is where the month gets interesting.',
                    ]
                  : [
                      'ここからどう使うかが大事だね。',
                      '少しずつ終盤が見えてきたね。',
                      '今ならまだ整えられるね。',
                      'ここからの使い方でかなり変わるね。',
                      'まだ戦えるね。ここからが本番だね。',
                    ],
        ),
      );
    }

    if (usageRate >= 0.5) {
      final isBehind = progressRate > 0 && usageRate < progressRate - 0.15;
      final isAhead = progressRate > 0 && usageRate > progressRate + 0.1;
      return RemainingBudgetResult(
        title: _title(lang),
        message: _t(lang, '残り${_formatMoney(remaining, lang)}', '${_formatMoney(remaining, lang)} left'),
        subMessage: _pick(
          isBehind
              ? isEn
                  ? [
                      'So far, this is a pretty strong pace.',
                      'You are spending slower than the period is moving. Nice.',
                      'If this continues, the month could stay very stable.',
                      'For the middle of the period, this is honestly solid.',
                      'You are creating some breathing room.',
                    ]
                  : [
                      '今のところ、かなりいいペースだね。',
                      '期間より、うまく抑えられてるよ。',
                      'このままいけると、かなり安定しそうだね。',
                      '中盤としては、かなり優秀だよ。',
                      '余裕を作れてる流れだね。',
                    ]
              : isAhead
                  ? isEn
                      ? [
                          'For the middle of the period, the pace is a little fast.',
                          'Not dangerous yet, but worth watching.',
                          'At this rate, the second half may feel heavier.',
                          'You can still adjust from here.',
                          'A little forward-leaning, but not out of control.',
                        ]
                      : [
                          '中盤としては、少しペース早めだね。',
                          'まだ危険ではないけど、進み方は見ておきたいよ。',
                          'このままだと、後半が少し重くなるかもね。',
                          '今ならまだ調整できるよ。',
                          '少し前のめりだけど、まだ戻せるね。',
                        ]
                  : isEn
                      ? [
                          'Still pretty calm.',
                          'So far, not a bad flow at all.',
                          'For the middle of the period, this feels natural.',
                          'Looks like things are still under control.',
                          'So far, steady enough.',
                        ]
                      : [
                          'まだ落ち着いてるね。',
                          '今のところ、悪くない流れだよ。',
                          '中盤としては、かなり自然だね。',
                          'この感じなら、まだコントロールできてるよ。',
                          '今のところ順調だね。',
                        ],
        ),
      );
    }

    final isEarly = progressRate <= 0.35;
    return RemainingBudgetResult(
      title: _title(lang),
      message: _t(lang, '残り${_formatMoney(remaining, lang)}', '${_formatMoney(remaining, lang)} left'),
      subMessage: _pick(
        isEarly
            ? isEn
                ? [
                    'Still plenty of room.',
                    'Good start so far.',
                    'At this point, things are looking calm.',
                    'Still early, and there is real room left.',
                    'The month is still young. Nice opening move.',
                  ]
                : [
                    'まだかなり余裕あるね。',
                    '出だしとしてはいい感じだよ。',
                    '今の時点では、かなり落ち着いてるね。',
                    'まだ序盤だね。余裕はしっかりあるよ。',
                    'ここから全部決まるね。いいスタートだよ。',
                  ]
            : isEn
                ? [
                    'Still some comfortable room left.',
                    'Things are still calm.',
                    'Good flow so far.',
                    'This is looking pretty steady.',
                    'This pace feels good.',
                  ]
                : [
                    '今のところ余裕あるね。',
                    'まだ落ち着いてるね。',
                    'いい流れだね。',
                    'かなり順調だね。',
                    'この感じ、かなりいいね。',
                  ],
      ),
    );
  }
}