`timescale 1ns/1ps

module tb_axi_lite_write;

  logic ACLK;
  logic ARESETn;

  // Clock
  initial begin
      ACLK = 0;
      forever #5 ACLK = ~ACLK;
  end

  // Reset
  initial begin
      ARESETn = 0;
      repeat (4) @(posedge ACLK);
      ARESETn = 1;
  end

  // DUT + Interface
  axi4_if #(32,64,4) axi_if (.ACLK(ACLK), .ARESETn(ARESETn));
  axi_subordinate dut (.s(axi_if.subordinate_mp));   // using slave modport

  // AXI-Lite constants
  localparam RESP_OKAY   = 2'b00;
  localparam RESP_SLVERR = 2'b10;
  localparam RESP_DECERR = 2'b11;

  // --------------------------------------------------------
  // TASK: AXI4-Lite Single Beat Write
  // --------------------------------------------------------
  task automatic axi_lite_write(
      input logic [3:0]  id,
      input logic [31:0] addr,
      input logic [63:0] data
  );
      $display("\n---- WRITE START addr=%h data=%h ----", addr, data);

      // --------------------------
      // Write Address Channel (AW)
      // --------------------------
      axi_if.manager_mp.AWID     <= id;
      axi_if.manager_mp.AWADDR   <= addr;
      axi_if.manager_mp.AWLEN    <= 8'd0;       // AXI-Lite = single beat
      axi_if.manager_mp.AWSIZE   <= 3;          // 8 bytes (64-bit)
      axi_if.manager_mp.AWBURST  <= 2'b01;      // INCR (AXI-Lite compliant)
      axi_if.manager_mp.AWVALID  <= 1;

      @(posedge ACLK);
      while (!axi_if.manager_mp.AWREADY) @(posedge ACLK);
      axi_if.manager_mp.AWVALID <= 0;

      // --------------------------
      // Write Data Channel (W)
      // --------------------------
      axi_if.manager_mp.WDATA  <= data;
      axi_if.manager_mp.WSTRB  <= 8'hFF;        // full byte enable
      axi_if.manager_mp.WLAST  <= 1;            // AXI-Lite = always 1
      axi_if.manager_mp.WVALID <= 1;

      @(posedge ACLK);
      while (!axi_if.manager_mp.WREADY) @(posedge ACLK);
      axi_if.manager_mp.WVALID <= 0;
      axi_if.manager_mp.WLAST  <= 0;

      // --------------------------
      // Write Response Channel (B)
      // --------------------------
      axi_if.manager_mp.BREADY <= 1;

      @(posedge ACLK);
      while (!axi_if.manager_mp.BVALID) @(posedge ACLK);

      if (axi_if.BRESP != RESP_OKAY)
          $error("[TB] BRESP ERROR: expected OKAY (00), got %b", axi_if.BRESP);
      else
          $display("[TB] BRESP OKAY (00)");

      axi_if.manager_mp.BREADY <= 0;

      $display("---- WRITE END ----\n");
  endtask

  // --------------------------------------------------------
  // SELF-CHECK MEMORY (Lite = only one beat)
  // --------------------------------------------------------
  task automatic axi_lite_check_mem(
      input logic [31:0] addr,
      input logic [63:0] expected
  );
      logic [63:0] read_val;
      for (int i = 0; i < 8; i++)
          read_val[8*i +: 8] = dut.mem[addr + i];

      if (read_val !== expected)
          $error("[TB] MEM MISMATCH @%h expected=%h got=%h",
                  addr, expected, read_val);
      else
          $display("[TB] MEM OK @%h : %h", addr, read_val);
  endtask

  // --------------------------------------------------------
  // TESTCASE
  // --------------------------------------------------------
  initial begin
      @(posedge ARESETn);

      logic [63:0] data1 = 64'hCAFE_F00D_DEAD_BEEF;
      logic [63:0] data2 = 64'h1234_5678_ABCD_EF77;

      // Test 1: simple write
      axi_lite_write(4'd1, 32'h0000_0010, data1);
      axi_lite_check_mem(32'h0000_0010, data1);

      // Test 2: another write
      axi_lite_write(4'd2, 32'h0000_0080, data2);
      axi_lite_check_mem(32'h0000_0080, data2);

      $display("\n========== AXI-LITE WRITE TEST COMPLETE ==========\n");
      #50 $finish;
  end

endmodule
