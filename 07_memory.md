# Lesson 7 — Memory: RAM, Register Files, FIFOs and Bandwidth

> **Why this matters for your GPU:** a GPU is mostly memory: register files (huge), instruction memory, data memory, caches, framebuffers, FIFOs between blocks. GPU performance is usually limited by **how fast data can be moved**, not by how fast you can compute. This lesson explains how memories work, why reading takes a clock cycle, how a FIFO works, and how to calculate bandwidth.

---

## 7.1 What a Memory Is

A memory is an array of **words**. You give it an **address** and it reads or writes the word at that address.

```
          address (AW bits)
               │
          ┌────▼─────────────┐
 wdata ──►│ word 0           │
   we ───►│ word 1           │──► rdata
  clk ───►│ ...              │
          │ word 2^AW − 1    │
          └──────────────────┘
```

| Term | Meaning |
|---|---|
| AW (address width) | Number of address bits. Number of words = 2^AW |
| DW (data width) | Bits per word |
| Capacity | 2^AW × DW bits |
| we (write enable) | 1 = write wdata into the addressed word at the next edge |

### Size math (do these in your head)

- AW = 10, DW = 32: 1024 words × 32 bits = 32,768 bits = **4 KB** (4096 bytes).
- Your GPU's data memory: AW = 12 → 4096 words × 32 bits = **16 KB**.
- A 320×240 framebuffer at 8 bits per pixel: 76,800 bytes ≈ 75 KB, so it needs 17 address bits.

**Units:** 1 KB = 1024 bytes (2¹⁰), 1 MB = 2²⁰ bytes. Bits (b) vs bytes (B): 8 bits = 1 byte. FPGA datasheets often list memory in **Kbits**, so divide by 8 for bytes.

In Verilog, a memory is an array:

```verilog
reg [31:0] mem [0:4095];      // 4096 words, each 32 bits
```

---

## 7.2 Kinds of Memory

| Kind | Built from | Size | Speed | Used in your GPU for |
|---|---|---|---|---|
| **Flip-flops** | Individual DFFs | Tiny (bits–KB) | Fastest, any number of ports | Pipeline registers, per-warp state |
| **FPGA LUT RAM** (distributed) | Logic LUTs used as tiny memories | Small (≤ few KB) | Fast, can read without a clock | Small FIFOs |
| **FPGA block RAM (BRAM)** | Dedicated SRAM blocks (e.g. 36 Kbit each) | Medium (100s of KB per chip) | Fast, **synchronous read** | Register files, instruction memory, framebuffer |
| **SRAM** (in ASICs) | 6 transistors per bit | KB–MB on-chip | Fast | Caches, register files, shared memory |
| **DRAM** (DDR, GDDR, HBM) | 1 transistor + 1 capacitor per bit | GBs, off-chip | Slow to access (~100s of cycles), high bandwidth in bursts | Main GPU memory |

- **ROM** (read-only memory): contents fixed. On FPGAs it's just a RAM preloaded at startup that's never written (e.g. the instruction memory, loaded with `$readmemh`).
- **Volatile:** SRAM and DRAM lose their contents when power is off. DRAM even loses them over milliseconds unless **refreshed**.

---

## 7.3 Synchronous Read: Why the Data Arrives One Cycle Later

FPGA block RAMs register the address at the clock edge, and the data comes out after that edge. So:

> **Present the address in cycle N → the data is available in cycle N+1.**

```verilog
always @(posedge clk) begin
  if (we) mem[addr] <= wdata;
  rdata <= mem[addr];            // rdata is a register: updated at the edge
end
```

`code/07_memory/memories.v`:

