'include "axi_transaction.sv"

package generator_pkg;

  localparam logic [1:0] RESP_OKAY = 2'b00;
  localparam logic [1:0] RESP_DECERR = 2'b11;

  typedef mailbox #(axi_transaction) gen_to_drv_mbx_t;
  typedef mailbox #(axi_transaction) gen_to_sco_mbx_t;

  class generator;
      gen_to_drv_mbx_t drv_mbx;
      gen_to_sco_mbx_t sco_mbx;
      event drv_next;

      int max_tr_count = 20;
      function new(gen_to_drv_mbx_t, drv_mbx, gen_to_drv_sco_t, sco_mbx);
            this.drv_mbx = drv_mbx;
            this.sco_mbx = sco_mbx;
      endfunction

      function void predict_response(axi_transaction tr);
            if(tr.addr >= 32'h2000 || tr.addr > 32'h0FFF) begin
               tr.resp = RESP_DECERR;
            end else begin
               tr.resp = RESP_OKAY;
            end
      endfunction

      task run ();
          axi_transaction tr;
          int tx_count = 0;

          $display("[%0t] [GEN] Starting Randomized Transaction Generation (Total: %0d)", $time, max_tx_count);

          repeat (max_tx_count) begin
              tx_count++;
              tr = new();

              assert(tr.randomize()) else $fatal(0, "[GEN] Failed to randomize transaction object!");

              predict_reponse(tr);

              $display("[%0] [GEN] Tx %0d: %s 0x%08h (ID %0d). Predicted Response: %b", $time, tx_count, tr.op == WRITE_OP ? "WRITE" : "READ", tr.addr, tr.id, tr.resp);

              drv.mbx.put(tr);

              sco_mbx.put(tr.copy());

              @(drv_next);
        end
        $display("[%0t] [GEN] Generator Finished all %0d transactions.", $time, max_tx_count);
      endtask
  endclass
endpackage
