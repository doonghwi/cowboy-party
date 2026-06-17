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

### 2026-06-17 bugloop 메타 감사 (직접 발견)
(아래 처리 완료 — 완료 섹션 참고)

## 완료
(처리되면 cowboy-fix-loop가 여기로 옮김)

### 2026-06-17 bugloop reveal/curse 엣지 헌팅 (cycle 10) — 실버그 1건
- [x] (P2) 의사가 저주 만료·덫 반사를 자힐로 버틴 턴, 사인(死因) 표시 플래그가 산 의사에게 남음 — 재현: 의사가 저주에 걸려 10턴 뒤 만료될 때(또는 덫 놓은 사냥꾼을 쏴 반사될 때) 자힐로 생존 / 기대: 살아남았으니 어떤 사망 연출도 없음 / 실제: `의사 자힐 단계가 hit만 끄고 curseKill·reflectKill는 안 꺼서` 좌석에 '저주 사망!'/'반사 사망' 연출(circular_table)·사망 배너(online/offline)가 산 의사에게 잘못 표시 / 근본원인: party_logic 5단계 의사 힐이 `hit[i]=false`만 하고 사인 플래그 미정리(리셋 4b는 정리하는데 힐은 누락) / 수정: 힐 시 `curseKill[i]=false; reflectKill[i]=false`도 정리. / 발견경위: 저주 재시전 회귀를 막는 퍼즈 불변식을 강화하다 의사-저주만료-재시전 경로가 노출돼 curseKill 잔류를 포착. / 회귀: fuzz_party_logic에 **사인 플래그⟹실제 사망** 불변식(curseKill/reflectKill && alive → 위반) + fuzz_edge 의사-저주만료-재시전·의사-덫반사 자힐 2종. analyze 0 / test 174. 화면: party_logic.dart

### 2026-06-17 bugloop 적대적 시나리오 + 인코딩 경화 (cycle 8)
- [x] (P3·잠복) `Move.dualShoot` 인코딩이 두 번째 대상 없음(target2=-1)일 때 손상 — 근본원인: `encode()`가 `100 + target*8 + target2`라 target2=-1이면 `99+target*8` → decode 시 다른 행동(예: target=0→99→trap)으로 오역. **현재 UI에선 도달 불가**(더블 빵야 confirm이 `selectedTarget2>=0`을 요구해 게이트됨, 2인전에선 외길이라 발사 자체 불가). 하지만 온라인 결정성의 핵심인 Firebase 정수↔Move 왕복이 잠재적으로 깨질 수 있어 경화. / 수정: 좌석은 0..5뿐이라 미사용인 **슬롯 7**에 target2=-1을 실어 보내고 decode가 7→-1로 복원. **기존 유효코드(t2 0..5)는 그대로라 버전 스큐 없음.** / 테스트: party_logic_test에 전 행동종류×전좌석×연막 무손실 왕복 + 더블빵야 전쌍/외길 왕복 + 코드 유일성(충돌 0) 추가. 화면: party_logic.dart
- [x] (P2) 적대적/퇴행 시나리오 스크립트 테스트 — `test/adversarial_scenarios_test.dart`: 전원 영원히 가만히(자원불변·미종료), 전원 방어 스테일메이트, 마지막 2인 상호사살→무승부, 긴 저주 체인(퓨즈 10→0 단조·만료턴 사망·시전자 사망시 해제), ???vs???(결정적), 최대장전 평화주의자 승리 + **동시 2인 도달은 단독승자 없음(ongoing)** + 평화주의자 발사 불가. **위반 0건** — 엔진은 극단 대국에서도 멈추거나 거짓승리 안 냄. 화면: test/adversarial_scenarios_test.dart
- [x] (감사·클린) 고친 두 버그의 이웃 재점검 — 선물코드 `redeemGiftCode`/`unlock`은 **지역 가드(이미사용·해금여부) → 전역 점유(트랜잭션) → 지급** 순서가 올바름(닉네임 버그 같은 "전역 선변경" 없음). ???턴-트리거 reveal은 각 직업의 관측 신호(스나 관통·스피드로더 +2·의사 자힐·헌터 덫·스모커 연막·5특수)가 발현될 때만 공개 — 신호 없으면 일반인과 구분 불가라 미공개가 정상(bug1 수정 철학과 일치). 새 버그 없음.
- [x] (블로커·문서화) 온라인 2-클라이언트 에뮬 대국 — AVD가 `cowboy` 하나뿐 + 실제 대국엔 프로덕션 Firebase RTDB 방 생성·인증 필요(bugloop이 prod에 실방 만들면 안 됨). 대신 온라인 로직은 `computeView` 단위테스트(방장승계·난입·reveal·결투·딥링크·승점)로 RTDB-형태 데이터를 결정적으로 재생해 커버. 2-클라 실대국은 사용자/스테이징에서만 가능 — 미실행 사유 명시.

