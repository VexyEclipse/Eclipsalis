"""Generate UI/Icons.lua: Lucide icons flattened to stroke geometry the UI draws with Frames.

Lucide (https://lucide.dev) is ISC licensed. Run: python tools/lucide_icons.py
"""
from pathlib import Path
import math
import re
import urllib.request

VERSION = "0.460.0"
NAMES = ["house", "eye", "zap", "settings", "user", "map-pin", "swords", "info", "ellipsis",
         "layout-grid", "search", "panel-left", "panel-left-close", "panel-left-open", "keyboard"]
TOLERANCE = 0.2  # in 24-unit icon space


def fetch(name):
    url = f"https://unpkg.com/lucide-static@{VERSION}/icons/{name}.svg"
    with urllib.request.urlopen(url) as response:
        return response.read().decode("utf-8")


def tokens(d):
    return re.findall(r"[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?", d)


def cubic(p0, p1, p2, p3, steps=12):
    return [tuple((1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t * t * c + t ** 3 * e
                  for a, b, c, e in zip(p0, p1, p2, p3)) for t in (i / steps for i in range(1, steps + 1))]


def quad(p0, p1, p2, steps=10):
    return [tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * c for a, b, c in zip(p0, p1, p2))
            for t in (i / steps for i in range(1, steps + 1))]


def arc(p0, rx, ry, angle, large, sweep, p1):
    # SVG endpoint parameterisation to centre form (SVG 1.1 implementation notes, F.6.5).
    if p0 == p1:
        return []
    if rx == 0 or ry == 0:
        return [p1]
    phi = math.radians(angle)
    cos, sin = math.cos(phi), math.sin(phi)
    dx, dy = (p0[0] - p1[0]) / 2, (p0[1] - p1[1]) / 2
    x1, y1 = cos * dx + sin * dy, -sin * dx + cos * dy
    rx, ry = abs(rx), abs(ry)
    scale = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
    if scale > 1:
        rx, ry = rx * math.sqrt(scale), ry * math.sqrt(scale)
    num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    den = rx * rx * y1 * y1 + ry * ry * x1 * x1
    factor = math.sqrt(max(0, num / den)) * (-1 if large == sweep else 1)
    cx1, cy1 = factor * rx * y1 / ry, -factor * ry * x1 / rx
    cx = cos * cx1 - sin * cy1 + (p0[0] + p1[0]) / 2
    cy = sin * cx1 + cos * cy1 + (p0[1] + p1[1]) / 2
    start = math.atan2((y1 - cy1) / ry, (x1 - cx1) / rx)
    delta = math.atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx) - start
    if sweep and delta < 0:
        delta += 2 * math.pi
    elif not sweep and delta > 0:
        delta -= 2 * math.pi
    steps = max(2, int(abs(delta) * max(rx, ry) / 0.6) + 1)
    points = []
    for i in range(1, steps + 1):
        t = start + delta * i / steps
        x, y = rx * math.cos(t), ry * math.sin(t)
        points.append((cos * x - sin * y + cx, sin * x + cos * y + cy))
    return points


def path(d):
    items, polylines, current = tokens(d), [], []
    index, command = 0, None
    pos = start = (0.0, 0.0)
    last_control = None

    def number():
        nonlocal index
        value = float(items[index])
        index += 1
        return value

    while index < len(items):
        if re.match(r"[A-Za-z]", items[index]):
            command = items[index]
            index += 1
        relative = command.islower()
        op = command.upper()
        base = pos if relative else (0.0, 0.0)
        if op == "M":
            if len(current) > 1:
                polylines.append(current)
            pos = (base[0] + number(), base[1] + number())
            start, current, last_control = pos, [pos], None
            command = "l" if relative else "L"
        elif op == "L":
            pos = (base[0] + number(), base[1] + number())
            current.append(pos)
            last_control = None
        elif op == "H":
            pos = ((pos[0] if relative else 0) + number(), pos[1])
            current.append(pos)
            last_control = None
        elif op == "V":
            pos = (pos[0], (pos[1] if relative else 0) + number())
            current.append(pos)
            last_control = None
        elif op == "C":
            c1 = (base[0] + number(), base[1] + number())
            c2 = (base[0] + number(), base[1] + number())
            end = (base[0] + number(), base[1] + number())
            current += cubic(pos, c1, c2, end)
            pos, last_control = end, c2
        elif op == "S":
            c1 = (2 * pos[0] - last_control[0], 2 * pos[1] - last_control[1]) if last_control else pos
            c2 = (base[0] + number(), base[1] + number())
            end = (base[0] + number(), base[1] + number())
            current += cubic(pos, c1, c2, end)
            pos, last_control = end, c2
        elif op == "Q":
            c = (base[0] + number(), base[1] + number())
            end = (base[0] + number(), base[1] + number())
            current += quad(pos, c, end)
            pos, last_control = end, None
        elif op == "A":
            rx, ry, angle, large, sweep = number(), number(), number(), number(), number()
            end = (base[0] + number(), base[1] + number())
            current += arc(pos, rx, ry, angle, int(large), int(sweep), end)
            pos, last_control = end, None
        elif op == "Z":
            current.append(start)
            pos = start
            polylines.append(current)
            current, last_control = [pos], None
        else:
            raise ValueError(f"Unsupported path command {command}")
    if len(current) > 1:
        polylines.append(current)
    return polylines


