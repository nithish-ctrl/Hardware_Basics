// tb_fixed.v
// Run: iverilog -o fixed.vvp fixed_point.v tb_fixed.v && vvp -n fixed.vvp
`timescale 1ns/1ps
module tb_fixed;
  reg  signed [15:0] a, b;
  wire signed [15:0] y;
  wire ovf;
  q88_mul u_mul (.a(a), .b(b), .y(y), .overflow(ovf));

  reg  [7:0] la, lb, t;
  wire [7:0] ly;
  lerp8 u_lerp (.a(la), .b(lb), .t(t), .y(ly));

  task show_mul(input real ra, input real rb);
    begin
      a = $rtoi(ra * 256.0); b = $rtoi(rb * 256.0); #1;
      $display("%8.4f x %8.4f : a=%6d b=%6d -> y=%6d = %9.5f  (exact %9.5f)%s",
               ra, rb, a, b, y, y / 256.0, ra * rb, ovf ? "  OVERFLOW" : "");
    end
  endtask

  integer i, errors = 0, exp;
  initial begin
    $display("Q8.8 multiply (value = stored integer / 256):");
    show_mul(3.25, -1.5);
    show_mul(0.5, 0.5);
    show_mul(1.1, 1.1);      // 1.1 is not exact in Q8.8 -> small error
    show_mul(100.0, 2.0);    // 200 > 127.996 -> overflow
    show_mul(-2.0, 64.0);    // exactly -128: the most negative value fits

    $display("\nlerp8: from a=40 to b=240");
    la = 40; lb = 240;
    for (i = 0; i <= 256; i = i + 64) begin
      t = (i == 256) ? 8'd255 : i; #1;
      $display("  t=%3d/256 -> %3d", t, ly);
    end
    // exhaustive check of lerp against the formula (floor division)
    for (i = 0; i < 65536; i = i + 1) begin
      la = i[7:0]; lb = i[15:8]; t = (i * 37) & 8'hFF; #1;
      exp = la + (((lb - la) * t) >>> 8);
      if (ly !== exp[7:0]) errors = errors + 1;
    end
    if (errors == 0) $display("PASS: lerp8 matches a + ((b-a)*t >> 8) for 65536 cases");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
