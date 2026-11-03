// blocking_demo.v: the SAME code with = and <= builds DIFFERENT hardware.
// Run: iverilog -o blocking.vvp blocking_demo.v && vvp -n blocking.vvp
`timescale 1ns/1ps
module blocking_demo;
  reg clk = 0;
  always #5 clk = ~clk;

  reg in = 0;
  reg nb_a = 0, nb_b = 0, nb_c = 0;   // built with <=  (non-blocking)
  reg b_a  = 0, b_b  = 0, b_c  = 0;   // built with =   (blocking)

  // Non-blocking: all right-hand sides are read FIRST (old values), then all updated together.
  // Hardware: three flip-flops in a chain -> in takes 3 cycles to reach nb_c.
  always @(posedge clk) begin
    nb_a <= in;
    nb_b <= nb_a;
    nb_c <= nb_b;
  end

  // Blocking: each line finishes before the next one starts, like software.
  // b_b reads the NEW b_a, b_c reads the NEW b_b -> all three equal 'in' at once.
  // Hardware: effectively ONE flip-flop (b_a, b_b, b_c are copies of it).
  always @(posedge clk) begin
    b_a = in;
    b_b = b_a;
    b_c = b_b;
  end

  integer cyc;
  initial begin
    $display("cyc in | non-blocking a b c | blocking a b c");
    for (cyc = 0; cyc < 6; cyc = cyc + 1) begin
      in = (cyc == 0);                 // a single 1 in cycle 0, then 0s
      @(posedge clk); #1;
      $display("%3d  %b |        %b %b %b        |       %b %b %b",
               cyc, in, nb_a, nb_b, nb_c, b_a, b_b, b_c);
    end
    $display("With <= the 1 walks down the chain (3 flops). With = it appears everywhere at once (1 flop).");
    $finish;
  end
endmodule
