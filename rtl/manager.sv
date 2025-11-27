import axi_helper::*;
module manager(	
	axi4_if.manager_mp bus,
	TB_if.manager tb					//****<<<<< use this to control internals of master
	);
	localparam DATA_W = bus.DATA_W;			//pull in DATA_W
	localparam ADDR_W = bus.ADDR_W;			//pull in ADDR_W
	logic [DATA_W:0] cache [0:1023];				//cache is smaller than memory! CPU for now store by line not byte
	logic [DATA_W:0] data_W, data_R;			  	//data_W,addr_AW,addr_R, opcode
	logic [ADDR_W:0] addr_AW, addr_AR;				//hook input address for AW 
								
	logic [4:0] data_flag;				//data flag register notifies if new data present on channel latch (if RX)
	input logic [1:0] bresp;
	logic zero;
	logic [bus.STRB_W-1:0] wstrb;
	
	
	resp_t rx_bresp, rx_rresp;
	assign zero  = 1'b0;
	assign wstrb = '1;				//WSTRB is handled here for axi_lite dont do double driver in TB
	
	/*============= AW CHANNEL =============*/
	TX_channel #(.WIDTH(ADDR_W)) AW (				
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),
	 	.READY(bus.AWREADY),				//TOP 5 IS ON THE BUS
	 	.VALID(bus.AWVALID),
	 	.xDATA(bus.AWADDR),
	 	
	 	.tx_data(tb.mgr_tx_AW),				//BOTTOM 3 IS interface with parent module
	 	.tx_en(tb.tx_en[4]),
	 	.tx_hold()					// 1: HOLD data for subordinate not ready( it is just ~READY)
	);
	/*============= W CHANNEL =============*/
	TX_channel #(.WIDTH(DATA_W)) W (					
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.WREADY),
	 	.VALID(bus.WVALID),
	 	.xDATA(bus.WDATA),
	 	
	 	.tx_data(tb.mgr_tx_W),
	 	.tx_en(tb.tx_en[3]),
	 	.tx_hold()
	);
	always_comb
		if(bus.WVALID) bus.WSTRB = wstrb;		//bus.WVALID is driven synchronously in submodule
		else bus.WSTRB = 'x;				//axi signal to indicate which bytes in data to change (change all bytes in axi_lite)
	end
	/*============= B CHANNEL =============*/
	RX_channel #(.WIDTH(2)) B (				//write confirmation channel B
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						// aCLK, ARESETn,
	 	.READY(bus.BREADY),
		.VALID(bus.BVALID),
		.xDATA(bus.BRESP),
		
		.rx_data(tb.mgr_bresp),				//data recieved
	 	.rx_new_data(tb.mgr_new_data[2]),			//let module know if there is new data
		.rx_hold(zero),					//if there is data on data_flag[2] put it in memory
	);							//we dont care about storing so keep mem_busy = 0
	/*============= AR CHANNEL =============*/
	TX_channel #(.WIDTH(ADDR_W)) AR (				
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.ARREADY),
	 	.VALID(bus.ARVALID),
	 	.xDATA(bus.ARADDR),
	 	
	 	.tx_data(tb.mgr_tx_AR),
	 	.tx_en(tb.tx_en[1]),
	 	.tx_hold()
	);
	/*============= R CHANNEL =============*/
	RX_channel #(.WIDTH(DATA_W)) R (			
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.RREADY),
		.VALID(bus.RVALID),
		.xDATA(bus.RDATA),
		
		.rx_data(tb.mgr_rx_R),				
	 	.rx_new_data(tb.mgr_new_data[0]),			
		.rx_hold(tb.mem_flag[0]),				
	);
	always_comb
		if(bus.RVALID && bus.RREADY) rx_rresp = bus.RRESP;		// if is driven by synchronous signals, accepts RRESP	
	end
	//reset is handled in RX/TX modules where states are set to idle Valid = 0/ready =1
	
endmodule

/*
	Mem_Manager_Write R_service #(					//This module not yet tested
		.LEN_ADDR(10),
		.LEN_DATA(DATA_W) 
		)(							//master has 11 addr and slave has 10, cs of which slave is the 11th address
		.*,							//aCLK,ARESETn,
		.ADDR(CTRL.addr_AR[4:0]),				//take the bottom 32 bit→ SET/INDEX we'll just overwirte data in cache
		.DATA(data_R),
		.WE(.data_flag[0]), 					//write enable
		.memory(cache),						//*** passes whole memory maybe better to pass by refference?
		.MEM_BUSY(mem_flag[0])
	);
*/
