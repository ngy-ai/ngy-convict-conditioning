"""示意图后处理与体检：水平镜像、把整块剪影压成单一棕色 #5B3A24、批量检查规格。

用法（参数用式次前缀，避免命令行传中文路径）：
    python tool/figtool.py mirror 53
    python tool/figtool.py flatten 32 33 49
    python tool/figtool.py audit          # 全部 60 张
    python tool/figtool.py audit 23 37    # 只查指定几张
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "assets" / "exercise-figures"
BROWN = np.array([0x5B, 0x3A, 0x24], dtype=np.uint8)
# 剪影主体（含深浅两种棕色）亮度都在 160 以下；160 以上只留抗锯齿过渡与白色背景/浅灰道具。
SOLID_LUM = 160.0
# 剪影像素中，纯 #5B3A24 占比低于该值即认为存在「两块褐色」。
PURE_RATIO = 0.97


def figure_mask(pixels: np.ndarray) -> np.ndarray:
    r, g, b = pixels[..., 0], pixels[..., 1], pixels[..., 2]
    luminance = pixels.mean(axis=2)
    brownish = (r - b > 12) & (r >= g) & (g >= b)
    return brownish & (luminance < SOLID_LUM)


def resolve(prefix: str) -> Path:
    matches = sorted(ROOT.glob(f"{prefix}-*.png"))
    if len(matches) != 1:
        raise SystemExit(f"{prefix}: expected 1 file, got {matches}")
    return matches[0]


def mirror(path: Path) -> None:
    Image.open(path).transpose(Image.FLIP_LEFT_RIGHT).save(path)
    print("mirror", path.name)


def flatten(path: Path) -> None:
    """把深色剪影内部所有深浅不一的棕色统一成 #5B3A24，保留抗锯齿与浅灰道具。"""
    pixels = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    solid = figure_mask(pixels)
    out = pixels.copy()
    out[solid] = BROWN
    Image.fromarray(out.astype(np.uint8)).save(path)
    print("flatten", path.name, "solid", int(solid.sum()))


def whiten(path: Path) -> None:
    """把背景压成纯 #FFFFFF：亮度 ≥252 的中性像素直接置白，去掉生成图的 ±2 噪点。

    阈值取 252 是为了不伤到浅灰墙面（≈247）与地面细线。
    """
    pixels = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    luminance = pixels.mean(axis=2)
    neutral = (pixels.max(axis=2) - pixels.min(axis=2)) < 10
    background = neutral & (luminance >= 252)
    out = pixels.copy()
    out[background] = 255
    Image.fromarray(out.astype(np.uint8)).save(path)
    print("whiten", path.name, "px", int(background.sum()))


def normalize(path: Path) -> None:
    flatten(path)
    whiten(path)


def audit(path: Path) -> None:
    image = Image.open(path).convert("RGB")
    pixels = np.asarray(image).astype(np.float32)
    mask = figure_mask(pixels)
    total = int(mask.sum())
    pure = int((np.all(pixels[mask] == BROWN, axis=-1)).sum()) if total else 0
    ratio = pure / total if total else 0.0
    corners = [pixels[0, 0], pixels[0, -1], pixels[-1, 0], pixels[-1, -1]]
    # 生成图自带 ±2 的压缩噪声，肉眼不可分，因此角点 ≥250 且中性即视为纯白。
    white = all(c.min() >= 250 and c.max() - c.min() <= 4 for c in corners)
    flags = []
    if image.size != (1024, 1024):
        flags.append(f"size={image.size}")
    if not white:
        flags.append("背景非纯白")
    if ratio < PURE_RATIO:
        flags.append(f"棕色不纯 {ratio:.1%}")
    print(f"{path.name:<24} fig={total:<7} pure={ratio:6.1%} {' '.join(flags) or 'ok'}")


if __name__ == "__main__":
    action, prefixes = sys.argv[1], sys.argv[2:]
    handler = {
        "mirror": mirror,
        "flatten": flatten,
        "whiten": whiten,
        "normalize": normalize,
        "audit": audit,
    }[action]
    targets = [resolve(p) for p in prefixes] if prefixes else sorted(ROOT.glob("*.png"))
    for path in targets:
        handler(path)
