
`timescale 1ns / 1ps

module user_interrupts #
(
	parameter NUM_OF_INTERRUPTS						= 1,

  	parameter AXI_ID_WIDTH                   		= 8,
  	parameter AXI_ADDR_WIDTH                 		= 16,
  	parameter AXI_DATA_WIDTH                 		= 32,
  	parameter AXI_STRB_WIDTH                 		= AXI_DATA_WIDTH/8
)
(
	// clock for all interfaces
    input  wire                     s_axi_clk,
    input  wire                     s_axi_rstn,
    
    
    //AXI Lite Registes target for W/R from the host
    input  wire [AXI_ADDR_WIDTH-1:0]    	s_axil_awaddr,              
    input  wire [2:0]               		s_axil_awprot,              
    input  wire                     		s_axil_awvalid,             
    output wire                     		s_axil_awready,             
    input  wire [AXI_DATA_WIDTH-1:0]    	s_axil_wdata,               
    input  wire [AXI_STRB_WIDTH-1:0]    	s_axil_wstrb,               
    input  wire                     		s_axil_wvalid,              
    output wire                     		s_axil_wready,              
    output wire [1:0]               		s_axil_bresp,               
    output wire                     		s_axil_bvalid,              
    input  wire                     		s_axil_bready,              
    input  wire [AXI_ADDR_WIDTH-1:0]    	s_axil_araddr,
    input  wire [2:0]               		s_axil_arprot,
    input  wire                     		s_axil_arvalid,
    output wire                     		s_axil_arready,
    output wire [AXI_DATA_WIDTH-1:0]    	s_axil_rdata,
    output wire [1:0]               		s_axil_rresp,
    output wire                     		s_axil_rvalid,
    input  wire                     		s_axil_rready,
    
	input  wire [NUM_OF_INTERRUPTS-1:0]     status_ack,		    
	output reg 	[NUM_OF_INTERRUPTS-1:0]     status_req,		    
	output wire [64*NUM_OF_INTERRUPTS-1:0]  status_qword,	
	output wire [64*NUM_OF_INTERRUPTS-1:0]  status_addr,	 
        
	input  wire [NUM_OF_INTERRUPTS-1:0] 	int_req_in,
	output reg 	[NUM_OF_INTERRUPTS-1:0] 	int_req
   
    
);

localparam NUM_OF_REGISTERS_PER_INT = 2;
localparam NUM_OF_REGISTERS = NUM_OF_REGISTERS_PER_INT*NUM_OF_INTERRUPTS;

(* keep = "true" *) reg [NUM_OF_REGISTERS-1:0] [31:0] read_reg_array;

wire [31:0] reg_val;                                                      
wire [7:0] reg_index;                                                     
wire reg_valid;  

(* keep = "true" *) reg [NUM_OF_REGISTERS-1:0] [7:0] int_cnt;                                                          


axi_reg_file #(                                                              
 .C_AXI_ADDR_WIDTH 	(AXI_ADDR_WIDTH),                                               
 .C_AXI_DATA_WIDTH 	(AXI_DATA_WIDTH),
 .ADDR_VADID_BITS 	(8),
 .NUM_OF_REGISTERS 	(NUM_OF_REGISTERS)
)
axi_reg_file_i 
(                                                                            
 .S_AXI_ACLK	(s_axi_clk),                                                    
 .S_AXI_ARESETN	(s_axi_rstn),                                                 
                                               
 .S_AXI_AWVALID	(s_axil_awvalid),                                                      
 .S_AXI_AWREADY	(s_axil_awready),                                              
 .S_AXI_AWADDR	(s_axil_awaddr),                             
 .S_AXI_AWPROT	(s_axil_awprot),                                    
 //                                                                             
 .S_AXI_WVALID	(s_axil_wvalid),                                                  
 .S_AXI_WREADY	(s_axil_wready),                                               
 .S_AXI_WDATA	(s_axil_wdata),                          
 .S_AXI_WSTRB	(s_axil_wstrb),                         
 //                                                                                         
 .S_AXI_BVALID	(s_axil_bvalid),                                                 
 .S_AXI_BREADY	(s_axil_bready),                                                  
 .S_AXI_BRESP	(s_axil_bresp),                                              
 //                                                                                        
 .S_AXI_ARVALID	(s_axil_arvalid),                                             
 .S_AXI_ARREADY	(s_axil_arready),                                                    
 .S_AXI_ARADDR	(s_axil_araddr),                             
 .S_AXI_ARPROT	(s_axil_arprot),                                           
 //                                                                                         
 .S_AXI_RVALID	(s_axil_rvalid),                                                                                                 
 .S_AXI_RREADY	(s_axil_rready),                                                      
 .S_AXI_RDATA	(s_axil_rdata),                           
 .S_AXI_RRESP	(s_axil_rresp),                                  
                                                                                  
                                                                                  
 .reg_val		(reg_val),                                                      
 .reg_index		(reg_index),                                                     
 .reg_valid		(reg_valid),                                                            
                                                                                
 .read_reg_array (read_reg_array)                     
);  

always @(posedge s_axi_clk) 
begin
	if(reg_valid)
		read_reg_array[reg_index] <= reg_val;
end

genvar i;

generate 
	for(i=0;i<NUM_OF_INTERRUPTS;i=i+1)
	begin
		assign status_addr[i*64+63-:64] = {read_reg_array[2*i+1],read_reg_array[2*i]};
		assign status_qword[i*64+63-:64] = {56'h00000000000000, int_cnt[i]};  
	end
endgenerate
	
integer j;	
always @(posedge s_axi_clk) 
begin
  if(!s_axi_rstn)
  begin
  		status_req <= 0;
  		for(j=0;j<NUM_OF_INTERRUPTS;j=j+1)
  		begin
 	 		int_req[j] <= 1'b0;
 	 		int_cnt[j] <= 8'h00; 
 		end
  end
  else 
  begin
  		for(j=0;j<NUM_OF_INTERRUPTS;j=j+1)
  		begin
  			if(int_req[j] == 1'b0 && int_req_in[j] == 1'b1)
  				status_req[j] <= 1'b1;
  			if(status_ack[j] == 1'b1)
  				status_req[j] <= 1'b0;
  				
  			int_req[j] <= status_ack[j];
  			
  			if(int_req[j] == 1'b0 && int_req_in[j] == 1'b1)
  				int_cnt[j] <= int_cnt[j]+1;	
  		end
  end
end
	


                                                                                        
                                                                                        
endmodule
