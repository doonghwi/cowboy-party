/// 봇 러너 설정. 값은 cowboy_party 프로젝트(cowboy-party-doonghwi)에서 가져왔다.
library;

import 'game/char_core.dart';

/// 러너봇 한 명의 사양. 이름 + (선택) 특수 성향.
/// - [fixedChar]: 항상 이 직업으로 플레이(null=매판 랜덤).
/// - [personality]: 'aggressive'(공격적)·'defensive'(수비적)·null(랜덤 성격).
/// - [reloadOnly]: true면 무조건 장전만(개그봇).
class BotSpec {
  final String name;
  final CharId? fixedChar;
  final String? personality;
  final bool reloadOnly;
  const BotSpec(this.name,
      {this.fixedChar, this.personality, this.reloadOnly = false});
}

class Config {
  Config._();

  /// Firebase 프로젝트.
  static const projectId = 'cowboy-party-doonghwi';

  /// rooms/seasons 가 사는 RTDB (앱 OnlineService.databaseUrl 과 동일).
  static const databaseUrl =
      'https://cowboy-party-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Firebase Auth(Identity Toolkit) REST 용 API 키.
  ///
  /// ⚠️ **주의**: google-services.json 의 Android 키(AIza…8qT0)는 Cloud Console 에서
  /// "Android 앱" 애플리케이션 제한이 걸려 있어 **서버(REST)에서 호출하면 차단**된다.
  /// 러너용으로 **애플리케이션 제한 없는(또는 맥미니 IP 제한) API 키**를 Cloud Console
  /// 에서 새로 만들어(“Identity Toolkit API”만 허용 권장) 여기에 넣는다.
  ///   콘솔: https://console.cloud.google.com/apis/credentials?project=cowboy-party-doonghwi
  /// (환경변수 COWBOY_AUTH_API_KEY 로 덮어쓸 수 있다 — 키를 코드에 안 박고 싶을 때.)
  static String get authApiKey =>
      _env('COWBOY_AUTH_API_KEY') ?? 'REPLACE_WITH_SERVER_API_KEY';

  /// 봇 계정 자격증명을 저장할 파일(저장형 익명 → uid·이름 안정).
  static String get credsPath =>
      _env('COWBOY_BOT_CREDS') ?? 'bot_creds.json';

  /// 러너봇 목록. 개수 = 익명 계정 수. 늘리면 다음 실행 때 새 계정이 붙는다.
  static const bots = <BotSpec>[
    // 특수 성향/직업 봇(이름은 사용자 지정 유지).
    BotSpec('티모', fixedChar: CharId.voodoo),
    BotSpec('공격', personality: 'aggressive'),
    BotSpec('수비', personality: 'defensive'),
    BotSpec('쌍권총', fixedChar: CharId.dualgun),
    BotSpec('사냥꾼', fixedChar: CharId.hunter),
    BotSpec('머리에한방', fixedChar: CharId.sniper),
    BotSpec('티라노', personality: 'aggressive'),
    BotSpec('독사', personality: 'aggressive'),
    BotSpec('바위방패', personality: 'defensive'),
    BotSpec('난장전만해'),
    // 한국 게이머 스타일 다양한 닉네임(서부식 X).
    BotSpec('김첨지'),
    BotSpec('사딸라'),
    BotSpec('이대리'),
    BotSpec('순두부'),
    BotSpec('냥냥펀치'),
    BotSpec('지나가던행인'),
    BotSpec('어둠의기사'),
    BotSpec('킹받네'),
    BotSpec('빡종러'),
    BotSpec('무야호'),
    BotSpec('롤린이'),
    BotSpec('배그고인물'),
    BotSpec('오늘도평화'),
    BotSpec('퇴근하고파'),
    BotSpec('라면앤김밥'),
    BotSpec('햄최몇'),
    BotSpec('코노고고'),
    BotSpec('마라탕러버'),
    BotSpec('하이염'),
    BotSpec('즐겜유저'),
    BotSpec('꿀잼각'),
    BotSpec('컵라면'),
    BotSpec('삼겹살'),
    BotSpec('아아한잔'),
    BotSpec('치킨각'),
    BotSpec('소확행'),
    BotSpec('광클왕'),
    BotSpec('눈치백단'),
    BotSpec('발컨주의'),
    BotSpec('캐리해줘'),
  ];

  static List<String> get botNames => [for (final b in bots) b.name];

  // ── 튜닝 ──────────────────────────────────────────────────────────────
  /// 사람이 빠른시작 방을 판 뒤, 봇이 끼어들기 전 기다리는 시간(사람끼리 우선).
  static const graceDelayMs = 5000;

