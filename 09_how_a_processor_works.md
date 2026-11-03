# Lesson 9 — How a Processor Works (Build One in 70 Lines)

> **Why this matters for your GPU:** a GPU core *is* a processor. It fetches instructions, decodes their bit fields, reads registers, computes in an ALU, and writes results back. The only difference is that it does this for many threads at once (Lesson 10). Here you'll build and run a complete tiny CPU, encode instructions by hand, and then decode real instructions from your GPU's program.

---

## 9.1 The Big Idea: a Program Is Just Numbers in Memory

A processor repeats one loop forever:

```
   ┌──────────────────────────────────────────────────────────┐
   │ 1. FETCH:    read the instruction at address PC           │
   │ 2. DECODE:   split its bits into fields (what op? which   │
   │              registers? what constant?)                   │
   │ 3. EXECUTE:  do it: ALU math, memory access, or jump      │
   │ 4. WRITE:    store the result; update PC                  │
   └────────────────────────── repeat ────────────────────────┘
```

- **PC (program counter):** a register holding the address of the current instruction. Normally PC = PC + 1 each instruction. A **jump/branch** sets PC to another address. That's how loops and ifs work.
- **Registers:** a few fast storage slots inside the processor (r0, r1, …). Instructions operate on them.
- **Memory:** a large, slower store. Data moves between memory and registers with **load** and **store** instructions.
- **Instruction:** a number whose bits mean "do this operation on these registers". The rules for what each bit means are the **ISA** (Instruction Set Architecture).

---

## 9.2 The Tiny CPU's Instruction Set

8-bit data, 4 registers (r0–r3), 16-bit instructions:

```
 15    12 11  10 9    8 7                 0
┌────────┬──────┬──────┬───────────────────┐
│ opcode │  rd  │  rs  │      imm          │
│ 4 bits │2 bits│2 bits│     8 bits        │
└────────┴──────┴──────┴───────────────────┘
```

| Opcode | Assembly | Meaning |
|---|---|---|
| 0 | `LI rd, imm` | rd = imm (load immediate) |
| 1 | `ADD rd, rs` | rd = rd + rs |
| 2 | `SUB rd, rs` | rd = rd − rs |
| 3 | `ADDI rd, imm` | rd = rd + imm |
| 4 | `JMP imm` | PC = imm |
| 5 | `JNZ rd, imm` | if rd ≠ 0 then PC = imm |
| 6 | `LD rd, [imm]` | rd = mem[imm] |
| 7 | `ST rd, [imm]` | mem[imm] = rd |
| F | `HALT` | stop |

**Why 2 bits for registers?** 4 registers need log₂4 = 2 bits (Lesson 2). **Why is imm 8 bits?** The data is 8-bit, so a constant can be any byte.

**Negative constants:** `ADDI r0, -1` uses imm = `0xFF`. In 8-bit arithmetic, adding 255 is the same as subtracting 1 (modulo 256, Lesson 2).

---

## 9.3 Encoding Instructions by Hand (and a Real Mistake)

To encode `ADD r1, r0`:

| Field | Value | Bits |
|---|---|---|
| opcode (ADD) | 1 | `0001` |
| rd (r1) | 1 | `01` |
| rs (r0) | 0 | `00` |
| imm (unused) | 0 | `0000 0000` |

```
0001 01 00 0000 0000  →  group into nibbles: 0001 0100 0000 0000  →  0x1400
```

**A true story from building this lesson:** I first encoded `ADD r1, r0` as `0x1100`. Decode that: `0001 0001 0000 0000` → opcode 1, rd = `00` (r0), rs = `01` (r1). That's `ADD r0, r1`, the operands **swapped**. I also wrote `JNZ r0, 2` as `0x0502`, forgetting the opcode nibble (it decodes as `LI r1, 2`!). The CPU faithfully did exactly what the wrong bits said, and the test failed. **This is why assemblers exist**: humans are bad at bit-packing, and computers are perfect at it.

The full program, computing 10 + 9 + 8 + … + 1:

`code/09_tiny_cpu/sum.s`:

