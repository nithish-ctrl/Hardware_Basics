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
