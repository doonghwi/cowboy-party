# iOS 릴리스 자동화 체계 (2026-07-17)

> 목표(사용자): "구글 콘솔에 손 하나 안 대는 것처럼" iOS도 무인 릴리스.
> v1.0 첫 제출(2026-07-17 새벽, 심사 대기 중)까지의 1회성 설정 기록 + 이후 자동 파이프라인.

## 1. 끝난 1회성 설정 (다시 할 일 없음)
| 항목 | 상태 | 위치/비고 |
|---|---|---|
| Apple Developer 등록($99/년) | ✅ | 팀 Donghwi Moon / 8ZQLPP4N24 |
| Xcode 계정·팀·Sign in with Apple capability | ✅ | pbxproj에 커밋됨 |
| 기기 없는 서명 문제 | ✅ | 맥 자체를 iOS 기기로 등록(Designed-for-iPad 빌드 트릭) |
| Firebase Apple 로그인 공급자 | ✅ | 콘솔 토글 |
| App Store Connect 앱 "카우보이 파티" | ✅ | ID 6791663761, SKU cowboy-party-001 |
| 스토어 메타데이터·스크린샷·등급(13+)·개인정보·가격(무료)·DSA(비거래자) | ✅ | 문안: store/appstore_metadata.md |
| **ASC API 키** | ✅ | Key D3TN3JP93R / Issuer c9d3b6fa-…e205. p8+json = `~/.appstoreconnect/` — **드라이브 백업됨**(dailyapp-secrets-backup) |
| 앱 아이콘(iOS) | ✅ | 카우보이 얼굴로 교체(빌드 29). 소스 진실 = `store/icon_512.png` (assets/icon/icon.png는 구식 모자 — LESSONS 참고) |

## 2. 매 릴리스 무인 파이프라인
1. 세션이 버전 범프(pubspec +N, shell.dart kBuildNo) + 검증(analyze·test·에뮬)
2. `bash tools/release_ios.sh "새 소식 문구"` — 빌드→업로드→처리 대기→버전 페이지 생성·빌드 선택·새 소식→**심사 자동 제출**(승인 시 자동 출시)
   - 업로드만 필요하면: `bash tools/upload_appstore.sh`
3. 진행 상황은 **대시보드 🚦 출시 탭**이 App Store Connect API로 자동 표시(심사 대기/심사 중/판매 중/반려)
> ⚠️ release_ios.sh 전체 흐름의 **첫 실전은 다음 릴리스(1.0.1)** — v1.0은 수동 제출로 완료. 첫 가동 때 세션이 로그를 지켜볼 것.

## 3. 여전히 사람(또는 세션 판단)이 필요한 것
- **심사 반려 대응** — 반려 사유 읽고 수정 방향 결정(메일: 계정 이메일 + 출시 탭)
- **스크린샷/아이콘 교체** — 디자인 규칙상 시안 검사 후(선택 탭)
- **수익화 전환 시** — 유료 계약·세금·계좌(Apple/Google 콘솔), DSA 거래자 전환, 인앱결제 심사
- 연령 등급·개인정보 답변이 **바뀌는 기능**이 들어갈 때만 콘솔 재설문

## 4. 안드로이드와의 대칭
| 단계 | Android | iOS |
|---|---|---|
| 업로드 | tools/upload_play.sh (서비스 계정) | tools/upload_appstore.sh (ASC API 키) |
| 심사 제출 | 업로드 시 자동 | tools/release_ios.sh (deliver) |
| 상태 모니터링 | 🚦 출시 탭 (Play API) | 🚦 출시 탭 (ASC API) |
| 시크릿 백업 | 드라이브 dailyapp-secrets-backup | 동일 |
