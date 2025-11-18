interface axi4_if #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 64,
  parameter int ID_W   = 4
)(
  input  logic ACLK,
  input  logic ARESETn
);
  localparam int STRB_W = DATA_W/8;

  // --- Write Address (AW) ---
  logic [ID_W-1:0]   AWID;
  logic [ADDR_W-1:0] AWADDR;
  logic [7:0]        AWLEN;    // beats-1
  logic [2:0]        AWSIZE;   // log2(bytes/beat)
  logic [1:0]        AWBURST;  // 01=INCR
  logic              AWVALID, AWREADY;

  // --- Write Data (W) ---
  logic [DATA_W-1:0] WDATA;
  logic [STRB_W-1:0] WSTRB;
  logic              WLAST, WVALID, WREADY;

  // --- Write Response (B) ---
  logic [ID_W-1:0]   BID;
  logic [1:0]        BRESP;    // 00=OKAY, 10=SLVERR, 11=DECERR (impl dependent)
  logic              BVALID, BREADY;

  // --- Read Address (AR) ---
  logic [ID_W-1:0]   ARID;
  logic [ADDR_W-1:0] ARADDR;
  logic [7:0]        ARLEN;
  logic [2:0]        ARSIZE;
  logic [1:0]        ARBURST;  // 01=INCR
  logic              ARVALID, ARREADY;

  // --- Read Data (R) ---
  logic [ID_W-1:0]   RID;
  logic [DATA_W-1:0] RDATA;
  logic [1:0]        RRESP;
  logic              RLAST, RVALID, RREADY;

  // -------- Modports --------
  // Manager
  modport manager_mp (
    // AW
    output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID,
    input  AWREADY,
    // W
    output WDATA, WSTRB, WLAST, WVALID,
    input  WREADY,
    // B
    input  BID, BRESP, BVALID,
    output BREADY,
    // AR
    output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
    input  ARREADY,
    // R
    input  RID, RDATA, RRESP, RLAST, RVALID,
    output RREADY,
    // clk/rst
    input  ACLK, ARESETn
  );

  // Subordinate
  modport subordinate_mp (
    // AW
    input  AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID,
    output AWREADY,
    // W
    input  WDATA, WSTRB, WLAST, WVALID,
    output WREADY,
    // B
    output BID, BRESP, BVALID,
    input  BREADY,
    // AR
    input  ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
    output ARREADY,
    // R
    output RID, RDATA, RRESP, RLAST, RVALID,
    input  RREADY,
    // clk/rst
    input  ACLK, ARESETn
  );

endinterface
