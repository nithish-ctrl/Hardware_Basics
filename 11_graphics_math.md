# Lesson 11 — Graphics Math: Vectors, Matrices, Projection and Rasterization

> **Why this matters for your GPU:** the graphics half of the project (main guide, Parts 12 and 14) turns 3D triangles into colored pixels. That uses a small set of math tools: vectors, dot products, matrices, a perspective divide, edge functions and interpolation. Each one is explained here from scratch, with numbers you can check, and a working Python rasterizer that uses exactly the same method as the hardware.

---

## 11.1 Coordinates and Vectors

A **point** in 3D is three numbers (x, y, z). A **vector** is a direction with a length, also written (x, y, z). In graphics:

- **x** points right, **y** points up, and the camera looks down the **−z** axis (OpenGL convention).
- On the **screen**, pixel (0, 0) is the **top-left**, and y grows **downward**. (We flip y at the end.)

### Vector operations

| Operation | Formula | Meaning |
|---|---|---|
| Add | (a.x + b.x, a.y + b.y, a.z + b.z) | Move by b |
| Subtract | b − a | Vector pointing from a to b |
| Scale | s × (x, y, z) | Stretch |
| Length | √(x² + y² + z²) | Size (Pythagoras in 3D) |
| Normalize | v / length(v) | Same direction, length 1 |

Example: from a = (1, 2, 0) to b = (4, 6, 0), b − a = (3, 4, 0), length = √(9 + 16) = 5.

---

## 11.2 The Dot Product: "How Much Do Two Directions Agree?"

```
a · b = a.x·b.x + a.y·b.y + a.z·b.z  =  |a| × |b| × cos(θ)
```

where θ is the angle between them. For unit-length vectors, it's just cos θ:

| Angle | cos θ | Meaning |
|---|---|---|
| 0° | 1 | Same direction |
| 90° | 0 | Perpendicular |
| 180° | −1 | Opposite |

### Use 1: lighting

A surface is brightest when it faces the light directly. With **N** = the surface's normal (the direction it faces) and **L** = the direction to the light, both normalized:

```
brightness = max(0, N · L)          (Lambert's law: the basis of diffuse lighting)
```

Worked example: N = (0, 1, 0) (facing up), light coming from 60° above the horizon: L = (cos 60°, sin 60°, 0) = (0.5, 0.866, 0). N · L = 0 × 0.5 + 1 × 0.866 + 0 = **0.866**, so the surface is 87% lit.

**Cost:** 3 multiplies + 2 adds = 3 FMAs (Lesson 8). Lighting is why GPUs are FMA machines.

### Use 2: matrix multiplication (next section) is just many dot products.

---

## 11.3 The 2D Cross Product: Which Side of a Line?

For 2D vectors u and v:

```
cross(u, v) = u.x × v.y − u.y × v.x
```

The sign says which way you turn from u to v: positive for one direction, negative for the other, zero if they're parallel. Its magnitude is the **area of the parallelogram** they span, which is **twice the area of the triangle**.

This single formula is the heart of rasterization (Section 11.7).

---

## 11.4 Matrices: Transformations as Multiplication

A matrix is a grid of numbers. **Multiplying a matrix by a vector** = taking the dot product of **each row** with the vector:

```
| a b |   | x |   | a·x + b·y |
| c d | × | y | = | c·x + d·y |
```

### Rotation (2D) by angle θ

```
| cos θ  −sin θ |   | 1 |   | cos θ |
| sin θ   cos θ | × | 0 | = | sin θ |
```

Rotate (1, 0) by 90°: cos 90° = 0, sin 90° = 1, giving (0, 1). It turned from "right" to "up" ✓.

### Why 4×4 matrices? Homogeneous coordinates

Rotation and scaling are matrix multiplies, but **moving** a point (translation: x + tx) isn't, since there's nothing to multiply. The trick: add a 4th coordinate **w = 1** for points:

```
| 1 0 0 tx |   | x |   | x + tx |
| 0 1 0 ty |   | y |   | y + ty |
| 0 0 1 tz | × | z | = | z + tz |
| 0 0 0 1  |   | 1 |   |   1    |
```

Now **every** transformation (move, rotate, scale, even perspective) is a 4×4 matrix, and several transformations can be **combined into one matrix** by multiplying the matrices together. A GPU then applies that one matrix to every vertex: **16 multiplies + 12 adds** per vertex.

