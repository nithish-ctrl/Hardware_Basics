# Lesson 13 — Glossary and Final Quiz

Use the glossary while reading the main guide. Take the quiz when you've finished Lessons 1–12: if you can answer at least 20 of the 25 questions without peeking, you're ready for the main guide's GPU parts.

---

## Glossary

| Term | Plain-language meaning | Lesson |
|---|---|---|
| **Active mask** | One bit per lane: which lanes of a warp currently participate | 10 |
| **ALU** | Arithmetic logic unit: the circuit that adds, subtracts, compares, shifts | 4, 9 |
| **Assembler** | Program that turns assembly text into instruction bits | 9 |
| **Bandwidth** | Bytes per second a memory can deliver | 7 |
| **Bank / bank conflict** | One of several memories accessed in parallel / two accesses needing the same bank in the same cycle | 7 |
| **Barycentric coordinates** | Three weights (summing to 1) saying where a point sits inside a triangle | 11 |
| **Bias (exponent)** | Offset (127 for FP32) added to a float's exponent so it can be stored unsigned | 2 |
| **Bit / byte / word** | 1 binary digit / 8 bits / a machine's natural data size (32 bits in your GPU) | 2 |
| **Blocking `=` / non-blocking `<=`** | Update immediately / update all together at the end of the time step | 6 |
| **BRAM** | Block RAM: dedicated memory blocks inside an FPGA, synchronous read | 7 |
| **Capacitance** | How much charge a wire or gate "bucket" holds; the reason gates have delay | 1 |
| **Clock / period / frequency** | Toggling heartbeat signal / time per cycle / cycles per second (f = 1/T) | 1, 5 |
| **Combinational logic** | Output depends only on current inputs; no memory | 4 |
| **Critical path** | The slowest path between flip-flops; it sets the maximum clock speed | 5 |
| **Decoder** | Turns a binary number into one-hot; also: the part of a CPU that splits instruction fields | 4, 9 |
| **Divergence** | Threads in one warp wanting different paths | 10 |
| **DSP block** | Hard multiplier inside an FPGA | 8 |
| **DUT** | Design under test | 12 |
| **Edge function** | Signed "which side of this edge" value used to rasterize triangles | 11 |
| **FIFO** | First-in-first-out queue between two blocks | 7 |
| **Fixed point (Qm.n)** | Integers interpreted with an implied binary point: n fraction bits | 2, 8 |
| **Flip-flop (DFF)** | 1-bit memory that captures its input at the clock edge | 5 |
| **Floating point** | ±1.mantissa × 2^exponent format (FP32: 1 + 8 + 23 bits) | 2, 8 |
| **FMA** | Fused multiply-add: a × b + c with one rounding. The GPU's main operation | 8 |
| **FPGA** | Chip of configurable logic and wiring: hardware you can reprogram | 1, 12 |
| **FSM** | Finite state machine: state register + next-state logic + output logic | 6 |
| **Glitch** | Brief wrong value while signals settle; harmless in synchronous design | 4 |
| **Handshake (valid/ready)** | Agreement to transfer data only in cycles where both are 1 | 6 |
| **Hex** | Base 16; 1 hex digit = 4 bits | 2 |
| **Homogeneous coordinates** | (x, y, z, w) form that lets translation and perspective be 4×4 matrices | 11 |
| **ISA** | Instruction set architecture: what instructions exist and how they're encoded | 9 |
| **Lane** | One ALU slot in a SIMD unit; runs one thread of a warp | 10 |
| **Latch** | Level-sensitive memory; usually created by accident by incomplete combinational code | 4, 5 |
| **Latency / throughput** | Time for one item / items finished per unit of time | 6 |
| **Latency hiding** | Running other warps while one waits for memory | 10 |
| **Lerp** | Linear interpolation a + (b − a)·t | 8 |
| **Lint** | Static check of code for likely mistakes | 12 |
| **Little's law** | In-flight items = latency × throughput | 10 |
| **LSB / MSB** | Least / most significant bit | 2 |
| **LSU** | Load/store unit: handles memory instructions | 10 |
| **LUT** | Look-up table: an FPGA's basic logic element (a tiny truth-table memory) | 3 |
| **Metastability** | A flip-flop stuck between 0 and 1 after its input changed too close to the edge | 5 |
| **Mux** | Multiplexer: selects one of several inputs. Hardware's "if" | 4 |
| **NDC** | Normalized device coordinates (−1..1) after the perspective divide | 11 |
| **One-hot** | Exactly one bit is 1 | 4 |
| **Overflow** | Result too large for its bit width | 2 |
| **PC** | Program counter: address of the current instruction | 9 |
| **Pipeline** | Splitting work into stages separated by registers to raise throughput | 6 |
| **Propagation delay** | Time for a change to travel through gates | 1, 4 |
| **Rasterization** | Finding which pixels a triangle covers | 11 |
| **Register / register file** | Group of flip-flops / array of registers an instruction reads and writes | 5, 7 |
| **Reset** | Signal forcing state to known values | 5 |
| **RTL** | Register-transfer level: describing hardware as registers + logic between them | 5 |
| **Setup / hold time** | How long a flip-flop's input must be stable before / after the edge | 5 |
| **Sign extension** | Widening a signed number by copying its sign bit | 2 |
| **SIMD / SIMT** | One instruction on many data lanes / the same, exposed as independent threads | 10 |
| **Slack** | Required time − actual time for a path; negative = fails timing | 5 |
| **Synthesis** | Converting RTL into gates/LUTs | 12 |
| **Testbench** | Non-hardware Verilog that drives and checks a design | 3, 12 |
| **Thread / thread ID** | One instance of the kernel program / its unique number | 10 |
| **Two's complement** | Standard signed-integer encoding: MSB has negative weight | 2 |
| **Warp** | Group of threads that execute together with one PC | 10 |
| **Z-buffer** | Per-pixel depth memory for hiding far surfaces | 11 |

