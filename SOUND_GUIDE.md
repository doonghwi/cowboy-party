# 사운드 가이드 — 카우보이 파티

게임 사운드는 **효과음(SFX)** 과 **배경음악(BGM)** 두 갈래.

## 1. 효과음 (SFX) — 이미 완비

- 생성: `python3 tool/make_sounds.py` (순수 stdlib, 저작권 0, 재현 가능 / seed 고정).
- 출력: `assets/sounds/*.wav` 12종 — click, confirm, reload, shot, super, shield, trap, smoke, hit, win, lose, coin.
- 재생: `lib/audio/sfx.dart`의 `Sfx`. 음소거 토글은 SharedPreferences `sfx_muted`.
- 전 게임 이벤트(오프라인·온라인)에 연결됨 — 발사/명중/회피/방어/덫/연막/슈퍼/장전/승패/구매/탭.
- 합성 품질: 총성에 협곡 에코(reverb), 팡파레·임팩트에 하모닉·서브 베이스 레이어.

효과음을 바꾸려면 `make_sounds.py`의 해당 `write_wav(...)` 블록만 고치고 다시 실행하면 끝(파일명 고정이라 코드 재배선 불필요).

## 2. 배경음악 (BGM) — Suno로 제작해 드롭

코드 인프라는 준비됨 (`lib/audio/sfx.dart`의 `Bgm`). **파일만 `assets/music/`에 넣으면 자동 재생**.

| 파일 | 용도 | 재생 위치 | 코드 볼륨 |
|---|---|---|---|
| `assets/music/menu.mp3` | 메뉴/상점/랭킹/보상 | `shell.dart` initState | 0.55 |
| `assets/music/battle.mp3` | 게임 진행 중(오프·온라인) | `*_game_screen.dart` initState | 0.45 |

- 화면 전환 시 페이드아웃→페이드인으로 부드럽게 교체.
- 음소거 토글(우상단 스피커)이 효과음+BGM **둘 다** 제어 (`Sfx.setMuted` → `Bgm.applyMute`).
- 파일이 없으면 그냥 무음 (앱 안 깨짐). 그러니 Suno 곡 받기 전에도 빌드/실행 정상.

### 2-1. Suno 프롬프트 (복붙용)

> Suno는 공식 API가 없어 자동 생성 불가 → 아래 프롬프트로 직접 생성하세요.
> **Instrumental 토글 ON**(가사 없이), 가능하면 **Pure/Instrumental 모드**. 유료 플랜이라야 상업 사용 가능(앱 스토어 배포).

**① 메뉴 (menu.mp3) — 느긋한 살룬 분위기**

- Style/Genre:
```
spaghetti western, lazy saloon honky-tonk, warm acoustic guitar, soft whistling melody, light hand percussion, upright piano, laid-back swing, looping background music for a casual game menu, cheerful and relaxed, no vocals, instrumental
```
- 길이/구조: 60~90초, 강한 인트로/엔딩 없이 균일한 루프 느낌. (Suno에 "no big intro, steady groove, seamless loop" 추가)
- BPM 느낌: 90~105, 메이저 키, 밝게.

**② 전투 (battle.mp3) — 긴장되는 결투**

- Style/Genre:
```
spaghetti western showdown, tense duel, twangy electric guitar tremolo, driving low tom and stomp percussion, ocarina/whistle motif, suspenseful Morricone-style, building tension, loopable game battle music, energetic but not chaotic, no vocals, instrumental
```
- 길이/구조: 60~90초, 일정한 텐션 유지(빌드업 후 급정지 X), 루프용.
- BPM 느낌: 110~130, 마이너/모달, 긴장감.

**③ (선택) 승리 짧은 스팅어** — 이미 `win.wav` SFX가 있어 필수는 아님. 원하면:
```
short triumphant western fanfare sting, brass and guitar, victory jingle, 4 seconds, no vocals, instrumental
```

### 2-2. 루프 가공 (중요)

Suno 곡은 보통 인트로/아웃트로가 있어 **그대로 루프하면 이음새가 끊긴다.** ffmpeg로 가공:

```bash
# (a) 앞 인트로 잘라내고 본 루프 구간만 (예: 4초~64초)
ffmpeg -i suno_menu.mp3 -ss 4 -to 64 -c copy menu_cut.mp3

# (b) 끝<->앞 0.5초 크로스페이드로 이음새 없애기
ffmpeg -i menu_cut.mp3 -filter_complex \
  "[0]afade=t=in:st=0:d=0.5[a];[a]afade=t=out:st=59.5:d=0.5" menu.mp3

# (c) 볼륨 정규화(선택)
ffmpeg -i menu.mp3 -af loudnorm assets/music/menu.mp3
```

> 정밀 무이음 루프가 필요하면 Audacity에서 zero-crossing 기준으로 자르는 게 가장 깔끔.

가공 후 `assets/music/menu.mp3`, `assets/music/battle.mp3`로 저장 → `flutter run`이면 끝.

### 2-3. 라이선스 체크 (배포 전 필수)

- Suno **유료 플랜** 출력물인지 확인 (무료 플랜은 상업 사용 불가).
- `CREDITS.md`에 음원 출처/라이선스 한 줄 추가.
- 출시 게이트 `LEGAL_CHECKLIST.md` 통과 시 BGM 라이선스 항목 확인.
