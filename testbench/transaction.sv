'ifndef AXI_TRANSACTION_SV
'define AXI_TRANSACTION_SV

//Enum for high level transaction operation
typedef enum {WRITE_OP, READ_OP, INVALID_OP} axi_op_t;

class axi_transaction;

    rand axi_op_t op;         //Transaction Metadata read and write operation
    rand bit [31:0] addr;     //Address
    rand bit [31:0] id;       //ID
    rand bit [63:0] w_data;   //Write Data

    constraint op_c {op dist {WRITE_OP:1, READ_OP:1};} // Constraint to prevent an INVALID_OP 
    
    constraint addr_c{addr [2:0] == 0}; //Constraint to ensure address alignment

    bit [63:0] r_data;         //Read Datafor 64-bit
    bit [1:0] resp;            //Response (Success, Fail)

    function new();
    endfunction

    //Deep Copy fucntion to duplicate the transaction object
    function axi_transaction copy(); 
        axi_transaction tmp;
        tmp = new();            //Deep Copy 
        tmp.op = this.op;
        tmp.addr = this.id;
        tmp.id = this.id;
        tmp.w_data = this.w_data;

        tmp.r_data = this.r_data;
        temp.resp = this.resp;

        //For tracking the responses in scoreboard
        return tmp;
    endfunction
endclass

'endif

    
