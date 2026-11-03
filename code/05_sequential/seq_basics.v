// seq_basics.v: circuits WITH memory. They only change on the rising clock edge.

// An 8-bit register with synchronous reset and enable
module register8 (
  input  wire       clk,
  input  wire       rst,     // when 1 at a clock edge: q becomes 0
  input  wire       en,      // when 1 at a clock edge: q captures d
  input  wire [7:0] d,
  output reg  [7:0] q
);
  always @(posedge clk) begin
    if (rst)     q <= 8'd0;
    else if (en) q <= d;
    // else: q keeps its value (that is what "memory" means)
  end
endmodule

// A 4-bit counter: 0, 1, 2, ... 15, 0, 1, ... (wraps around, because 15 + 1 = 16 needs 5 bits)
module counter4 (
  input  wire       clk,
  input  wire       rst,
  output reg  [3:0] count
);
  always @(posedge clk) begin
    if (rst) count <= 4'd0;
    else     count <= count + 4'd1;
  end
endmodule

// A 4-bit shift register: each edge, every bit moves one place and a new bit enters
module shift_reg4 (
  input  wire       clk,
  input  wire       rst,
  input  wire       serial_in,
  output reg  [3:0] q
);
  always @(posedge clk) begin
    if (rst) q <= 4'b0000;
    else     q <= {q[2:0], serial_in};   // drop the top bit, append the new one at the bottom
  end
endmodule
