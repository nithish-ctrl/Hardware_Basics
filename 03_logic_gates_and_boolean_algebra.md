# Lesson 3 — Logic Gates and Boolean Algebra

> **Why this matters for your GPU:** every adder, comparator, multiplexer and decoder in your GPU is built from logic gates. Boolean algebra is the math that lets you design them, simplify them and prove them correct. Here you'll go from truth tables to a working full adder: the first piece of the GPU's ALU.

---

## 3.1 Logic Gates

A gate takes 1-bit inputs and produces a 1-bit output. A **truth table** lists the output for every possible input combination. With n inputs there are 2ⁿ rows.

| a | b | AND `a & b` | OR `a \| b` | XOR `a ^ b` | NAND `~(a & b)` | NOR `~(a \| b)` | XNOR `~(a ^ b)` |
|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| 0 | 1 | 0 | 1 | 1 | 1 | 0 | 0 |
| 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 |
| 1 | 1 | 1 | 1 | 0 | 0 | 0 | 1 |

And NOT: `~a` flips the bit.

**How to remember them in plain words:**
- **AND:** 1 only if *all* inputs are 1. ("both")
- **OR:** 1 if *any* input is 1. ("at least one")
- **XOR:** 1 if the inputs *differ*. Equivalently, 1 if an *odd number* of inputs are 1. ("exactly one", or parity)
- **NAND / NOR / XNOR:** the opposite of AND / OR / XOR.
- **XNOR:** 1 if the inputs are *equal*. That's a 1-bit equality checker!

In math notation you'll see: AND = a·b (or ab), OR = a + b, NOT = ā or ¬a, XOR = a ⊕ b. **Careful:** "+" here means OR, not addition.

**Verilog operators** on multi-bit values work bit by bit: `4'b1100 & 4'b1010 = 4'b1000`.

