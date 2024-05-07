
`timescale 1ns / 1ps

module full_dup_tester #
(
	parameter CHAN_NUM								= 0,
	parameter PCIE_CORE_DATA_WIDTH 					= 128,
	parameter ONE_USEC_PER_BUS_CYCLE 				= 250,
	
  	
  	parameter AXI_ADDR_WIDTH                 		= 12,
  	parameter AXI_DATA_WIDTH                 		= 32,
  	parameter AXI_STRB_WIDTH                 		= AXI_DATA_WIDTH/8
	
)
(
	// clock for all interfaces
    input  wire                     s_axi_clk,
    input  wire                     s_axi_rstn,
	  	
  	// C2S AXI-S master Interface
  	
  	output reg [PCIE_CORE_DATA_WIDTH-1:0]  	 m_axis_tdata,
  	output reg [PCIE_CORE_DATA_WIDTH/32-1:0] m_axis_tkeep,
  	output reg                     			 m_axis_tlast,
  	output reg                     			 m_axis_tvalid,
  	output reg             [32:0]  			 m_axis_tuser,
  	input                      			     m_axis_tready,
  	
  	//User Interrupt requeset
  	output reg 								int_gen,
  	
  	// S2C AXI-S slave Interface
  	input  [PCIE_CORE_DATA_WIDTH-1:0]  	 	s_axis_tdata,
  	input  [PCIE_CORE_DATA_WIDTH/32-1:0]  	s_axis_tkeep,
  	input                      			 	s_axis_tlast,
  	input                      			 	s_axis_tvalid,
  	input              [32:0]  			 	s_axis_tuser,
  	output                      		 	s_axis_tready,
  	
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


//reg map:
localparam C2S_CTRL 		= 0;
localparam INT_GEN			= 1;
localparam INT_PERIOD 		= 2;
localparam C2S_PCKET_SIZE 	= 3;
localparam BURST_SIZE		= 4;
localparam INTER_PACKET_GAP	= 5;
localparam INTER_BURST_GAP  = 6;


localparam NUM_OF_REGISTERS = 16;
localparam ADDR_VADID_BITS  = 20; 


wire [31:0] reg_val;                             
wire [7:0] 	reg_index;                           
wire 		reg_valid; 
reg [NUM_OF_REGISTERS-1:0] [31:0] reg_array;

reg active;

localparam [3:0]
	inter_packet_gap 	= 3'b001,
	do_burst 			= 3'b010,
	inter_burst_gap  	= 3'b100;

reg [3:0] state;

reg [23:0] c2s_packet_size;
reg [23:0] bust_size;
reg [31:0] inter_packet_gap_size;
reg [31:0] inter_burst_gap_size;
 
reg [23:0] c2s_bytes_left;
reg [31:0] inter_packet_gap_left;
reg [23:0] bust_left;
reg [31:0] inter_burst_left;


////////////////////////////////////////// c2s  ////////////////////////////////

axi_reg_file #(                                                              
 .C_AXI_ADDR_WIDTH 	(AXI_ADDR_WIDTH),                                               
 .C_AXI_DATA_WIDTH 	(AXI_DATA_WIDTH),
 .ADDR_VADID_BITS 	(ADDR_VADID_BITS),
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
                                                                                
 .read_reg_array (reg_array)                     
);  

always @(posedge s_axi_clk) 
begin
	if(~s_axi_rstn)
		active <= 1'b0;
	else if(reg_valid && reg_index == C2S_CTRL)
		active <= reg_val[0];
end			



integer i;
always @(posedge s_axi_clk) 
begin
	if(~s_axi_rstn)
	begin
 		for(int i=0;i<PCIE_CORE_DATA_WIDTH/32;i++)
 		     m_axis_tdata[i*32+31-:32]  <=	i;
 		m_axis_tkeep  <=	{(PCIE_CORE_DATA_WIDTH/32){1'b0}};
 		m_axis_tlast  <= 1'b0;
 		m_axis_tvalid <= 1'b0;
 		m_axis_tuser  <= 32'b0;
		inter_packet_gap_left <= 8'h00;
		c2s_bytes_left	<= 24'h000000;	
	end
	else if(!active)
	begin
 		m_axis_tdata  <=	0;
 		m_axis_tkeep  <=	{(PCIE_CORE_DATA_WIDTH/32){1'b0}};
 		m_axis_tlast  <= 1'b0;
 		m_axis_tvalid <= 1'b0;
 		m_axis_tuser  <= 32'b0;
		state <= inter_packet_gap;
	end
	else
	begin
	
	
	
		m_axis_tdata <= m_axis_tdata;
 		m_axis_tkeep  <=	{(PCIE_CORE_DATA_WIDTH/32){1'b0}};
 		m_axis_tlast  <= 1'b0;
 		m_axis_tvalid <= 1'b0;
 		m_axis_tuser  <= 32'b0;
	
		case(state)
			inter_packet_gap:
			begin
				for(int i=0;i<PCIE_CORE_DATA_WIDTH/32;i++)
							m_axis_tdata[i*32+31-:32]  <=	i;
				if(inter_packet_gap_left < 2 && active)	
				begin
					c2s_bytes_left <= c2s_packet_size;
					bust_left <= bust_size;
					state <= do_burst;
				end
				
				if(inter_packet_gap_left)
					inter_packet_gap_left <= inter_packet_gap_left-1;
			end
			do_burst:
			begin
				m_axis_tvalid <= 1'b1; //m_axis_tready;
				if(m_axis_tready)
					bust_left <= bust_left-1;
				
				if(m_axis_tready)
					c2s_bytes_left <= c2s_bytes_left-PCIE_CORE_DATA_WIDTH/8;
				
				
				if((bust_left == 1 || !(c2s_bytes_left > PCIE_CORE_DATA_WIDTH/8)) && m_axis_tready && inter_burst_gap_size > 0)	
				begin
					state <= inter_burst_gap;
					inter_burst_left <= inter_burst_gap_size;
				end
				else if ((!(c2s_bytes_left > PCIE_CORE_DATA_WIDTH/8)) && m_axis_tready && inter_packet_gap_size == 0)
				begin
					c2s_bytes_left <= c2s_packet_size;
					bust_left <= bust_size;
					state <= do_burst;
				end
				else if ((!(c2s_bytes_left > PCIE_CORE_DATA_WIDTH/8)) && m_axis_tready)
				begin
					state <= inter_packet_gap;
					inter_packet_gap_left <= inter_packet_gap_size;

				end
				
				if(!(c2s_bytes_left > PCIE_CORE_DATA_WIDTH/8) && ~m_axis_tready)
				begin
					m_axis_tlast  <= m_axis_tlast;
					m_axis_tkeep  <=	m_axis_tkeep;
				end
				else if(!(c2s_bytes_left > PCIE_CORE_DATA_WIDTH/8))
				begin
					m_axis_tlast  <= 32'b1;
					m_axis_tkeep  <=	{(PCIE_CORE_DATA_WIDTH/32){1'b1}};
				end

				if(m_axis_tready)
				   for(int i=0;i<PCIE_CORE_DATA_WIDTH/32;i++)
					 m_axis_tdata[i*32+31-:32]  <=	m_axis_tdata[i*32+31-:32]+(PCIE_CORE_DATA_WIDTH/32);
			end
			inter_burst_gap:
			begin
				inter_burst_left <= inter_burst_left-1;
				
				if(inter_burst_left == 1 && c2s_bytes_left > 0)
				begin
					bust_left <= bust_size;
					state <= do_burst;
				end
				else if(inter_burst_left == 1)
				begin
					state <= inter_packet_gap;
				end
				
			end
		endcase
			
		
 		m_axis_tuser  <= 32'b0;		
	end	
end

////////////////////////////////////////// User Interrupt generation ////////////////////////////////
reg [31:0] counter;
reg int_gen_active;
always @(posedge s_axi_clk) 
begin
	if(~s_axi_rstn)
	begin
		counter <= 32'h00000000;
	end
	else 
	begin
		if(!int_gen_active)
			counter <= 32'h00000000;
		else if (!counter)
			counter <= reg_array[INT_PERIOD];
		else
			counter <= counter-1;
	end
end	

always @(posedge s_axi_clk) 
begin
	if(~s_axi_rstn)
		int_gen_active <= 1'b0;
	else if(reg_valid && reg_index == INT_GEN)
		int_gen_active <= reg_val[0];
end	


always @(posedge s_axi_clk) 
begin
	if(~s_axi_rstn)
		c2s_packet_size <= 24'h000080;
	else if(reg_valid && reg_index == C2S_PCKET_SIZE)
		c2s_packet_size <= reg_val[23:0];
end	


always @(posedge s_axi_clk) 
begin
	if(~s_axi_rstn)
		bust_size <= 24'h000001;
	else if(reg_valid && reg_index == BURST_SIZE)
		bust_size <= reg_val[23:0];
end	

always @(posedge s_axi_clk) 
begin
	if(~s_axi_rstn)
		inter_packet_gap_size <= 32'h00000000;
	else if(reg_valid && reg_index == INTER_PACKET_GAP)
		inter_packet_gap_size <= reg_val;
end	

always @(posedge s_axi_clk) 
begin
	if(~s_axi_rstn)
		inter_burst_gap_size <= 32'h00000000;
	else if(reg_valid && reg_index == INTER_BURST_GAP)
		inter_burst_gap_size <= reg_val;
end	




		
always @(posedge s_axi_clk) 
begin
	int_gen <= 1'b0;
	if(counter == 32'h00000001)
		int_gen <= 1'b1;
end	

////////////////////////////////////////// s2c  ///////////////////////////////////////////////////////

assign s_axis_tready = 1'b1;

//////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge s_axi_clk) 
begin
	if(reg_valid)
		reg_array[reg_index] <= reg_val;
end			
                                                                                        
                                                                                        
endmodule
