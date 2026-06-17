# 카우보이 버그 큐 (cowboy-fix-loop 입력)

> 사용자가 QA로 찾은 버그를 여기에 적으면 `cowboy-fix-loop` 스킬이 하나씩 처리한다.
> 형식: `- [ ] (P0~P3) 제목 — 재현: / 기대: / 실제: / 화면:`
> 상태: `[ ]` 대기 · `[~]` 진행 · `[x]` 완료(배포까지). 우선순위 P0(크래시)~P3(사소).
> 분류는 `cowboy-bug-triage` 스킬 참고.

## 대기
(여기에 새 버그를 추가하세요. 예시 한 줄:)
- 예) [ ] (P1) 빵야 후 총알 안 줄어듦 — 재현: 2발로 빵야 / 기대: 1발 차감 / 실제: 그대로 / 화면: party_logic.dart

### 2026-06-17 ralph 버그헌팅 (마스터가 근본원인 규명해 등록)
(아래 두 건 처리 완료 — 완료 섹션 참고)

## 완료
(처리되면 cowboy-fix-loop가 여기로 옮김)

- [x] (P1) ???(mystery) 정체가 영영 공개 안 되는 직업이 있음 — 근본원인: `online_service.dart` reveal 루프가 active 능력 트리거(또는 결과 플래그)로만 공개 → 일반인·평화주의자·그림자·결투가(능동 신호 없음)·파파라치(엿보기는 별도 페이즈)는 영영 ???로 남음. 준비자만 시작-공개 예외였음. / 수정: `characters.dart`에 **순수함수 `mysteryRevealsAtStart`** + 분류 집합 `kMysteryStartRevealChars`(일반인·준비자·평화주의자·그림자·결투가) / `kMysteryTurnTriggerChars`(나머지 10직업) 추가. online_service의 시작-공개 루프를 이 함수로 교체하고 파파라치는 `peekUsed` 시 공개. / 단위테스트: characters_test에 "시작공개 ∪ 턴트리거 == kMysteryPool 전체, 서로소" 보장. / 커밋 완료, web/APK 영향(재배포 권장). 화면: online_service.dart, characters.dart, party_logic.dart(export)
- [x] (P2) 룰엔진 퍼즈/속성 테스트 하니스 — `test/fuzz_party_logic_test.dart` 추가: 시드고정 무작위게임 4000판 × 최대 80턴, 매 턴 [resolvePartyTurn] 불변식 검사(총알 0~max, 부활 금지, 사망자 행동·능력 무효, 1회성 자원 단조성, 연막 0~2 단조감소, 장전 누적 비감소, 저주 도화선 0~10·시전자 사망시 해제·단조감소, 무효턴 사망·저주 보존, 승패-생존자 일관성). **위반 0건** — 현 엔진은 불변식을 모두 만족(무효턴의 자원 소모는 설계상 의도, party_logic.dart:368). 하니스는 회귀 가드로 상주. 화면: test/fuzz_party_logic_test.dart