**Reduction operators** squash a whole vector into one bit: `&x` (all bits 1?), `|x` (any bit 1?), `^x` (odd number of 1s? that's parity). Example: `|count` is "count is not zero".

---

## 3.2 Boolean Algebra: the Laws

These laws let you rewrite logic without changing what it does. Each one can be **proved by checking every row of a truth table** (with 1 or 2 variables that's only 2 or 4 rows).

| Law | AND form | OR form |
|---|---|---|
| Identity | a · 1 = a | a + 0 = a |
| Null (domination) | a · 0 = 0 | a + 1 = 1 |
| Idempotent | a · a = a | a + a = a |
| Complement | a · ā = 0 | a + ā = 1 |
| Double negation | ¬¬a = a | |
| Commutative | a · b = b · a | a + b = b + a |
| Associative | (a·b)·c = a·(b·c) | (a+b)+c = a+(b+c) |
| Distributive | a·(b + c) = a·b + a·c | a + b·c = (a + b)·(a + c) ← surprising, but true |
| Absorption | a·(a + b) = a | a + a·b = a |
| **De Morgan** | ¬(a·b) = ā + b̄ | ¬(a + b) = ā · b̄ |

### Proving De Morgan's law with a truth table

Claim: ¬(a·b) = ā + b̄.

| a | b | a·b | ¬(a·b) | ā | b̄ | ā + b̄ |
|---|---|---|---|---|---|---|
| 0 | 0 | 0 | **1** | 1 | 1 | **1** |
| 0 | 1 | 0 | **1** | 1 | 0 | **1** |
| 1 | 0 | 0 | **1** | 0 | 1 | **1** |
| 1 | 1 | 1 | **0** | 0 | 0 | **0** |

The two bold columns are identical for every input, so the expressions are equal. ∎

**In words:** "not (both)" = "at least one is not". "Not (either)" = "neither". **To push a NOT through a gate: flip AND↔OR and invert each input.**

### Simplifying with algebra: a worked example

Simplify `f = a·b + a·b̄`:

```
f = a·b + a·b̄
  = a·(b + b̄)        distributive (factor out a)
  = a·1              complement: b + b̄ = 1
  = a                identity
```

So that whole expression is just the wire `a`. Simpler logic means fewer gates, less delay and less power.

---

## 3.3 From a Truth Table to a Circuit (Sum of Products)

Any truth table can be turned into a circuit mechanically:

1. Find every row where the output is 1.
2. For each such row, write an AND term that is 1 **only** on that row: use the variable if it's 1 in that row, and its negation if it's 0. This is called a **minterm**.
3. OR all those terms together.

The result is a **sum of products (SOP)**. It proves that **any** logic function can be built from AND, OR and NOT.

### Worked example: designing the full adder

A **full adder** adds three bits: a, b and a carry-in (cin) from the previous column. The result is 0–3, so it needs 2 bits: **sum** (the 1s place) and **cout** (carry-out, the 2s place).

| a | b | cin | total | cout | sum |
|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 | 0 |
| 0 | 0 | 1 | 1 | 0 | 1 |
| 0 | 1 | 0 | 1 | 0 | 1 |
| 0 | 1 | 1 | 2 | 1 | 0 |
| 1 | 0 | 0 | 1 | 0 | 1 |
| 1 | 0 | 1 | 2 | 1 | 0 |
| 1 | 1 | 0 | 2 | 1 | 0 |
| 1 | 1 | 1 | 3 | 1 | 1 |

**sum:** it's 1 in rows 001, 010, 100 and 111, which are exactly the rows with an *odd* number of 1s. That's XOR:

```
sum = a ⊕ b ⊕ cin
```

(The SOP method gives `ā·b̄·cin + ā·b·c̄in + a·b̄·c̄in + a·b·cin`, which simplifies to the XOR. Recognizing patterns like "odd number of ones = XOR" saves a lot of work.)

**cout:** it's 1 in rows 011, 101, 110 and 111, meaning "at least two inputs are 1" (the **majority** function). SOP:

```
cout = ā·b·cin + a·b̄·cin + a·b·c̄in + a·b·cin
```

Simplify with algebra. Note `a·b·cin` can be used more than once (idempotent: x = x + x):

```
cout = (a·b·c̄in + a·b·cin) + (ā·b·cin + a·b·cin) + (a·b̄·cin + a·b·cin)
     = a·b·(c̄in + cin)     + b·cin·(ā + a)     + a·cin·(b̄ + b)
     = a·b + b·cin + a·cin
```

An equivalent form that reuses the XOR already computed for sum:

```
cout = a·b + cin·(a ⊕ b)
```

(Check: if a and b are both 1, cout = 1. If exactly one of them is 1 (a⊕b = 1), cout = cin. If neither, cout = 0. Matches the table.)

### Karnaugh maps (K-maps): a visual shortcut

A K-map lays the truth table on a grid where neighbouring cells differ in exactly one input bit (Gray-code order: 00, 01, 11, 10). Groups of adjacent 1s (in sizes 1, 2, 4, 8 …) become simplified product terms.

cout as a K-map (rows: a, columns: b cin):

```
            b cin
           00  01  11  10
         ┌───┬───┬───┬───┐
   a = 0 │ 0 │ 0 │ 1 │ 0 │
         ├───┼───┼───┼───┤
   a = 1 │ 0 │ 1 │ 1 │ 1 │
         └───┴───┴───┴───┘
```

Three groups of two (each pair of adjacent 1s):
- The column `b cin = 11` (both rows): b·cin
- Row a=1, columns 01 and 11: a·cin
- Row a=1, columns 11 and 10: a·b

Result: `cout = a·b + b·cin + a·cin`, the same as the algebra gave.

**Honest note:** you will rarely simplify logic by hand in practice. Synthesis tools (like Yosys) do it automatically and better. But knowing how it works lets you predict what your code will cost and read what the tools produce.

---

## 3.4 Universal Gates: Everything From NAND

NAND alone can build every other gate. That matters because NAND is the cheapest gate in CMOS (Lesson 1).

```
NOT a     = NAND(a, a)                      ¬(a·a) = ā
a AND b   = NOT(NAND(a, b))                 = NAND(NAND(a,b), NAND(a,b))
a OR b    = NAND(NOT a, NOT b)              by De Morgan: ¬(ā·b̄) = a + b
```

### XOR from four NANDs

```
n1 = NAND(a, b)
n2 = NAND(a, n1)
n3 = NAND(b, n1)
y  = NAND(n2, n3)        = a XOR b
```

Why it works, row by row:

| a | b | n1 = ¬(ab) | n2 = ¬(a·n1) | n3 = ¬(b·n1) | y = ¬(n2·n3) |
|---|---|---|---|---|---|
| 0 | 0 | 1 | 1 | 1 | **0** |
| 0 | 1 | 1 | 1 | 0 | **1** |
| 1 | 0 | 1 | 0 | 1 | **1** |
| 1 | 1 | 0 | 1 | 1 | **0** |

The y column is exactly XOR ✓.

---

## 3.5 Gates in Verilog

Verilog describes the same circuits in text. `assign` creates a continuous connection: the output **always** equals the expression, just like a real gate whose output follows its inputs.

`code/03_logic_gates/full_adder.v`:

```verilog
// full_adder.v: adds three 1-bit inputs (a + b + carry-in) -> 2-bit result {cout, sum}
module full_adder (
  input  wire a,
  input  wire b,
  input  wire cin,
  output wire sum,
  output wire cout
);
  assign sum  = a ^ b ^ cin;                    // odd number of 1s -> sum bit is 1
  assign cout = (a & b) | (cin & (a ^ b));      // carry if at least two inputs are 1
endmodule

// xor_from_nand.v: XOR built only from NAND gates (NAND is "universal")
module xor_from_nand (
  input  wire a,
  input  wire b,
  output wire y
);
  wire n1 = ~(a & b);        // NAND(a, b)
  wire n2 = ~(a & n1);       // NAND(a, n1)
  wire n3 = ~(b & n1);       // NAND(b, n1)
  assign y = ~(n2 & n3);     // NAND(n2, n3) = a XOR b
endmodule
```

Key points:
- `module ... endmodule` is one hardware block. Its ports (`input`, `output`) are its pins.
- `wire` is a connection. `wire n1 = ~(a & b);` declares a wire and connects it to a NAND gate in one line.
- The order of `assign` statements **does not matter**. These are not steps executed in order. They're descriptions of gates that all exist at the same time. (This is the #1 mindset shift from software.)

### The testbench: proving it works for every input

A **testbench** is Verilog code that isn't hardware. It's a test program that drives inputs and checks outputs. With only 3 inputs, we can test all 2³ = 8 combinations. That's **exhaustive testing**, the strongest possible check.

`code/03_logic_gates/tb_logic.v`:

```verilog
// tb_logic.v: prints truth tables and checks them against arithmetic.
// Run: iverilog -o logic.vvp full_adder.v tb_logic.v && vvp -n logic.vvp
`timescale 1ns/1ps
module tb_logic;
  reg a, b, cin;
  wire sum, cout, x;
  integer i, errors = 0;

  full_adder    u_fa  (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
  xor_from_nand u_xor (.a(a), .b(b), .y(x));

  initial begin
    $display(" a b cin | cout sum | as a number");
    $display("---------+----------+------------");
    for (i = 0; i < 8; i = i + 1) begin
      {a, b, cin} = i;           // the 3 low bits of i become the 3 inputs
      #1;                        // let the combinational logic settle
      $display(" %b %b  %b  |   %b   %b  |  %0d + %0d + %0d = %0d",
               a, b, cin, cout, sum, a, b, cin, {cout, sum});
      if ({cout, sum} !== a + b + cin) errors = errors + 1;
      if (x !== (a ^ b)) errors = errors + 1;
    end
    if (errors == 0) $display("PASS: full adder and NAND-only XOR are correct for all inputs");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
```

Run it (Lesson 12 explains the tools in detail):

```
cd hardware_basics\code\03_logic_gates
iverilog -o logic.vvp full_adder.v tb_logic.v
vvp -n logic.vvp
```

Output:

```
 a b cin | cout sum | as a number
---------+----------+------------
 0 0  0  |   0   0  |  0 + 0 + 0 = 0
 0 0  1  |   0   1  |  0 + 0 + 1 = 1
 0 1  0  |   0   1  |  0 + 1 + 0 = 1
 0 1  1  |   1   0  |  0 + 1 + 1 = 2
 1 0  0  |   0   1  |  1 + 0 + 0 = 1
 1 0  1  |   1   0  |  1 + 0 + 1 = 2
 1 1  0  |   1   0  |  1 + 1 + 0 = 2
 1 1  1  |   1   1  |  1 + 1 + 1 = 3
PASS: full adder and NAND-only XOR are correct for all inputs
```

Testbench tricks used here:
- `{a, b, cin} = i;` **concatenation**: splits the 3 low bits of i across three 1-bit signals.
- `#1;` waits 1 time unit so the gates "settle" before we look at them.
- `!==` compares including the unknown value `x`, so an undriven output counts as a failure instead of silently passing.
- The check uses **arithmetic** (`a + b + cin`) as the reference model. It's a completely different description of the same thing, so a mistake in the gates can't hide.

---

## 3.6 How This Connects to the GPU

- The full adder is the cell repeated 32 times inside every 32-bit adder in each ALU lane of your GPU (Lesson 4 chains them).
- XNOR + AND-reduce is an equality comparator. Your GPU's coalescing unit (main guide, Part 15.8) compares addresses with exactly this.
- On an FPGA, gates don't exist as separate parts. Everything becomes **look-up tables (LUTs)**: tiny memories storing a truth table. A 6-input LUT can implement *any* 6-input truth table. So on an FPGA, "cost" means "how many LUTs", which roughly means how many inputs each output depends on.

---

## Exercises

1. Write the truth table for `f = a·b̄ + ā·b`. Which gate is it?
2. Use De Morgan to rewrite `¬(a + b + c)` with only ANDs and NOTs.
3. Simplify `f = a·b + a·b·c + a·b̄`. (Hint: absorption, then the complement law.)
4. Build OR from NAND gates only, and check it with a 4-row truth table.
5. Write the truth table for a 3-input **majority** gate. What expression did we already derive for it?
6. In Verilog, what is `4'b1011 ^ 4'b0110`? What is `^4'b1011` (reduction XOR)?
7. How many rows does an exhaustive test of a 16-bit + 16-bit adder need? Is that practical in simulation? What about 32-bit + 32-bit?

<details>
<summary><b>Answers</b></summary>

1. Rows (a,b) → f: 00→0, 01→1, 10→1, 11→0. It's **XOR**.
2. `¬(a + b + c) = ā · b̄ · c̄`.
3. `a·b + a·b·c = a·b` (absorption). Then `a·b + a·b̄ = a·(b + b̄) = a`. So **f = a**.
4. `OR(a,b) = NAND(NAND(a,a), NAND(b,b))`. Rows: 00 → NAND(1,1) = 0. 01 → NAND(1,0) = 1. 10 → 1. 11 → NAND(0,0) = 1 ✓.
5. Output 1 when at least two inputs are 1: rows 011, 101, 110, 111. It's the full adder's carry: `a·b + b·c + a·c`.
6. `1011 ^ 0110 = 1101`. `^1011` = 1⊕0⊕1⊕1 = **1** (three 1s: odd).
7. 2³² ≈ 4.3 billion. At about a million tests per second in a simulator, that's over an hour: possible, but slow. 32+32 bits = 2⁶⁴ ≈ 1.8×10¹⁹: **impossible** (centuries). That's why big blocks use **random testing** plus carefully chosen corner cases, or **formal proofs** (main guide, Part 8).

</details>

---

**Next:** [Lesson 4 — Combinational Circuits](04_combinational_circuits.md)
