module TX_channel #(parameter WIDTH=8)(			//control signal between master and slave
	input 	logic ACLK, 
	input 	logic ARESETn,
	input 	logic READY,
	output 	logic VALID,						//VALID and READY on the bus
	output 	logic [WIDTH-1:0] xDATA,				//DATA on the bus
	input 	logic [WIDTH-1:0] tx_data,				//staged data for transfer
	output 	logic tx_hold,						// ~READY
	input 	logic tx_en 						//transfer enable
	);
	//TX not permited to wait for ready to assert valid
	typedef enum logic [1:0] {RST,IDLE,HOLD} state_t;
	state_t state, next_state;
	
	always_comb begin
		next_state = state;						//valid was in this case block 
		case (state)							//but this created race condition
			RST: 	begin
				VALID = 0;					//AXI protocol: reset valid must be driven low
				next_state = IDLE;
			end
			IDLE: 	begin
									
				if (tx_en) begin			
					VALID = 1;
					xDATA = tx_data;	//replace data when ready
					if(!READY) next_state = HOLD;		//hold when not ready
				end else begin					//tx_en ==0;
				if (READY) begin				//if ready, signal accepted no new data
					VALID = 0;					//when not holding
					xDATA = 'x;
				end
				end	
			end
				
			HOLD:	begin
				if (!READY) begin
					next_state = HOLD;	//hold the data until reciever ready
				end else begin			//READY
					next_state = IDLE;				//stop holding	
				end
				end
			//default: 	next_state = IDLE;	
		endcase
						
	end 
	assign tx_hold = ~READY;				//RX tells Tx to hold, Tx tells data supply to hold
								//RX READY passed to data source
	
	always_ff @ (posedge ACLK, negedge ARESETn) begin 
		if (!ARESETn) begin
			state <= RST; 
		end else state <= next_state;
	end
endmodule