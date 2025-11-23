import hook::*;
module manager(	
	axi4_if.manager_mp bus_ports,
	input hook_t CTRL;					//****<<<<< use this to control internals of master
	);
	localparam DATA_W = axi4_if.DATA_W;			//pull in DATA_W
	localparam ADDR_W = axi4_if.ADDR_W;			//pull in ADDR_W
	logic [DATA_W:0] cache [0:1023];				//cache is smaller than memory! CPU for now store by line not byte
	logic [DATA_W:0] data_W, data_R;			  	//data_W,addr_AW,addr_R, opcode
	logic [ADDR_W:0] addr_AW, addr_AR;				//hook input address for AW 
								
	logic [4:0] data_flag;				//data flag register notifies if new data present on channel latch (if RX)
	input logic [1:0] bresp_l;
	logic zero;
	logic [7:0] AW_byte, W_byte, AR_byte, R_Byte;
	
BURST_DATA = DATA_W/8;						//todo:parse data into 8 bits and feed into channels
BURST_ADDR = ADDR_W/8;
	
	TX_channel AW #(WIDTH(8))(				//Write DATA
		.*,						// aCLK, ARESETn,
	 	.READY(AWREADY),
	 	.VALID(AWVALID),
	 	.xDATA(AWADDR),
	 	
	 	.tx_data(CTRL.addr_AW),
	 	.tx_en(CTRL.opcode[4]),
	 	.tx_hold()					// 1: HOLD data for subordinate not ready( basically ~READY)
	);
	TX_channel W #(WIDTH(8))(				//Write DATA	
		.*,						// aCLK, ARESETn,
	 	.READY(WREADY),
	 	.VALID(WVALID),
	 	.xDATA(WDATA),
	 	
	 	.tx_data(CTRL.data_W),
	 	.tx_en(CTRL.opcode[3]),
	 	.tx_hold()
	);
	RX_channel B #(WIDTH(2))(				//write confirmation channel B
		.*,						// aCLK, ARESETn,
	 	.READY(BREADY),
		.VALID(BVALID),
		.xDATA(BRESP),
		
		.rx_data(bresp_l),				//data recieved
	 	.rx_new_data(data_flag[2]),			//let module know if there is new data
		.rx_hold(zero),					//if there is data on data_flag[2] put it in memory
	);							//we dont care about storing so keep mem_busy = 0
	TX_channel AR #(WIDTH(8))(				//READ address DATA
		.*,						// aCLK, ARESETn,
	 	.READY(ARREADY),
	 	.VALID(ARVALID),
	 	.xDATA(ARADDR),
	 	
	 	.tx_data(CTRL.addr_AR),
	 	.tx_en(CTRL.opcode[1]),
	 	.tx_hold()
	);
	RX_channel R #(WIDTH(8))(				//Read channel 
		.*,						// aCLK, ARESETn,
	 	.READY(RREADY),
		.VALID(RVALID),
		.xDATA(RDATA),
		
		.rx_data(data_R),				//W_okay checks if the write is good
	 	.rx_new_data(data_flag[0]),			//tells if we have some new data
		.rx_hold(mem_flag[0]),				
	);
	
	//reset is handled in RX/TX modules where states are set to idle Valid = 0/ready =1

	Mem_Manager_Write R_service #(					//This module not yet tested
		LEN_ADDR(10),
		LEN_DATA(DATA_W) 
		)(							//master has 11 addr and slave has 10, cs of which slave is the 11th address
		.*,							//aCLK,ARESETn,
		.ADDR(CTRL.addr_AR[4:0]),				//take the bottom 32 bit→ SET/INDEX we'll just overwirte data in cache
		.DATA(data_R),
		.WE(.data_flag[0]), 					//write enable
		.memory(cache),						//*** passes whole memory maybe better to pass by refference?
		.MEM_BUSY(mem_flag[0])
	);
	always_comb
		zero = 0;
	
endmodule
