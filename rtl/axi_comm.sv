/*

//global 
ACLK
ARESETn
//AW (write address) 	output from
AWADDR  		mas
AWVALID			mas
AWREADY			sla
////AWPROT			mas
//W (write data)
WDATA 			mas
WSTRB			mas     **** not yet imp
WVALID			mas
WREADY			sla
//B (write response)
BRESP			sla	**** 2 bit		//Table A3.28: BRESP encodings
BVALID			sla
BREADY			mas
//AR (read address)
ARADDR			mas
ARVALID			mas
ARREADY			sla
/////ARPROT			mas
//R (read data)
RDATA 			sla
RRESP			sla    **** 2 bit (optional signal)
RVALID			sla
RREADY			mas
*/

package hook;
	typedef struct packed{						//hook into the internal of master for Test bech control
	logic [31:0] data_W;					
	logic [10:0] addr_AW, addr_R;
	logic [4:0] opcode;					//opcode for simplicity 1 hot encoding, AW,W,B,AR,R
								//to request a tx, assert, send AW? opcode[4] = 1
								//this should chain all necessary events
}hook_t;
endpackage
//address size =10 bits
//datawidth =32 bits

import hook::*;
module master(	
	input  wire  ACLK, ARESETn,					//global channel
	input  logic [31:0] RDATA,					//data x32
	input  logic [1:0] BRESP, 
	input  logic AWREADY,WREADY,BVALID,ARREADY,RVALID,		//valid and ready bits for all 5 channels
	output logic AWVALID,WVALID,BREADY,ARVALID,RREADY,		//implement as FSM?
	output logic [1:0] RRESP,
	output logic [10:0] AWADDR, ARADDR, 				//adresses +1 for choosing which slave
	output logic [31:0] WDATA					//data x32
	input hook_t CTRL;					//****<<<<< use this to control internals of master
	);
	logic [31:0] cache [0:31];				//cache is smaller than memory! CPU
	logic [31:0] data_W, data_R;			  	//data_W,addr_AW,addr_R, opcode
	logic [10:0] addr_AW, addr_R;				//hook input address for AW 
								
	logic [4:0] data_flag;				//data flag register notifies if new data present on channel latch (if RX)
	input logic [1:0] W_OKAY;
	logic zero;
	assign zero = 0; 
	
	TX_channel AW #(WIDTH(11))(				//Write DATA
		.*,						// aCLK, ARESETn,
	 	.READY(AWREADY),
	 	.VALID(AWVALID),
	 	.din(CTRL.addr_AW),
	 	.xDATA(AWADDR),
	 	.opcode(CTRL.opcode[4])
	);
	TX_channel W #(WIDTH(32))(				//Write DATA	
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
	TX_channel AR #(WIDTH(11))(				//READ address DATA
		.*,						// aCLK, ARESETn,
	 	.READY(ARREADY),
	 	.VALID(ARVALID),
	 	.din(CTRL.addr_AR),
	 	.xDATA(ARADDR),
	 	.opcode(CTRL.opcode[1])
	);
	RX_channel R #(WIDTH(32))(				//Read channel 
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
		LEN_ADDR(5),
		LEN_DATA(32) 
		)(							//master has 11 addr and slave has 10, cs of which slave is the 11th address
		.*,							//aCLK,ARESETn,
		.ADDR(CTRL.addr_AR[4:0]),				//take the bottom 32 bit→ SET/INDEX we'll just overwirte data in cache
		.DATA(data_R),
		.WE(.data_flag[0]), 					//write enable
		.memory(cache),						//*** passes whole memory maybe better to pass by refference?
		.MEM_BUSY(mem_flag[0])
	);
	always_comb
		Zero = 0;
	
endmodule

module Mem_Manager_Write #(
	parameter LEN_ADDR=10,
	parameter LEN_DATA=32 
	)(							//master has 11 addr and slave has 10, cs of which slave is the 11th address
	input 	ACLK,ARESETn,
	input 	[LEN_ADDR-1:0] 	ADDR,
	input	[LEN_DATA-1:0]	DATA,
	input 	WE, 						//write enable
	inout 	[LEN_DATA-1:0] memory [LEN_ADDR-1:0],		//*** passes whole memory maybe better to pass by refference?
	output 	MEM_BUSY
	);
	
	typedef enum logic {IDLE,STORE} state_t;
	state_t state, next_state;
	always_comb begin
		case (state)
			IDLE: 	begin
				if (WE == 1)begin
					next_state = STORE;
					MEM_BUSY = 1;		//fLIP THIS ASYNCHRONOUSLY INRESPONSE TO we
				end
				end
			STORE:	begin 
					next_state = IDLE;
					MEM_BUSY = 0;
				end
			default:
				next_state = IDLE;
		endcase
		
	end 
	always_ff @ (posedge aCLK) begin 
		if (ARESETn)
			state <= next_state;
			if (state == STORE)
				memory[ADDR] <= DATA;		//synchronous store
		else
			state <= IDLE;
		
	end
