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
