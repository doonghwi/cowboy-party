# 카우보이 파티 — 설계 문서 (살아있는 문서)

> **규칙: 코드를 바꿀 때마다 이 문서를 같이 갱신한다.** 새 사람(또는 다음 세션의 Claude)이
> 이 문서만 읽고 전체 게임과 코드 구조를 이해할 수 있어야 한다.
> 최종 갱신: 2026-06-15 (Stage 2: 신규 행동 플레이 가능화)

---

## 1. 게임 한눈에
2~6명이 원형으로 앉아 매 턴 **동시에** 한 가지 행동을 골라 공개·판정하는 눈치 대결.
마지막 1인이 승리. 온라인(방 코드/공개방)과 오프라인(vs 컴퓨터) 둘 다 지원.

### 기본 행동
- **장전**: 총알 +1 (최대 6).
- **방어**: 그 턴 나에게 오는 일반 공격을 전부 막음.
- **빵야**: 총알 1발 소모, 한 명 저격. 이전 턴까지 모은 총알로만 가능(첫 턴 불가).
- **슈퍼빵야**: 총알 가득(6)일 때 장전칸이 변신. 5발 소모, 방어·덫 무시 확정 처치.
- **가만히(idle)**: 아무것도 안 함. 시간초과(20초) 시 자동.

### 승리 특수조건
- 평화주의자: 장전 6회 + 생존 → 즉시 승리.
- 결투가: 둘만 남고 결투가가 정확히 1명 → 즉시 승리.
- 전원 동시 사망 → 반응속도 결투(showdown)로 1인 가림.

---

## 2. 캐릭터 (CharId, characters.dart)
> enum 값은 **append만** (RTDB에 정수 index로 저장됨). 능력 확률은 전부 `seededRoll`(결정적).

| 직업 | 능력 | 사용 | 코인 |
|---|---|---|---|
| 준비자 prepper | 총알 1발 장전 상태로 시작 | 패시브 | 0 |
| 스나이퍼 sniper | 빵야가 10% 확률로 방어 무시 | 패시브 | 0 |
| 스피드로더 speedloader | 장전 시 50%로 +2발 | 패시브 | 200 |
| 의사 doctor | 게임당 1회 치명타 버팀 → **버틴 즉시 총알 0** | 패시브 | 250 |
| 스모커 smoker | 연막(게임당 2회, 행동과 병행): 그 턴 공격 발당 50% 회피 | 토글 | 300 |
| 사냥꾼 hunter | 덫(게임당 1회, 단독 행동): 나를 쏜 일반탄 전부 반사 | 액션 | 350 |
| 결투가 duelist | 둘만 남으면 즉시 승리(결투가끼리면 무효) | 패시브 | 450 |
| 평화주의자 pacifist | 빵야 불가, 장전 6회 시 즉시 승리 | 패시브 | 500 |
| 그림자 shadow | 장전·방어·**탄약수가 상대에게 안 보임**(빵야·피격 시 방어는 드러남) | 패시브(표시) | 550 |
| 러시안룰렛 roulette | **운명의 방아쇠**(상시): 총알 0 소모 즉시 발사 — 50:50로 나/상대 사망, 상대 방어 시 반사돼 내가 죽음 | 액션 | 600 |
| 쌍권총 dualgun | **더블 빵야**(상시): 총알 2발로 두 명 동시 저격 | 액션 | 650 |
| 파파라치 paparazzi | **엿보기**(게임당 1회): 1명 행동 미리보고 내 행동 결정 (온라인은 10초 대기 페이즈) | 액션 | 700 |
| 부두술사 voodoo | **저주**(상시): 대상을 10턴(kCurseFuse) 뒤 사망. 부두술사 죽으면 해제. 동시 1개 | 액션 | 750 |
| ??? mystery | 미공개 시작, 능력 발동 시 정체 공개. 직업은 매 게임 랜덤(resolveMystery). 전 캐릭터 보유 시 구매 | 메타 | 1000 |

---

## 3. 결정성 모델 (가장 중요)
온라인은 **모든 클라이언트가 턴 히스토리(turns/t0,t1…)를 각자 리플레이**해 같은 화면을 만든다.
따라서:
- 랜덤은 절대 `Random()` 금지 → `seededRoll('$seed|$turn|$seat|$salt')` (FNV-1a 해시, 0~1).
- `seed` = `방코드#게임번호`. `turn` = 턴 인덱스.
- 능력 결과는 입력(이전 상태+이번 무브들)만으로 완전 결정 → 모두가 동일 결과.
- 새 능력을 추가할 때 salt 이름을 **기존과 안 겹치게** (예: 연막=`evade$shooter`).

---

## 4. 코드 구조 (lib/)
### 게임 규칙 (UI 무관, 순수 함수 — 테스트로 고정)
- **game/characters.dart**: `CharId` enum, `CharDef`(이름/아이콘/색/코인), `kCharacters`,
  `seededRoll`, `kCurseFuse`, `resolveMystery`/`kMysteryPool`.
