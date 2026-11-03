# Lesson 5 — Sequential Logic: Memory, Flip-Flops and Clocks

> **Why this matters for your GPU:** a GPU must *remember* things: each warp's program counter, every thread's registers, which warps are busy, pipeline stage contents. All of that is stored in **flip-flops** that update on the **clock edge**. This lesson explains how a circuit can remember, what a clock edge really does, and the timing math that sets your GPU's maximum clock speed.

---

## 5.1 How Can a Circuit Remember Anything?

Combinational logic forgets: its output only depends on the current input. To remember, you need **feedback**: an output that loops back to an input.

### The simplest memory: two inverters in a loop

```
     ┌──────[NOT]──────┐
     │                 │
     └──────[NOT]◄─────┘
```

If the top wire is 1, the first NOT makes the bottom 0, and the second NOT makes the top 1 again. It's stable. Same for 0. It holds one bit forever (while powered). But there's no way to *change* it. We need inputs.

### The SR latch (Set/Reset), made from two NOR gates

```
            ┌───────┐
  R ───────►│       │
            │  NOR  ├───┬──────► Q
       ┌───►│       │   │
       │    └───────┘   │
       │                │      each gate's OUTPUT is wired to
       │    ┌───────┐   │      the OTHER gate's INPUT (feedback)
       │    │       │◄──┘
       └────┤  NOR  │
            │       │◄──────── S
            └───────┘
          (this gate's output is Q̄, the opposite of Q)
```

Walk through it: with S = 1, the bottom NOR outputs 0 (any 1 input makes NOR output 0). That 0 feeds the top NOR along with R = 0, so it outputs 1: **Q = 1 (set)**. Now drop S back to 0: the bottom NOR sees Q = 1, so it still outputs 0, and the top NOR still outputs 1. **The loop holds the 1 by itself.**

| S | R | Q next | Meaning |
|---|---|---|---|
| 0 | 0 | Q (unchanged) | **hold**: remembers |
| 1 | 0 | 1 | set |
| 0 | 1 | 0 | reset |
| 1 | 1 | invalid | don't do this |

That's a 1-bit memory with controls. Every memory element is a refinement of this feedback idea.

### The D latch: "while enable is 1, follow D"

