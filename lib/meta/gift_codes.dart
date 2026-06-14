/// 선물 코드(기프트 코드) 정의.
///
/// 두 종류:
///  - **공용(universal)**: 누구나 쓸 수 있음. 단 계정당 1회.
///  - **단일(single)**: 전체에서 단 1명만 쓸 수 있음(선착순). 역시 계정당 1회.
///
/// 공용 코드는 여기 [kGiftCodes]에 박아두면 배포 시 적용된다(코드 추가 = 이 맵에 한 줄).
/// 단일 코드는 RTDB `/giftcodes/<code>: { gold, single:true }` 로 만들면(콘솔에서)
/// 런타임에 조회된다. 선착순 점유는 `/giftcodes/<code>/claimedBy` 트랜잭션으로 보장.
///
/// 입력은 항상 소문자+trim 으로 정규화해서 비교한다.
class GiftCode {
  final int gold;
  final bool single; // true = 전체 1명만(선착순)
  const GiftCode({required this.gold, this.single = false});
}

/// 빌드에 내장된 공용 코드. (코드 문자열은 소문자로.)
const Map<String, GiftCode> kGiftCodes = {
  'thankyou': GiftCode(gold: 100000),
};

String normalizeGiftCode(String raw) => raw.trim().toLowerCase();
