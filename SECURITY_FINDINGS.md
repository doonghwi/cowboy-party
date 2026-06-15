# 카우보이 파티 — 보안 검토 결과 (SECURITY_FINDINGS)

> 검토일: 2026-06-15 · 대상: `cowboy_party` (Firebase RTDB `cowboy-party-doonghwi`, asia-southeast1)
> 구조: **신뢰-클라이언트**(서버 권위 없음, 클라가 턴 히스토리를 리플레이). 지시서: `SECURITY_REVIEW_PREP.md`.
> 위험도 H(높음)/M(보통)/L(낮음). 코드 수정 없이 점검·문서화 위주(규칙 변경은 운영 영향 커서 **배포 보류**, 권고만).

## 처리 현황 (2026-06-15 규칙 배포·REST 검증 완료)
- ✅ **H2 (랭킹 위조) 차단** — `pts` 증가량 캡(≤60/스텝) 배포. REST 검증: 1,000,000 거부 / 정상 +50 허용 / 50→100000 거부 / 타인 uid 거부.
- ✅ **M1 (통계 남용) 차단** — `build`·`stats` 쓰기 잠금, `charstats`는 숫자·단조 검증. REST 검증: 비로그인 쓰기·문자열 주입 모두 거부.
  - 🔒 **2026-06-16 추가 하드닝**: `charstats` 쓰기를 `auth != null`로 잠금(기존 `.write: true`). 통계는 온라인 게임 종료 시(`CharStats.record`, 호출처 `online_game_screen.dart`)만 기록되고 그 시점엔 방 생성/입장으로 이미 인증돼 있어 정상 플레이 불변. REST 검증: 무인증 쓰기 거부 / 익명토큰 쓰기 허용. 무인증 DB 남용·통계 봇 주입 벡터 차단.
- 🟡 **H1 (방 그리핑) 부분 완화** — `rooms` 쓰기에 **로그인 요구** + `createdAt` 불변 배포. 비로그인 드라이브-바이는 차단(REST 검증). **잔여**: 익명 토큰은 무료라 결정적 공격자는 토큰 받아 타 방 삭제 가능 → 완전 차단은 좌석↔uid 바인딩 또는 Functions 필요(아래 S9).
- 🟡 **M2 (방 비번 노출)** — 규칙만으로 불가(공개 read 구조). 미해결, 권고만.
- 🟡 **M3 (제보 공개 토픽)** — 안내 문구 권고. 미해결.
- ✅ **시크릿/권한/전송/개인정보**: 양호(원래부터). 키스토어·plist 커밋 이력 없음, INTERNET만, 전부 HTTPS, data_safety 일치.

## 요약 (TL;DR — 최초 발견 기준)
- **H1** `rooms/$code` 가 **인증 없이 누구나 전체 쓰기**(`.write:true`, `auth` 무관) → 방 삭제/위변조로 **그리핑(서비스 방해)**·점수 위조 가능. 가장 큰 실위험.
- **H2** `seasons/$sid/$uid/pts` 증가량 **상한 없음**(단조증가만 검사) → 로그인 유저가 자기 점수를 **임의 거대값으로 위조** → 랭킹 신뢰성 0.
- **M1** `build`·`stats`·`charstats` **공개·무검증 쓰기** → 통계(특히 사이트에 노출되는 캐릭터 승률) 조작·쓰레기 주입·DB 남용.
- **M2** 비공개 방 비밀번호(`pw`)가 **평문·공개 read** → 소프트 게이트일 뿐 우회 가능.
- **M3** 제보가 **공개 ntfy 토픽** → 누구나 구독해 제보 열람·스팸 주입 가능(사용자가 PII 입력 시 유출).
- **시크릿/권한/전송보안/개인정보**: 양호. 키스토어·plist·google-services.json 커밋 이력 없음(과거 추적분은 `413e981`에서 제거), INTERNET 권한만, 전부 HTTPS, 수집 항목이 data_safety와 일치.

---

## S1 — RTDB 보안 규칙 (`database.rules.json`)

### H1 · `rooms/$code` 누구나 전체 쓰기 — 그리핑/위변조  ⚠️ 최우선
**발견.** `rooms`: `.read:true`, `rooms/$code`: `.write:true` (인증 조건 없음). `.validate`는 `title/hostName/capacity/players.$slot.name` 형태만 제한하고, 나머지 키(`turns`, `score`, `scored`, `started`, `host`, `kicked`, `pw`, `chars`, `players.$slot.id/char/seen` …)와 **노드 자체 삭제**는 무제한.

