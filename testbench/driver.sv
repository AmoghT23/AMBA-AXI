'include "axi_transaction.sv"

package driver_pkg;
    import generator_pkg::*;

    typedef virtual axi4_if.manager_mp vif_t;

    class driver;
        gen_to_drv_mbx_t drv_mbx;   // Communication handles
        vif_t vif;
        event drv_next; // Signal Generator for next transaction

        // Constructor
        function new(vif_t vif, gen_to_drv_mbx_t drv_mbx, event drv_next);
            this.vif = vif;
            this.drv_mbx = drv_mbx;
            this.drv_next = drv_next;
        endfunction

        // Task to set all manager output signals to idle state
        task reset_outputs();
            vif.AWVALID = 1'b0; vif.AWID    = '0; vif.AWADDR  = '0;
            vif.WVALID  = 1'b0; vif.WDATA   = '0; vif.WSTRB   = '0; 
            vif.WLAST   = 1'b0;
            vif.BREADY  = 1'b0;
            vif.ARVALID = 1'b0; vif.ARID    = '0; vif.ARADDR  = '0;
            vif.RREADY  = 1'b0;
            @(posedge vif.ACLK);
        endtask

        // Dedicated AXI-LITE WRITE Task (AW, W, B Channels)
        task do_axi_write(axi_transaction tr);
            
            // AXI Write: AW, W Channels Handshake
            @(posedge vif.ACLK);
            vif.AWID = tr.id; vif.AWADDR = tr.addr; vif.AWVALID = 1'b1;
            vif.WDATA = tr.w_data; 
            vif.WSTRB = {vif.DATA_W/8{1'b1}}; // Full strobe for 64-bit data
            vif.WLAST = 1'b1; vif.WVALID = 1'b1;

            @(posedge vif.ACLK);
            while (!(vif.AWREADY && vif.WREADY)) @(posedge vif.ACLK);
            vif.AWVALID = 1'b0; vif.WVALID = 1'b0;

            // B Channel Handshake (Response)
            vif.BREADY = 1'b1;
            @(posedge vif.ACLK);
            while (!vif.BVALID) @(posedge vif.ACLK);
            tr.resp = vif.BRESP; // Capture response
            vif.BREADY = 1'b0;
        endtask

        // Dedicated AXI-LITE READ Task (AR, R Channels)
        task do_axi_read(axi_transaction tr);

            // AR Channel Handshake (Address)
            @(posedge vif.ACLK);
            vif.ARID = tr.id; 
            vif.ARADDR = tr.addr; 
            vif.ARVALID = 1'b1;

            @(posedge vif.ACLK);
            while (!vif.ARREADY) @(posedge vif.ACLK);
            vif.ARVALID = 1'b0; // De-assert ARVALID after handshake

            // R Channel Handshake (Data and Response)
            vif.RREADY = 1'b1;
            @(posedge vif.ACLK);
            while (!vif.RVALID) @(posedge vif.ACLK);
            
            tr.r_data = vif.RDATA; // Capture data
            tr.resp = vif.RRESP;   // Capture response
            vif.RREADY = 1'b0;
        endtask

        // AXI-LITE Transaction Handler (Routes to Read or Write)
        task do_transaction(axi_transaction tr);
            if (tr.op == WRITE_OP) begin
                do_axi_write(tr);
            end else if (tr.op == READ_OP) begin
                do_axi_read(tr);
            end else begin
                $error("[%0t] [DRV] Received INVALID_OP!", $time);
            end
        endtask

        // Main Task
        task run();
            axi_transaction tr;
            
            reset_outputs();
            $display("[%0t] [DRV] Driver ready.", $time);
            
            forever begin
                // Get transaction from Generator
                drv_mbx.get(tr);
                
                // Execute transaction
                do_transaction(tr);
                
                // Signal Generator for next transaction
                -> drv_next;
            end
        endtask
    endclass
endpackage
