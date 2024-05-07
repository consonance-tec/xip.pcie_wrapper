
`timescale 1ns / 1ps

module sg_c2s_chan #
(
	parameter CHAN_NUM								= 0,
	parameter PCIE_CORE_DATA_WIDTH 					= 128,
	parameter ONE_USEC_PER_BUS_CYCLE 				= 250,
	parameter SWAP_ENDIAN			 				= 1,
	parameter MAX_USER_RX_REQUEST_SIZE 				= 4096, //256 4096;
	parameter NUM_NUM_OF_USER_RX_PENDINNG_REQUEST 	= 2,
	parameter BUFFES_SIZE_LOG_OF2					= 6,
		
  	parameter AXI_ID_WIDTH                   		= 8,
  	parameter AXI_ADDR_WIDTH                 		= 16,
  	parameter AXI_DATA_WIDTH                 		= 32,
  	parameter AXI_STRB_WIDTH                 		= AXI_DATA_WIDTH/8
 
)
(
	// clock for all interfaces
    input  wire                     s_axi_clk,
    input  wire                     s_axi_rstn,
    
    //global system enable			         
    input  sys_ena,     			

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
    
  
    
   //Mrd tag allocation interface
	output 			alloc_tag_req,
	input 			allocated_tag_rdy,
	input [7:0]	    allocated_tag,
    
    
    
	//Read Completion Interface
	input 	[PCIE_CORE_DATA_WIDTH-1 : 0]	bm_data, 
	input 	[PCIE_CORE_DATA_WIDTH/8-1:0]	bm_be,
	input 	bm_rx_done,
	input 	bm_rx_active,
	output 	bm_rx_rdy,
	input 	bm_rx_last_in_burst,
	input 	[31:0]	bm_context,

	// MRd Req Interface
	output 		mrd_req_arbit_req,
	input  		mrd_req_arbit_grnt,
	input  		mrd_req_rearbit_req,	
	output [12:0] mrd_req_burst_len_out,
	output [63:0] mrd_req_burst_sys_addr_out,
	output [7:0]  mrd_req_burst_tag,
	output [31:0] mrd_req_context,
	
	
    // TX Dispatcher Interface 
    output tx_stop,
	output tx_arbit_req,
	input  tx_arbit_grnt,
	input  tx_rearbit_req,	
	output [12:0] tx_burst_len_out,
	output [63:0] tx_burst_sys_addr_out,
	output [7:0] tx_burst_tag,
	input tx_wr_active, 
	
	input  read_req,
	output [PCIE_CORE_DATA_WIDTH-1:0] read_data,
	
	
	

	  	
  	// AXI-S slave Interface from the app
  	
  	input [PCIE_CORE_DATA_WIDTH-1:0]  	s_axis_tdata,
  	input [PCIE_CORE_DATA_WIDTH/32-1:0] s_axis_tkeep,
  	input                     	s_axis_tlast,
  	input                     	s_axis_tvalid,
  	input             [32:0]  	s_axis_tuser,
  	output                      s_axis_tready,
  	
  	//////////////// SG_BM signals ////////////////////////
    //system level state 
	input [12:0] max_payload_size,
	input [12:0] max_read_request_size,
	
	// interrupt request signals	
	output int_gen,	
	
	input  status_ack,
	output status_req,
	output [63:0] status_qword,
	output [63:0] status_addr
    
);

localparam NUM_OF_REGISTERS = 5;
localparam C_AXI_ADDR_WIDTH = 4;     
localparam C_AXI_DATA_WIDTH = 32;    
localparam ADDR_VADID_BITS  = 20; 

function integer clog2 (
	input integer number
);
integer i;
integer count;
begin
	clog2 = 0;
	count = 0;
	for(i = 0; i < 32; i = i + 1)
	begin
		if(number&(1<<i))
		begin
			clog2 = i;
			count = count + 1;
		end
	end
	// clog2 holds the largest set bit position and count
	// holds the number of bits set. More than one bit set
	// indicates that the input was not an even power of 2,
	// so round the result up.
	if(count > 1)
		clog2 = clog2 + 1;
end
endfunction


//registes acess interface
wire [31:0] reg_val;                             
wire [7:0] 	reg_index;                           
wire 		reg_valid; 
wire [NUM_OF_REGISTERS-1:0] [31:0] read_reg_array;

//front buffer / mrd req interface
wire [63:0]	tx_sys_addr;
wire		tx_dir;
wire		tx_last;
wire		tx_active;
wire		tx_done;
wire [12:0]	tx_burst_size;
wire		tx_data_valid;
wire [PCIE_CORE_DATA_WIDTH-1 : 0] tx_data;
wire [31:0] tx_bufffer_space;
wire stop_req_pending; 		
wire stop_rq_ack;

//TODO: connect the following signals to the registes file
reg bm_ena_clr;  			//in  			       
reg bm_start; 				//in   			         
reg bm_stop; 				//in    
reg state;					//out
reg [63:0] bm_req_address;	//in	
				          
wire bm_wait_for_int_ack; 

wire bm_req;
wire bm_rdy;

wire bmi_tx_last;
wire bmi_tx_data_valid;
wire [clog2(PCIE_CORE_DATA_WIDTH/8)-1:0]	bmi_tx_empty;
wire [PCIE_CORE_DATA_WIDTH-1:0]				bmi_tx_data;
wire bmi_tx_data_rdy;

wire [255:0] dbg_word;


axi_reg_file #(                                                              
 .C_AXI_ADDR_WIDTH 	(C_AXI_ADDR_WIDTH),                                               
 .C_AXI_DATA_WIDTH 	(C_AXI_DATA_WIDTH),
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
                                                                                
 .read_reg_array (read_reg_array)                     
);  

	
 assign	bmi_tx_last	= s_axis_tlast && bmi_tx_data_rdy && s_axis_tvalid;
 assign	bmi_tx_data_valid = bmi_tx_data_rdy && s_axis_tvalid;
 assign	bmi_tx_empty = s_axis_tkeep;
 assign	bmi_tx_data = s_axis_tdata;
 assign	s_axis_tready = bmi_tx_data_rdy;


	
c2s_sg_bm #
(
	.CHAN_NUM								(CHAN_NUM),								                     
	.PCIE_CORE_DATA_WIDTH 					(PCIE_CORE_DATA_WIDTH), 					           
	.ONE_USEC_PER_BUS_CYCLE 				(ONE_USEC_PER_BUS_CYCLE), 				          
	.SWAP_ENDIAN			 				(SWAP_ENDIAN),			 				                  
	.MAX_USER_RX_REQUEST_SIZE 				(MAX_USER_RX_REQUEST_SIZE), 				        
	.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST 	(NUM_NUM_OF_USER_RX_PENDINNG_REQUEST)               
)
c2s_sg_bm_i
( 
	// system i/f
	.reset_n_i 					(s_axi_rstn),  
    .clk 						(s_axi_clk), 
	
	.msix_enabled_i				(1'b0), //msix (if enabled) is handeled by the interrutp controller
	.max_payload_size_i			(max_payload_size),
	.max_read_request_size_i 	(max_read_request_size),
	
	.msix_vector_control_i		(32'h00000000),
	.msix_msg_data_i			(32'h00000000),
	.msix_msg_uppr_addr_i		(32'h00000000),
	.msix_msg_addr_i			(32'h00000000),
	
	.sys_ena_i 					(sys_ena),
	.bm_ena_clr_i 				(bm_ena_clr),
	.bm_start_i					(bm_start),
	.bm_stop_i					(bm_stop),
	.state_o					(state),
	.bm_req_address_i			(bm_req_address),	

	.stop_req_pending_o			(stop_req_pending),
	.stop_rq_ack_i				(stop_rq_ack),

	.bm_wait_for_int_ack_i 			(),
	.bm_int_ack_i					(1'b0),
	
	// interrupt signals 	
	.int_gen_o						(int_gen),
	
  	//tx bm i/f
	.tx_sys_addr_o    				(tx_sys_addr),
	.tx_dir_o						(tx_dir),
	.tx_last_o						(tx_last),
	.tx_active_i					(tx_active),
	.tx_done_i						(tx_done),
	.tx_burst_size_o				(tx_burst_size),
	.tx_data_valid_o 	 			(tx_data_valid),
	.tx_data_o    	  				(tx_data),
	.tx_bufffer_space_i				(tx_bufffer_space),
	.bm_tx_data_front_buff_empty_i	(bm_tx_data_front_buff_empty),
	.bm_tx_data_fron_buff_flush_o 	(bm_tx_data_fron_buff_flush),

		
	.status_ack						(status_ack),
	.status_req						(status_req),
	.status_qword					(status_qword),
	.status_addr					(status_addr),
                                	
	.buffer_rdy_o					(),		
	                            	
  	//rx bm i/f                 	
  	.rx_data_i    	  				(bm_data),
	.rx_done_i						(bm_rx_done),
	.rx_active_i					(bm_rx_active),
	.bm_rx_rdy_o					(bm_rx_rdy),
	.bm_rx_last_in_burst_i 			(bm_rx_last_in_burst),
	.rx_be_i						(bm_be),
 	.bm_context_i					(bm_context),
 	
 	//bus master initiator <--> arbiter i/f	
	.bm_req_o			   			(bm_req),
	.bm_rdy_i			   			(bm_rdy),
	.context_o						(mrd_req_context),
	                            	
    .bm_transfer_size_o         	(), 
    .bm_transfer_size_valid_o   	(),
  	                            	
	                            	
	.bm_packet_ack_i				(1'b0),

	//bm intiator i/f
	.bmi_bm_tag_data_o				(),
	.bmi_status_i					(10'b0000000000),
	
	.bmi_tx_last_i					(bmi_tx_last),
	.bmi_tx_data_valid_i 	 		(bmi_tx_data_valid),
	.bmi_tx_empty_i					(bmi_tx_empty),
	.bmi_tx_data_i    	  			(bmi_tx_data),
	.bmi_tx_data_rdy_o				(bmi_tx_data_rdy),
	
	.bmi_rx_rdy_i					(1'b0),
	.bmi_rx_data_o					(),
	.bmi_rx_data_valid_o			(),
	.bmi_rx_last_o					(),
	.bmi_rx_be_o					(),
	.bmi_rx_first_o					(),
	.bmi_rx_pending_o				(),
	
	                            	
	.bmi_transfer_done_o 			(),
		
	
	.tx_error_i						(1'b0),
                                	
	.chnn_gp_in_0_o					(),
	.chnn_gp_in_1_o					(),
	.chnn_gp_out_0_i				(32'h00000000),
	.chnn_gp_out_1_i				(32'h00000000),
                                	
	.dbg_signal_o					(),
	.dbg0_reg_0						(),
	.dbg_word_o						(dbg_word)
);


wire tx_bm_req;
wire rd_bm_req;
wire tx_bm_rdy;
wire rd_bm_rdy;

assign tx_stop = stop_req_pending;
assign tx_bm_req = bm_req && tx_dir;
assign rd_bm_req = bm_req && ~tx_dir;
assign bm_rdy = tx_bm_rdy || rd_bm_rdy;


	
	
	
		
	
	
	
	
	




tx_fron_buff # 	
(
	.CHAN_ID					(CHAN_NUM),		
	.PCIE_CORE_DATA_WIDTH		(PCIE_CORE_DATA_WIDTH),
	.BUFFES_SIZE_LOG_OF2	 	(6),
	.XILINX_MODE			 	(1'b1),
	.EVAL				 		("FALSE") 
)
tx_fron_buff_i
(
	// signals at system clock
	.reset_n_i 					(s_axi_rstn),  
    .clk_i 						(s_axi_clk), 
    
	.write_ena_i			 	(tx_data_valid),
	.write_last_i				(tx_last),
	.write_rdy_o			  	(tx_active),
	.write_data_i				(tx_data),

	.tx_buffer_space_o			(tx_bufffer_space),
	
		
	.alloc_tag_req_o			(),
	.allocated_tag_rdy_i		(1'b0),
	.allocated_tag_i			(8'h00),
	
	// value on delay_i is valid at clk_i domain 
	.read_req					(read_req),
	.read_data_o				(read_data),
	.read_empty_o				(bm_tx_data_front_buff_empty), //
	.wc_o 						(),
	
	.flush_i					(bm_tx_data_fron_buff_flush),
	.overflow_o					(),
	
	.burst_req_i				(tx_bm_req),
	.burst_rdy_o				(tx_bm_rdy),
	.burst_len_i				(tx_burst_size),
	.burst_sys_addr_i			(tx_sys_addr),
	
	//TX Dispatcher interface
	.arbit_req_o				(tx_arbit_req),
	.arbit_grnt_i				(tx_arbit_grnt),
	.rearbit_req_i				(tx_rearbit_req),
	
	.burst_len_out_o			(tx_burst_len_out),
	.burst_dir_out_o			(),
	.burst_sys_addr_out_o		(tx_burst_sys_addr_out),
	.burst_tag_o				(tx_burst_tag),
	                        	
	.stop_req_pending_i			(stop_req_pending),
	.stop_rq_ack_o				(stop_rq_ack),
	.wr_active_i				(tx_wr_active)
		
);

wire [12:0] mrd_req_burst_len;

mrd_requestor # 	
(
	.CHAN_ID				 (CHAN_NUM) 
)
mrd_requestor_i
(
	
	.reset_n_i 				(s_axi_rstn),  
    .clk_i 					(s_axi_clk), 
		
	.alloc_tag_req_o		(alloc_tag_req),
	.allocated_tag_rdy_i	(allocated_tag_rdy),
	.allocated_tag_i		(allocated_tag),
	
	.burst_req_i			(rd_bm_req),
	.burst_rdy_o			(rd_bm_rdy),
	.burst_len_i			(tx_burst_size),
	.burst_sys_addr_i		(tx_sys_addr),  
	
	.arbit_req_o			(mrd_req_arbit_req),
	.arbit_grnt_i			(mrd_req_arbit_grnt),
	.rearbit_req_i			(mrd_req_rearbit_req),
	
	.burst_len_out_o		(mrd_req_burst_len),
	.burst_dir_out_o		(),
	.burst_sys_addr_out_o	(mrd_req_burst_sys_addr_out),
	.burst_tag_o			(mrd_req_burst_tag)
);


assign mrd_req_burst_len_out = mrd_req_burst_len[12:0];

 
always @(posedge s_axi_clk) 
begin
  if(!s_axi_rstn)
  begin
  		bm_ena_clr <= 1'b0;
  end
  else if(reg_valid && reg_index == 0)
  begin
  		bm_ena_clr <= reg_val[0];
  end
end

always @(posedge s_axi_clk) 
begin
	bm_start <= 1'b0;
  	bm_stop <= 1'b0;
  	if(reg_valid && reg_index == 0)
  	begin
		bm_start <= reg_val[2];
	  	bm_stop <= reg_val[7];
  	end
end 	

always @(posedge s_axi_clk) 
begin
	if(reg_valid && reg_index == 1)
		bm_req_address[31:0] <= reg_val;
		
	if(reg_valid && reg_index == 2)
		bm_req_address[63:32] <= reg_val;
end
	

 
 assign read_reg_array[0] = {30'b0 ,state, 1'b0};
 assign read_reg_array[1] = bm_req_address[31:0];  
 assign read_reg_array[2] = bm_req_address[63:31];
 assign read_reg_array[3] = dbg_word[31:0];                                                                  
                                                                                        
endmodule
