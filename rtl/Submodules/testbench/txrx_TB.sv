/* 
*  Author: Nhat Nguyen
*  Editors: 
*/

module txrx_TB;
	logic ACLK,ARESETn;
	logic READY, VALID;
	logic [7:0] tx_data, xDATA, rx_data;
	logic tx_en, rx_hold, rx_new_data,tx_hold;
	logic memsim_manual;
	
	/*------------instantiations------------*/
	TX_channel #(.WIDTH(8)) TX (.*);			
	RX_channel #(.WIDTH(8)) RX (.*);			
	
	/*------------SETUP------------*/
	initial begin
		ARESETn <= 0;
		ACLK <= 1;
		#10 ARESETn <= 1;
	end 
	always 	#5 ACLK = ~ACLK;
	initial #1000 $finish;
	/*------------TEST------------*/
	always begin 					//at every rising edge new data if not holding data
		#10 tx_data=$random;
	end
	initial begin
		rx_hold <= 0;
		tx_en <=0;
		memsim_manual<=0;		//manual control of rx_hold
		#10 tx_en <= 1;
	end
	
	initial begin
		#40; 
		#10 tx_en = ~tx_en;
		#20 tx_en = ~tx_en;
		#10 memsim_manual=1;
		rx_hold = ~rx_hold;
		#19 rx_hold = ~rx_hold;
		memsim_manual =0;
		
		#21;
		memsim_manual=1;
		rx_hold = ~rx_hold;
		#19 rx_hold = ~rx_hold;
		memsim_manual=0;
		#1 tx_en = ~tx_en;
		#30 tx_en = ~tx_en;
		
		#20;
		memsim_manual=1;
		rx_hold = ~rx_hold;
		#10 tx_en = ~tx_en;
		#10 rx_hold = ~rx_hold;
		#10 tx_en = ~tx_en;
		memsim_manual=0;
		
		
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
	
	always begin;		//simulate memory storage && not manually memory		
		@(posedge ACLK);
		#1 if (rx_new_data && !memsim_manual) begin
		rx_hold <=1;
		#5 rx_hold <=0;
		end
	end
	
endmodule
