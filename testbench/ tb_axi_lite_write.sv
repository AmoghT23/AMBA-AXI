/*
*  Author: Jaswanti Beeram
*  Editors: Jaswanti Beeram
*/

// AXI Lite Write Task

module do_write #
(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 64,
    parameter int STRB_W = DATA_W/8
)
(
    input  logic                ACLK,
    input  logic                ARESETn,

    // AXI Lite master -> subordinate
    output logic [ADDR_W-1:0]  AWADDR,
    output logic                AWVALID,
    input  logic                AWREADY,

    output logic [DATA_W-1:0]  WDATA,
    output logic [STRB_W-1:0]  WSTRB,
    output logic                WVALID,
    input  logic                WREADY,

    // AXI Lite subordinate -> master
    input  logic [1:0]          BRESP,
    input  logic                BVALID,
    output logic                BREADY
);

    // Task for performing a single AXI Lite write
    task automatic do_write(
        input logic [ADDR_W-1:0] addr_i,
        input logic [DATA_W-1:0] data_i,
        input logic [STRB_W-1:0] strb_i,
        output logic [1:0]        bresp_i
    );
    begin
        // ------------------- Issue AW -------------------
        AWADDR  <= addr_i;
        AWVALID <= 1'b1;
        WDATA   <= data_i;
        WSTRB   <= strb_i;
        WVALID  <= 1'b1;
        BREADY  <= 1'b1;  // ready to accept write response

        // Wait for AW and W handshake
        wait (AWVALID && AWREADY && WVALID && WREADY);
        @(posedge ACLK); // synchronize
        AWVALID <= 1'b0;
        WVALID  <= 1'b0;

        // ------------------- Wait for B -------------------
        wait (BVALID && BREADY);
        @(posedge ACLK);
        bresp_i = BRESP;

        // Complete handshake
        BREADY <= 1'b0;
        @(posedge ACLK);
    end
    endtask

endmodule
