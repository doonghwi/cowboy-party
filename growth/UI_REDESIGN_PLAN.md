# 전체 UI 개편 계획 (2026-07-13 — 사용자 지시: "클로드 단독 결과물 말고 툴 연결해서 확실하게")

> **2026-07-13 사용자 추가 지시**: ① 대규모 개편은 **선택지를 먼저 보여주고 상의 후** 작업 ② 보상 화면은 타 게임 벤치마크로 즉시 재설계 → ✅ **P1 보상 탭은 designer 에이전트로 재설계 완료(v20)** — 브롤패스식 가로 티어 트랙·요약 스트립·체크리스트 미션·접이식 트로피. 나머지(P0/P2~P4)는 아래 §3 목업 선택지를 보시고 컨셉을 골라주시면 진행.

## 0. 진단 — 왜 지금 UI가 "별로"인가

1. **카드 나열 증후군**: 보상 탭이 대표적 — 레벨/패스/출석/데일리/주간/트로피/코드가 똑같은 파치먼트 카드 7개로 세로 나열. 위계도 리듬도 없음.
2. **진행 시스템이 "표"처럼 보임**: 시즌 패스가 게임의 심장인데 진행바 한 줄. 하스스톤/브롤은 패스를 **길(로드맵)**로 그림.
3. **게임 화면의 무드 부족**: 살룬·서부 정체성이 배경 그라데이션뿐. 테이블(펠트·나무 테두리), 좌석 카드의 질감·계급장이 없음.
4. **토큰 없는 디자인**: 간격·라운드·그림자가 화면마다 제각각(theme.dart에 색만 있음).

## 1. 방법론 — 3중 툴 파이프라인 (Claude 단독 지양)

| 단계 | 도구 | 산출물 |
|---|---|---|
| ① 방향 시안 | **사용자 이미지 스크립트**(아래 목업 프롬프트) | 화면별 목업 이미지 2~3안 → 사용자가 방향 선택 |
| ② 경쟁 설계 | **designer 전문 에이전트 3개 병렬**(서로 다른 컨셉: "살룬 리얼" / "포스터 팝" / "미니멀 웨스턴") + 심판 에이전트 채점 | 채택 컨셉의 디자인 시스템 명세 |
| ③ 구현·검증 | designer 에이전트 구현 → 에뮬 스크린샷 → **visual-verdict**(목업 대비 구조 비교) → 사용자 최종 O/X | 화면별 PR 단위 반영 |

> 참고: codex/gemini CLI는 이 맥에 미설치라 텍스트 멀티모델 크리틱은 제외.
> 대신 ②를 "독립 에이전트 3안 경쟁 + 심판"으로 대체 — 단일 시각의 한계를 같은 방식으로 회피.
> ②③을 멀티에이전트 워크플로로 돌리면 토큰 소모가 큼(회당 수십만) — **사용자 승인 후 실행**.

## 2. 단계별 범위 (각 단계 = 시안 승인 → 구현 → 검증 → v업로드)

- **P0. 디자인 시스템** (선행, 0.5일): theme.dart 확장 — 간격/라운드/그림자 토큰, 카드 위계 3단계(Hero/Standard/Compact), 파치먼트 텍스처, 타이포 스케일, 공통 헤더. *이후 모든 화면이 이 위에서만 조립.*
- **P1. 보상 탭** (사용자 지목 1순위): 시즌 패스를 **가로 스크롤 티어 로드맵**(보상 아이콘·현재 위치 마커·스파이크 강조)으로 승격, 출석/미션은 Compact 카드로 압축, 트로피 로드는 접이식.
- **P2. 게임 테이블**: 펠트+나무 프레임 테이블, 좌석 카드 리디자인(초상 크게·탄약을 총알 아이콘으로·상태 배지 정리), 상단 HUD(턴/타이머) 정돈. **대형 초상 규격 확정**(스킨 무대 — SKIN_PLAN 연동).
- **P3. 홈/셸**: 대문(빠른시작 히어로), 탭바·상단바 스타일 통일, 공지 배너 정리.
- **P4. 상점·랭킹·대기실**: 도감을 앨범 느낌으로, 랭킹 포디움, 대기실 좌석 연출.

## 3. 목업 생성 프롬프트 (사용자 스크립트 — ①단계)

공통: 세로 9:19.5 모바일 UI 목업, 첨부한 현 스크린샷(shots/ 폴더)을 참조로.

**P1 보상 탭 목업**
```
Mobile game UI mockup, 9:19.5 portrait. A "season pass" screen for a cartoon
western party game. Top: horizontal scrolling reward road with 30 tier nodes on
a winding dusty trail, current position marked by a small cowboy token, big
reward chests at tiers 5/10/20/30, warm parchment & leather palette, gold
accents. Below: compact daily-attendance strip and mission checklist cards with
clear visual hierarchy. Playful western saloon style, Korean-game polish level
(like Cookie Run), clean readable layout. No real text needed — use placeholder
bars.
```

**P2 게임 테이블 목업**
```
Mobile game UI mockup, 9:19.5 portrait. Top-down circular saloon poker table
(green felt with wooden rim and brass studs) in a desert dusk. 4 character
seat-cards around the table: each card shows a big cartoon cowboy portrait,
bullet icons for ammo, small status badges. Center: round banner plaque.
Bottom: three big action buttons (reload/defend/shoot) styled as carved wooden
signs with icons. Warm sunset palette, playful western style. Placeholder text.
```

**P3 홈 목업**
```
Mobile game UI mockup, 9:19.5 portrait. Home screen of a western party game:
hero "Quick Start" button styled as a wanted poster, below it two smaller mode
buttons, top bar with gold coins and level badge, bottom tab bar with 4 western
icons (play/shop/ranking/rewards). Desert dusk background with cacti. Playful
cartoon western, high polish. Placeholder text.
```

## 4. 일정·의사결정 지점
1. (지금) 이 계획 + 현 상태 스크린샷 세트 → **사용자: 컨셉 방향·워크플로 실행 승인**
2. P0+P1 실행(승인 후 1~2일) → v업로드 → 반응 보고 P2~P4
3. 스토어 스크린샷 최종본은 **P2까지 끝난 뒤 재촬영**(이번에 찍는 세트는 "현재 기능 반영" 중간본)

## 5. 리스크
- 전 화면 동시 개편 금지 — 단계별 배포로 회귀 위험 분산(테스트 230종이 가드)
- 게임 로직 0줄 원칙 유지(표시 전용 개편)
- 색·무드 변경은 공지로 사용자에게 알림
