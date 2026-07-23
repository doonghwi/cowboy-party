// 계정 삭제(App Store 5.1.1(v)) — 확인 다이얼로그 렌더·취소·안내 문구 검증.
// Firebase가 없는 테스트 환경에선 삭제 시도 시 "삭제할 서버 계정이 없어요"로
// 안전하게 끝나는지(크래시 없음)도 확인한다.
import 'package:cowboy_party/meta/account_deletion.dart';
import 'package:cowboy_party/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget host() => MaterialApp(
        theme: buildCowboyTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showDeleteAccountDialog(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );

  testWidgets('확인 다이얼로그 — 안내 항목과 취소/삭제 버튼', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('계정을 삭제할까요?'), findsOneWidget);
    expect(find.textContaining('닉네임'), findsOneWidget);
    expect(find.textContaining('친구 목록'), findsOneWidget);
    expect(find.textContaining('떠난 카우보이'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);

    // 취소 → 아무 일도 안 일어나고 닫힘.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('계정을 삭제할까요?'), findsNothing);
  });

  testWidgets('삭제 확정 — Firebase 없는 환경에선 안내 스낵바로 안전 종료',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('삭제할 서버 계정이 없어요'), findsOneWidget);
  });
}
