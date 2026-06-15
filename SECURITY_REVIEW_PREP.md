# 카우보이 — 보안 검토 지시서 (다른 세션 전용)

> **이 파일을 읽은 세션이 할 일**: 아래 항목을 실제로 점검하고, 발견·조치·잔여위험을
> `SECURITY_FINDINGS.md`로 정리한다. 코드 수정 시 `flutter analyze`(0)+`flutter test`+
> 커밋(작성자 `doonghwi <ehdgnlans@gmail.com>`, Co-Authored-By 금지). 끝나면 HANDOFF.md 갱신.
> 표준 체크리스트: `_make-new-app/SECURITY_CHECKLIST.md`도 함께 본다.

## 0. 컨텍스트
- 작업 디렉토리: `/Users/doonghwi/Documents/dailyapp/cowboy_party`
- 온라인은 Firebase RTDB(`cowboy-party-doonghwi`, asia-southeast1) + Auth(Google/Apple/익명).
- 클라가 턴 히스토리를 리플레이하는 **신뢰-클라이언트** 구조(서버 권위 없음).
- 규칙 파일 `database.rules.json`. 사용량/승률 등 공개 노드 있음.

## 점검 항목
- [ ] S1 **RTDB 보안 규칙 검토**(`database.rules.json`): 각 경로의 read/write 범위가 과도하지 않은지.
      특히 `rooms/$code`가 `.write:true`(누구나 쓰기) — 방 조작(점수/턴 위변조) 가능성. 영향·완화안 기술.
      `charstats`·`stats`·`build`가 공개 write — 통계 조작 가능. 허용 위험인지 판단.
- [ ] S2 **방 비밀번호**가 클라 검증(소프트 게이트)이고 `pw`가 공개 read로 노출됨 — 위험도/대안(함수) 기술.
- [ ] S3 **클라 신뢰 구조의 치팅면**: 점수/시즌포인트(`seasons/$sid/$uid/pts`)를 클라가 직접 증가 →
      위조 가능. 규칙의 pts 단조증가 검증이 충분한지, 랭킹 신뢰성 영향.
- [ ] S4 **시크릿 스캔**: 키스토어/`key.properties`/`google-services.json`/plist 가 커밋 이력에 없는지
      (`_shared/scan_secrets.sh`, `git log -p`로 확인). Firebase 웹 API 키는 비밀 아님(식별자) — 단 API 제한 점검.
- [ ] S5 **인증**: Google/Apple/익명 흐름. 승인된 도메인, Apple 공급자 설정 의존성. 토큰 처리.
- [ ] S6 **입력 검증/남용**: 닉네임(비속어 필터·길이), 제보(ntfy 공개 토픽 — 스팸·개인정보 유입 위험),
      선물코드(트랜잭션 선착순) 안전성.
- [ ] S7 **개인정보**: 수집 항목이 개인정보처리방침과 일치하는지, 익명 식별자 외 PII 미수집 확인.
- [ ] S8 **의존성**: `flutter pub outdated`로 알려진 취약 버전 여부, GPL 등 라이선스(법무는 LEGAL_IP_NOTES.md).
- [ ] S9 **권장 강화안**: 서버 권위가 필요한 부분(점수/매칭/랭킹) — Cloud Functions 도입 시 우선순위·범위.

## 산출물
`SECURITY_FINDINGS.md`: 항목별 (위험도 H/M/L · 발견 · 영향 · 조치/완화 · 잔여위험). 즉시 고친 것은 커밋 해시.
