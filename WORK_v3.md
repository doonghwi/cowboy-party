# 카우보이 — v3 대규모 업데이트 작업 명세 (ralph 단일 기준)

> 진행: ralph 루프. 각 항목 [ ]→[x]. 모든 변경은 `flutter analyze`(0) + `flutter test` 통과 +
> 가능하면 에뮬 확인 + `ARCHITECTURE.md`/공지 갱신까지가 "완료". 규칙은 `party_logic.dart` 한 곳.
>
> **확정된 결정**: ①무료 기본 캐릭터 = '일반인'만 ②초대 = 일반 공유(share, 카톡 포함) 방 링크
> ③관리자 연락 = ntfy 채널(`cowboy-feedback-doonghwi`) ④게임 중 캐릭터 설명 = 좌석/배지 탭 → 능력+프로필 팝업.

## A. 이름·기본 구조
- [x] A1 게임 표시 이름 "카우보이 파티" → **"카우보이"** (main title/web/home/manifest. repo·URL·DB·패키지 유지).
- [x] A2 하단 탭 "캐릭터" → **"상점"** rename (storefront 아이콘).

## B. 캐릭터 밸런스·기본
- [x] B1 스나이퍼 관통 10% → **20%** (party_logic 0.20, 설명·테스트 갱신).
- [x] B2 결투가 너프: 평소 효과 없음 → **반응속도 결투(showdown)에서만 자동 승리** (online computeView + offline _beginShowdown).
- [x] B3 신규 **일반인(commoner)** cost 0, 유일 무료. enum append.
- [x] B4 일반인 외 전부 유료(cost>0). (기본 장착 일반인은 G/E 메타에서 확정)
- [x] B5 **모든 캐릭터 가격 ×10** (일반인 0).
- [x] B6 신규 **리셋터(resetter)** '무효'(ActKind.reset): 그 턴 다른 모두 행동 결과 무효(총알·자원 소모). party_logic + 테스트.
- [x] B7 의사: 설명 보강 + 0발 처리 테스트로 고정.
- [x] B8 ??? 정체 숨김(능력 발동 전) — computeView displayCharsNow + revealed 추적 + 테스트.
- [x] B9 그림자: 은폐 로직 점검 + computeView 단위테스트로 확인(정상 동작).

## C. 규칙 버그
- [x] C1 운명의 방아쇠: 연막 회피 적용 + 테스트.
- [x] C2 저주: 남은 턴 좌석 표시(💀) + 저주 사망 라벨 + 모두에게 공개(SeatView/TableSeat/SeatCard) + 테스트.
- [x] C3 의사 0발 (B7과 동일 — 확인됨).

## D. 행동 이펙트·배치 (모든 행동 이펙트화)
- [x] D1 스나이퍼 관통 '관통!' 좌석 라벨(piercedFx).
- [x] D2 스모커 연막 남은 횟수 액션바 상시 표시(좌석 배지는 후속).
- [x] D3 특수행동 배치 규칙(SpecialSlot: parallel/turnSlot/alwaysRow/none) 코드 적용 + ARCHITECTURE 표.
- [x] D4 행동별 좌석 이펙트/배너 점검 + 무효(resetFx)·관통·저주 라벨 추가.

## E. 상점·캐릭터
- [x] E1 "상점" 탭: 구매 + 닉네임 변경권 판매(G2) + 튜토리얼 진입 버튼.
- [x] E2 상점 카드 설명 스크롤로 잘림 해결.
- [x] E3 캐릭터 안 사도 봇 튜토리얼(일반인 강제 vs컴퓨터).
- [x] E4 캐릭터 보유 유지(_unlocked 영구·enum append) + ARCHITECTURE 명시.

## F. 방·온라인
- [x] F1 대기실에서 시작 전 캐릭터 변경(setRoomChar).
- [x] F2 방 만들기 **항상 6인** + **방장 자리막기/추방**(크레이지아케이드식): 방장이 빈 자리 닫기·열기(최소 2자리), 들어온 사람 추방(재입장 차단). blocked/kicked + iWasKicked.
- [x] F3 비공개방 비밀번호 + 공개/비공개 토글 라벨 개선(코드 시작 제거).
- [x] F4 초대 **네이티브 공유 시트**(share_plus, 카톡 등) + 딥링크 입장(?room=CODE).

## G. 계정·랭킹·프로필
- [x] G1 랭킹 계정별(uid 키, 동일인 1행).
- [x] G2 닉네임 변경권 10000골드(첫 설정 무료, 이후 변경권 소모). **설정 닉네임 칸 완전 제거** → 상점/온보딩에서만. 익명은 랭킹 미등록.
- [x] G3 게임 중 좌석 탭 → 프로필(닉네임·점수·능력, 개인정보 없음) — 결정④ 통합.
- [x] G4 첫 진입 온보딩(게스트/구글 선택·닉네임 안내·신규 5000골드).

## H. UI·콘텐츠
- [x] H1 공지 패널(AD 자리) — announcements.dart, 최신 배너 + 전체 시트.
- [x] H2 관리자 제보 → ntfy `cowboy-feedback-doonghwi`(익명 식별자만).
- [x] H3 플레이 탭 게임방법 진입 전체폭 배너 강조.
- [x] H4 "첫 턴엔 못 쏴요" → "장전을 해야 쏠 수 있어요".

## I. 문서·루프
- [x] I1 ARCHITECTURE 특수행동 배치 규칙(D3) + 캐릭터 수정 루프 체크리스트.
- [x] I2 공지 작성 루틴 — 루트 CLAUDE.md 작업종료 루틴 §4.

## 후속(완료/보류)
- [x] D2 좌석에 연막 남은 횟수 배지(내 좌석에 구름 배지).
- [x] 방장 승계 — 방장이 나가면 현재 인원 중 가장 낮은 좌석이 방장 이어받음(ensureHost + iShouldClaimHost).
- (보류, 사용자 요청) 비공개 방 비밀번호 서버 강제 — Cloud Functions 필요. 현재 클라 소프트 게이트로 둠.

## 배포·정리 (작업 종료 루틴)
- 단계별 커밋·푸시(시크릿 스캔 통과). 마무리에 web/APK 빌드·배포 + dashboard status.json + HANDOFF.md + 공지 갱신.
