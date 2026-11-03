// tb_traffic.v
// Run: iverilog -o traffic.vvp traffic_light.v tb_traffic.v && vvp -n traffic.vvp
`timescale 1ns/1ps
module tb_traffic;
  reg clk = 0, rst = 1, button = 0;
  always #5 clk = ~clk;
  wire [2:0] lights;
  traffic_light u_tl (.clk(clk), .rst(rst), .button(button), .lights(lights));

  function [6*8-1:0] name(input [2:0] l);
    name = (l == 3'b001) ? "GREEN " : (l == 3'b010) ? "YELLOW" : "RED   ";
  endfunction

  integer cyc;
  initial begin
    @(posedge clk); #1 rst = 0;
    for (cyc = 0; cyc < 26; cyc = cyc + 1) begin
      button = (cyc == 18);            // someone presses the button in cycle 18
      $display("cycle %2d: %s  state=%0d timer=%0d %s", cyc, name(lights), u_tl.state,
               u_tl.timer, button ? "<- button pressed" : "");
      @(posedge clk); #1;
    end
    $finish;
  end
endmodule
