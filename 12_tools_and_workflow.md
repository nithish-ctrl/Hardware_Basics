# Lesson 12 — Tools and Workflow: Simulating, Reading Waveforms, Debugging

> **Why this matters for your GPU:** you'll spend far more time *testing and debugging* hardware than writing it. This lesson explains what each tool does, how a testbench is built, how to read a waveform, and a step-by-step debugging method, so you can run and understand everything in `gpu_project/` and in these lessons.

---

## 12.1 The Two Lives of Verilog Code

The same Verilog file can go two places:

```
                     ┌──► SIMULATION (Icarus, Verilator)
your .v / .sv files ─┤      runs the code on your PC to check behaviour. Fast to iterate.
                     │      Can use testbench-only features: $display, #delays, files.
                     │
                     └──► SYNTHESIS (Yosys, Vivado) → place & route (nextpnr) → bitstream
                            turns the code into real gates/LUTs on an FPGA.
                            Only the "synthesizable" subset is allowed.
```

**Workflow:** simulate until it's correct, *then* synthesize. Debugging on a real FPGA is much harder: you can't see inside it.

| Tool | Role | Used in this course |
|---|---|---|
| **Icarus Verilog** (`iverilog` + `vvp`) | Event-driven simulator | Every example |
| **Verilator** (`verilator_bin --lint-only`) | Fast simulator + strict code checker ("linter") | Checking code for mistakes |
| **GTKWave** | Waveform viewer | Looking at signals over time |
| **Yosys** | Synthesis | Main guide, Part 9 |
| **Python** | Reference models, assemblers, test generators | `numbers_lab.py`, `gpuemu.py`, `cosim.py`, … |

---

## 12.2 Setting Up a PowerShell Window

The tools live in `D:\Downloads\Hardware\tools\oss-cad-suite`. In **each new PowerShell window**:

```powershell
. D:\Downloads\Hardware\tools\oss-cad-suite\environment.ps1
$env:VERILATOR_ROOT = "$env:YOSYSHQ_ROOT\share\verilator"
```

The leading `. ` (dot, space) runs the script *inside* the current window, so its PATH changes stick. The prompt changes to `[OSS CAD Suite]` when it worked.

Then run every example in this folder at once:

```powershell
cd D:\Downloads\Hardware\GPU\hardware_basics
.\run_all.ps1
```

---

## 12.3 Compiling and Running a Simulation

Two steps:

```
iverilog -g2012 -o sim.vvp design.v tb.v     # 1. compile: check syntax, build a simulation program
vvp -n sim.vvp                               # 2. run it (-n: don't wait for keyboard input at the end)
```

- `-o sim.vvp` names the output file.
- List **all** the files the design needs (a module used but not listed gives "Unknown module type").
- `-g2012` enables SystemVerilog features (needed for `.sv` files).
- To change a parameter without editing the file: `-Ptb_cosim.NUM_WARPS=8`.

**Reading compile messages:**
- `error:` must be fixed. The line number is given: go there.
- `warning:` read it! Width mismatches and implicit wires are real bugs half the time.
- `sorry: constant selects in always_* processes are not fully supported`: harmless Icarus note (it just re-evaluates a bit more often).

---

## 12.4 Anatomy of a Testbench

A testbench is a top-level module **with no ports**. It creates the design under test (**DUT**), drives its inputs, and checks its outputs.

