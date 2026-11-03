// tb_comb.v: EXHAUSTIVE tests. Small blocks have few inputs, so we try every combination.
// Run: iverilog -o comb.vvp ../03_logic_gates/full_adder.v comb_blocks.v tb_comb.v && vvp -n comb.vvp
`timescale 1ns/1ps
module tb_comb;
  integer i, j, k, errors = 0;

  // ---- mux4 ----
  reg  [1:0] sel;
  wire [7:0] my;
  mux4 #(.W(8)) u_mux (.d0(8'd10), .d1(8'd20), .d2(8'd30), .d3(8'd40), .sel(sel), .y(my));

  // ---- decoder ----
  reg  [1:0] din; reg den;
  wire [3:0] dout;
  decoder2to4 u_dec (.in(din), .en(den), .out(dout));

  // ---- comparator + adder ----
  reg  [3:0] a, b; reg cin;
  wire eq, lt, gt, cout;
  wire [3:0] sum;
  comparator4 u_cmp (.a(a), .b(b), .eq(eq), .lt(lt), .gt(gt));
  adder4      u_add (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));

  // ---- shifter ----
  reg  [7:0] sx; reg [2:0] amt; reg left;
  wire [7:0] sy;
  shifter8 u_sh (.x(sx), .amount(amt), .left(left), .y(sy));

  initial begin
    // mux: each select value must route the matching input
    for (i = 0; i < 4; i = i + 1) begin
      sel = i; #1;
      if (my !== (i + 1) * 10) errors = errors + 1;
    end
    $display("mux4    : sel=0..3 gives 10,20,30,40");

    // decoder: one-hot output
    den = 1;
    for (i = 0; i < 4; i = i + 1) begin
      din = i; #1;
      $display("decoder : in=%0d -> out=%b", din, dout);
      if (dout !== (4'b0001 << i)) errors = errors + 1;
    end
    den = 0; #1; if (dout !== 4'b0000) errors = errors + 1;

    // comparator + adder: all 16 x 16 x 2 = 512 combinations
    for (i = 0; i < 16; i = i + 1)
      for (j = 0; j < 16; j = j + 1)
        for (k = 0; k < 2; k = k + 1) begin
          a = i; b = j; cin = k; #1;
          if ({cout, sum} !== i + j + k) errors = errors + 1;
          if (eq !== (i == j) || lt !== (i < j) || gt !== (i > j)) errors = errors + 1;
        end
    a = 4'd9; b = 4'd8; cin = 0; #1;
    $display("adder4  : 9 + 8 = %0d -> sum=%b cout=%b (cout is the 5th bit: 16)", {cout, sum}, sum, cout);

    // shifter: all values, amounts, directions
    for (i = 0; i < 256; i = i + 1)
      for (j = 0; j < 8; j = j + 1)
        for (k = 0; k < 2; k = k + 1) begin
          sx = i; amt = j; left = k; #1;
          if (sy !== (k ? ((i << j) & 8'hFF) : (i >> j))) errors = errors + 1;
        end
    sx = 8'b0000_0101; amt = 2; left = 1; #1;
    $display("shifter : 5 << 2 = %0d (shifting left by n multiplies by 2^n)", sy);

    if (errors == 0) $display("PASS: all combinational blocks correct (exhaustive)");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
