# store/ — 스토어 출시 산출물

스토어 콘솔에 그대로 올리는 자료 모음. 사용자 계정/결제/제출이 필요 없는 것은 미리 준비됨.

## 파일
- `listing_ko.md` / `listing_en.md` — 앱 이름·짧은/긴 설명·카테고리·콘텐츠 등급 답안.
- `data_safety.md` — Play 데이터안전 + Apple App Privacy 답안 초안.
- `ios_release.md` — iOS(아카이브·Apple 로그인·스크린샷 규격) 절차.
- `icon_512.png` — 512×512 앱 아이콘(Play 등록용).
- `feature_graphic.png` — 1024×500 Play 피처 그래픽(`tool/make_feature_graphic.py`로 재생성 가능).
- `screenshots/android/` — Play용 폰 스크린샷.
- `screenshots/ios/` — App Store용(시뮬레이터 캡처 필요 — ios_release.md 규격 참고).

## 개인정보처리방침 URL
https://doonghwi.github.io/cowboy.gg/privacy.html (소스: cowboy.gg repo `privacy.html`)

## Android appbundle(.aab) 만들기
실제 스토어 제출용은 업로드 키 서명이 필요(키는 사장님 보관).
```bash
cp android/key.properties.example android/key.properties   # 값 채우기(android/key.properties.example 참고)
flutter build appbundle --release
# 산출물: build/app/outputs/bundle/release/app-release.aab
```
key.properties가 없으면 자동으로 디버그 서명으로 폴백되어 빌드 검증만 가능(제출 불가).

## 스크린샷 캡처(참고: _make-new-app/TESTING.md)
```bash
adb exec-out screencap -p > store/screenshots/android/01_home.png
```
