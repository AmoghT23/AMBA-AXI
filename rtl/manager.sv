import hook::*;
module master(	
	axi4_if.manager_mp bus_ports,
	input hook_t CTRL;					//****<<<<< use this to control internals of master
	);
	localparam DATA_W = axi4_if.DATA_W;			//pull in DATA_W
	localparam ADDR_W = axi4_if.ADDR_W;			//pull in ADDR_W
	logic [DATA_W:0] cache [0:1023];				//cache is smaller than memory! CPU
	logic [DATA_W:0] data_W, data_R;			  	//data_W,addr_AW,addr_R, opcode
	logic [ADDR_W:0] addr_AW, addr_AR;				//hook input address for AW 
								
	logic [4:0] data_flag;				//data flag register notifies if new data present on channel latch (if RX)
	input logic [1:0] W_OKAY;
	logic zero;
	
	TX_channel AW #(WIDTH(ADDR_W))(				//Write DATA
		.*,						// aCLK, ARESETn,
	 	.READY(AWREADY),
	 	.VALID(AWVALID),
	 	.din(CTRL.addr_AW),
	 	.xDATA(AWADDR),
	 	.opcode(CTRL.opcode[4])
	);
	TX_channel W #(WIDTH(DATA_W))(				//Write DATA	
		.*,						// aCLK, ARESETn,
	 	.READY(WREADY),
	 	.VALID(WVALID),
	 	.din(CTRL.data_W),
	 	.xDATA(WDATA),
	 	.opcode(CTRL.opcode[3])
	);
	RX_channel B #(WIDTH(2))(				//write confirmation channel B
		.*,						// aCLK, ARESETn,
	 	.READY(BREADY),
		.VALID(BVALID),
		.xDATA(BRESP),
		.DATA_Latch(W_OKAY),				//W_okay checks if the write is good
	 	.LATCH_FULL(data_flag[2]),		
		.MEM_BUSY(zero),				//if there is data on data_flag[2] put it in memory
	);							//we dont care about storing so keep mem_busy = 0
	TX_channel AR #(WIDTH(ADDR_W))(				//READ address DATA
		.*,						// aCLK, ARESETn,
	 	.READY(ARREADY),
	 	.VALID(ARVALID),
	 	.din(CTRL.addr_AR),
	 	.xDATA(ARADDR),
	 	.opcode(CTRL.opcode[1])
	);
	RX_channel R #(WIDTH(DATA_W))(				//Read channel 
		.*,						// aCLK, ARESETn,
	 	.READY(RREADY),
		.VALID(RVALID),
		.xDATA(RDATA),
		.DATA_Latch(data_R),				//W_okay checks if the write is good
	 	.LATCH_FULL(data_flag[0]),			//tells if we latched some new data
		.MEM_BUSY(mem_flag[0]),				//if there is data on data_flag[2] put it in memory
	);
	
	//reset is handled in RX/TX modules where states are set to idle Valid = 0/ready =1

	Mem_Manager_Write R_service #(
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
