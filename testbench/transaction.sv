'ifndef AXI_TRANSACTION_SV
'define AXI_TRANSACTION_SV

typedef enum {WRITE_OP, READ_OP, INVALID_OP} axi_op_t;

class axi_transaction;

    rand axi_op_t op; //Transaction Metadata read and write operation
    rand bit [31:0] addr;    //Address
    rand bit [31:0] id;      //Data

    //Read and Write to monitor and capture response 
    rand bit [63:0] w_data; 
    bit [31:0] r_data;
    bit [1:0] resp;    //Response (Success, Fail)

    function new();
    endfunction

    function axi_transaction copy();
        axi_transaction tmp;
        tmp = new();
        tmp.op = this.op;
        tmp.addr = this.id;
        tmp.id = this.id;
        tmp.w_data = this.w_Data;

        return tmp;
    endfunction
endclass

'endif

    
