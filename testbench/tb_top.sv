/*
*  Author: Amogh and Jaswanthi
*  Editors: Amogh and Jaswanthi
*/

`timescale 1ns/1ps

import axi_helper::*;

module top_tb;

  // Parameters (match all modules)
  localparam int ADDR_W = 32;
  localparam int DATA_W = 64;

  // Clock & Reset
  logic ACLK;
  logic ARESETn;

  initial begin
    ACLK = 0;
    forever #5 ACLK = ~ACLK;   // 100 MHz clock
  end

  initial begin
    ARESETn = 0;
    repeat(5) @(posedge ACLK);
    ARESETn = 1;
  end

  // Interfaces
  axi4_if #(
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .ID_W(4)
  ) axi_if (
    .ACLK(ACLK),
    .ARESETn(ARESETn)
  );

  TB_if #(
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W)
  ) tb_if();

  // DUT Instantiation (Master + Slave)
  manager u_manager (
    .bus(axi_if.manager_mp),
    .tb(tb_if.manager)
  );

  axi_subordinate u_subordinate (
    .s(axi_if.subordinate_mp)
  );

  // ------------------Helper Tasks---------------------
	
  // Write task 
  task automatic do_write(
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] data
  );
    string result;
    begin
      @(posedge ACLK);
      tb_if.mgr_tx_AW = addr;
      tb_if.mgr_tx_W  = data;
      tb_if.tx_en[4]  = 1;   // AW
      tb_if.tx_en[3]  = 1;   // W

      @(posedge ACLK);

      tb_if.tx_en[4] = 0;
      tb_if.tx_en[3] = 0;
	
      // Wait for B channel response
      wait(tb_if.mgr_new_data[2]);
      repeat(2) @(posedge ACLK);

      result = (axi_if.BRESP == '0) ? "PASS":"FAIL";
      $display("Time:[%0t] OP:[WRITE] ADDR: @0x%08x DATA: %016x BRESP: %0d Result: %s",
               $time,addr, data, axi_if.BRESP, result);
    end
  endtask

  // Read task
  task automatic do_read(input logic [ADDR_W-1:0] addr);
    string result;
    begin
      @(posedge ACLK);
      tb_if.mgr_tx_AR <= addr;
      tb_if.tx_en[1]  <= 1; // AR

      @(posedge ACLK);

      tb_if.tx_en[1] <= 0;

      // Wait for R channel data
      wait(tb_if.mgr_new_data[0]);
      repeat(2) @(posedge ACLK);

      result = (axi_if.BRESP == '0) ? "PASS":"FAIL";
      $display("Time:[%0t] OP:[READ] ADDR: @0x%08x DATA: %016x BRESP: %0d Result: %s",
               $time,addr, axi_if.RDATA, axi_if.RRESP, result);
    end
  endtask

  // ---------------------Corner Case Test Sequences---------------------

  initial begin
    // Dump waveforms
    $dumpfile("axi_lite_tb.vcd");
    $dumpvars(1, top_tb);

    // Wait for reset
    wait(ARESETn == 1);
    @(posedge ACLK);

    $display("----------------------- STARTING AXI-LITE CORNER CASE VERIFICATION -----------------------");

    // Simple aligned write/read
    do_write(32'h0000_0010, 64'hA5A5_A5A5_1111_2222);
    do_read (32'h0000_0010);

    // Misaligned write
    do_write(32'h0000_0013, 64'hDEAD_BEEF_CAFE_F00D);
    do_read (32'h0000_0013);

    // Boundary write (last valid byte)
    do_write(32'h0000_0FFF, 64'h1234_5678_9ABC_DEF0);
    do_read (32'h0000_0FFF);

    // Out-of-range write
    do_write(32'h0000_2000, 64'hFACE_FACE_FACE_FACE);

    // Out-of-range read
    do_read(32'h0000_2000);
    // Back-to-back AW/W cycles
    for (int i = 0; i < 4; i++) begin
        do_write(32'h0000_0100 + (i * 8), $random);
    end

    // Back-to-back AR cycles
    for (int i = 0; i < 4; i++) begin 
	    do_read(32'h0000_0100 + (i * 8));
    end

    // Stall R channel (manager mem busy)
    tb_if.mem_flag[0] = 1;   // block R channel receive
    fork
      begin
        do_read(32'h0000_0040);
      end
    join_none

    repeat(10) @(posedge ACLK);
    tb_if.mem_flag[0] = 0; // release
    @(posedge ACLK);

    // Write then immediate read
    do_write(32'h0000_0200, 64'h1020_3040_5060_7080);
    do_read (32'h0000_0200);

    // Partial strobes (subordinate handles WSTRB)
    @(posedge ACLK);
    tb_if.mgr_tx_W  <= 64'hFF00_FF00_FF00_FF00;
    tb_if.mgr_tx_AW <= 32'h0000_0300;
    tb_if.tx_en[4]  <= 1;
    tb_if.tx_en[3]  <= 1;
    repeat(2) @(posedge ACLK);
    tb_if.tx_en[4] <= 0;
    tb_if.tx_en[3] <= 0;

    wait(tb_if.mgr_new_data[2]);
    do_read(32'h0000_0300);

    $display("----------------------- AXI-LITE CORNER CASE TESTING COMPLETE -----------------------");

    $finish;
  end

endmodule

