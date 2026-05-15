from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import math

from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parent
SOURCE_DIR = ROOT / "source-screenshots"
OUTPUT_DIR = ROOT / "generated"
STORE_DIR = OUTPUT_DIR / "apple-iphone-6.9"
HARMONY_DIR = OUTPUT_DIR / "harmony-agc-phone"
PREVIEW_DIR = OUTPUT_DIR / "previews"

CANVAS_SIZE = (1320, 2868)
HARMONY_CANVAS_SIZE = (1080, 1920)
TITLE_COLOR = (47, 123, 234)
SUBTITLE_COLOR = (16, 19, 90)
PATTERN_COLOR = (218, 233, 250, 150)
ACCENT_COLOR = (76, 43, 255)
FRAME_COLOR = (18, 20, 24)
FRAME_HIGHLIGHT = (70, 72, 76)

FONT_CANDIDATES = {
    "title_cjk": [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/Library/Fonts/SF-Pro-Display-Bold.otf",
        "/System/Library/Fonts/SFNS.ttf",
    ],
    "subtitle_cjk": [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/Library/Fonts/SF-Pro-Display-Semibold.otf",
        "/System/Library/Fonts/SFNS.ttf",
    ],
    "title_latin": [
        "/Library/Fonts/SF-Pro-Display-Bold.otf",
        "/Library/Fonts/SF-Pro-Text-Bold.otf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ],
    "subtitle_latin": [
        "/Library/Fonts/SF-Pro-Display-Semibold.otf",
        "/Library/Fonts/SF-Pro-Text-Semibold.otf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ],
}


@dataclass(frozen=True)
class Copy:
    title: str
    subtitle: str


@dataclass(frozen=True)
class Slide:
    source: str
    zh: Copy
    en: Copy


SLIDES = [
    Slide(
        "032480652ca3f80cd96046b7efeeaf49.jpg",
        Copy("随身仓库", "Star 与 PR 随时管理"),
        Copy("Your Repos", "Stars and PRs in reach"),
    ),
    Slide(
        "14a9e5af183624ff79aab4f436f39867.jpg",
        Copy("每日趋势", "读懂开源热点"),
        Copy("Daily Trends", "Read the open-source pulse"),
    ),
    Slide(
        "37d5f8fa6fccfc30511a03700b457f5e.jpg",
        Copy("开源足迹", "贡献与关注一目了然"),
        Copy("Your Footprint", "Contributions at a glance"),
    ),
    Slide(
        "9a6cdd9c92ff3bb17766b96591816d7f.jpg",
        Copy("移动审阅", "PR 细节随时看"),
        Copy("Review PRs", "Details, anywhere"),
    ),
    Slide(
        "b6efa369aae9bde4bfffbc2031cc8124.jpg",
        Copy("组织生态", "关注团队与项目"),
        Copy("Org Profiles", "Follow teams and projects"),
    ),
    Slide(
        "b9d42cb4ec5eadb1ee33666cfa9c087b.jpg",
        Copy("版本追踪", "Release 更新不错过"),
        Copy("Release Watch", "Never miss an update"),
    ),
    Slide(
        "d5564742367fb5dfc5576215813f71e0.jpg",
        Copy("热门项目", "发现增长最快的仓库"),
        Copy("Trending Now", "Find fast-growing repos"),
    ),
]

LANGUAGES = {
    "zh-Hans": lambda slide: slide.zh,
    "en": lambda slide: slide.en,
}


def filename_key(path: Path) -> str:
    return path.name.lower()


def contains_cjk(text: str) -> bool:
    return any("\u3400" <= char <= "\u9fff" for char in text)


def load_font(kind: str, text: str, size: int) -> ImageFont.FreeTypeFont:
    script = "cjk" if contains_cjk(text) else "latin"
    for candidate in FONT_CANDIDATES[f"{kind}_{script}"]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default(size=size)


def draw_triangle_pattern(draw: ImageDraw.ImageDraw, width: int, height: int) -> None:
    step_x = 68
    step_y = 58
    triangle_w = 24
    triangle_h = 22
    for row, y in enumerate(range(0, height + step_y, step_y)):
        offset = 0 if row % 2 == 0 else step_x // 2
        for x in range(-step_x, width + step_x, step_x):
            cx = x + offset
            points = [
                (cx, y),
                (cx - triangle_w // 2, y + triangle_h),
                (cx + triangle_w // 2, y + triangle_h),
            ]
            draw.polygon(points, fill=PATTERN_COLOR)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def resize_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    ratio = max(target_w / image.width, target_h / image.height)
    resized = image.resize((math.ceil(image.width * ratio), math.ceil(image.height * ratio)), Image.LANCZOS)
    left = (resized.width - target_w) // 2
    top = 0
    return resized.crop((left, top, left + target_w, top + target_h))


def make_phone(source: Path, outer_size: tuple[int, int]) -> Image.Image:
    outer_w, outer_h = outer_size
    phone = Image.new("RGBA", outer_size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)

    shadow = Image.new("RGBA", outer_size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((16, 22, outer_w - 16, outer_h - 10), radius=96, fill=(0, 0, 0, 115))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    phone.alpha_composite(shadow)

    draw.rounded_rectangle((18, 18, outer_w - 18, outer_h - 18), radius=104, fill=FRAME_COLOR)
    draw.rounded_rectangle((30, 30, outer_w - 30, outer_h - 30), radius=92, outline=FRAME_HIGHLIGHT, width=6)

    inset = 46
    screen_size = (outer_w - inset * 2, outer_h - inset * 2)
    screen = resize_cover(Image.open(source).convert("RGB"), screen_size).convert("RGBA")
    screen_mask = rounded_mask(screen_size, 78)
    phone.paste(screen, (inset, inset), screen_mask)

    island_w = int(outer_w * 0.24)
    island_h = int(outer_h * 0.036)
    island_x = (outer_w - island_w) // 2
    island_y = 54
    draw.rounded_rectangle(
        (island_x, island_y, island_x + island_w, island_y + island_h),
        radius=island_h // 2,
        fill=(0, 0, 0, 240),
    )

    return phone


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> int:
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0]


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0], box[3] - box[1]


def draw_text_pair(
    draw: ImageDraw.ImageDraw,
    copy: Copy,
    *,
    x: int | None = None,
    y: int = 126,
    gap: int = 40,
    center: bool = True,
    canvas_size: tuple[int, int] = CANVAS_SIZE,
    title_size: int | None = None,
    subtitle_size: int | None = None,
) -> None:
    title_size = title_size or (150 if len(copy.title) <= 12 else 128)
    subtitle_size = subtitle_size or (76 if len(copy.subtitle) <= 24 else 64)
    title_font = load_font("title", copy.title, title_size)
    subtitle_font = load_font("subtitle", copy.subtitle, subtitle_size)

    title_w, title_h = text_size(draw, copy.title, title_font)
    subtitle_w, _ = text_size(draw, copy.subtitle, subtitle_font)
    title_x = (canvas_size[0] - title_w) // 2 if center else x or 92
    subtitle_x = (canvas_size[0] - subtitle_w) // 2 if center else x or 92

    draw.text((title_x, y), copy.title, font=title_font, fill=TITLE_COLOR)
    draw.text((subtitle_x, y + title_h + gap), copy.subtitle, font=subtitle_font, fill=SUBTITLE_COLOR)


def draw_slide(slide: Slide, copy: Copy, index: int) -> Image.Image:
    canvas = Image.new("RGBA", CANVAS_SIZE, (255, 255, 255, 255))
    draw = ImageDraw.Draw(canvas)
    draw_triangle_pattern(draw, *CANVAS_SIZE)

    source = SOURCE_DIR / slide.source
    if index == 1:
        draw_text_pair(draw, copy, x=92, y=138, gap=34, center=False)
        paired_phone = make_phone(SOURCE_DIR / SLIDES[1].source, (980, 2180)).rotate(
            12, resample=Image.Resampling.BICUBIC, expand=True
        )
        canvas.alpha_composite(paired_phone, (1120, 430))
        phone = make_phone(source, (910, 2024)).rotate(
            -12, resample=Image.Resampling.BICUBIC, expand=True
        )
        x = -118
        y = 680
        canvas.alpha_composite(phone, (x, y))
    elif index == 2:
        paired_phone = make_phone(SOURCE_DIR / SLIDES[0].source, (650, 1445)).rotate(
            -12, resample=Image.Resampling.BICUBIC, expand=True
        )
        canvas.alpha_composite(paired_phone, (-690, 2340))
        phone = make_phone(source, (1050, 2334)).rotate(
            12, resample=Image.Resampling.BICUBIC, expand=True
        )
        x = 190
        y = 110
        canvas.alpha_composite(phone, (x, y))
    else:
        draw_text_pair(draw, copy, y=126, gap=46, center=True)
        phone = make_phone(source, (860, 1912))
        x = (CANVAS_SIZE[0] - phone.width) // 2
        y = 620
        canvas.alpha_composite(phone, (x, y))

    return canvas.convert("RGB")


def draw_harmony_slide(slide: Slide, copy: Copy, index: int) -> Image.Image:
    canvas = Image.new("RGBA", HARMONY_CANVAS_SIZE, (255, 255, 255, 255))
    draw = ImageDraw.Draw(canvas)
    draw_triangle_pattern(draw, *HARMONY_CANVAS_SIZE)

    source = SOURCE_DIR / slide.source
    if index == 1:
        draw_text_pair(
            draw,
            copy,
            x=76,
            y=86,
            gap=26,
            center=False,
            canvas_size=HARMONY_CANVAS_SIZE,
            title_size=116 if len(copy.title) <= 12 else 100,
            subtitle_size=58 if len(copy.subtitle) <= 24 else 50,
        )
        paired_phone = make_phone(SOURCE_DIR / SLIDES[1].source, (760, 1690)).rotate(
            12, resample=Image.Resampling.BICUBIC, expand=True
        )
        canvas.alpha_composite(paired_phone, (930, 360))
        phone = make_phone(source, (740, 1646)).rotate(
            -12, resample=Image.Resampling.BICUBIC, expand=True
        )
        canvas.alpha_composite(phone, (-84, 455))
    elif index == 2:
        paired_phone = make_phone(SOURCE_DIR / SLIDES[0].source, (500, 1112)).rotate(
            -12, resample=Image.Resampling.BICUBIC, expand=True
        )
        canvas.alpha_composite(paired_phone, (-555, 1660))
        phone = make_phone(source, (840, 1868)).rotate(
            12, resample=Image.Resampling.BICUBIC, expand=True
        )
        canvas.alpha_composite(phone, (166, 68))
    else:
        draw_text_pair(
            draw,
            copy,
            y=82,
            gap=32,
            center=True,
            canvas_size=HARMONY_CANVAS_SIZE,
            title_size=112 if len(copy.title) <= 12 else 96,
            subtitle_size=56 if len(copy.subtitle) <= 24 else 48,
        )
        phone = make_phone(source, (650, 1445))
        x = (HARMONY_CANVAS_SIZE[0] - phone.width) // 2
        canvas.alpha_composite(phone, (x, 385))

    return canvas.convert("RGB")


def draw_harmony_hero_pair(copy: Copy) -> tuple[Image.Image, Image.Image]:
    pair_size = (HARMONY_CANVAS_SIZE[0] * 2, HARMONY_CANVAS_SIZE[1])
    canvas = Image.new("RGBA", pair_size, (255, 255, 255, 255))
    draw = ImageDraw.Draw(canvas)
    draw_triangle_pattern(draw, *pair_size)

    draw_text_pair(
        draw,
        copy,
        x=76,
        y=86,
        gap=26,
        center=False,
        canvas_size=pair_size,
        title_size=116 if len(copy.title) <= 12 else 100,
        subtitle_size=58 if len(copy.subtitle) <= 24 else 50,
    )

    left_phone = make_phone(SOURCE_DIR / SLIDES[0].source, (650, 1445)).rotate(
        30, resample=Image.Resampling.BICUBIC, expand=True
    )
    right_phone = make_phone(SOURCE_DIR / SLIDES[1].source, (800, 1780)).rotate(
        -20, resample=Image.Resampling.BICUBIC, expand=True
    )

    # The first two screenshots are sliced from this continuous canvas. Keep
    # both devices in one coordinate space so adjacent store cards align.
    canvas.alpha_composite(left_phone, (70, 455))
    canvas.alpha_composite(right_phone, (820, 80))

    left = canvas.crop((0, 0, HARMONY_CANVAS_SIZE[0], HARMONY_CANVAS_SIZE[1]))
    right = canvas.crop((HARMONY_CANVAS_SIZE[0], 0, pair_size[0], pair_size[1]))
    return left.convert("RGB"), right.convert("RGB")


def write_copy_markdown() -> None:
    lines = [
        "# Store Screenshot Copy",
        "",
        "Order is based on lexicographic filename sort from `app-store-assets/source-screenshots/`.",
        "Target store size: Apple App Store iPhone 6.9-inch portrait, `1320x2868`.",
        "Harmony/AGC target size: phone portrait, `1080x1920`, 9:16, 5 screenshots per locale.",
        "",
        "Store-ready files are under `app-store-assets/generated/apple-iphone-6.9/`.",
        "Harmony/AGC files are under `app-store-assets/generated/harmony-agc-phone/`.",
        "Preview contact sheets are under `app-store-assets/generated/previews/` and are not submission assets.",
        "Harmony/AGC `01.png` and `02.png` are cropped from one continuous `2160x1920` paired hero canvas.",
        "",
        "| # | Source | 中文主标题 | 中文副标题 | English Title | English Subtitle |",
        "|---|---|---|---|---|---|",
    ]
    for index, slide in enumerate(SLIDES, start=1):
        lines.append(
            f"| {index} | `{slide.source}` | {slide.zh.title} | {slide.zh.subtitle} | {slide.en.title} | {slide.en.subtitle} |"
        )
    (OUTPUT_DIR / "copy.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def make_contact_sheet(paths: list[Path], output: Path) -> None:
    thumb_w = 264
    thumb_h = 574
    padding = 26
    label_h = 48
    sheet_w = padding + len(paths) * (thumb_w + padding)
    sheet_h = thumb_h + label_h + padding * 2
    sheet = Image.new("RGB", (sheet_w, sheet_h), (246, 248, 252))
    draw = ImageDraw.Draw(sheet)
    label_font = load_font("subtitle", "01", 24)
    for index, path in enumerate(paths, start=1):
        image = Image.open(path).convert("RGB").resize((thumb_w, thumb_h), Image.LANCZOS)
        x = padding + (index - 1) * (thumb_w + padding)
        y = padding
        sheet.paste(image, (x, y))
        draw.text((x, y + thumb_h + 10), f"{index:02d}", font=label_font, fill=(38, 50, 64))
    sheet.save(output, quality=95)


def main() -> None:
    files = sorted(
        [path for path in SOURCE_DIR.iterdir() if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}],
        key=filename_key,
    )
    expected = [slide.source for slide in SLIDES]
    found = [path.name for path in files]
    if found != expected:
        raise SystemExit(f"Screenshot order mismatch.\nExpected: {expected}\nFound: {found}")

    generated: dict[str, list[Path]] = {}
    harmony_generated: dict[str, list[Path]] = {}
    for locale, copy_getter in LANGUAGES.items():
        locale_dir = STORE_DIR / locale
        locale_dir.mkdir(parents=True, exist_ok=True)
        generated[locale] = []
        for index, slide in enumerate(SLIDES, start=1):
            image = draw_slide(slide, copy_getter(slide), index)
            output = locale_dir / f"{index:02d}.png"
            image.save(output, optimize=True)
            generated[locale].append(output)

        harmony_locale_dir = HARMONY_DIR / locale
        harmony_locale_dir.mkdir(parents=True, exist_ok=True)
        harmony_generated[locale] = []
        hero_left, hero_right = draw_harmony_hero_pair(copy_getter(SLIDES[0]))
        hero_outputs = [hero_left, hero_right]
        for index, slide in enumerate(SLIDES[:5], start=1):
            image = hero_outputs[index - 1] if index <= 2 else draw_harmony_slide(slide, copy_getter(slide), index)
            output = harmony_locale_dir / f"{index:02d}.png"
            image.save(output, optimize=True)
            harmony_generated[locale].append(output)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    write_copy_markdown()
    for locale, paths in generated.items():
        make_contact_sheet(paths, PREVIEW_DIR / f"contact-sheet-phone-{locale}.jpg")
    for locale, paths in harmony_generated.items():
        make_contact_sheet(paths, PREVIEW_DIR / f"contact-sheet-harmony-agc-phone-{locale}.jpg")

    total = sum(len(paths) for paths in generated.values())
    harmony_total = sum(len(paths) for paths in harmony_generated.values())
    print(f"Generated {total} Apple phone screenshots and {harmony_total} Harmony phone screenshots in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
