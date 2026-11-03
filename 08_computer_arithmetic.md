# Lesson 8 — Computer Arithmetic: Adding, Multiplying, Fixed Point and Floating Point in Hardware

> **Why this matters for your GPU:** a GPU is an arithmetic machine. Its whole job is billions of additions and multiplications per second. This lesson shows how hardware multiplies, how wide results get, how fixed-point math works in Verilog (with real rounding errors), the **lerp** operation that graphics uses everywhere, and how floating-point add and multiply actually work.

---

## 8.1 Addition and Subtraction (Recap)

From Lessons 2 and 4:
- N-bit + N-bit gives up to N+1 bits.
- Subtraction is addition: `a − b = a + ~b + 1`.
- The same adder works for signed and unsigned numbers. Only overflow detection differs.

**Proof of the width rule:** the biggest N-bit unsigned value is 2ᴺ − 1. The biggest sum is 2 × (2ᴺ − 1) = 2ᴺ⁺¹ − 2 < 2ᴺ⁺¹, so N+1 bits are always enough.

---

## 8.2 Multiplication

### By hand in binary: shift and add

Multiplying by a binary digit is trivial: × 0 gives 0 and × 1 gives the number itself. So binary long multiplication is: **for every 1 bit in the multiplier, add a shifted copy of the multiplicand**.

6 × 5 = 110 × 101:

```
          1 1 0      (6)
        × 1 0 1      (5)
        -------
          1 1 0      bit 0 of 5 is 1 → 6 shifted by 0
        0 0 0        bit 1 is 0      → 0
      1 1 0          bit 2 is 1      → 6 shifted by 2  (= 24)
      ---------
      1 1 1 1 0      = 30 ✓
```

### Width of a product

An N-bit × M-bit product needs **N + M bits**. Proof: (2ᴺ − 1)(2ᴹ − 1) = 2ᴺ⁺ᴹ − 2ᴺ − 2ᴹ + 1 < 2ᴺ⁺ᴹ. Example: 8 × 8 bits → 16 bits (255 × 255 = 65,025 < 65,536).

**Verilog gotcha:** the result width comes from the *left-hand side*, so:

```verilog
wire [31:0] a, b;
wire [31:0] p  = a * b;     // keeps only the LOW 32 bits (what the GPU's MUL instruction does)
wire [63:0] pf = a * b;     // the full 64-bit product
```

### How hardware does it

| Method | How | Speed | Size |
|---|---|---|---|
| **Sequential** shift-and-add | 1 bit of the multiplier per cycle (an FSM + one adder) | N cycles | Tiny |
| **Array multiplier** | All N partial products at once, added by a grid of adders | 1 cycle, slow-ish | ~N² full adders |
| **Tree (Wallace/Dadda) + Booth** | Recode to halve the partial products, then add them in a tree | 1 cycle, fast | Large |
| **FPGA DSP block** | A hardened multiplier circuit on the FPGA (e.g. 25×18 bits) | Very fast | "Free" (but limited count) |

On an FPGA, just write `a * b`: the tools use **DSP blocks**. An FPGA has a fixed number of them (90 on a small Artix-7, 240 on a bigger one). **The number of DSPs often limits how many GPU lanes you can build.** A 32×32 multiply needs 3–4 DSPs, but a 16×16 needs just 1. That's a real reason GPUs on FPGAs often use 16-bit math.

Multiplication by a **constant power of 2 is free** (a shift = wiring). Multiplication by other constants can be built from shifts and adds: `x * 10 = (x << 3) + (x << 1)`.

### Division is expensive

Division can't be parallelized as nicely. Hardware usually computes 1–2 quotient bits per cycle, or computes a reciprocal (1/b) by Newton-Raphson iteration and multiplies. GPUs compute `a / b` as `a × (1/b)`, using a special unit for 1/b. **Avoid division in hardware when you can.** Dividing by a power of 2 is just a shift.

---

## 8.3 Fixed-Point Math in Verilog

Recall from Lesson 2: Q8.8 stores `value × 256` in 16 bits. Multiplying two Q8.8 numbers gives a Q16.16 result in 32 bits. Shift right by 8 to get back to Q8.8.

`code/08_arithmetic/fixed_point.v`:

