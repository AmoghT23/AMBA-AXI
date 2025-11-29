'include "axi_transaction.sv"

package generator_pkg;

  //AXI reponse values for Success and Failure
  localparam logic [1:0] RESP_OKAY = 2'b00;       //Success
  localparam logic [1:0] RESP_DECERR = 2'b11;     //Decode Error (for out of range)

  //Mailbox to communicate within the verification environment
  typedef mailbox #(axi_transaction) gen_to_drv_mbx_t;     //Generator to Driver
  typedef mailbox #(axi_transaction) gen_to_sco_mbx_t;     //Generator to Scoreboard

  class generator;
    //Mailboxes to send transactions to driver and scoreboard
      gen_to_drv_mbx_t drv_mbx;
      gen_to_sco_mbx_t sco_mbx;
    
      event drv_next;    //Event used for synchronize with driver

      int max_tr_count = 20;
      // Takes the mailboxes as argument
      function new(gen_to_drv_mbx_t, drv_mbx, gen_to_drv_sco_t, sco_mbx);
            this.drv_mbx = drv_mbx;
            this.sco_mbx = sco_mbx;
      endfunction
    
      // Response Prediction (Golden Reference Intent)
      function void predict_response(axi_transaction tr);
        if(tr.addr >= 32'h0000_1000) begin         // Addresses 0x1000 and above are out of range.
               tr.resp = RESP_DECERR;          //Expected Decode Error
            end else begin
              tr.resp = RESP_OKAY;           //Expected Success
            end
      endfunction

      task run ();
          axi_transaction tr;
          int tx_count = 0;

          $display("[%0t] [GEN] Starting Randomized Transaction Generation (Total: %0d)", $time, max_tx_count);

          repeat (max_tx_count) begin
              tx_count++;
              tr = new();
            
              //Generate randomizing transactions
              assert(tr.randomize()) else $fatal(0, "[GEN] Failed to randomize transaction object!");

            predict_reponse(tr); //Predicting expected response

            //Send to driver (driver will execute on the manager side
            $display("[%0t] [GEN] Tx %0d: %s 0x%08h (ID %0d). Predicted Response: %b", $time, tx_count, tr.op == WRITE_OP ? "WRITE" : "READ", tr.addr, tr.id, tr.resp);
            drv.mbx.put(tr);

            //Send to scoreboard
            sco_mbx.put(tr.copy());

            //Wait for next driver to signal that the hanshake is done and ready for next transaction
            @(drv_next);
        end
        $display("[%0t] [GEN] Generator Finished all %0d transactions.", $time, max_tx_count);
      endtask
  endclass
endpackage
