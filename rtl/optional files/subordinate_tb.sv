/* 
*  Author: 	Nhat Nguyen
*  Editors:
*  Info:	This module is intended to show how values are connected to TB_IF for subordinate (not fully tested)
*		RRESP and WSTRB not added 
*/


import axi_helper::*;
module subordinate(	
	axi4_if.subordinate_mp bus,
	TB_if.subordinate tb
	);
	localparam DATA_W = axi4_if.DATA_W;				//pull in DATA_W
	localparam ADDR_W = axi4_if.ADDR_W;				//pull in ADDR_W
	byte unsigned memory [0:4095];				//cache is smaller than memory! CPU
	logic [DATA_W:0] data_W, data_R;			  	//data_W,addr_AW,addr_R, opcode
	logic [ADDR_W:0] addr_AW, addr_AR;				//hook input address for AW 
								
	logic [4:0] rx_flag,tx_flag;				//data flag register notifies if new data present on channel latch (if RX
	
	logic zero,bresp; 
	
	resp_t tx_bresp, tx_rresp;
	assign tx_bresp = OKAY;					//these are hanging ports for now
	assign tx_rresp = OKAY;
	assign zero  = 1'b0;
	
	/*============= AW CHANNEL =============*/
	RX_channel #(.WIDTH(ADDR_W)) AW (				//Write DATA
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.AWREADY),
		.VALID(bus.AWVALID),
		.xDATA(bus.AWDATA),
		
		.rx_data(tb.sub_rx_AW),				//DATA RECIEVED BY SUB	
	 	.rx_new_data(tb.sub_new_data[4]),			//flag for new data recieved
		.rx_hold(tb.mem_flag[4]),				//1: SUB says HOLD the transfer for processing
	);
	/*============= W CHANNEL =============*/
	RX_channel #(.WIDTH(DATA_W)) W (				//Write DATA	
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.WREADY),
		.VALID(bus.WVALID),
		.xDATA(bus.WDATA),
		
		.rx_data(tb.sub_rx_W),						
	 	.rx_new_data(tb.sub_new_data[3]),			
		.rx_hold(tb.mem_flag[3]),
	);
	/*============= B CHANNEL =============*/
	TX_channel #(.WIDTH(2)) B (				//write confirmation channel B
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.BREADY),
	 	.VALID(bus.BVALID),
	 	.xDATA(bus.BDATA),
	 	
	 	.tx_data(rb.sub_bresp),
	 	.tx_en(tb.tx_en[2]),
	 	.tx_hold()				
	);	
	/*============= AR CHANNEL =============*/
	RX_channel #(.WIDTH(ADDR_W)) AR (				//READ address DATA
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.ARREADY),
		.VALID(bus.ARVALID),
		.xDATA(bus.ARDATA),
		
		.rx_data(tb.sub_rx_AR),				
	 	.rx_new_data(tb.sub_new_data[1]),			
		.rx_hold(tb.mem_flag[1]),
	);
	/*============= R CHANNEL =============*/
	TX_channel #(.WIDTH(DATA_W)) R (				//Read channel 
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.RREADY),
	 	.VALID(bus.RVALID),
	 	.xDATA(bus.RDATA),
	 	
	 	.tx_data(tb.sub_tx_R),				//outgoing data from SUB
	 	.tx_en(tb.tx_en[0]),				//SUB enables the transfer
	 	.tx_hold()					//~READY from the master use this or (~bus.RREADY)
	);
	
	//reset is handled in RX/TX modules where states are set to idle Valid = 0/ready =1
	

endmodule


