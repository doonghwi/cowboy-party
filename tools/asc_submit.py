#!/usr/bin/env python3
"""App Store Connect 심사 제출 자동화 (2026-11-07, 22차 수동 REST 절차를 도구로).

    python3 tools/asc_submit.py status                 # 버전·빌드·제출 상태
    python3 tools/asc_submit.py submit 1.0.1 36        # 버전(없으면 생성) + 빌드 연결 + 심사 제출
    python3 tools/asc_submit.py submit 1.0.1 36 --wait # 빌드 처리(PROCESSING→VALID)를 기다렸다가 제출

인증: ~/.appstoreconnect/private_keys/AuthKey_D3TN3JP93R.p8 (PyJWT 필요).
함정: 계약 미동의면 REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED — ASC에서 동의 후 몇 분간 간헐 거부(자동 재시도).
"""
import sys, time, json
from pathlib import Path
import jwt, requests

APP = "6791663761"
KEY_ID = "D3TN3JP93R"
ISSUER = "c9d3b6fa-18a5-4e5d-bf82-1c02c7f5e205"
P8 = Path.home() / f".appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"
API = "https://api.appstoreconnect.apple.com/v1"


def token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      P8.read_text(), algorithm="ES256", headers={"kid": KEY_ID})


def req(method, path, **kw):
    h = {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}
    for i in range(6):
        r = requests.request(method, API + path, headers=h, timeout=30, **kw)
        if "REQUIRED_AGREEMENTS" in r.text:
            time.sleep(3); continue
        if r.status_code >= 400:
            raise SystemExit(f"{method} {path} → {r.status_code}\n{r.text[:800]}")
        return r.json() if r.text else {}
    raise SystemExit("ASC 계약 오류 지속 — App Store Connect > 계약에서 동의 확인")


def versions():
    return req("GET", f"/apps/{APP}/appStoreVersions",
               params={"fields[appStoreVersions]": "versionString,appStoreState,platform", "limit": 5})["data"]


def builds(limit=5):
    return req("GET", "/builds", params={"filter[app]": APP, "sort": "-uploadedDate", "limit": limit,
                                         "fields[builds]": "version,processingState,uploadedDate,expired"})["data"]


def submissions():
    return req("GET", "/reviewSubmissions", params={"filter[app]": APP, "limit": 5,
                                                    "fields[reviewSubmissions]": "state,submittedDate,platform"})["data"]


def status():
    print("버전:")
    for v in versions():
        a = v["attributes"]; print(f"  {a['versionString']:8} {a['appStoreState']}  ({v['id']})")
    print("빌드(최근):")
    for b in builds():
        a = b["attributes"]; print(f"  #{a['version']:4} {a['processingState']:12} {a['uploadedDate'][:16]} {'만료' if a['expired'] else ''}")
    print("심사 제출:")
    for s in submissions():
        a = s["attributes"]; print(f"  {s['id'][:8]} {a['state']} {a.get('submittedDate') or ''}")


def find_build(no, wait):
    while True:
        for b in builds(20):
            if b["attributes"]["version"] == str(no):
                st = b["attributes"]["processingState"]
                if st == "VALID":
                    return b["id"]
                if not wait:
                    raise SystemExit(f"빌드 {no} 상태 {st} — --wait 로 처리 완료를 기다리거나 잠시 후 재시도")
                print(f"  빌드 {no} {st}… 60초 대기"); break
        else:
            if not wait:
                raise SystemExit(f"빌드 {no} 이 ASC에 아직 없음(업로드 직후면 5~15분) — --wait 사용")
            print(f"  빌드 {no} 아직 안 보임… 60초 대기")
        time.sleep(60)


def submit(ver, build_no, wait=False):
    vid = None
    for v in versions():
        if v["attributes"]["versionString"] == ver:
            vid = v["id"]; print(f"버전 {ver} 있음: {v['attributes']['appStoreState']}")
    if vid is None:
        vid = req("POST", "/appStoreVersions", json={"data": {"type": "appStoreVersions", "attributes": {
            "versionString": ver, "platform": "IOS", "releaseType": "AFTER_APPROVAL"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
        print(f"버전 {ver} 생성: {vid}")
    bid = find_build(build_no, wait)
    req("PATCH", f"/appStoreVersions/{vid}/relationships/build",
        json={"data": {"type": "builds", "id": bid}})
    print(f"빌드 {build_no} 연결")
    # 열려 있는 제출이 있으면 거기에 추가, 없으면 새로 만든다.
    open_sub = next((s for s in submissions() if s["attributes"]["state"] in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES")), None)
    if open_sub and open_sub["attributes"]["state"] == "UNRESOLVED_ISSUES":
        req("PATCH", f"/reviewSubmissions/{open_sub['id']}", json={"data": {"type": "reviewSubmissions", "id": open_sub["id"], "attributes": {"canceled": True}}})
        print("옛 제출 취소"); open_sub = None; time.sleep(10)
    sid = open_sub["id"] if open_sub else req("POST", "/reviewSubmissions", json={"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
    req("POST", "/reviewSubmissionItems", json={"data": {"type": "reviewSubmissionItems", "relationships": {
        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    req("PATCH", f"/reviewSubmissions/{sid}", json={"data": {"type": "reviewSubmissions", "id": sid, "attributes": {"submitted": True}}})
    print(f"심사 제출 완료: {sid[:8]} (버전 {ver}, 빌드 {build_no})")


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0] == "status":
        status()
    elif a[0] == "submit" and len(a) >= 3:
        submit(a[1], a[2], wait="--wait" in a)
    else:
        print(__doc__)
