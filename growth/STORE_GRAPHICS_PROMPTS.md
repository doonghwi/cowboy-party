# 스토어 그래픽 생성 프롬프트 (2026-07-13 — 사용자 이미지 스크립트용)

> Play 콘솔 규격 기준. 생성 후 파일을 `store/graphics/`에 넣어주시면 제가 리사이즈·검수·업로드 준비까지 합니다.
> 참조 이미지: `assets/characters/` PNG 2~3장(스타일 고정용)과 `assets/icon/icon.png`(기존 아이콘 톤)를 첨부 권장.

## 1. 앱 아이콘 A/B (512×512 PNG, 32-bit)

**A안 — 캐릭터 훅** (추천: 얼굴이 있는 아이콘이 CTR이 높음)
```
App icon for a western party game, square 1:1. A charismatic cartoon cowboy
face (soft comic ink style matching the attached reference characters) winking
and pointing a finger-gun at the viewer, tight close-up crop, warm sunset
palette (deep orange sky, brown leather), bold and readable at 48px.
Flat vector-like shading, no text, no border, no watermark.
```

**B안 — 심볼 강화** (현행 모자 아이콘의 고도화)
```
App icon, square 1:1. A brown cowboy hat tilted at a jaunty angle with two
crossed golden revolvers beneath it, subtle radial sunset burst background
(#2E6E5A deep green to warm orange), thick playful outlines, flat cartoon
style, crisp silhouette readable at 48px. No text, no watermark.
```

## 2. 피처 그래픽 (1024×500 PNG/JPG, 텍스트 최소)

```
Google Play feature graphic, 1024x500 landscape. Six cartoon cowboys sitting
around a circular poker table in a desert at sunset, seen slightly from above,
all pointing revolvers at each other in a comedic Mexican standoff, muzzle
flashes and one golden bullet tracer crossing the table, style matching the
attached soft comic ink reference characters, warm palette (sunset orange sky,
deep green table felt #2E6E5A, parchment cards). Leave the center-left third
visually calm for logo overlay. No text, no watermark.
```
(로고 텍스트 "카우보이"는 제가 폰트로 후처리 — 생성 이미지엔 텍스트 금지)

## 3. 스크린샷 배경 프레임 (선택, 1080×1920)

```
Vertical phone-screenshot backdrop, 1080x1920. Minimal desert dusk scene:
gradient sky from warm orange to deep teal, low dunes and two saguaro cactus
silhouettes at the bottom, soft vignette, EMPTY center area (a phone screenshot
will be overlaid). Matches a playful western cartoon game. No text.
```
(생성해주시면 실기 스크린샷을 얹어 마케팅 스크린샷 세트로 조립합니다)

## 4. 홍보 트윗용 키비주얼 (선택, 1200×675)

```
16:9 promotional key art, 1200x675. Two cartoon cowboys facing each other in a
tense quick-draw duel at high noon, dust swirling, dramatic long shadows, one
tumbleweed, style matched to the attached reference characters, comedic tension
(sweat drop), sunset western palette. Bottom quarter kept calm for caption
overlay. No text, no watermark.
```

## 반입 체크리스트 (제가 할 일)
- [ ] 512 아이콘 → `flutter_launcher_icons` 재생성(안드로이드 적응형 포함) → A/B는 콘솔 실험
- [ ] 피처 그래픽에 로고 타이포 합성(Rye/BlackHanSans) → 1024×500 검수
- [ ] 스크린샷 프레임에 실기 캡처 합성 → 문구 얹어 8장 세트
