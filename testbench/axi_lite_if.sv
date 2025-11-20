// tb top

module tb_top;

  logic ACLK;
  logic ARESETn;

  // Clock generation
  initial begin
    ACLK = 0;
    forever #5 ACLK = ~ACLK;
  end

  // Reset generation
  initial begin
    ARESETn = 0;
    repeat (5) @(posedge ACLK);
    ARESETn = 1;
  end

  // Instantiate the AXI interface already provided by design team
  axi4_if axi_if(
    .ACLK(ACLK),
    .ARESETn(ARESETn)
  );

  // Instantiate DUT
  axi_comm u_dut (
    .axi(axi_if)   // They probably used modport or interface port
  );

  // Simple AXI write/read tasks right inside tb_top
  task automatic axi_write(input [31:0] addr, input [31:0] data);
    // AW channel
    axi_if.AWADDR  <= addr;
    axi_if.AWVALID <= 1;
    @(posedge ACLK);
    wait(axi_if.AWREADY);
    axi_if.AWVALID <= 0;

    // W channel
    axi_if.WDATA  <= data;
    axi_if.WSTRB  <= 4'hF;
    axi_if.WVALID <= 1;
    @(posedge ACLK);
    wait(axi_if.WREADY);
    axi_if.WVALID <= 0;

    // B channel
    axi_if.BREADY <= 1;
    wait(axi_if.BVALID);
    axi_if.BREADY <= 0;
  endtask

  task automatic axi_read(input [31:0] addr, output [31:0] data);
    // AR channel
    axi_if.ARADDR  <= addr;
    axi_if.ARVALID <= 1;
    @(posedge ACLK);
    wait(axi_if.ARREADY);
    axi_if.ARVALID <= 0;

    // R channel
    axi_if.RREADY <= 1;
    wait(axi_if.RVALID);
    data = axi_if.RDATA;
    axi_if.RREADY <= 0;
  endtask

  logic [31:0] rd_data;

  initial begin
    @(posedge ARESETn);

    $display("----- AXI SIMPLE TB START -----");

    axi_write(32'h00, 32'hDEADBEEF);
    axi_read(32'h00, rd_data);
    $display("Read[0] = %h", rd_data);

    axi_write(32'h04, 32'h12345678);
    axi_read(32'h04, rd_data);
    $display("Read[4] = %h", rd_data);

    $display("----- AXI SIMPLE TB END -----");

    #50 $finish;
  end

endmodule
