interface TB_if #(
  	parameter int ADDR_W = 32,	
  	parameter int DATA_W = 64
	);
	/*
	This interface is used to for putting in data for manager or subordinate to send
	and observe what is recieved in each manager and subordinate
	*/
	logic [DATA_W-1:0] sub_rx_W, sub_tx_R, mgr_tx_W, mgr_rx_R;					
	logic [ADDR_W-1:0] sub_rx_AW, sub_rx_AR, mgr_tx_AW, mgr_tx_AR;
	logic [1:0] mgr_bresp, mgr_rresp, sub_bresp, sub_rresp;
	logic [4:0] tx_en, mgr_new_data, sub_new_data, mem_flag;		//enable transfer on AW: tx_en[4] | W: tx_en[3] | B: tx_en[2] | ARr: tx_en[1] | R: tx_en[0]
						//tx_en controls all 5 channel transfers both master and slave
						//same for new data flag when recieved
	modport manager (
		input mgr_tx_AW, mgr_tx_W, mgr_tx_AR, tx_en, mem_flag,		//name for clarity of direction and which port
		output mgr_rx_R, mgr_bresp, mgr_rresp, mgr_new_data		//this is just for TB top to hook to manager or subordinate
		);								// so manager and subordinate dont share any ports here
	modport subordinate (							//besides tx_en for send control and new_data for viewing if data is sent
		input sub_tx_R, sub_bresp, sub_rresp, tx_en, mem_flag,		// <<<<put the values you want to send in here,
		output sub_rx_AW, sub_rx_W, sub_rx_AR, sub_new_data   		// this is the values revieved
		);							
endinterface	
