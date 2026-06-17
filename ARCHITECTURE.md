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
- 결투가: 전원 동시 사망(showdown 참가자) 중 결투가가 정확히 1명 → 반응속도 없이 자동 승리. 판정은 순수함수 `duelistShowdownWinner(party_logic.dart)` 하나로 온라인 computeView·오프라인 _beginShowdown이 공유(결투가 0·2명 이상이면 자동승 무효 → 반응속도 결투).
- 전원 동시 사망 → 반응속도 결투(showdown)로 1인 가림.

---

## 2. 캐릭터 (CharId, characters.dart)
> enum 값은 **append만** (RTDB에 정수 index로 저장됨). 능력 확률은 전부 `seededRoll`(결정적).
> v3에서 가격 ×10, **일반인(commoner)만 무료 기본**, 리셋터 신규.

| 직업 | 능력 | 배치(slot) | 코인 |
|---|---|---|---|
| **일반인 commoner** | 능력 없음 — 장전/방어/빵야 정공법. **유일한 무료 기본** | none | 0 |
| 준비자 prepper | 총알 1발 장전 상태로 시작 | none | 1000 |
| 스나이퍼 sniper | 빵야가 **20%** 확률로 방어 무시(B1) | none | 1500 |
| 스피드로더 speedloader | 장전 시 50%로 +2발 | none | 2000 |
| 의사 doctor | 게임당 1회 치명타 버팀 → **버틴 즉시 총알 0**(B7) | none | 2500 |
| 스모커 smoker | 연막(게임당 2회, 행동과 병행): 그 턴 공격 발당 50% 회피 | parallel | 3000 |
| 사냥꾼 hunter | 덫(게임당 1회, 한 턴 소모): 나를 쏜 일반탄 전부 반사 | turnSlot | 3500 |
| **리셋터 resetter** | **무효**(게임당 1회, 한 턴 소모): 그 턴 다른 모두의 행동 결과 무효(총알·자원은 소모)(B6) | turnSlot | 4000 |
| 결투가 duelist | **반응속도 결투(showdown)에 가면 반드시 승리**. 평소 효과 없음(B2, 결투가끼리면 무효) | none | 4500 |
| 평화주의자 pacifist | 빵야 불가, 장전 6회 시 즉시 승리 | none | 5000 |
| 그림자 shadow | 장전·방어·**탄약수가 상대에게 안 보임**(빵야·피격 시 방어는 드러남) | none(표시) | 5500 |
| 러시안룰렛 roulette | **운명의 방아쇠**(상시): 50:50로 나/상대 사망, 상대 방어 시 내가 죽음. **연막 회피 적용(C1)** | alwaysRow | 6000 |
| 쌍권총 dualgun | **더블 빵야**(상시): 총알 2발로 두 명 동시 저격. **두 대상 모두에 탄도 표시**(effects.dart `ShotsLayer`가 firedTarget+firedTarget2 그림) | alwaysRow | 6500 |
| 파파라치 paparazzi | **엿보기**(게임당 1회): 1명 행동 미리보고 내 행동 결정 (온라인은 대기 페이즈) | turnSlot | 7000 |
| 부두술사 voodoo | **저주**: 대상을 10턴(kCurseFuse) 뒤 사망. 부두술사 죽으면 해제. 남은 턴 모두에게 표시(C2). **저주는 대상 좌석별로 독립**(`PartyState.curseFuse/curseCaster`가 List) — 부두술사 여럿이 각자, 동시에 여러 명을 저주 가능. **이미 저주 중인 대상에 재시전은 무효**(도화선 유지 — 재시전으로 10 리셋해 죽음을 무한 연기하는 것 방지, 제보 #2) | turnSlot | 7500 |
| ??? mystery | 미공개 시작, **정체 공개(B8)**: 변신 직업을 `mysteryRevealsAtStart`(characters.dart 순수함수)로 분류 — 능동 신호 없는 직업(일반인·준비자·평화주의자·그림자·결투가=`kMysteryStartRevealChars`)은 **시작 즉시 공개**, 나머지 10직업(`kMysteryTurnTriggerChars`)은 **능력 발동 턴 공개**(파파라치는 엿보기[peekUsed]). 두 집합의 합=kMysteryPool 보장(characters_test). 직업은 매 게임 랜덤(resolveMystery). 전 캐릭터 보유 시 구매 | 메타 | 10000 |

### 특수행동 배치 규칙 (D3, SpecialSlot)
캐릭터 전용 행동은 UI에서 **종류별로 정해진 자리**에 놓는다 (`SpecialSlot`, characters.dart):
- **parallel** — 기본 행동과 *함께* 쓰는 토글. 행동 칸 **위 얇은 토글 바**. 예) 스모커 연막.
- **turnSlot** — 한 턴을 *소모*하는 단독 행동. 기본 3칸(장전/방어/빵야) 옆 **4번째 칸**. 예) 사냥꾼 덫, 리셋터 무효, 파파라치 엿보기, 부두 저주.
- **alwaysRow** — 상시 공격형. 기본 행동 줄 **아래 별도 줄**. 예) 운명의 방아쇠, 더블 빵야.
- **none** — 특수행동 없음(패시브/표시형).
action_bar.dart가 이 분류대로 렌더하고, party_logic이 판정한다.

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
  - **빠른 시작 매칭 `quickMatch`**: ⓪ **`_ensureTimeSync()`**(서버시계 오프셋
    적용 대기, 최대 5초) — **기기 시계가 어긋난 두 사람**(친구폰끼리)이 서로의
    `seen`/`createdAt`을 "오래됨"으로 오판해 같은 방을 못 찾던 **실기기 매칭 실패의
    근본 원인**. createRoom/joinRoom도 동일하게 await(seen이 서버시계 기준). →
    ① 모이는 중인 매칭 방이 있으면 합류(staleness 창 30초로 넉넉) →
    ② 직전 버킷 방 합류 시도(경계 갈림 보정) →
    ③ **30초 버킷 결정 코드**(`'M'+bucket.toRadixString(36)`)로 *수렴* —
    같은 시간대에 누른 사람은 같은 코드를 계산하고, `_createMatchRoomIfAbsent`
    트랜잭션이 *한 명만* 만들고 나머지는 joinRoom으로 합류. (예전엔 각자 임의 코드로
    방을 만들어 동시 탭 시 서로 못 만나던 버그 — "1명만 보이고 매칭 실패".)
  - **닉네임 유일성 `claimNickname`**: `nicknames/<정규화키>`=uid 트랜잭션으로 전역
    선점. 다른 uid가 점유 중이면 false. 정규화는 소문자+금지문자 치환(`_nickKey`).
    서버 식별자 없으면(오프라인) 통과(강제 불가). meta `changeNickname`이 **async**로
    호출 — 중복이면 "이미 존재하는 닉네임이에요"로 거절(변경권 미소모).

