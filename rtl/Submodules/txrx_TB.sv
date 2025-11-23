module txrx_TB;
	logic ACLK,ARESETn;
	logic READY, VALID;
	logic [7:0] xDATA; 
	logic [7:0] tx_data, rx_data;
	logic tx_en,rx_hold, rx_new_data,tx_hold;
	logic memsim_manual;
	
	/*------------instantiations------------*/
	TX_channel #(.WIDTH(8)) TX (				//Write DATA
		.*						// ACLK, ARESETn,
	);
	RX_channel #(.WIDTH(8)) RX (				//write confirmation channel B
		.*						 
	);			
	
	/*------------SETUP------------*/
	initial begin
		ARESETn <= 0;
		ACLK <= 1;
		#5 ARESETn <= 1;
	end 
	always 	#5 ACLK = ~ACLK;
	//always  #2 memclk = ~memclk
	initial #1000 $finish;
	/*------------TEST------------*/
	always  #10 if(~tx_hold && tx_en) 
			tx_data=$random;			//at every rising edge new data if not holding data
	
	initial begin
		rx_hold <= 0;
		tx_en <=0;
		memsim_manual<=0;
		#10 tx_en <= 1;
	end
	
	initial begin
		#100;				// sim regular operation
		repeat(10)			// simulate new data availability
		#10 tx_en = ~tx_en;
		#10 tx_en = ~tx_en;		//long stall
		#50 tx_en = ~tx_en;
		
		
		#10 memsim_manual=1;
		rx_hold = ~rx_hold;		//simulate rx_memory busy
		repeat(5)
		#10 rx_hold = ~rx_hold;
		#10 rx_hold = ~rx_hold;
		#50 rx_hold = ~rx_hold;		
		memsim_manual=0;		//turning off tx_en (data for sending available)
		#100 memsim_manual=1;		//during tx_hold (holding data until RX ready
						//will cause loss of data
						//data stay valid after tx_en deassert until reciever gets data
						//new data not accepted
		#10 rx_hold = ~rx_hold;		//test this scenario
		#10 tx_en = ~tx_en;
		#50 rx_hold = ~rx_hold;
		#40 tx_en = ~tx_en;
		memsim_manual=0;		
	end
	
	always #1 if (rx_new_data && ~memsim_manual) begin		//simulate memory storage && not manually memory
		rx_hold =1;
		#2 rx_hold =0;
	end
	
endmodule
