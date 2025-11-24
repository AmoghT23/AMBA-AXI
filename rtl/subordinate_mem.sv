import axi_helper::*;
module subordinate(	
	axi4_if.subordinate_mp bus
	//TB_if.subordinate tb						//all tb is used in memory so tb_if not used
	);
	localparam DATA_W = axi4_if.DATA_W;				//pull in DATA_W
	localparam ADDR_W = axi4_if.ADDR_W;				//pull in ADDR_W
	logic [7:0] memory [0:4095];				//cache is smaller than memory! CPU
	logic [DATA_W:0] data_W, data_R;			  	//data_W,addr_AW,addr_R, opcode
	logic [ADDR_W:0] addr_AW, addr_AR;				//hook input address for AW 							
	logic [4:0] rx_flag,tx_flag;				//data flag register notifies if new data present on channel latch (if RX
	logic aw_new, w_new, aw_busy, w_busy,tx_b;
	logic zero,bresp,read_REQ; 
	localparam LEN = DATA_W/8;
	resp_t tx_bresp, tx_rresp;
	assign tx_bresp = OKAY;					//these are hanging ports for now
	assign tx_rresp = OKAY;
	assign zero  = 1'b0;
	
	/*============= AW CHANNEL =============*/
	RX_channel AW #(.WIDTH(ADDR_W))(				//Write DATA
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.AWREADY),
		.VALID(bus.AWVALID),
		.xDATA(bus.AWDATA),
		
		.rx_data(addr_AW),				//DATA RECIEVED BY SUB	
	 	.rx_new_data(aw_new),				//flag for new data recieved
		.rx_hold(aw_busy),				//1: SUB says HOLD the transfer for processing
	);
	/*============= W CHANNEL =============*/
	RX_channel W #(.WIDTH(DATA_W))(				//Write DATA	
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.WREADY),
		.VALID(bus.WVALID),
		.xDATA(bus.WDATA),
		
		.rx_data(data_W),				//the output in w channel and aw channel are passed to 			
	 	.rx_new_data(w_new),				//the write handler
		.rx_hold(w_busy),
	);
	/*============= Write handler =============*/
	Mem_Write W_service #(
		.ADDR_W(12),
		.DATA_W(DATA_W) 
		)(							//master has 11 addr and slave has 10, cs of which slave is the 11th address
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),	
		.AWADDR(data_AW[11:0]), 
		.WDATA(data_W),
	 	.AW_NEW(aw_new), 
		.W_NEW(w_new), 
	 	.W_BUSY(w_busy), 
	 	.AW_BUSY(aw_busy),
	 	.tx_resp(tx_b)
	 	.memory(memory)					//passed as reference not synthesizable but 
	);							//submodule contents can be move here for synthesis
	/*============= B CHANNEL =============*/
	TX_channel B #(.WIDTH(2))(				//write confirmation channel B
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.BREADY),
	 	.VALID(bus.BVALID),
	 	.xDATA(bus.BDATA),
	 	
	 	.tx_data(tx_bresp),
	 	.tx_en(tx_b),
	 	.tx_hold()				
	);	
	/*============= AR CHANNEL =============*/
	RX_channel AR #(.WIDTH(ADDR_W))(				//READ address DATA
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.ARREADY),
		.VALID(bus.ARVALID),
		.xDATA(bus.ARDATA),
		
		.rx_data(addr_AR),				
	 	.rx_new_data(read_REQ),			
		.rx_hold(~bus.RREADY),					//when read is not ready dont send more address
	);
	/*============= R CHANNEL =============*/
	TX_channel R #(.WIDTH(DATA_W))(				//Read channel 
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.RREADY),
	 	.VALID(bus.RVALID),
	 	.xDATA(bus.RDATA),
	 	
	 	.tx_data(data_R),				//outgoing data from SUB
	 	.tx_en(read_REQ),				//SUB enables the transfer
	 	.tx_hold()					//~READY from the master use this or (~bus.RREADY)
	);
	
	//reset is handled in RX/TX modules where states are set to idle Valid = 0/ready =1
	/*============= Read handler =============*/
	always_comb begin
		data_R = '0;					//continuously set rdata to the value in rx_RADDR]
		for(integer i =0; i < LEN; i++) begin
			data_R [(8*(i+1))-1:(8*i)]= memory [addr_AR[11:0] + i]; //our memory only has 12 bits capacity 
		end
	end
endmodule


