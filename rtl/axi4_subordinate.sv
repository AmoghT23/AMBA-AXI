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
    logic [2:0]        wr_size;       // AWSIZE
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
            when i=0 mem[0x1000 + 0] = wdata[8*0 + 7: 8*0] i.e wdata[8:0]
            if STRB_W = 8'b00000011
            when i=0 mem[0x1000 + 0] = wdata[8*0 + 7: 8*0] i.e wdata[8:0]
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
            wr_id         <= s.AWID;
            wr_addr       <= s.AWADDR;
            wr_size       <= s.AWSIZE;
            wr_len        <= s.AWLEN;
            wr_beats_rem  <= {1'b0, s.AWLEN} + 9'd1;
            wr_burst      <= s.AWBURST;
            wrap_mask     <= wrap_boundary(s.AWLEN, s.AWSIZE) - 1;

            wr_err        <= 1'b0;
            if (!(s.AWBURST inside {2'b00,2'b01,2'b10})) begin 
                wr_err <= 1'b1;
            end
            if (s.AWSIZE != LSB[2:0]) begin
                wr_err <= 1'b1; // full-width only
            end
            if ((s.AWADDR & (((1<<s.AWSIZE))-1)) != '0) begin
                wr_err <= 1'b1; // alignment
            end
            if ((s.AWADDR[11:0] +( (int'(s.AWLEN)+1 ) << s.AWSIZE)) > 12'd4096 - 1)begin
                wr_err <= 1'b1; // 4KB
            end
            if (s.AWADDR >= MEM_BYTES) begin
                wr_err <= 1'b1; // simple range
            end
        end

        // --- Accept one W beat when active ---
        if (s.WVALID && s.WREADY) begin
            if (!wr_err) begin
                unique case (wr_burst)
                    2'b00: do_write_fixed(wr_addr, s.WDATA, s.WSTRB);
                    2'b01: do_write_incr (wr_addr, wr_size, s.WDATA, s.WSTRB);
                    2'b10: do_write_wrap (wr_addr, wr_size, wrap_mask, s.WDATA, s.WSTRB);
                    default: wr_err <= 1'b1;
                endcase
            end

            wr_beats_rem <= wr_beats_rem - 9'd1;

            // If last beat accepted, produce B
            if (s.WLAST) begin
                w_active <= 1'b0;
                s.BVALID <= 1'b1;
                s.BID    <= wr_id;
                s.BRESP  <= wr_err ? RESP_DECERR : RESP_OKAY;
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
            rd_id         <= s.ARID;
            rd_addr       <= s.ARADDR;
            rd_size       <= s.ARSIZE;
            rd_burst      <= s.ARBURST;
            rd_beats_rem  <= {1'b0, s.ARLEN} + 9'd1;
            r_wrap_mask   <= wrap_boundary(s.ARLEN, s.ARSIZE) - 1;
            rd_err        <= 1'b0;

            // Same basic checks as AW
            if (!(s.ARBURST inside {2'b00,2'b01,2'b10})) begin
                rd_err <= 1'b1;
            end
            if (s.ARSIZE != LSB[2:0]) begin
                rd_err <= 1'b1; // full-width only
            end
            if ((s.ARADDR & (((1<<s.ARSIZE))-1)) != '0) begin
                rd_err <= 1'b1; // alignment
            end
            if ((s.ARADDR[11:0] + ( (int'(s.ARLEN)+1 ) << s.ARSIZE)) > 12'd4096 - 1) begin
                rd_err <= 1'b1; // 4KB
            end
            if (s.ARADDR >= MEM_BYTES) begin
                rd_err <= 1'b1; // simple range
            end
        end

        // --- Produce R beat when active and no beat currently valid ---
        if (r_active && !rvalid_q) begin
            bit lane_err;

            read_fixed(rd_addr, rdata_q, lane_err);

            rid_q   <= rd_id;
            rlast_q <= (rd_beats_rem == 9'd1);

            if (lane_err) begin
                rd_err <= 1'b1;
            end

            rresp_q <= rd_err ? RESP_SLVERR : RESP_OKAY;
            rvalid_q <= 1'b1;
        end

        // --- On R handshake, drop RVALID and advance to next beat or finish ---
        if (rvalid_q && s.RREADY) begin
            rvalid_q <= 1'b0;

            if (rlast_q) begin
                // Last beat just accepted
                r_active <= 1'b0;
            end
            else begin

                if (rd_beats_rem != '0)
                rd_beats_rem <= rd_beats_rem - 9'd1;

                unique case (rd_burst)
                2'b00: ; // FIXED: rd_addr unchanged
                2'b01: begin // INCR
                    rd_addr <= rd_addr + ({{(ADDR_W-1){1'b0}},1'b1} << rd_size);
                end
                2'b10: begin // WRAP
                    automatic logic [ADDR_W-1:0] base = rd_addr & ~r_wrap_mask;
                    automatic logic [ADDR_W-1:0] off  = rd_addr &  r_wrap_mask;
                    automatic logic [ADDR_W-1:0] inc  = ({{(ADDR_W-1){1'b0}},1'b1} << rd_size);
                    off     = (off + inc) & r_wrap_mask;
                    rd_addr <= base | off;
                end
                default: rd_err <= 1'b1;
                endcase
            end
        end
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
        s.RID     = rid_q;
        s.RDATA   = rdata_q;
        s.RRESP   = rresp_q;
        s.RLAST   = rlast_q;
    end
endmodule




