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

package data_type;
	typedef 
endpackage
//address size =10 bits
//datawidth =32 bits

module axiglobal_tb; 
	logic ACLK, ARESETn;
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


module master(	
	input  wire  ACLK, ARESETn,					//global channel
	input  logic [31:0] RDATA,					//data x32
	input  logic [1:0] BRESP, 
	input  logic AWREADY,WREADY,BVALID,ARREADY,RVALID,		//valid and ready bits for all 5 channels
	output logic AWVALID,WVALID,BREADY,ARVALID,RREADY,		//implement as FSM?
	output logic [1:0] RRESP,
	output logic [10:0] AWADDR, ARADDR, 				//adresses +1 for more slave 
	output logic [31:0] WDATA					//data x32
	);
	logic [31:0] memory [0:1023] 				//10 bit address x32 (not sure if master/manager have memory)
	logic [31:0] DATA_L;			  		//queue data in/out? where does it go in memory?
	logic NEW_DATA;
	
	HANDSHAKE_LATCH u0 #(.WIDTH(32))(			//master already have address so only need slave data @ handshake
		.*,						//latch to memory @ RVALID && RREADY
		.xVALID(RVALID),
		.xREADY(RREADY),
		.xDATA_IN(RDATA),
		.xDATA_OUT(DATA_L),				//maybe we should put strait to memory instead of a reg
		.LATCH_BUSY(NEW_DATA)
		);
		
	
		
	/* initialize or reset */
	always_ff @ (posedge ACLK) begin 
		if (ARESETn = 0) begin
			AWVALID <= 0;
			WVALID <= 0;
			BREADY <= 0;		
			ARVALID <= 0;
			RREADY <= 0;
		end

		/* AW channel (write address)*/				
		if (AWREADY && AWVALID) begin				//format (slave && master)
			//AWVALID <= 0;					
		end
		
		/* W channel (write data)*/
		if (WREADY && WVALID) begin 
			//WVALID <= 0;
		end
		
		/* B channel (write acknowledge)*/		
		if (BVALID && BREADY) begin
			BREADY <= 0;
		end
		
		/* AR channel (read address)*/	
		if (ARREADY && ARVALID) begin
			ARVALID <= 0;
		end
		
		/* R channel (read data)*/		
		if (NEW_DATA) begin
			memory[ARADDR] 	<= DATA_L;		// Write latched data to memory
			RRESP 		<= 2'b01;		//say data written to slave (optional)
			RREADY 		<= 0;
		end
	end
endmodule

module slave(
	input  wire  ACLK, ARESETn,					//global channel
	output logic [31:0] RDATA,					//data x32
	output logic [1:0] BRESP,
	output logic AWREADY,WREADY,BVALID,ARREADY,RVALID,		//valid and ready bits for all 5 channels
	input  logic AWVALID,WVALID,BREADY,ARVALID,RREADY,
	input logic [1:0] RRESP,
	input  logic [9:0] AWADDR, ARADDR, 				//adresses
	input  logic [31:0] WDATA					//data x32
	);
	logic [31:0] memory [0:1023]; //10 bit address x32
	logic [9:0]  ADDR_L;
	logic [31:0] DATA_L;
	logic NEW_DATA, NEW_ADDR, WEN;
	
	assign WEN = NEW_DATA & NEW_ADDR; 
	HANDSHAKE_LATCH u0 #(.WIDTH(32))(				//latch data @ handshake
		.*,
		.xVALID(WVALID),
		.xREADY(WREADY),
		.xDATA_IN(WDATA),
		.xDATA_OUT(DATA_L),
		.LATCH_BUSY(NEW_DATA)					//flag for new data
		);
	HANDSHAKE_LATCH u1 #(.WIDTH(9))(				//latch addr @ handshake 
		.*,
		.xVALID(AWVALID),
		.xREADY(AWREADY),
		.xDATA_IN(AWADDR),
		.xDATA_OUT(ADDR_L),
		.LATCH_BUSY(NEW_ADDR)
		);
	
		
	always_ff @ (posedge ACLK) begin 		//prototype to put in aw or w channel
		if (new address and data recieved)      //new bit to capture if new data?
		begin	
					//
		end 
	end

	
	/* initialize or reset */
	always_ff @ (posedge ACLK) begin 				
		if (ARESETn = 0) begin
			AWREADY <= 1;				//latch is not busy so start with 1 available
			WREADY 	<= 1;				//AW and W can be sent at same time
			BVALID 	<= 0;
			ARREADY <= 1;
			RVALID 	<= 0;
			NEW_DATA <= 0;
			NEW_ADDR <= 0;
		end
		
		/* AW channel (write address)*/				
		if (NEW_ADDR) begin				//format (slave && master)
			AWREADY <= 0;				//latch is busy
		end
		
		/* W channel (write data)*/
		if (NEW_DATA) begin 
			WREADY <= 0;				//latch is busy
		end
		/* write to memory */
		if (NEW_DATA && NEW_ADDR) begin 
			memory[ADDR_L] 	<= DATA_L;		//write operation from latch  && do we want to wait another cycle?
			BRESP 		<= 2'b01;		//say data written to master (what do with this?)
			BVALID 		<= 1;
			AWREADY 	<= 1;			//make done writing so make latch available
			WREADY 		<= 1;	
			NEW_DATA 	<= 0;			//DATA+ADDR becomes old
			NEW_ADDR 	<= 0;
		end 
		
		/* B channel (write acknowledge)*/		
		if (BVALID && BREADY) begin
			BVALID <= 0;
		end
		
		/* AR channel (read address)*/	
		if (ARREADY && ARVALID) begin
			ARREADY = 0;
		end
		
		/* R channel (read data)*/		
		if (RVALID && RREADY) begin
			RVALID <= 0;
		end
	end
endmodule

module HANDSHAKE_LATCH #(parameter WIDTH =32) (
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
