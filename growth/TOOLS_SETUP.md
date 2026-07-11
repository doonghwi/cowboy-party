# 에셋 생성 툴 연결 체크리스트 — 사용자 작업 안내

> 결론: **$0 조합만으로 시작 가능** (Gemini 이미지 + jsfxr 효과음 + Kenney CC0 + pub 패키지).
> 유료 2개(Recraft·ElevenLabs, 합계 ~$10-15/월)는 스킨 시스템·시그니처 사운드 단계에서.

## 사용자가 해줄 연결 작업 (우선순위순)

### 1. [무료·5분·지금] Gemini API 키 — 이미지 생성
- https://aistudio.google.com → "Get API key" → 발급
- `~/.zshrc`에 `export GEMINI_API_KEY=...` 추가
- 효과: 하루 ~500장 무료(Nano Banana 계열). 프로모 아트·스토어 그래픽 배경·캐릭터 시안·**기존 캐릭터 이미지를 참조한 스킨 변형**에 사용. Claude가 REST로 직접 호출.

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
