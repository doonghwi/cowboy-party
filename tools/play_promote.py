#!/usr/bin/env python3
"""Play 트랙 상태 조회·프로덕션 승격 (Android Publisher REST 직접, 2026-11-08).

    python3 tools/play_promote.py status              # 트랙별 릴리스(버전코드·상태)
    python3 tools/play_promote.py promote 36          # alpha에 있는 빌드 36을 production(completed)으로 승격
    python3 tools/play_promote.py promote 36 --draft  # 초안으로만 올리기(콘솔에서 제출)

인증: android/play-service-account.json (서비스 계정, upload_play.sh와 같은 키). PyJWT·requests만 필요.
출시 노트: fastlane/metadata/android/ko-KR/changelogs/<버전코드>.txt 가 있으면 ko-KR 노트로 넣는다.
함정(14차): fastlane supply --skip_upload_aab 는 release_status 를 트랙에 반영 안 함 → REST로 직접.
"""
import json, sys, time
from pathlib import Path
import jwt, requests

ROOT = Path(__file__).resolve().parents[1]
KEY = json.loads((ROOT / "android/play-service-account.json").read_text())
PKG = "com.doonghwi.cowboy_party"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"


def token():
    now = int(time.time())
    a = jwt.encode({"iss": KEY["client_email"], "scope": "https://www.googleapis.com/auth/androidpublisher",
                    "aud": "https://oauth2.googleapis.com/token", "iat": now, "exp": now + 3000},
                   KEY["private_key"], algorithm="RS256")
    r = requests.post("https://oauth2.googleapis.com/token",
                      data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": a}, timeout=30)
    r.raise_for_status(); return r.json()["access_token"]


H = {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}


def req(method, path, **kw):
    r = requests.request(method, API + path, headers=H, timeout=60, **kw)
    if r.status_code >= 400:
        raise SystemExit(f"{method} {path} → {r.status_code}\n{r.text[:1200]}")
    return r.json() if r.text else {}


def status():
    eid = req("POST", "/edits")["id"]
    for t in req("GET", f"/edits/{eid}/tracks").get("tracks", []):
        rels = t.get("releases", [])
        desc = ", ".join(f"{'/'.join(r.get('versionCodes', ['-']))}:{r.get('status')}" for r in rels) or "(비어 있음)"
        print(f"  {t['track']:12} {desc}")
    req("DELETE", f"/edits/{eid}")


def promote(vc, draft=False):
    notes = ROOT / f"fastlane/metadata/android/ko-KR/changelogs/{vc}.txt"
    eid = req("POST", "/edits")["id"]
    tracks = {t["track"]: t for t in req("GET", f"/edits/{eid}/tracks").get("tracks", [])}
    have = {c for t in tracks.values() for r in t.get("releases", []) for c in r.get("versionCodes", [])}
    if str(vc) not in have:
        raise SystemExit(f"버전코드 {vc} 가 어느 트랙에도 없음 — 먼저 upload_play.sh 로 업로드")
    rel = {"versionCodes": [str(vc)], "status": "draft" if draft else "completed"}
    if notes.exists():
        rel["releaseNotes"] = [{"language": "ko-KR", "text": notes.read_text().strip()}]
    req("PUT", f"/edits/{eid}/tracks/production", json={"track": "production", "releases": [rel]})
    res = req("POST", f"/edits/{eid}:commit")
    print(f"production ← {vc} ({rel['status']}) 커밋 완료: edit {res.get('id', eid)}")
    status()


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0] == "status":
        status()
    elif a[0] == "promote" and len(a) >= 2:
        promote(a[1], draft="--draft" in a)
    else:
        print(__doc__)
