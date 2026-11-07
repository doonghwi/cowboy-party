"""Firebase RTDB 관리자 접근 공통 — 이 맥의 `firebase` CLI 로그인(관리자 권한)으로 읽고 쓴다.
새 키 발급 없음. 규칙(database.rules.json)은 CLI에 적용되지 않는다.
"""
import json
import os
import subprocess
import tempfile

PROJECT = "cowboy-party-doonghwi"
INSTANCE = "cowboy-party-doonghwi-default-rtdb"
_ENV = {**os.environ, "NODE_OPTIONS": "--no-deprecation"}


def _run(args, data=None):
    # database:* 명령의 경로는 반드시 '/'로 시작해야 한다(remove 가 조용히 실패하던 원인).
    args = [("/" + a if i == 1 and not a.startswith("/") else a) for i, a in enumerate(args)]
    cmd = ["firebase", *args, "--project", PROJECT, "--instance", INSTANCE]
    if data is not None:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(data, f, ensure_ascii=False)
            path = f.name
        cmd += [path]
    r = subprocess.run(cmd, capture_output=True, text=True, env=_ENV)
    if r.returncode != 0:
        raise SystemExit(f"firebase 실패: {' '.join(cmd)}\n{r.stderr.strip()[-800:]}")
    return r.stdout


def get(path, shallow=False):
    args = ["database:get", path]
    if shallow:
        args.append("--shallow")
    out = _run(args).strip()
    return json.loads(out) if out else None


def update(path, data):
    """부분 갱신(merge). 승인 프롬프트 없이 실행(-f)."""
    _run(["database:update", path, "-f"], data)


def push(path, data):
    out = _run(["database:push", path], data)
    # 출력 예: "Data pushed successfully\n  https://.../notices/-N..." → key 추출
    for tok in out.split():
        if "/" in tok:
            return tok.rstrip("/").rsplit("/", 1)[-1]
    return None


def remove(path):
    _run(["database:remove", path, "-f"])


def nickname_of(uid):
    """nicknames/{name} = uid 역조회(공개 노드)."""
    m = get("/nicknames") or {}
    for name, u in m.items():
        if u == uid:
            return name
    return None