```verilog
// memories.v

// RAM with SYNCHRONOUS read (this is how FPGA block RAM behaves):
// you give the address in cycle N, the data appears in cycle N+1.
module ram_sync #(parameter AW = 4, DW = 8) (
  input  wire          clk,
  input  wire          we,          // write enable
  input  wire [AW-1:0] addr,
  input  wire [DW-1:0] wdata,
  output reg  [DW-1:0] rdata
);
  reg [DW-1:0] mem [0:(1<<AW)-1];   // 2^AW words of DW bits
  always @(posedge clk) begin
    if (we) mem[addr] <= wdata;
    rdata <= mem[addr];              // registered read -> one cycle of latency
  end
endmodule

// Synchronous FIFO (first in, first out), depth 2^AW
module sync_fifo #(parameter DW = 8, AW = 2) (
  input  wire          clk, rst,
  input  wire          wr_en,
  input  wire [DW-1:0] wr_data,
  output wire          full,
  input  wire          rd_en,
  output wire [DW-1:0] rd_data,
  output wire          empty
);
  reg [DW-1:0] mem [0:(1<<AW)-1];
  reg [AW:0]   wptr, rptr;           // ONE EXTRA BIT: the "lap" bit

  wire do_wr = wr_en && !full;
  wire do_rd = rd_en && !empty;

  always @(posedge clk) begin
    if (rst) begin
      wptr <= 0;
      rptr <= 0;
    end else begin
      if (do_wr) begin
        mem[wptr[AW-1:0]] <= wr_data;  // low bits = slot number
        wptr <= wptr + 1'b1;
      end
      if (do_rd) rptr <= rptr + 1'b1;
    end
  end

  assign rd_data = mem[rptr[AW-1:0]];
  assign empty   = (wptr == rptr);                                  // same slot, same lap
  assign full    = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);  // same slot, writer one lap ahead
endmodule
```

The first part of the testbench writes 100..107 to addresses 0..7, then reads:

```
RAM read latency (address given in a cycle, data shows up the NEXT cycle):
  cycle 0: addr=0   rdata=x
  cycle 1: addr=1   rdata=100
  cycle 2: addr=2   rdata=101
  cycle 3: addr=3   rdata=102
  cycle 4: addr=4   rdata=103
```

Every row shows the data for the **previous** row's address. And the `x` in cycle 0? In the cycle before it, address 7 was being **written**. At that edge, the RAM read the **old** contents of address 7 (nothing yet, so `x` = unknown) at the same time as writing the new value. This is called **read-first** behavior. (Some RAMs are "write-first" and return the new value. FPGA vendors let you choose.)

### Why this one cycle matters so much

Every design that uses BRAM must account for it:
- The GPU core fetches an instruction: `s1_instr <= imem[pc[issue_w]]`. It arrives in **stage 1**, one cycle after the address was given in **stage 0**. That's exactly why fetch is its own pipeline stage.
- The display controller reads pixels from a BRAM framebuffer, so it must delay hsync/vsync by one cycle to keep them aligned with the pixel data (main guide, Part 14.2: "the latency-alignment lesson").

---

## 7.4 Ports and the Register File

A **port** is one independent address/data access per cycle.

- Single-port: one read **or** write per cycle.
- **Simple dual-port:** one write port + one read port at the same time (most common).
- **True dual-port:** two fully independent read/write ports (FPGA BRAMs support this).

A processor's **register file** typically needs **2 reads + 1 write per cycle** (`ADD rd, rs1, rs2` reads two registers and writes one). FPGA BRAMs have only 2 ports. Solutions:
- **Replicate:** keep two copies, write both, read one from each. That gives 2 read ports.
- **Bank** it (what real GPUs do): split the registers across several memories. Simultaneous accesses to *different* banks proceed in parallel.
- Use flip-flops: any number of ports, but huge.

The GPU core's register file `rf[lane][warp*16 + reg]` has **one bank per lane**, so all lanes read their own registers in parallel. That's banking by lane.

### Banking math

With N banks and word-interleaving, **bank = address mod N** and **row = address / N** (with N a power of 2, these are just the low and high bits):

```
N = 4 banks:   address 0 → bank 0,  1 → bank 1,  2 → bank 2,  3 → bank 3,  4 → bank 0, ...
```

Four accesses to addresses 8, 9, 10, 11 hit banks 0, 1, 2, 3, so they're all served **in one cycle**. Four accesses to 0, 4, 8, 12 all hit bank 0, so they need **4 cycles** (a **bank conflict**). GPU shared memory works exactly like this, with 32 banks.

---

## 7.5 The FIFO: a Queue in Hardware

A **FIFO** (first in, first out) is a queue. A writer pushes items in, and a reader pops them out in the same order. It lets two blocks run at different speeds: the FIFO absorbs bursts.

### How it works: a ring of slots and two pointers

```
  slots:   [0] [1] [2] [3]      (depth 4)
            ▲       ▲
           rptr    wptr          rptr = next slot to read, wptr = next slot to write
```

- **Push:** write at `wptr`, then wptr = wptr + 1 (wrapping around after the last slot).
- **Pop:** read at `rptr`, then rptr = rptr + 1.
- **Count** = wptr − rptr.

