# -*- coding: utf-8 -*-
"""App 图标：出母版并铺到 Android / iOS / Windows 三端。

默认是「鎏金徽章」：深墨底上一层金色徽章——外圈细金环、内圈一圈念珠
（其中六颗稍大，暗合「六艺」），正中是金色「囚」。全部矢量式绘制，
每个尺寸都从同一张 1024 母版缩放，小尺寸不放大小图、不留水印。

用法（仓库根目录下执行，需要 Pillow：pip install pillow）：
    python tool/app_icon/make_icon.py                   # 鎏金徽章（默认）
    python tool/app_icon/make_icon.py --style flat      # 另一路配色（rust/night）
    python tool/app_icon/make_icon.py --from 设计稿.png  # 用外部母版（正方形，建议 1024）
    python tool/app_icon/make_icon.py --check           # 只校验三端图标，不改文件
"""
import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[2]
MASTER_PATH = Path(__file__).resolve().parent / "app_icon_1024.png"

GLYPH = "囚"
SS = 2                          # 母版超采样倍数，边缘更干净
SIZE = 1024
DEFAULT_FONT = r"C:\Windows\Fonts\msyhbd.ttc"
FALLBACK_FONTS = (
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\Dengb.ttf",
    "C:/Windows/Fonts/msyh.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
)

# 鎏金徽章的几何：全部按画布边长的比例，换尺寸不用改。
RING_OUTER = 0.396              # 外金环半径
RING_OUTER_WIDTH = 0.014
RING_INNER = 0.352              # 内圈发丝环半径
RING_INNER_WIDTH = 0.0045
BEAD_RING = 0.318               # 念珠所在圆圈半径
BEAD = 0.036                    # 珠子直径
BEAD_BIG_SCALE = 1.35           # 六颗大珠子的放大倍数
BEAD_COUNT = 24                 # 24 = 6 的整数倍，六颗大珠子正好每 60° 一颗
GLYPH_RATIO = 0.33              # 中央字形的墨迹高度

GILDED = {
    "ink_top": (16, 15, 19),
    "ink_bottom": (8, 8, 10),
    "warm_glow": ((66, 48, 20), 0.3),
    "gold_top": (255, 236, 180),
    "gold_bottom": (190, 133, 46),
    "specular": 120,            # 左上高光强度
    "halo": 0.26,               # 金字外发光
    "adaptive_bg": "100f13",
}

# 另一路配色：扁平色块，跟应用内的「夜铁」「纸感」同源。
FLAT = {
    "rust": {
        "bg_top": (198, 88, 32),
        "bg_bottom": (136, 50, 15),
        "glow": ((255, 200, 150), 0.14),
        "halo": 0.18,
        "halo_blur": 0.03,
        "glyph_top": (24, 19, 17),
        "glyph_bottom": (16, 13, 12),
        "adaptive_bg": "b4491c",
        "glyph_ratio": 0.58,
    },
    "night": {
        "bg_top": (30, 24, 22),
        "bg_bottom": (16, 14, 13),
        "glow": ((78, 42, 25), 0.22),
        "halo": 0.30,
        "halo_blur": 0.02,
        "glyph_top": (212, 98, 58),
        "glyph_bottom": (150, 56, 15),
        "adaptive_bg": "1e1816",
        "glyph_ratio": 0.58,
    },
}

ANDROID = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
ANDROID_FOREGROUND = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}
ADAPTIVE_SAFE = 72 / 108        # 自适应前景：可见区只占图层的 72/108
IOS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

ICON_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- 自适应图标：底色 + 中间的徽章层，8.0 以上系统会自动裁成圆形/方形。 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""

