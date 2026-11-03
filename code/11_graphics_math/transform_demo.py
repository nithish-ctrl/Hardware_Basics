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
