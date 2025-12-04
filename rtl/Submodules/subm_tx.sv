/* 
*  Author: Nhat Nguyen
*  Editors: 
*/

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
	logic [WIDTH-1:0] hold_DATA;
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
					xDATA = tx_data;		//replace data when ready
					if (READY) next_state = IDLE;	
					else  begin 
					next_state = HOLD;		//hold when not ready			
					end
					
				end else begin					//tx_en ==0;
									//if ready, signal accepted no new data
					VALID = 0;					//when not holding
					xDATA = 'x;
				end	
			end
				
			HOLD:	begin
				VALID = 1;
				xDATA = hold_DATA;   	//simulation instability resulted changing xDATA values when holding
							//if there is no internal register to hold data
							//this is called pass-through glitch
				if (READY) next_state = IDLE;	//hold the data until reciever ready
				else next_state = HOLD;					
				
			end
			//default 	next_state = IDLE;	
		endcase
						
	end 
	assign tx_hold = ~READY;				//RX tells Tx to hold, Tx tells data supply to hold
								//RX READY passed to data source
	
	always_ff @ (posedge ACLK, negedge ARESETn) begin 
		if (!ARESETn) begin
			state <= RST; 
		end else begin 
		if ((state == IDLE) && VALID && !READY) hold_DATA <= xDATA;
		state <= next_state;
		end
	end
endmodule
