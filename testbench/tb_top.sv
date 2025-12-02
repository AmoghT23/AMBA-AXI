`timescale 1ns/1ps

module tb_top;

  // ===============================
  // Clock + Reset
  // ===============================
  logic ACLK;
  logic ARESETn;
  int   error_count = 0;

  initial begin
      ACLK = 0;
      forever #5 ACLK = ~ACLK;   // 100MHz
  end

  initial begin
      ARESETn = 0;
      repeat (4) @(posedge ACLK);
      ARESETn = 1;
  end

  // ===============================
  // AXI Interface
  // ===============================
  axi4_if #(32,64,4) axi_if (
      .ACLK(ACLK),
      .ARESETn(ARESETn)
  );

  // ===============================
  // MASTER COMMAND INTERFACE
  // ===============================
  logic         cmd_valid;
  logic         cmd_write;
  logic [31:0]  cmd_addr;
  logic [63:0]  cmd_wdata;
  logic [63:0]  cmd_rdata;
  logic         cmd_done;

  // ===============================
  // INSTANTIATE MASTER RTL
  // ===============================
  axi4_lite_master #(
      .ADDR_W(32), .DATA_W(64), .ID_W(4)
  ) u_master (
      .ACLK      (ACLK),
      .ARESETn   (ARESETn),
      .m         (axi_if.manager_mp),

      .cmd_valid (cmd_valid),
      .cmd_write (cmd_write),
      .cmd_addr  (cmd_addr),
      .cmd_wdata (cmd_wdata),
      .cmd_rdata (cmd_rdata),
      .cmd_done  (cmd_done)
  );

  // ===============================
  // INSTANTIATE SLAVE RTL
  // ===============================
  axi_subordinate dut (
      .s(axi_if.subordinate_mp)
  );

  // ===============================
  // Helper tasks to talk to MASTER RTL
  // ===============================
  task automatic master_write(input [31:0] addr, input [63:0] data);
      cmd_addr  = addr;
      cmd_wdata = data;
      cmd_write = 1;
      cmd_valid = 1;

      @(posedge ACLK);
      while (!cmd_done) @(posedge ACLK);

      cmd_valid = 0;
      @(posedge ACLK);
  endtask

  task automatic master_read(input [31:0] addr, output [63:0] data);
      cmd_addr  = addr;
      cmd_wdata = 0;
      cmd_write = 0;
      cmd_valid = 1;

      @(posedge ACLK);
      while (!cmd_done) @(posedge ACLK);

      data = cmd_rdata;
      cmd_valid = 0;
      @(posedge ACLK);
  endtask

  // ===============================
  // YOUR SAME 7 TEST CASES
  // ===============================
  logic [63:0] wdata, rdata;

  initial begin
      @(posedge ARESETn);
      $display("\n===== AXI4-LITE MASTER+SLAVE RTL TEST START =====\n");

      // ================================================================
      // TEST 1 — Basic Write / Readback
      // ================================================================
      wdata = 64'h1111_2222_3333_4444;
      master_write(32'h0000_0020, wdata);
      master_read (32'h0000_0020, rdata);

      if (rdata !== wdata) error_count++; else $display("[T1] PASS");

      // ================================================================
      // TEST 2
      // ================================================================
      wdata = 64'hAAAA_BBBB_CCCC_DDDD;
      master_write(32'h0000_0040, wdata);
      master_read (32'h0000_0040, rdata);

      if (rdata !== wdata) error_count++; else $display("[T2] PASS");

      // ================================================================
      // TEST 3 — high address
      // ================================================================
      wdata = 64'h1234_5678_ABCD_EF00;
      master_write(32'h0000_0FF0, wdata);
      master_read (32'h0000_0FF0, rdata);

      if (rdata !== wdata) error_count++; else $display("[T3] PASS");

      // ================================================================
      // TEST 4 — alignment
      // ================================================================
      wdata = 64'hDEAD_BEEF_FACE_CAFE;
      master_write(32'h0000_0038, wdata);
      master_read (32'h0000_0038, rdata);

      if (rdata !== wdata) error_count++; else $display("[T4] PASS");

      // ================================================================
      // TEST 5 — invalid address (DECERR)
      // ================================================================
      wdata = 64'hCAFEBABE_00112233;
      $display("[T5] Expect DECERR …");
      master_write(32'h0000_2000, wdata);
      master_read (32'h0000_2000, rdata);
      $display("[T5] DONE");

      // ================================================================
      // TEST 6 — overwrite
      // ================================================================
      logic [63:0] w1 = 64'h1010_2020_3030_4040;
      logic [63:0] w2 = 64'h9999_AAAA_BBBB_CCCC;

      master_write(32'h0000_0050, w1);
      master_write(32'h0000_0050, w2);
      master_read (32'h0000_0050, rdata);

      if (rdata !== w2) error_count++; else $display("[T6] PASS");

      // ================================================================
      // TEST 7 — sparse writes
      // ================================================================
      logic [63:0] A = 64'hAAAA_FFFF_0000_1111;
      logic [63:0] B = 64'hBBBB_EEEE_2222_3333;
      logic [63:0] C = 64'hCCCC_DDDD_4444_5555;

      master_write(32'h0000_0100, A);
      master_write(32'h0000_0200, B);
      master_write(32'h0000_0300, C);

      master_read(32'h0000_0100, rdata); if (rdata !== A) error_count++; else $display("[T7-A] PASS");
      master_read(32'h0000_0200, rdata); if (rdata !== B) error_count++; else $display("[T7-B] PASS");
      master_read(32'h0000_0300, rdata); if (rdata !== C) error_count++; else $display("[T7-C] PASS");

      // ================================================================
      $display("\n===== AXI4-LITE MASTER+SLAVE RTL TEST END =====");
      $display("ERROR COUNT = %0d", error_count);
      #40 $finish;
  end

endmodule
