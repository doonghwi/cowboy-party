# 앱스토어 반려(5.1.1(v) 계정 삭제) 대응 — 재제출 가이드 (2026-07-23)

## 상황
- 1.0 (빌드 29) **반려**: 계정 생성(Google/Apple 로그인)은 있는데 **계정 삭제 기능이 없음** (Guideline 5.1.1(v)).
- 대응 완료: 설정 → **계정 삭제** 구현(빌드 30) — 확인 다이얼로그 → 서버 데이터(닉네임·친구·요청·클라우드 백업·접속 정보) 삭제 + 랭킹 이름 익명화("떠난 카우보이") → Firebase 계정 삭제. 필요 시 재인증(requires-recent-login) 처리.

## 사용자가 할 일 (아이폰으로 5~10분)
1. **TestFlight에서 빌드 30 설치** (App Store Connect에서 처리 완료되면 TestFlight 앱에 뜸 — 업로드 후 수 분~1시간).
2. **화면 녹화 켜고**(제어 센터 녹화 버튼) 아래를 한 번에 촬영:
   - 앱 실행 → (로그아웃 상태라면) 설정에서 **Apple 또는 Google로 로그인**
   - 우상단 ⚙️ 설정 → 맨 아래 **계정 삭제** 탭
   - 확인 다이얼로그에서 **삭제** → "계정이 삭제됐어요" 토스트까지
3. App Store Connect → 카우보이 파티 → **앱 심사 페이지의 반려 메시지에 "회신"** — 아래 영어 회신문 붙여넣고 **녹화 영상 첨부**.
4. **iOS 앱 1.0 버전 페이지에서 빌드를 29 → 30으로 교체** 후 **앱 심사에 다시 제출** 클릭.
   (또는 세션에 "재제출 해줘"라고 하면 빌드 선택·제출은 자동화 스크립트로 처리)

## 영어 회신문 (복사용)
```
Hello,

Thank you for the review. We have added full account deletion in build 30.

How to find it: Settings (gear icon, top right) → "계정 삭제" (Delete Account) at the bottom of the settings sheet.

The flow: a confirmation dialog explains exactly what will be deleted → tapping Delete removes all server-side personal data (nickname, friends list, friend requests, cloud save, presence) and permanently deletes the Firebase authentication account. Leaderboard entries are anonymized. The deletion is performed entirely in-app — no website visit or customer service contact is required.

A screen recording captured on a physical device demonstrating sign-in → navigating to the deletion option → the complete deletion flow is attached.

Thank you!
```

## 참고
- 시연 영상은 향후 제출을 위해 **App Review Information의 Notes**에도 남겨두라고 하니, 회신 첨부와 함께 앱 정보 > 앱 심사 정보 메모에도 한 줄("Account deletion: Settings → Delete Account, see attached recording") 남기면 좋음.
- 구현 상세: `lib/meta/account_deletion.dart` (HANDOFF 2026-07-23 참고).