**영향.**
- 인증 없이도(익명 로그인조차 불필요) `rooms`가 공개 read라 **활성 방 코드를 모두 열거** → 임의 방을 `remove()`/덮어쓰기로 **게임 강제 중단(가용성 공격)**. 스크립트 한 줄로 전 방 파괴 가능.
- `score`/`turns` 직접 주입으로 **게임 결과·점수 위조**. (단 점수→코인/시즌포인트는 각 클라 로컬에서 산정하므로 영향은 해당 방 참가자 경험 한정 — 서버 랭킹은 H2 경로가 별개.)
- `kicked/$id`·`host` 조작으로 타인 추방·방장 탈취.

**조치/완화(권고, 미배포).** 신뢰-클라이언트라 쓰기를 완전히 잠그긴 어렵지만 최소한:
1. `rooms/$code` 쓰기에 **`auth != null` 요구**(앱은 익명 로그인 폴백 보유 — 단 **콘솔에서 익명 공급자 ON 확인 후** 배포해야 온라인이 안 깨짐).
2. 불변 필드 보호: `createdAt`은 한 번 쓰면 변경 금지(`!data.exists() || data.val() == newData.val()`), `host`는 기존 host/빈값/본인만, `score/$slot`는 **단조증가**(`newData.val() >= data.val()`).
3. `turns/t$n/$slot`은 한 번 쓰면 **덮어쓰기 금지**(`!data.exists()`)로 히스토리 리라이트 차단(리플레이 결정성과도 합치).

**잔여위험.** 같은 방 참가자끼리의 위조는 신뢰-클라이언트 구조상 남음 → 근본 해결은 S9(Cloud Functions 권위화). 위 1~3만으로도 무인증 대량 그리핑은 차단됨.

### H2 · 시즌 포인트 위조 — 랭킹 신뢰성 0
**발견.** `seasons/$sid/$uid` 쓰기는 `auth.uid == $uid`로 보호되고 `pts`는 `>=0 && (!data.exists() || newData.val() >= data.val())`(단조증가)만 검사. **증가 폭 상한이 없음.** 클라는 `ServerValue.increment(winPts)`(승리당 10~50)로 올리지만, 규칙은 증가 방식/크기를 강제하지 않음.

**영향.** 로그인한 사용자가 콘솔/스크립트로 `pts`를 한 번에 임의 거대값으로 set → 단조 조건 통과 → **랭킹 1위 자작**. 자기 uid만 가능하지만 랭킹 전체 신뢰성이 무너짐.

**조치/완화(권고).** 증가량 캡 추가:
`".validate": "newData.isNumber() && newData.val() >= 0 && (!data.exists() ? newData.val() <= 60 : newData.val() > data.val() && newData.val() <= data.val() + 60)"`
(정당 1회 최대 50 < 60). 루프 반복 위조까지 막으려면 서버 권위(S9) 필요.

**잔여위험.** 캡이 있어도 다회 쓰기로 점진 누적 가능 → 완전 차단은 Functions에서 "방 결과 검증 후 가산"만 허용해야 함.

### M1 · `build`·`stats`·`charstats` 공개·무검증 쓰기
**발견.** 셋 다 `.read:true, .write:true`, 검증 전무. `charstats`는 사이트(cowboy.gg)에 **노출되는 밸런스 통계**.

**영향.** 누구나 승률 통계 조작(밸런스 의사결정 오염), 비숫자/거대 페이로드 주입, DB를 임의 저장소로 남용(비용/쿼터 abuse).

**조치/완화(권고).** 최소 타입·구조 검증: `charstats/$idx/{games,wins}`만 허용하고 `newData.isNumber()` + 단조증가, `$other: {".validate": false}`. `build`/`stats`도 키 화이트리스트 + 숫자 단조. 토이앱 통계라 "허용 위험"으로 둘 수도 있으나, **무인증 무제한 쓰기**는 비용 abuse 측면에서 닫는 걸 권장.

**판단.** 통계 신뢰도는 낮춰 받아들이더라도, `auth != null` + 타입검증만이라도 거는 게 비용/무결성 대비 이득.

