// tb_handshake.v: a producer sends 0,1,2,...,19 to a consumer using valid/ready.
// The consumer is randomly busy. A transfer happens ONLY in cycles where valid && ready.
// Run: iverilog -o handshake.vvp tb_handshake.v && vvp -n handshake.vvp
`timescale 1ns/1ps
module tb_handshake;
  reg clk = 0;
  always #5 clk = ~clk;

  // ---- producer ----
  reg       valid = 0;
  reg [7:0] data  = 0;
  reg [7:0] next_value = 0;
  // ---- consumer ----
  reg       ready = 0;
  reg [7:0] expected = 0;
  integer   errors = 0, cyc = 0, transfers = 0;

  wire fire = valid && ready;            // the one rule of the handshake

  // Producer: offer a value; when it is taken (fire), offer the next one.
  // It must NOT change data or drop valid while waiting for ready.
  always @(posedge clk) begin
    if (!valid || fire) begin
      if (next_value < 20) begin
        valid      <= 1;
        data       <= next_value;
        next_value <= next_value + 1;
      end else valid <= 0;
    end
  end

  // Consumer: randomly ready (like a busy memory). Checks the values arrive in order.
  always @(posedge clk) begin
    ready <= ($random & 3) != 0;          // ready about 75% of cycles
    if (fire) begin
      if (data !== expected) errors = errors + 1;
      expected  <= expected + 1;
      transfers = transfers + 1;
    end
  end

  initial begin
    $display("cyc valid ready data | event");
    for (cyc = 0; cyc < 40; cyc = cyc + 1) begin
      @(negedge clk);                     // look in the middle of the cycle
      $display("%3d   %b     %b   %3d  | %0s", cyc, valid, ready, data,
               fire ? "TRANSFER" : (valid ? "waiting (consumer busy)" : "idle"));
    end
    if (transfers == 20 && errors == 0) $display("PASS: 20 values transferred in order, none lost or repeated");
    else $display("FAIL: transfers=%0d errors=%0d", transfers, errors);
    $finish;
  end
endmodule
