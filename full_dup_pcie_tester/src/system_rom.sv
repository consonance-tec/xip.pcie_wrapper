

`timescale 1ns / 1ps

module system_rom #
(
  	parameter NUM_OF_C2S_CHANNELS = 1,
  	parameter NUM_OF_S2C_CHANNELS = 1, 
  	parameter	NUM_OF_INTERRUPTS = 1,
	parameter 	DATAE 			= 32'h03_0A_07e6,
	parameter 	VER_MJ 			= 16'h0005,
	parameter 	VER_MN 			= 16'h0001,

  	parameter AXI_ID_WIDTH      = 8,
  	parameter AXI_ADDR_WIDTH    = 16,
  	parameter AXI_DATA_WIDTH    = 32,
  	parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8
 
)
(
	// clock for all interfaces
    input  wire                     		s_axi_clk,
    input  wire                     		s_axi_rstn,

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
    input  wire                     		s_axil_rready


);

localparam NUM_OF_REGISTERS = 5;

wire [NUM_OF_REGISTERS-1:0] [31:0] read_reg_array;

wire [31:0] reg_val;
wire [7:0] 	reg_index;
wire 		reg_valid;



wire [15:0] num_of_c2s = NUM_OF_C2S_CHANNELS;
wire [15:0] num_of_s2c = NUM_OF_S2C_CHANNELS;	
		
assign read_reg_array[0] = {VER_MJ,VER_MN};
assign read_reg_array[1] = DATAE;
assign read_reg_array[2] = NUM_OF_INTERRUPTS;
assign read_reg_array[3] = NUM_OF_C2S_CHANNELS+NUM_OF_S2C_CHANNELS;
assign read_reg_array[4] = {num_of_s2c,num_of_c2s};
		
axi_reg_file #(                                                              
 .C_AXI_ADDR_WIDTH 	(AXI_ADDR_WIDTH),                                               
 .C_AXI_DATA_WIDTH 	(AXI_DATA_WIDTH),
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

 

                                                                                        
                                                                                        
endmodule