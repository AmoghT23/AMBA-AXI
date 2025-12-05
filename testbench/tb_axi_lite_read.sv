/*
*  Author: Amogh Thakur
*  Editors: Amogh Thakur
*/

// AXI Lite Read Task
module do_read #
(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 64
)
(
    input  logic                ACLK,
    input  logic                ARESETn,

    // AXI Lite master --> subordinate
    output logic [ADDR_W-1:0]  ARADDR,
    output logic                ARVALID,
    input  logic                ARREADY,

    // AXI Lite subordinate --> master
    input  logic [DATA_W-1:0]   RDATA,
    input  logic [1:0]          RRESP,
    input  logic                RVALID,
    output logic                RREADY
);

    // Task for performing a single AXI Lite read
    task automatic do_read(
        input  logic [ADDR_W-1:0] addr_i,
        output logic [DATA_W-1:0] data_out_i,
        output logic [1:0]        rresp_i
    );
    begin
        //  Issue AR 
        ARADDR  <= addr_i;
        ARVALID <= 1'b1;
        RREADY  <= 1'b1;  // ready to accept read data

        // Wait for subordinate to accept AR
        wait (ARREADY && ARVALID);
        @(posedge ACLK);   // synchronize with clock
        ARVALID <= 1'b0;   // lower ARVALID once accepted

        //  Wait for R
        wait (RVALID && RREADY);
        @(posedge ACLK);   // latch data
        data_out_i = RDATA;
        rresp_i    = RRESP;

        // Complete handshake
        RREADY <= 1'b0;
        @(posedge ACLK);
    end
    endtask

endmodule