```verilog
`timescale 1ns/1ps                 // "#1" means 1 ns; times are tracked to 1 ps precision
module tb_example;                 // no ports: this is the whole world

  // 1. CLOCK: toggle every 5 ns -> 10 ns period -> 100 MHz
  reg clk = 0;
  always #5 clk = ~clk;

  // 2. SIGNALS that connect to the DUT
  reg        rst = 1;              // inputs we drive: reg
  wire [3:0] count;                // outputs we observe: wire

  // 3. THE DUT
  counter4 dut (.clk(clk), .rst(rst), .count(count));

  // 4. STIMULUS + CHECKS: runs once, top to bottom, waiting where told
  initial begin
    $dumpfile("wave.vcd");         // record every signal for GTKWave
    $dumpvars(0, tb_example);

    repeat (2) @(posedge clk);     // wait 2 rising edges
    rst <= 0;                      // release reset (<= : change right after the edge, no race)
    repeat (5) @(posedge clk);
    #1;                            // look 1 ns after the edge, once outputs have updated
    if (count !== 4'd5) $display("FAIL: count=%0d", count);
    else                $display("PASS");
    $finish;                       // end the simulation
  end
endmodule
```

### Useful testbench commands

| Command | Does |
|---|---|
| `#10;` | Wait 10 time units |
| `@(posedge clk);` | Wait for the next rising edge |
| `repeat (N) @(posedge clk);` | Wait N edges |
| `do @(posedge clk); while (!done);` | Wait until `done` is seen **at a clock edge** (safer than `wait(done)`) |
| `$display("x=%0d y=%h", x, y);` | Print (`%d` decimal, `%h` hex, `%b` binary, `%0d` = no padding) |
| `$readmemh("f.hex", mem);` / `$writememh` | Load / save a memory from/to a text file |
| `$random` / `$urandom` | Random numbers |
| `$finish;` | Stop |

### The `===` / `!==` operators

Simulation has 4 values per bit: 0, 1, **x** (unknown) and **z** (undriven). `a != b` returns x if either side has an x, and `if (x)` treats that as false, **hiding the bug**. `!==` compares x and z literally, so an x output counts as a mismatch. **Always use `!==` / `===` in checks.**

### Golden rules of good testbenches

1. **Self-checking:** print PASS/FAIL. Never rely on eyeballing numbers.
2. **A reference model written differently** (arithmetic instead of gates, Python instead of Verilog). If the model copies the design's logic, it copies its bugs.
3. **Exhaustive when small** (all inputs to a 4-bit adder), **random when big** (random programs for the GPU).
4. **Test the corners:** 0, maximum values, −1, wrap-around, full/empty, single element, nothing active.
5. **Prove your test can fail:** break the design on purpose and confirm the test catches it (the mutation test from the main guide).

---

## 12.5 Reading Waveforms in GTKWave

Tables printed by `$display` are great for a few signals. For timing questions ("why was this one cycle late?"), use a waveform.

```powershell
cd hardware_basics\code\05_sequential
vvp -n seq.vvp          # produces seq.vcd (because the testbench calls $dumpfile/$dumpvars)
gtkwave seq.vcd
```

In GTKWave:
1. Top-left panel (**SST**): click `tb_seq`. Its signals appear below.
2. Select `clk`, `rst`, `en`, `d`, `q`, `count` and click **Append** (or drag them into the Signals pane).
3. Click the **zoom-fit** button (magnifier with a square) to see the whole run.
4. Right-click a bus → **Data Format** → **Decimal** to read numbers instead of hex.
5. Click in the wave area to place the cursor. The values at that time show next to the names.

### How to read it

```
clk    ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
      ─┘ └─┘ └─┘ └─┘ └─┘ └─
en     ────────┐   ┌───────
               └───┘
d      ═[20 ]═[30 ]═[40 ]═[50 ]
q      ═[ 0 ]═[20 ]═[20 ]═[40 ]═[50 ]    ← q changes RIGHT AFTER rising edges, to the d value
                                           that was present JUST BEFORE that edge (when en=1)
```

**The single most important waveform skill:** to know what a register will hold after an edge, look at its inputs **just before** that edge. (That's the "camera photo" from Lesson 5.)

---

## 12.6 The Debugging Method (Use It Every Time)

1. **Reproduce** the failure with the smallest, simplest test you can (e.g. one warp, n = 3, instead of the whole suite).
2. **Find the FIRST wrong cycle.** Errors spread: a bad value in cycle 50 causes chaos in cycles 51–1000. Only the first one points at the cause.
3. **Trace backwards:** the wrong signal is computed from other signals. Which input to it was wrong? Repeat until you find a block whose inputs are right but whose output is wrong. **That's the bug.**
4. **Explain it** before fixing it. If you can't explain it, you haven't found it.
5. **Fix it, re-run everything**, and add a test that would have caught it.

### Real examples from building this course

| Symptom | How it was found | Cause |
|---|---|---|
| Tiny CPU stored the wrong sum | The instruction trace showed `ADD r0, r1` where `ADD r1, r0` was intended | Hand-encoded bits had the register fields swapped (Lesson 9) |
| GPU with 1 warp "finished" after 1 cycle | Printed `done` every cycle: the hardware never raised it | Testbench `wait(done)` caught a 0-width glitch |
| RTL memory shifted by one word | Compared the first mismatching addresses | `$writememh` adds `// 0x…` comment lines that the parser counted as data |
| Random programs gave `x` | Found the first `x`: a register read before any write | Hardware registers aren't reset; the test program must initialize them |

### Debug printing tricks

```verilog
// print every committed instruction of a GPU core (add inside a testbench, or as a separate module)
always @(posedge clk)
  if (dut.g_core[0].u_core.s2_v)
    $display("%0t warp=%0d op=%h mask=%b", $time,
             dut.g_core[0].u_core.s2_w, dut.g_core[0].u_core.s2_op, dut.g_core[0].u_core.m_cur);
```

`dut.g_core[0].u_core.s2_w` is a **hierarchical name**: a path down through instances to any internal signal. Testbenches may peek anywhere. (Real hardware can't, so never use these in synthesizable code.)

---

## 12.7 Linting: Let the Computer Find Mistakes First

```powershell
verilator_bin --lint-only -Wall my_module.v
```

Verilator checks the code without running it and warns about things like:

| Warning | Usually means |
|---|---|
| `WIDTHTRUNC` / `WIDTHEXPAND` | Sizes don't match: a value is silently cut or padded. Sometimes intended, often a bug |
| `LATCH` | A combinational block doesn't assign a signal on every path (Lesson 4) |
| `MULTIDRIVEN` | Two blocks assign the same signal |
| `UNUSEDSIGNAL` | A signal is never read: dead code, or a typo in a name |
| "syntax error, unexpected inside" | You used a reserved word (`inside`, `buf`, …) as a name |

Lint every module before you simulate it. It takes a second and catches whole classes of bugs.

---

## 12.8 How the Pieces of `gpu_project` Fit Together

```
 sw/vadd.s ──► gpuasm.py ──► vadd.hex ──► $readmemh into the GPU's instruction memory
                                              │
 tb/tb_gpu.sv  sets up memory, pulses start,  ▼
               waits for done ─────────► rtl/gpu_top.sv (cores + memory)
               prints PASS + cycle counts

 sim/cosim.py:
   for each test program (hand-written or randomly generated):
     1. assemble it                                  (gpuasm.py)
     2. run it on the Python golden model            (gpuemu.py)
     3. run it on the RTL in Icarus                  (tb_cosim.sv dumps memory to mem_out.hex)
     4. compare all 4096 memory words
```

That's the professional verification loop: a **golden model**, a **real design**, **automatic comparison** and **lots of random inputs**. Lessons 7 and 10 do miniature versions of it.

---

## Exercises

1. You get `error: Unknown module type: full_adder`. What did you forget?
2. Your check `if (y != 5) $display("FAIL");` never prints FAIL, but y is shown as `x` in the waveform. Why? Fix it.
3. In a waveform, a register changes from 3 to 4 at the edge at 45 ns. Where do you look to see why it became 4?
4. A big test fails at cycle 8,000. Describe your next three steps.
5. Why does the testbench drive inputs with `<=` right after a clock edge instead of exactly at the edge with `=`?

<details>
<summary><b>Answers</b></summary>

1. To list the file that defines it on the `iverilog` command line (e.g. `..\03_logic_gates\full_adder.v`).
2. `y != 5` with y = x evaluates to x, which `if` treats as false. Use `if (y !== 5)`. Then also find out why y is x (undriven? uninitialized?).
3. At the register's **inputs just before 45 ns**: its D input (the next-value expression), its enable, and its reset.
4. (1) Shrink the test until it fails as early and simply as possible. (2) Find the **first** cycle where any value differs from the model. (3) Trace that signal's inputs backwards until you reach a block with correct inputs and a wrong output.
5. If the testbench changes an input at the exact same instant as the clock edge, whether the DUT sees the old or the new value depends on simulator event ordering: a **race**. Changing it with `<=` (or 1 ns later) makes the DUT see it reliably at the *next* edge, just like real flip-flop-driven signals.

</details>

---

**Next:** [Lesson 13 — Glossary and Final Quiz](13_glossary_and_final_quiz.md)
