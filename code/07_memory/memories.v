// memories.v

// RAM with SYNCHRONOUS read (this is how FPGA block RAM behaves):
// you give the address in cycle N, the data appears in cycle N+1.
module ram_sync #(parameter AW = 4, DW = 8) (
  input  wire          clk,
  input  wire          we,          // write enable
  input  wire [AW-1:0] addr,
  input  wire [DW-1:0] wdata,
  output reg  [DW-1:0] rdata
);
  reg [DW-1:0] mem [0:(1<<AW)-1];   // 2^AW words of DW bits
  always @(posedge clk) begin
    if (we) mem[addr] <= wdata;
    rdata <= mem[addr];              // registered read -> one cycle of latency
  end
endmodule

// Synchronous FIFO (first in, first out), depth 2^AW
module sync_fifo #(parameter DW = 8, AW = 2) (
  input  wire          clk, rst,
  input  wire          wr_en,
  input  wire [DW-1:0] wr_data,
  output wire          full,
  input  wire          rd_en,
  output wire [DW-1:0] rd_data,
  output wire          empty
);
  reg [DW-1:0] mem [0:(1<<AW)-1];
  reg [AW:0]   wptr, rptr;           // ONE EXTRA BIT: the "lap" bit

  wire do_wr = wr_en && !full;
  wire do_rd = rd_en && !empty;

  always @(posedge clk) begin
    if (rst) begin
      wptr <= 0;
      rptr <= 0;
    end else begin
      if (do_wr) begin
        mem[wptr[AW-1:0]] <= wr_data;  // low bits = slot number
        wptr <= wptr + 1'b1;
      end
      if (do_rd) rptr <= rptr + 1'b1;
    end
  end

  assign rd_data = mem[rptr[AW-1:0]];
  assign empty   = (wptr == rptr);                                  // same slot, same lap
  assign full    = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);  // same slot, writer one lap ahead
endmodule
