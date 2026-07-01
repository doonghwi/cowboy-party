# 카우보이 — Flow Map (설명용 관계도)

> 개발자·기획자·투자자에게 게임을 설명할 때 쓰는 다이어그램 모음.
> GitHub에서 이 파일을 열면 그림으로 렌더링된다(mermaid). 발표용 이미지가 필요하면
> https://mermaid.live 에 코드 블록을 붙여넣고 PNG로 내보내면 된다.

---

## 1. 플레이어 여정 (User Flow) — "유저가 앱에서 뭘 하나"

```mermaid
flowchart TD
    A[앱 실행] --> B{첫 실행?}
    B -- 예 --> C[환영 팝업 · 게임방법]
    B -- 아니오 --> D[홈: 4탭 셸]
    C --> D

    D --> E[플레이 탭]
    D --> F[캐릭터 탭<br/>상점 · 장착]
    D --> G[랭킹 탭<br/>주간 시즌]
    D --> H[보상 탭<br/>출석]

    E --> E1[빠른 시작<br/>자동 매칭+봇 채움]
    E --> E2[공개방 목록 입장]
    E --> E3[방 만들기 / 코드 입장]
    E --> E4[컴퓨터전<br/>오프라인 봇]

    E1 & E2 & E3 & E4 --> GAME[게임 한 판<br/>2~6인 동시턴 눈치싸움]
    GAME --> R[결과: 코인 + 랭킹 포인트]
    R --> F
    R --> GAME
    F -- 새 캐릭터로 --> GAME
```

## 2. 코어 게임 루프 (한 턴) — "게임이 왜 재밌나"

```mermaid
flowchart LR
    S[턴 시작<br/>20초 타이머] --> P[전원 동시 비밀 선택<br/>장전 · 방어 · 빵야 · 특수능력]
    P --> O[동시 공개!]
    O --> J[판정<br/>party_logic 단일 엔진]
    J --> FX[연출: 탄도 · 연막 · 저주<br/>사운드 · 햅틱]
    FX --> K{생존자 1명?}
    K -- 아니오 --> S
    K -- 예 --> W[승리]
    K -- 전원 동시 사망 --> SD[반응속도 결투<br/>쇼다운]
    SD --> W
```

핵심 재미 축: **① 심리전**(동시 선택 눈치싸움) **② 캐릭터 비대칭**(15종 직업 능력) **③ 짧은 판**(수 분 내 결판).

## 3. 경제 · 리텐션 루프 — "왜 또 오나"

```mermaid
flowchart TD
    subgraph SOURCE[코인 소스]
        W1[게임 승리]
        W2[일일 출석]
        W3[선물 코드 이벤트]
    end
    subgraph SINK[코인 싱크]
        SH[캐릭터 상점<br/>15종 · 1,000~7,500]
    end
    SOURCE --> COIN[코인]
    COIN --> SH
    SH --> NEW[새 능력 · 새 전략]
    NEW --> PLAY[다시 플레이]
    PLAY --> W1
    RANK[주간 랭킹 · 지난주 챔피언] --> PLAY
    PLAY --> RANK
```

> 현재 싱크가 캐릭터뿐 → 전 캐릭터 보유 후 코인 쓸 곳 없음. 백로그의 스킨·일일미션이 이 구멍을 메운다(PRODUCT_PLAN.md §4).

## 4. 시스템 아키텍처 — "어떻게 돌아가나" (개발자·VC용)

```mermaid
flowchart TD
    subgraph CLIENT[Flutter 앱  Android · iOS · Web]
        UI[화면 screens/ · widgets/]
        LOGIC[게임 규칙 엔진<br/>party_logic — 순수함수 · 시드 결정적]
        META[메타 meta/<br/>코인 · 상점 · 출석 · 계정]
        FXS[연출 effects · audio<br/>게임로직과 분리]
        UI --> LOGIC
        UI --> META
        UI --> FXS
    end

    subgraph FB[Firebase]
        RTDB[(Realtime Database<br/>rooms · users · seasons)]
        AUTH[Auth<br/>Google · Apple · 게스트]
    end

    subgraph BOT[봇 러너  맥미니 상시가동]
        RUNNER[40봇: 매치 채움 ·<br/>공개방 사회성 · 죽은방 청소]
        CORE[동일 규칙엔진 공유<br/>sync_core.sh 복사]
    end

    CLIENT <-->|턴 기록 쓰기 · 리플레이 읽기| RTDB
    CLIENT --> AUTH
    RUNNER <-->|일반 클라이언트처럼 접속| RTDB
    RUNNER --- CORE
```

설계 포인트(설명 시 강조):
- **서버 로직 없음**: 모든 클라이언트가 턴 히스토리를 각자 리플레이해 같은 결과 도출(시드 결정적 난수). 서버비 ≈ 0.
- **규칙은 한 곳**: `party_logic.dart` 순수함수 + 테스트 204개로 고정 → 봇 러너도 같은 파일 공유.
- **콜드스타트 해결**: 유저가 적어도 봇 러너가 매칭을 성사시키고 로비를 북적이게 유지.

## 5. 제품 단계 (현재 위치) — 로드맵 설명용

```mermaid
flowchart LR
    P1[프로토타입] --> P2[비공개 테스트<br/>Play 내부 · 봇러너 가동] --> P3[소프트런치<br/>공개 테스트 + 지표 측정] --> P4[정식 출시<br/>Android + iOS] --> P5[라이브옵스<br/>시즌 · 이벤트 · 스킨]
    style P2 fill:#e8a33d,color:#000
```

**지금 P2.** P3 진입 조건: 분석 이벤트 심기(리텐션 측정 가능) + 게임필 1차 + 일일미션 → PRODUCT_PLAN.md §3.
