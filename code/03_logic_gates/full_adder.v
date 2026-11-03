// full_adder.v: adds three 1-bit inputs (a + b + carry-in) -> 2-bit result {cout, sum}
module full_adder (
  input  wire a,
  input  wire b,
  input  wire cin,
  output wire sum,
  output wire cout
);
  assign sum  = a ^ b ^ cin;                    // odd number of 1s -> sum bit is 1
  assign cout = (a & b) | (cin & (a ^ b));      // carry if at least two inputs are 1
endmodule

// xor_from_nand.v: XOR built only from NAND gates (NAND is "universal")
module xor_from_nand (
  input  wire a,
  input  wire b,
  output wire y
);
  wire n1 = ~(a & b);        // NAND(a, b)
  wire n2 = ~(a & n1);       // NAND(a, n1)
  wire n3 = ~(b & n1);       // NAND(b, n1)
  assign y = ~(n2 & n3);     // NAND(n2, n3) = a XOR b
endmodule
