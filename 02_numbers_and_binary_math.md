# Lesson 2 — Numbers and Binary Math

> **Why this matters for your GPU:** every wire in your GPU carries bits. Addresses, colors, instructions, coordinates and thread IDs are all just patterns of bits. To read the RTL and the instruction encodings, you must be fluent in binary, hex, two's complement, fixed point and floating point. This lesson builds that fluency from zero.

---

## 2.1 Positional Number Systems

In decimal, the digits of `472` mean:

```
4 × 100  +  7 × 10  +  2 × 1   =   4×10²  +  7×10¹  +  2×10⁰
```

Each position is worth **10 times** the one to its right. Nothing is special about 10: in **binary (base 2)** each position is worth **2 times** the one to its right, and the only digits are 0 and 1.

```
Binary 1011  =  1×2³ + 0×2² + 1×2¹ + 1×2⁰  =  8 + 0 + 2 + 1  =  11
```

**Learn these powers of 2 by heart.** You'll use them constantly:

| 2⁰ | 2¹ | 2² | 2³ | 2⁴ | 2⁵ | 2⁶ | 2⁷ | 2⁸ | 2⁹ | 2¹⁰ | 2¹⁶ | 2²⁰ | 2³² |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 | 256 | 512 | 1024 (≈1K) | 65,536 | ≈1M | ≈4.29 billion |

Words you'll meet: a **bit** is one binary digit, a **byte** is 8 bits, a **nibble** is 4 bits, and a **word** is the natural size of a machine (32 bits in your GPU).

### Converting decimal → binary (repeated division by 2)

Convert 200: divide by 2 repeatedly and record the remainders. The remainders, read **bottom to top**, are the bits.

```
200 ÷ 2 = 100 r 0   ← bit 0 (least significant bit, LSB)
100 ÷ 2 =  50 r 0
 50 ÷ 2 =  25 r 0
 25 ÷ 2 =  12 r 1
 12 ÷ 2 =   6 r 0
  6 ÷ 2 =   3 r 0
  3 ÷ 2 =   1 r 1
  1 ÷ 2 =   0 r 1   ← bit 7 (most significant bit, MSB)

200 = 1100 1000₂
```

Check: 128 + 64 + 8 = 200 ✓.

**Faster method for small numbers:** subtract the biggest power of 2 that fits. 200 − 128 = 72, 72 − 64 = 8, 8 − 8 = 0. So bits 7, 6 and 3 are set: `1100_1000`.

### Hexadecimal (base 16): binary's shorthand

Binary is long, so we group **4 bits = 1 hex digit** (0–9, then A=10, B=11, C=12, D=13, E=14, F=15).

| Binary | 0000 | 0001 | ... | 1001 | 1010 | 1011 | 1100 | 1101 | 1110 | 1111 |
|---|---|---|---|---|---|---|---|---|---|---|
| Hex | 0 | 1 | ... | 9 | A | B | C | D | E | F |

```
1100 1000₂   →   C 8   →   0xC8   (= 12×16 + 8 = 200)
```

Hex→binary is the reverse: replace each hex digit with its 4 bits. `0xA04` → `1010 0000 0100`. This is how you'll read instruction encodings like `0xA0400000` in Lesson 9.

In Verilog you write sized literals: `8'd200`, `8'hC8`, `8'b1100_1000` (all the same value; underscores are ignored and only help readability).

### How many bits do I need?

To represent N different values you need `⌈log₂ N⌉` bits (log₂ rounded **up**). Verilog's `$clog2(N)` computes exactly this.

| Values needed | Bits | Example in this project |
|---|---|---|
| 2 | 1 | a flag |
| 4 warps | 2 | warp ID |
| 16 registers | 4 | register field in an instruction |
| 640 pixels across | 10 (2¹⁰ = 1024 ≥ 640) | x coordinate |
| 76,800 framebuffer pixels | 17 (2¹⁷ = 131,072) | framebuffer address |
| 4096 memory words | 12 | memory address |

**Memory sizes:** `AW` address bits give `2^AW` locations. Total bits = `2^AW × data width`. A 12-bit address with 32-bit words: 4096 × 32 = 131,072 bits = 16 KB.

---

## 2.2 Unsigned Numbers and Their Limits

