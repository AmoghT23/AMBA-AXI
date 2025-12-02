import axi_helper::*;
module manager(	
	axi4_if.manager_mp bus,
	TB_if.manager tb					//****<<<<< use this to control internals of master
	);
	localparam DATA_W = bus.DATA_W;			//pull in DATA_W
	localparam ADDR_W = bus.ADDR_W;			//pull in ADDR_W
	
	//registers  below in the manager are pushed out to TestBench (TB_if)
	//logic [DATA_W:0] cache [0:1023];				//cache is smaller than memory! CPU for now store by line not byte
	//logic [DATA_W:0] data_W, data_R;			  	//data_W,addr_AW,addr_R, opcode
	//logic [ADDR_W:0] addr_AW, addr_AR;				//hook input address for AW 
								
						
	logic zero;
	logic [bus.STRB_W-1:0] wstrb;
	
	//AXI_lite
	WxDATA_t	wIN, wBUS;			//in package axi_helper
	RxDATA_t 	rBUS, rOUT;			
	/* //AXI_FULL axi full structre is created and can be implemented
	// axi_lite is chosen to simplify testing first
	AWxDATA_t 	awIN, awBUS;
	WxDATA_t 	wIN, wBUS;
	BxDATA_t 	rBUS, rOUT;
	ARxDATA_t	wIN, wBUS;
	RxDATA_t 	rBUS, rOUT;	
	*/
	
	
	resp_t rx_bresp, rx_rresp;
	assign zero  = 1'b0;
	assign wstrb = '1;				//WSTRB is handled here for axi_lite dont do double driver in TB
	
	/*============= AW CHANNEL =============*/
	//we only send AWADDR on xDATA channel so connect directly without packed struct
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
	//[data + comands] → [packed struct] → [tx_submodule.xDATA] → [packed struct] → [bus]
	//this way submodule can be reused to add as many lines as needed without 
	//making a new tx or rx for each channel
	
	assign wIN.data = tb.mgr_tx_W;					//input data	
	assign wIN.strb = wstrb;					//input wstrb
	assign bus.WDATA = wOUT.data;					//output data to Bus
	assign bus.WSTRB = wOUT.strb;					//output strobe to bus
	
	TX_channel #(.WIDTH(WxDATA_W)) W (			//sum of all w channel bits (data and control) besides ready valid		
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.WREADY),
	 	.VALID(bus.WVALID),
	 	.xDATA(wBUS),
	 	
	 	.tx_data(wIN),
	 	.tx_en(tb.tx_en[3]),
	 	.tx_hold()					//optional signal, it is ~READY
	);
	
	
	
	/*============= B CHANNEL =============*/
	//we only send BRESP on xDATA channel so connect directly without packed struct
	RX_channel #(.WIDTH(2)) B (				//write confirmation channel B
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						// aCLK, ARESETn,
	 	.READY(bus.BREADY),
		.VALID(bus.BVALID),
		.xDATA(bus.BRESP),
		
		.rx_data(tb.mgr_bresp),				//data recieved
	 	.rx_new_data(tb.mgr_new_data[2]),			//let module know if there is new data
		.rx_hold(zero)  				//if there is data on new_data[2] put it in memory
	);							//we dont care about storing so keep rx_hold = 0
	/*============= AR CHANNEL =============*/
	//we only send ARADDR on xDATA channel so connect directly without packed struct
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
	//[BUS] → [packed struct] → [rx_submodule.xDATA] → [packed struct] → [data + commands]
	//this way submodule rx tx can be reused to add as many lines as needed without 
	//making a new tx or rx for each channel
	assign rBUS.data = bus.RDATA;		//inputs recieved from bus
	assign rBUS.resp = bus.RRESP;
	
	assign tb.mgr_rx_R = rOUT.data;		//submodule output data pushed to TB_if wires
	assign tb.mgr_rresp = rOUT.resp;        //this is what the manager recieves

	
	RX_channel #(.WIDTH(RxDATA_W)) R (			
		.ACLK(bus.ACLK),
		.ARESETn(bus.ARESETn),						
	 	.READY(bus.RREADY),
		.VALID(bus.RVALID),
		.xDATA(rBUS),
		
		.rx_data(rOUT),				
	 	.rx_new_data(tb.mgr_new_data[0]),			
		.rx_hold(tb.mem_flag[0])				
	);
	

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