---

## Final Quiz

### Physics and numbers
1. Why does a logic gate have a delay? What makes it longer?
2. What happens to dynamic power if you double the frequency and lower the voltage from 1.0 V to 0.8 V?
3. Write −1 in 8-bit and 16-bit two's complement. What is `0xFFFF` as a signed 16-bit number?
4. How many address bits does a memory with 10,000 words need?
5. In Q8.8, what is the stored integer for 1.75? Multiply 1.75 × 2.0 in Q8.8 step by step.
6. Decode FP32 `0x40800000`.

### Logic
7. Prove ¬(a + b) = ā · b̄ with a truth table.
8. Why is an `if/else` in hardware "both branches plus a mux"?
9. What creates an accidental latch, and how do you prevent it?
10. How many cases does an exhaustive test of a 6-input block need?

### Sequential and timing
11. A register has `en = 0` this cycle. What does it hold after the edge?
12. t_cq = 0.5 ns, t_su = 0.2 ns, logic = 7.3 ns. What's f_max?
13. What's the difference between latency and throughput? Give an example where pipelining improves one and worsens the other.
14. In `always @(posedge clk) begin a <= b; b <= a; end`, what happens? With `=`?
15. State the two rules of the valid/ready handshake that prevent bugs.

### Memory and processors
16. A BRAM gets address 9 in cycle 4. When is the data usable?
17. Explain how one extra pointer bit lets a FIFO tell "full" from "empty".
18. Your GPU's memory delivers 4 bytes per cycle at 100 MHz. Vector add needs 12 bytes per element. What's the maximum element rate?
19. Decode the tiny-CPU instruction `0x34FE`.
20. Why does the GPU core's fetch take its own pipeline stage?

### GPU
21. What's the difference between a thread, a lane and a warp?
22. Mask is `1111`, and r = [0, 5, 0, 5]. After `IF r`, `ELSE`, `ENDIF`, what are the three masks?
23. Why does adding warps raise ALU utilization? Why does it stop helping eventually?
24. Why does the GPU core need no forwarding/hazard logic?
25. Edge function: is p = (1, 3) inside the triangle (0,0), (4,0), (0,4)?

<details>
<summary><b>Answers</b></summary>

