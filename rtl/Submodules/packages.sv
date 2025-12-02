package axi_helper;
	localparam int 	DATA_LEN = 64;			//values should match DATA_W /ADDR_W from axi bus
	localparam int	ADDR_LEN = 32;
	localparam int	ID_LEN = 4;
	localparam int	WSTRB_LEN = DATA_LEN/8;
	
	

	typedef enum logic [1:0] {
		OKAY	= 2'b00,
		EXOKAY	= 2'b01,
		SLVERR	= 2'b10,
		DECERR	= 2'b11
	} resp_t;

	//AXI_LITE
	//localparam for input into submodule .WIDTH parameter for xDATA
	localparam int	WxDATA_W = DATA_LEN + WSTRB_LEN;
	localparam int	RxDATA_W = DATA_LEN + 2;
	typedef struct packed {			//this is how to add more lines to each channel bus
		logic [DATA_LEN-1:0] data;
		logic [WSTRB_LEN-1:0] wstrb;
	} WxDATA_t;
	
	typedef struct packed {
		logic [DATA_LEN-1:0] data;
		resp_t resp;
	} RxDATA_t;
	

	/*
	//AXI_FULL
	localparam int	AWxDATA_W = ID_LEN + ADDR_LEN + 8 + 3 + 2;	//not used in axi_lite
	localparam int	WxDATA_W = ID_LEN + DATA_LEN + WSTRB_LEN + 1;	//not used in axi_lite
	localparam int	BxDATA_W = ID_LEN + 2;				//not used in axi_lite
	localparam int	ARxDATA_W = ID_LEN + ADDR_LEN + 8 + 3 + 2;	//not used in axi_lite each addition is a separate line
	localparam int	RxDATA_W = ID_LEN + DATA_LEN + 2 + 1;
	
	typedef struct packed {	
	logic [ID_LEN-1:0]     id;
	logic [ADDR_LEN-1:0] addr;
	logic [7:0]           len;    // beats-1
	logic [2:0]          size;   // log2(bytes/beat)
	logic [1:0]         burst;  // 01=INCR
	} AWxDATA_t;
	  // --- Write Data (W) ---
	typedef struct packed {	
	logic [DATA_LEN-1:0] data;
	logic [STRB_LEN-1:0] strb;
	logic                last;
	} WxDATA_t;
	  // --- Write Response (B) ---
	typedef struct packed {	
	logic [ID_LEN-1:0]    bid;
	resp_t		     resp;    
	} BxDATA_t;
	  // --- Read Address (AR) ---
	typedef struct packed {	
	logic [ID_LEN-1:0]     id;
	logic [ADDR_LEN-1:0] addr;
	logic [7:0]           len;
	logic [2:0]          size;
	logic [1:0]         burst;  
	} ARxDATA_t;

	  // --- Read Data (R) ---
	typedef struct packed {	
	logic [ID_LEN-1:0]     id;
	logic [DATA_LEN-1:0] data;
	resp_t               resp;
	logic                last;
	} RxDATA_t;
	*/
endpackage


