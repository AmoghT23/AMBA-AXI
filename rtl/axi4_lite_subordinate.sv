module axi_subordinate #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 64,
  parameter int ID_W = 4
)(
    axi4_if.subordinate_mp s
);
    // Local params
    localparam int STRB_W = DATA_W/8;
    localparam int LSB    = $clog2(STRB_W);

    localparam logic [1:0] RESP_OKAY  = 2'b00;
    localparam logic [1:0] RESP_SLVERR= 2'b10;
    localparam logic [1:0] RESP_DECERR= 2'b11;

    // Byte-addressable memory
    localparam int MEM_BYTES = 4096;
    byte unsigned mem [0:MEM_BYTES-1];

    
    logic              w_active;
    logic [ID_W-1:0]   wr_id;
    logic [ADDR_W-1:0] wr_addr;       // current beat byte address
    logic [2:0]        wr_size = $clog2(DATA_W/8);       // AWSIZE
    logic [7:0]        wr_len;        // AWLEN (beats-1)
    logic [8:0]        wr_beats_rem;  // beats remaining (0..256)
    logic [1:0]        wr_burst;      // AWBURST
    logic [ADDR_W-1:0] wrap_mask;     // (wrap_boundary-1) for WRAP
    logic              wr_err;

    // ---------------- Read burst state/context ----------------
    logic              r_active;       // currently in a read burst
    logic [ID_W-1:0]   rd_id;          // ARID for this burst
    logic [ADDR_W-1:0] rd_addr;        // current beat byte address
    logic [2:0]        rd_size;        // ARSIZE
    logic [1:0]        rd_burst;       // ARBURST
    logic [8:0]        rd_beats_rem;   // beats remaining (0..256)
    logic [ADDR_W-1:0] r_wrap_mask;    // wrap_boundary-1 for WRAP
    logic              rd_err;         // accumulated error for this burst

    logic              rvalid_q;
    logic [ID_W-1:0]   rid_q;
    logic [DATA_W-1:0] rdata_q;
    logic [1:0]        rresp_q;
    logic              rlast_q;

    // Helpers
    /*
        beats is the no of transaction and size - no of bytes per beat
        boundary = beats * size
    */
    function automatic logic [ADDR_W-1:0] wrap_boundary(input logic [7:0] len, input logic [2:0] size);
        logic [ADDR_W-1:0] beats = {{(ADDR_W-8){1'b0}}, len} + 1;
        return beats << size;
    endfunction

    task automatic do_write_fixed (
        input  logic [ADDR_W-1:0] addr,
        input  logic [DATA_W-1:0] wdata,
        input  logic [STRB_W-1:0] wstrb
    );
        /*
            logic [ADDR_W-1:0] base = {addr[ADDR_W-1:LSB], {LSB{1'b0}}};
            This aligns addr down to the nearest bus word boundary:
            On 64‑bit bus (8 bytes), it clears the bottom 3 bits.
            So if addr = 0x1002, base = 0x1000.
        */
        logic [ADDR_W-1:0] base = {addr[ADDR_W-1:LSB], {LSB{1'b0}}};
        /*
            if STRB_W = 8'b00000001
            when i=0 mem[0x1000 + 0] = wdata[8*0 + 7: 8*0] i.e wdata[7:0]
            if STRB_W = 8'b00000011
            when i=0 mem[0x1000 + 0] = wdata[8*0 + 7: 8*0] i.e wdata[7:0]
            when i=1 mem[0x1000 + 1] = wdata[8*1 + 7: 8*1] i.e wdata[15:8]
        */
        for (int i=0;i<STRB_W;i++) begin
            if (wstrb[i]) begin
                if ((base+i)<MEM_BYTES) begin
                    mem[base+i] = wdata[8*i +: 8];
                end 
            end 
        end
    endtask

    task automatic do_write_incr (
        inout logic [ADDR_W-1:0] addr,
        input  logic [2:0]       size,
        input  logic [DATA_W-1:0] wdata,
        input  logic [STRB_W-1:0] wstrb
    );
        logic [ADDR_W-1:0] base = {addr[ADDR_W-1:LSB], {LSB{1'b0}}};
        for (int i=0;i<STRB_W;i++) begin
            if (wstrb[i]) begin
                if ((base+i)<MEM_BYTES) begin
                    mem[base+i] = wdata[8*i +: 8];
                end
            end
        end
        addr = addr + ({{(ADDR_W-1){1'b0}},1'b1} << size);
    endtask

    task automatic do_write_wrap (
        inout logic [ADDR_W-1:0] addr,
        input  logic [2:0]       size,
        input  logic [ADDR_W-1:0] wrap_mask_i,   // = wrap_boundary(len,size) - 1
        input  logic [DATA_W-1:0] wdata,
        input  logic [STRB_W-1:0] wstrb
    );
        logic [ADDR_W-1:0] base, incr, reg_base, off;
        base = {addr[ADDR_W-1:LSB], {LSB{1'b0}}};
        for (int i=0;i<STRB_W;i++) begin
            if (wstrb[i]) begin
                if ((base+i)<MEM_BYTES) begin
                    mem[base+i] = wdata[8*i +: 8];
                end 
            end
        end 

        // Wrap advance: keep address inside wrap window
        incr = ({{(ADDR_W-1){1'b0}},1'b1} << size);
        reg_base = addr & ~wrap_mask_i;
        off = (addr & wrap_mask_i);
        off  = (off + incr) & wrap_mask_i;
        addr = reg_base | off;
    endtask

    task automatic read_fixed (
        input  logic [ADDR_W-1:0] addr,
        output logic [DATA_W-1:0] rdata,
        output bit err
    );
        logic [ADDR_W-1:0] base;
        base = {addr[ADDR_W-1:LSB], {LSB{1'b0}}};

        err = 1'b0;

        for (int i = 0; i < STRB_W; i++) begin
            if ((base + i) < MEM_BYTES) begin
                rdata[8*i +: 8] = mem[base + i];
            end
            else begin
                rdata[8*i +: 8] = '0; // out-of-range -> 0
                err = 1'b1;
            end
        end
    endtask

    always_ff @(posedge s.ACLK or negedge s.ARESETn) begin
        if (!s.ARESETn) begin
            // -------- write path reset--------
            w_active      <= 1'b0;
            wr_id         <= '0;
            wr_addr       <= '0;
            wr_size       <= '0;
            wr_len        <= '0;
            wr_beats_rem  <= '0;
            wr_burst      <= 2'b01;
            wrap_mask     <= '0;
            wr_err        <= 1'b0;
            s.BVALID      <= 1'b0;
            s.BID         <= '0;
            s.BRESP       <= RESP_OKAY;

            // -------- read path reset--------
            r_active      <= 1'b0;
            rd_id         <= '0;
            rd_addr       <= '0;
            rd_size       <= '0;
            rd_burst      <= 2'b01;
            rd_beats_rem  <= '0;
            r_wrap_mask   <= '0;
            rd_err        <= 1'b0;

            rvalid_q      <= 1'b0;
            rid_q         <= '0;
            rdata_q       <= '0;
            rresp_q       <= RESP_OKAY;
            rlast_q       <= 1'b0;

        end else begin
        // ===================== WRITE PATH =====================
        // --- Accept AW when idle and no pending B ---
        if (s.AWVALID && s.AWREADY) begin
            w_active      <= 1'b1;
            wr_addr       <= s.AWADDR;
            wr_err        <= 1'b0;
            if (s.AWADDR >= MEM_BYTES) begin
                wr_err <= 1'b1; // simple range
            end
        end

        // --- Accept one W beat when active ---
        if (s.WVALID && s.WREADY) begin
            if (!wr_err) begin
                    do_write_fixed(wr_addr, s.WDATA, s.WSTRB);
            end
                w_active <= 1'b0;
                s.BVALID <= 1'b1;
                s.BRESP  <= wr_err ? RESP_SLVERR : RESP_OKAY;
            end
        end

        // --- Complete B ---
        if (s.BVALID && s.BREADY) begin
            s.BVALID <= 1'b0;
        end

        // ===================== READ PATH=====================

        // --- Accept AR when idle and no pending R beat ---
        if (s.ARVALID && s.ARREADY) begin
            r_active      <= 1'b1;
            rd_addr       <= s.ARADDR;
            rd_err        <= 1'b0;

            if (s.ARADDR >= MEM_BYTES) begin
                rd_err <= 1'b1; // simple range
            end
        end

        // --- Produce R beat when active and no beat currently valid ---
        if (r_active && !rvalid_q) begin
            bit lane_err;

            read_fixed(rd_addr, rdata_q, lane_err);

            if (lane_err) begin
                rd_err <= 1'b1;
            end

            rresp_q <= rd_err ? RESP_SLVERR : RESP_OKAY;
            rvalid_q <= 1'b1;
        end
    end

    always_comb begin
        // Write READYs
        s.AWREADY = (!w_active) && (!s.BVALID);
        s.WREADY  = w_active;

        // Read READY: accept a new AR only when no active burst and no pending R beat
        s.ARREADY = (!r_active) && (!rvalid_q);

        // Drive R channel from registered signals
        s.RVALID  = rvalid_q;
        s.RDATA   = rdata_q;
        s.RRESP   = rresp_q;
    end
endmodule




