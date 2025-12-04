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

    // Byte-addressable memory
    localparam int MEM_BYTES = 4096;
    byte unsigned mem [0:MEM_BYTES-1];

    
    logic              w_active;
    logic [ADDR_W-1:0] wr_addr;       // current beat byte address
    logic              wr_err;

    
    logic              r_active;       // currently in a read burst
    logic [ADDR_W-1:0] rd_addr;        // current beat byte address
    logic              rd_err;

    logic              rvalid_q;
    logic [DATA_W-1:0] rdata_q;
    logic [1:0]        rresp_q;
    logic              rlast_q;

    task automatic do_write_fixed (
        input  logic [ADDR_W-1:0] addr,
        input  logic [DATA_W-1:0] wdata,
        input  logic [STRB_W-1:0] wstrb
    );
        /*
            logic [ADDR_W-1:0] base = {addr[ADDR_W-1:LSB], {LSB{1'b0}}};
            This aligns addr down to the nearest bus word boundary:
            On 64?bit bus (8 bytes), it clears the bottom 3 bits.
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

    task automatic read_fixed (
        input  logic [ADDR_W-1:0] addr,
        output logic [DATA_W-1:0] rdata
    );
        logic [ADDR_W-1:0] base;
        base = {addr[ADDR_W-1:LSB], {LSB{1'b0}}};

        rdata = '0;

        for (int i = 0; i < STRB_W; i++) begin
            if ((base + i) < MEM_BYTES) begin
                rdata[8*i +: 8] = mem[base + i];
            end
    
        end
    endtask

    always_ff @(posedge s.ACLK or negedge s.ARESETn) begin
        if (!s.ARESETn) begin
            
            //write reset
            w_active      <= 1'b0;
            wr_addr       <= '0;
            wr_err        <= 1'b0;
            s.BVALID      <= 1'b0;
            s.BRESP       <= RESP_OKAY;

            //read reset
            r_active      <= 1'b0;
            rd_addr       <= '0;
            rd_err        <= 1'b0;

            rvalid_q      <= 1'b0;
            rdata_q       <= '0;
            rresp_q       <= RESP_OKAY;
            rlast_q       <= 1'b0;

        end else begin
            
            if (s.AWVALID && s.AWREADY) begin
                w_active      <= 1'b1;
                wr_addr       <= s.AWADDR;
                wr_err        <= 1'b0;
                if (s.AWADDR >= MEM_BYTES) begin //range check
                    wr_err <= 1'b1;
                end
            end

            
            if (s.WVALID && s.WREADY) begin
                if (!wr_err) begin
                        do_write_fixed(wr_addr, s.WDATA, s.WSTRB);
                end
                    w_active <= 1'b0;
                    s.BVALID <= 1'b1;
                    s.BRESP  <= wr_err ? RESP_SLVERR : RESP_OKAY;
                    wr_addr <= '0;
                end

            
            if (s.BVALID && s.BREADY) begin
                s.BVALID <= 1'b0;
            end

            
            if (s.ARVALID && s.ARREADY) begin
                r_active      <= 1'b1;
                rd_addr       <= s.ARADDR;
                rd_err        <= 1'b0;

                if (s.ARADDR >= MEM_BYTES) begin
                    rd_err <= 1'b1;
                end
            end

            if (r_active && !rvalid_q) begin
                if(!rd_err) begin
                    read_fixed(rd_addr, rdata_q);

                end 
                r_active <= 1'b0;
                rvalid_q <= 1'b1;
                rresp_q <= rd_err ? RESP_SLVERR : RESP_OKAY;
            end
            if(rvalid_q && s.RREADY) begin
                rvalid_q <= 1'b0;
            end
        end	
    end

    always_comb begin
        s.AWREADY = (!w_active) && (!s.BVALID);
        s.WREADY  = w_active;

        s.ARREADY = (!r_active) && (!rvalid_q);

        s.RVALID  = rvalid_q;
        s.RDATA   = rdata_q;
        s.RRESP   = rresp_q;
    end
endmodule
