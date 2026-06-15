#!/usr/bin/env python3
"""Play 피처 그래픽(1024x500) 생성 — 앱 아이콘 + 타이틀 + 태그라인.

자작 에셋(앱 아이콘·번들 폰트)만 사용. 재현 가능:
    python3 tool/make_feature_graphic.py
산출물: store/feature_graphic.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 1024, 500

# 브랜드 색 (앱 adaptive 배경 = #2E6E5A 세이지 그린)
TOP = (46, 110, 90)
BOT = (28, 70, 56)
GOLD = (217, 164, 65)
CREAM = (239, 226, 198)

img = Image.new("RGB", (W, H), TOP)
px = img.load()
for y in range(H):  # 세로 그라데이션
    t = y / (H - 1)
    r = int(TOP[0] + (BOT[0] - TOP[0]) * t)
    g = int(TOP[1] + (BOT[1] - TOP[1]) * t)
    b = int(TOP[2] + (BOT[2] - TOP[2]) * t)
    for x in range(W):
        px[x, y] = (r, g, b)

draw = ImageDraw.Draw(img)

# 아이콘 (좌측, 둥근 그림자)
icon = Image.open(os.path.join(ROOT, "assets/icon/icon.png")).convert("RGBA")
isz = 300
icon = icon.resize((isz, isz), Image.LANCZOS)
ix, iy = 70, (H - isz) // 2
shadow = Image.new("RGBA", (isz + 24, isz + 24), (0, 0, 0, 0))
ImageDraw.Draw(shadow).ellipse([0, 0, isz + 24, isz + 24], fill=(0, 0, 0, 70))
img.paste(shadow, (ix - 12, iy - 6), shadow)
img.paste(icon, (ix, iy), icon)

def font(path, size):
    return ImageFont.truetype(os.path.join(ROOT, "assets/fonts", path), size)

f_title = font("BlackHanSans-Regular.ttf", 118)
f_en = font("Rye-Regular.ttf", 60)
f_tag = font("GothicA1-Bold.ttf", 34)

tx = ix + isz + 60
# 타이틀
draw.text((tx, 120), "카우보이", font=f_title, fill=CREAM)
draw.text((tx + 4, 252), "COWBOY", font=f_en, fill=GOLD)
# 태그라인
draw.text((tx, 340), "서부 눈치 대결 · 2~6인 동시 행동", font=f_tag, fill=CREAM)

img.save(os.path.join(ROOT, "store/feature_graphic.png"))
print("feature_graphic.png written:", img.size)