### 양호 항목
- 루트 `.read/.write:false` 기본 차단 OK.
- `users/$uid`: `auth.uid==$uid` 게이트 + `coins>=0` 검증. 상한은 없지만 **본인 데이터 미러**라 자기 코인 부풀리기는 자기 경험 한정(서버 권위 보상 아님) → 수용 가능.
- `giftcodes`: 코드 노드 자체는 클라가 생성 불가(쓰기 규칙은 `claimedBy`에만), 선착순 트랜잭션 OK. (단 S6 참고 — 코드가 공개 read라 열거 가능.)

---

## S2 — 방 비밀번호 (M2)
**발견.** `createRoom`이 `pw: password.trim()`를 **평문**으로 방 노드에 저장. `rooms`는 공개 read → 누구나 `rooms/$code/pw`를 읽어 비번 확보. 검증도 클라(`joinRoom`)에서 문자열 비교(소프트 게이트).

**영향.** 비공개 방 비밀번호가 **무의미**. 코드만 알면(또는 공개목록 제외라도 코드 추측/열거) 비번을 읽어 입장.

**조치/완화(권고).** (a) 단기: 비번을 평문 대신 **솔트 해시**로 저장하고 해시 노드는 read 차단(규칙으로 `pw` read 금지) — 단 신뢰-클라 검증이라 한계. (b) 근본: 입장 인가를 Cloud Function으로(코드+비번 검증 후 좌석 토큰 발급). 토이앱 수준이면 "비공개=목록 비노출"로 받아들이고 비번은 약한 게이트임을 인지.

**잔여위험.** 클라 검증인 한 우회 가능. 민감 방 없으면 수용 가능 위험.

---

## S3 — 클라 신뢰 구조의 치팅면
**발견.** 점수/시즌포인트/통계/코인 모두 클라가 직접 산정·기록. 턴 히스토리 리플레이는 결정적이지만 **입력(turns) 자체가 위조 가능**(H1). 시즌포인트는 H2 경로로 직접 위조.
**영향.** 랭킹·통계·방 결과 모두 신뢰 불가(권위 서버 없음).
**조치.** H1/H2/M1 완화로 무인증·대량 위조는 차단, 근본은 S9. 코인은 로컬/본인 미러라 타인 피해 없음 → 수용.
**잔여위험.** 동일 방 참가자 간, 인증된 본인 점수의 점진 위조는 남음.

---

## S4 — 시크릿 스캔 (양호)
- `git log --all`: `*.jks` / `key.properties` / `google-services.json` / `GoogleService-Info.plist` / `*service-account*` **커밋 이력에 없음**. 과거 추적되던 plist/google-services.json은 커밋 `413e981`에서 추적 제거됨. 현재 추적 파일은 `key.properties.example`(예시, 안전)뿐.
- `.gitignore`에 `key.properties`, `*.jks`, `*.keystore`, `GoogleService-Info.plist`, `google-services.json` 모두 등재.
- 소스 grep의 `password` 매치는 전부 **방 비번 UI 변수**(시크릿 아님).
- `firebase_options.dart`의 `apiKey: AIza…`는 **클라이언트 식별자**(비밀 아님). ✅ 단 **GCP 콘솔에서 API 키 앱 제한**(Android 패키지+SHA-1 / iOS 번들 / 웹 리퍼러) 적용 여부는 코드로 확인 불가 → **수동 확인 필요**(아래 액션).

## S5 — 인증 (양호)
- Google(웹 popup / 네이티브 credential), Apple(네이티브 **nonce+sha256** 리플레이 방지 OK, 웹 popup), 익명. 모든 실패는 로컬 게스트 폴백 → 앱 안 깨짐.
- 토큰은 Firebase SDK가 처리(직접 보관 없음). 게스트 id는 기기 로컬(SharedPreferences) 무작위.
- **의존성**: Apple 로그인은 콘솔 Apple 공급자 ON, 익명/Google은 각 공급자 ON, **승인된 도메인**(gh-pages 도메인 포함) 설정 필요 — 콘솔 수동 확인.

