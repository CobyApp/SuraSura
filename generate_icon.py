"""
SuraSura 앱 아이콘 v7 — ultra simple, thin bubbles
콘셉트: 얇은 두 버블, iPhone 전용
"""

from PIL import Image, ImageDraw
import os, json

BLUE      = (37, 99, 235)
WHITE     = (255, 255, 255, 255)
WHITE_DIM = (255, 255, 255, 180)


def rounded_rect_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    return mask


def create_icon(size):
    s = size
    img = Image.new("RGBA", (s, s), (*BLUE, 255))
    img.putalpha(rounded_rect_mask(s, int(s * 0.225)))
    draw = ImageDraw.Draw(img, "RGBA")

    pad = int(s * 0.13)
    br  = int(s * 0.065)  # 모서리 둥글기

    # 공통 버블 크기 — 동일한 너비/높이, 같은 흰색
    bw = int(s * 0.48)
    bh = int(s * 0.16)

    # 버블 1 — 왼쪽 정렬, 위쪽
    b1_x = pad
    b1_y = int(s * 0.24)
    draw.rounded_rectangle(
        [b1_x, b1_y, b1_x + bw, b1_y + bh],
        radius=br, fill=WHITE
    )

    # 버블 2 — 오른쪽 정렬, 아래쪽
    b2_x = s - pad - bw
    b2_y = int(s * 0.60)
    draw.rounded_rectangle(
        [b2_x, b2_y, b2_x + bw, b2_y + bh],
        radius=br, fill=WHITE
    )

    return img


# ── 저장 ─────────────────────────────────────────────────────────
SIZES = [1024, 180, 120, 87, 80, 60, 58, 40]

OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "App/Resources/Assets.xcassets/AppIcon.appiconset"
)
os.makedirs(OUT_DIR, exist_ok=True)

master = create_icon(1024)
master.save(os.path.join(OUT_DIR, "icon_1024.png"), "PNG")
print("✅ 1024×1024")

for sz in [s for s in SIZES if s != 1024]:
    master.resize((sz, sz), Image.LANCZOS).save(
        os.path.join(OUT_DIR, f"icon_{sz}.png"), "PNG"
    )
    print(f"✅ {sz}×{sz}")

contents = {
    "images": [
        {"size": "20x20",     "idiom": "iphone",        "scale": "2x", "filename": "icon_40.png"},
        {"size": "20x20",     "idiom": "iphone",        "scale": "3x", "filename": "icon_60.png"},
        {"size": "29x29",     "idiom": "iphone",        "scale": "2x", "filename": "icon_58.png"},
        {"size": "29x29",     "idiom": "iphone",        "scale": "3x", "filename": "icon_87.png"},
        {"size": "40x40",     "idiom": "iphone",        "scale": "2x", "filename": "icon_80.png"},
        {"size": "40x40",     "idiom": "iphone",        "scale": "3x", "filename": "icon_120.png"},
        {"size": "60x60",     "idiom": "iphone",        "scale": "2x", "filename": "icon_120.png"},
        {"size": "60x60",     "idiom": "iphone",        "scale": "3x", "filename": "icon_180.png"},
        {"size": "1024x1024", "idiom": "ios-marketing", "scale": "1x", "filename": "icon_1024.png"},
    ],
    "info": {"version": 1, "author": "xcode"}
}
with open(os.path.join(OUT_DIR, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

print("🎉 완료!")