Adding a little logic in front of the SR latch gives a **D latch**: when `en = 1`, Q follows D (it's "transparent"); when `en = 0`, Q holds its last value.

Problem: while `en = 1`, any change on D flows straight through, possibly around a loop and back again many times. Timing becomes hard to reason about. We want changes to happen at **one instant**.

---

## 5.2 The D Flip-Flop: Memory That Updates at One Instant

A **D flip-flop (DFF)** samples its D input **only at the rising edge of the clock** and holds that value until the next rising edge. (Internally it's two latches in series, enabled on opposite clock phases: "master-slave". You don't need the internals, just the behavior.)

```
         ┌──────┐
   D ────┤D    Q├──── Q
         │      │
  clk ───┤>     │       ">" means: edge-triggered on the clock
         └──────┘
```

```
clk   ──┐_┌─┐_┌─┐_┌─┐_┌─┐_┌─
         ↑   ↑   ↑   ↑   ↑        rising edges
D     ───XXX111XXXX000XXX111────   (D can do anything between edges)
Q     ──────111111111000000111     Q changes ONLY at edges, to the value D had right then
```

**The key mental model:** a flip-flop is a camera that takes a photo of D at each rising edge, and Q shows the latest photo.

In Verilog:

```verilog
always @(posedge clk)     // "at every rising edge of clk..."
  q <= d;                  // "...q takes the value of d"  (<= is explained in Lesson 6)
```

A **register** is just N flip-flops sharing a clock: `reg [31:0] q;` with the same code gives 32 flip-flops.

---

## 5.3 The Synchronous Design Pattern

Almost all digital chips are built like this:

```
      ┌─────────┐      ┌──────────────────┐      ┌─────────┐
 ────►│ flip-   │─────►│  combinational   │─────►│ flip-   │────►
      │ flops   │      │  logic (gates)   │      │ flops   │
 clk ►│         │      └──────────────────┘ clk ►│         │
      └─────────┘                                └─────────┘
       state now           compute next            state next cycle
```

At each rising edge, every flip-flop captures its input **at the same instant**. Between edges, the combinational logic computes the next values. Then the next edge captures them. Repeat.

This is why it's called **register-transfer level (RTL)** design: you describe what gets computed from registers and transferred into registers at each clock edge.

### Building blocks with feedback through logic

**Register with enable:** a mux in front of the flip-flop chooses "new value" or "keep old value".

```
          ┌───────┐
  d ──────┤1      │    ┌────┐
          │  MUX  ├───►┤D  Q├──┬── q
      ┌───┤0      │    │>   │  │
      │   └───┬───┘    └────┘  │
      │      en                │
      └────────────────────────┘     (when en = 0 the flop re-captures its own output)
```

**Counter:** a register whose next value is "itself + 1". The adder sits in the feedback loop.

```
   ┌──────────────┐
   └─►[ +1 ]──►[D  Q]──┬── count
               clk     │
   ▲───────────────────┘
```

**Shift register:** a chain of flip-flops. Each edge, every bit moves one place along.

```
serial_in ──►[DFF]──►[DFF]──►[DFF]──►[DFF]
              q0      q1      q2      q3
```

---

## 5.4 Reset

When power comes on, flip-flops hold random values. A **reset** input forces them to a known state.

- **Synchronous reset:** takes effect at the next clock edge (`if (rst)` inside `always @(posedge clk)`). Simple and safe. The style used in this project.
- **Asynchronous reset:** takes effect immediately, even without a clock (`always @(posedge clk or posedge rst)`). Common in ASICs.

**Rule of thumb:** reset *control* state (valid bits, FSM states, counters, program counters). Pure data registers often don't need a reset. Notice that in the GPU core, `active`, `busy` and `pend` are reset, but the register file isn't. And that's exactly why random programs had to initialize their registers (main guide, "Lessons From Actually Debugging This Code").

---

## 5.5 The Code: a Register, a Counter and a Shift Register

`code/05_sequential/seq_basics.v`:

```verilog
// seq_basics.v: circuits WITH memory. They only change on the rising clock edge.

// An 8-bit register with synchronous reset and enable
module register8 (
  input  wire       clk,
  input  wire       rst,     // when 1 at a clock edge: q becomes 0
  input  wire       en,      // when 1 at a clock edge: q captures d
  input  wire [7:0] d,
  output reg  [7:0] q
);
  always @(posedge clk) begin
    if (rst)     q <= 8'd0;
    else if (en) q <= d;
    // else: q keeps its value (that is what "memory" means)
  end
endmodule

// A 4-bit counter: 0, 1, 2, ... 15, 0, 1, ... (wraps around, because 15 + 1 = 16 needs 5 bits)
module counter4 (
  input  wire       clk,
  input  wire       rst,
  output reg  [3:0] count
);
  always @(posedge clk) begin
    if (rst) count <= 4'd0;
    else     count <= count + 4'd1;
  end
endmodule

// A 4-bit shift register: each edge, every bit moves one place and a new bit enters
module shift_reg4 (
  input  wire       clk,
  input  wire       rst,
  input  wire       serial_in,
  output reg  [3:0] q
);
  always @(posedge clk) begin
    if (rst) q <= 4'b0000;
    else     q <= {q[2:0], serial_in};   // drop the top bit, append the new one at the bottom
  end
endmodule
```

The testbench drives the inputs cycle by cycle and prints what each circuit holds **just after** each clock edge:

`code/05_sequential/tb_seq.v`:

```verilog
// tb_seq.v: prints a cycle-by-cycle table. Compare each row with the lesson's hand-drawn table.
// Run: iverilog -o seq.vvp seq_basics.v tb_seq.v && vvp -n seq.vvp   (then: gtkwave seq.vcd)
`timescale 1ns/1ps
module tb_seq;
  reg clk = 0;
  always #5 clk = ~clk;             // period 10 ns -> 100 MHz

  reg        rst = 1, en = 0, sin = 0;
  reg  [7:0] d = 0;
  wire [7:0] q;
  wire [3:0] count, sq;

  register8  u_reg (.clk(clk), .rst(rst), .en(en), .d(d), .q(q));
  counter4   u_cnt (.clk(clk), .rst(rst), .count(count));
  shift_reg4 u_sh  (.clk(clk), .rst(rst), .serial_in(sin), .q(sq));

  // Stimulus: what each input is during each cycle (changed just after each rising edge)
  //           cycle:   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19
  reg [19:0] rst_seq = 20'b0000_0000_0000_0000_0011;   // bit k = value in cycle k (cycles 0,1 in reset)
  reg [19:0] en_seq  = 20'b0000_0000_0000_0011_0100;   // enable in cycles 2, 4, 5
  reg [19:0] sin_seq = 20'b0000_0000_0000_0010_1100;   // serial bits 1,1,0,1 in cycles 2..5
  integer cyc;

  initial begin
    $dumpfile("seq.vcd");
    $dumpvars(0, tb_seq);
    $display("cyc | rst en d   sin || after the edge: q(reg) count shift");
    $display("----+------------------++-------------------------------");
    for (cyc = 0; cyc < 20; cyc = cyc + 1) begin
      rst = rst_seq[cyc]; en = en_seq[cyc]; sin = sin_seq[cyc];
      d   = 8'd10 * cyc;                     // d changes every cycle: 0, 10, 20, ...
      @(posedge clk); #1;                    // the edge happens; look 1 ns later
      $display("%3d |  %b   %b %3d   %b  ||      %3d       %2d    %b",
               cyc, rst, en, d, sin, q, count, sq);
    end
    $display("Notice: q only changes in cycles where en=1, count wraps 15 -> 0, bits march through 'shift'.");
    $finish;
  end
endmodule
```

```
cd hardware_basics\code\05_sequential
iverilog -o seq.vvp seq_basics.v tb_seq.v
vvp -n seq.vvp
```

Output:

```
cyc | rst en d   sin || after the edge: q(reg) count shift
----+------------------++-------------------------------
  0 |  1   0   0   0  ||        0        0    0000
  1 |  1   0  10   0  ||        0        0    0000
  2 |  0   1  20   1  ||       20        1    0001
  3 |  0   0  30   1  ||       20        2    0011
  4 |  0   1  40   0  ||       40        3    0110
  5 |  0   1  50   1  ||       50        4    1101
  6 |  0   0  60   0  ||       50        5    1010
  7 |  0   0  70   0  ||       50        6    0100
  8 |  0   0  80   0  ||       50        7    1000
  9 |  0   0  90   0  ||       50        8    0000
 ...
 16 |  0   0 160   0  ||       50       15    0000
 17 |  0   0 170   0  ||       50        0    0000
```

### Read it row by row (do this carefully: it's the core skill)

- **Cycles 0–1:** rst = 1, so at each edge all three circuits are forced to 0.
- **Cycle 2:** en = 1 and d = 20, so the register captures **20**. The counter goes 0 → 1. The shift register takes in sin = 1: `0001`.
- **Cycle 3:** en = 0, so the register **keeps** 20, even though d = 30. That's memory! The shift register: `0001` shifts left and takes in 1: `0011`.
- **Cycle 4:** en = 1, so it captures 40. Shift: `0011` → `0110` (new bit 0).
- **Cycle 5:** captures 50. Shift: `0110` → `1101`.
- **Cycles 6–9:** the shift register keeps shifting in 0s, and the `1101` pattern marches out of the top: `1010`, `0100`, `1000`, `0000`.
- **Cycle 17:** the 4-bit counter wraps: 15 + 1 = 16 = `1_0000`, and the 5th bit doesn't fit, so it shows 0 (modulo 2⁴, Lesson 2).

**Look at the waveform too:** run `gtkwave seq.vcd` and add `clk`, `en`, `d`, `q`, `count`. Lesson 12 shows how.

---

## 5.6 Timing: Setup, Hold and the Maximum Clock Speed

A flip-flop needs D to be **stable for a short time around the edge**:

- **Setup time (t_su):** D must be stable this long **before** the edge.
- **Hold time (t_h):** D must stay stable this long **after** the edge.
- **Clock-to-Q (t_cq):** after the edge, Q takes this long to show the new value.

```
              setup  hold
              |<-->|<->|
clk  ________________|‾‾‾‾‾‾‾‾‾‾
D    =====XXXX[ stable  ]XXXXX====       D must not change inside the window
Q    ===================|<t_cq>|=== new value
```

### The setup equation (THE timing formula)

Consider a path from flip-flop A, through combinational logic, to flip-flop B:

```
[FF A] ──► (logic: t_logic) ──► [FF B]
```

After a clock edge, A's output changes at t_cq. The signal then travels through the logic (t_logic), and must arrive at B at least t_su before the **next** edge. So:

```
T_clk  ≥  t_cq  +  t_logic  +  t_su

f_max  =  1 / (t_cq + t_logic,max + t_su)
```

### Worked example

t_cq = 0.4 ns, t_su = 0.1 ns, and the slowest path through the logic is 6.5 ns:

```
T_min = 0.4 + 6.5 + 0.1 = 7.0 ns   →   f_max = 1 / 7.0 ns ≈ 143 MHz
```

If you want 200 MHz (5 ns), the logic must take ≤ 5 − 0.5 = **4.5 ns**. The slowest path is called the **critical path**. The design tools report it, along with **slack** = required time − actual time (negative slack means "fails timing": it will malfunction at that clock speed).

### How to make a design faster

The main trick is **pipelining**: put flip-flops in the middle of a long path, so each piece has a full clock period. Lesson 6 covers it with numbers. This is why real GPU ALUs take several cycles per operation, and why the GPU core has 3 pipeline stages.

### Metastability (a warning)

If D changes *inside* the setup/hold window (which happens when a signal comes from outside, like a button, or from a different clock), the flip-flop can get stuck "between" 0 and 1 for a while. This is **metastability**. The standard fix is to pass such signals through **two flip-flops in a row** (a synchronizer), giving the first one a whole cycle to settle. Main guide, Part 1.7 and 11.3.

---

## 5.7 How This Connects to the GPU

In `gpu_project/rtl/gpu_core.sv`:

- `pc[w]`, `mask[w]`, `active`, `busy`: **registers** (per-warp state). They change only on clock edges.
- `rf`: the **register file**. Thousands of bits of flip-flops (or RAM) holding every thread's registers.
- `s1_*`, `s2_*`: **pipeline registers** between stages. They hold an instruction's information as it moves through the pipeline, one stage per cycle.
- `perf_cycles <= perf_cycles + 1`: a **counter**, exactly like `counter4`.

---

## Exercises

1. A flip-flop's D input is 1 before the edge and changes to 0 a long time after the edge. What does Q show after this edge?
2. In the testbench output, why does q stay 20 in cycle 3 even though d = 30?
3. An 8-bit counter starts at 250. What does it show after 10 clock edges?
4. Design (in words or Verilog) a register that *adds* its input to itself every cycle when `en = 1` (an **accumulator**).
5. t_cq = 0.3 ns, t_su = 0.2 ns, critical path = 4.5 ns. What's f_max? If you split the path into two equal halves with a flip-flop in between, what's the new f_max?
6. Why can't you fix a *hold* violation by slowing down the clock? (Hint: look at which edge the hold check uses.)

<details>
<summary><b>Answers</b></summary>

1. **1**. Q captures D's value at the edge. Changes after the edge only matter at the *next* edge.
2. Because en = 0 in cycle 3. The mux in front of the flop selects "keep old value", so it re-captures 20.
3. 250 + 10 = 260, modulo 256 = **4**.
4. `always @(posedge clk) if (rst) acc <= 0; else if (en) acc <= acc + d;`. The adder is in the feedback loop, like the counter, but adding `d` instead of 1.
5. T = 0.3 + 4.5 + 0.2 = 5.0 ns → **200 MHz**. Split: T = 0.3 + 2.25 + 0.2 = 2.75 ns → **≈364 MHz**. (Not 2×, because the flip-flop overhead t_cq + t_su is paid in every stage.)
6. Hold compares the data change against the **same** edge that launched it (did the new data arrive too *soon*?). The clock period isn't part of that equation, so changing it doesn't help. Tools fix hold problems by adding delay to short paths.

</details>

---

**Next:** [Lesson 6 — Thinking in Clock Cycles: Blocking vs Non-Blocking, Pipelines, FSMs, Handshakes](06_thinking_in_cycles_fsms_handshakes.md)
