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

### 오디오 (audio/sfx.dart) — 효과음 + 배경음악
- **`Sfx`**: 효과음. `Sfx.play('shot')` → `assets/sounds/shot.wav`. 음소거 토글은 SharedPreferences `sfx_muted`.
  실패는 전부 삼킨다(소리는 앱을 절대 안 깬다). 발사/명중/회피/방어/덫/연막/슈퍼/장전/승패/구매/탭에 연결.
- **`Bgm`**: 배경음악(루프). `Bgm.play('menu'|'battle')` → `assets/music/<name>.mp3`(Pixabay 음원, 루프 가공). 단일 플레이어 +
  페이드아웃→인 전환. **메뉴=shell initState, 전투=`*_game_screen.dart` initState, 게임 dispose 시 'menu'로 복귀.**
  - **볼륨**: 배경 수준으로 매우 낮음 — menu 0.03 / battle 0.024(효과음 0.7~1.0 대비). 호출부에서 `volume:`으로 지정, 기본값 `_vol=0.03`.
  - **페이드인**: `_fadeIn()` 약 2초 ease-in(제곱 곡선) — 탁 시작하지 않고 서서히 스며듦.
  - **웹 자동재생 대응**: 브라우저는 첫 제스처 전 오디오를 막음 → `main.dart`에서 `kIsWeb`일 때 첫 PointerDown에 `Bgm.kickStart()`로 현재 트랙을 살림(모바일은 미적용). mp3 없으면 무음(앱 안 깨짐).
  - 음소거는 `Sfx`와 공유(`Sfx.setMuted`→`Bgm.applyMute`). **토글 UI 2곳**: shell 우상단 스피커 버튼(`volume_up`/`volume_off`) + 설정 시트의 '효과음' 스위치.
- **에셋**: 효과음 = `tool/make_sounds.py`(순수 stdlib, seed 고정, 저작권 0) 합성 12종(총성 협곡 에코·하모닉 팡파레·서브 베이스).
  BGM = Pixabay Content License 2곡(menu=Texas Cowboy Wild West Intro 263183, battle=Sound of Desert 335725), ffmpeg crossfade-fold 무이음 루프 가공. 출처·라이선스 `CREDITS.md`, 가이드 `SOUND_GUIDE.md`.

### 위젯 (widgets/)
- **juice.dart**(`JuiceController`/`JuiceLayer`, v12): 타격감(주스) — **화면 흔들림**(감쇠 사인, 두 축 주파수 상이) + **피격 붉은 비네트**. effects.dart와 같은 원칙(표시 전용·게임상태 미참조·의존성 0). 양 게임 화면이 테이블 Stack을 JuiceLayer로 감싸고, 리빌 시 `_playRevealJuice`가 강도 결정: 내 사망 14+비네트 > 내 피격 13+비네트 > 슈퍼 12 > 남 피격 6 > 발사만 2.5 (햅틱 heavy/medium/light 동반). 온라인 `_handleReveal`(턴 리빌+"마지막 한 방" 즉시종료 케이스 둘 다)·오프라인 `_resolve`에서 구동.
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
- **meta/analytics.dart**(`Ana`, v12): Firebase Analytics 이벤트 로깅(제품 지표 — 리텐션·퍼널). **실패 전부 삼킴**(Sfx와 같은 원칙 — 분석은 앱을 안 깬다). 이벤트 사전은 파일 상단 주석이 단일 출처: `game_start`/`game_end`(mode=cpu|online·players·won)·`char_buy`·`daily_claim`·`mission_done`·`share_result`. 발화 지점: 게임 화면 2곳(start/end)·meta_service(구매/출석/미션)·결과 공유 버튼. 새 이벤트 추가 시 사전 주석도 갱신.
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

## 최근 변경 (2026-07)
### v13 (2026-07-02, Play 광고 ID 선언 대응)
- v12의 firebase_analytics가 매니페스트에 `AD_ID` 권한을 자동 병합 → Play "광고 ID 선언이 불완전함" 경고. **광고 ID를 안 쓰므로 권한 제거로 대응**: AndroidManifest에 `tools:node="remove"` 3종(AD_ID·ADSERVICES_AD_ID·ATTRIBUTION) + `google_analytics_adid_collection_enabled=false`. `aapt dump permissions`로 제거 검증. 콘솔 선언 답안은 `store/data_safety.md` §5(**"사용 안 함"**, v13 이상 업로드 전제). versionCode 13·kBuildNo 13. Analytics 기능 손실 없음(앱 인스턴스 ID 기반).