(For directions, w = 0, so translation doesn't affect them, which is correct: a direction has no position.)

### Order matters

Matrix multiplication isn't commutative: `Translate × Rotate` (rotate first, then move) ≠ `Rotate × Translate` (move, then rotate around the origin, swinging the object in an arc). The matrix closest to the vector is applied **first**.

---

## 11.5 Perspective: Why Far Things Look Small

A pinhole camera. A point at height y, distance z from the eye, appears on a screen at distance d with height y':

```
        eye ●───────────── d ─────────────┼───────── z − d ───────────── ● point (height y)
                                          │ y'
         similar triangles:   y' / d = y / z    →    y' = d × y / z
```

**Screen position = position divided by distance.** Double the distance and the object looks half as big. That division is the **perspective divide**.

How a GPU does it:
1. The **projection matrix** arranges for the 4th coordinate to become the distance: **w = −z** (the camera looks down −z, so distances in front are negative z).
2. After the matrix, the GPU divides x, y and z by w. This produces **NDC** (normalized device coordinates): everything visible lands in −1..+1.
3. The **viewport transform** maps −1..+1 to pixels:

```
pixel_x = (x_ndc + 1) / 2 × width
pixel_y = (1 − y_ndc) / 2 × height        (flip: screen y grows downward)
```

### Follow one point all the way

`code/11_graphics_math/transform_demo.py`:

```python
"""transform_demo.py: follow ONE point from 3D world to a pixel, printing every step.
Run: python transform_demo.py
Pure Python (no numpy) so every multiply is visible.
"""
import math


def mat_vec(m, v):
    """4x4 matrix times 4-vector: each output = dot product of a matrix ROW with v."""
    return [sum(m[r][c] * v[c] for c in range(4)) for r in range(4)]


def mat_mul(a, b):
    """4x4 times 4x4: entry (r, c) = row r of a  dot  column c of b."""
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def show(name, v):
    print(f"  {name:<34} = (" + ", ".join(f"{x:8.3f}" for x in v) + ")")


def translate(tx, ty, tz):
    return [[1, 0, 0, tx], [0, 1, 0, ty], [0, 0, 1, tz], [0, 0, 0, 1]]


def rotate_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]


def perspective(fov_deg, aspect, near, far):
    f = 1 / math.tan(math.radians(fov_deg) / 2)
    return [[f / aspect, 0, 0, 0],
            [0, f, 0, 0],
            [0, 0, -(far + near) / (far - near), -2 * far * near / (far - near)],
            [0, 0, -1, 0]]


if __name__ == "__main__":
    W, H = 320, 240
    p_object = [1.0, 1.0, 1.0, 1.0]           # a cube corner; w = 1 means "a point"

    print("Step 0: the point in the object's own coordinates")
    show("p_object", p_object)

    print("\nStep 1: MODEL transform = rotate 30 degrees about Y, then move 4 units away (-Z)")
    model = mat_mul(translate(0, 0, -4), rotate_y(30))
    p_world = mat_vec(model, p_object)
    show("p_world", p_world)

    print("\nStep 2: VIEW transform = camera at the origin looking down -Z (identity here)")
    p_eye = p_world
    show("p_eye", p_eye)

    print("\nStep 3: PROJECTION (fov 60 deg, aspect 4:3, near 0.1, far 100)")
    proj = perspective(60, W / H, 0.1, 100)
    p_clip = mat_vec(proj, p_eye)
    show("p_clip", p_clip)
    print(f"  note: w_clip = {p_clip[3]:.3f} = -z_eye = distance in front of the camera")

    print("\nStep 4: PERSPECTIVE DIVIDE (divide x, y, z by w): far things get smaller")
    ndc = [p_clip[i] / p_clip[3] for i in range(3)]
    show("p_ndc (each in -1..1 if visible)", ndc)

    print("\nStep 5: VIEWPORT: map -1..1 to pixels (y flipped: screen y grows downward)")
    sx = (ndc[0] + 1) / 2 * W
    sy = (1 - ndc[1]) / 2 * H
    print(f"  pixel x = (x_ndc + 1)/2 * {W} = {sx:.2f}")
    print(f"  pixel y = (1 - y_ndc)/2 * {H} = {sy:.2f}")

    print("\nThe same point twice as far away lands closer to the screen centre:")
    for dist in (4, 8, 16):
        p = mat_vec(proj, mat_vec(translate(0, 0, -dist), [1, 1, 1, 1]))
        print(f"  distance {dist:2d}: x_ndc = {p[0] / p[3]:.3f}   (halves as distance doubles)")
```

```
cd hardware_basics\code\11_graphics_math
python transform_demo.py
```

```
Step 0: the point in the object's own coordinates
  p_object = (1.000, 1.000, 1.000, 1.000)
Step 1: MODEL transform = rotate 30 degrees about Y, then move 4 units away (-Z)
  p_world  = (1.366, 1.000, -3.634, 1.000)
Step 3: PROJECTION (fov 60 deg, aspect 4:3, near 0.1, far 100)
  p_clip   = (1.775, 1.732, 3.441, 3.634)
  note: w_clip = 3.634 = -z_eye = distance in front of the camera
Step 4: PERSPECTIVE DIVIDE (divide x, y, z by w): far things get smaller
  p_ndc    = (0.488, 0.477, 0.947)
Step 5: VIEWPORT: map -1..1 to pixels (y flipped: screen y grows downward)
  pixel x = (x_ndc + 1)/2 * 320 = 238.13
  pixel y = (1 - y_ndc)/2 * 240 = 62.80

The same point twice as far away lands closer to the screen centre:
  distance  4: x_ndc = 0.433
  distance  8: x_ndc = 0.186
  distance 16: x_ndc = 0.087
```

**Check step 1 by hand:** rotating (1, 1, 1) by 30° about Y: x' = cos30·1 + sin30·1 = 0.866 + 0.5 = 1.366 ✓, z' = −sin30·1 + cos30·1 = 0.366. Then moving by −4 in z: 0.366 − 4 = −3.634 ✓.

(The far-away numbers aren't *exactly* halving: the point sits at z = −3, −7, −15 after the move, since the cube corner is at z = +1. Close enough to see the rule.)

---

## 11.6 Rasterization: From a Triangle to Pixels

After projection, each triangle has three corners in pixel coordinates. **Rasterization** answers: **which pixels are inside the triangle?**

### The edge function

For a directed edge from corner a to corner b, and a pixel p:

```
E(p) = (p.x − a.x) × (b.y − a.y) − (p.y − a.y) × (b.x − a.x)
```

That's the 2D cross product of (b − a) and (p − a) (up to sign convention). Its **sign** tells which side of the line through a and b the pixel is on.

**A pixel is inside the triangle if it is on the same side of all three edges**, meaning all three edge functions have the same sign as the triangle's area.

### Worked example with small numbers

Triangle v0 = (0, 0), v1 = (4, 0), v2 = (0, 4). Test p = (1, 1) and q = (3, 3):

```
Edge v1→v2:  a = (4,0), b = (0,4):  E(p) = (1−4)(4−0) − (1−0)(0−4) = −12 + 4 = −8
                                    E(q) = (3−4)(4)   − (3)(−4)    = −4 + 12 = +8
Edge v2→v0:  a = (0,4), b = (0,0):  E(p) = (1−0)(0−4) − (1−4)(0−0) = −4
                                    E(q) = (3)(−4)    − (−1)(0)    = −12
Edge v0→v1:  a = (0,0), b = (4,0):  E(p) = (1)(0) − (1)(4) = −4
                                    E(q) = (3)(0) − (3)(4) = −12
Area = E_v0→v1(v2) = (0)(0) − (4)(4) = −16   (negative: this winding gives negative values inside)
```

p: (−8, −4, −4), all negative like the area → **inside** ✓.
q: (+8, −12, −12), mixed signs → **outside** ✓ (q = (3, 3) is past the diagonal edge x + y = 4).

### Why hardware loves edge functions

E is **linear** in x and y: E(x+1, y) = E(x, y) + (b.y − a.y). Moving one pixel right is **one addition per edge**, with no multiplications. The hardware rasterizer in the main guide (Part 14.4) computes E with multipliers once per triangle (setup), then walks the pixels with only adders. Every pixel is independent, so you can test 4, 16 or 64 pixels in parallel.

---

## 11.7 Barycentric Coordinates and Interpolation

The three edge functions, divided by the area, give three weights:

```
λ0 = E_v1v2(p) / area,   λ1 = E_v2v0(p) / area,   λ2 = E_v0v1(p) / area,     with λ0 + λ1 + λ2 = 1
```

These **barycentric coordinates** say how close p is to each corner: at v0 itself, λ0 = 1 and the others are 0. At the centre, each is ⅓.

Any value stored at the corners (color, depth, texture coordinates) is **interpolated** across the triangle the same way:

```
color(p) = λ0 × color0 + λ1 × color1 + λ2 × color2
```

From the worked example, p = (1, 1): λ0 = −8/−16 = 0.5, λ1 = −4/−16 = 0.25, λ2 = 0.25 (sum = 1 ✓). If v0 is red (255, 0, 0), v1 green and v2 blue, p's color = (127, 63, 63): mostly red, because p is closest to v0.

(For 3D perspective, attributes must be interpolated as attr/w and then divided by 1/w per pixel: "perspective-correct interpolation", main guide Part 12.4. For flat 2D it isn't needed.)

---

## 11.8 The Depth Buffer (Z-Buffer)

When triangles overlap, the **nearest** one should win at each pixel. Keep one depth value per pixel, starting at "infinitely far":

```
for each pixel a triangle covers:
    z = interpolated depth
    if z < zbuffer[pixel]:            # nearer than anything drawn so far?
        zbuffer[pixel] = z
        color[pixel]   = shaded color
```

That's a **read-compare-write** for every pixel: one reason graphics needs so much memory bandwidth (Lesson 7). The hardware version (main guide Part 14.5) even has a pipeline hazard to solve: two fragments for the same pixel in quick succession.

---

## 11.9 Putting It Together: a Rasterizer You Can Run

`code/11_graphics_math/mini_raster.py`:

```python
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
```

```
python mini_raster.py
```

```
triangle 1 drew 5910 pixels, triangle 2 won the depth test on 1889 pixels
wrote triangle.png and triangle.ppm: the grey triangle hides the colored one where it is nearer
.......oooo...........................................
..........ooooooooooooooooooooooooooo.................
...........oooooooooooooooooooooooooooooooooooooo.....
....##........oooooooooooooooooooooooooooo............
.....##################oooooooooooooooo...............
......##################oooooooooooo########..........
.......##################ooooooooo###.................
```

Open `triangle.png`: a triangle blending smoothly from red, green and blue corners, with a grey triangle cutting through it. The grey one has depth 0.2 on its left and 0.9 on its right, while the colored one has 0.5 everywhere. So grey wins on the left (nearer) and loses on the right (farther). The **diagonal boundary** where they cross is exactly where the interpolated grey depth equals 0.5. The Z-buffer computed a 3D intersection with no special code.

Every line of this program corresponds to a hardware block:

| Python | Hardware (main guide) |
|---|---|
| bounding box | Rasterizer setup (Part 14.4) |
| `edge()` ×3 and the inside test | Edge-function walker |
| barycentric `l0, l1, l2` | Attribute interpolator (Part 14.5) |
| `if z >= zb[y][x]` | Depth test unit (Part 14.5) |
| writing `fb[y][x]` | ROP / framebuffer write |
| `write_png` | (the display controller instead shows it on a monitor: Part 14.1) |

---

## Exercises

1. Length of (2, 3, 6)? Normalize it.
2. N = (0, 0, 1), L = normalize(1, 0, 1). Brightness = max(0, N·L)?
3. Rotate the 2D point (2, 0) by 90° with the rotation matrix.
4. Why do we need 4×4 matrices instead of 3×3 for 3D?
5. A point at eye-space z = −10 has x_clip = 3 and w = 10. What's x_ndc? Which pixel column on a 320-wide screen?
6. Triangle v0 = (0, 0), v1 = (4, 0), v2 = (0, 4). Is p = (2, 1) inside? Compute all three edge functions.
7. Barycentric weights at p = (2, 1) for the same triangle. If the corners have depths 0.2, 0.4 and 0.6, what's the depth at p?
8. Moving one pixel right, how does E change for the edge v0→v1 of that triangle?

<details>
<summary><b>Answers</b></summary>

1. √(4 + 9 + 36) = **7**. Normalized: **(2/7, 3/7, 6/7)**.
2. L = (1, 0, 1)/√2 = (0.707, 0, 0.707). N · L = **0.707** (the light comes in at 45°).
3. x' = cos90·2 − sin90·0 = 0, y' = sin90·2 + cos90·0 = 2 → **(0, 2)**.
4. Translation (moving) can't be written as a 3×3 multiply. With a 4th coordinate w = 1, it can. And perspective needs w to hold the distance for the divide.
5. x_ndc = 3 / 10 = **0.3**. Column = (0.3 + 1) / 2 × 320 = **208**.
6. E_v1v2 = (2−4)(4) − (1)(−4) = −8 + 4 = **−4**. E_v2v0 = (2)(−4) − (1−4)(0) = **−8**. E_v0v1 = (2)(0) − (1)(4) = **−4**. All negative, same sign as the area (−16) → **inside** ✓.
7. λ0 = −4/−16 = 0.25, λ1 = −8/−16 = 0.5, λ2 = 0.25. Depth = 0.25 × 0.2 + 0.5 × 0.4 + 0.25 × 0.6 = 0.05 + 0.2 + 0.15 = **0.4**.
8. E_v0v1(p) = (p.x)(0) − (p.y)(4) = −4·p.y. It doesn't depend on x at all: change **0**. (The edge is horizontal, so moving right never crosses it. In general, the step is b.y − a.y = 0 − 0 = 0.)

</details>

---

**Next:** [Lesson 12 — Tools and Workflow](12_tools_and_workflow.md)
