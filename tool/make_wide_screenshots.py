#!/usr/bin/env python3
"""Play 가로 16:9(1920x1080) 스토어 스크린샷 합성 — 폰 캡처 2장 + 카피.

재현 가능. 자작 에셋(게임 스크린샷·번들 폰트)만 사용:
    python3 tool/make_wide_screenshots.py
입력:  store/screenshots/wide_src/<이름>.png (1080x2400 폰 캡처)
산출물: store/screenshots/wide/wide_XX_<slug>.png (1920x1080)

브랜드 색은 tool/make_feature_graphic.py와 동일.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "store", "screenshots", "wide_src")
OUT = os.path.join(ROOT, "store", "screenshots", "wide")
os.makedirs(OUT, exist_ok=True)

TOP = (46, 110, 90)
BOT = (28, 70, 56)
GOLD = (217, 164, 65)
CREAM = (239, 226, 198)
W, H = 1920, 1080

FONT_TITLE = os.path.join(ROOT, "assets", "fonts", "BlackHanSans-Regular.ttf")
FONT_BODY = os.path.join(ROOT, "assets", "fonts", "Pretendard-Bold.otf")

# (슬러그, 왼쪽 캡처, 오른쪽 캡처, 헤드라인, 서브카피)
CARDS = [
    ("duel", "tutorial_coach.png", "game_hit.png",
     "눈치싸움 한 판, 빵야!", "장전·방어·빵야 — 마지막 1인이 될 때까지"),
    ("social", "friends_tab.png", "waiting_room.png",
     "친구와 1:1 결투장", "친구 탭에서 바로 친선전 · 방 초대"),
    ("meta", "shop_carousel.png", "rewards_pass.png",
     "15인의 총잡이를 모아라", "캐릭터 대사·능력 · 시즌 패스 보상 길"),
]


def vgrad(w, h):
    img = Image.new("RGB", (w, h), TOP)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        px_row = tuple(int(TOP[i] + (BOT[i] - TOP[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = px_row
    return img


def rounded(img, rad):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1], rad, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out


def phone(img_path, height):
    shot = Image.open(img_path).convert("RGB")
    w = int(shot.width * height / shot.height)
    shot = shot.resize((w, height), Image.LANCZOS)
    return rounded(shot, 36)


def main():
    title_f = ImageFont.truetype(FONT_TITLE, 88)
    sub_f = ImageFont.truetype(FONT_BODY, 40)
    for i, (slug, left, right, headline, sub) in enumerate(CARDS, 1):
        lp, rp = os.path.join(SRC, left), os.path.join(SRC, right)
        if not (os.path.exists(lp) and os.path.exists(rp)):
            print(f"skip {slug}: 캡처 없음 ({left}, {right})")
            continue
        canvas = vgrad(W, H).convert("RGBA")
        d = ImageDraw.Draw(canvas)
        # 은은한 원형 하이라이트.
        glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([W // 2 - 560, -260, W // 2 + 560, 620],
                                     fill=(255, 240, 200, 46))
        canvas = Image.alpha_composite(
            canvas, glow.filter(ImageFilter.GaussianBlur(120)))
        d = ImageDraw.Draw(canvas)

        ph = 860
        l_img = phone(lp, ph)
        r_img = phone(rp, ph)
        # 폰 2장 — 살짝 겹치게 우측 배치, 그림자.
        x0 = W - l_img.width - r_img.width - 60
        for img, (x, y) in [(l_img, (x0, H - ph + 60)),
                            (r_img, (x0 + l_img.width - 40, H - ph + 130))]:
            sh = Image.new("RGBA", (img.width + 60, img.height + 60), (0, 0, 0, 0))
            ImageDraw.Draw(sh).rounded_rectangle(
                [30, 34, img.width + 30, img.height + 38], 40, fill=(0, 0, 0, 130))
            canvas.alpha_composite(
                sh.filter(ImageFilter.GaussianBlur(22)), (x - 30, y - 30))
            canvas.alpha_composite(img, (x, y))

        # 좌측 카피.
        tx = 96
        d = ImageDraw.Draw(canvas)
        d.text((tx, 300), headline, font=title_f, fill=CREAM)
        d.text((tx, 300 + 118), sub, font=sub_f, fill=GOLD)
        d.rounded_rectangle([tx, 300 + 196, tx + 470, 300 + 202], 3, fill=GOLD)

        out = os.path.join(OUT, f"wide_{i:02d}_{slug}.png")
        canvas.convert("RGB").save(out)
        print("OK", out)


if __name__ == "__main__":
    main()
