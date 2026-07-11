# Play 콘솔 업로드 자동화 — 사용자 1회 설정 가이드 (~15분)

> 목표: "adb(=AAB) 콘솔 수동 업로드" 단순작업 제거. 설정 후엔 Claude가
> `flutter build appbundle` → `fastlane supply` 한 줄로 비공개 테스트 릴리스까지 완료.
> **설정 완료 즉시 밀려 있는 v13(광고 ID 권한 제거분, ~/Downloads/cowboy_party-v13.aab) 업로드부터 Claude가 처리.**
> 방식: fastlane supply (Flutter 공식 문서 권장, 커스텀 트랙·릴리스노트·단계출시 지원).

## 사용자 1회 설정 (순서대로)

> 중요: 예전 Play Console "설정→API 액세스" 페이지는 **2023년에 폐지**됨.
> 이제 Cloud 프로젝트 연결 절차가 필요 없고, 서비스 계정을 그냥 "사용자"로 초대하면 된다.

1. https://console.cloud.google.com/projectcreate → 새 프로젝트 (예: `cowboy-play-publisher`)
2. 그 프로젝트에서 **API 및 서비스 → 라이브러리 → "Google Play Android Developer API" 검색 → 사용 설정**
3. **IAM 및 관리자 → 서비스 계정 → 서비스 계정 만들기** (이름: `play-publisher`). Cloud IAM 역할은 부여 안 해도 됨.
4. 만든 서비스 계정 → **키 탭 → 키 추가 → JSON** → 다운로드
5. 키 파일을 `~/Documents/dailyapp/cowboy_party/android/play-service-account.json` 로 이동
   (.gitignore에 패턴 추가됨 — 커밋 안 됨. 유출 시 Cloud Console에서 키 삭제→재발급)
6. https://play.google.com/console → **사용자 및 권한 → 새 사용자 초대** → 이메일란에 서비스 계정 이메일
   (`play-publisher@<프로젝트>.iam.gserviceaccount.com`) 입력
7. 같은 화면 **앱 추가 → 카우보이 파티만 선택** → 권한: 앱 권한 세트 **"출시 관리자(Release manager)"** → 초대
   (서비스 계정은 수락 절차 없이 즉시 활성)
8. `brew install fastlane` (Claude가 대신 실행 가능 — 승인만)

설정 완료를 Claude에게 알려주면 검증부터 실행:
```bash
fastlane run validate_play_store_json_key json_key:android/play-service-account.json
```

## 이후 Claude가 반복 실행하는 시퀀스

```bash
# 0) pubspec.yaml version +N 증가 (versionCode — 같은 값 재업로드는 API가 거부)
# 1) flutter build appbundle --release
# 2) bash tools/upload_play.sh [--aab <경로>] [--track alpha]
```
`tools/upload_play.sh` 준비됨 — fastlane supply 래퍼(메타데이터 skip, 릴리스노트는
`fastlane/metadata/android/ko-KR/changelogs/<versionCode>.txt` 있으면 자동 첨부).

## 함정 메모 (리서치에서 확인)
- **트랙 이름**: 콘솔 비공개 테스트가 기본 "Alpha"면 API명 `alpha`, 커스텀 트랙이면 콘솔에 보이는 이름 그대로. 첫 실행 때 콘솔에서 확인.
- **internal 트랙**은 심사 없이 몇 분 내 배포 → 초고속 반복엔 internal에 올리고 closed로 승격(promote)하는 것도 가능.
- `edits.commit` 시 자동으로 심사 제출됨(콘솔 클릭 불필요). 단 **관리형 게시(managed publishing) ON이면 수동 "게시" 클릭 필요** — 완전 자동화 원하면 꺼둘 것.
- `changes_not_sent_for_review` 에러가 나면(거절 이력 등) 그때만 `--changes_not_sent_for_review true` + 콘솔 수동 전송 1회.
- 서비스 계정은 앱 업데이트만 가능(새 앱 생성 불가) — 새 앱은 첫 AAB 수동 업로드 필요.
- **설정 완료(2026-07-12)**: v13 업로드로 전 과정 검증됨. 트랙명 `alpha` 확인. Play Console "사용자 및 권한" 메뉴는 앱 안에서는 안 보임 — 계정 홈(모든 앱) 좌측 메뉴 또는 https://play.google.com/console/users-and-permissions 직행.
- **맥 기본 bash 3.2**: `set -u`에서 빈 배열 `"${arr[@]}"` 확장이 unbound variable 에러 → `${arr[@]+"${arr[@]}"}` 패턴 필요 (upload_play.sh에서 실제 발생, 수정됨).

## 출처
- https://developers.google.com/android-publisher/getting_started (연결 불필요 명시)
- https://docs.fastlane.tools/actions/supply/
- https://support.google.com/googleplay/android-developer/answer/9859654 (관리형 게시)