COLOR_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#%s</color>
</resources>
"""


# ───────────────────────── 基础绘制 ─────────────────────────

def pick_font(preferred=None):
    for path in (preferred, DEFAULT_FONT, *FALLBACK_FONTS):
        if path and Path(path).exists():
            return path
    raise SystemExit("找不到可用的中文字体，用 --font 指定一个")


def vertical_gradient(size, top, bottom):
    grad = Image.new("RGB", (1, size), top)
    for y in range(size):
        k = y / max(size - 1, 1)
        grad.putpixel((0, y), tuple(
            round(top[i] + (bottom[i] - top[i]) * k) for i in range(3)
        ))
    return grad.resize((size, size))


def soft_light(size, color, strength, blur, squash=0.92):
    """中心到边缘渐隐的柔光，用来做底色的暖调。"""
    glow = Image.new("L", (size, size), 0)
    r = size * 0.62
    ImageDraw.Draw(glow).ellipse(
        (size / 2 - r, size / 2 - r * squash, size / 2 + r, size / 2 + r * squash),
        fill=strength,
    )
    return Image.new("RGB", (size, size), color), glow.filter(
        ImageFilter.GaussianBlur(blur)
    )


def glyph_mask(font_path, canvas, ratio):
    """字形蒙版：裁到墨迹边界再缩放，构图不受字体自带留白影响。"""
    font = ImageFont.truetype(font_path, canvas)
    raw = Image.new("L", (canvas * 2, canvas * 2), 0)
    ImageDraw.Draw(raw).text((canvas, canvas), GLYPH, font=font, fill=255, anchor="mm")
    raw = raw.crop(raw.getbbox())
    height = round(canvas * ratio)
    scale = height / raw.height
    return raw.resize((max(1, round(raw.width * scale)), height), Image.LANCZOS)


def emblem_mask(canvas, font_path=None, scale=1.0):
    """金色元素蒙版：外环 + 发丝环 + 念珠圈 + 中央的「囚」。"""
    mask = Image.new("L", (canvas, canvas), 0)
    draw = ImageDraw.Draw(mask)
    mid = canvas / 2

    def ring(radius, width):
        r = canvas * radius * scale
        draw.ellipse((mid - r, mid - r, mid + r, mid + r),
                     outline=255, width=max(1, round(canvas * width * scale)))

    ring(RING_OUTER, RING_OUTER_WIDTH)
    ring(RING_INNER, RING_INNER_WIDTH)

    bead_ring = canvas * BEAD_RING * scale
    for i in range(BEAD_COUNT):
        angle = 2 * math.pi * i / BEAD_COUNT - math.pi / 2
        big = i % (BEAD_COUNT // 6) == 0
        radius = canvas * BEAD * scale * (BEAD_BIG_SCALE if big else 1.0) / 2
        cx = mid + bead_ring * math.cos(angle)
        cy = mid + bead_ring * math.sin(angle)
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=255)

    glyph = glyph_mask(pick_font(font_path), canvas, GLYPH_RATIO)
    figured = Image.new("L", (canvas, canvas), 0)
    figured.paste(
        glyph,
        (round(mid - glyph.width / 2), round(mid - glyph.height / 2)),
    )
    if scale != 1.0:
        scaled = int(canvas * scale)
        figured = figured.resize((scaled, scaled), Image.LANCZOS)
        big = Image.new("L", (canvas, canvas), 0)
        big.paste(figured, (round(mid - scaled / 2), round(mid - scaled / 2)))
        figured = big
    return ImageChops.lighter(mask, figured)


# ───────────────────────── 出母版 ─────────────────────────

def draw_master_gilded(font_path=None):
    canvas = SIZE * SS
    base = vertical_gradient(canvas, GILDED["ink_top"], GILDED["ink_bottom"])

    glow_color, glow_strength = GILDED["warm_glow"]
    layer, glow = soft_light(canvas, glow_color, 96, canvas * 0.24)
    base = Image.composite(layer, base, glow.point(lambda v: int(v * glow_strength)))
    base = Image.blend(base, Image.effect_noise((canvas, canvas), 8).convert("RGB"), 0.018)

    mask = emblem_mask(canvas, font_path)

    # 金字外发光：先铺一层模糊的金，再盖上实体金字。
    halo = mask.filter(ImageFilter.GaussianBlur(canvas * 0.022)).point(
        lambda v: int(v * GILDED["halo"])
    )
    base = Image.composite(
        Image.new("RGB", (canvas, canvas), GILDED["gold_top"]), base, halo
    )

    base.paste(
        vertical_gradient(canvas, GILDED["gold_top"], GILDED["gold_bottom"]),
        (0, 0),
        mask,
    )

    # 左上角一道柔光扫过金字，做出鎏金的转折。
    highlight = Image.new("L", (canvas, canvas), 0)
    radius = canvas * 0.5
    center = (canvas * 0.34, canvas * 0.3)
    ImageDraw.Draw(highlight).ellipse(
        (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius),
        fill=GILDED["specular"],
    )
    highlight = ImageChops.multiply(
        highlight.filter(ImageFilter.GaussianBlur(canvas * 0.16)), mask
    )
    base = Image.composite(
        Image.new("RGB", (canvas, canvas), (255, 246, 214)), base, highlight
    )

    return base.resize((SIZE, SIZE), Image.LANCZOS)


def draw_master_flat(variant="rust", font_path=None):
    palette = FLAT[variant]
    canvas = SIZE * SS
    base = vertical_gradient(canvas, palette["bg_top"], palette["bg_bottom"])

    glow_color, glow_strength = palette["glow"]
    layer, glow = soft_light(canvas, glow_color, 90, canvas * 0.2)
    base = Image.composite(layer, base, glow.point(lambda v: int(v * glow_strength)))
    base = Image.blend(base, Image.effect_noise((canvas, canvas), 9).convert("RGB"), 0.025)

    mask = glyph_mask(pick_font(font_path), canvas, palette["glyph_ratio"])
    canvas_mask = Image.new("L", (canvas, canvas), 0)
    canvas_mask.paste(
        mask,
        (
            round((canvas - mask.width) / 2),
            round((canvas - mask.height) / 2) - round(canvas * 0.005),
        ),
    )

    halo = canvas_mask.filter(
        ImageFilter.GaussianBlur(canvas * palette["halo_blur"])
    ).point(lambda v: int(v * palette["halo"]))
    base = Image.composite(
        Image.new("RGB", (canvas, canvas), palette["glyph_top"]), base, halo
    )
    base.paste(
        vertical_gradient(canvas, palette["glyph_top"], palette["glyph_bottom"]),
        (0, 0),
        canvas_mask,
    )
    return base.resize((SIZE, SIZE), Image.LANCZOS)


def sample_master(path):
    """外部母版：取中心一小块当图案色、四角平均当底色，供自适应图标用。"""
    image = Image.open(path).convert("RGB")
    if image.width != image.height:
        side = min(image.width, image.height)
        left = (image.width - side) // 2
        top = (image.height - side) // 2
        image = image.crop((left, top, left + side, top + side))
    if image.width < SIZE:
        print("提醒：母版只有 %dpx，建议 %dpx" % (image.width, SIZE))

    half = round(image.width * 0.06)
    mid = image.width // 2
    ink = image.crop((mid - half, mid - half, mid + half, mid + half)).resize(
        (1, 1), Image.LANCZOS
    ).getpixel((0, 0))
    corners = [
        image.getpixel((4, 4)),
        image.getpixel((image.width - 5, 4)),
        image.getpixel((4, image.height - 5)),
        image.getpixel((image.width - 5, image.height - 5)),
    ]
    bg = tuple(round(sum(c[i] for c in corners) / len(corners)) for i in range(3))
    return image, ink, "#%02x%02x%02x" % bg


# ───────────────────────── 铺三端 ─────────────────────────

def install(master, root):
    written = []

    res = root / "android/app/src/main/res"
    for folder, size in ANDROID.items():
        target = res / folder / "ic_launcher.png"
        master.resize((size, size), Image.LANCZOS).save(target, "PNG")
        written.append(target)

    iconset = root / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in IOS.items():
        target = iconset / name
        # iOS 图标不能带透明通道，统一存 RGB。
        master.resize((size, size), Image.LANCZOS).save(target, "PNG")
        written.append(target)

    ico = root / "windows/runner/resources/app_icon.ico"
    master.resize((256, 256), Image.LANCZOS).save(ico, format="ICO", sizes=ICO_SIZES)
    written.append(ico)
    return written


def install_adaptive(root, background, gold_top, gold_dark, font_path=None):
    """Android 自适应图标：底色一层 + 徽章一层（缩到 72/108 安全区）。"""
    res = root / "android/app/src/main/res"
    written = []

    for folder, size in ANDROID_FOREGROUND.items():
        canvas = size * SS
        mask = emblem_mask(canvas, font_path, scale=ADAPTIVE_SAFE)
        gradient = vertical_gradient(canvas, gold_top, gold_dark).convert("RGBA")
        gradient.putalpha(mask)
        target = res / folder / "ic_launcher_foreground.png"
        gradient.resize((size, size), Image.LANCZOS).save(target, "PNG")
        written.append(target)

    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ICON_XML, encoding="utf-8")
    written.append(anydpi / "ic_launcher.xml")

    color = res / "values" / "ic_launcher_background.xml"
    color.write_text(COLOR_XML % background.lstrip("#"), encoding="utf-8")
    written.append(color)
    return written


# ───────────────────────── 校验 ─────────────────────────

def check(root):
    problems = []

    def look(path, size, mode=None):
        if not path.exists():
            problems.append("%s 不存在" % path.relative_to(root))
            return
        image = Image.open(path)
        if image.size != (size, size):
            problems.append(
                "%s 尺寸 %s，应为 %dx%d" % (path.name, image.size, size, size)
            )
        if mode and image.mode != mode:
            problems.append("%s 模式 %s，应为 %s" % (path.name, image.mode, mode))

    res = root / "android/app/src/main/res"
    for folder, size in ANDROID.items():
        look(res / folder / "ic_launcher.png", size, "RGB")
    for folder, size in ANDROID_FOREGROUND.items():
        look(res / folder / "ic_launcher_foreground.png", size, "RGBA")
    for name, size in IOS.items():
        look(root / "ios/Runner/Assets.xcassets/AppIcon.appiconset" / name, size, "RGB")

    adaptive = res / "mipmap-anydpi-v26/ic_launcher.xml"
    if not adaptive.exists():
        problems.append("mipmap-anydpi-v26/ic_launcher.xml 不存在")
    else:
        text = adaptive.read_text(encoding="utf-8")
        for token in ("adaptive-icon", "ic_launcher_background", "ic_launcher_foreground"):
            if token not in text:
                problems.append("ic_launcher.xml 少了 %s" % token)
    if not (res / "values/ic_launcher_background.xml").exists():
        problems.append("values/ic_launcher_background.xml 不存在")

    ico = root / "windows/runner/resources/app_icon.ico"
    if not ico.exists():
        problems.append("app_icon.ico 不存在")
    else:
        sizes = set(Image.open(ico).info.get("sizes", set()))
        for need in (16, 16), (32, 32), (48, 48), (256, 256):
            if need not in sizes:
                problems.append("app_icon.ico 缺 %dx%d" % need)

    for line in problems:
        print("问题：" + line)
    if problems:
        raise SystemExit(1)
    print("三端图标都正常：尺寸、通道、自适应配置齐全")


# ───────────────────────── 入口 ─────────────────────────

def main(argv=None):
    parser = argparse.ArgumentParser(description="出 App 图标并铺到三端")
    parser.add_argument("--style", choices=("gilded", "flat"), default="gilded",
                        help="gilded＝鎏金徽章（默认），flat＝扁平色块")
    parser.add_argument("--variant", choices=sorted(FLAT), default="rust",
                        help="flat 风格的配色（默认 rust）")
    parser.add_argument("--from", dest="source", help="改用外部母版图片")
    parser.add_argument("--font", help="画字形用的字体文件")
    parser.add_argument("--out", help="把母版另存一份到指定路径")
    parser.add_argument("--check", action="store_true", help="只校验，不改文件")
    args = parser.parse_args(argv)

    if args.check:
        check(REPO_ROOT)
        return

    if args.source:
        master, ink, background = sample_master(Path(args.source))
        gold_top = gold_dark = ink
    elif args.style == "gilded":
        master = draw_master_gilded(args.font)
        background = "#" + GILDED["adaptive_bg"]
        gold_top, gold_dark = GILDED["gold_top"], GILDED["gold_bottom"]
    else:
        master = draw_master_flat(args.variant, args.font)
        palette = FLAT[args.variant]
        background = "#" + palette["adaptive_bg"]
        gold_top = gold_dark = tuple(
            round((palette["glyph_top"][i] + palette["glyph_bottom"][i]) / 2)
            for i in range(3)
        )

    # 只有默认那套（鎏金）写回仓库里的母版，免得别的组合把它覆盖掉。
    if not args.source and args.style == "gilded":
        master.save(MASTER_PATH, "PNG")
        print("母版     %s" % MASTER_PATH.relative_to(REPO_ROOT))

    if args.out:
        master.save(args.out, "PNG")
        print("母版副本 %s" % args.out)

    written = install(master, REPO_ROOT) + install_adaptive(
        REPO_ROOT, background, gold_top, gold_dark, args.font
    )
    for path in written:
        print("         %s" % path.relative_to(REPO_ROOT))
    print("共写入 %d 个文件" % len(written))


if __name__ == "__main__":
    sys.exit(main())