With N bits, unsigned numbers go from 0 to 2ᴺ − 1. 8 bits gives 0..255.

**What happens at the top?** 255 + 1 in 8 bits:

```
  1111 1111
+ 0000 0001
-----------
1 0000 0000     ← the 9th bit (the carry) doesn't fit in 8 bits, so it's lost
```

The 8-bit result is `0`. This is **wrap-around**: unsigned N-bit arithmetic is arithmetic **modulo 2ᴺ**, like a car odometer rolling over from 999999 to 000000. Your counters in Lesson 5 do exactly this.

---

## 2.3 Negative Numbers: Two's Complement

Hardware needs negative numbers too. The trick used by essentially every computer is **two's complement**.

### The idea: a clock face

Think of 8-bit numbers as 256 positions on a circle. Going one step backward from 0 lands on 255 (`1111_1111`). So we simply **agree** that the pattern for 255 *means* −1, 254 means −2, and so on.

```
                 0000_0000 (0)
      1111_1111 (−1)      0000_0001 (+1)
   1111_1110 (−2)            0000_0010 (+2)
        ...                       ...
   1000_0001 (−127)          0111_1110 (+126)
           1000_0000 (−128)  0111_1111 (+127)
```

**Rule:** if the MSB is 1, the number is negative. Formally, the MSB has a **negative weight**:

```
value = −b₇×128 + b₆×64 + b₅×32 + b₄×16 + b₃×8 + b₂×4 + b₁×2 + b₀×1
```

So `1111_1011` = −128 + 64 + 32 + 16 + 8 + 0 + 2 + 1 = **−5**.

8-bit signed range: −128 to +127. N bits: −2ᴺ⁻¹ to 2ᴺ⁻¹ − 1.

### How to negate: invert all bits, then add 1

```
+5  =  0000_0101
invert: 1111_1010
add 1:  1111_1011   = −5 ✓
```

**Why does this work?** For any N-bit x, `x + (~x)` is all ones = 2ᴺ − 1 (every bit position has exactly one 1). So `~x + 1 = 2ᴺ − x`, and modulo 2ᴺ that **is** −x. ∎

### Why hardware loves it

1. **One adder does both signed and unsigned addition.** The bits come out right either way. Only the *interpretation* differs.
2. **Subtraction is free:** `a − b = a + (~b) + 1`. Feed the inverted b into the adder and set its carry-in to 1. No separate subtractor is needed.
3. There's only one zero (unlike older "sign-magnitude" formats, which had +0 and −0).

### Sign extension

To make a signed number wider, **copy the sign bit** into the new positions:

```
−5 in 8 bits:            1111_1011
−5 in 16 bits: 1111_1111_1111_1011     (copied the 1)
+5 in 8 bits:            0000_0101
+5 in 16 bits: 0000_0000_0000_0101     (copied the 0)
```

In Verilog: `{{8{x[7]}}, x}` (repeat bit 7 eight times, then append x). Your GPU decoder does exactly this to the 18-bit immediate: `{{14{imm18[17]}}, imm18}`.

### Overflow in signed arithmetic

Overflow happens when the true result doesn't fit. For addition, the rule is: **two operands with the same sign produced a result with the other sign.**

```
  100   =  0110_0100
+ 100   =  0110_0100
-------------------
          1100_1000   = −56 (!!)  two positives gave a "negative": overflow
```

Hardware check: `overflow = (a[7] == b[7]) && (sum[7] != a[7])`. For unsigned addition, overflow is simply the carry-out bit.

---

## 2.4 Fixed-Point Numbers (Fractions Without Floating Point)

What about 3.25? One option is to **pretend there's a binary point** at a fixed position. In **Q8.8** format (16 bits), the top 8 bits are the integer part and the bottom 8 are the fraction:

```
bit weights:  −128 64 32 16 8 4 2 1 . ½ ¼ ⅛ 1/16 1/32 1/64 1/128 1/256
3.25 =           0  0  0  0 0 0 1 1 . 0 1 0  0    0    0    0     0
```

Equivalently: **store the integer `value × 2^(fraction bits)`**. 3.25 × 256 = 832, so you store 832.

