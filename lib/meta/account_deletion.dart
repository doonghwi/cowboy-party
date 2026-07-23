import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../online/friend_service.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/top_toast.dart';
import 'auth_service.dart';
import 'meta_service.dart';
import 'season_service.dart';

/// 계정 삭제 — App Store 심사 5.1.1(v) 요구(2026-07-17 반려 대응).
///
/// 서버에 저장된 내 개인 데이터를 지우고 Firebase Auth 계정을 삭제한다.
/// 데이터 노드 삭제는 전부 베스트에포트(하나 실패해도 계속) — 남더라도
/// 규칙상 본인 외에는 읽을 수 없는 노드들이고, 계정이 사라지면 접근 불가.
/// 시즌 랭킹 점수는 규칙상 삭제가 막혀 있어(점수 조작 방지) 이름만 익명화한다.
class AccountDeletion {
  /// 성공 시 null, 실패 시 사용자에게 보여줄 한 줄 메시지.
  static Future<String?> deleteAccount() async {
    final User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return '삭제할 서버 계정이 없어요';
    }
    if (user == null) return '삭제할 서버 계정이 없어요';
    final uid = user.uid;

    DatabaseReference? root;
    try {
      root = FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: OnlineService.databaseUrl)
          .ref();
    } catch (_) {}

    if (root != null) {
      // 1) 친구 그래프 — 상대 쪽 목록에서도 나를 지운다(규칙이 상호 삭제 허용).
      try {
        final snap = await root.child('friends/$uid').get();
        final v = snap.value;
        if (v is Map) {
          for (final fuid in v.keys) {
            try {
              await root.child('friends/$fuid/$uid').remove();
            } catch (_) {}
          }
        }
      } catch (_) {}
      // 2) 보낸 친구 요청 — 상대의 받은 요청함에서 회수(로컬 기록 기반).
      try {
        for (final s in await FriendService.I.sentRequests()) {
          try {
            await root.child('friendReqs/${s.uid}/$uid').remove();
          } catch (_) {}
          await FriendService.I.forgetSent(s.uid);
        }
      } catch (_) {}
      // 3) 내 소유 노드 일괄 삭제.
      for (final path in [
        'friends/$uid',
        'friendReqs/$uid',
        'presence/$uid',
        'invites/$uid',
        'users/$uid',
      ]) {
        try {
          await root.child(path).remove();
        } catch (_) {}
      }
      // 4) 닉네임 매핑 해제 — 내 소유일 때만(트랜잭션).
      final nick = Meta.I.nickname.trim();
      if (nick.isNotEmpty) {
        final key = FriendService.nickKey(nick);
        if (key.isNotEmpty) {
          try {
            await root.child('nicknames/$key').runTransaction((cur) {
              if (cur == uid) return Transaction.success(null);
              return Transaction.abort();
            });
          } catch (_) {}
        }
      }
      // 5) 시즌 랭킹 익명화(이번 주 + 지난 주) — 점수 노드는 규칙상 삭제 불가.
      for (final sid in [SeasonService.seasonId, SeasonService.prevSeasonId]) {
        try {
          final e = await root.child('seasons/$sid/$uid/pts').get();
          if (e.exists) {
            await root.child('seasons/$sid/$uid/name').set('떠난 카우보이');
          }
        } catch (_) {}
      }
    }

    // 6) Firebase Auth 계정 삭제 (+ 오래된 세션이면 재인증 후 재시도).
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        final ok = await AuthService.I.reauthenticate();
        if (!ok) {
          return '보안 확인이 필요해요 — 방금 로그인한 상태에서만 삭제할 수 있어요. '
              '다시 로그인한 뒤 한 번 더 시도해 주세요';
        }
        try {
          await user.delete();
        } catch (_) {
          return '계정 삭제에 실패했어요. 잠시 후 다시 시도해 주세요';
        }
      } else {
        return '계정 삭제에 실패했어요 (${e.code})';
      }
    } catch (_) {
      return '계정 삭제에 실패했어요. 네트워크를 확인해 주세요';
    }

    // 7) 로컬 정리 — 구글 세션 해제 + 닉네임 초기화(이 기기 게임 데이터는 유지).
    try {
      if (!kIsWeb) await GoogleSignIn().signOut();
    } catch (_) {}
    Meta.I.clearNicknameLocal();
    return null;
  }
}

/// 설정 → 계정 삭제 진입점. 확인 다이얼로그 → 진행 스피너 → 결과 안내.
Future<void> showDeleteAccountDialog(BuildContext context,
    {VoidCallback? onDeleted}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CD.parchment,
      title: Text('계정을 삭제할까요?', style: posterTitle(20)),
      content: const Text(
        '되돌릴 수 없어요. 서버에서 아래 정보가 삭제돼요.\n\n'
        '• 닉네임 (다른 사람이 쓸 수 있게 돼요)\n'
        '• 친구 목록·주고받은 친구 요청\n'
        '• 클라우드 백업(코인·캐릭터 기기 간 연동)\n'
        '• 온라인 접속 정보\n'
        '• 랭킹에는 점수만 "떠난 카우보이"로 남아요\n\n'
        '이 기기에 저장된 게임 진행(코인·캐릭터)은 지워지지 않아요.',
        style: TextStyle(fontSize: 13.5, height: 1.5),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: CD.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('삭제',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // 진행 표시 — 삭제는 수 초 걸릴 수 있다(노드 여러 개 + 인증 삭제).
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator(color: CD.rust)),
    ),
  );
  final err = await AccountDeletion.deleteAccount();
  if (!context.mounted) return;
  Navigator.pop(context); // 스피너 닫기
  if (err == null) {
    onDeleted?.call();
    TopToast.show(context,
        message: '계정이 삭제됐어요. 그동안 함께해 줘서 고마워요 🤠');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating, content: Text(err)));
  }
}
