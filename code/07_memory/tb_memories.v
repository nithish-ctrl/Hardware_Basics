// tb_memories.v
// Run: iverilog -o mem.vvp memories.v tb_memories.v && vvp -n mem.vvp
`timescale 1ns/1ps
module tb_memories;
  reg clk = 0;
  always #5 clk = ~clk;
  integer i, errors = 0;

  // ---------------- part 1: RAM read latency ----------------
  reg        we = 0;
  reg  [3:0] addr = 0;
  reg  [7:0] wdata = 0;
  wire [7:0] rdata;
  ram_sync #(.AW(4), .DW(8)) u_ram (.clk(clk), .we(we), .addr(addr), .wdata(wdata), .rdata(rdata));

  // ---------------- part 2: FIFO vs a software model ----------------
  reg        rst = 1, wr_en = 0, rd_en = 0;
  reg  [7:0] wr_data = 0;
  wire [7:0] rd_data;
  wire       full, empty;
  sync_fifo #(.DW(8), .AW(2)) u_fifo (.clk(clk), .rst(rst), .wr_en(wr_en), .wr_data(wr_data),
    .full(full), .rd_en(rd_en), .rd_data(rd_data), .empty(empty));

  reg [7:0] model [0:255];             // software FIFO: an array with head/tail counters
  integer head = 0, tail = 0, pushes = 0, pops = 0;

  initial begin
    // Write 100, 101, ... into addresses 0..7
    for (i = 0; i < 8; i = i + 1) begin
      we = 1; addr = i; wdata = 100 + i;
      @(posedge clk); #1;
    end
    we = 0;
    $display("RAM read latency (address given in a cycle, data shows up the NEXT cycle):");
    for (i = 0; i < 5; i = i + 1) begin
      addr = i;
      $display("  cycle %0d: addr=%0d   rdata=%0d", i, addr, rdata);
      @(posedge clk); #1;
    end
    $display("  -> rdata always shows the data for the PREVIOUS cycle's address.");

    // FIFO: random pushes/pops, compare every popped value to the model
    @(posedge clk); #1 rst = 0;
    for (i = 0; i < 400; i = i + 1) begin
      wr_en = $random & 1; rd_en = $random & 1; wr_data = $random;
      // check BEFORE the edge: what will be read this cycle
      if (rd_en && !empty) begin
        if (rd_data !== model[head % 256]) errors = errors + 1;
        head = head + 1; pops = pops + 1;
      end
      if (wr_en && !full) begin
        model[tail % 256] = wr_data; tail = tail + 1; pushes = pushes + 1;
      end
      @(posedge clk); #1;
      // after the edge, the hardware's full/empty must agree with the model's count
      if (empty !== (tail == head) || full !== (tail - head == 4)) errors = errors + 1;
    end
    $display("FIFO: %0d pushes, %0d pops, depth 4", pushes, pops);
    if (errors == 0) $display("PASS: FIFO matched the software model every cycle");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