| Format | Integer bits (incl. sign) | Fraction bits | Range | Smallest step |
|---|---|---|---|---|
| Q8.8 | 8 | 8 | −128 … +127.996 | 1/256 ≈ 0.0039 |
| Q16.16 | 16 | 16 | ±32768 | 1/65536 ≈ 0.000015 |
| Q1.15 | 1 | 15 | −1 … +0.99997 | 1/32768 |

**General formulas** for Qm.n (signed): range = −2^(m−1) to 2^(m−1) − 2^(−n), and resolution = 2^(−n).

### The rules (memorize these)

- **Add/subtract:** both numbers must have the same number of fraction bits. Then it's a plain integer add.
- **Multiply:** the fraction bits **add up**. Q8.8 × Q8.8 gives a Q16.16 result (32 bits). Shift right by 8 to get back to Q8.8.

```
3.25 × (−1.5):
  stored:   832 × (−384) = −319,488      (this has 16 fraction bits)
  as value: −319,488 / 65,536 = −4.875   ✓
  back to Q8.8: −319,488 >> 8 = −1,248   → −1,248 / 256 = −4.875 ✓
```

**Why GPUs (and you) use fixed point:** an integer adder is tiny and fast, and the results are exact and deterministic. Real rasterizers use fixed-point screen coordinates (e.g. 8 fraction bits = 1/256 of a pixel). Your first GPU datapath is integer/fixed point for this reason.

---

## 2.5 Floating Point (How GPUs Store Real Numbers)

Fixed point has a fixed range. Science and graphics need both tiny and huge numbers, so we use **scientific notation in binary**:

```
decimal scientific:   −6.02 × 10²³
binary scientific:    −1.01₂ × 2¹    (= −1.25 × 2 = −2.5)
```

### IEEE-754 single precision (FP32), the standard GPU number

```
 31  30        23 22                                    0
┌───┬────────────┬────────────────────────────────────────┐
│ S │  exponent  │              mantissa (fraction)        │
│1b │   8 bits   │                23 bits                  │
└───┴────────────┴────────────────────────────────────────┘

value = (−1)^S × 1.mantissa × 2^(exponent − 127)
```

- **S:** 1 means negative.
- **Exponent:** stored with a **bias** of 127 (stored 127 means 2⁰, stored 128 means 2¹, stored 126 means 2⁻¹). The bias lets the exponent be stored as an unsigned number.
- **Mantissa:** the bits after the binary point. The leading `1.` is **not stored** ("hidden bit"), because a normalized binary number always starts with 1. That's a free extra bit of precision.

### Worked decode: 0xC0200000

```
hex:    C    0    2    0    0    0    0    0
bits: 1100 0000 0010 0000 0000 0000 0000 0000

S        = 1                         → negative
exponent = 1000 0000 = 128           → 2^(128 − 127) = 2¹
mantissa = 010 0000 ... 0            → 1.01₂ = 1 + 1/4 = 1.25

value = −1.25 × 2 = −2.5
```

### Worked encode: 0.75

1. 0.75 = 0.11₂ (½ + ¼).
2. Normalize: 0.11₂ = 1.1₂ × 2⁻¹.
3. S = 0. Exponent stored = −1 + 127 = 126 = `0111_1110`. Mantissa = `100 0000 …` (the bits after "1.").
4. Bits: `0 01111110 10000000000000000000000` = `0x3F400000`.

### Precision

23 stored mantissa bits plus the hidden bit give 24 bits of precision: about **7 decimal digits**. And many simple decimals are **not exact** in binary. 0.1 is 0.000110011001100…₂ forever, so it gets rounded. That's why `0.1 + 0.2 != 0.3` in most programming languages.

### Special values

| Exponent | Mantissa | Meaning |
|---|---|---|
| 0 | 0 | ±0 |
| 0 | ≠ 0 | subnormal (tiny numbers near 0) |
| 255 | 0 | ±infinity |
| 255 | ≠ 0 | NaN ("not a number", e.g. 0/0) |

### Other formats you'll hear about

