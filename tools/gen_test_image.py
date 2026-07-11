#!/usr/bin/env python3
"""Gemini 이미지 생성 테스트 — 기존 캐릭터 스타일 참조 카우보이 1장."""
import base64, json, os, sys, urllib.request

API_KEY = os.environ["GEMINI_API_KEY"]
MODEL = sys.argv[1] if len(sys.argv) > 1 else "gemini-2.5-flash-image"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "growth/art_samples")
os.makedirs(OUT, exist_ok=True)

def img_part(path):
    with open(path, "rb") as f:
        return {"inline_data": {"mime_type": "image/png",
                                "data": base64.b64encode(f.read()).decode()}}

refs = [os.path.join(REPO, "assets/characters", n)
        for n in ("commoner.png", "hunter.png", "duelist.png")]

prompt = (
    "You are creating a NEW character for a western party game, matching the exact "
    "art style of the three reference character portraits provided (same illustrator). "
    "Match: soft comic ink lines, warm muted western palette (browns, tans, deep reds), "
    "gentle cel shading, bust-up portrait composition, plain pure-white background, "
    "square 1:1 canvas.\n\n"
    "New character: a weathered veteran SHERIFF in his 50s — gray-streaked mustache, "
    "brown wide-brim cowboy hat, gold star badge on a dark leather vest, red neckerchief, "
    "calm confident slight smile, facing slightly left. "
    "No text, no watermark, no border. Pure white background."
)

body = {
    "contents": [{"parts": [img_part(r) for r in refs] + [{"text": prompt}]}],
    "generationConfig": {"responseModalities": ["IMAGE"]},
}

req = urllib.request.Request(
    f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "x-goog-api-key": API_KEY},
)
try:
    with urllib.request.urlopen(req, timeout=180) as r:
        resp = json.load(r)
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.read().decode()[:800])
    sys.exit(1)

saved = 0
for cand in resp.get("candidates", []):
    for part in cand.get("content", {}).get("parts", []):
        if "inlineData" in part:
            out = os.path.join(OUT, f"test_sheriff_{MODEL.replace('.', '_')}.png")
            with open(out, "wb") as f:
                f.write(base64.b64decode(part["inlineData"]["data"]))
            print("saved:", out)
            saved += 1
        elif "text" in part:
            print("text:", part["text"][:300])
if not saved:
    print("NO IMAGE. usage:", json.dumps(resp.get("usageMetadata", {})))
    print(json.dumps(resp)[:1000])
    sys.exit(2)
