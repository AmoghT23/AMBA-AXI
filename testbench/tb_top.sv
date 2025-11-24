`timescale 1ns/1ps

`include "tb_axi_lite_write.sv"
`include "tb_axi_lite_read.sv"

module tb_top;

  // Clock + Reset
  logic ACLK;
  logic ARESETn;

  initial begin
      ACLK = 0;
      forever #5 ACLK = ~ACLK;
  end

  initial begin
      ARESETn = 0;
      repeat (4) @(posedge ACLK);
      ARESETn = 1;
  end

  // AXI Interface + DUT
  axi4_if #(32,64,4) axi_if (.ACLK(ACLK), .ARESETn(ARESETn));
  axi_subordinate dut (.s(axi_if.subordinate_mp));

  logic [63:0] wdata, rdata;

  initial begin
      @(posedge ARESETn);

      $display("\n============== AXI4-LITE TOP TEST START ==============\n");

      // ================================================================
      // TEST 1 — Basic Write / Readback @ small aligned address
      // ================================================================
      wdata = 64'h1111_2222_3333_4444;
      axi_lite_write(4'd1, 32'h0000_0020, wdata);
      axi_lite_read (4'd1, 32'h0000_0020, rdata);

      if (rdata !== wdata)
          $error("[T1] FAIL: expected %h got %h", wdata, rdata);
      else
          $display("[T1] PASS: readback correct.\n");

      // ================================================================
      // TEST 2 — Write to different address with different ID
      // ================================================================
      wdata = 64'hAAAA_BBBB_CCCC_DDDD;
      axi_lite_write(4'd2, 32'h0000_0040, wdata);
      axi_lite_read (4'd2, 32'h0000_0040, rdata);

      if (rdata !== wdata)
          $error("[T2] FAIL: expected %h got %h", wdata, rdata);
      else
          $display("[T2] PASS: readback correct.\n");

      // ================================================================
      // TEST 3 — Large address region but still valid
      // ================================================================
      wdata = 64'h1234_5678_ABCD_EF00;
      axi_lite_write(4'd3, 32'h0000_0FF0, wdata); // Near 4KB limit but valid
      axi_lite_read (4'd3, 32'h0000_0FF0, rdata);

      if (rdata !== wdata)
          $error("[T3] FAIL: expected %h got %h", wdata, rdata);
      else
          $display("[T3] PASS: readback correct.\n");

      // ================================================================
      // TEST 4 — Alignment test (AXI-Lite requires aligned access)
      // ================================================================
      wdata = 64'hDEAD_BEEF_FACE_CAFE;

      // Slave enforces proper alignment; this address is 8-byte aligned → OK
      axi_lite_write(4'd4, 32'h0000_0038, wdata);
      axi_lite_read (4'd4, 32'h0000_0038, rdata);

      if (rdata !== wdata)
          $error("[T4] FAIL: alignment readback mismatch");
      else
          $display("[T4] PASS: alignment OK.\n");

      // ================================================================
      // TEST 5 — Invalid Address (Beyond 4KB Memory)
      // ================================================================
      wdata = 64'hCAFEBABE_00112233;

      $display("[T5] EXPECTING DECERR on invalid write...");
      axi_lite_write(4'd5, 32'h0000_2000, wdata);  // Out-of-range → DECERR

      // Read should also return DECERR/invalid or default 0
      axi_lite_read(4'd5, 32'h0000_2000, rdata);

      // We do NOT compare rdata because out-of-range is undefined content
      $display("[T5] Completed invalid address test.\n");

      // ================================================================
      // TEST 6 — Write to same address twice (overwrite test)
      // ================================================================
      logic [63:0] w1 = 64'h1010_2020_3030_4040;
      logic [63:0] w2 = 64'h9999_AAAA_BBBB_CCCC;

      axi_lite_write(4'd6, 32'h0000_0050, w1);
      axi_lite_write(4'd6, 32'h0000_0050, w2);
      axi_lite_read (4'd6, 32'h0000_0050, rdata);

      if (rdata !== w2)
          $error("[T6] FAIL: overwrite failed.");
      else
          $display("[T6] PASS: overwrite OK.\n");

      // ================================================================
      // TEST 7 — Sparse writes (non-contiguous addresses)
      // ================================================================
      logic [63:0] A = 64'hAAAA_FFFF_0000_1111;
      logic [63:0] B = 64'hBBBB_EEEE_2222_3333;
      logic [63:0] C = 64'hCCCC_DDDD_4444_5555;

      axi_lite_write(4'd7, 32'h0000_0100, A);
      axi_lite_write(4'd7, 32'h0000_0200, B);
      axi_lite_write(4'd7, 32'h0000_0300, C);

      axi_lite_read (4'd7, 32'h0000_0100, rdata);  if (rdata !== A) $error("[T7-A] FAIL"); else $display("[T7-A] PASS");
      axi_lite_read (4'd7, 32'h0000_0200, rdata);  if (rdata !== B) $error("[T7-B] FAIL"); else $display("[T7-B] PASS");
      axi_lite_read (4'd7, 32'h0000_0300, rdata);  if (rdata !== C) $error("[T7-C] FAIL"); else $display("[T7-C] PASS");

      // ================================================================
      $display("\n============== AXI4-LITE TOP TEST END =================\n");
      #40 $finish;

  end

endmodule
