# 앱스토어 반려(5.1.1(v) 계정 삭제) 대응 — 재제출 가이드 (2026-07-23, 2026-07-30 최신화)

## 상황
- 1.0 (빌드 29) **반려**: 계정 생성(Google/Apple 로그인)은 있는데 **계정 삭제 기능이 없음** (Guideline 5.1.1(v)).
- 대응 완료: 설정 → **계정 삭제** 구현(빌드 30) — 확인 다이얼로그 → 서버 데이터 삭제 + 랭킹 이름 익명화 → Firebase 계정 삭제.
- 2026-07-30: 애플 로그인 credential 오류(서버 clientId 공란 + 클라이언트 SDK 경로)도 수정 완료, **사용자 실기기에서 애플 로그인 성공 확인됨**.
- ASC API로 확인(2026-07-30): **빌드 35가 VALID 상태로 이미 업로드되어 있어 바로 선택 가능**(TestFlight 인식 여부와 무관 — 심사 제출엔 TestFlight 등록이 필요 없음).

## 사용자가 할 일 (아이폰/아이패드로 5~10분, 웹 브라우저에서)
1. **appstoreconnect.apple.com 접속 → 카우보이 파티 앱 선택**.
2. 왼쪽 메뉴에서 **"앱스토어" 탭 → 1.0 버전 페이지**로 들어가면, 반려 사유가 적힌 **노란/빨간 박스(Resolution Center, 심사 메시지창)**가 상단에 보임. 이건 실제 이메일이 아니라 **ASC 안의 메시지창**(애플이 알림 이메일도 같이 보내지만, 답장은 반드시 이 페이지 안에서).
3. 그 메시지창 안 **"회신(Reply)" 입력칸**에 아래 영어 회신문을 붙여넣기.
4. 같은 회신창에 있는 **"첨부파일 추가(Add Attachment)"** 버튼으로 촬영해둔 화면 녹화 영상(로그인→계정 삭제 장면)을 첨부. (용량 제한 있으니 너무 크면 압축 필요 — 보통 500MB 이하 mp4/mov면 통과)
5. **보내기(Send)** — 여기까지가 "반려 메시지 회신".
6. 회신과 별개로, **같은 1.0 버전 페이지에서 "빌드(Build)" 항목을 빌드 35로 선택**(현재 29로 걸려있을 것) → 저장.
7. 페이지 상단의 **"심사에 제출(Submit for Review)"** 버튼 클릭 → 몇 가지 확인 질문(수출 규정 등) 예/아니오 답하면 제출 완료.
8. 이후는 애플 심사 대기(보통 1~3일). 결과는 이메일 + ASC 앱 상태로 옴.

**6~7번(빌드 선택 + 제출)은 API로 대행 가능** — "재제출 해줘"라고만 하면 빌드 35를 선택하고 심사 제출까지 자동으로 처리. 단 **3~5번(회신 작성 + 영상 첨부)은 애플이 공개 API를 제공하지 않아 반드시 사용자가 직접 웹에서** 해야 함.

## 영어 회신문 (복사용 — 빌드 35 기준)
```
Hello,

Thank you for the review. We have added full account deletion, verified in build 35.

How to find it: Settings (gear icon, top right) → "계정 삭제" (Delete Account) at the bottom of the settings sheet.

The flow: a confirmation dialog explains exactly what will be deleted → tapping Delete removes all server-side personal data (nickname, friends list, friend requests, cloud save, presence) and permanently deletes the Firebase authentication account. Leaderboard entries are anonymized. The deletion is performed entirely in-app — no website visit or customer service contact is required.

A screen recording captured on a physical device demonstrating sign-in → navigating to the deletion option → the complete deletion flow is attached.

Thank you!
```

## 참고
- 시연 영상은 향후 제출을 위해 **App Review Information의 Notes**에도 남겨두면 좋음: "Account deletion: Settings → Delete Account, see attached recording".
- 구현 상세: `lib/meta/account_deletion.dart`. 애플 로그인 수정 상세: HANDOFF 2026-07-30(17~18차).
- ASC API로 확인한 현재 빌드 상태(2026-07-30): 27~35 전부 processingState=VALID, 만료 없음 — 35가 최신.