```verilog
// fixed_point.v: signed Q8.8 arithmetic (16 bits = 8 integer bits incl. sign + 8 fraction bits)
// A Q8.8 number stored as integer N means the real value N / 256.

module q88_mul (
  input  wire signed [15:0] a, b,        // Q8.8
  output wire signed [15:0] y,           // Q8.8 (truncated toward -infinity)
  output wire               overflow     // true result does not fit in Q8.8
);
  wire signed [31:0] full = a * b;       // Q16.16: 16x16 bits -> 32 bits, 16 fraction bits
  wire signed [23:0] shifted = full[31:8];  // drop 8 fraction bits -> 8 left (Q16.8)
  assign y = shifted[15:0];
  // fits only if the top bits are all copies of the sign bit
  assign overflow = (shifted[23:15] != {9{shifted[15]}});
endmodule

// Linear interpolation: y = a + (b - a) * t, with t in [0, 1) as an unsigned 0.8 fraction.
// This exact operation is everywhere in graphics: color blending, texture filtering.
module lerp8 (
  input  wire [7:0] a, b,                // e.g. two color intensities 0..255
  input  wire [7:0] t,                   // t/256 = how far from a toward b
  output wire [7:0] y
);
  wire signed [8:0]  diff = $signed({1'b0, b}) - $signed({1'b0, a});   // -255..255 needs 9 bits
  wire signed [17:0] scaled = diff * $signed({1'b0, t});               // 9 bits x 9 bits
  assign y = a + scaled[15:8];                                        // divide by 256
endmodule
```

Notice the `signed` keyword: it makes `*` a **signed** multiply. Without it, −1.5 (stored as 65,152 unsigned) would be treated as a large positive number.

### Overflow detection, explained

After shifting, the 24-bit value must fit in 16 signed bits. It fits only if bits 23 down to 15 are all the same (all copies of the sign bit). Any difference means the value needed more bits: overflow.

### Run it

`code/08_arithmetic/tb_fixed.v`:

```verilog
// tb_fixed.v
// Run: iverilog -o fixed.vvp fixed_point.v tb_fixed.v && vvp -n fixed.vvp
`timescale 1ns/1ps
module tb_fixed;
  reg  signed [15:0] a, b;
  wire signed [15:0] y;
  wire ovf;
  q88_mul u_mul (.a(a), .b(b), .y(y), .overflow(ovf));

  reg  [7:0] la, lb, t;
  wire [7:0] ly;
  lerp8 u_lerp (.a(la), .b(lb), .t(t), .y(ly));

  task show_mul(input real ra, input real rb);
    begin
      a = $rtoi(ra * 256.0); b = $rtoi(rb * 256.0); #1;
      $display("%8.4f x %8.4f : a=%6d b=%6d -> y=%6d = %9.5f  (exact %9.5f)%s",
               ra, rb, a, b, y, y / 256.0, ra * rb, ovf ? "  OVERFLOW" : "");
    end
  endtask

  integer i, errors = 0, exp;
  initial begin
    $display("Q8.8 multiply (value = stored integer / 256):");
    show_mul(3.25, -1.5);
    show_mul(0.5, 0.5);
    show_mul(1.1, 1.1);      // 1.1 is not exact in Q8.8 -> small error
    show_mul(100.0, 2.0);    // 200 > 127.996 -> overflow
    show_mul(-2.0, 64.0);    // exactly -128: the most negative value fits

    $display("\nlerp8: from a=40 to b=240");
    la = 40; lb = 240;
    for (i = 0; i <= 256; i = i + 64) begin
      t = (i == 256) ? 8'd255 : i; #1;
      $display("  t=%3d/256 -> %3d", t, ly);
    end
    // exhaustive check of lerp against the formula (floor division)
    for (i = 0; i < 65536; i = i + 1) begin
      la = i[7:0]; lb = i[15:8]; t = (i * 37) & 8'hFF; #1;
      exp = la + (((lb - la) * t) >>> 8);
      if (ly !== exp[7:0]) errors = errors + 1;
    end
    if (errors == 0) $display("PASS: lerp8 matches a + ((b-a)*t >> 8) for 65536 cases");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
