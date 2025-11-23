module tb_top;

  // Clock and Reset Generation (OPTIONAL FOR ASYNCHRONOUS READ ONLY)
  /*logic ACLK;
  logic ARESETn;
  initial begin ACLK = 1'b0; forever #5 ACLK = ~ACLK; end
  initial begin ARESETn = 1'b0; repeat (4) @(posedge ACLK); ARESETn = 1'b1; end 
*/

  axi4_if #(.ADDR_W(32), .DATA_W(64), .ID_W(4)) axi_if (.ACLK(ACLK), .ARESETn(ARESETn));   // AXI Interface Instantiation
  
  subordinate2 #(.ADDR_W(32), .DATA_W(64), .ID_W(4)) dut (.bus_ports(axi_if.subordinate_mp));   // DUT Instantiation (Subordinate)

  // AXI Response Codes
  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_DECERR = 2'b11; // Decode Error

  // AXI-Lite Write Task (Used ONLY for Test Setup/Initialization)
  task automatic axi_lite_write(
    input  logic [3:0]  id,
    input  logic [31:0] addr,
    input  logic [63:0] data,
    input  logic [1:0]  expected_resp
  );
    $display("-------------------------------------------------------");
    $display("[%0t] [W-SETUP] Writing to 0x%08h, Data=0x%016h...", $time, addr, data);

    // Setup AW/W channel signals
    axi_if.manager_mp.AWID     <= id;
    axi_if.manager_mp.AWADDR   <= addr;
    axi_if.manager_mp.AWVALID  <= 1'b1;

    axi_if.manager_mp.WDATA    <= data;
    axi_if.manager_mp.WSTRB    <= 8'hFF; 
    axi_if.manager_mp.WLAST    <= 1'b1;    
    axi_if.manager_mp.WVALID   <= 1'b1;
    axi_if.manager_mp.BREADY   <= 1'b0;

    // Wait for address and data acceptance
    do @(posedge ACLK); while (!axi_if.manager_mp.AWREADY || !axi_if.manager_mp.WREADY);
    
    // De-assert AWVALID and WVALID after handshake
    axi_if.manager_mp.AWVALID <= 1'b0;
    axi_if.manager_mp.WVALID  <= 1'b0;

    // B channel: wait for response
    axi_if.manager_mp.BREADY <= 1'b1;
    do @(posedge ACLK); 
    while (!axi_if.manager_mp.BVALID);

    // Complete B handshake (Ignore response check for setup)
    axi_if.manager_mp.BREADY <= 1'b0;
    @(posedge ACLK);
  endtask
  
  // AXI-Lite Read Task (Primary Test Focus)
  task automatic axi_lite_read(
    input  logic [3:0]  id,
    input  logic [31:0] addr,
    input  logic [63:0] expected_data,
    input  logic [1:0]  expected_resp 
  );
    logic [63:0] received_data;
    
    $display("-------------------------------------------------------");
    $display("[%0t] [R-TEST] Read from 0x%08h. Expected Data=0x%016h, Expected Resp=0b%b", $time, addr, expected_data, expected_resp);

    // Setup AR channel signals
    axi_if.manager_mp.ARID     <= id;
    axi_if.manager_mp.ARADDR   <= addr;
    axi_if.manager_mp.ARVALID  <= 1'b1;
    axi_if.manager_mp.RREADY   <= 1'b0;

    // Wait for address acceptance
    do @(posedge ACLK); 
    while (!axi_if.manager_mp.ARREADY);
    axi_if.manager_mp.ARVALID <= 1'b0;

    // R channel: wait for data and response
    axi_if.manager_mp.RREADY <= 1'b1;
    do @(posedge ACLK);   
    while (!axi_if.manager_mp.RVALID);
    
    received_data = axi_if.RDATA;

    // Check response and data (Self-Checking Logic)
    if (axi_if.RRESP == expected_resp) begin
        if (expected_resp == RESP_OKAY) begin
            if (received_data == expected_data) begin
                $display("[%0t] [R-END] SUCCESS (OKAY): Data matched (0x%016h).", $time, received_data);
            end else begin
                 $error("[%0t] [R-END] FAILURE (Data Mismatch): Read 0x%016h, Expected 0x%016h.", 
                       $time, received_data, expected_data);
            end
        end else if (expected_resp == RESP_DECERR) begin
            $display("[%0t] [R-END] SUCCESS (DECERR): Received expected Decode Error.", $time);
        end
    end else begin
        $error("[%0t] [R-END] FAILURE (Response Mismatch): Expected 0b%b but received 0b%b.", 
               $time, expected_resp, axi_if.RRESP);
    end

    // Complete R handshake
    axi_if.manager_mp.RREADY <= 1'b0;
    @(posedge ACLK);
  endtask

  // Test Sequence
  initial begin
    // Initialize control signals
    axi_if.manager_mp.AWVALID  = 1'b0;
    axi_if.manager_mp.WVALID   = 1'b0;
    axi_if.manager_mp.BREADY   = 1'b0;
    axi_if.manager_mp.ARVALID  = 1'b0;
    axi_if.manager_mp.RREADY   = 1'b0;

    @(posedge ARESETn);
    @(posedge ACLK);
    $display("========== AXI-LITE READ-ONLY TB START ==========");

    // --- SETUP: Write Initial Data ---
    $display("\n--- SETUP PHASE: Writing initial data for subsequent reads ---");
    axi_lite_write(4'd1, 32'h0000_0008, 64'hCAFE_BAB0_F00D_FACE, RESP_OKAY);
    axi_lite_write(4'd2, 32'h0000_0010, 64'h1122_3344_5566_7788, RESP_OKAY);
    axi_lite_write(4'd3, 32'h0000_0FF8, 64'hBEEF_CFFE_0000_FFFF, RESP_OKAY);

    //SCENARIO 1
    $display("\n--- SCENARIO 1: Basic Read Checks (Mapped Addresses) ---");
    
    // Read Address 0x8
    axi_lite_read(4'd4, 32'h0000_0008, 64'hCAFE_BAB0_F00D_FACE, RESP_OKAY);
    // Read Address 0x10
    axi_lite_read(4'd5, 32'h0000_0010, 64'h1122_3344_5566_7788, RESP_OKAY);
    // Read Edge Case (Highest Mapped Address 0xFF8)
    axi_lite_read(4'd6, 32'h0000_0FF8, 64'hBEEF_CFFE_0000_FFFF, RESP_OKAY);


    //SCENARIO 2
    $display("\n--- SCENARIO 2: Read Decode Error Check (DECERR) ---");

    // Read from an unmapped address (above the 4KB boundary: 0x2000)
    // For DECERR, the returned data should be ignored or typically zeroed out.
    axi_lite_read(4'd7, 32'h0000_2000, 64'h0, RESP_DECERR); 
    // Read from a high, unmapped address
    axi_lite_read(4'd8, 32'hFFFF_FFF0, 64'h0, RESP_DECERR); 


    //SCENARIO 3
    $display("\n--- SCENARIO 3: Sequential Read Accesses ---");

    // Read 0x8
    axi_lite_read(4'd9, 32'h0000_0008, 64'hCAFE_BAB0_F00D_FACE, RESP_OKAY);
    // Read 0x10
    axi_lite_read(4'd10, 32'h0000_0010, 64'h1122_3344_5566_7788, RESP_OKAY);
    // Read unmapped 0x2000
    axi_lite_read(4'd11, 32'h0000_2000, 64'h0, RESP_DECERR);
    $display("========== AXI-LITE READ-ONLY TB END (Self-Check Complete) ==========");
    #50;
    $finish; // Simuation End
  end

endmodule
