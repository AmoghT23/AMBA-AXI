/*
Here write will act as master driving axi4_if.manager signals manually.

AW (address) → W (data) → B (response)

Checks BRESP against OKAY/SLVERR/DECERR.

*/

`timescale 1ns/1ps

module tb_write_full;

  // --------------------------------------------------
  // Clock and Reset
  // --------------------------------------------------
  logic ACLK;
  logic ARESETn;

  initial begin
    ACLK = 1'b0;
    forever #5 ACLK = ~ACLK;  // 100 MHz
  end

  initial begin
    ARESETn = 1'b0;
    repeat (4) @(posedge ACLK);
    ARESETn = 1'b1;
  end

  // --------------------------------------------------
  // AXI4 Interface + Subordinate DUT
  // --------------------------------------------------
  axi4_if #(
    .ADDR_W(32),
    .DATA_W(64),
    .ID_W  (4)
  ) axi_if (
    .ACLK   (ACLK),
    .ARESETn(ARESETn)
  );

  // DUT: AXI4 subordinate (memory slave)
  axi_subordinate #(
    .ADDR_W(32),
    .DATA_W(64),
    .ID_W  (4)
  ) dut (
    .s(axi_if.subordinate_mp)
  );

  // --------------------------------------------------
  // Local variables for checking
  // --------------------------------------------------
  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  localparam logic [1:0] RESP_DECERR = 2'b11;

  // --------------------------------------------------
  // Simple AXI single-beat write task
  // --------------------------------------------------
  task automatic axi_single_write(
    input  logic [3:0]  id,
    input  logic [31:0] addr,
    input  logic [63:0] data,
    input  logic [7:0]  strb = 8'hFF  // full-width write by default
  );
    // Setup default values
    axi_if.AWID     <= id;
    axi_if.AWADDR   <= addr;
    axi_if.AWLEN    <= 8'd0;     // single beat
    axi_if.AWSIZE   <= 3'd3;     // 8 bytes per beat (for DATA_W=64)
    axi_if.AWBURST  <= 2'b01;    // INCR
    axi_if.AWVALID  <= 1'b0;

    axi_if.WDATA    <= '0;
    axi_if.WSTRB    <= '0;
    axi_if.WLAST    <= 1'b0;
    axi_if.WVALID   <= 1'b0;

    axi_if.BREADY   <= 1'b0;

    @(posedge ACLK);
    // -----------------------------
    // AW channel: address phase
    // -----------------------------
    axi_if.AWVALID <= 1'b1;
    $display("[%0t] AW: addr=0x%08h, id=%0d", $time, addr, id);

    // Wait for slave to accept address
    do @(posedge ACLK); while (!axi_if.AWREADY);
    axi_if.AWVALID <= 1'b0;

    // -----------------------------
    // W channel: data phase
    // -----------------------------
    axi_if.WDATA  <= data;
    axi_if.WSTRB  <= strb;
    axi_if.WLAST  <= 1'b1;    // single beat
    axi_if.WVALID <= 1'b1;

    $display("[%0t] W: data=0x%016h, strb=0x%02h", $time, data, strb);

    // Wait for slave to accept data
    do @(posedge ACLK); while (!axi_if.WREADY);
    axi_if.WVALID <= 1'b0;
    axi_if.WLAST  <= 1'b0;

    // -----------------------------
    // B channel: response
    // -----------------------------
    axi_if.BREADY <= 1'b1;
    $display("[%0t] Waiting for B response...", $time);

    do @(posedge ACLK); while (!axi_if.BVALID);

    $display("[%0t] B: id=%0d, resp=0b%b", $time, axi_if.BID, axi_if.BRESP);

    if (axi_if.BRESP == RESP_OKAY) begin
      $display("[%0t] WRITE OKAY", $time);
    end
    else if (axi_if.BRESP == RESP_SLVERR) begin
      $error("[%0t] WRITE SLVERR", $time);
    end
    else if (axi_if.BRESP == RESP_DECERR) begin
      $error("[%0t] WRITE DECERR (decode error / addr range)", $time);
    end
    else begin
      $error("[%0t] WRITE unknown BRESP = %b", $time, axi_if.BRESP);
    end

    axi_if.BREADY <= 1'b0;
  endtask

  // --------------------------------------------------
  // Test sequence
  // --------------------------------------------------
  initial begin
    // Initialize master-side outputs to zero
    axi_if.AWID     = '0;
    axi_if.AWADDR   = '0;
    axi_if.AWLEN    = '0;
    axi_if.AWSIZE   = '0;
    axi_if.AWBURST  = '0;
    axi_if.AWVALID  = 1'b0;

    axi_if.WDATA    = '0;
    axi_if.WSTRB    = '0;
    axi_if.WLAST    = 1'b0;
    axi_if.WVALID   = 1'b0;

    axi_if.BREADY   = 1'b0;

    axi_if.ARID     = '0;
    axi_if.ARADDR   = '0;
    axi_if.ARLEN    = '0;
    axi_if.ARSIZE   = '0;
    axi_if.ARBURST  = '0;
    axi_if.ARVALID  = 1'b0;

    axi_if.RREADY   = 1'b0;

    @(posedge ARESETn);
    @(posedge ACLK);
    $display("========== AXI WRITE FULL TB START ==========");

    // 1) Simple single-beat INCR write inside 4KB range
    axi_single_write(4'd1, 32'h0000_0040, 64'hDEAD_BEEF_CAFE_1234);

    // 2) Another write to a different address
    axi_single_write(4'd2, 32'h0000_0080, 64'h0123_4567_89AB_CDEF);

    // 3) (Optional) Try an out-of-range address to hit DECERR
    //    Uncomment if you want to see error response
    // axi_single_write(4'd3, 32'h0001_1000, 64'hBAD0_BAD0_BAD0_BAD0);

    $display("========== AXI WRITE FULL TB END ==========");
    #50;
    $finish;
  end

endmodule
