# 구글 로그인 — 남은 Firebase 설정 (feat/google-login)

코드는 완성·빌드 검증 완료. **실제 로그인이 동작하려면 아래 콘솔 토글이 필요**합니다.
(미설정 상태에서도 앱은 게스트로 정상 동작 — 로그인 버튼만 "설정 준비 중" 안내.)

## 이미 자동으로 한 것
- `firebase_auth ^6.5.2`, `google_sign_in 6.3.0`, `shared_preferences` 추가.
- `AuthService`(웹=`signInWithPopup`, 모바일=네이티브) + 홈 로그인 칩 + 로비 닉네임 대체.
- **안드로이드 디버그 SHA-1/SHA-256을 Firebase 앱에 등록**(firebase CLI).
  - SHA-1 `DC:FE:31:00:03:BC:6C:D6:81:E1:02:D8:3C:9D:79:08:D0:52:96:1F`
  - (릴리스 APK가 디버그 키로 서명되므로 디버그 키스토어 기준. 실제 출시 키 쓰면 그 SHA도 추가 필요.)

## 콘솔에서 해야 할 것 (약 3분)
1. **Authentication → Sign-in method → Google → 사용 설정(Enable)** → 저장.
   - 저장하면 웹 OAuth 클라이언트 + 안드로이드 oauth_client가 자동 생성됨.
2. **Authentication → Settings → 승인된 도메인(Authorized domains)** 에 `doonghwi.github.io` 추가.
   - (웹 팝업 로그인용. `localhost`는 기본 포함.)
3. **google-services.json 재생성** — oauth_client가 들어가야 안드로이드 네이티브 로그인이 됨:
   ```
   flutterfire configure --project=cowboy-party-doonghwi
   ```
   또는 콘솔 안드로이드 앱에서 google-services.json 내려받아 `android/app/`에 교체.
4. 재빌드 후 확인:
   - 웹: 홈 "Google로 로그인" → 팝업 → 로그인되면 칩에 이름/사진.
   - 안드로이드: 같은 버튼 → 구글 계정 선택 → 로그인.

## 동작 방식
- 로그인하면 온라인 로비에서 **닉네임 칸이 사라지고 구글 이름으로 입장**.
- 게스트(미로그인)는 기존처럼 닉네임 입력/랜덤.
- `AppUser.uid`(Firebase uid)가 **랭킹(feat/ranking)의 안정적 식별자**로 쓰임.