- [x] (P3) 닉네임 변경권 없는 변경 시도가 전역 닉네임 레지스트리를 오염 — 재현: 닉네임 이미 설정 + 변경권 0장인 상태에서 `Meta.changeNickname(newName)` 직접 호출(또는 UI 가드 사이 레이스) / 기대: 변경권 없으면 레지스트리를 건드리지 않고 거절 / 실제: `claimNickname`이 변경권 체크 **이전**에 호출돼 새 이름을 점유하고 **현재 이름을 해제**(nicknames/<old>=null) → 로컬 닉네임은 그대로인데 내 현재 이름이 전역에서 풀려 남이 가로챌 수 있음 / 근본원인: `meta_service.dart changeNickname`에서 `_nicknameTickets<=0` 게이트가 `claimNickname`(전역 점유·예전이름 해제) 뒤에 있었음 / 수정: 결정 로직을 순수함수 `nicknameChangeGate`(empty/unchanged/needTicket/proceed)로 빼서 **claimNickname 이전에** 변경권 게이트 적용. UI(characters_tab)는 이미 가드했지만 서비스 계층 방어 + 단위테스트. / 화면: meta_service.dart, online_service.dart(claimNickname)

- [x] (P1) ???(mystery) 정체가 영영 공개 안 되는 직업이 있음 — 근본원인: `online_service.dart` reveal 루프가 active 능력 트리거(또는 결과 플래그)로만 공개 → 일반인·평화주의자·그림자·결투가(능동 신호 없음)·파파라치(엿보기는 별도 페이즈)는 영영 ???로 남음. 준비자만 시작-공개 예외였음. / 수정: `characters.dart`에 **순수함수 `mysteryRevealsAtStart`** + 분류 집합 `kMysteryStartRevealChars`(일반인·준비자·평화주의자·그림자·결투가) / `kMysteryTurnTriggerChars`(나머지 10직업) 추가. online_service의 시작-공개 루프를 이 함수로 교체하고 파파라치는 `peekUsed` 시 공개. / 단위테스트: characters_test에 "시작공개 ∪ 턴트리거 == kMysteryPool 전체, 서로소" 보장. / 커밋 완료, web/APK 영향(재배포 권장). 화면: online_service.dart, characters.dart, party_logic.dart(export)
- [x] (P2) 룰엔진 퍼즈/속성 테스트 하니스 — `test/fuzz_party_logic_test.dart` 추가: 시드고정 무작위게임 4000판 × 최대 80턴, 매 턴 [resolvePartyTurn] 불변식 검사(총알 0~max, 부활 금지, 사망자 행동·능력 무효, 1회성 자원 단조성, 연막 0~2 단조감소, 장전 누적 비감소, 저주 도화선 0~10·시전자 사망시 해제·단조감소, 무효턴 사망·저주 보존, 승패-생존자 일관성). **위반 0건** — 현 엔진은 불변식을 모두 만족(무효턴의 자원 소모는 설계상 의도, party_logic.dart:368). 하니스는 회귀 가드로 상주. 화면: test/fuzz_party_logic_test.dart