def simplify(points, tolerance=TOLERANCE):
    if len(points) < 3:
        return points
    (ax, ay), (bx, by) = points[0], points[-1]
    length = math.hypot(bx - ax, by - ay)
    best, best_index = 0, 0
    for i, (px, py) in enumerate(points[1:-1], 1):
        distance = (abs((bx - ax) * (ay - py) - (ax - px) * (by - ay)) / length if length
                    else math.hypot(px - ax, py - ay))
        if distance > best:
            best, best_index = distance, i
    if best <= tolerance:
        return [points[0], points[-1]]
    return simplify(points[:best_index + 1], tolerance)[:-1] + simplify(points[best_index:], tolerance)


def attrs(tag):
    return dict(re.findall(r'([\w-]+)="([^"]*)"', tag))


def convert(svg):
    shapes = []
    for kind, raw in re.findall(r"<(path|circle|rect|line|polyline|ellipse)\b([^>]*)/?>", svg):
        a = attrs(raw)
        if kind == "path":
            for line in path(a["d"]):
                shapes.append(("line", simplify(line)))
        elif kind == "circle":
            shapes.append(("circle", float(a["cx"]), float(a["cy"]), float(a["r"])))
        elif kind == "rect":
            shapes.append(("rect", float(a.get("x", 0)), float(a.get("y", 0)), float(a["width"]),
                           float(a["height"]), float(a.get("rx", 0))))
        elif kind == "line":
            shapes.append(("line", [(float(a["x1"]), float(a["y1"])), (float(a["x2"]), float(a["y2"]))]))
        elif kind == "polyline":
            values = [float(v) for v in re.findall(r"-?[\d.]+", a["points"])]
            shapes.append(("line", list(zip(values[::2], values[1::2]))))
        else:
            raise ValueError(f"Unsupported element {kind}")
    return shapes


def lua(value):
    return f"{value / 24:.4f}".rstrip("0").rstrip(".") or "0"


def main():
    root = Path(__file__).resolve().parent.parent
    lines = [f"-- Lucide icons v{VERSION} (https://lucide.dev, ISC License, Copyright (c) Lucide Contributors).",
             "-- Generated by tools/lucide_icons.py: strokes flattened to polylines in 0-1 icon space.",
             "return function(Library, ctx)", "    ctx.lucide = {"]
    total = 0
    for name in NAMES:
        parts = []
        for shape in convert(fetch(name)):
            if shape[0] == "line":
                total += len(shape[1]) - 1
                parts.append("{" + ",".join(lua(c) for point in shape[1] for c in point) + "}")
            elif shape[0] == "circle":
                parts.append(f"{{circle={{{lua(shape[1])},{lua(shape[2])},{lua(shape[3])}}}}}")
            else:
                parts.append(f"{{rect={{{','.join(lua(v) for v in shape[1:])}}}}}")
        lines.append(f'        ["{name}"] = {{{", ".join(parts)}}},')
    lines += ["    }", "end", ""]
    (root / "UI" / "Icons.lua").write_text("\n".join(lines), encoding="utf-8")
    print(f"{len(NAMES)} icons, {total} segments")


if __name__ == "__main__":
    main()
