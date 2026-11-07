#!/usr/bin/env python3
"""원격 공지 관리자 도구 (2026-11-06, growth/FEEDBACK_REPLY_PLAN.md B).

  python3 tools/notice.py post "<제목>" "<본문>" [--until YYYY-MM-DD] [--date YYYY-MM-DD]
  python3 tools/notice.py list
  python3 tools/notice.py remove <id>

RTDB notices/{id} = {date, title, body, until?}. 앱은 시작 시 읽어 내장 공지와 합친다
(앱 업데이트 불필요). 본문 줄바꿈은 \\n 으로.
"""
import sys
from datetime import date

import _fbdb as db


def main(argv):
    if len(argv) < 2 or argv[1] not in ("post", "list", "remove"):
        print(__doc__)
        return 1
    if argv[1] == "list":
        for k, v in sorted((db.get("/notices") or {}).items(), key=lambda kv: kv[1].get("date", ""), reverse=True):
            print(f"{k}  {v.get('date')}  {v.get('title')}" + (f"  (까지 {v['until']})" if v.get("until") else ""))
            print("   " + v.get("body", "").replace("\n", "\n   "))
        return 0
    if argv[1] == "remove":
        db.remove(f"/notices/{argv[2]}")
        print("삭제:", argv[2])
        return 0
    title, body = argv[2], argv[3].replace("\\n", "\n")
    d = argv[argv.index("--date") + 1] if "--date" in argv else date.today().isoformat()
    data = {"date": d, "title": title, "body": body}
    if "--until" in argv:
        data["until"] = argv[argv.index("--until") + 1]
    k = db.push("/notices", data)
    print("게시:", k, title)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
