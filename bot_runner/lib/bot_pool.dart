import 'dart:math';

import 'bot_client.dart';

/// 봇 풀 — 매칭(빠른시작)과 사회성(공개방)이 **같은 봇 목록**을 공유하되, 한 봇은
/// 한 번에 한 곳에만(busy) 있도록 관리한다. 공개방에 있는 봇은 busy라 빠른시작에
/// 안 뽑힌다(요구사항). 사회성은 [reserve]만큼 빠른시작용으로 남겨둔다.
class BotPool {
  BotPool(this._all);
  final List<BotClient> _all;
  final _busy = <BotClient>{};
  final _rng = Random();

  int get total => _all.length;
  int get freeCount => _all.length - _busy.length;
  Set<String> get uids => {for (final b in _all) b.uid};

  /// 자유 봇 [n]명 확보(busy 표시). [reserve]명은 남겨둔다(못 남기면 가능한 만큼만,
  /// 단 reserve를 침범하지 않음). 없으면 빈 리스트.
  /// **랜덤 선발** — 목록 순서대로 뽑으면 늘 같은 봇(티모·공격…)만 로비에 보여서
  /// 부자연스럽고, 같은 이름의 방이 반복해서 파인다. 40명이 골고루 나오게 섞는다.
  List<BotClient> acquire(int n, {int reserve = 0}) {
    final free = [for (final b in _all) if (!_busy.contains(b)) b]
      ..shuffle(_rng);
    final available = free.length - reserve;
    final take = n < available ? n : available;
    if (take <= 0) return const [];
    final picked = free.take(take).toList();
    _busy.addAll(picked);
    return picked;
  }

  void release(BotClient b) => _busy.remove(b);
  void releaseAll(Iterable<BotClient> bs) => bs.forEach(_busy.remove);
}
