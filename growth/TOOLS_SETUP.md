# 에셋 생성 툴 연결 체크리스트 — 사용자 작업 안내

> 결론: **$0 조합만으로 시작 가능** (jsfxr 효과음 + Kenney CC0 + pub 패키지 — 이미지는 Gemini 무료 폐지로 웹 수동 or mflux, 섹션 1 참고).
> 유료 2개(Recraft·ElevenLabs, 합계 ~$10-15/월)는 스킨 시스템·시그니처 사운드 단계에서.

## 사용자가 해줄 연결 작업 (우선순위순)

### 1. Gemini API 키 — 이미지 생성 ⚠️ 2026-07-12 실측 정정
- ~~하루 ~500장 무료~~ → **틀림. API 무료 티어는 이미지 생성 한도 0**(전 이미지 모델 429 `limit: 0` 실측). 텍스트 모델만 무료.
- 품질 확인은 **AI Studio 웹**(aistudio.google.com)에서 무료 체험 — `~/Downloads/cowboy_art_samples/사용법_프롬프트.txt` 키트 참고.
- API 자동화(Claude가 직접 생성)하려면 셋 중 하나:
  (a) **Gemini 결제 연결**(Cloud billing) — 장당 약 $0.02~0.13, 이미지 편집·참조 변형 강점
  (b) **mflux 로컬**(무료 무제한, 디스크 8~24GB, 맥 M시리즈) — `pip install mflux`
  (c) **Recraft**($10 선불) — 스타일 고정 시리즈 생산에 최적
- 키 자체는 `~/.zshrc` `GEMINI_API_KEY`로 저장됨(텍스트 모델 검증 OK. 단 gemini-2.5-flash는 신규 사용자 404 — gemini-3 계열 사용).

### 2. [무료·승인만] jsfxr + Kenney — 효과음
- 사용자 작업 없음. Claude가 `npm i jsfxr` + Kenney CC0 오디오팩 다운로드.
- jsfxr는 JSON 파라미터→WAV라 Claude가 파라미터를 튜닝하며 무한 생성 가능(발사·히트·코인·UI 블립).
- Kenney는 CC0(표기 의무 없음, 가장 안전).

### 3. [무료·승인만] Flutter pub 패키지 — 파티클·햅틱·오디오
- `flutter_soloud`(저지연 SFX+피치, Flutter 공식 쿡북 권장) · `newton_particles`(파티클, Flame 불필요) · `haptic_kit`(게임급 햅틱). 전부 무료, 연결 불필요.

### 4. [무료·표기 필요] incompetech 음악 (임시)
- Kevin MacLeod 서부극 트랙 다수(CC-BY). 설정 화면에 "Music: Kevin MacLeod (incompetech.com), CC-BY 4.0" 한 줄 표기 승인만 필요. (CREDITS.md에도 추가)

### 5. [유료 $10 선불~·10분·스킨 만들 때] Recraft API
- https://www.recraft.ai → 가입 → API 토큰 → `export RECRAFT_API_TOKEN=...`
- **Style ID(참조 이미지 3~5장)로 모든 생성물 스타일 고정** → 캐릭터 스킨 세트 일관성에 최적. ~$0.04/장, SVG 벡터 지원(아이콘·UI). 예상 월 $5~10.

### 6. [유료 $5/월·10분·시그니처 사운드 원할 때] ElevenLabs Starter
- https://elevenlabs.io → **Starter 결제**(무료 티어는 상업 사용 불가!) → API 키 → `export ELEVENLABS_API_KEY=...`
- "리볼버 격발+리코셰", "살룬 문 삐걱" 같은 리얼 서부극 SFX를 텍스트로 생성. 음악(Music v2)도 같은 키 — 단 게임 배포 라이선스 조항은 붙이기 전 Claude가 약관 확인 후 보고.

### 7. [유료·선택] Stable Audio — 음악 자동화
- https://platform.stability.ai 키 발급(25크레딧 무료 체험) → `export STABILITY_API_KEY=...`
- 1크레딧=$0.01. 로비 루프·쇼다운 스팅·승리 징글 생성에 적합. Creator 등급 = 연매출 $1M 미만 개인 상업권.

### 8. [무료·선택] mflux — 맥 로컬 이미지 무제한
- `pip install mflux` 승인만(디스크 8~24GB). Flux schnell/klein(Apache 라이선스)로 무제한 생성. Gemini 무료 티어로 부족할 때.

## 음악 관련 주의
- **Suno는 공식 공개 API 없음**(2026-07 현재 파트너 신청만) — 자동화 비추. 웹에서 수동 생성(Pro $10/월 상업권)은 가능.

## 추천 시작 순서
**1→2→3→4 (오늘, $0)** → 타격감 1~2단계 완료 후 효과 보고 → 스킨 착수 시 5, 사운드 욕심나면 6.

## 요청 이력
- 2026-07-08 계획 수립. 사용자 키 발급 대기: GEMINI_API_KEY (1순위).
- 2026-07-12 ✅ GEMINI_API_KEY 수령·검증(모델 목록 200 OK)·`~/.zshrc` 저장 완료. 유료 툴은 사용자 보류(스킨·시그니처 SFX 단계에서 재결정). 무료 조합(jsfxr·Kenney·pub 패키지)은 별도 툴 연결 세션에서 설치 예정.
- 2026-07-12 (2차 세션) 무료 툴 연결 실행 결과:
  - ❌ **Gemini 테스트 이미지 실패 — 무료 티어 이미지 생성 폐지 확인.** gemini-2.5-flash-image·3.1-flash-image·3.1-flash-lite-image 전부 429 `free_tier_requests limit: 0`(키·요청 자체는 정상 — 텍스트 모델 `gemini-flash-latest`는 무료 응답 OK). 즉 이미지 생성은 이제 결제 연결 프로젝트 전용. **사용자 결정 필요**: ① AI Studio 프로젝트에 결제 연결(pay-as-you-go, flash-image 약 $0.04/장 — 테스트+스킨 시안 수십 장이면 $1~3 수준) ② `mflux` 로컬 생성(무료 무제한, 디스크 8~24GB 승인 필요) ③ AI Studio 웹에서 수동 생성. 생성 스크립트는 `tools/gen_test_image.py`로 준비 완료(참조 캐릭터 3장+보안관 프롬프트, 키 활성화 즉시 `python3 tools/gen_test_image.py <모델명>` 실행 가능).
  - ✅ jsfxr 설치(`tools/sfx/`, npm 로컬) + 샘플 3종 생성 → `growth/sfx_samples/` (총성 jsfxr_gunshot.wav · 코인 jsfxr_coin.wav · UI클릭 jsfxr_ui_click.wav — 파라미터는 `tools/sfx/gen_sfx.js`에서 무한 튜닝 가능).
  - ✅ Kenney CC0 5팩(423파일) 다운로드·검토 → 서부극 후보 46개 선별 `growth/audio_candidates/kenney/` (용도별 10폴더, README에 목록·한계 정리). 진짜 총성은 Kenney에 없음 → jsfxr/ElevenLabs 몫.
  - ✅ ImageMagick 7.1.2(brew) + rembg 2.0.76(uv tool) 설치·실동작 검증(캐릭터 PNG 배경 제거 512x512 출력 OK). python3.12에서 rembg는 `--with "numba>=0.59" --with "llvmlite>=0.42"` 필요. rembg 경로 `~/.local/bin`을 `~/.zshrc` PATH에 등록.
  - ✅ pubspec에 flutter_soloud ^4.0.12 · newton_particles ^0.3.0 · haptic_kit ^2.1.2 추가, `flutter analyze` 통과(No issues found).