endmodule
	

module TX_channel #(parameter WIDTH=32)(			//control signal between master and slave
	input 	ACLK, ARESETn,
	input 	READY,
	output 	VALID,
	input 	[WIDTH-1:0]din,
	output 	[WIDTH-1:0]xDATA,
	input 	opcode
	);
	//TX not permited to wait for ready to assert valid
	typedef enum logic {IDLE,SEND} state_t;
	state_t state, next_state;
	
	always_comb begin
		case (state)
			IDLE: 	begin
				xDATA = 0;
				VALID = 0;
				if (opcode == 1)
					next_state = SEND;
				end
			SEND:	begin 
				xDATA = din;			//din is data from master to submodule txchannel
				VALID = 1;			//dout is output connecting to master output
				if (READY == 1)
					next_state = IDLE;
				end
			default:
				next_state = IDLE;
		endcase
	end 
	always_ff @ (posedge aCLK) begin 
		if (ARESETn)
			state <= next_state;
		else
			state <= IDLE;
	end
endmodule

module RX_channel #(parameter WIDTH =32)(			//control signal between master and slave
	input  	ACLK, ARESETn,
	output  READY,
	input 	VALID,
	input logic [WIDTH-1:0] xDATA,
	output logic [WIDTH-1:0] DATA_Latch,
	output 	LATCH_FULL,		//if latch has fresh data to store =1, when stored in memory =0 latch→ fifo when we implement AXI full
	input 	MEM_BUSY,
	);
	//TX not permited to wait for ready to assert valid
	typedef enum logic {IDLE,GET,WAIT} state_t;
	state_t state, next_state;
	
	always_comb begin
	case (state)
		IDLE: 	begin
				READY = 1;
				if (VALID == 1)
					next_state = GET;
			end
		GET:	begin 
				DATA_Latch = xDATA;			
				READY = 0;			//stop recieving new data /latch full
				LATCH_FULL = 1;			
				next_state = WAIT;
			end
		WAIT:	begin
				if (MEM_BUSY == 0) begin		//when data from latch→ memory then transfer ends. this needs to wait 1 cycle
					LATCH_FULL = 0;
					next_state = IDLE;
				end
			end
		default:
				next_state = IDLE;
	endcase
	always_ff @ (posedge aCLK) begin 
		if (ARESETn)
			state <= next_state;
		else
			state <= IDLE;
endmodule

/*

module HANDSHAKE_LATCH #(parameter WIDTH =32) (			//simple reciever design but does not manage valid/ready
	inout  logic xVALID, xREADY, 
	input  logic ACLK, ARESETn,
	input  logic [WIDTH-1:0] xDATA_IN, 
	output logic [WIDTH-1:0] xDATA_OUT,
	output logic LATCH_BUSY,
	);
	always_ff @ (posedge aCLK) begin 
		if (ARESETn && xVALID && xREADY) begin
			xDATA_OUT = xDATA_IN;
			LATCH_BUSY = 1;
		end	
	end	
endmodule
*/
/*
	HANDSHAKE_LATCH u0 #(.WIDTH(32))(			//master already have address so only need slave data @ handshake
		.*,						//latch to memory @ RVALID && RREADY
		.xVALID(RVALID),
		.xREADY(RREADY),
		.xDATA_IN(RDATA),
		.xDATA_OUT(DATA_L),				//maybe we should put strait to memory instead of a reg
		.LATCH_BUSY(NEW_DATA)
		);
	*/
	/* initialize or reset */
	//always_ff @ (posedge ACLK) begin 
		/* REST is managed in RX/TX channel state
		if (ARESETn = 0) begin				
			AWVALID <= 0;
			WVALID <= 0;
			BREADY <= 0;		
			ARVALID <= 0;
			RREADY <= 0;
		end
		*/
/*
module axiglobal_tb; 
	logic ACLK, ARESETn;
	task configs;
	initial begin
		ARESETn = 0;
		#5 ARESETn = 1;
	end 
	initial begin
		#5 ACLK = ~ACK;
	end 
	initial begin
		#1000 $finish;
	end
endmodule
*/

