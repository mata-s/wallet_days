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
    required int totalBudget,
    required int usedAmount,
    DateTime? cycleStart,
    DateTime? cycleEnd,
  }) {
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
        title: '財布の余命',
        message: '予算がまだ設定されていません',
        subMessage: _pick([
          'まずは今月の予算を決めてみましょう。',
          'スタート地点がまだ決まっていません。',
          'ここが決まると一気に見えやすくなります。',
          'ここから全部決まります。',
          'まず土台です。ここがないと何も始まりません。',
        ]),
      );
    }

    if (remaining <= 0) {
      return RemainingBudgetResult(
        title: '財布の余命',
        message: '予算オーバーです',
        subMessage: _pick([
          '未来の自分がちょっと困っています。',
          '今月はすでに延長戦に入っています。',
          'ここからは完全に追加ラウンドです。',
          'もう戻れません。ここからは記録だけです。',
          'ここ、完全にオーバーラインです。',
        ]),
      );
    }

    if (usageRate >= 0.95) {
      return RemainingBudgetResult(
        title: '財布の余命',
        message: '残り$remaining円',
        subMessage: _pick([
          'かなりギリギリです。ほぼ終盤です。',
          'ここまで来ると、一手ミスると終わります。',
          '残りはありますが、かなりシビアです。',
          'もう余裕とは呼べないゾーンです。',
          '終盤戦、かなりハードです。',
        ]),
      );
    }

    if (usageRate >= 0.85) {
      return RemainingBudgetResult(
        title: '財布の余命',
        message: '残り$remaining円',
        subMessage: _pick([
          'だいぶ削られてきています。',
          'もやし生活見えてきました。',
          'ここから先は慎重にいきたいところです。',
          'かなり終盤感が出てきました。',
          '残りはありますが、油断できません。',
          '少しずつではなく、ちゃんと減っています。',
        ]),
      );
    }

    if (usageRate >= 0.7) {
      final isAhead = progressRate > 0 && usageRate > progressRate + 0.15;
      return RemainingBudgetResult(
        title: '財布の余命',
        message: '残り$remaining円',
        subMessage: _pick(
          isAhead
              ? [
                  '期間の進み方より、少し使うペースが早めです。',
                  '今の時点としては、やや前のめりです。',
                  'まだ持ちますが、このペースは少し気になります。',
                  '使い方としては、少しだけ先行しています。',
                  '余裕ゼロではないですが、ペースは見ておきたいです。',
                ]
              : [
                  'ここからどう使うかが大事です。',
                  '少しずつ終盤が見えてきました。',
                  '今ならまだ十分立て直せます。',
                  'ここからの使い方でかなり変わります。',
                  'まだ戦えます。ここからが本番です。',
                ],
        ),
      );
    }

    if (usageRate >= 0.5) {
      final isBehind = progressRate > 0 && usageRate < progressRate - 0.15;
      final isAhead = progressRate > 0 && usageRate > progressRate + 0.1;
      return RemainingBudgetResult(
        title: '財布の余命',
        message: '残り$remaining円',
        subMessage: _pick(
          isBehind
              ? [
                  '今のところ、かなり良いペースです。',
                  '期間の進み方より、上手く抑えられています。',
                  'このままいけると、かなり安定しそうです。',
                  '中盤としては、かなり優秀です。',
                  '余裕を作れている流れです。',
                ]
              : isAhead
                  ? [
                      '中盤としては、少しペースが早めです。',
                      'まだ危険ではありませんが、進み方は見ておきたいです。',
                      'このまま行くと、後半が少し重くなるかもしれません。',
                      '今ならまだ調整できます。',
                      '少し前のめりですが、まだ戻せます。',
                    ]
                  : [
                      'まだ落ち着いています。',
                      '今のところ、悪くない流れです。',
                      '中盤としては、かなり自然です。',
                      'この感じなら、まだコントロールできています。',
                      '今のところ順調です。',
                    ],
        ),
      );
    }

    final isEarly = progressRate <= 0.35;
    return RemainingBudgetResult(
      title: '財布の余命',
      message: '残り$remaining円',
      subMessage: _pick(
        isEarly
            ? [
                'まだかなり余裕があります。',
                '出だしとしては良い感じです。',
                '今の時点では、かなり落ち着いています。',
                'まだ序盤なので、余裕はしっかりあります。',
                'ここから全部決まります。良いスタートです。',
              ]
            : [
                '今のところ余裕があります。',
                'まだ落ち着いています。',
                'いい流れです。',
                'かなり順調です。',
                'この感じ、かなり良いです。',
              ],
      ),
    );
  }
}