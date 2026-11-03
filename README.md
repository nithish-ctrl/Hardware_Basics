# Hardware Basics — Everything You Need Before Building the GPU

This folder teaches the foundations behind `GPU_Mastery_Guide.md` and `gpu_project/`, from zero, one idea at a time. Every lesson has:

- **Plain-language explanations**, with the "why" before the "how"
- **The math**, with worked examples you can check by hand
- **Runnable code** (Verilog and Python), every example tested, with its real output shown
- **Exercises with answers** (hidden in collapsible sections: try first!)
- **"How this connects to the GPU"**, so nothing is learned in isolation

## The Lessons (Do Them in Order)

| # | Lesson | You'll understand | Runnable code |
|---|---|---|---|
| 1 | [Electricity, Transistors and Why Hardware Has Limits](01_electricity_and_transistors.md) | Voltage, current, transistors as switches, CMOS gates, why gates have delay, power = αCV²f, clocks | — |
| 2 | [Numbers and Binary Math](02_numbers_and_binary_math.md) | Binary, hex, bit widths, two's complement, overflow, fixed point, floating point | `numbers_lab.py` |
| 3 | [Logic Gates and Boolean Algebra](03_logic_gates_and_boolean_algebra.md) | Truth tables, Boolean laws, De Morgan, deriving the full adder, NAND universality | full adder + exhaustive test |
| 4 | [Combinational Circuits](04_combinational_circuits.md) | Mux, decoder, comparator, adder, shifter, the latch trap, width rules | 5 blocks + exhaustive tests |
| 5 | [Sequential Logic and Clocks](05_sequential_logic_and_clocks.md) | Feedback, latches, flip-flops, registers, counters, reset, setup/hold, f_max math | register, counter, shift register |
| 6 | [Thinking in Clock Cycles](06_thinking_in_cycles_fsms_handshakes.md) | `=` vs `<=`, latency vs throughput, pipelining, state machines, valid/ready | blocking demo, traffic-light FSM, handshake |
| 7 | [Memory](07_memory.md) | RAM, read latency, ports, banking, FIFOs, `$readmemh`, bandwidth math | synchronous RAM, FIFO vs model |
| 8 | [Computer Arithmetic](08_computer_arithmetic.md) | Multiplication, product widths, fixed-point Verilog, lerp, how FP add/multiply work, signed pitfalls | Q8.8 multiplier, lerp |
| 9 | [How a Processor Works](09_how_a_processor_works.md) | Fetch/decode/execute, ISA, encoding, assemblers, decoding your GPU's instructions | a complete tiny CPU + assembler |
| 10 | [From CPU to GPU](10_from_cpu_to_gpu.md) | Threads, lanes, SIMD, warps, masks, divergence, latency hiding, a tour of `gpu_core.sv` | SIMT lane tracer, latency-hiding timeline |
| 11 | [Graphics Math](11_graphics_math.md) | Vectors, dot product, matrices, homogeneous coordinates, perspective, edge functions, barycentrics, Z-buffer | transform walkthrough, software rasterizer (makes a PNG) |
| 12 | [Tools and Workflow](12_tools_and_workflow.md) | Simulation vs synthesis, testbenches, GTKWave, debugging method, linting | — |
| 13 | [Glossary and Final Quiz](13_glossary_and_final_quiz.md) | 60+ terms, 25 quiz questions with answers, where to go next | — |

**Time:** roughly 1–2 evenings per lesson. Don't rush Lessons 5, 6 and 10: they contain the ideas everything else rests on.

## How to Study Each Lesson

1. Read the explanation once.
2. **Predict** what the example will print, then run it and compare. Surprises are where learning happens.
3. Change something (an input, a width, a parameter) and predict again.
4. Do the exercises **on paper** before opening the answers.
5. Can you explain the "How this connects to the GPU" section to someone else? Then move on.

## Setup (Once per PowerShell Window)

The tools were installed to `D:\Downloads\Hardware\tools\oss-cad-suite`:

```powershell
. D:\Downloads\Hardware\tools\oss-cad-suite\environment.ps1
$env:VERILATOR_ROOT = "$env:YOSYSHQ_ROOT\share\verilator"
cd D:\Downloads\Hardware\GPU\hardware_basics
.\run_all.ps1          # runs every example in every lesson and reports PASS/FAIL
```

To run a single example, follow the commands shown in its lesson (e.g. in Lesson 5: `cd code\05_sequential`, then `iverilog ...` and `vvp ...`).

## Folder Layout

```
hardware_basics/
  README.md                       (this file)
  01_ ... 13_*.md                 (the lessons)
  run_all.ps1                     (runs every example)
  code/
    02_numbers/                   numbers_lab.py
    03_logic_gates/               full_adder.v, tb_logic.v
    04_combinational/             comb_blocks.v, tb_comb.v
    05_sequential/                seq_basics.v, tb_seq.v
    06_cycles_fsm/                blocking_demo.v, traffic_light.v, tb_traffic.v, tb_handshake.v
    07_memory/                    memories.v, tb_memories.v
    08_arithmetic/                fixed_point.v, tb_fixed.v
    09_tiny_cpu/                  tiny_cpu.v, tb_cpu.v, tiny_asm.py, sum.s, sum.hex
    10_cpu_to_gpu/                simt_trace.py, latency_hiding.py
    11_graphics_math/             transform_demo.py, mini_raster.py
```

