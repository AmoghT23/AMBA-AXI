/* 
*  Author: 	Nhat Nguyen
*  Editors: 
*/


module Mem_Write #(
	parameter ADDR_W=12,
	parameter DATA_W=64 
	)(							
	input	logic ACLK						
	input 	logic ARESETn,
	input 	logic [ADDR_W-1:0] 	AWADDR,
	input	logic [DATA_W-1:0]	WDATA,
	input 	logic AW_NEW, W_NEW, 
	output 	logic W_BUSY, AW_BUSY, tx_resp,
	ref 	logic [7:0] memory [0:(2**ADDR_W)-1]		//*** passes whole memory maybe better to pass by refference?
	);
	localparam LEN = DATA_W/8;

	//byte unsigned memory [0:ADDR_W-1];
	/*====Write OP====*/

	always_ff @ (posedge ACLK, negedge ARESTn) begin 
		if (!ARESETn) begin
			W_BUSY <= 0;
			AW_BUSY <= 0;
		end
		else begin 
			if (AW_NEW & W_NEW) begin
				for(integer i = 0; i <LEN; i++) begin
				memory[AWADDR+i] <= WDATA[(8*(i+1)-1):8*(i)];			//sychronous write
				end
				W_BUSY <=0;
				AW_BUSY<=0;
				tx_resp <1;
			end
			else begin
				tx_resp <0;
				if (AW_NEW) AW_BUSY<=1;
				if (W_NEW) W_BUSY <=1;
			end
		end
	end
	
endmodule
	