1. Each gate must charge/discharge the capacitance of the wires and inputs it drives through its transistors' resistance (an RC delay). More load (fan-out, long wires) means more C, which means longer delay.
2. P ∝ V²f: 0.8² × 2 = **1.28×** the original power.
3. `1111_1111` and `1111_1111_1111_1111`. `0xFFFF` = **−1**.
4. 2¹³ = 8192 < 10,000 ≤ 16,384 = 2¹⁴ → **14 bits**.
5. 1.75 × 256 = **448**. 2.0 → 512. 448 × 512 = 229,376 (16 fraction bits), >> 8 = 896 → 896 / 256 = **3.5** ✓.
6. `0 10000001 000…`: exponent 129 → 2², mantissa 1.0 → **4.0**.
7. Rows (a, b): 00 → both sides 1. 01 → both 0. 10 → both 0. 11 → both 0. The columns are identical ✓.
8. Hardware can't "skip" circuits: both computations physically exist and run every cycle, and the condition drives a mux that picks which result to use.
9. A combinational block (`always @(*)`) that doesn't assign some output on some path, so the hardware has to remember it. Prevent it with a default assignment at the top and a `default:` in every case.
10. 2⁶ = **64**.
11. Its **old value** (the enable mux feeds the output back).
12. T = 0.5 + 7.3 + 0.2 = 8.0 ns → **125 MHz**.
13. Latency = time for one item; throughput = items per unit of time. Splitting a 12 ns operation into 3 stages: throughput rises from 80 M/s to 222 M/s, while latency rises from 12.5 to 13.5 ns (Lesson 6).
14. With `<=`: a and b **swap** every cycle (both read the old values). With `=`: a = b, then b = (new) a = b, so both become the old b. **No swap.**
15. (1) Once valid is high, keep valid and data stable until the transfer. (2) Never wait for ready before raising valid (that deadlocks).
16. **Cycle 5.**
17. Pointers carry a "lap" bit above the slot bits. Same slot + same lap = empty. Same slot + different lap = full (the writer is a whole lap ahead).
18. 400 MB/s ÷ 12 B ≈ **33.3 M elements/s**.
19. `0011 01 00 1111_1110` → opcode 3 = ADDI, rd = r1, imm = 0xFE = −2 → **`ADDI r1, -2`**.
20. Instruction memory is BRAM with a **synchronous read**: the instruction arrives one cycle after the address is given.
21. A **thread** = one instance of the program with its own registers and ID. A **lane** = the hardware ALU slot that executes one thread's work. A **warp** = a group of threads that share one PC and execute together on the lanes.
22. After IF: **`.1.1`**. After ELSE: **`1.1.`**. After ENDIF: **`1111`**.
23. While one warp waits for memory, others can issue, so idle cycles get filled. It stops helping once the ALUs are always busy (100%), or once another shared resource (like the memory port) is saturated.
24. A warp is marked `busy` from issue until its instruction finishes, so a warp never has two instructions in flight: no instruction can read a result that isn't written yet. Other warps fill the pipeline meanwhile.
25. E_v1v2 = (1−4)(4) − (3)(−4) = −12 + 12 = **0**. E_v2v0 = (1)(−4) = −4. E_v0v1 = −(3)(4) = −12. Area = −16. The values are ≤ 0 (one is exactly 0), so p is **on the edge**. With "≤ 0 counts as inside" (as in `mini_raster.py`), it's inside. Real GPUs use a "top-left rule" to decide edge pixels so shared edges aren't drawn twice (main guide, Part 12.3).

</details>

---

## Where to Go Next

You now have the foundations for the main guide. Suggested order:

| You learned | Continue in the main guide (`GPU_Mastery_Guide.md`) |
|---|---|
| Lessons 1–4 | Part 1 (logic theory), Part 2 (arithmetic), Part 5 (Verilog) |
| Lessons 5–7 | Part 7 (design patterns), Part 11 (buses, CDC, memory) |
| Lesson 8 | Part 2.4 (floating point in depth) |
| Lesson 9 | Part 3 (architecture), Part 15.2 (your GPU's ISA) |
| Lesson 10 | Part 13 (GPU architecture), Part 15 (the full core) |
| Lesson 11 | Part 12 (graphics theory), Part 14 (building the graphics pipeline) |
| Lesson 12 | Part 8 (verification), Part 9 (toolchain), `gpu_project/README.md` |

Then: run `gpu_project`'s experiments (main guide, Part 15.7), and start modifying the GPU yourself.