```asm
; sum.s: compute 10 + 9 + ... + 1 and store it at address 128
        LI   r0, 10        ; r0 = counter
        LI   r1, 0         ; r1 = running sum
loop:
        ADD  r1, r0        ; sum = sum + counter
        ADDI r0, -1        ; counter = counter - 1
        JNZ  r0, loop      ; repeat while counter != 0
        ST   r1, [128]     ; mem[128] = sum
        HALT
```

| Address | Assembly | Fields (op rd rs imm) | Hex |
|---|---|---|---|
| 0 | `LI r0, 10` | 0 00 00 00001010 | `000A` |
| 1 | `LI r1, 0` | 0 01 00 00000000 | `0400` |
| 2 | `ADD r1, r0` | 1 01 00 00000000 | `1400` |
| 3 | `ADDI r0, -1` | 3 00 00 11111111 | `30FF` |
| 4 | `JNZ r0, 2` | 5 00 00 00000010 | `5002` |
| 5 | `ST r1, [128]` | 7 01 00 10000000 | `7480` |
| 6 | `HALT` | F 00 00 00000000 | `F000` |

The label `loop:` becomes the address of the instruction after it (2), so `JNZ r0, loop` becomes `JNZ r0, 2`.

---

## 9.4 The Assembler

An **assembler** turns text into those numbers. It needs **two passes**, because a jump can refer to a label defined *later* in the file:
1. **Pass 1:** walk the lines and record each label's address.
2. **Pass 2:** encode each instruction, replacing labels with addresses.

`code/09_tiny_cpu/tiny_asm.py`:

```python
"""tiny_asm.py: assembler for tiny_cpu. Turns readable text into the 16-bit hex the CPU runs.
Run: python tiny_asm.py sum.s sum.hex
"""
import sys

OPCODES = {"LI": 0x0, "ADD": 0x1, "SUB": 0x2, "ADDI": 0x3, "JMP": 0x4,
           "JNZ": 0x5, "LD": 0x6, "ST": 0x7, "HALT": 0xF}


def reg(tok):                       # "r2" -> 2
    return int(tok.strip().lower().lstrip("r"))


def num(tok, labels):               # "10", "0x80", "-1", "[128]" or a label
    tok = tok.strip().strip("[]")
    if tok in labels:
        return labels[tok]
    return int(tok, 0) & 0xFF       # & 0xFF turns -1 into 0xFF (two's complement)


def encode(op, rd=0, rs=0, imm=0):
    #        [15:12]           [11:10]      [9:8]       [7:0]
    return (OPCODES[op] << 12) | (rd << 10) | (rs << 8) | imm


def assemble(text):
    lines = [l.split(";")[0].strip() for l in text.splitlines()]
    # pass 1: give every label the address of the next instruction
    labels, pc = {}, 0
    for l in lines:
        if l.endswith(":"):
            labels[l[:-1]] = pc
        elif l:
            pc += 1
    # pass 2: encode
    out = []
    for l in lines:
        if not l or l.endswith(":"):
            continue
        op, _, rest = l.partition(" ")
        op = op.upper()
        args = [a for a in rest.split(",") if a.strip()]
        if op in ("ADD", "SUB"):
            out.append(encode(op, rd=reg(args[0]), rs=reg(args[1])))
        elif op in ("LI", "ADDI", "JNZ", "LD", "ST"):
            out.append(encode(op, rd=reg(args[0]), imm=num(args[1], labels)))
        elif op == "JMP":
            out.append(encode(op, imm=num(args[0], labels)))
        elif op == "HALT":
            out.append(encode(op))
        else:
            raise SystemExit(f"unknown instruction: {l}")
    return out


if __name__ == "__main__":
    words = assemble(open(sys.argv[1]).read())
    with open(sys.argv[2], "w") as f:
        for w in words:
            f.write(f"{w:04X}\n")
    for w in words:
        print(f"{w:04X} = {w:016b}")
```

```
cd hardware_basics\code\09_tiny_cpu
python tiny_asm.py sum.s sum.hex
```

