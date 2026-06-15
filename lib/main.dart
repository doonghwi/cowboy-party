import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'audio/sfx.dart';
import 'firebase_options.dart';
import 'meta/auth_service.dart';
import 'meta/meta_service.dart';
import 'meta/profanity.dart';
import 'online/online_service.dart';
import 'screens/shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // On mobile, persist queued writes so an open that happened offline still
    // syncs to the usage counter once the device is back online.
    if (!kIsWeb) {
      try {
        FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: OnlineService.databaseUrl,
        ).setPersistenceEnabled(true);
      } catch (_) {}
    }
    _recordOpen();
  } catch (_) {
    // Firebase is optional — the offline vs-CPU game works without it.
  }
  // 메타(코인·캐릭터·출석)는 로컬 우선이라 Firebase 실패와 무관하게 항상 초기화.
  await Meta.I.init();
  await AuthService.I.init();
  await Sfx.init();
  await Profanity.I.init(); // 닉네임 비속어 필터 단어 로드(#1)
  // 익명 로그인이 콘솔에서 켜져 있으면 게스트도 랭킹에 오를 수 있다(베스트에포트).
  AuthService.I.tryAnonymous();
  runApp(const CowboyPartyApp());
}

/// The DailyApp dashboard reads every app's usage from one central RTDB
/// (the original Cowboy Duel project), so we report opens there — same node
/// the dashboard already polls via its single STATS_URL.
const String _statsDbUrl =
    'https://cowboy-duel-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app';

/// Anonymously bump an app-open counter so the DailyApp dashboard can show
/// real usage. Fire-and-forget; never blocks or breaks the app.
void _recordOpen() {
  try {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _statsDbUrl,
    );
    final ref = db.ref('dailyapp_stats/cowboy_party');
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    ref.child('opens').runTransaction((cur) {
      final n = cur is int ? cur : 0;
      return Transaction.success(n + 1);
    });
    ref.child('opens_$platform').runTransaction((cur) {
      final n = cur is int ? cur : 0;
      return Transaction.success(n + 1);
    });
    ref.update({
      'name': '🎉 카우보이',
      'desc': '2~6인 원형 눈치 대결 · 아무나 저격 · 온라인+컴퓨터전',
      'day': 'Day 4',
      'platforms': ['web', 'android', 'online'],
      'webUrl': 'https://doonghwi.github.io/cowboy-party/',
      'repoUrl': 'https://github.com/doonghwi/cowboy-party',
      'lastOpen': ServerValue.timestamp,
    });
  } catch (_) {
    // ignore analytics failures
  }
}

class CowboyPartyApp extends StatelessWidget {
  const CowboyPartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '카우보이',
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: const ShellScreen(),
    );
  }
}