- **game/party_logic.dart**: 핵심. `Move`(행동+타겟+target2+smoke, int 인코딩),
  `ActKind`, `PartyState`(턴 간 캐릭터 자원: doctorUsed/trapUsed/smokeLeft/reloads/
  paparazziUsed/curse*), `resolvePartyTurn(...)→TurnOutcome`. **모든 캐릭터 판정이 여기 한 곳.**
  - `TurnOutcome`: 결과 + 표시 플래그(healed/pierced/reflectKill/evaded/rouletteFired/
    dualFired/dualTarget2/voodooCast/curseKill…) + `stateAfter`.
- **game/cpu_ai.dart**: 오프라인 봇. `chooseMove(seat, ammo, alive, chars, state)`.

### 온라인 동기화
- **online/online_service.dart**: RTDB 입출력 + `computeView(data, myClientId, …)→RoomView`
  (히스토리를 리플레이해 좌석/상태/배너 도출). `SeatView`(좌석 1개 렌더 정보),
  `RoomView`(내 관점 전체), `PublicRoomInfo`(로비 목록).

### 화면 (screens/)
- **shell.dart**: 하단 4탭(플레이/캐릭터/랭킹/보상) + 코인칩 + 설정시트(닉네임/사운드/디스코드).
  `kDiscordUrl`, `kShowAdPlaceholder`.
- **play_tab.dart**: 모드 버튼 + 공개방 목록(폴링).
- **online_lobby_screen.dart**: 방 만들기/코드 입장.
- **online_game_screen.dart** / **offline_game_screen.dart**: 실제 게임 진행(공유 위젯 사용).
- **characters_tab.dart**: 캐릭터 카드(해금/장착). **rewards_tab.dart**: 출석. **ranking_tab.dart**: 시즌 랭킹.
- **how_to_play_screen.dart**: 규칙·캐릭터 설명(캐릭터 추가 시 자동 반영 — kCharacters 순회).

### 위젯 (widgets/)
- **action_bar.dart**: 하단 행동 선택 바. **circular_table.dart**(+ seat_card.dart): 원형 테이블·
  트레이서·발동 이펙트. **emo.dart**: Twemoji 이미지. **online_showdown.dart**: 반응속도 결투.
  **super_flash.dart**: 슈퍼빵야 연출. **top_toast.dart**: 상단 토스트(코인 등).

### 메타/경제
- **meta/meta_service.dart**(`Meta.I`): 코인·해금·장착·출석. 로컬(SharedPreferences) + 로그인 시 /users/$uid 미러.
- **meta/auth_service.dart**(`AuthService.I`): Google + 게스트(익명). 콘솔 미설정이어도 폴백.
- **meta/season_service.dart**(`SeasonService.I`): 월별 시즌 랭킹 /seasons/$sid/$uid.

---

## 5. RTDB 데이터 모델 (cowboy-party-doonghwi)
```
rooms/<code>: { host, capacity, started, public, title, hostName, game(게임번호),
                seatCount, chars/{p0:idx…}(시작 시 스냅샷),
                players/{p0:{id,name,seen,char,late?}…},
                turns/{t0:{p0:code…}…}, score/{p0:n}, scored, rematch, quit, react, showdown }
users/<uid>:   { name, coins, unlocked[], equipped, dailyLast, dailyStreak }   (.write: 본인만)
seasons/<sid>/<uid>: { name, pts }   (.indexOn: pts)
dailyapp_stats/cowboy_party: 사용량(중앙 대시보드)
```
- 보안 규칙: `database.rules.json`. **orderByChild 쓰는 경로엔 반드시 `.indexOn`**
  (rooms.createdAt, seasons.$sid.pts) — 없으면 쿼리 거부 → 빈 목록 버그.

---

## 6. 진행 상황 / TODO (Stage)
- [x] **Stage 1**: 신규 캐릭터 규칙엔진 + 의사 수정 + idle + 테스트 27건.
- [x] **Stage 2**: 액션바 특수행동줄 + 타겟선택(더블빵야 2명 순차) + CPU AI(운빵/더블/저주) +
      ??? 변환(effectiveChar) + 결과 배너·사운드. analyze 0 / 54 테스트. (에뮬 검증은 Stage 5)
- [ ] **Stage 3**: 턴 20초 타이머 + 시간초과 멘트 + 그림자(표시 숨김).
- [ ] **Stage 4**: 파파라치 엿보기 페이즈(온라인 대기 + 이펙트).
- [ ] **Stage 5**: ??? 해금 게이트 + 캐릭터 탭 정리 + 에뮬 검증 + 배포.

## 7. 유지보수 원칙
- 규칙 바꿀 일은 **party_logic.dart 한 곳**. 바꾸면 characters_test.dart에 케이스 추가.
- 캐릭터 추가: characters.dart(enum 끝에 append + CharDef) → party_logic 판정 → 테스트 → UI(action_bar/이펙트) → 이 문서 갱신.
- 새 RTDB 정렬 쿼리 추가 시 `.indexOn` 규칙 동반.
- 배포 전: `flutter analyze`(0) + `flutter test` + 에뮬 스모크 + 시크릿 스캔(pre-push 자동).
