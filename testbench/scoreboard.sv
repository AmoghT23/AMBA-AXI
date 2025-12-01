`ifndef AXI_LITE_SCOREBOARD_SV
`define AXI_LITE_SCOREBOARD_SV

// -------------------------------------------------------------------
// Scoreboard for AXI4-Lite
// Maintains an internal memory model
// Checks reads against expected data if written earlier
// -------------------------------------------------------------------

class axi_lite_scoreboard;

    mailbox #(axi_transaction) mon_mbx;

    // Simple memory model: associative array indexed by addr
    bit [63:0] mem_model [bit [31:0]];

    function new(mailbox #(axi_transaction) mon_mbx);
        this.mon_mbx = mon_mbx;
    endfunction

    task run();
        axi_transaction tr;

        forever begin
            mon_mbx.get(tr);

            if (tr.op == WRITE_OP) begin
                // Store into memory model
                mem_model[tr.addr] = tr.w_data;

                $display("[%0t][SCB] WRITE addr=0x%08h data=%h stored",
                         $time, tr.addr, tr.w_data);
            end
            else if (tr.op == READ_OP) begin
                if (mem_model.exists(tr.addr)) begin
                    $display("[%0t][SCB] READ addr=0x%08h expected=%h",
                             $time, tr.addr, mem_model[tr.addr]);
                end else begin
                    $display("[%0t][SCB] READ addr=0x%08h no prior write!",
                             $time, tr.addr);
                end
            end
        end
    endtask

endclass

`endif
