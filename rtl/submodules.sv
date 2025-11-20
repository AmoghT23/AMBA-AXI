package hook;
	typedef struct packed{						//hook into the internal of master for Test bech control
	logic [63:0] data_W;					
	logic [10:0] addr_AW, addr_R;
	logic [4:0] opcode;					//opcode for simplicity 1 hot encoding, AW,W,B,AR,R
								//to request a tx, assert, send AW? opcode[4] = 1
								//this should chain all necessary events
}hook_t;
endpackage
//address size =10 bits
//datawidth =32 bits
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
	always_ff @ (posedge ACLK) begin 
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
	always_ff @ (posedge ACLK) begin 
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
	always_ff @ (posedge ACLK) begin 
		if (ARESETn)
			state <= next_state;
		else
			state <= IDLE;
endmodule