  /// 이 시간 안에 하트비트(seen)한 사람만 "살아서 대기 중"으로 본다.
  /// 오래된 스테일 방(옛 대기자 잔존)에 봇이 헛되이 들어가는 것 방지.
  static const humanFreshMs = 25000;

  /// 사람 1명 방에 채울 봇 수 범위(총 인원 = 사람 + 이 값). 랜덤 2~4.
  static const minBotsFill = 2;
  static const maxBotsFill = 4;

  /// 봇들이 한꺼번에 안 들어오고 순차로 들어오게 하는 간격(사람 화면에서
  /// '1명→2명→3명'으로 자연스럽게 늘도록).
  static const joinStaggerMs = 900;

  /// 방 목록 폴링 주기(매칭 감시).
  static const roomsPollMs = 2000;

  /// 게임 중 방 상태 폴링 주기(턴 감시).
  static const gamePollMs = 900;

  /// 봇이 수를 두기 전 "생각하는" 시간 범위(사람처럼). 실제 제출 지연.
  static const thinkMinMs = 700;
  static const thinkMaxMs = 2600;

  /// 한 게임이 이 시간 동안 진전이 없으면(상대 이탈 등) 봇은 포기하고 나간다.
  static const gameStallTimeoutMs = 30000;

  // ── 공개방 사회성 시뮬레이션(로비 북적임) ─────────────────────────────
  /// 봇이 상시 유지하는 공개방 개수(봇 많으니 넉넉히).
  static const socialTargetRooms = 3;

  /// 사회성에 쓸 봇을 아무리 많이 써도 이만큼은 빠른시작용으로 남긴다.
  static const socialReserveForQuickMatch = 4;

  /// 사회성 방 한 개의 목표 인원 범위(랜덤). 실제론 더 적게 시작하기도.
  static const socialMinMembers = 2;
  static const socialMaxMembers = 5;

  /// 방 수명 범위(ms) — 지나면 해산하고 새 방이 생긴다(로비가 계속 변함).
  static const socialRoomLifeMinMs = 90000;
  static const socialRoomLifeMaxMs = 240000;

  /// 사회성 방 관리 폴링 주기.
  static const socialTickMs = 3000;

  /// 사람이 방에 들어온 뒤, 준비를 안 눌러도 이 시간 지나면 방장 봇이 그냥 시작한다
  /// (준비 기능 없는 구버전 앱 대응 + 너무 오래 안 시작하면 답답하니까).
  static const socialHumanStartGraceMs = 15000;

  /// 봇 공개방에서 사람 좌석의 하트비트가 이 시간 이상 끊기면 호스트 봇이 좌석을
  /// 치운다(앱은 4초마다 하트비트 → 45초면 확실히 나간 것). 안 치우면 유령 좌석이
  /// "사람 대기 중"으로 보여 봇이 헛게임을 시작한다.
  static const socialEvictStaleMs = 45000;

  /// 게임 시작 판단에 쓰는 "지금 활동 중인 사람" 기준(앱 하트비트 4초 → 12초면
  /// 확실). grace(15초)보다 짧아서, 자리만 남기고 떠난 사람 때문에 헛게임이
  /// 시작되는 일이 없다(떠난 지 12초 넘으면 시작 조건에서 빠짐).
  static const socialHumanActiveMs = 12000;

  // ── 죽은 방 청소부 ────────────────────────────────────────────────────
  /// 방의 **모든 플레이어**가 이 시간 이상 하트비트(seen)가 없으면 버려진 방으로
  /// 보고 삭제한다. 앱은 대기실·게임에서 4초마다 하트비트하므로 사람이 있는 방은
  /// 절대 지워지지 않는다(넉넉히 2분).
  static const janitorStaleMs = 120000;

  /// 매칭(빠른시작) 방은 훨씬 빨리 치운다 — 안 그러면 게임 끝내고 다시 빠른시작을
  /// 눌렀을 때 옛 매칭 방에 도로 들어가 큐가 안 잡히는 버그(사용자 제보).
  static const janitorMatchStaleMs = 25000;

  /// 청소 주기(매칭방을 빨리 잡으려 짧게).
  static const janitorPollMs = 12000;

  static String? _env(String k) {
    final v = _environment[k];
    return (v == null || v.isEmpty) ? null : v;
  }

  // Platform.environment 는 bin/runner.dart 에서 주입(테스트 용이).
  static Map<String, String> _environment = const {};
  static void loadEnv(Map<String, String> env) => _environment = env;
}
