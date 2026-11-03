// fixed_point.v: signed Q8.8 arithmetic (16 bits = 8 integer bits incl. sign + 8 fraction bits)
// A Q8.8 number stored as integer N means the real value N / 256.

module q88_mul (
  input  wire signed [15:0] a, b,        // Q8.8
  output wire signed [15:0] y,           // Q8.8 (truncated toward -infinity)
  output wire               overflow     // true result does not fit in Q8.8
);
  wire signed [31:0] full = a * b;       // Q16.16: 16x16 bits -> 32 bits, 16 fraction bits
  wire signed [23:0] shifted = full[31:8];  // drop 8 fraction bits -> 8 left (Q16.8)
  assign y = shifted[15:0];
  // fits only if the top bits are all copies of the sign bit
  assign overflow = (shifted[23:15] != {9{shifted[15]}});
endmodule

// Linear interpolation: y = a + (b - a) * t, with t in [0, 1) as an unsigned 0.8 fraction.
// This exact operation is everywhere in graphics: color blending, texture filtering.
module lerp8 (
  input  wire [7:0] a, b,                // e.g. two color intensities 0..255
  input  wire [7:0] t,                   // t/256 = how far from a toward b
  output wire [7:0] y
);
  wire signed [8:0]  diff = $signed({1'b0, b}) - $signed({1'b0, a});   // -255..255 needs 9 bits
  wire signed [17:0] scaled = diff * $signed({1'b0, t});               // 9 bits x 9 bits
  assign y = a + scaled[15:8];                                        // divide by 256
endmodule