### 화면 (screens/)
- **shell.dart**: 하단 4탭(플레이/캐릭터/랭킹/보상) + 코인칩 + 설정시트(닉네임/사운드/디스코드).
  `kDiscordUrl`, `kShowAdPlaceholder`.
- **play_tab.dart**: 모드 버튼 + 공개방 목록(폴링).
- **online_lobby_screen.dart**: 방 만들기/코드 입장. 배경은 `DesertBackground`를
  **body 래퍼**(BoxConstraints.expand)로 깐다 — Stack(loose)으로 깔면 짧은 내용
  높이에 맞춰져 아래가 단색으로 끊긴다(주의).
- **닉네임 비속어 필터(`meta/profanity.dart`)**: `assets/badwords_ko.json` 로드.
  정규화는 `\p{P}\p{S}`(유니코드)만 제거 — **`\W`는 한글을 통째로 지워 한국어가
  전혀 안 걸리니 금지**. `changeNickname`은 검사 전 `Profanity.init` await.
- **online_game_screen.dart** / **offline_game_screen.dart**: 실제 게임 진행(공유 위젯 사용).
- **characters_tab.dart**: 캐릭터 카드(해금/장착). **rewards_tab.dart**: 출석. **ranking_tab.dart**: 시즌 랭킹.
- **how_to_play_screen.dart**: 규칙·캐릭터 설명(캐릭터 추가 시 자동 반영 — kCharacters 순회).

