// tb top

`timescale 1ns/1ps
import hook::*;

module tb_top;

  // Clock + Reset
  logic ACLK;
  logic ARESETn;

  initial begin
    ACLK = 0;
    forever #5 ACLK = ~ACLK;   // 100 MHz
  end

  initial begin
    ARESETn = 0;
    repeat (4) @(posedge ACLK);
    ARESETn = 1;
  end

  // ----------------------------
  // Master <-> Slave signals
  // ----------------------------

  // AW channel
  logic [31:0] AWADDR;
  logic        AWVALID, AWREADY;

  // W channel
  logic [31:0] WDATA;
  logic        WVALID, WREADY;

  // B channel
  logic [1:0]  BRESP;
  logic        BVALID, BREADY;

  // AR channel
  logic [31:0] ARADDR;
  logic        ARVALID, ARREADY;

  // R channel
  logic [31:0] RDATA;
  logic [1:0]  RRESP;
  logic        RVALID, RREADY;

  // Hook struct input to master
  hook_t CTRL;

  // ----------------------------
  // Instantiate Master DUT
  // ----------------------------
  master dut (
    .ACLK(ACLK),
    .ARESETn(ARESETn),

    .RDATA(RDATA),
    .BRESP(BRESP),

    .AWREADY(AWREADY),
    .WREADY(WREADY),
    .BVALID(BVALID),
    .ARREADY(ARREADY),
    .RVALID(RVALID),

    .AWVALID(AWVALID),
    .WVALID(WVALID),
    .BREADY(BREADY),
    .ARVALID(ARVALID),
    .RREADY(RREADY),

    .AWADDR(AWADDR),
    .ARADDR(ARADDR),
    .WDATA(WDATA),

    .CTRL(CTRL)
  );

  // ----------------------------
  // SLAVE BEHAVIOR (simple mock)
  // ----------------------------
  always @(*) begin
    AWREADY = 1;
    WREADY  = 1;
    BVALID  = AWVALID & WVALID;   // respond to write
    BRESP   = 2'b00;              // OKAY

    ARREADY = 1;
    RVALID  = ARVALID;            // respond to read
    RRESP   = 2'b00;
    RDATA   = 32'hCAFEBABE;       // fixed read data
  end



endmodule
