# 스킨 활용안 + 생성 프롬프트 (2026-07-13, 사용자 질문 "당장 스킨이 필요한가?"에 대한 답)

## 결론: 지금 당장은 필요 없다 — 순서는 "무대 먼저, 스킨은 그다음"

스킨의 가치는 그림 파일이 아니라 **노출되는 순간**에서 나온다(RETENTION_PLAN §B2 무대 설계).
현재 상태 점검:
- ✅ 무대 1: 승리 셀레브레이션(콘페티) — 있음. 여기에 "승자 대형 초상"만 얹으면 스킨 무대가 됨
- ✅ 무대 2: 결투 DRAW! — 있음. 대결자 2인 컷인 초상을 얹을 자리
- ❌ 무대 3: 로비 대형 스탠딩·상점 착용 미리보기 — UI 개편(아래 UI_REDESIGN_PLAN)과 함께 만드는 게 효율적
- ❌ 스킨 데이터 모델(unlocked에 `skin:<char>:<id>`) — 미구현

## 스킨을 "어떻게 활용"할 것인가 (수익 아닌 리텐션 자산으로)

1. **시즌 패스 30티어 보상** — 매 시즌 한정 스킨 1종 = 4주 케이던스의 피날레(이미 패스에 "소급 지급" 명시됨)
2. **트로피 로드 최상위 보상** — 통산 1000판/500승 같은 장기 목표에 전용 스킨 = 고인물 훈장
3. **골드 싱크** — 현재 경제(미션·패스·트로피로 월 2~4만G 유입)에 캐릭터 말고는 쓸 곳이 없음 → 스킨 상점이 인플레 해소처
4. **도감 완성 드라이브** — 도감에 스킨 슬롯 추가 → 수집률이 다시 오를 목표가 됨
5. 광고/IAP는 여전히 제외 — 스킨은 전부 인게임 획득

## 추천 실행 순서
1. **UI 개편(별도 계획)에서 "대형 초상 규격"을 확정** ← 지금 할 일
2. 스킨 데이터 모델 + 착용 UI (Claude, 이미지 없이도 가능 — 기본 스킨=현재 그림)
3. **사용자 이미지 스크립트로 스킨 생성** (아래 프롬프트) — 캐릭터당 후보 4장 → 보드에서 O/X
4. 시즌 패스 P2(8/3 시작) 30티어에 첫 한정 스킨 탑재

## 이미지 생성 프롬프트 (사용자 스크립트용)

공통 규격: **정사각 1:1, 순백 배경, 512px 이상**, 캐릭터당 아래 템플릿에 [SKIN] 치환.
참조 이미지로 `assets/characters/<캐릭터>.png`를 반드시 첨부(스타일·인물 고정).

```
Redraw the EXACT SAME character from the attached reference image (same face,
same pose, same soft comic ink style, same warm western palette, same bust-up
composition, plain pure-white background, square 1:1) but wearing a new outfit
theme: [SKIN]. Keep the character recognizable — only clothing/accessories
change. No text, no watermark, no border.
```

첫 시즌 한정 스킨 후보 테마([SKIN]에 넣을 것):
- `black-and-gold "High Noon Sheriff" formal suit with a golden star badge` (시즌 P2 한정 — 준비자/일반인용)
- `midnight-blue bounty hunter outfit with a silver-trimmed poncho` (트로피 로드용)
- `festive mariachi outfit with embroidered patterns` (이벤트용)

> ⚠️ 사운드 규칙과 동일: 생성물은 board에 올려 사용자 승인 후 반영.