### The tricky part: full vs empty

When `wptr == rptr`, the FIFO is either **empty** (reader caught up) or **full** (writer went all the way round). The slot numbers alone can't tell these apart.

**Solution: one extra bit in each pointer, a "lap counter".** For a depth-4 FIFO, use 3-bit pointers: the low 2 bits are the slot, the top bit counts laps.

Worked example (depth 4, pointers shown as `lap|slot`):

| Action | wptr | rptr | slots equal? | laps equal? | State |
|---|---|---|---|---|---|
| start | 0\|00 | 0\|00 | yes | yes | **empty** |
| push ×3 | 0\|11 | 0\|00 | no | — | count 3 |
| push ×1 | 1\|00 | 0\|00 | yes | **no** | **full** (writer is one lap ahead) |
| pop ×4 | 1\|00 | 1\|00 | yes | yes | **empty** again |

```verilog
assign empty = (wptr == rptr);                                       // same slot, same lap
assign full  = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);  // same slot, different lap
```

And the count is simply `wptr − rptr` in modulo arithmetic (here 3-bit). The wrap-around from Lesson 2 makes it work automatically.

### Testing a FIFO against a software model

The testbench does 400 cycles of random pushes and pops, keeps a **software copy** of the queue, and checks every popped value and the full/empty flags every cycle:

```
FIFO: 179 pushes, 178 pops, depth 4
PASS: FIFO matched the software model every cycle
```

That pattern (**hardware vs a simple software model, with random stimulus**) is exactly how the whole GPU core was verified against the Python emulator.

`code/07_memory/tb_memories.v`:

```verilog
// tb_memories.v
// Run: iverilog -o mem.vvp memories.v tb_memories.v && vvp -n mem.vvp
`timescale 1ns/1ps
module tb_memories;
  reg clk = 0;
  always #5 clk = ~clk;
  integer i, errors = 0;

  // ---------------- part 1: RAM read latency ----------------
  reg        we = 0;
  reg  [3:0] addr = 0;
  reg  [7:0] wdata = 0;
  wire [7:0] rdata;
  ram_sync #(.AW(4), .DW(8)) u_ram (.clk(clk), .we(we), .addr(addr), .wdata(wdata), .rdata(rdata));

  // ---------------- part 2: FIFO vs a software model ----------------
  reg        rst = 1, wr_en = 0, rd_en = 0;
  reg  [7:0] wr_data = 0;
  wire [7:0] rd_data;
  wire       full, empty;
  sync_fifo #(.DW(8), .AW(2)) u_fifo (.clk(clk), .rst(rst), .wr_en(wr_en), .wr_data(wr_data),
    .full(full), .rd_en(rd_en), .rd_data(rd_data), .empty(empty));

  reg [7:0] model [0:255];             // software FIFO: an array with head/tail counters
  integer head = 0, tail = 0, pushes = 0, pops = 0;

  initial begin
    // Write 100, 101, ... into addresses 0..7
    for (i = 0; i < 8; i = i + 1) begin
      we = 1; addr = i; wdata = 100 + i;
      @(posedge clk); #1;
    end
    we = 0;
    $display("RAM read latency (address given in a cycle, data shows up the NEXT cycle):");
    for (i = 0; i < 5; i = i + 1) begin
      addr = i;
      $display("  cycle %0d: addr=%0d   rdata=%0d", i, addr, rdata);
      @(posedge clk); #1;
    end
    $display("  -> rdata always shows the data for the PREVIOUS cycle's address.");

    // FIFO: random pushes/pops, compare every popped value to the model
    @(posedge clk); #1 rst = 0;
    for (i = 0; i < 400; i = i + 1) begin
      wr_en = $random & 1; rd_en = $random & 1; wr_data = $random;
      // check BEFORE the edge: what will be read this cycle
      if (rd_en && !empty) begin
        if (rd_data !== model[head % 256]) errors = errors + 1;
        head = head + 1; pops = pops + 1;
      end
      if (wr_en && !full) begin
        model[tail % 256] = wr_data; tail = tail + 1; pushes = pushes + 1;
      end
      @(posedge clk); #1;
      // after the edge, the hardware's full/empty must agree with the model's count
      if (empty !== (tail == head) || full !== (tail - head == 4)) errors = errors + 1;
    end
    $display("FIFO: %0d pushes, %0d pops, depth 4", pushes, pops);
    if (errors == 0) $display("PASS: FIFO matched the software model every cycle");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
