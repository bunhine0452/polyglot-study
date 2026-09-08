#!/usr/bin/env python3
"""앱 아이콘을 그려 App/Resources/Polyglot.icns 를 만든다 — {#app-icon}.

왜 그림 파일이 아니라 스크립트인가:
  아이콘은 앱의 팔레트에서 파생된다. 색을 하나 바꾸면 10개 크기를 전부 다시 내보내야
  하는데, 손으로 하면 어느 하나가 뒤처진다. 여기서는 팔레트 상수 하나만 고치고 다시
  돌리면 된다. 생성물(.icns)도 함께 커밋한다 — 빌드가 Python·Pillow 에 의존하지 않는다.

무엇을 그리는가:
  먹 바탕에 트랙 세 줄. 각 줄은 진도만큼 채워져 있고, 맨 위 한 줄만 끝까지 차 있다.
  앱 화면이 실제로 보여주는 것(`7 / 24`, `12 / 22`, `1 / 24` — 서로 다른 진도로 나란히
  가는 독립 트랙)을 그대로 도형으로 옮긴 것이다.

왜 이 팔레트인가:
  앱은 의도적으로 준-모노크롬이다 — 먹·종이·회색 계조에 의미색 둘(통과 초록, 실패 빨강)
  뿐이다(`design/*.dc.html` 실측). 그래서 아이콘도 색을 늘리지 않는다. 완료된 줄 하나에만
  통과 초록을 쓴다. 바탕을 종이가 아니라 먹으로 뒤집은 이유는 Dock 과 Finder 의 밝은
  배경에서 종이색 아이콘이 사라지기 때문이다 — 팔레트는 그대로 두고 명도만 뒤집었다.

사용법:
    python3 App/Icon/make-icon.py          # .icns 갱신
    python3 App/Icon/make-icon.py --png    # 미리보기 PNG 도 함께 남긴다
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

# ── 팔레트 — design/*.dc.html 에서 실측한 값 ──────────────────────────────
INK = (0x14, 0x14, 0x14)  # 바탕. 앱 본문 글자색과 같은 먹.
PAPER = (0xF4, 0xF4, 0xF2)  # 채워진 진도. 앱 배경색.
RAIL = (0x33, 0x33, 0x31)  # 아직 안 한 부분. 먹에서 살짝 든 계조.
PASS = (0x2F, 0x8F, 0x4E)  # 완료 한 줄에만. 앱의 통과 색.
EDGE = (0x5F, 0x5F, 0x5C)  # 본체 실선. 앱의 헤어라인과 같은 회색.

# ── 기하 — 1024 기준. macOS 아이콘 격자는 1024 중 824 를 본체로 쓴다 ────────
CANVAS = 1024
BODY = 824  # 본체 한 변
BODY_RADIUS = 185  # 모서리 반지름 (824 의 22.4% — Big Sur 이후 규격)
SUPERSAMPLE = 4  # 이 배율로 그린 뒤 줄인다. 곡선 계단이 사라진다.

BAR_LEFT = 220
BAR_RIGHT = 804
BAR_HEIGHT = 150
BAR_GAP = 78
EDGE_WIDTH = 8  # 본체 실선 두께. 어두운 Dock 에서 윤곽이 죽지 않게 한다.
# 진도. 맨 위만 완료다 — 나머지는 진행 중인 트랙.
BAR_FILLS = (1.00, 0.62, 0.30)

# iconutil 이 요구하는 파일 이름과 픽셀 크기.
ICONSET = (
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
)


def draw_master() -> Image.Image:
    """1024 기준 좌표로 그린 뒤 되돌려준다. 안티에일리어싱은 축소로 얻는다."""
    s = SUPERSAMPLE
    img = Image.new("RGBA", (CANVAS * s, CANVAS * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def rect(x0, y0, x1, y1, radius, color):
        d.rounded_rectangle(
            (x0 * s, y0 * s, x1 * s, y1 * s), radius=radius * s, fill=color + (255,)
        )

    # 본체. 실선을 두르는 이유는 어두운 Dock 때문이다 — 먹 바탕만으로는 배경과
    # 붙어 형태가 사라진다. 앱이 곳곳에 쓰는 헤어라인과 같은 회색이라 팔레트도 안 늘린다.
    inset = (CANVAS - BODY) / 2
    rect(inset, inset, CANVAS - inset, CANVAS - inset, BODY_RADIUS, INK)
    d.rounded_rectangle(
        (inset * s, inset * s, (CANVAS - inset) * s, (CANVAS - inset) * s),
        radius=BODY_RADIUS * s, outline=EDGE + (255,), width=int(EDGE_WIDTH * s),
    )

    # 트랙 세 줄. 세로로 가운데 정렬한다.
    block = len(BAR_FILLS) * BAR_HEIGHT + (len(BAR_FILLS) - 1) * BAR_GAP
    y = (CANVAS - block) / 2
    radius = BAR_HEIGHT / 2
    span = BAR_RIGHT - BAR_LEFT

    for fill in BAR_FILLS:
        # 레일은 항상 끝까지 그린다 — 남은 분량이 보여야 "진도" 로 읽힌다.
        rect(BAR_LEFT, y, BAR_RIGHT, y + BAR_HEIGHT, radius, RAIL)

        filled = max(BAR_HEIGHT, span * fill)
        color = PASS if fill >= 1.0 else PAPER
        rect(BAR_LEFT, y, BAR_LEFT + filled, y + BAR_HEIGHT, radius, color)
        if fill < 1.0:
            # **채운 쪽 끝을 각지게 자른다.** 양끝이 둥근 알약이 레일 안에 놓이면
            # 그건 진도가 아니라 **토글 스위치**로 읽힌다(첫 시안에서 실측). 왼쪽만
            # 둥글고 오른쪽이 각지면 "여기까지 찼다" 로 읽힌다.
            d.rectangle(
                ((BAR_LEFT + filled - radius) * s, y * s,
                 (BAR_LEFT + filled) * s, (y + BAR_HEIGHT) * s),
                fill=color + (255,),
            )
        y += BAR_HEIGHT + BAR_GAP

    return img.resize((CANVAS, CANVAS), Image.LANCZOS)


def main() -> int:
    root = Path(__file__).resolve().parent.parent  # App/
    out_icns = root / "Resources" / "Polyglot.icns"

    if shutil.which("iconutil") is None:
        print("iconutil 이 없다 — macOS 에서 돌려라.", file=sys.stderr)
        return 1

    master = draw_master()

    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "Polyglot.iconset"
        iconset.mkdir()
        for name, size in ICONSET:
            master.resize((size, size), Image.LANCZOS).save(iconset / name)

        out_icns.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(out_icns)], check=True
        )

    print(f"==> {out_icns.relative_to(root.parent)}  ({out_icns.stat().st_size:,} 바이트)")

    if "--png" in sys.argv:
        preview = Path(__file__).parent / "preview"
        preview.mkdir(exist_ok=True)
        for size in (16, 32, 128, 512, 1024):
            master.resize((size, size), Image.LANCZOS).save(preview / f"icon-{size}.png")
        print(f"==> 미리보기 PNG 5종: {preview.relative_to(root.parent)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