### 2026-06-17 사용자 제보 묶음 (6건) — fixer 세션 처리
- [x] (P1) ???정체 공개 보정 — 평화주의자·결투가는 능력이 게임 끝에 발동되므로 **시작공개에서 제외**(그 전엔 숨겨야 함). 수정: `characters.dart` `kMysteryStartRevealChars`에서 pacifist·duelist 제거 → `kMysteryTurnTriggerChars`로 이동(시작공개={일반인·준비자·그림자}만). reveal은 **능력 실제 발동(승리) 시점**에 켜기 — `online_service.dart` 종료 처리에서 `status==won && origChars[winner]==mystery && specialWin∈{pacifist,duelist}` → `revealed[winner]=true`. 오프라인은 ??? 은폐 개념 없음(단일 휴먼·봇은 실직업) → 변경 불필요. / 테스트: characters_test에 "평화·결투는 시작공개 아님, 발동 시 공개" 멤버십 회귀 + online_service_test에 "6장전 승리 순간 상대시야 공개(승리 전엔 ???)"·"결투 자동승 순간 공개" 통합 2종(seed 브루트포스로 ???→해당직업 강제). analyze 0 / test 166. 화면: characters.dart, online_service.dart
- [x] (P2) 부두 저주 재시전이 도화선 10턴으로 리셋되는 버그 — 이미 저주 걸린 대상에 다시 걸면 curseFuse를 10으로 덮어써 죽음을 늦춤. 수정: party_logic.dart 7b 새저주 적용부에 `curseFuse[m.target] <= 0` 조건 추가 → **이미 저주 중이면 재시전 무효**(도화선 유지·voodooCast 표시 안 함·원 시전자 유지). 같은 턴 두 부두가 같은 비저주 대상 노리면 먼저 처리된 좌석만 걸림(기존 anyOf 테스트 호환). / 회귀: fuzz_edge_test "이미 저주된 대상 재시전 무효 — 도화선 리셋 안 됨"(10→8→재시전→7, voodooCast false). 퍼즈 하니스 불변식도 여전히 통과. analyze 0 / test 167. 화면: party_logic.dart, ARCHITECTURE.md
- [x] (P1) 승률 트래킹 사이트(cowboy.gg) 작동 안 함 — **근본원인은 보안규칙 아님**(charstats `.read:true`로 공개 read 정상, 라이브 REST가 데이터 반환 확인). 진짜 원인: RTDB가 charstats를 **희소 배열**로 반환(집계 제외인 none=idx0·mystery=idx13은 `null`), index.html 루프가 idx0은 이름체크로 건너뛰지만 **idx13(null)에서 `data[k].games` 역참조 → TypeError**로 `.then` 전체가 실패해 "불러오기 실패" 표시. / 수정(cowboy.gg repo `index.html`): null/비객체 칸 스킵 + `???` 이름 명시 제외 + `e.games/e.wins` 사용. **라이브 데이터로 15행 정상 출력 검증**(node 시뮬: old=TypeError throw, new=15 rows). NAMES 배열 순서는 CharId enum과 일치 확인. cowboy.gg main 푸시(7a0eca4)로 gh-pages 배포. 화면: cowboy.gg/index.html
- [x] (P2) 게임 폰트를 Pretendard로 교체 — OFL 오픈폰트. Pretendard Regular/Bold(700)/Black(900) OTF를 공식 repo(orioncactus)에서 받아 `assets/fonts/`에 번들, pubspec `fonts:`에 Pretendard 패밀리 등록, theme.dart 본문 기본 `fontFamily: 'GothicA1'`→`'Pretendard'` 교체(헤더 BlackHanSans·라틴 Rye는 유지). CREDITS.md에 OFL(Reserved Font Name 'Pretendard') 표기 + 라이선스 전문 `assets/fonts/Pretendard-OFL.txt` 동봉. pub get·analyze 0·test 167 통과(폰트 에셋 해석 OK). 에뮬 시각확인은 5·6 UI 변경과 함께 최종 1회. 화면: pubspec.yaml, theme.dart, assets/fonts/, CREDITS.md
- [x] (P2) 배경 선인장·태양 이미지 개선 — 현재 코드드로잉이 조악함. **개선된 코드 드로잉**으로 격상(에셋/라이선스 부담 없이 자체완결): 태양 RadialGradient 글로우+크리스프 디스크+수평 광선, 지평선 위 별·새 한 쌍, **언덕 3층**(far/mid/near)+근경 능선 림라이트, **유기적 사구아로 선인장**(둥근 팔꿈치·세로 갈비·바닥 그림자)+깊이용 3그루. 사막 노을 톤·`bright` 팔레트·DesertBackground API 유지. duneMid는 인라인색(far↔near 사이). / 회귀: test/desert_background_test.dart 렌더 스모크(dusk·bright·초소형 셰이더). **에뮬 시각확인 OK**(개선된 선인장·사구 렌더). 화면: lib/widgets/desert_background.dart
- [x] (P2) 플레이 화면 "처음이세요? 게임방법…" 위치·디자인 개선 — 2줄 넘침·위치 부적절. 수정: Meta에 독립 플래그 `tutorialSeen`(SharedPrefs `tutorial_seen`)+`markTutorialSeen()` 추가. play_tab initState 포스트프레임에서 **첫 실행이면 환영 팝업**(showDialog: 게임 소개 + '나중에'/'게임 방법 보기'→HowToPlayScreen) 1회 — 띄우기 전에 seen 표시해 닫아도 재등장 안 함. 전체폭 금색 배너는 **우측 상단 작은 '게임 방법' 링크**로 축소(재방문자용). / 회귀: meta_logic_test "튜토리얼 본 적 표시(처음 false→표시 후 true·멱등)". **에뮬 시각확인 OK**(첫 실행 팝업 정상 표시·닉네임 온보딩과 공존). 화면: play_tab.dart, meta_service.dart