```

```
cd hardware_basics\code\08_arithmetic
iverilog -o fixed.vvp fixed_point.v tb_fixed.v
vvp -n fixed.vvp
```

```
Q8.8 multiply (value = stored integer / 256):
  3.2500 x  -1.5000 : a=   832 b=  -384 -> y= -1248 =  -4.87500  (exact  -4.87500)
  0.5000 x   0.5000 : a=   128 b=   128 -> y=    64 =   0.25000  (exact   0.25000)
  1.1000 x   1.1000 : a=   281 b=   281 -> y=   308 =   1.20312  (exact   1.21000)
100.0000 x   2.0000 : a= 25600 b=   512 -> y=-14336 = -56.00000  (exact 200.00000)  OVERFLOW
 -2.0000 x  64.0000 : a=  -512 b= 16384 -> y=-32768 = -128.00000  (exact -128.00000)
```

**Read each line:**
- **3.25 × −1.5:** exact, because both numbers are exact in binary (they're sums of powers of 2).
- **1.1 × 1.1:** 1.1 can't be represented exactly. 1.1 × 256 = 281.6, which became 281 (= 1.09766). Then 281 × 281 = 78,961, and >> 8 = 308.4 → 308 = 1.20312. **Two rounding errors**: one when storing and one when shifting. Error ≈ 0.007. This is why precision (the number of fraction bits) matters.
- **100 × 2:** 200 doesn't fit in Q8.8 (max ≈ 127.996). The bits wrapped to −56. The `overflow` flag caught it. Real hardware either flags it or **saturates** (clamps to the max value).
- **−2 × 64 = −128:** exactly the most negative value, which still fits.

---

## 8.4 Lerp: the Most Common Operation in Graphics

**Linear interpolation** blends from a to b by a fraction t (0 ≤ t ≤ 1):

```
lerp(a, b, t) = a + (b − a) × t          (t = 0 → a, t = 1 → b, t = 0.5 → halfway)
```

Graphics uses it **everywhere**: blending colors between triangle corners, mixing a transparent pixel with the background (alpha blending), filtering textures (bilinear filtering = 3 lerps), animation.

In hardware with 8-bit colors and t as an 8-bit fraction (t/256):

```
y = a + ((b − a) × t) >> 8
```

The `lerp8` module computes it. Note that `b − a` can be negative (−255…255), so it needs 9 bits and a signed multiply.

```
lerp8: from a=40 to b=240
  t=  0/256 ->  40
  t= 64/256 ->  90       40 + 200 × 0.25
  t=128/256 -> 140       halfway
  t=192/256 -> 190
  t=255/256 -> 239       almost b (t can't reach exactly 1.0 in 8 bits)
PASS: lerp8 matches a + ((b-a)*t >> 8) for 65536 cases
```

**Cost:** 1 subtract, 1 multiply, 1 add. A texture unit doing bilinear filtering on RGBA does 3 lerps × 4 channels = 12 of these per pixel.

---

## 8.5 Floating-Point Arithmetic: How It Really Works

Floating-point numbers (Lesson 2) are `±1.mantissa × 2^exponent`. Arithmetic works like it does with scientific notation by hand.

### Multiplication: actually the easy one

(1.5 × 2³) × (1.25 × 2²):

1. **Sign:** XOR the signs (positive × positive = positive).
2. **Exponent:** **add** them: 3 + 2 = 5. (In stored form: e₁ + e₂ − 127, because both carry the bias.)
3. **Mantissa:** **multiply** them: 1.5 × 1.25 = 1.875. (A 24×24-bit integer multiply for FP32.)
4. **Normalize:** if the mantissa product is ≥ 2, shift it right once and add 1 to the exponent. (1.875 < 2, so no change.)
5. **Round** the mantissa back to 23 bits.

Result: 1.875 × 2⁵ = 60 ✓ (12 × 5 = 60).

### Addition: harder

1.5 × 2³ + 1.25 × 2¹ (= 12 + 2.5):

1. **Align:** the exponents must match. Shift the smaller number's mantissa right by the difference (3 − 1 = 2): 1.25 × 2¹ = 0.3125 × 2³.
2. **Add the mantissas:** 1.5 + 0.3125 = 1.8125 → 1.8125 × 2³ = 14.5 ✓.
3. **Normalize:** if the result is ≥ 2, shift right. When *subtracting* nearly-equal numbers the result can be tiny (like 0.000001…), so you need a **leading-zero counter** and a big left shift.
4. **Round.**

The alignment shifter and leading-zero counter make an FP adder **bigger and slower than an FP multiplier**. Surprising but true.

### FMA: Fused Multiply-Add

`a × b + c` computed as **one operation with one rounding** at the end. It's more accurate (one rounding instead of two), and it's the core operation of GPUs:
- A dot product `x₁y₁ + x₂y₂ + x₃y₃ + …` is a chain of FMAs.
- Matrix multiply, lighting and neural networks are all FMAs.

GPU marketing counts one FMA as **2 FLOPs** (floating-point operations).

### Why GPUs started with fixed point, and why your GPU does too

FP units are much larger than integer units (an FP32 FMA on an FPGA is ~1000 LUTs + several DSPs vs ~32 LUTs for an integer add). Your first GPU uses 32-bit integers to get the *control* right. Floating point is an upgrade (main guide, Part 15.8, upgrade #5).

---

## 8.6 Signed vs Unsigned in Verilog (Read This Twice)

Verilog's rule: **if any operand in an expression is unsigned, the entire expression is treated as unsigned.**

```verilog
wire        [7:0] u = 8'd200;
wire signed [7:0] s = -8'sd5;

wire result1 = (s < 0);            // 0 is a signed integer literal → signed compare → TRUE
wire result2 = (s < u);            // u is unsigned → BOTH treated as unsigned: 251 < 200 → FALSE!
wire result3 = ($signed(s) < $signed({1'b0, u}));  // force signed: −5 < 200 → TRUE
```

The GPU's ALU uses `$signed(a) < $signed(b)` for `SLT` and plain `a < b` for `SLTU`. Same bits, different questions.

---

## Exercises

1. Multiply 1101 × 1011 in binary by shift-and-add. Check in decimal.
2. How many bits does a 12-bit × 9-bit product need?
3. Express `x * 12` using only shifts and adds.
4. Q8.8: compute 0.75 × 0.75 using stored integers, with the shift. Is the result exact? Why?
5. In Q4.4 (8 bits total), what's the largest positive value and the smallest step?
6. `lerp8(100, 50, 128)`: compute by hand. (Watch the sign of b − a.)
7. Floating point: multiply (1.5 × 2⁴) × (1.5 × 2⁻²) using the 5-step method. Does it need normalization?
8. Why is `a / b` usually computed as `a × (1/b)` on GPUs?

<details>
<summary><b>Answers</b></summary>

1. 1101 (13) × 1011 (11): add 1101 (bit 0) + 11010 (bit 1) + 0 (bit 2 is 0) + 1101000 (bit 3) = 13 + 26 + 104 = **143** = `1000_1111`. 13 × 11 = 143 ✓.
2. 12 + 9 = **21 bits**.
3. 12 = 8 + 4 → `(x << 3) + (x << 2)`.
4. 0.75 → 192. 192 × 192 = 36,864, and >> 8 = **144**. 144 / 256 = 0.5625 = 0.75² exactly ✓. Exact, because 0.75 = ½ + ¼ is exact in binary and the result 0.5625 = 9/16 needs only 4 fraction bits.
5. Largest: 0111.1111 = 7 + 15/16 = **7.9375**. Step = 1/16 = **0.0625**.
6. b − a = −50. −50 × 128 = −6400. −6400 >> 8 = −25 (arithmetic shift). 100 + (−25) = **75** = halfway ✓.
7. Sign +. Exponent 4 + (−2) = 2. Mantissa 1.5 × 1.5 = 2.25 ≥ 2 → **normalize**: 1.125, exponent 3. Result 1.125 × 2³ = 9 ✓ (24 × 0.375 = 9).
8. Division hardware is big and slow. A reciprocal unit (lookup table + a Newton-Raphson step) followed by a multiply is faster, and the reciprocal can be reused when dividing many values by the same b.

</details>

---

**Next:** [Lesson 9 — How a Processor Works](09_how_a_processor_works.md)
