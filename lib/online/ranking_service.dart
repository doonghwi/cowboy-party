import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';
import 'online_service.dart' show OnlineService;

/// One row of the global leaderboard.
class RankEntry {
  final String uid;
  final String name;
  final String? photoUrl;
  final int elo;
  final int wins;
  final int losses;
  const RankEntry({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.elo,
    required this.wins,
    required this.losses,
  });

  int get games => wins + losses;
}

/// ELO-like rating, keyed by the signed-in player's Firebase uid (so it follows
/// them across devices and sessions). Each client records only its own result
/// at game-over; a win nudges the rating up (a touch more per opponent beaten),
/// a loss down. Starts everyone at [_base].
class RankingService {
  static const int _base = 1000;

  final FirebaseDatabase _fdb = FirebaseDatabase.instanceFor(
      app: Firebase.app(), databaseURL: OnlineService.databaseUrl);

  DatabaseReference _entry(String uid) => _fdb.ref('ranking/$uid');

  /// Apply one game result to my own rating. [opponents] is how many other
  /// players were in the game (more beaten → a little more rating on a win).
  Future<void> recordResult(
      {required AppUser user, required bool won, required int opponents}) async {
    final delta =
        won ? 20 + 4 * opponents.clamp(0, 5) : -12; // simple, predictable
    try {
      await _entry(user.uid).runTransaction((cur) {
        final m = (cur is Map) ? Map<String, Object?>.from(cur) : <String, Object?>{};
        final elo = (m['elo'] is int ? m['elo'] as int : _base) + delta;
        m['elo'] = elo < 0 ? 0 : elo;
        m['wins'] = (m['wins'] is int ? m['wins'] as int : 0) + (won ? 1 : 0);
        m['losses'] =
            (m['losses'] is int ? m['losses'] as int : 0) + (won ? 0 : 1);
        m['name'] = user.displayName;
        if (user.photoUrl != null) m['photo'] = user.photoUrl;
        return Transaction.success(m);
      });
    } catch (_) {}
  }

  /// Top players by rating (highest first).
  Stream<List<RankEntry>> watchTop({int limit = 50}) {
    return _fdb
        .ref('ranking')
        .orderByChild('elo')
        .limitToLast(limit)
        .onValue
        .map((e) {
      final raw = e.snapshot.value;
      final out = <RankEntry>[];
      if (raw is Map) {
        raw.forEach((uid, value) {
          if (value is! Map) return;
          out.add(RankEntry(
            uid: uid.toString(),
            name: (value['name'] as String?) ?? '카우보이',
            photoUrl: value['photo'] as String?,
            elo: value['elo'] is int ? value['elo'] as int : _base,
            wins: value['wins'] is int ? value['wins'] as int : 0,
            losses: value['losses'] is int ? value['losses'] as int : 0,
          ));
        });
      }
      out.sort((a, b) => b.elo.compareTo(a.elo)); // highest rating first
      return out;
    });
  }
}
