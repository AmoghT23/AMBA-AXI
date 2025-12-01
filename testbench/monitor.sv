`ifndef AXI_LITE_MONITOR_SV
`define AXI_LITE_MONITOR_SV

// -------------------------------------------------------------------
// Passive Monitor for AXI4-Lite
// Observes AW, W, AR channels and builds axi_transaction objects
// -------------------------------------------------------------------

class axi_lite_monitor;

    typedef virtual axi4_if.manager_mp vif_t;

    vif_t vif;
    mailbox #(axi_transaction) mon_mbx;

    function new(vif_t vif, mailbox #(axi_transaction) mon_mbx);
        this.vif     = vif;
        this.mon_mbx = mon_mbx;
    endfunction

    task run();
        axi_transaction tr;

        forever begin
            @(posedge vif.ACLK);

            // -------------------------
            // WRITE ADDRESS + WRITE DATA
            // -------------------------
            if (vif.AWVALID && vif.AWREADY) begin
                tr = new();
                tr.op   = WRITE_OP;
                tr.addr = vif.AWADDR;

                // Wait for WDATA
                @(posedge vif.ACLK);
                if (vif.WVALID && vif.WREADY) begin
                    tr.w_data = vif.WDATA;
                end

                mon_mbx.put(tr);
                $display("[%0t][MON] WRITE addr=0x%08h data=%h", 
                         $time, tr.addr, tr.w_data);
            end

            // -------------------------
            // READ ADDRESS
            // -------------------------
            if (vif.ARVALID && vif.ARREADY) begin
                tr = new();
                tr.op   = READ_OP;
                tr.addr = vif.ARADDR;

                mon_mbx.put(tr);
                $display("[%0t][MON] READ addr=0x%08h", 
                         $time, tr.addr);
            end
        end
    endtask

endclass

`endif