### 위젯 (widgets/)
- **action_bar.dart**: 하단 행동 선택 바. **circular_table.dart**(+ seat_card.dart): 원형 테이블·
  트레이서·발동 이펙트. **emo.dart**: Twemoji 이미지. **online_showdown.dart**: 반응속도 결투.
  **super_flash.dart**: 슈퍼빵야 연출. **top_toast.dart**: 상단 토스트(코인 등).
- **character_portrait.dart**(이식, cowboy_redesign): `CharacterPortrait`(얼굴 클로즈업 원형 아바타,
  `assets/characters/<CharId.name>.png`, 누락 시 `charDef.icon` 폴백, `dim`=미보유) + `CharacterHero`
  (상점 상세용 풀 일러스트, BoxFit.contain 정사각 전체·화면 55%캡). **순수 표시** — 게임상태 미참조.
  적용처: 상점 카드/상세, 좌석 프로필 팝업, 라이브 좌석(생존자=초상, 빈자리=사람/탈락=해골 유지).
- **effects.dart**(가산 레이어, **전부 Canvas-only·IgnorePointer·게임상태 미참조·의존성 0** — flame/셰이더 미도입, 출시 안정성·웹 호환 우선):
  - `SmokePuff`: 연막 구름. circular_table 리빌에서 `smoked`(연막 발동=차지 소모, **회피 성공 여부와 무관**) 좌석 위 표출. ('회피!' 텍스트 라벨은 `evadedFx` 별개 유지.)
  - `ShotsLayer`(+ `ShotSpec`/`ShotResult`): 빵야/슈퍼빵야 애니메이션 탄도. 지속 베이스 라인+화살표 위에 머즐 플래시·이동 코어·임팩트(명중=충격링+파편/방어=세이지 디플렉션 호/빗나감=먼지). 슈퍼=노바 볼트+스타버스트. 관통(`ShotSpec.pierce`)=흰 랜스. **임팩트는 타깃 좌석의 기존 리빌 플래그(hit/defend/evaded/smoked/reflected)에서 유도** — 정적 `_TracerPainter` 대체.
  - `ShieldPulse`(방어 충격파 링)·`ReloadBurst`(장전 탄피 솟구침, 더블장전 강화)·`HealSparkle`(의사 자힐 초록 십자)·`ResetRipple`(리셋 무효 워시)·`CurseAura`(부두 저주 보라 오라+모트, 만료 사망=데스 버스트). circular_table `_effects()`/리빌 루프에서 해당 플래그 시 표출.
  - **(E) 퀄 통일/누락0**: `ShotsLayer` 머즐을 다중 파티클 분사(연막식 운동학, white→탄색 보간)로 격상 + 일반 탄도 글로우 + 명중 이중 충격파/파편 강화. `RouletteSpin`(러시안룰렛 리볼버 실린더 스핀→딸깍, `lastMove.kind==roulette` 구동) · `CurseBolt`(저주 시전 시 시전자→대상 떨리는 테더+착탄 링, `lastMove.kind==voodoo`+`target` 구동). **신규 플러밍 0** — 전부 `lastMove`/기존 리빌 플래그로 구동돼 오프/온라인 자동 동일. 전 특수행동 이펙트 커버(장전·방어·빵야·슈퍼빵야·덫반사·저주(상시+시전)·룰렛·더블·관통·의사·무효).
  - **(F) 룰렛 자기-꽝**: `TurnOutcome.rouletteSelf`(좌석별 bool, 표시용 파생 — 인코딩/판정 불변) 노출 → 오프라인 `_lastOut`·온라인 `SeatView.rouletteSelfFx`까지 배선(이것만 플러밍 추가, 게임 로직 0줄). `RouletteBust`(붉은 충격 플래시+적색 스타버스트+'꽝!'+반동) — 실린더 인트로는 양쪽 동일, 자기-꽝일 때만 시전자 좌석에 추가(상대 명중과 구분).

### 메타/경제
- **meta/meta_service.dart**(`Meta.I`): 코인·해금·장착·출석·**선물코드**(redeemGiftCode). 로컬(SharedPreferences) + 로그인 시 /users/$uid 미러.
- **meta/gift_codes.dart**: 선물 코드 정의. `kGiftCodes`(빌드 내장 공용 코드, 예 `thankyou`→100000) +
  단일 코드는 RTDB `/giftcodes/<code>`. 공용=계정당 1회(_redeemed), 단일=전체 1명 선착순(`claimedBy` 트랜잭션). 입력은 소문자 정규화.