### v12 (2026-07-02, 성장 배치 W1~W4 — PRODUCT_PLAN.md 로드맵 실행)
- **W1 지표**: `meta/analytics.dart`(`Ana`) 신설 + firebase_analytics 도입. 이벤트 6종(game_start/game_end/char_buy/daily_claim/mission_done/share_result) — 이제 D1 리텐션·퍼널을 Firebase 콘솔에서 측정 가능(Analytics 대시보드 반영은 최대 24h).
- **W2 타격감**: `widgets/juice.dart` — 피격 화면 흔들림+붉은 비네트+햅틱(강도 위계는 §위젯 참조). 게임로직 0줄, 표시 레이어만.
- **W3 결과 공유**: 승리 결과 카드에 "자랑하기/우승 자랑하기" 버튼(온/오프) → share_plus 네이티브 시트(실패 시 클립보드 폴백), 웹 링크 포함. (일일미션은 #9에서 기구현.)
- **W4 ASO**: `store/listing_ko.md`·`listing_en.md` 리뉴얼 — 훅 강화, 주간 랭킹·일일미션·타격감 반영, 캐릭터 15종 정정(??? 비활성), 스크린샷 촬영 가이드 추가. versionCode 12·kBuildNo 12.

### v10~v11 (2026-07-02 야간)
- **대기실 준비 기능 (v10)**: 방 만들기(공개/비공개) 대기실에서 **방장 빼고 전원 준비해야 시작**. 비-방장=`준비하기/준비완료` 토글(`online_service.setReady`→`rooms/$code/ready/p$seat`), 방장 시작버튼은 `준비 대기(N/M)`→전원준비 시 `시작!`, 준비 안 됐는데 누르면 스낵바 안내(`online_game_screen._hostStart`). 방장=참여좌석 중 최저. **빠른시작(match) 방은 게이트 제외**(봇 자동시작). startGame/resetBoard가 `ready` 초기화.
- **관전입장 "꽉 찼어요" 버그 수정 (v11 미빌드)**: 시작된 방은 좌석이 `seatCount`(그 판 인원)만큼이라, 버튼 full 판정을 capacity(6)로 하면 5인게임(5/5)을 "안 꽉참"으로 오판→"관전입장"눌렀는데 joinRoom은 full. `PublicRoomInfo`에 `seatCount`+`isFull` getter 추가, `play_tab`이 이걸로 판정·표시.
- **iAmOut "연결끊겨 나가졌어요" 오안내 수정 (v11 미빌드)**: `computeView`에서 `mySeat>=seatCount`(봇방 시작 직전 난입 등)를 '쫓겨남'이 아니라 **'다음 판 관전'(iAmLate)** 으로. 다음 라운드 리셋에서 정상 합류.

### versionCode 9 (2026-07-01~02)
- **랭킹 월간→주간** (`season_service.dart`): `seasonId`가 이제 그 주 **월요일 날짜**(`yyyy-MM-dd`) → 매주 월요일 자동 리셋(별도 크론 불필요, `seasons/$sid` 와일드카드라 규칙 변경 없음). `prevSeasonId`/`fetchPrevTop`로 **지난주 챔피언 1~3위**를 랭킹 상단 카드에 표시(`ranking_tab.dart`). 게스트 로컬포인트(`_seasonPtsLocal`)도 `_rollSeasonWeek`로 주간 리셋(`meta_service.dart`).
- **??? 캐릭터 비활성화**: `characters.dart`의 mystery `CharDef`만 **주석 처리**(kCharacters 순회하는 선택화면·게임설명 자동 제외). enum `CharId.mystery`·`resolveMystery`/`effectiveChar`/공개셋은 **휴면 유지**(인덱스·참조 안 깨짐). 이미 장착했던 유저는 `meta_service` init에서 일반인 복구. 다시 켜려면 그 CharDef 주석만 해제.
- **컴퓨터전 봇 AI 개편** (`cpu_ai.dart`): 봇 전부 CpuAi 1개 공유 → **좌석별 `_BotProfile`**(skill·aggression·caution·focus·grudge, 게임 시작 `beginGame()`에서 리롤). `_pickTarget`이 "최다 무장만" 노려 **사람에게 몰빵**하던 것 → focus·**반격(grudge, `lastMoves`)**·랜덤 분산으로 표적 흩어짐. 결투 반응속도 `showdownReactionMs(seat)`=실력 연동. 봇 이름 24개 서부풍 풀에서 매판 랜덤(`offline_game_screen._chosenBotNames`). **오프라인 전용**(온라인은 CpuAi 미사용).
- **오디오 포커스 음악끊김 수정** (`audio/sfx.dart`): audioplayers 기본 `audioFocus: gain`이라 효과음(클릭) 재생 때마다 BGM 포커스를 뺏어 멈추던 버그(웹은 무관). 전역 `AudioPlayer.global.setAudioContext(AudioContext(android: audioFocus:none, iOS: mixWithOthers))`로 해결. 클릭음은 아예 `HapticFeedback.selectionClick()` **햅틱**으로 대체.
- **배포앱 구글 로그인** — SHA를 **두 곳**에 등록해야 함: ① Firebase 콘솔 Android앱 SHA 지문(OAuth), ② **Google Cloud Console → API 및 서비스 → 사용자 인증정보 → API키(AIza…) → 애플리케이션 제한 → Android → 패키지+SHA-1**(API키 호출 허용). `auth_service`에 `serverClientId`(웹클라 id) 명시 + `catch`에서 실제 예외 노출. 상세는 루트 `_make-new-app/LESSONS.md` 2026-07-02 항목.
- **빌드번호 표시**: `shell.dart` `const kBuildNo`(versionCode와 손으로 일치) → 설정 시트 하단 "빌드 N". 로그인류 디버깅은 "폰에 뜬 빌드번호"부터 확인(Play 비공개테스트는 옛버전 캐시).

## 봇 러너 (온라인 봇 채우기) — **구현 완료·가동 중** (`bot_runner/`, 상세 README)
빠른시작·공개방을 봇이 채워 게임 성사 + 로비 북적임 연출. 순수 Dart(http만), 맥미니 상시실행. **앱과 동일한 규칙엔진**(`bot_runner/lib/game/`=`char_core`·`party_logic`·`cpu_ai`를 `tool/sync_core.sh`로 앱에서 복사 → 버전스큐 방지). **앱 재빌드 불필요**(봇은 일반 클라이언트처럼 RTDB에 write).
- **char_core 분리(P1 완료)**: 룰엔진이 `characters.dart`→flutter 의존이라 헤드리스 불가 → 순수 Dart `lib/game/char_core.dart` 신설(CharId·seededRoll·mystery/reveal·charFromIndex·kPlayableCharIds). characters.dart=UI(CharDef·kCharacters·charDef)+char_core 재export. party_logic은 char_core만 import(순수). 앱 analyze0/test204 유지.
- **구성**: `config.dart`(봇40·튜닝) · `auth.dart`(Auth REST 저장형익명) · `rtdb.dart`(REST) · `game_replay.dart`(=computeView 축약, seed `{code}#{gameNo}`, **좌석은 uid로 찾음**, 무승부→drawTurn·참가자 + showdown.winner/결투가 자동승 반영) · `bot_client.dart`(입장·하트비트·턴제출·결투탭·**결투 심판 hostRefereeGame**·랭킹기록·퇴장 + 공개방 프리미티브 createPublicRoom/joinSeat/setReady/hostStartGame/resetToLobby/removeSeatEntry) · `bot_pool.dart`(공유 busy풀+예비) · `matchmaker.dart`(빠른시작 채움) · `social_sim.dart`(공개방 3개 상시·churn·호스트교체·사람있어야시작) · `room_janitor.dart`(죽은방 삭제) · `bin/runner.dart`(3개 동시) · `bin/testgame.dart`(빠른시작 e2e) · `bin/showdowntest.dart`(결투 e2e).
- **핵심 버그·수정(1차)**: ①**좌석 압축**—startGame이 좌석 압축(p0..pn)해서, churn으로 좌석 밀린 봇이 입장seat 그대로 쓰면 엉뚱좌석 판단→가만히있음. `_gameLoop`이 매턴 `_seatOfUid(data)`로 자기좌석 찾도록(+`_leave`도). ②**재큐**—끝낸 매칭방이 안지워져 다시빠른시작 시 옛방 재입장→janitor 매칭방 25초 청소. ③봇끼리 게임시작 방지(사람1명 필수). ④표적몰빵→focus↓+조준풀 절반 랜덤.
- **핵심 버그·수정(2차, 07-02 심야 — 전부 e2e 검증)**: ⑤**유령 플레이어**—startGame 좌석압축 뒤 SocialSim이 옛 좌석 키로 하트비트/지연 ready → `players/pX/seen`만 있는 id 없는 노드 생성 → `_humanCount`가 "사람"으로 오인 → 유령 기다리며 헛게임 시작→봇 전원 30초 스톨→"포기 퇴장" 폭주(로그 32건). 수정: SocialSim 매 틱 **uid 기반 좌석 재동기화**(resync) + `setReady`가 쓰기 직전 자기 좌석 재확인 + `_awaitStart` 하트비트도 uid 좌석. ⑥**사람 판정 강화**—id 없거나 하트비트 끊긴 좌석은 사람 아님(`socialHumanActiveMs` 12초 < grace 15초라 떠난 사람이 헛시작 못 유발), 호스트 봇이 유령·45초+ 끊긴 좌석 청소(`socialEvictStaleMs`), matchmaker/janitor도 유령 무시. ⑦**RangeError**—seatCount 밖 늦은 입장 좌석이 `r.submitted[seat]` 인덱스 초과 → `_gameLoop`에 seat≥n이면 관전상태로 퇴장 가드 + `_claimSeat`이 입장 직전 재확인(사람 좌석 덮어쓰기 방지). ⑧**결투 탭 무효**—봇이 탭 값으로 반응시간(250 등)을 기록했는데 앱 호스트는 `tap≥goAt`(서버시각)만 유효 처리 → 봇 탭 전부 무효였음. `goAt+반응ms`(서버시각)로 수정.
- **결투(무승부) 완성**: 봇방 무승부 시 호스트 봇이 앱 호스트 대신 심판(`hostRefereeGame`: showdown 생성→유효 탭 중 최속 승자 확정→전원 부정출발 시 라운드 재시작→15초 무응답 포기). game_replay가 computeView처럼 showdown.winner·결투가 자동승을 won으로 반영. 라운드 종료 후 4~7초 여유 두고 리셋(사람이 결과 볼 시간). e2e `bin/showdowntest.dart` PASS(심판 개시→탭 2개 유효→빠른 쪽 승자→랭킹 기록).
- **봇 성향**: config `BotSpec(name, fixedChar, personality, reloadOnly)`. personality는 `CpuAi.setProfile(seat, aggression/caution...)`로 주입(앱 cpu_ai에 setProfile 추가).
- **운영**: 실행 `bash bot_runner/run_local.sh`(키 gitignore) / 상시 `com.doonghwi.cowboy-bot-runner.plist` / 계정 `bot_creds.json`(비밀). 서버 API키=`COWBOY_AUTH_API_KEY`(Cloud Console 애플리케이션제한 없는 키. google-services Android키는 서버 차단됨).
- **e2e 검증(07-02 심야)**: ⓐ testgame 풀게임(봇 채움→턴 진행→승자·랭킹) ⓑ 유령 방=봇 미투입+janitor 즉시 삭제 ⓒ 가짜 사람 시나리오=활동 사람 준비→3초 시작 / 사람 잠적→**유령 재시작 0회**·47초 좌석 청소 ⓓ showdowntest 결투 PASS. 러너 재시작 후 오류·포기퇴장 0건.
- **주의**: 앱 규칙 바꾸면 `bash tool/sync_core.sh`+`dart test`(재현 테스트 6개). 봇 랭킹 반영은 실유저 늘면 `bot_client._recordWin` 가드로 끄기(README).
- **남음**: v11 빌드(관전·iAmOut) · 폰 실기기 확인 · 사회성 튜닝(빈도·인원) 실사용 관찰.

## 후속(선택)
- 그림자/파파라치 등 신규 캐릭터의 SeatView 발동 배지(현재 일부는 배너+사운드로만 표시).
- 온라인 엿보기 2-클라이언트 실기기 검증(현재 computeView 단위테스트 + 오프라인 동작으로 검증됨).

## iOS 스토어 준비 (App Store, 계정 전 사전작업 완료)
> 상세·체크리스트는 `STORE_RELEASE_PREP.md`(F절)·`store/ios_release.md`·`store/appstore_metadata.md`.
- **PrivacyInfo.xcprivacy** (`ios/Runner/`) — 수집데이터(uid·닉네임·플레이기록, Linked·비추적) +
  필요사유 API(UserDefaults/파일타임스탬프/부팅시각) 선언. pbxproj Resources에 연결 → `Runner.app` 최상위 번들 검증.
- **Runner.entitlements** — `com.apple.developer.applesignin`(계정 뒤 Xcode capability로 자동 연결).
- **Info.plist**: `ITSAppUsesNonExemptEncryption=false`(수출규정 자동통과), 구글 URL scheme·아이콘 세트 확인.
- iOS 릴리스 빌드 `flutter build ios --release --no-codesign` 통과(서명/업로드만 Apple Developer 계정 필요).
- 스크린샷: 6.9"(1320×2868)·iPad 13"(2064×2752) 홈 캡처(`store/screenshots/ios/`), 나머지는 README 절차로 추가.

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
