/* 
*  Author: 	Senkathir Mutharasu
*  Editors: 
*  Requires:
*/
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
  //logic [ID_W-1:0]   AWID;
  logic [ADDR_W-1:0] AWADDR;
  //logic [7:0]        AWLEN;    // beats-1
  //logic [2:0]        AWSIZE;   // log2(bytes/beat)
  //logic [1:0]        AWBURST;  // 01=INCR
  logic              AWVALID, AWREADY;

  // --- Write Data (W) ---
  logic [DATA_W-1:0] WDATA;
  logic [STRB_W-1:0] WSTRB;
  //logic              WLAST;
  logic WVALID, WREADY;

  // --- Write Response (B) ---
  //logic [ID_W-1:0]   BID;
  logic [1:0]        BRESP;    // 00=OKAY, 10=SLVERR, 11=DECERR (impl dependent)
  logic              BVALID, BREADY;

  // --- Read Address (AR) ---
  //logic [ID_W-1:0]   ARID;
  logic [ADDR_W-1:0] ARADDR;
  //logic [7:0]        ARLEN;
  //logic [2:0]        ARSIZE;
  //logic [1:0]        ARBURST;  // 01=INCR
  logic              ARVALID, ARREADY;

  // --- Read Data (R) ---
  //logic [ID_W-1:0]   RID;
  logic [DATA_W-1:0] RDATA;
  logic [1:0]        RRESP;
  //logic              RLAST;
  logic	    RVALID, RREADY;

  // -------- Modports --------
  // Manager
  modport manager_mp (
    // AW
    //output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID,
    output AWADDR, AWVALID,
    input  AWREADY,
    // W
    output WDATA, WSTRB, WVALID,
    //output WLAST,
    input  WREADY,
    // B
    input  BRESP, BVALID,
    //input  BID, 
    output BREADY,
    // AR
    output ARADDR, ARVALID,
    //output ARID, ARLEN, ARSIZE, ARBURST,
    input  ARREADY,
    // R
    input  RDATA, RRESP, RVALID,
    //input  RID, RLAST,
    output RREADY,
    // clk/rst
    input  ACLK, ARESETn
  );

  // Subordinate
  modport subordinate_mp (
    // AW
    input  AWADDR, AWVALID,
    //input  AWID, AWLEN, AWSIZE, AWBURST,
    output AWREADY,
    // W
    input  WDATA, WSTRB, WVALID,
    //input WLAST,
    output WREADY,
    // B
    //output BID, BRESP, BVALID,
    output BRESP, BVALID,
    input  BREADY,
    // AR
    input  ARADDR, ARVALID,
    //input  ARID, ARLEN, ARSIZE, ARBURST,
    output ARREADY,
    // R
    output RDATA, RRESP, RVALID,
    //output RID, RLAST,
    input  RREADY,
    // clk/rst
    input  ACLK, ARESETn
  );

endinterface
