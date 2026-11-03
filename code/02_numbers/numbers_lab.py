"""numbers_lab.py: play with the number formats hardware uses.
Run: python numbers_lab.py
Every function here mirrors a hand calculation in lesson 02. Change the inputs and re-run.
"""


def to_binary(n, bits):
    """Unsigned integer -> binary string, by repeated division by 2 (the hand method)."""
    digits = []
    for _ in range(bits):
        digits.append(str(n % 2))   # remainder = next bit, starting from the LSB
        n //= 2
    return "".join(reversed(digits))


def from_binary(s):
    """Binary string -> integer, by positional weights (sum of bit * 2^position)."""
    total = 0
    for position, bit in enumerate(reversed(s)):
        total += int(bit) * (2 ** position)
    return total


def twos_complement(value, bits):
    """Signed integer -> its bit pattern (as an unsigned number) in `bits` bits."""
    return value % (2 ** bits)          # the whole trick: arithmetic modulo 2^bits


def signed_value(pattern, bits):
    """Bit pattern -> signed value: the MSB has weight -2^(bits-1)."""
    msb = (pattern >> (bits - 1)) & 1
    return pattern - msb * (2 ** bits)


def to_fixed(x, frac_bits):
    """Real number -> fixed-point integer (round to nearest)."""
    return round(x * (2 ** frac_bits))


def from_fixed(i, frac_bits):
    return i / (2 ** frac_bits)


def decode_float32(bits32):
    """Split an IEEE-754 single into sign/exponent/mantissa and rebuild the value by hand."""
    sign = bits32 >> 31
    exponent = (bits32 >> 23) & 0xFF
    mantissa = bits32 & 0x7FFFFF
    if exponent == 0:
        value = (-1) ** sign * (mantissa / 2 ** 23) * 2 ** (-126)        # subnormal / zero
    elif exponent == 255:
        value = float("nan") if mantissa else (-1) ** sign * float("inf")
    else:
        value = (-1) ** sign * (1 + mantissa / 2 ** 23) * 2 ** (exponent - 127)
    return sign, exponent, mantissa, value


def float_to_bits(x):
    import struct
    return struct.unpack("<I", struct.pack("<f", x))[0]


if __name__ == "__main__":
    print("== Unsigned binary ==")
    for n in (5, 11, 200, 255):
        b = to_binary(n, 8)
        print(f"{n:4d} -> {b} -> back to {from_binary(b)}   hex 0x{n:02X}")

    print("\n== Two's complement (8 bits) ==")
    for v in (5, -5, 127, -128, -1):
        p = twos_complement(v, 8)
        print(f"{v:5d} -> pattern {to_binary(p, 8)} (0x{p:02X}) -> read back {signed_value(p, 8)}")

    print("\n== Overflow: 100 + 100 in 8-bit signed ==")
    s = (twos_complement(100, 8) + twos_complement(100, 8)) % 256
    print(f"pattern {to_binary(s, 8)} reads as {signed_value(s, 8)}  (the true answer 200 does not fit)")

    print("\n== Fixed point Q8.8 (8 fractional bits) ==")
    a, b = to_fixed(3.25, 8), to_fixed(-1.5, 8)
    print(f"3.25 -> {a} (0x{a:04X}),  -1.5 -> {b}")
    prod = a * b                                      # Q16.16 result: 16 fractional bits
    print(f"raw product {prod} has 16 fractional bits -> {from_fixed(prod, 16)}")
    print(f"shift right by 8 -> Q8.8 {prod >> 8} -> {from_fixed(prod >> 8, 8)}")

    print("\n== IEEE-754 float32 ==")
    for x in (1.0, -2.5, 0.1, 3.14159):
        bits = float_to_bits(x)
        s, e, m, v = decode_float32(bits)
        print(f"{x:>8} -> 0x{bits:08X}  sign={s} exp={e} (2^{e-127}) mant=0x{m:06X} -> {v!r}")
    print("Note 0.1 is not exact in binary: the stored value is the closest float.")
