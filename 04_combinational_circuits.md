# Lesson 4 — Combinational Circuits: the Building Blocks

> **Why this matters for your GPU:** the GPU's ALU, instruction decoder, operand selection, arbiters and address calculation are all *combinational* blocks: multiplexers, decoders, comparators, adders and shifters. Once you know these five, you can read most of `gpu_alu.sv` and `gpu_decode.sv`.

---

## 4.1 What "Combinational" Means

A **combinational** circuit's output depends **only on its current inputs**. It has no memory and no clock. Change the inputs, wait a moment for the signals to travel through the gates (the **propagation delay**), and the output is the new answer.

```
 inputs ──►[ gates, no memory ]──► outputs        output = f(inputs), always
```

The opposite is **sequential** logic (Lesson 5), which remembers things.

### Glitches

While signals travel through gates of different lengths, the output can briefly show a wrong value (a **glitch**) before settling. For example, if `y = a & ~a` and `a` changes, the path through the inverter is slower, so for a few picoseconds both inputs to the AND can be 1.

**Why we don't care:** in synchronous design (Lesson 5), outputs are only *sampled* at clock edges, long after everything settles. This is the main reason all modern digital design is synchronous.

---

## 4.2 The Multiplexer (Mux): Hardware's "if"

A **mux** selects one of several inputs, using a **select** signal.

```
        d0 ──┐
        d1 ──┤
        d2 ──┤ MUX ──► y          y = d[sel]
        d3 ──┘
              ↑
             sel (2 bits)
```

2-to-1 mux in Boolean form: `y = (s̄ · d0) + (s · d1)`. When s = 0 the first term passes d0; when s = 1 the second passes d1.

In Verilog the `? :` operator is a 2:1 mux:

```verilog
assign y = sel ? d1 : d0;
```

**The most important idea in this lesson:** in hardware, an `if/else` doesn't "choose which code to run". **Both** sides are built, both compute all the time, and a mux picks which result to use.

```verilog
if (subtract) y = a - b; else y = a + b;
// builds: an adder AND a subtractor (both always computing) + a 2:1 mux on the output
```

That's why a GPU ALU that supports 14 operations contains 14 operation circuits plus a big mux (look at `gpu_alu.sv`: it's exactly that).

**Cost:** an N:1 mux needs ⌈log₂N⌉ select bits and roughly N−1 two-input muxes per output bit. Wide muxes get expensive. A 32:1 mux on 32-bit data is about 31 × 32 ≈ 1000 small muxes.

---

## 4.3 Decoders and Encoders

A **decoder** turns an n-bit binary number into 2ⁿ outputs where exactly one is 1 (**one-hot**):

| in | out[3:0] |
|---|---|
| 00 | 0001 |
| 01 | 0010 |
| 10 | 0100 |
| 11 | 1000 |