```

```
cd hardware_basics\code\07_memory
iverilog -o mem.vvp memories.v tb_memories.v
vvp -n mem.vvp
```

---

## 7.6 Loading Memory From a File: `$readmemh`

```verilog
initial $readmemh("kernel.hex", imem);
```

The file is plain text, **one hex word per line**:

```
a0400000
a0800004
80c00000
```

Line 1 goes to address 0, line 2 to address 1, and so on. This is how the assembler's output (`vadd.hex`) becomes the GPU's program. It even works on real FPGAs: the contents are baked into the bitstream as the BRAM's initial values. (`$writememh` does the reverse: dumps a memory to a file, which is how the co-simulation compares memory.)

---

## 7.7 Bandwidth: the Number That Limits GPUs

**Bandwidth** = how many bytes per second a memory can deliver:

```
bandwidth = (bytes per access) × (accesses per cycle) × (clock frequency)
```

### Worked examples

- Your GPU's memory: 4 bytes per access, 1 access per cycle, at 100 MHz → 4 × 1 × 100 M = **400 MB/s**.
- A 16-bit SDRAM at 100 MHz: 2 bytes × 100 M = **200 MB/s**.
- DDR3 with a 16-bit bus at 800 MHz, two transfers per clock ("double data rate"): 2 × 2 × 800 M = **3.2 GB/s**.
- A high-end GPU with GDDR: about **1,000 GB/s**. HBM-based GPUs: 3,000+ GB/s.

### How much bandwidth does a computation need?

Vector add, `C[i] = A[i] + B[i]` with 4-byte numbers: per element, read 8 bytes and write 4 bytes = 12 bytes, for **1** addition.

At 400 MB/s, you can do at most 400 M / 12 ≈ **33 million additions per second**, no matter how many ALUs you have. Your 4-lane, 2-core GPU at 100 MHz could do 800 million additions per second, but memory can only feed 4% of that. **The computation is memory-bound.**

This is the most important performance idea in GPUs (main guide, Part 3.5: "roofline"). It's why GPUs have:
- **coalescing:** combine neighbouring threads' accesses into one wide access;
- **caches and shared memory:** reuse data instead of re-fetching it;
- **very wide memory buses:** GDDR, HBM.

### Why DRAM is slow to start but fast in bursts

DRAM stores bits as charge in tiny capacitors arranged in rows. Reading means first **opening a whole row** (slow: tens of nanoseconds), then reading many consecutive words from that open row quickly. So **sequential access is fast and random access is slow**. GPUs are designed so that neighbouring threads access neighbouring addresses.

---

## Exercises

1. A memory has AW = 14 and DW = 16. How many words? How many bytes?
2. You give a BRAM address 5 in cycle 10 and address 6 in cycle 11. In which cycle can you use the data from address 5?
3. In a depth-8 FIFO (3-bit slots + 1 lap bit), wptr = `1_010` and rptr = `0_110`. How many items are in it? Is it full?
4. 8 banks, word-interleaved. Which bank holds address 21? Do addresses 3, 11, 19 and 27 conflict?
5. A display shows 640×480 pixels at 2 bytes per pixel, 60 times per second. How much read bandwidth does that need?
6. A kernel reads 2 floats and writes 1 float per multiply-add (2 FLOPs). With 1 GB/s of bandwidth, what's the maximum FLOP rate?

<details>
<summary><b>Answers</b></summary>

1. 2¹⁴ = **16,384 words** × 2 bytes = **32,768 bytes (32 KB)**.
2. **Cycle 11** (one cycle later).
3. Count = wptr − rptr in 4-bit arithmetic: 1010 − 0110 = 0100 = **4 items**. Full requires equal slots (010 vs 110: no) → **not full**.
4. 21 mod 8 = **bank 5**. 3, 11, 19, 27 mod 8 are all **3**, so they **all conflict**: 4 cycles instead of 1.
5. 640 × 480 × 2 × 60 = **36.9 MB/s**. (Fits easily in 200 MB/s SDRAM, but only if the GPU leaves enough bandwidth for the display. That's why the display gets priority in the memory arbiter.)
6. 12 bytes per 2 FLOPs → 1 GB/s ÷ 12 × 2 ≈ **167 MFLOP/s**, regardless of how many ALUs you have.

</details>

---

**Next:** [Lesson 8 — Computer Arithmetic](08_computer_arithmetic.md)