## S6 — 입력 검증/남용
- **닉네임**: 비속어 필터(`badwords_ko.json` 부분일치) + 길이(규칙 ≤16/24). 양호. 필터 로드 실패 시 통과(가용성 우선) — 수용.
- **제보(M3)**: `ntfy.sh/cowboy-feedback-doonghwi` **공개 토픽**. 익명 식별자(uid 앞 6자)만 부착하고 본문은 사용자 자유입력. 위험: ① 누구나 토픽 **구독해 모든 제보 열람**(사용자가 실수로 PII/이름 입력 시 유출), ② 누구나 토픽에 **스팸 발행**. 완화: 토픽명 추측난도↑(현재 노출됨)·제보 입력란에 "개인정보 입력 금지" 안내·서버측 수신은 인증 게이트 불가(ntfy 공개). 토이앱 수준 수용 가능하나 안내 문구 권장.
- **선물코드**: 공용은 빌드 내장, 단일은 RTDB 선착순(`claimedBy` 트랜잭션) — 동시성 안전. 단 `giftcodes` **공개 read**라 유효 코드·금액 **열거 가능** → 단일코드를 제3자가 먼저 선점 가능(이벤트 공정성 약화). 완화: 코드 read 차단하고 검증을 트랜잭션 쓰기 결과로만(현재 `_fetchGiftCodeFromCloud`가 read 의존이라 구조 변경 필요) 또는 단일코드는 Function 발급.

## S7 — 개인정보 (양호)
- 수집: 닉네임·식별자(uid/게스트)·게임기록뿐. PII(이메일/전화/위치/광고ID) 미수집 → `store/data_safety.md` 및 정책과 일치.
- 제보는 uid **앞 6자 해시 일부**만(역추적 어려움). 단 M3대로 본문은 사용자 자유 → 안내 필요.

## S8 — 의존성
- `flutter pub outdated`: 알려진 취약 버전 없음. 메이저 뒤처짐만: `google_sign_in 6.3→7.2`, `share_plus 10.1→13.1`, `sign_in_with_apple 6.1→8.1`. **L(보안 이슈 아님, 유지보수용 업그레이드 권장)**. 라이선스 이슈는 `LEGAL_IP_NOTES.md` 소관.

## S9 — 권장 강화안 (서버 권위)
신뢰-클라 한계의 근본 해결 순서:
1. **랭킹 가산**(H2): 방 종료 결과를 Function이 검증 후 `seasons` 가산, 클라 직접 쓰기 차단. (랭킹이 의미 가지면 1순위)
2. **방 쓰기 인가**(H1): 좌석 토큰/Function 중계로 `rooms` 직접 쓰기 축소.
3. **통계 집계**(M1): Function 단일 진입점.
4. **비번 입장**(M2)·**단일 선물코드 발급**(S6): Function 인가.
토이앱 단계에선 비용 대비 과할 수 있어, **우선 규칙 하드닝(H1·H2·M1)** 으로 무인증/대량 위조만 막고 단계적 도입 권장.

---

## 즉시 조치한 것 (배포·검증 완료)
1. **익명 로그인 활성화 확인** — REST(`accounts:signUp`)로 idToken 발급 확인 → `auth != null` 요구가 온라인을 깨지 않음을 입증 후 진행.
2. **`database.rules.json` 하드닝 배포**(`firebase deploy --only database`, cowboy-party-doonghwi):
   - `rooms/$code` `.write: true → "auth != null"`, `createdAt` 불변, `score/$slot` 숫자·단조.
   - `seasons/$sid/$uid/pts` 증가량 캡(첫 ≤60, 이후 +60 이내).
   - `build`·`stats` `.write: false`(이 DB 미사용 노드), `charstats` 숫자·단조 검증 + `$other:false`.
3. **클라이언트 보강**(`lib/online/online_service.dart`) — `createRoom`/`joinRoom` 쓰기 전 `AuthService.I.tryAnonymous()` await로 로그인 보장(로그인 요구 규칙과 레이스 차단).
4. **검증**: `flutter analyze` 0 / `flutter test` 76 통과 / REST로 무단·과도 쓰기 거부 + 정상 쓰기 허용 확인.

> 잔여(미배포): H1 완전차단(좌석↔uid 바인딩/Functions), M2 비번 서버검증, M3 제보 안내 — S9 참고.

## 사용자(운영자) 수동 확인 액션
1. **GCP 콘솔 → API 키 앱 제한** 적용 확인(Android 패키지+SHA-1 / iOS 번들 / 웹 도메인). (S4)
2. **Firebase Auth 공급자/승인 도메인** 설정 확인(익명·Google·Apple, gh-pages 도메인). (S5)
3. 규칙 하드닝 배포 여부 결정: **H1·H2·M1 권고 diff** 적용 + 익명 공급자 ON 선행. (S1)
4. (선택) 제보 입력란 "개인정보 입력 금지" 안내, 의존성 메이저 업그레이드. (S6/S8)
