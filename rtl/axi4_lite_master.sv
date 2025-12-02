// ------------------------------------------------------------
// AXI4-Lite Master RTL (64-bit data, 32-bit address, ID=4 bits)
// ------------------------------------------------------------
module axi4_lite_master #(
    parameter ADDR_W = 32,
    parameter DATA_W = 64,
    parameter ID_W   = 4
)(
    input  logic                 ACLK,
    input  logic                 ARESETn,

    // AXI4-Lite Interface (Master Side)
    axi4_if.manager_mp           m,

    // Simple command interface (from TB)
    input  logic                 cmd_valid,
    input  logic                 cmd_write,        // 1=write, 0=read
    input  logic [ADDR_W-1:0]    cmd_addr,
    input  logic [DATA_W-1:0]    cmd_wdata,
    output logic [DATA_W-1:0]    cmd_rdata,
    output logic                 cmd_done
);

// ------------------------------------------------------------
// Internal FSM
// ------------------------------------------------------------
typedef enum logic [1:0] {
    IDLE,
    WRITE,
    READ,
    RESP
} state_t;

state_t state, next_state;

// ------------------------------------------------------------
// Registers
// ------------------------------------------------------------
logic [ADDR_W-1:0] addr_q;
logic [DATA_W-1:0] wdata_q;
logic               is_write_q;

// ------------------------------------------------------------
// Sequential
// ------------------------------------------------------------
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        state      <= IDLE;
        addr_q     <= '0;
        wdata_q    <= '0;
        is_write_q <= 1'b0;
    end else begin
        state <= next_state;
    end
end

// ------------------------------------------------------------
// FSM next state
// ------------------------------------------------------------
always_comb begin
    next_state = state;

    case (state)
        IDLE: 
            if (cmd_valid)
                next_state = cmd_write ? WRITE : READ;

        WRITE:
            if (m.AWREADY && m.WREADY)
                next_state = RESP;

        READ:
            if (m.ARREADY)
                next_state = RESP;

        RESP:
            if (is_write_q ? m.BVALID : m.RVALID)
                next_state = IDLE;

    endcase
end

// ------------------------------------------------------------
// Output logic
// ------------------------------------------------------------
assign cmd_done = (state == RESP) &&
                  (is_write_q ? m.BVALID : m.RVALID);

always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        m.AWVALID <= 0;
        m.WVALID  <= 0;
        m.ARVALID <= 0;
        m.BREADY  <= 0;
        m.RREADY  <= 0;
    end else begin
        case (state)

        IDLE: begin
            m.AWVALID <= 0;
            m.WVALID  <= 0;
            m.ARVALID <= 0;
            m.BREADY  <= 0;
            m.RREADY  <= 0;

            if (cmd_valid) begin
                addr_q     <= cmd_addr;
                wdata_q    <= cmd_wdata;
                is_write_q <= cmd_write;
            end
        end

        WRITE: begin
            // AW channel
            m.AWADDR  <= addr_q;
            m.AWID    <= '0;
            m.AWLEN   <= 0;
            m.AWSIZE  <= 3;       // 8-byte (64 bit)
            m.AWBURST <= 1;
            m.AWVALID <= 1;

            // W channel
            m.WDATA   <= wdata_q;
            m.WSTRB   <= 8'hFF;
            m.WLAST   <= 1;
            m.WVALID  <= 1;

            if (m.AWREADY) m.AWVALID <= 0;
            if (m.WREADY)  m.WVALID  <= 0;
        end

        READ: begin
            m.ARADDR  <= addr_q;
            m.ARID    <= '0;
            m.ARLEN   <= 0;
            m.ARSIZE  <= 3;
            m.ARBURST <= 1;
            m.ARVALID <= 1;

            if (m.ARREADY) m.ARVALID <= 0;
        end

        RESP: begin
            if (is_write_q) begin
                m.BREADY <= 1;
            end else begin
                m.RREADY <= 1;
                cmd_rdata <= m.RDATA;
            end
        end

        endcase
    end
end

endmodule
