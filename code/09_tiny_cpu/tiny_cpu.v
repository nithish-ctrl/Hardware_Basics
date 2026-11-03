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
