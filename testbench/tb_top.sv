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

  // Storage for readback
  logic [63:0] wdata, rdata;

  initial begin
      @(posedge ARESETn);

      $display("============== AXI4-LITE TOP TEST START ==============\n");

      // --------------------------------------------------------
      // WRITE TEST
      // --------------------------------------------------------
      wdata = 64'hABCD_EF12_3456_7890;
      axi_lite_write(4'd1, 32'h0000_0020, wdata);

      // --------------------------------------------------------
      // READ TEST
      // --------------------------------------------------------
      axi_lite_read(4'd1, 32'h0000_0020, rdata);

      // --------------------------------------------------------
      // COMPARE RESULTS
      // --------------------------------------------------------
      if (rdata !== wdata)
          $error("[TOP] READBACK MISMATCH: expected=%h got=%h", wdata, rdata);
      else
          $display("[TOP] READBACK MATCH OK!");

      $display("\n============== AXI4-LITE TOP TEST END =================\n");

      #40 $finish;
  end

endmodule