FP16 (1-5-10 bits), bfloat16 (1-8-7: FP32's range, less precision), FP8 and FP4 (used by AI tensor cores). Fewer bits mean less precision but smaller, faster, lower-power hardware. Lesson 8 covers how floating-point add and multiply are actually computed.

---

## 2.6 Run the Lab

All of the above, computed in Python so you can experiment:

`code/02_numbers/numbers_lab.py`:

```python
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
```

```
cd hardware_basics\code\02_numbers
python numbers_lab.py
```

Expected output (abridged):

```
== Two's complement (8 bits) ==
   -5 -> pattern 11111011 (0xFB) -> read back -5
 -128 -> pattern 10000000 (0x80) -> read back -128
== Overflow: 100 + 100 in 8-bit signed ==
pattern 11001000 reads as -56  (the true answer 200 does not fit)
== Fixed point Q8.8 (8 fractional bits) ==
3.25 -> 832 (0x0340),  -1.5 -> -384
raw product -319488 has 16 fractional bits -> -4.875
== IEEE-754 float32 ==
    -2.5 -> 0xC0200000  sign=1 exp=128 (2^1) mant=0x200000 -> -2.5
     0.1 -> 0x3DCCCCCD  sign=0 exp=123 (2^-4) mant=0x4CCCCD -> 0.10000000149011612
```

**Try:** change the inputs, predict the output by hand first, then run it and check.

---

## Common Mistakes

- **Forgetting the width.** "−1" is not a bit pattern until you say how many bits: `1111` (4 bits) or `1111_1111` (8 bits).
- **Zero-extending a signed number** (filling with 0s) turns −5 into +251. Sign-extend signed values.
- **Mixing signed and unsigned** in Verilog. If *any* operand is unsigned, Verilog treats the whole expression as unsigned (Lesson 8 shows the fix: `$signed()`).
- **Forgetting to shift after a fixed-point multiply.** The fraction bits double.

---

## Exercises

1. Convert 157 to binary and to hex.
2. What is `0x3F` in decimal? And `0b1010_0101`?
3. How many bits do you need for: (a) 8 warps (b) 1000 different values (c) a 320×240 framebuffer address?
4. Write −20 in 8-bit two's complement. Then sign-extend it to 16 bits.
5. Compute 120 + 10 in 8-bit signed arithmetic. What bit pattern results and what does it mean? Did it overflow?
6. In Q8.8, what integer is stored for 2.5? For −0.25? What real value does the stored integer 100 represent?
7. Multiply Q8.8 values 1.5 × 2.25 by hand using stored integers, and convert back.
8. Decode the FP32 value `0x40400000`.
9. Encode 5.0 as FP32 hex.

<details>
<summary><b>Answers</b></summary>

1. 157 = 128 + 16 + 8 + 4 + 1 = `1001_1101` = **0x9D**.
2. 0x3F = 3×16 + 15 = **63**. `1010_0101` = 128 + 32 + 4 + 1 = **165** (0xA5).
3. (a) **3** bits (b) **10** bits (2¹⁰ = 1024 ≥ 1000) (c) 76,800 values → **17** bits.
4. +20 = `0001_0100` → invert `1110_1011` → +1 = **`1110_1100`**. 16 bits: **`1111_1111_1110_1100`**.
5. 120 = `0111_1000`, 10 = `0000_1010`, sum = `1000_0010` = **−126** as signed. Two positives gave a negative: **overflow** (130 doesn't fit in −128..127).
6. 2.5 × 256 = **640**. −0.25 × 256 = **−64** (pattern 0xFFC0). 100 / 256 = **0.390625**.
7. 1.5 → 384, 2.25 → 576. 384 × 576 = 221,184 (16 fraction bits). Shift right by 8: **864**. 864 / 256 = **3.375** ✓ (1.5 × 2.25 = 3.375).
8. `0100 0000 0100 0000 …`: S = 0, exponent = `1000_0000` = 128 → 2¹, mantissa `100…` → 1.5. Value = 1.5 × 2 = **3.0**.
9. 5 = 101₂ = 1.01₂ × 2². Exponent = 2 + 127 = 129 = `1000_0001`. Mantissa = `0100…`. Bits: `0 10000001 01000…0` = `0100 0000 1010 0000 …` = **0x40A00000**.

</details>

---

**Next:** [Lesson 3 — Logic Gates and Boolean Algebra](03_logic_gates_and_boolean_algebra.md)
