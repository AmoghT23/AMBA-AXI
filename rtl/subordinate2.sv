import hook::*;
module subordinate(	
	axi4_if.subordinate_mp bus_ports,
	);
	localparam DATA_W = axi4_if.DATA_W;				//pull in DATA_W
	localparam ADDR_W = axi4_if.ADDR_W;				//pull in ADDR_W
	logic [DATA_W:0] memory [0:4095];				//cache is smaller than memory! CPU
	logic [DATA_W:0] data_W, data_R;			  	//data_W,addr_AW,addr_R, opcode
	logic [ADDR_W:0] addr_AW, addr_AR;				//hook input address for AW 
								
	logic [4:0] data_flag;				//data flag register notifies if new data present on channel latch (if RX)
	input logic [1:0] W_OKAY;
	input logic [1:0] bresp;
	logic zero; 
	 
	always_comb begin 
		bresp = 2'b00;
		AWW_latched = data_flag[4] & data_flag[3];
		if (data_flag[1]) begin
			data_R = memory [addr_AR];			//asynchronous read
		end
	end
	always_ff @ (posedge ACLK) begin 
		if (ARESETn)
		else

	end
	
	RX_channel AW #(WIDTH(ADDR_W))(				//Write DATA
		.*,						// aCLK, ARESETn,
	 	.READY(AWREADY),
		.VALID(AWVALID),
		.xDATA(AWADDR),
		.DATA_Latch(addr_AW),				
	 	.LATCH_FULL(data_flag[4]),		
		.MEM_BUSY(),
	);
	RX_channel W #(WIDTH(DATA_W))(				//Write DATA	
		.*,						// aCLK, ARESETn,
	 	.READY(WREADY),
		.VALID(WVALID),
		.xDATA(WDATA),
		.DATA_Latch(data_W),				
	 	.LATCH_FULL(data_flag[3]),		
		.MEM_BUSY(),
	);
	TX_channel B #(WIDTH(2))(				//write confirmation channel B
		.*,						// aCLK, ARESETn,
	 	.READY(BREADY),
	 	.VALID(BVALID),
	 	.din(bresp),
	 	.xDATA(BRESP),
	 	.opcode()				
	);							
	RX_channel AR #(WIDTH(ADDR_W))(				//READ address DATA
		.*,						// aCLK, ARESETn,
	 	.READY(ARREADY),
		.VALID(ARVALID),
		.xDATA(ARADDR),
		.DATA_Latch(addr_AR),				
	 	.LATCH_FULL(data_flag[1]),		
		.MEM_BUSY(),
	);
	TX_channel R #(WIDTH(DATA_W))(				//Read channel 
		.*,						// aCLK, ARESETn,
	 	.READY(AWREADY),
	 	.VALID(AWVALID),
	 	.din(data_R),
	 	.xDATA(RDATA),
	 	.opcode()				//if there is data on data_flag[2] put it in memory
	);
	
	//reset is handled in RX/TX modules where states are set to idle Valid = 0/ready =1
	
	Mem_Manager_Write R_service #(
		LEN_ADDR(12),
		LEN_DATA(DATA_W) 
		)(							//master has 11 addr and slave has 10, cs of which slave is the 11th address
		.*,							//aCLK,ARESETn,
		.ADDR(addr_AW[11:0]),					//take the bottom 32 bit→ SET/INDEX we'll just overwirte data in cache
		.DATA(data_R),
		.WE(.data_flag[0]), 					//write enable
		.memory(memory),						//*** passes whole memory maybe better to pass by refference?
		.MEM_BUSY(mem_flag[0])
	);
	always_comb
		Zero = 0;
	
endmodule
