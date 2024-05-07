//-----------------------------------------------------------------------------
//
// (c) Copyright 2001-2014 Consonance, LTD. All rights reserved.
//
//
//-----------------------------------------------------------------------------
// Project    PCIe DMA Egnine: 
// File       pcie_dma_engine: 
// Version    1.0: 
//
// Description:  
//
//----------------------------------------------------------------------------
`timescale 1ps/1ps                                                                                                     
                                                                                                                       
module completer_interface #(                                                                                                          
  parameter TCQ = 1,                                                                                            
  parameter C_DATA_WIDTH               = 256,                                                                
  parameter AXISTEN_IF_CC_ALIGNMENT_MODE   = "FALSE",                                                           
  parameter AXISTEN_IF_CC_PARITY_CHECK     = 0,                                                                 
  parameter AXI4_CQ_TUSER_WIDTH            = 88,                                                                                                                     
  //Do not modify the parameters below this line                                                                       
  parameter PARITY_WIDTH = C_DATA_WIDTH /8,                                                                            
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32,
  parameter MAPPED_ADDR_WIDTH				= 21                                                                            
)(                                                                                                                     
  input                            user_clk,                                                                           
  input                            reset_n,                                                                            
  input                            user_lnk_up,                                                                        
                                                                                                                       
                                                                                                                       
  // PIO TX Engine                                                                                                     
                                                                                                                       
  // AXI-S Completer Competion Interface                                                                               
                                                                                                                       
  output wire 	[C_DATA_WIDTH-1:0]   	s_axis_cc_tdata,                                                                    
  output wire   [KEEP_WIDTH-1:0]   		s_axis_cc_tkeep,                                                                    
  output wire                      		s_axis_cc_tlast,                                                                    
  output wire                      		s_axis_cc_tvalid,                                                                   
  output wire  	[32:0]   				s_axis_cc_tuser,                                                                    
  input                            		s_axis_cc_tready,                                                                   
                                                                                                                       
                                                                                                                       
  // Completer Request Interface                                                                                       
  input       [C_DATA_WIDTH-1:0]   		m_axis_cq_tdata,                                                                    
  input                            		m_axis_cq_tlast,                                                                    
  input                            		m_axis_cq_tvalid,                                                                   
  input       [AXI4_CQ_TUSER_WIDTH-1:0] m_axis_cq_tuser,                                                                    
  input       [KEEP_WIDTH-1:0]   		m_axis_cq_tkeep,                                                                    
  input                    [5:0]   		pcie_cq_np_req_count,                                                               
  output wire              		  		m_axis_cq_tready,                                                                   
  output wire                      		pcie_cq_np_req,                                                                     
                                                                                                                       
  // Payload info                                               
   output                payload_len,
   
   
  //W/R BAR info
  output               [2:0]    req_bar_id,                    
  output   			   [5:0]	req_bar_aperture,
                                                                       
  // Memory W/R interface

  output      [MAPPED_ADDR_WIDTH-1:0]    rd_addr,
  output      [3:0]     				 rd_be,
  output 	  [5:0]						 rd_req,
 
  input       [31:0]    				 rd_data,
  input 								 rd_valid,

  //  Write Port

  output      [MAPPED_ADDR_WIDTH-1:0]   wr_addr,
  output      [C_DATA_WIDTH/8-1:0]    	wr_be,
  output      [C_DATA_WIDTH-1:0]    	wr_data,
  output      [5:0]     				wr_en,
  output 								wr_last,
  input               					wr_busy

  

 
                                                                                                                         
); 


///////////////////////////////


  
  wire              req_compl;
  wire   [5:0]      req_compl_wd;
  wire              req_compl_ur;
  wire              compl_done;
  
  wire  [2:0]       req_tc;
  wire  [2:0]       req_attr;
  wire  [10:0]       req_len;
  wire  [15:0]      req_rid;
  wire  [7:0]       req_tag;
  wire  [7:0]       req_be;
  wire  [MAPPED_ADDR_WIDTH-1:0]      req_addr;
  wire  [1:0]       req_at;
  
  
  wire [63:0]       req_des_qword0;
  wire [63:0]       req_des_qword1;
  wire              req_des_tph_present;
  wire [1:0]        req_des_tph_type;
  wire [7:0]        req_des_tph_st_tag;
  
  
  wire              req_mem_lock;
  wire              req_mem;


  wire 				m_axis_cq_tready_bit;
 
///////////////////////////////////////////////////////////////////////////////////


	assign m_axis_cq_tready                    = m_axis_cq_tready_bit;
    assign rd_req = req_compl_wd;
	assign rd_addr = req_addr;


  cq_rx_t #(
    .TCQ(TCQ),
    .C_DATA_WIDTH               	( C_DATA_WIDTH ),
    .AXI4_CQ_TUSER_WIDTH            ( AXI4_CQ_TUSER_WIDTH),
	.MAPPED_ADDR_WIDTH				(MAPPED_ADDR_WIDTH)
  ) cq_rx_t_i (

    .user_clk( user_clk ),
    .reset_n( reset_n ),

    // Target Request Interface
    .m_axis_cq_tdata( m_axis_cq_tdata ),
    .m_axis_cq_tlast( m_axis_cq_tlast ),
    .m_axis_cq_tvalid( m_axis_cq_tvalid ),
    .m_axis_cq_tuser( m_axis_cq_tuser ),
    .m_axis_cq_tkeep( m_axis_cq_tkeep ),
    .m_axis_cq_tready( m_axis_cq_tready_bit ),
    .pcie_cq_np_req_count ( pcie_cq_np_req_count ),
    .pcie_cq_np_req ( pcie_cq_np_req ),


    .req_compl( req_compl ),
    .req_compl_wd( req_compl_wd ),
    .req_compl_ur( req_compl_ur ),
    .compl_done( compl_done ),

    .req_tc( req_tc ),
    .req_attr( req_attr ),
    .req_len( req_len ),
    .req_rid( req_rid ),
    .req_tag( req_tag ),
    .req_be( req_be ),
    .req_addr( req_addr ),
    .req_at( req_at ),

    .req_des_qword0( req_des_qword0 ),
    .req_des_qword1( req_des_qword1 ),
    .req_des_tph_present( req_des_tph_present ),
    .req_des_tph_type( req_des_tph_type ),
    .req_des_tph_st_tag( req_des_tph_st_tag ),
    .req_mem_lock( req_mem_lock ),
    .req_mem( req_mem ),

    
    .req_bar_id			(req_bar_id		 ),                    
  	.req_bar_aperture	(req_bar_aperture),
  
    
    
    .wr_addr( wr_addr ),
    .wr_be( wr_be ),
    .wr_data( wr_data ),
    .wr_en( wr_en ),
    .wr_last( wr_last),
    .payload_len( payload_len ),
    .wr_busy( wr_busy)
  );


  
  
  
  cc_tx_t #(
    .TCQ( TCQ ),
    .C_DATA_WIDTH             		( C_DATA_WIDTH ),
    .AXISTEN_IF_CC_ALIGNMENT_MODE ( AXISTEN_IF_CC_ALIGNMENT_MODE ),
    .AXISTEN_IF_CC_PARITY_CHECK   ( AXISTEN_IF_CC_PARITY_CHECK ),
    .MAPPED_ADDR_WIDTH				(MAPPED_ADDR_WIDTH)
  ) cc_tx_t_i (
    .user_clk( user_clk ),
    .reset_n( reset_n ),

    // AXI-S Target Competion Interface

    .s_axis_cc_tdata( s_axis_cc_tdata ),
    .s_axis_cc_tkeep ( s_axis_cc_tkeep ),
    .s_axis_cc_tlast( s_axis_cc_tlast ),
    .s_axis_cc_tvalid( s_axis_cc_tvalid ),
    .s_axis_cc_tuser( s_axis_cc_tuser ),
    .s_axis_cc_tready( s_axis_cc_tready ),

        
    .req_compl( req_compl ),
    .req_compl_wd( req_compl_wd ),
    .req_compl_ur( req_compl_ur ),
    .payload_len ( payload_len ),
    .compl_done( compl_done ),

    .req_tc( req_tc ),
    .req_td(1'b0),
    .req_ep(1'b0),
    .req_attr( req_attr[1:0] ),
    .req_len( req_len ),
    .req_rid( req_rid ),
    .req_tag( req_tag ),
    .req_be( req_be ),
    .req_addr( req_addr ),
    .req_at( req_at ),

    .req_des_qword0( req_des_qword0 ),
    .req_des_qword1( req_des_qword1 ),
    .req_des_tph_present( req_des_tph_present ),
    .req_des_tph_type( req_des_tph_type ),
    .req_des_tph_st_tag( req_des_tph_st_tag ),
    .req_mem_lock( req_mem_lock ),
    .req_mem( req_mem ),
    
    
    
    
    .rd_addr(  ),
    .rd_be( rd_be ),
    .rd_valid(rd_valid ),
    .rd_data( rd_data )

    );


endmodule                                                                                      
                                                                                                                       