- **meta/auth_service.dart**(`AuthService.I`): Google + **Apple**(`signInWithApple`, nonce+Firebase apple.com,
  iOS/macOS/웹만 `showAppleButton`) + 게스트(익명). 콘솔 미설정이어도 폴백. `isGoogle`=실제 클라우드 계정(구글/애플) 게이트.
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
nicknames/<정규화키>: uid   (닉네임 전역 유일성. .write: 빈칸이거나 내 uid일 때만)
dailyapp_stats/cowboy_party: 사용량(중앙 대시보드)
```
- 보안 규칙: `database.rules.json`. **orderByChild 쓰는 경로엔 반드시 `.indexOn`**
  (rooms.createdAt, seasons.$sid.pts) — 없으면 쿼리 거부 → 빈 목록 버그.

---

## 6. 진행 상황 / TODO (Stage)
- [x] **Stage 1**: 신규 캐릭터 규칙엔진 + 의사 수정 + idle + 테스트 27건.
- [x] **Stage 2**: 액션바 특수행동줄 + 타겟선택(더블빵야 2명 순차) + CPU AI(운빵/더블/저주) +
      ??? 변환(effectiveChar) + 결과 배너·사운드. analyze 0 / 54 테스트. (에뮬 검증은 Stage 5)
- [x] **Stage 3**: 턴 20초 타이머(온/오프, 만료 시 idle+멘트) + 그림자(상대에게 탄약/장전·방어 숨김,
      빵야·피격시 방어는 드러남). kTurnSeconds/kIdleFlavors, SeatView.hideAmmo/hideAction.
- [x] **Stage 4**: 파파라치 엿보기 — **오프라인·온라인 모두 완성**.
      온라인: `startPeek`(peek/t<turn> + peekUsed) → 전원 제출되면 computeView가 peekActive로
      `RoomView.iAmPeeker/peekedMove` 노출 → 재선택 제출. 다른 사람은 "엿보는 중" 대기.
      호스트 언블록(_maybePeekUnblock, peekStale 10초+). computeView 엿보기 테스트 3건.
- [x] **Stage 5**: ??? 해금 게이트(canBuyMystery, 전 캐릭터 보유 시) + 선물코드 + 에뮬 검증 + 배포.

## 후속(선택)
- 그림자/파파라치 등 신규 캐릭터의 SeatView 발동 배지(현재 일부는 배너+사운드로만 표시).
- 온라인 엿보기 2-클라이언트 실기기 검증(현재 computeView 단위테스트 + 오프라인 동작으로 검증됨).

## 7. 유지보수 원칙
- 규칙 바꿀 일은 **party_logic.dart 한 곳**. 바꾸면 characters_test.dart에 케이스 추가.
- 새 RTDB 정렬 쿼리 추가 시 `.indexOn` 규칙 동반.
- 배포 전: `flutter analyze`(0) + `flutter test` + 에뮬 스모크 + 시크릿 스캔(pre-push 자동).

### 캐릭터 추가/수정 루프 체크리스트 (I1) — 캐릭터를 건드릴 때 **전부** 점검
1. **설명(ability)** — characters.dart `CharDef.ability` 수치 포함 한 문장. enum은 **append만**.
2. **사운드** — 발동 시 Sfx 연출(필요 시 추가).
3. **캐릭터 이펙트** — circular_table `_effects`/`_fxLabel` + seat 배지(발동 시각 표시).
4. **특수행동 배치(D3)** — `SpecialSlot` 지정(parallel/turnSlot/alwaysRow/none) + action_bar 렌더.
5. **밸런스/판정** — party_logic.dart `resolvePartyTurn` 한 곳. 랜덤은 `seededRoll`만(결정성).
6. **단위테스트** — characters_test.dart(규칙) / online_service_test.dart(표시·은폐·정체).
7. **게임방법/공지 반영** — how_to_play(자동 순회) 확인 + H1 공지(announcements.dart)에 한 줄.
8. **??? 풀 영향** — `kMysteryPool`(mystery·commoner 제외)에 자동 포함되는지. 능력이 ???로 변신 가능한지.
9. **온/오프라인 양쪽** — offline_game_screen + online computeView/SeatView 둘 다 배선.
