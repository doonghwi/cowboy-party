#!/usr/bin/env python3
"""SNS 홍보 카드 생성 — 정사각(1080x1080) + 와이드/OG(1200x630).

재현 가능. 자작 에셋(앱 아이콘·번들 폰트·게임 스크린샷)만 사용:
    python3 tool/make_promo_cards.py
산출물:
    promo/cards/sns_square_1080.png   (인스타/스레드 1080x1080)
    promo/cards/sns_wide_1200x630.png (트위터/OG 1200x630)

브랜드 색은 store/make_feature_graphic.py와 동일.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "promo", "cards")
os.makedirs(OUT, exist_ok=True)

# 브랜드 색 (앱 adaptive 배경 = #2E6E5A 세이지 그린)
TOP = (46, 110, 90)
BOT = (28, 70, 56)
GOLD = (217, 164, 65)
CREAM = (239, 226, 198)


def vgrad(w, h, top, bot):
    img = Image.new("RGB", (w, h), top)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        px_row = (
            int(top[0] + (bot[0] - top[0]) * t),
            int(top[1] + (bot[1] - top[1]) * t),
            int(top[2] + (bot[2] - top[2]) * t),
        )
        for x in range(w):
            px[x, y] = px_row
    return img


def font(path, size):
    return ImageFont.truetype(os.path.join(ROOT, "assets/fonts", path), size)


def rounded(im, radius):
    """이미지에 둥근 모서리 마스크 적용."""
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0], im.size[1]], radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def cover_crop(im, w, h):
    """object-fit: cover 처럼 비율 유지하며 w×h 채우기."""
    iw, ih = im.size
    scale = max(w / iw, h / ih)
    nim = im.resize((int(iw * scale) + 1, int(ih * scale) + 1), Image.LANCZOS)
    nw, nh = nim.size
    left = (nw - w) // 2
    top = (nh - h) // 2
    return nim.crop((left, top, left + w, top + h))


ICON = Image.open(os.path.join(ROOT, "assets/icon/icon.png")).convert("RGBA")
SHOT = os.path.join(ROOT, "store/screenshots/android/05_gameplay.png")  # 실제 게임 화면


def shadow_circle(size, pad, alpha=70):
    s = Image.new("RGBA", (size + pad * 2, size + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(s).ellipse([0, 0, size + pad * 2, size + pad * 2], fill=(0, 0, 0, alpha))
    return s


# ---------- 1) 정사각 1080x1080 (인스타/스레드) ----------
def make_square():
    W = H = 1080
    img = vgrad(W, H, TOP, BOT)
    draw = ImageDraw.Draw(img)

    isz = 300
    icon = ICON.resize((isz, isz), Image.LANCZOS)
    ix, iy = (W - isz) // 2, 150
    sh = shadow_circle(isz, 14)
    img.paste(sh, (ix - 14, iy - 8), sh)
    img.paste(icon, (ix, iy), icon)

    f_title = font("BlackHanSans-Regular.ttf", 150)
    f_en = font("Rye-Regular.ttf", 64)
    f_tag = font("GothicA1-Bold.ttf", 40)
    f_sub = font("GothicA1-Regular.ttf", 34)

    def center(text, y, fnt, fill):
        w = draw.textlength(text, font=fnt)
        draw.text(((W - w) / 2, y), text, font=fnt, fill=fill)

    center("카우보이", 500, f_title, CREAM)
    center("COWBOY", 672, f_en, GOLD)
    center("서부 눈치 대결 · 2~6인 동시 행동", 770, f_tag, CREAM)
    center("장전? 방어? 아니면 빵야?", 858, f_sub, GOLD)
    center("무료 · 광고 없음 · cowboy.gg", 916, f_sub, CREAM)
    img.save(os.path.join(OUT, "sns_square_1080.png"))
    print("sns_square_1080.png", img.size)


# ---------- 2) 와이드 1200x630 (트위터/OG) ----------
def make_wide():
    W, H = 1200, 630
    img = vgrad(W, H, TOP, BOT)
    draw = ImageDraw.Draw(img)

    # 우측: 실제 게임 스크린샷 패널 (둥근 모서리 + 그림자)
    pw, ph = 300, 540
    if os.path.exists(SHOT):
        shot = cover_crop(Image.open(SHOT).convert("RGB"), pw, ph)
        shot = rounded(shot, 28)
        px, py = W - pw - 60, (H - ph) // 2
        sh = Image.new("RGBA", (pw + 28, ph + 28), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([0, 0, pw + 28, ph + 28], 34, fill=(0, 0, 0, 80))
        img.paste(sh, (px - 14, py - 6), sh)
        img.paste(shot, (px, py), shot)

    # 좌측: 아이콘 + 타이틀 + 카피
    isz = 150
    icon = ICON.resize((isz, isz), Image.LANCZOS)
    lx = 80
    sh = shadow_circle(isz, 10)
    img.paste(sh, (lx - 10, 70 - 4), sh)
    img.paste(icon, (lx, 70), icon)

    f_title = font("BlackHanSans-Regular.ttf", 104)
    f_en = font("Rye-Regular.ttf", 46)
    f_tag = font("GothicA1-Bold.ttf", 34)
    f_sub = font("GothicA1-Regular.ttf", 28)

    draw.text((lx, 250), "카우보이", font=f_title, fill=CREAM)
    draw.text((lx + 4, 366), "COWBOY", font=f_en, fill=GOLD)
    draw.text((lx, 438), "서부 눈치 대결 · 2~6인 동시 행동", font=f_tag, fill=CREAM)
    draw.text((lx, 492), "장전? 방어? 아니면 빵야? — 마지막 한 명이 승자", font=f_sub, fill=GOLD)
    draw.text((lx, 534), "무료 · 광고 없음 · cowboy.gg", font=f_sub, fill=CREAM)
    img.save(os.path.join(OUT, "sns_wide_1200x630.png"))
    print("sns_wide_1200x630.png", img.size)


if __name__ == "__main__":
    make_square()
    make_wide()
    print("done →", OUT)