```
000A = 0000000000001010
0400 = 0000010000000000
1400 = 0001010000000000
30FF = 0011000011111111
5002 = 0101000000000010
7480 = 0111010010000000
F000 = 1111000000000000
```

Your GPU has the same kind of assembler (`gpu_project/sw/gpuasm.py`), just with a 32-bit encoding and more instructions.

---

## 9.5 The CPU in Verilog

`code/09_tiny_cpu/tiny_cpu.v`:

```verilog
// tiny_cpu.v: a complete 8-bit processor in about 70 lines. One instruction per clock cycle.
//
// 4 registers r0..r3 (8 bits each), 256 bytes of data memory, up to 256 instructions.
// Instruction = 16 bits:   [15:12] opcode   [11:10] rd   [9:8] rs   [7:0] imm
//
//   op  name   meaning
//   0   LI     rd = imm
//   1   ADD    rd = rd + rs
//   2   SUB    rd = rd - rs
//   3   ADDI   rd = rd + imm            (imm 0xFF = -1, because 8-bit arithmetic wraps)
//   4   JMP    pc = imm
//   5   JNZ    if (rd != 0) pc = imm
//   6   LD     rd = mem[imm]
//   7   ST     mem[imm] = rd
//   F   HALT   stop
module tiny_cpu (
  input  wire       clk,
  input  wire       rst,
  output reg        halted,
  output reg  [7:0] pc
);
  reg  [15:0] rom  [0:255];          // program (instruction memory)
  reg  [7:0]  dmem [0:255];          // data memory
  reg  [7:0]  r    [0:3];            // the register file
  integer i;

  // ---------- FETCH: read the instruction at pc ----------
  wire [15:0] instr = rom[pc];

  // ---------- DECODE: slice the instruction into fields ----------
  wire [3:0] op  = instr[15:12];
  wire [1:0] rd  = instr[11:10];
  wire [1:0] rs  = instr[9:8];
  wire [7:0] imm = instr[7:0];

  // ---------- EXECUTE + WRITE BACK: all on the clock edge ----------
  always @(posedge clk) begin
    if (rst) begin
      pc <= 8'd0;
      halted <= 1'b0;
      for (i = 0; i < 4; i = i + 1) r[i] <= 8'd0;
    end else if (!halted) begin
      pc <= pc + 8'd1;                         // default: go to the next instruction
      case (op)
        4'h0: r[rd] <= imm;                    // LI
        4'h1: r[rd] <= r[rd] + r[rs];          // ADD
        4'h2: r[rd] <= r[rd] - r[rs];          // SUB
        4'h3: r[rd] <= r[rd] + imm;            // ADDI
        4'h4: pc <= imm;                       // JMP
        4'h5: if (r[rd] != 8'd0) pc <= imm;    // JNZ
        4'h6: r[rd] <= dmem[imm];              // LD
        4'h7: dmem[imm] <= r[rd];              // ST
        4'hF: begin halted <= 1'b1; pc <= pc; end   // HALT
        default: ;                             // unknown opcode: do nothing
      endcase
    end
  end
endmodule
```

