module read_data_mn_tb;

logic ACLK, ARESETn;

axi4.axi axi_if(.ACLK(ACLK), .ARESETn(ARESETn));       //Instantiate AXI Interface

read_read_mn uut(.bus_ports(axi_if.subordinate_mp));       //Instantiate modport(subordinate)

initial 
    begin
    
    axi_if.RDATA = 32'hffffffff;        
    axi.if.RRESP = 2'b01;
    axi_if.RVALID = 0;
    
     @(posedge ACLK);
    #5 axi.if.RVALID = 1'b1;        //Slave Ready, master not
       axi.if.RREADY = 1'b0;
       
    @(posedge ACLK);
    #5 axi.if.RVALID = 1'b1;        //Slave Ready, master not
       axi.if.RREADY = 1'b0;

    @(posedge ACLK);                
    #5 axi.if.RVALID = 1'b1;        //Slave Ready, master ready
       axi.if.RREADY = 1'b1;

    @(posedge ACLK);
    #5 axi.if.RVALID = 1'b1;        //Keep Valid, master ready
       axi.if.RREADY = 1'b1;

    @(posedge ACLK);
    #5 axi.if.RVALID = 1'b0;        //deassert valid after handshake 
       axi.if.RREADY = 1'b1;
       
    $finish

end 
endmodule 
