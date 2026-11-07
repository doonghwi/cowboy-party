#!/usr/bin/env python3
"""제보 답변 관리자 도구 (2026-11-06, growth/FEEDBACK_REPLY_PLAN.md A).

  python3 tools/feedback_reply.py list                      # 답 없는 제보(닉네임 포함)
  python3 tools/feedback_reply.py list --all                # 전부
  python3 tools/feedback_reply.py reply <uid앞6|닉네임> "<답변>"   # 가장 최근 제보에 답변
  python3 tools/feedback_reply.py reply <uid앞6|닉네임> "<답변>" --id <제보id>
  python3 tools/feedback_reply.py message <uid앞6|닉네임> "<메시지>" # 제보 없이 운영자 메시지 보내기

답변은 RTDB feedback/{uid}/{id}/reply 에 기록 → 앱 설정에 빨간 점, 제보·문의 창에 표시.
"""
import sys
import time
from datetime import datetime

import _fbdb as db


def resolve_uid(key):
    """uid 앞글자(6자 이상) 또는 닉네임 → 전체 uid."""
    nick = db.get("/nicknames") or {}
    if key in nick:
        return nick[key]
    cands = {u for u in nick.values() if u.startswith(key)}
    fb = db.get("/feedback", shallow=True) or {}
    cands |= {u for u in fb if u.startswith(key)}
    if len(cands) == 1:
        return cands.pop()
    if not cands:
        raise SystemExit(f"'{key}' 에 맞는 사용자가 없어요 (닉네임 또는 uid 앞 6자)")
    raise SystemExit(f"'{key}' 가 여러 명에 맞아요: {sorted(cands)} — 더 길게 적어주세요")


def fmt(ms):
    return datetime.fromtimestamp(ms / 1000).strftime("%m-%d %H:%M") if ms else "-"


def cmd_list(show_all):
    fb = db.get("/feedback") or {}
    rows = []
    for uid, items in fb.items():
        for fid, v in (items or {}).items():
            if not isinstance(v, dict):
                continue
            if not show_all and v.get("reply"):
                continue
            rows.append((v.get("at", 0), uid, fid, v))
    rows.sort(reverse=True)
    if not rows:
        print("제보 없음" if show_all else "답 없는 제보 없음")
        return
    for at, uid, fid, v in rows:
        nick = db.nickname_of(uid) or "(닉네임 없음)"
        print(f"[{fmt(at)}] {nick} #{uid[:6]} id={fid} 빌드{v.get('build', '?')}")
        print(f"   제보: {v.get('text', '')}")
        if v.get("reply"):
            print(f"   답변({fmt(v.get('repliedAt', 0))}): {v['reply']}"
                  + ("  ✓읽음" if v.get("readAt") else ""))


def cmd_reply(key, text, fid=None):
    uid = resolve_uid(key)
    items = db.get(f"/feedback/{uid}") or {}
    if fid is None:
        cands = [(v.get("at", 0), k) for k, v in items.items() if isinstance(v, dict)]
        if not cands:
            raise SystemExit("이 사용자의 제보가 없어요 — `message` 명령으로 운영자 메시지를 보내세요")
        fid = max(cands)[1]
    now = int(time.time() * 1000)
    db.update(f"/feedback/{uid}/{fid}", {"reply": text, "repliedAt": now})
    print(f"답변 기록: {db.nickname_of(uid) or uid[:6]} id={fid}")


def cmd_message(key, text):
    uid = resolve_uid(key)
    now = int(time.time() * 1000)
    fid = db.push(f"/feedback/{uid}", {"text": "", "at": now, "build": 0, "reply": text, "repliedAt": now})
    print(f"운영자 메시지 전송: {db.nickname_of(uid) or uid[:6]} id={fid}")


def main(argv):
    if len(argv) < 2 or argv[1] not in ("list", "reply", "message"):
        print(__doc__)
        return 1
    if argv[1] == "list":
        cmd_list("--all" in argv)
    elif argv[1] == "reply":
        fid = argv[argv.index("--id") + 1] if "--id" in argv else None
        cmd_reply(argv[2], argv[3], fid)
    else:
        cmd_message(argv[2], argv[3])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
