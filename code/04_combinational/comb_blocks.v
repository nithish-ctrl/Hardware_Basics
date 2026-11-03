// comb_blocks.v: the classic combinational building blocks.
// "Combinational" = output depends ONLY on the current inputs. No clock, no memory.

// 4-to-1 multiplexer: picks one of four inputs using a 2-bit select
module mux4 #(parameter W = 8) (
  input  wire [W-1:0] d0, d1, d2, d3,
  input  wire [1:0]   sel,
  output reg  [W-1:0] y
);
  always @(*) begin
    case (sel)
      2'd0: y = d0;
      2'd1: y = d1;
      2'd2: y = d2;
      default: y = d3;
    endcase
  end
endmodule

// 2-to-4 decoder: turns a binary number into "one-hot" (exactly one output is 1)
module decoder2to4 (
  input  wire [1:0] in,
  input  wire       en,
  output wire [3:0] out
);
  assign out = en ? (4'b0001 << in) : 4'b0000;
endmodule

// 4-bit comparator
module comparator4 (
  input  wire [3:0] a, b,
  output wire       eq, lt, gt
);
  assign eq = (a == b);
  assign lt = (a <  b);
  assign gt = (a >  b);
endmodule

// 4-bit ripple-carry adder built from four full adders (structural Verilog)
module adder4 (
  input  wire [3:0] a, b,
  input  wire       cin,
  output wire [3:0] sum,
  output wire       cout
);
  wire c1, c2, c3;   // carries between the stages
  full_adder fa0 (.a(a[0]), .b(b[0]), .cin(cin), .sum(sum[0]), .cout(c1));
  full_adder fa1 (.a(a[1]), .b(b[1]), .cin(c1),  .sum(sum[1]), .cout(c2));
  full_adder fa2 (.a(a[2]), .b(b[2]), .cin(c2),  .sum(sum[2]), .cout(c3));
  full_adder fa3 (.a(a[3]), .b(b[3]), .cin(c3),  .sum(sum[3]), .cout(cout));
endmodule

// 8-bit shifter: shift left or right by 0..7 places
module shifter8 (
  input  wire [7:0] x,
  input  wire [2:0] amount,
  input  wire       left,
  output wire [7:0] y
);
  assign y = left ? (x << amount) : (x >> amount);
endmodule
