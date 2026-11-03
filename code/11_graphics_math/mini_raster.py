"""mini_raster.py: a tiny software rasterizer using exactly the hardware's method.
Run: python mini_raster.py      -> writes triangle.png (open it in any image viewer) and triangle.ppm
Shows: bounding box, edge functions, the inside test, barycentric color interpolation, a Z-buffer.
"""
import struct
import zlib

W, H = 160, 120


def write_png(path, fb):
    """Minimal PNG writer (standard library only): header chunk, compressed pixel rows, end chunk."""
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    raw = b"".join(bytes([0]) + bytes(c for px in row for c in px) for row in fb)  # filter byte 0 per row
    with open(path, "wb") as f:
        f.write(bytes([0x89]) + b"PNG" + bytes([0x0D, 0x0A, 0x1A, 0x0A]))      # PNG signature
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", len(fb[0]), len(fb), 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw)))
        f.write(chunk(b"IEND", b""))


def edge(ax, ay, bx, by, px, py):
    """Positive on one side of the line a->b, negative on the other, zero on it."""
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax)


def draw_triangle(fb, zb, v0, v1, v2):
    """Each vertex: (x, y, z, (r, g, b)). Colors are blended with barycentric weights."""
    (x0, y0, z0, c0), (x1, y1, z1, c1), (x2, y2, z2, c2) = v0, v1, v2
    area = edge(x0, y0, x1, y1, x2, y2)
    if area == 0:
        return 0
    minx, maxx = max(min(x0, x1, x2), 0), min(max(x0, x1, x2), W - 1)
    miny, maxy = max(min(y0, y1, y2), 0), min(max(y0, y1, y2), H - 1)
    drawn = 0
    for y in range(int(miny), int(maxy) + 1):
        for x in range(int(minx), int(maxx) + 1):
            px, py = x + 0.5, y + 0.5                     # sample the pixel centre
            w0 = edge(x1, y1, x2, y2, px, py)             # weight of v0 (opposite edge)
            w1 = edge(x2, y2, x0, y0, px, py)             # weight of v1
            w2 = edge(x0, y0, x1, y1, px, py)             # weight of v2
            inside = (w0 >= 0 and w1 >= 0 and w2 >= 0) if area > 0 else \
                     (w0 <= 0 and w1 <= 0 and w2 <= 0)
            if not inside:
                continue
            l0, l1, l2 = w0 / area, w1 / area, w2 / area  # barycentric: they sum to 1
            z = l0 * z0 + l1 * z1 + l2 * z2
            if z >= zb[y][x]:                             # depth test: keep the nearest
                continue
            zb[y][x] = z
            fb[y][x] = tuple(int(l0 * c0[i] + l1 * c1[i] + l2 * c2[i]) for i in range(3))
            drawn += 1
    return drawn


if __name__ == "__main__":
    fb = [[(20, 20, 30)] * W for _ in range(H)]           # background color
    zb = [[float("inf")] * W for _ in range(H)]           # depth: start "infinitely far"

    # A colorful triangle (red, green, blue corners) ...
    n1 = draw_triangle(fb, zb, (20, 10, 0.5, (255, 0, 0)), (150, 40, 0.5, (0, 255, 0)),
                       (60, 110, 0.5, (0, 0, 255)))
    # ... and a grey one that pokes through it: nearer at the left, farther at the right
    n2 = draw_triangle(fb, zb, (10, 60, 0.2, (230, 230, 230)), (140, 70, 0.9, (230, 230, 230)),
                       (30, 100, 0.2, (230, 230, 230)))
    with open("triangle.ppm", "wb") as f:                  # PPM: a header + raw RGB bytes
        f.write(f"P6 {W} {H} 255\n".encode())
        for row in fb:
            for r, g, b in row:
                f.write(bytes((r, g, b)))
    print(f"triangle 1 drew {n1} pixels, triangle 2 won the depth test on {n2} pixels")
    write_png("triangle.png", fb)
    print("wrote triangle.png and triangle.ppm: the grey triangle hides the colored one where it is nearer")

    # ASCII preview so you can see it without an image viewer
    for y in range(0, H, 6):
        row = ""
        for x in range(0, W, 3):
            r, g, b = fb[y][x]
            row += "." if (r, g, b) == (20, 20, 30) else ("#" if r == g == b else "o")
        print(row)
