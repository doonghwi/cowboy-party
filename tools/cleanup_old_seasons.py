#!/usr/bin/env python3
"""카우보이 주간 랭킹 전환 후 남은 구(舊) 시즌 노드 정리 스크립트.

배경: 랭킹이 월간(seasons/yyyy-MM) → 주간(seasons/yyyy-MM-dd)으로 바뀌면서
      월간 키와 테스트용 키는 더 이상 읽히지 않는 고아 데이터가 됐다.

안전 원칙:
  - 기본 실행은 읽기전용 dry-run — 무엇을 지울지 목록만 보여주고 아무것도 안 지운다.
  - 실제 삭제는 `--delete` + "yes" 입력이 있어야만 수행한다.
  - 삭제 대상은 (1) 월간 형식 yyyy-MM, (2) 명시된 테스트 키(JUNK_KEYS)뿐.
    **주간 키(yyyy-MM-dd)는 절대 건드리지 않는다.**
  - 삭제는 firebase CLI(프로젝트 소유자 권한, 규칙 우회)로 노드를 제거한다
    (RTDB 규칙상 일반 클라이언트는 seasons/$sid 부모를 못 지운다).

사용법:
  python3 tools/cleanup_old_seasons.py            # dry-run(목록만)
  python3 tools/cleanup_old_seasons.py --delete   # 확인 후 실제 삭제
"""
import json
import re
import subprocess
import sys
import urllib.request

DB = "https://cowboy-party-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app"
PROJECT = "cowboy-party-doonghwi"
INSTANCE = "cowboy-party-doonghwi-default-rtdb"
JUNK_KEYS = {"s_test", "zt"}  # 주간/월간 형식이 아닌 테스트 잔여물
MONTHLY_RE = re.compile(r"\d{4}-\d{2}")     # 구 월간 키
WEEKLY_RE = re.compile(r"\d{4}-\d{2}-\d{2}")  # 신 주간 키(보호 대상)


def _get(path):
    with urllib.request.urlopen(f"{DB}/{path}", timeout=15) as r:
        return json.load(r)


def main():
    do_delete = "--delete" in sys.argv[1:]
    print("== seasons/ 스캔 (읽기전용) ==")
    keys = list((_get("seasons.json?shallow=true") or {}).keys())

    targets = []
    for k in keys:
        if WEEKLY_RE.fullmatch(k):
            continue  # 주간 키는 절대 대상에 넣지 않는다
        if MONTHLY_RE.fullmatch(k) or k in JUNK_KEYS:
            targets.append(k)

    if not targets:
        print("정리할 구 시즌 노드가 없습니다. (주간 키만 존재)")
        return

    print("정리 대상 후보:")
    for k in targets:
        node = _get(f"seasons/{k}.json")
        cnt = len(node) if isinstance(node, dict) else 1
        print(f"  - seasons/{k}  (엔트리 {cnt}개)")

    protected = [k for k in keys if WEEKLY_RE.fullmatch(k)]
    print(f"\n보호(유지)되는 주간 키: {protected or '아직 없음'}")

    if not do_delete:
        print("\n※ dry-run입니다. 실제 삭제하려면: "
              "python3 tools/cleanup_old_seasons.py --delete")
        return

    ans = input("\n위 노드들을 정말 삭제할까요? 되돌릴 수 없습니다. "
                "(yes 입력 시에만 진행) ").strip()
    if ans != "yes":
        print("취소했습니다. 아무것도 지우지 않았습니다.")
        return

    for k in targets:
        print(f"삭제: seasons/{k}")
        r = subprocess.run(
            ["firebase", "database:remove", f"/seasons/{k}",
             "--project", PROJECT, "--instance", INSTANCE, "--confirm"],
            capture_output=True, text=True)
        if r.returncode != 0:
            print(f"!! seasons/{k} 삭제 실패 — 권한/네트워크 확인 필요. 중단합니다.")
            print(r.stderr.strip()[:500])
            sys.exit(1)
    print("\n완료. 남은 seasons 키:", list((_get("seasons.json?shallow=true") or {}).keys()))


if __name__ == "__main__":
    main()