Used for: choosing which register to write, which memory bank to enable, and turning an opcode into control signals (that's what an *instruction decoder* does, in a richer form).

An **encoder** does the reverse (one-hot → binary). A **priority encoder** handles several 1s by reporting the highest or lowest one. GPU warp schedulers use one to pick "the first ready warp".

A handy trick: `x & (~x + 1)` (equivalently `x & -x`) keeps only the **lowest set bit** of x. For x = `0110_1000`: ~x + 1 = `1001_1000`, AND gives `0000_1000`. That one line is a whole "pick the first requester" circuit.

---

## 4.4 Comparators

- **Equality:** XNOR each pair of bits (1 if they're equal), then AND all the results. In Verilog: `a == b`.
- **Less than:** compute `a − b` and check the borrow (or the sign, for signed numbers). In Verilog: `a < b`. Comparators reuse adder hardware.

**Signed vs unsigned:** `4'b1111 < 4'b0001` is **false** unsigned (15 < 1), but **true** signed (−1 < 1). Same bits, different meaning. Your GPU has both `SLT` (signed) and `SLTU` (unsigned) instructions for this reason.

---

## 4.5 The Adder: Chaining Full Adders

Add two 4-bit numbers by hand like in school, column by column, carrying into the next column:

```
  carries:  1 0 0 0
            1 0 0 1    (9)
          + 1 0 0 0    (8)
          ---------
          1 0 0 0 1    (17)    the 5th bit is the carry-out
```

Each column is exactly one **full adder** (Lesson 3): it takes a, b and the carry from the right, and produces sum and a carry to the left. Chain four of them and you get a **ripple-carry adder**:

```
   a3 b3       a2 b2       a1 b1       a0 b0
    │ │         │ │         │ │         │ │
  ┌─┴─┴─┐ c3  ┌─┴─┴─┐ c2  ┌─┴─┴─┐ c1  ┌─┴─┴─┐
◄─┤ FA  │◄────┤ FA  │◄────┤ FA  │◄────┤ FA  │◄── cin
cout└──┬──┘    └──┬──┘    └──┬──┘    └──┬──┘
       s3         s2         s1         s0
```

### Delay math: why adders can be slow

The carry must "ripple" through every stage. If one full adder's carry takes t_c, an N-bit ripple adder takes about **N × t_c**:

| Width | Carry delay (t_c = 50 ps) |
|---|---|
| 4 bits | 0.2 ns |
| 32 bits | 1.6 ns |
| 64 bits | 3.2 ns |

At 1 GHz (1 ns period), a 64-bit ripple adder doesn't fit in one cycle. Faster adders compute carries in parallel (carry-lookahead, Kogge-Stone) at the cost of more gates. Their delay grows like log₂N instead of N. That's the classic **area vs speed trade-off** (main guide, Part 2.1).

**FPGA twist:** FPGAs have dedicated, very fast **carry-chain** wires built into the silicon, so on an FPGA the simple ripple adder (just write `a + b`) is usually the fastest choice.

### Subtraction with the same adder

From Lesson 2: `a − b = a + (~b) + 1`. So: invert b, set cin = 1, and use the same adder. One adder does both. The mux picks `b` or `~b`.

### Width rule (very important)

Adding two N-bit numbers can produce an N+1-bit result (9 + 8 = 17 needs 5 bits). In Verilog:

```verilog
wire [3:0] s4 = a + b;       // 4 bits: 9 + 8 = 17 wraps to 1. Carry LOST
wire [4:0] s5 = a + b;       // 5 bits: 17 kept
assign {cout, sum} = a + b;  // concatenation on the left catches the carry separately
```

Verilog **silently truncates**. Always ask: "how wide can this result get?"

---

## 4.6 Shifters

Shifting left by n places multiplies by 2ⁿ, and shifting right divides by 2ⁿ (rounding down), just like moving the decimal point in base 10:

```
0000_0101 (5)  << 2  =  0001_0100 (20)    5 × 4
0001_0100 (20) >> 2  =  0000_0101 (5)     20 ÷ 4
```

- `>>` is a **logical** right shift (fills with 0s): correct for unsigned numbers.
- `>>>` is an **arithmetic** right shift (fills with copies of the sign bit): correct for signed numbers. Example: −8 = `1111_1000` >>> 1 = `1111_1100` = −4 ✓. With `>>` you'd get `0111_1100` = 124 ✗.

A **barrel shifter** shifts by any amount in one cycle using log₂N layers of muxes (shift by 1 or not, by 2 or not, by 4 or not, …).

**Shift by a constant is free in hardware:** it's just wiring, with no gates. `x << 3` connects bit i of x to bit i+3 of the output. That's why hardware designers love powers of two (main guide: `y*320 = (y<<8) + (y<<6)`).

---

## 4.7 Writing Combinational Logic in Verilog

Two styles, same hardware:

```verilog
// Style 1: continuous assignment (best for simple expressions)
assign y = sel ? d1 : d0;

// Style 2: always @(*) block (best for case/if with many branches)
always @(*) begin
  y = d0;               // DEFAULT FIRST
  if (sel) y = d1;
end
```

`always @(*)` means "re-evaluate whenever any input changes". Inside it, use **blocking** `=` assignments (Lesson 6 explains why).

### The latch trap

```verilog
always @(*) begin
  if (en) y = a;        // what is y when en = 0?? Not specified!
end
```

If some path doesn't assign `y`, the hardware must **remember** the old value. That needs memory, so the tool creates a **latch** you didn't want. Latches cause timing problems and are almost always bugs in combinational code. **Fix: assign a default at the top of every `always @(*)` block**, or cover every `case` with a `default:`.

---

## 4.8 The Code

`code/04_combinational/comb_blocks.v`:

```verilog
// comb_blocks.v: the classic combinational building blocks.
// "Combinational" = output depends ONLY on the current inputs. No clock, no memory.

// 4-to-1 multiplexer: picks one of four inputs using a 2-bit select
module mux4 #(parameter W = 8) (
  input  wire [W-1:0] d0, d1, d2, d3,
  input  wire [1:0]   sel,
  output reg  [W-1:0] y
);
  always @(*) begin
    case (sel)
      2'd0: y = d0;
      2'd1: y = d1;
      2'd2: y = d2;
      default: y = d3;
    endcase
  end
endmodule

// 2-to-4 decoder: turns a binary number into "one-hot" (exactly one output is 1)
module decoder2to4 (
  input  wire [1:0] in,
  input  wire       en,
  output wire [3:0] out
);
  assign out = en ? (4'b0001 << in) : 4'b0000;
endmodule

// 4-bit comparator
module comparator4 (
  input  wire [3:0] a, b,
  output wire       eq, lt, gt
);
  assign eq = (a == b);
  assign lt = (a <  b);
  assign gt = (a >  b);
endmodule

// 4-bit ripple-carry adder built from four full adders (structural Verilog)
module adder4 (
  input  wire [3:0] a, b,
  input  wire       cin,
  output wire [3:0] sum,
  output wire       cout
);
  wire c1, c2, c3;   // carries between the stages
  full_adder fa0 (.a(a[0]), .b(b[0]), .cin(cin), .sum(sum[0]), .cout(c1));
  full_adder fa1 (.a(a[1]), .b(b[1]), .cin(c1),  .sum(sum[1]), .cout(c2));
  full_adder fa2 (.a(a[2]), .b(b[2]), .cin(c2),  .sum(sum[2]), .cout(c3));
  full_adder fa3 (.a(a[3]), .b(b[3]), .cin(c3),  .sum(sum[3]), .cout(cout));
endmodule

// 8-bit shifter: shift left or right by 0..7 places
module shifter8 (
  input  wire [7:0] x,
  input  wire [2:0] amount,
  input  wire       left,
  output wire [7:0] y
);
  assign y = left ? (x << amount) : (x >> amount);
endmodule
```

Note how `adder4` is **structural**: it instantiates four `full_adder` modules (from Lesson 3) and wires them together, exactly like the diagram. Each instance (`fa0`, `fa1`, …) is a physical copy of the circuit.

The testbench tries **every** input combination: 512 for the adder/comparator (16 × 16 × 2), and 4096 for the shifter.

`code/04_combinational/tb_comb.v`:

```verilog
// tb_comb.v: EXHAUSTIVE tests. Small blocks have few inputs, so we try every combination.
// Run: iverilog -o comb.vvp ../03_logic_gates/full_adder.v comb_blocks.v tb_comb.v && vvp -n comb.vvp
`timescale 1ns/1ps
module tb_comb;
  integer i, j, k, errors = 0;

  // ---- mux4 ----
  reg  [1:0] sel;
  wire [7:0] my;
  mux4 #(.W(8)) u_mux (.d0(8'd10), .d1(8'd20), .d2(8'd30), .d3(8'd40), .sel(sel), .y(my));

  // ---- decoder ----
  reg  [1:0] din; reg den;
  wire [3:0] dout;
  decoder2to4 u_dec (.in(din), .en(den), .out(dout));

  // ---- comparator + adder ----
  reg  [3:0] a, b; reg cin;
  wire eq, lt, gt, cout;
  wire [3:0] sum;
  comparator4 u_cmp (.a(a), .b(b), .eq(eq), .lt(lt), .gt(gt));
  adder4      u_add (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));

  // ---- shifter ----
  reg  [7:0] sx; reg [2:0] amt; reg left;
  wire [7:0] sy;
  shifter8 u_sh (.x(sx), .amount(amt), .left(left), .y(sy));

  initial begin
    // mux: each select value must route the matching input
    for (i = 0; i < 4; i = i + 1) begin
      sel = i; #1;
      if (my !== (i + 1) * 10) errors = errors + 1;
    end
    $display("mux4    : sel=0..3 gives 10,20,30,40");

    // decoder: one-hot output
    den = 1;
    for (i = 0; i < 4; i = i + 1) begin
      din = i; #1;
      $display("decoder : in=%0d -> out=%b", din, dout);
      if (dout !== (4'b0001 << i)) errors = errors + 1;
    end
    den = 0; #1; if (dout !== 4'b0000) errors = errors + 1;

    // comparator + adder: all 16 x 16 x 2 = 512 combinations
    for (i = 0; i < 16; i = i + 1)
      for (j = 0; j < 16; j = j + 1)
        for (k = 0; k < 2; k = k + 1) begin
          a = i; b = j; cin = k; #1;
          if ({cout, sum} !== i + j + k) errors = errors + 1;
          if (eq !== (i == j) || lt !== (i < j) || gt !== (i > j)) errors = errors + 1;
        end
    a = 4'd9; b = 4'd8; cin = 0; #1;
    $display("adder4  : 9 + 8 = %0d -> sum=%b cout=%b (cout is the 5th bit: 16)", {cout, sum}, sum, cout);

    // shifter: all values, amounts, directions
    for (i = 0; i < 256; i = i + 1)
      for (j = 0; j < 8; j = j + 1)
        for (k = 0; k < 2; k = k + 1) begin
          sx = i; amt = j; left = k; #1;
          if (sy !== (k ? ((i << j) & 8'hFF) : (i >> j))) errors = errors + 1;
        end
    sx = 8'b0000_0101; amt = 2; left = 1; #1;
    $display("shifter : 5 << 2 = %0d (shifting left by n multiplies by 2^n)", sy);

    if (errors == 0) $display("PASS: all combinational blocks correct (exhaustive)");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
```

```
cd hardware_basics\code\04_combinational
iverilog -o comb.vvp ..\03_logic_gates\full_adder.v comb_blocks.v tb_comb.v
vvp -n comb.vvp
```

Output:

```
mux4    : sel=0..3 gives 10,20,30,40
decoder : in=0 -> out=0001
decoder : in=1 -> out=0010
decoder : in=2 -> out=0100
decoder : in=3 -> out=1000
adder4  : 9 + 8 = 17 -> sum=0001 cout=1 (cout is the 5th bit: 16)
shifter : 5 << 2 = 20 (shifting left by n multiplies by 2^n)
PASS: all combinational blocks correct (exhaustive)
```

---

## 4.9 How This Connects to the GPU

Open `gpu_project/rtl/gpu_alu.sv`. You'll now recognize every line:

```systemverilog
case (op)
  A_ADD:   y = a + b;                         // adder
  A_SUB:   y = a - b;                         // adder with inverted b, cin = 1
  A_SHL:   y = a << b[4:0];                   // barrel shifter (5-bit amount: 0..31)
  A_SRA:   y = $signed(a) >>> b[4:0];         // arithmetic shifter
  A_SLT:   y = {31'b0, $signed(a) < $signed(b)};   // signed comparator, zero-extended to 32 bits
  ...
endcase                                       // the case itself = a big mux choosing the result
```

The GPU has one of these ALUs **per lane**. With 4 lanes, there are 4 copies, all doing the same operation on different data. That's SIMD (Lesson 10).

---

## Exercises

1. Draw (or describe) a 4:1 mux built from three 2:1 muxes.
2. What does `8'b0101_1100 & -8'b0101_1100` produce? What is it used for?
3. A ripple adder's full-adder carry delay is 80 ps. What's the max width that fits in a 2 ns clock period (ignoring everything else)?
4. Is `4'b1000 < 4'b0111` true or false (a) unsigned (b) signed?
5. Compute `−12 >>> 2` and `−12 >> 2` in 8 bits. Which one equals −3?
6. This code makes a latch. Fix it:
   ```verilog
   always @(*) case (op) 2'b00: y = a; 2'b01: y = b; endcase
   ```
7. `wire [7:0] s = a + b;` where a and b are 8-bit values 200 and 100. What is s? How do you keep the full result?

<details>
<summary><b>Answers</b></summary>

1. First layer: mux A picks d0/d1 using sel[0], mux B picks d2/d3 using sel[0]. Second layer: mux C picks A/B using sel[1].
2. −x = ~x + 1 = `1010_0100`. AND with x = `0000_0100`: the **lowest set bit**. Used for "pick the first requester" (fixed-priority arbiters, finding the first ready warp).
3. 2000 / 80 = **25 bits**.
4. (a) Unsigned: 8 < 7 is **false**. (b) Signed: −8 < 7 is **true**.
5. −12 = `1111_0100`. `>>>` 2 = `1111_1101` = **−3** ✓. `>>` 2 = `0011_1101` = 61.
6. Add a default: `always @(*) begin y = 0; case (op) 2'b00: y = a; 2'b01: y = b; default: y = 0; endcase end` (either the top default or the `default:` alone is enough).
7. 300 doesn't fit in 8 bits: s = 300 − 256 = **44**. Use `wire [8:0] s = a + b;` (9 bits) or catch the carry with `{cout, s}`.

</details>

---

**Next:** [Lesson 5 — Sequential Logic and Clocks](05_sequential_logic_and_clocks.md)
