// ------------------------------------------------------------
// AXI4-Lite READ task (64-bit)
// ------------------------------------------------------------
task automatic axi_lite_read(
    input  logic [3:0]  id,
    input  logic [31:0] addr,
    output logic [63:0] data
);

    $display("[TB] READ addr=%h", addr);

    axi_if.manager_mp.ARID    <= id;
    axi_if.manager_mp.ARADDR  <= addr;
    axi_if.manager_mp.ARLEN   <= 0;
    axi_if.manager_mp.ARSIZE  <= 3;
    axi_if.manager_mp.ARBURST <= 1;
    axi_if.manager_mp.ARVALID <= 1;

    @(posedge ACLK);
    while (!axi_if.manager_mp.ARREADY) @(posedge ACLK);
    axi_if.manager_mp.ARVALID <= 0;

    axi_if.manager_mp.RREADY <= 1;

    @(posedge ACLK);
    while (!axi_if.manager_mp.RVALID) @(posedge ACLK);

    data = axi_if.RDATA;

    if (axi_if.RRESP != 0)
        $error("RRESP error: %0b", axi_if.RRESP);

    axi_if.manager_mp.RREADY <= 0;

    $display("[TB] READ data=%h", data);

endtask
