// tb_logic.v: prints truth tables and checks them against arithmetic.
// Run: iverilog -o logic.vvp full_adder.v tb_logic.v && vvp -n logic.vvp
`timescale 1ns/1ps
module tb_logic;
  reg a, b, cin;
  wire sum, cout, x;
  integer i, errors = 0;

  full_adder    u_fa  (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
  xor_from_nand u_xor (.a(a), .b(b), .y(x));

  initial begin
    $display(" a b cin | cout sum | as a number");
    $display("---------+----------+------------");
    for (i = 0; i < 8; i = i + 1) begin
      {a, b, cin} = i;           // the 3 low bits of i become the 3 inputs
      #1;                        // let the combinational logic settle
      $display(" %b %b  %b  |   %b   %b  |  %0d + %0d + %0d = %0d",
               a, b, cin, cout, sum, a, b, cin, {cout, sum});
      if ({cout, sum} !== a + b + cin) errors = errors + 1;
      if (x !== (a ^ b)) errors = errors + 1;
    end
    if (errors == 0) $display("PASS: full adder and NAND-only XOR are correct for all inputs");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