Map the code to the four steps:
- **Fetch:** `wire [15:0] instr = rom[pc];` reads the instruction memory at PC. (This simple CPU reads it combinationally, without waiting for a clock edge. The GPU core uses a synchronous BRAM read, so fetch takes its own pipeline stage. See Lesson 7.)
- **Decode:** four `wire` lines that just **slice bits**. Decoding is free: it's wiring!
- **Execute + write back:** the `case (op)` inside `always @(posedge clk)`. Each case does its operation, and the result is written at the clock edge with `<=`.
- **PC update:** `pc <= pc + 1` by default. Jumps override it. (In a clocked block, **the last `<=` to the same variable wins**, which is why the jump's `pc <= imm` beats the earlier `pc <= pc + 1`.)

This is a **single-cycle** CPU: one instruction completes per clock. Real CPUs pipeline these steps (Lesson 6) to raise the clock speed.

---

## 9.6 Watch It Run

`code/09_tiny_cpu/tb_cpu.v`:

```verilog
// tb_cpu.v: runs sum.hex (adds 10 + 9 + ... + 1) and prints every instruction it executes.
// Run: iverilog -o cpu.vvp tiny_cpu.v tb_cpu.v && vvp -n cpu.vvp
`timescale 1ns/1ps
module tb_cpu;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;
  wire halted;
  wire [7:0] pc;
  tiny_cpu u_cpu (.clk(clk), .rst(rst), .halted(halted), .pc(pc));

  function [8*24-1:0] disasm(input [15:0] ins);   // turn bits back into text
    reg [8*4-1:0] rdn, rsn;
    reg [8*24-1:0] text;
    begin
      rdn = {"r", 8'd48 + ins[11:10]};
      rsn = {"r", 8'd48 + ins[9:8]};
      case (ins[15:12])
        4'h0: $sformat(text, "LI   %0s, %0d", rdn, ins[7:0]);
        4'h1: $sformat(text, "ADD  %0s, %0s", rdn, rsn);
        4'h2: $sformat(text, "SUB  %0s, %0s", rdn, rsn);
        4'h3: $sformat(text, "ADDI %0s, %0d", rdn, $signed(ins[7:0]));
        4'h4: $sformat(text, "JMP  %0d", ins[7:0]);
        4'h5: $sformat(text, "JNZ  %0s, %0d", rdn, ins[7:0]);
        4'h6: $sformat(text, "LD   %0s, [%0d]", rdn, ins[7:0]);
        4'h7: $sformat(text, "ST   %0s, [%0d]", rdn, ins[7:0]);
        4'hF: $sformat(text, "HALT");
        default: $sformat(text, "???");
      endcase
      disasm = text;
    end
  endfunction

  integer cyc;
  initial begin
    $readmemh("sum.hex", u_cpu.rom);
    @(posedge clk); #1 rst = 0;
    $display("cyc pc instr  %-20s | r0  r1   (registers BEFORE this instruction runs)", "assembly");
    for (cyc = 0; cyc < 60 && !halted; cyc = cyc + 1) begin
      $display("%3d %2d  %h   %-20s | %3d %3d", cyc, pc, u_cpu.instr, disasm(u_cpu.instr),
               u_cpu.r[0], u_cpu.r[1]);
      @(posedge clk); #1;
    end
    $display("halted after %0d cycles. mem[128] = %0d (expected 55)", cyc, u_cpu.dmem[128]);
    if (u_cpu.dmem[128] == 55) $display("PASS"); else $display("FAIL");
    $finish;
  end
endmodule
```

```
iverilog -o cpu.vvp tiny_cpu.v tb_cpu.v
vvp -n cpu.vvp
```

```
cyc pc instr  assembly             | r0  r1   (registers BEFORE this instruction runs)
  0  0  000a   LI   r0, 10          |   0   0
  1  1  0400   LI   r1, 0           |  10   0
  2  2  1400   ADD  r1, r0          |  10   0
  3  3  30ff   ADDI r0, -1          |  10  10
  4  4  5002   JNZ  r0, 2           |   9  10
  5  2  1400   ADD  r1, r0          |   9  10      ← PC jumped back to 2: a loop!
  6  3  30ff   ADDI r0, -1          |   9  19
  7  4  5002   JNZ  r0, 2           |   8  19
 ...
 31  4  5002   JNZ  r0, 2           |   0  55      ← r0 is 0: no jump this time
 32  5  7480   ST   r1, [128]       |   0  55
 33  6  f000   HALT                 |   0  55
halted after 34 cycles. mem[128] = 55 (expected 55)
PASS
```

**Count the cycles:** 2 setup instructions + 10 loop iterations × 3 instructions + ST + HALT = 2 + 30 + 2 = 34 ✓. Being able to predict cycle counts like this is how you'll reason about GPU performance.

---

## 9.7 Now Decode Your GPU's Real Instructions

Your GPU's encoding (main guide, Part 15.2) is 32 bits:

```
 31      26 25   22 21   18 17   14 13                    0
┌──────────┬───────┬───────┬───────┬───────────────────────┐
│  opcode  │  rd   │  rs1  │  rs2  │                       │   R-type (register ops)
│  opcode  │  rd   │  rs1  │       imm[17:0]               │   I-type (immediate, memory, branch)
└──────────┴───────┴───────┴───────────────────────────────┘
   6 bits    4 bits  4 bits         18 bits
```

The first line of `vadd.hex` is `a0400000`. Decode it:

```
hex:   a    0    4    0    0    0    0    0
bits: 1010 0000 0100 0000 0000 0000 0000 0000

opcode [31:26] = 101000      = 0x28 → S2R (read a special register)
rd     [25:22] = 0001        = r1
rs1    [21:18] = 0000        = r0 (unused)
imm    [17:0]  = 0           → special register 0 = TID (thread ID)

→  S2R r1, TID      ✓ (line 1 of vadd.s)
```

Line 9 of `vadd.hex` is `06104000`:

```
bits: 0000 0110 0001 0000 0100 0000 0000 0000

opcode = 000001 = 0x01 → ADD
rd     = 1000   = r8
rs1    = 0100   = r4
rs2    = 0001   = r1

→  ADD r8, r4, r1        ✓ ("&A[i] = A base + i")
```

The GPU decoder (`gpu_decode.sv`) does exactly this slicing:

```systemverilog
assign op    = opcode_t'(instr[31:26]);
assign rd    = instr[25:22];
assign rs1   = instr[21:18];
assign rs2   = instr[17:14];
assign imm18 = instr[17:0];
```

### What's different in the GPU core (preview of Lesson 10)

| Tiny CPU | Your GPU core |
|---|---|
| 1 thread | Many warps × many lanes |
| 4 registers × 8 bits | 16 registers × 32 bits **per thread** |
| Single-cycle | 3-stage pipeline (fetch → decode/read → execute) |
| `JNZ` jumps for the whole program | Branches must handle threads that disagree (masks) |
| Reads its instruction memory instantly | Synchronous BRAM read (1-cycle latency) |
| Memory access in the same cycle | A separate load/store unit; memory takes several cycles |

---

## Exercises

1. Encode `SUB r2, r3` and `LD r3, [0x40]` in hex for the tiny CPU.
2. Decode tiny-CPU instruction `0x5C07`.
3. Write a tiny-CPU program that computes 7 × 6 by repeated addition and stores the result at address 0x90. How many cycles will it take?
4. Why does the assembler need two passes?
5. Decode the GPU instruction `0x29c4c000` from vadd.hex (line 7).
6. In the GPU encoding, why can registers only go up to r15? What would you change to support 32 registers?

<details>
<summary><b>Answers</b></summary>

1. `SUB r2, r3`: 0010 10 11 00000000 = **0x2B00**. `LD r3, [0x40]`: 0110 11 00 01000000 = **0x6C40**.
2. `0101 11 00 00000111` → opcode 5 = JNZ, rd = 3 → **`JNZ r3, 7`**.
3. One version:
   ```
   LI r0, 6        ; counter
   LI r1, 0        ; result
   LI r2, 7        ; value to add
   loop: ADD r1, r2
   ADDI r0, -1
   JNZ r0, loop
   ST r1, [0x90]
   HALT
   ```
   Cycles: 3 + 6 × 3 + 2 = **23**.
4. A jump may refer to a label that appears *later* in the file. In one pass, its address isn't known yet when the jump is encoded.
5. `0010 1001 1100 0100 1100 0000 …`: opcode `001010` = 0x0A = SLT, rd = `0111` = r7, rs1 = `0001` = r1, rs2 = `0011` = r3 → **`SLT r7, r1, r3`** ("is i < n?") ✓.
6. The register fields are 4 bits (2⁴ = 16). For 32 registers you'd need 5-bit fields: 3 fields × 5 bits = 15 bits instead of 12, leaving a 15-bit immediate instead of 18. Every encoding is a trade-off between register count and constant size.

</details>

---

**Next:** [Lesson 10 — From CPU to GPU](10_from_cpu_to_gpu.md)
