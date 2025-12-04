module RX_channel #(parameter WIDTH =8)(			//control signal between master and slave
	input  	logic ACLK, 
	input 	logic ARESETn,
	output  logic READY,						//READY and VALID on the bus
	input 	logic VALID,
	input   logic [WIDTH-1:0] xDATA,				//INCOMING DATA
	output  logic [WIDTH-1:0] rx_data,			// grab the data
	output 	logic rx_new_data,		//if latch has fresh data to store =1, when stored in memory =0 (latch? fifo when we implement AXI full)
	input 	logic rx_hold		//wait for upper module to tell us that the data in the latch is serviced (data is stored somewhere)
	);
	//TX not permited to wait for ready to assert valid
	typedef enum logic [1:0] {RST, IDLE,HOLD} state_t;
	state_t state, next_state;
	
	always_comb begin
		next_state = state;
		case (state)
			RST: 	begin
				READY = 1;			//AXI protocol: reset valid must be driven low
				next_state = IDLE;
			end
			IDLE: 	begin
				READY = 1;
				if (rx_hold)			//ready is dependent on rx_hold (memory)
				next_state = HOLD;		//make READY signal synchronous with ACLK
				end
			HOLD:	begin 				//reciever not ready
				READY=0;			//stop recieving new data /latch full			
				if (!rx_hold) begin		//when data from latch? memory then transfer ends.
					next_state = IDLE;	//wait until data is put in memory
					
				end
				end
			default:	next_state = IDLE;
		endcase
	end
	
	//always_ff @ (negedge rx_hold) rx_new_data <= 0;		//handshake within upper module, not on AXI bus
		
	always_ff @ (posedge ACLK, negedge ARESETn) begin 
		if (!ARESETn) begin
			state <= RST;
			rx_new_data <= 0;
		end else begin				//normal operation
			state <= next_state;
			if (VALID && READY) begin
			rx_data <= xDATA;		//must happen on ready & valid clkedge, HOLD cycle 1 clk is after
			rx_new_data <= 1;		//new data, let upper module know to put in memory
			end
		end
	end
endmodule
