//-----------------------------------------------------------------------------
//
// (c) Copyright 2001-2014 Consonance, LTD. All rights reserved.
//
//
//-----------------------------------------------------------------------------
// Project    PCIe DMA Egnine: 
// File       us_pcie_top.v: 
// Version    0.1: 
//
// Description:  
//
//----------------------------------------------------------------------------

`define PCI_EXP_EP_OUI                           24'h000A35
`define PCI_EXP_EP_DSN_1                         {{8'h1},`PCI_EXP_EP_OUI}
`define PCI_EXP_EP_DSN_2                         32'h00000001

`define PCIE4_NEW_PINS 1
`timescale 1ps / 1ps


module cosn_dma_us_top # (

  parameter 	NUM_OF_INTERRUPTS  	= 2,
  parameter     BAR2_ENABLED        = 0,
  parameter 	NUM_OF_S2C_CHAN		= 1,
  parameter 	NUM_OF_C2S_CHAN  	= 1,
    
  parameter C_DATA_WIDTH 			= 256,
  parameter AXI4_CQ_TUSER_WIDTH     = 88,
  parameter AXI4_RQ_TUSER_WIDTH     = 62,
  parameter AXI4_RC_TUSER_WIDTH     = 75,
  parameter KEEP_WIDTH   			= C_DATA_WIDTH/32,
  
  parameter 		AXI_ID_WIDTH       = 8,
  parameter 		AXI_ADDR_WIDTH     = 20,
  parameter 		AXI_DATA_WIDTH     = 32,
  parameter 		AXI_STRB_WIDTH     = AXI_DATA_WIDTH/8,
  
 parameter ONE_USEC_PER_BUS_CYCLE 				= 250,
 parameter SWAP_ENDIAN			 				= 0,
 parameter MAX_USER_RX_REQUEST_SIZE 			= 4096, //256 4096;
 parameter NUM_NUM_OF_USER_RX_PENDINNG_REQUEST 	= 2,
 parameter BUFFES_SIZE_LOG_OF2					= 6	
  
) 
(
  
  input   	usr_rst,
  input   	usr_clk,
  
  input  	[7:0] cfg_fc_ph,
  input  	[11:0] cfg_fc_pd,
  input  	[7:0] cfg_fc_nph,
  input  	[11:0] cfg_fc_npd,
  input  	[7:0] cfg_fc_cplh,
  input  	[11:0] cfg_fc_cpld,
  output 	[2:0] cfg_fc_sel,
  
  output    cfg_msg_transmit,
  output   	[2:0] cfg_msg_transmit_type,
  output  	[31:0] cfg_msg_transmit_data,
  input     cfg_msg_transmit_done,
  
  input    			cfg_msg_received,
  input  	[7:0]  	cfg_msg_received_data,
  input  	[4:0]  	cfg_msg_received_type, 


  
  output    [1:0]   pcie_cq_np_req,
  input 	[5:0]   pcie_cq_np_req_count,
  input  	[1:0]   cfg_current_speed,
  input          	cfg_err_cor_out,
  input          	cfg_err_nonfatal_out,
  input          	cfg_err_fatal_out,
  input  	[15:0]  cfg_function_status,
  input  	[11:0]  cfg_function_power_state,
  input  	[1:0]   cfg_link_power_state,
  input  	[4:0]   cfg_local_error_out,
  input				cfg_local_error_valid,
  input  	[5:0]   cfg_ltssm_state,
  input  	[1:0]   cfg_max_payload,  					
  input  	[2:0]   cfg_max_read_req,
  input  	[2:0]   cfg_negotiated_width,
  input  	[1:0]   cfg_obff_enable,
  input          	cfg_phy_link_down,
  input          	cfg_phy_link_status,
  input          	cfg_pl_status_change,
  input  	[3:0]   cfg_rcb_status,
  input 	[5:0]   pcie_rq_seq_num0,
  input      		pcie_rq_seq_num_vld0,
  input 	[5:0]   pcie_rq_seq_num1,
  input      		pcie_rq_seq_num_vld1,
  input 	[7:0]   pcie_rq_tag0,
  input 	[7:0]   pcie_rq_tag1,
  input 	[3:0]   pcie_rq_tag_av,
  input 			pcie_rq_tag_vld0,
  input 			pcie_rq_tag_vld1,
  input 	[1:0]	cfg_rx_pm_state,
  input   	[3:0]   cfg_tph_requester_enable,
  input  	[11:0]  cfg_tph_st_mode,           
  input 	[1:0]	cfg_tx_pm_state,
  input 		[755:0]	cfg_vf_power_state,
  input 		[503:0] cfg_vf_status,
  input 		[251:0] cfg_vf_tph_requester_enable,
  input 		[755:0] cfg_vf_tph_st_mode,
  
  input    [3:0]  	pcie_tfc_nph_av,
  input    [3:0]  	pcie_tfc_npd_av,
    
  output  	[9:0]  	cfg_mgmt_addr,
  output  	[3:0]  	cfg_mgmt_byte_enable,
  output	[7:0]   cfg_mgmt_function_number,
  input 	[31:0]  cfg_mgmt_read_data,
  output         	cfg_mgmt_read,
  input         	cfg_mgmt_read_write_done,
  output 	[31:0]  cfg_mgmt_write_data,  
  output       		cfg_mgmt_write,
  
     
  output			cfg_pm_aspm_l1_entry_reject,
  output			cfg_pm_aspm_tx_l0s_entry_disable,
   
  input 	[3:0] 	cfg_interrupt_msi_enable,    					                    
  output 	[31:0]  cfg_interrupt_msi_int,
  input   			cfg_interrupt_msi_sent,    										                                       
  input  			cfg_interrupt_msi_fail,    										                                       		
  input		[11:0] 	cfg_interrupt_msi_mmenable,
  input        		cfg_interrupt_msi_mask_update,
  input		[31:0] 	cfg_interrupt_msi_data,
  output  	[1:0] 	cfg_interrupt_msi_select,
  output	[63:0] 	cfg_interrupt_msi_pending_status,
  output  	[2:0] 	cfg_interrupt_msi_attr,
  output       		cfg_interrupt_msi_tph_present,
  output  	[1:0] 	cfg_interrupt_msi_tph_type,
  output  	[7:0] 	cfg_interrupt_msi_tph_st_tag,
  output  	[7:0] 	cfg_interrupt_msi_function_number,
  output  	[1:0] 	cfg_interrupt_msi_pending_status_function_num,
  output		  	cfg_interrupt_msi_pending_status_data_enable,
  
  output  	[3:0] 	cfg_interrupt_int,
  output  	[1:0] 	cfg_interrupt_pending,
  input        		cfg_interrupt_sent,
  
  input		[7:0]	cfg_bus_number,
  output			cfg_config_space_enable,
  output	[8:0]	cfg_ds_port_number,
  output	[8:0]	cfg_ds_bus_number,
  output	[4:0]   cfg_ds_device_number,
  output	[2:0]   cfg_ds_function_number,
  output	[63:0]  cfg_dsn,
  output			cfg_err_cor_in,
  output			cfg_err_uncor_in,
  input   	[3:0] 	cfg_flr_in_process,
  output   	[3:0] 	cfg_flr_done,
  input         	cfg_hot_reset_out,
  output            cfg_hot_reset_in,
  output			cfg_link_training_enable,
  input         	cfg_power_state_change_interrupt,
  output         	cfg_power_state_change_ack,
  output         	cfg_req_pm_transition_l23_ready,
  output 	[7:0] 	cfg_vf_flr_func_num,
  output       		cfg_vf_flr_done,
  input 	[251:0] cfg_vf_flr_in_process,
  
  
  // AXI-S Completer Interfaces

  output  [C_DATA_WIDTH-1:0]  s_axis_cc_tdata,
  output  [KEEP_WIDTH-1:0]  	 s_axis_cc_tkeep,
  output                      s_axis_cc_tlast,
  output                      s_axis_cc_tvalid,
  output  [32:0]  			 s_axis_cc_tuser,
  input                          s_axis_cc_tready,

  input      [C_DATA_WIDTH-1:0]    	m_axis_cq_tdata,
  input                            	m_axis_cq_tlast,
  input                            	m_axis_cq_tvalid,
  input      [AXI4_CQ_TUSER_WIDTH-1:0]    m_axis_cq_tuser,
  input      [KEEP_WIDTH-1:0]    	m_axis_cq_tkeep,
  output                        	m_axis_cq_tready,
    
  
  //AXI-S Requester Interfaces
  
  output 	[C_DATA_WIDTH-1:0]   		m_axis_rq_tdata, 	 
  output 	[AXI4_RQ_TUSER_WIDTH-1:0]   	m_axis_rq_tuser, 	
  output 	                      		m_axis_rq_tlast, 		 
  output 	[KEEP_WIDTH-1:0]   		m_axis_rq_tkeep, 		 
  output 	                      		m_axis_rq_tvalid,		 
  input  	                    		m_axis_rq_tready,
  
	input 		[C_DATA_WIDTH - 1:0]		s_axis_rc_tdata,
	input 		[C_DATA_WIDTH/32-1:0]		s_axis_rc_tkeep,
	input 						s_axis_rc_tlast,  
	input 						s_axis_rc_tvalid, 
	output						s_axis_rc_tready, 
	input 		[AXI4_RC_TUSER_WIDTH-1:0]				s_axis_rc_tuser ,
  
  input             user_lnk_up,
  input             phy_rdy_out,
  ///////////// user interface //////////////////////////////////    
 input 	int_req_0,
 input 	int_req_1,
 input 	int_req_2,
 input 	int_req_3,
 input 	int_req_4,
 input 	int_req_5,
 input 	int_req_6,
 input 	int_req_7,
  
 
 input   	axi_resetn,
 input   	axi_clk,
 
 output [AXI_ID_WIDTH-1:0]    	bar2_m_axi_awid,
 output [AXI_ADDR_WIDTH-1:0]  	bar2_m_axi_awaddr,
 output [7:0]                 	bar2_m_axi_awlen,
 output [2:0]                 	bar2_m_axi_awsize,
 output [1:0]                 	bar2_m_axi_awburst,
 output                       	bar2_m_axi_awlock,
 //output [3:0]                 bar2_m_axi_awcache,
 output [2:0]                 	bar2_m_axi_awprot,
 output                       	bar2_m_axi_awvalid,
 input                        	bar2_m_axi_awready,
 output [AXI_DATA_WIDTH-1:0]  	bar2_m_axi_wdata,
 output [AXI_STRB_WIDTH-1:0]  	bar2_m_axi_wstrb,
 output                       	bar2_m_axi_wlast,
 output                       	bar2_m_axi_wvalid,
 input                        	bar2_m_axi_wready,
 input  [AXI_ID_WIDTH-1:0]    	bar2_m_axi_bid,
 input  [1:0]                 	bar2_m_axi_bresp,
 input                        	bar2_m_axi_bvalid,
 output                       	bar2_m_axi_bready,
 
 output [AXI_ID_WIDTH-1:0]    	bar2_m_axi_arid,
 output [AXI_ADDR_WIDTH-1:0]  	bar2_m_axi_araddr,
 output [7:0]                 	bar2_m_axi_arlen,
 output [2:0]                 	bar2_m_axi_arsize,
 output [1:0]                 	bar2_m_axi_arburst,
 output                       	bar2_m_axi_arlock,
 output [3:0]                 	bar2_m_axi_arcache,
 output [2:0]                 	bar2_m_axi_arprot,
 output                       	bar2_m_axi_arvalid,
 input                        	bar2_m_axi_arready,
 input  [AXI_ID_WIDTH-1:0]    	bar2_m_axi_rid,
 input  [AXI_DATA_WIDTH-1:0]  	bar2_m_axi_rdata,
 input  [1:0]                 	bar2_m_axi_rresp,
 input                        	bar2_m_axi_rlast,
 input                        	bar2_m_axi_rvalid,
 output                       	bar2_m_axi_rready,
 
 output [C_DATA_WIDTH-1:0] 		s2c0_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c0_axis_tkeep,
 output [0:0]              		s2c0_axis_tlast,
 output [0:0]              		s2c0_axis_tvalid,
 output [31:0]  				s2c0_axis_tuser,
 input  [0:0]              		s2c0_axis_tready,
                           	
 input  [C_DATA_WIDTH-1:0]  	c2s0_axis_tdata,
 input  [KEEP_WIDTH-1:0]  		c2s0_axis_tkeep,
 input  [0:0]               	c2s0_axis_tlast,
 input  [0:0]               	c2s0_axis_tvalid,
 input  [31:0]  				c2s0_axis_tuser,
 output [0:0]             		c2s0_axis_tready,
 
 output [C_DATA_WIDTH-1:0] 		s2c1_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c1_axis_tkeep,
 output [0:0]              		s2c1_axis_tlast,
 output [0:0]              		s2c1_axis_tvalid,
 output [31:0]  				s2c1_axis_tuser,
 input  [0:0]              		s2c1_axis_tready,
                           	                        
 input  [C_DATA_WIDTH-1:0]  	c2s1_axis_tdata,    
 input  [KEEP_WIDTH-1:0]  		c2s1_axis_tkeep,    
 input  [0:0]               	c2s1_axis_tlast,    
 input  [0:0]               	c2s1_axis_tvalid,   
 input  [31:0]  				c2s1_axis_tuser,    
 output [0:0]             		c2s1_axis_tready,       
   
 output [C_DATA_WIDTH-1:0] 		s2c2_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c2_axis_tkeep,
 output [0:0]              		s2c2_axis_tlast,
 output [0:0]              		s2c2_axis_tvalid,
 output [31:0]  				s2c2_axis_tuser,
 input  [0:0]              		s2c2_axis_tready,
                           	                        
 input  [C_DATA_WIDTH-1:0]  	c2s2_axis_tdata,    
 input  [KEEP_WIDTH-1:0]  		c2s2_axis_tkeep,    
 input  [0:0]               	c2s2_axis_tlast,    
 input  [0:0]               	c2s2_axis_tvalid,   
 input  [31:0]  				c2s2_axis_tuser,    
 output [0:0]             		c2s2_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c3_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c3_axis_tkeep,
 output [0:0]              	s2c3_axis_tlast,
 output [0:0]              	s2c3_axis_tvalid,
 output [31:0]  				s2c3_axis_tuser,
 input  [0:0]              	s2c3_axis_tready,
                           	                        
 input  [C_DATA_WIDTH-1:0]  	c2s3_axis_tdata,    
 input  [KEEP_WIDTH-1:0]  		c2s3_axis_tkeep,    
 input  [0:0]               	c2s3_axis_tlast,    
 input  [0:0]               	c2s3_axis_tvalid,   
 input  [31:0]  				c2s3_axis_tuser,    
 output [0:0]             		c2s3_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c4_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c4_axis_tkeep,
 output [0:0]              	s2c4_axis_tlast,
 output [0:0]              	s2c4_axis_tvalid,
 output [31:0]  				s2c4_axis_tuser,
 input  [0:0]              	s2c4_axis_tready,
                           	                        
 input  [C_DATA_WIDTH-1:0]  	c2s4_axis_tdata,    
 input  [KEEP_WIDTH-1:0]  		c2s4_axis_tkeep,    
 input  [0:0]               	c2s4_axis_tlast,    
 input  [0:0]               	c2s4_axis_tvalid,   
 input  [31:0]  				c2s4_axis_tuser,    
 output [0:0]             		c2s4_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c5_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c5_axis_tkeep,
 output [0:0]              	s2c5_axis_tlast,
 output [0:0]              	s2c5_axis_tvalid,
 output [31:0]  				s2c5_axis_tuser,
 input  [0:0]              	s2c5_axis_tready,
                           	                        
 input  [C_DATA_WIDTH-1:0]  	c2s5_axis_tdata,    
 input  [KEEP_WIDTH-1:0]  		c2s5_axis_tkeep,    
 input  [0:0]               	c2s5_axis_tlast,    
 input  [0:0]               	c2s5_axis_tvalid,
 input  [31:0]  				c2s5_axis_tuser,    
 output [0:0]             		c2s5_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c6_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c6_axis_tkeep,
 output [0:0]              	s2c6_axis_tlast,
 output [0:0]              	s2c6_axis_tvalid,
 output [31:0]  				s2c6_axis_tuser,
 input  [0:0]              	s2c6_axis_tready,
                           	                        
 input  [C_DATA_WIDTH-1:0]  	c2s6_axis_tdata,    
 input  [KEEP_WIDTH-1:0]  		c2s6_axis_tkeep,    
 input  [0:0]               	c2s6_axis_tlast,    
 input  [0:0]               	c2s6_axis_tvalid,   
 input  [31:0]  				c2s6_axis_tuser,    
 output [0:0]             		c2s6_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c7_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c7_axis_tkeep,
 output [0:0]              	s2c7_axis_tlast,
 output [0:0]              	s2c7_axis_tvalid,
 output [31:0]  				s2c7_axis_tuser,
 input  [0:0]              	s2c7_axis_tready,
                           	                        
 input  [C_DATA_WIDTH-1:0]  	c2s7_axis_tdata,    
 input  [KEEP_WIDTH-1:0]  		c2s7_axis_tkeep,    
 input  [0:0]               	c2s7_axis_tlast,    
 input  [0:0]               	c2s7_axis_tvalid,   
 input  [31:0]  				c2s7_axis_tuser,    
 output [0:0]             		c2s7_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c8_axis_tdata,
 output [KEEP_WIDTH-1:0]  		s2c8_axis_tkeep,
 output [0:0]              	s2c8_axis_tlast,
 output [0:0]              	s2c8_axis_tvalid,
 output [31:0]  				s2c8_axis_tuser,
 input  [0:0]              	s2c8_axis_tready,
                           	                        
 input  [C_DATA_WIDTH-1:0]  	c2s8_axis_tdata,    
 input  [KEEP_WIDTH-1:0]  		c2s8_axis_tkeep,    
 input  [0:0]               	c2s8_axis_tlast,    
 input  [0:0]               	c2s8_axis_tvalid,   
 input  [31:0]  				c2s8_axis_tuser,    
 output [0:0]             		c2s8_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c9_axis_tdata,    
 output [KEEP_WIDTH-1:0]  		s2c9_axis_tkeep,    
 output [0:0]              	s2c9_axis_tlast,    
 output [0:0]              	s2c9_axis_tvalid,   
 output [31:0]  				s2c9_axis_tuser,            
 input  [0:0]              	s2c9_axis_tready,   
                           	                           
 input  [C_DATA_WIDTH-1:0]  	c2s9_axis_tdata,        
 input  [KEEP_WIDTH-1:0]  		c2s9_axis_tkeep,      
 input  [0:0]               	c2s9_axis_tlast,     
 input  [0:0]               	c2s9_axis_tvalid,   
 input  [31:0]  				c2s9_axis_tuser,              
 output [0:0]             		c2s9_axis_tready,         

 output [C_DATA_WIDTH-1:0] 	s2c10_axis_tdata,    
 output [KEEP_WIDTH-1:0]  		s2c10_axis_tkeep,    
 output [0:0]              	s2c10_axis_tlast,    
 output [0:0]              	s2c10_axis_tvalid,   
 output [31:0]  				s2c10_axis_tuser,            
 input  [0:0]              	s2c10_axis_tready,   
                           	                           
 input  [C_DATA_WIDTH-1:0]  	c2s10_axis_tdata,        
 input  [KEEP_WIDTH-1:0]  		c2s10_axis_tkeep,      
 input  [0:0]               	c2s10_axis_tlast,     
 input  [0:0]               	c2s10_axis_tvalid,   
 input  [31:0]  				c2s10_axis_tuser,              
 output [0:0]             		c2s10_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c11_axis_tdata,    
 output [KEEP_WIDTH-1:0]  		s2c11_axis_tkeep,    
 output [0:0]              	s2c11_axis_tlast,    
 output [0:0]              	s2c11_axis_tvalid,   
 output [31:0]  				s2c11_axis_tuser,            
 input  [0:0]              	s2c11_axis_tready,   
                           	                           
 input  [C_DATA_WIDTH-1:0]  	c2s11_axis_tdata,        
 input  [KEEP_WIDTH-1:0]  		c2s11_axis_tkeep,      
 input  [0:0]               	c2s11_axis_tlast,     
 input  [0:0]               	c2s11_axis_tvalid,   
 input  [31:0]  				c2s11_axis_tuser,              
 output [0:0]             		c2s11_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c12_axis_tdata,    
 output [KEEP_WIDTH-1:0]  		s2c12_axis_tkeep,    
 output [0:0]              	s2c12_axis_tlast,    
 output [0:0]              	s2c12_axis_tvalid,   
 output [31:0]  				s2c12_axis_tuser,            
 input  [0:0]              	s2c12_axis_tready,   
                           	                           
 input  [C_DATA_WIDTH-1:0]  	c2s12_axis_tdata,        
 input  [KEEP_WIDTH-1:0]  		c2s12_axis_tkeep,      
 input  [0:0]               	c2s12_axis_tlast,     
 input  [0:0]               	c2s12_axis_tvalid,   
 input  [31:0]  				c2s12_axis_tuser,              
 output [0:0]             		c2s12_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c13_axis_tdata,    
 output [KEEP_WIDTH-1:0]  		s2c13_axis_tkeep,    
 output [0:0]              	s2c13_axis_tlast,    
 output [0:0]              	s2c13_axis_tvalid,   
 output [31:0]  				s2c13_axis_tuser,            
 input  [0:0]              	s2c13_axis_tready,   
                           	                           
 input  [C_DATA_WIDTH-1:0]  	c2s13_axis_tdata,        
 input  [KEEP_WIDTH-1:0]  		c2s13_axis_tkeep,      
 input  [0:0]               	c2s13_axis_tlast,     
 input  [0:0]               	c2s13_axis_tvalid,   
 input  [31:0]  				c2s13_axis_tuser,              
 output [0:0]             		c2s13_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c14_axis_tdata,    
 output [KEEP_WIDTH-1:0]  		s2c14_axis_tkeep,    
 output [0:0]              	s2c14_axis_tlast,    
 output [0:0]              	s2c14_axis_tvalid,   
 output [31:0]  				s2c14_axis_tuser,            
 input  [0:0]              	s2c14_axis_tready,   
                           	                           
 input  [C_DATA_WIDTH-1:0]  	c2s14_axis_tdata,        
 input  [KEEP_WIDTH-1:0]  		c2s14_axis_tkeep,      
 input  [0:0]               	c2s14_axis_tlast,     
 input  [0:0]               	c2s14_axis_tvalid,   
 input  [31:0]  				c2s14_axis_tuser,              
 output [0:0]             		c2s14_axis_tready,       
 
 output [C_DATA_WIDTH-1:0] 	s2c15_axis_tdata,    
 output [KEEP_WIDTH-1:0]  		s2c15_axis_tkeep,    
 output [0:0]              	s2c15_axis_tlast,    
 output [0:0]              	s2c15_axis_tvalid,   
 output [31:0]  				s2c15_axis_tuser,            
 input  [0:0]              	s2c15_axis_tready,   
                           	                           
 input  [C_DATA_WIDTH-1:0]  	c2s15_axis_tdata,        
 input  [KEEP_WIDTH-1:0]  		c2s15_axis_tkeep,      
 input  [0:0]               	c2s15_axis_tlast,     
 input  [0:0]               	c2s15_axis_tvalid,   
 input  [31:0]  				c2s15_axis_tuser,              
 output [0:0]             		c2s15_axis_tready        
                                                 
 );
 

 
 localparam 	MAX_NUM_OF_INTERRUPTS	= NUM_OF_INTERRUPTS;
 localparam 	MAX_NUM_OF_S2C_CHANNELS	= NUM_OF_S2C_CHAN;
 localparam 	MAX_NUM_OF_C2S_CHANNELS	= NUM_OF_C2S_CHAN;
 localparam 	DATAE 	= 32'h03_0A_07e6;
 localparam 	VER_MJ 	= 16'h0005;
 localparam 	VER_MN 	= 16'h0001;
 localparam 	NUM_OF_BAR0_AXI_SLAVE = 1 + MAX_NUM_OF_C2S_CHANNELS + MAX_NUM_OF_S2C_CHANNELS + 2;  
 localparam 	NUM_OF_CHANNELS = MAX_NUM_OF_C2S_CHANNELS + MAX_NUM_OF_S2C_CHANNELS;  
 										

  wire [MAX_NUM_OF_S2C_CHANNELS*C_DATA_WIDTH-1:0] s2c_axis_tdata;
  wire [MAX_NUM_OF_S2C_CHANNELS*KEEP_WIDTH-1:0]   s2c_axis_tkeep;
  wire [MAX_NUM_OF_S2C_CHANNELS-1:0]              s2c_axis_tlast;
  wire [MAX_NUM_OF_S2C_CHANNELS-1:0]              s2c_axis_tvalid;
  wire [MAX_NUM_OF_S2C_CHANNELS*33-1:0]  		  s2c_axis_tuser;
  wire [MAX_NUM_OF_S2C_CHANNELS-1:0]              s2c_axis_tready;

  wire [MAX_NUM_OF_C2S_CHANNELS*C_DATA_WIDTH-1:0]  c2s_axis_tdata;
  wire [MAX_NUM_OF_C2S_CHANNELS*KEEP_WIDTH-1:0]    c2s_axis_tkeep;
  wire [MAX_NUM_OF_C2S_CHANNELS-1:0]               c2s_axis_tlast;
  wire [MAX_NUM_OF_C2S_CHANNELS-1:0]               c2s_axis_tvalid;
  wire [MAX_NUM_OF_C2S_CHANNELS*33-1:0]  		   c2s_axis_tuser;
  wire [MAX_NUM_OF_C2S_CHANNELS-1:0]               c2s_axis_tready;
 
  
  wire                				payload_len;
  wire   [2:0]    					req_bar_id;                    
  wire   [5:0]						req_bar_aperture;
  wire   [AXI_ADDR_WIDTH-1:0]    	rd_addr;
  wire   [3:0]     				 	rd_be;
  wire 	 [5:0]						rd_req;
 


  wire      [AXI_ADDR_WIDTH-1:0]  wr_addr;
  wire      [C_DATA_WIDTH/8-1:0]     wr_be;
  wire      [C_DATA_WIDTH-1:0]    	 wr_data;
  wire      [5:0]     				 wr_en;
  wire 								 wr_last;
  
  wire               				 wr_busy;
  reg       [31:0]    				 rd_data;
  reg 								 rd_valid;
 
  wire [5:0] 	is_bar;  
  reg [12:0] 	max_read_request_size; 
  reg [12:0] 	max_payload_size;
  wire [15:0] 	completer_id;
  
  
  wire 			bar0_data_valid;
  wire [31:0] 	bar_0_rd_data;
  wire 			bar2_data_valid;
  wire [31:0] 	bar_2_rd_data;
  
  
wire [MAX_NUM_OF_INTERRUPTS+MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1:0]	int_req_internal;
wire [MAX_NUM_OF_INTERRUPTS+MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1:0]	int_ack_internal;
wire int_req_fifo_full;   


//MRdReq mux <--> sg connection wires	                                                                        
wire [MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1:0]     	 mrd_req_req;	   
wire [MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1:0]     	 mrd_req_ack; 	  
wire [13*(MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS)-1:0]   mrd_req_len;	 
wire [64*(MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS)-1:0]   mrd_addr;	 	  
wire [8*(MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS)-1:0]    mrd_tag;		    


//MRdReq mux <--> tx_dispatcher connection wires
wire 		mrd_tx_req;
wire 		mrd_tx_done;
wire [7:0]  mrd_tx_tag;
wire [12:0] mrd_tx_len;
wire [63:0] mrd_tx_addr;

//WrReq mux <--> sg connection wires	
wire [MAX_NUM_OF_C2S_CHANNELS-1:0]     c2s_stop;                                                                                                                                                
wire [MAX_NUM_OF_C2S_CHANNELS-1:0]     mwr_ack;			     
wire [MAX_NUM_OF_C2S_CHANNELS-1:0]     mwr_req;			     
wire [13*MAX_NUM_OF_C2S_CHANNELS-1:0]  mwr_burst_len;	 
wire [64*MAX_NUM_OF_C2S_CHANNELS-1:0]  mwr_addr;		     
wire [8*MAX_NUM_OF_C2S_CHANNELS-1:0]   mwr_tag;			     
wire [MAX_NUM_OF_C2S_CHANNELS-1:0]     mwr_wr_active;	 
wire [MAX_NUM_OF_C2S_CHANNELS-1:0]     mwr_read_req; 	 
wire [MAX_NUM_OF_C2S_CHANNELS*C_DATA_WIDTH-1:0]  mwr_read_data; 	


//WrReq mux <--> tx_dispatcher connection wires
wire [C_DATA_WIDTH-1:0] mwr_tx_data; 
wire mwr_tx_req; 		
wire mwr_tx_data_req;		
wire mwr_tx_ack;			
wire mwr_tx_done;	        
wire [12:0] mwr_tx_burst_len; 
wire [63:0] mwr_tx_addr; 
wire [7:0]  mwr_tx_tag; 

//status mux <--> tx_dispatcher connection wires
wire 		status_tx_req;
wire 		status_tx_done;
wire [63:0] status_tx_qword;
wire [63:0] status_tx_addr;

wire 		rearbit_sig;


//status mux <--> sg  connecting wires
wire [MAX_NUM_OF_INTERRUPTS+MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1 : 0]     	status_ack;		    
wire [MAX_NUM_OF_INTERRUPTS+MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1 : 0]     	status_req;		    
wire [64*(MAX_NUM_OF_INTERRUPTS+MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS)-1 : 0] status_qword;	
wire [64*(MAX_NUM_OF_INTERRUPTS+MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS)-1 : 0] status_addr;	 

wire [MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1 : 0]      	tag_request;
wire [MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1 : 0]     	tag_valid; 
wire [(MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS)*32-1 : 0]  	context;	
wire [64*(MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS)-1 : 0]	bm_sys_addr;
wire [7 : 0]                        						tag;		

wire [C_DATA_WIDTH-1:0]                             bm_data;		   
wire [C_DATA_WIDTH/8-1:0]                           bm_be;       
wire [MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1:0]  bm_rx_done;	 
wire [MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1:0]  bm_rx_active;
wire [MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1:0]  bm_rx_rdy;	  
wire [31:0]                                         bm_context;	 
  
    
  
  	//------------------------------------------------------
  	//--------------- AXI4 BAR 0 inteface 
  	//------------------------------------------------------
     wire [AXI_ID_WIDTH-1:0]    bar0_m_axi_awid;
     wire [AXI_ADDR_WIDTH-1:0]  bar0_m_axi_awaddr;
     wire [7:0]                 bar0_m_axi_awlen;
     wire [2:0]                 bar0_m_axi_awsize;
     wire [1:0]                 bar0_m_axi_awburst;
     wire                       bar0_m_axi_awlock;
     wire [3:0]                 bar0_m_axi_awcache;
     wire [2:0]                 bar0_m_axi_awprot;
     wire                       bar0_m_axi_awvalid;
     wire                       bar0_m_axi_awready;
     wire [AXI_DATA_WIDTH-1:0]  bar0_m_axi_wdata;
     wire [AXI_STRB_WIDTH-1:0]  bar0_m_axi_wstrb;
     wire                       bar0_m_axi_wlast;
     wire                       bar0_m_axi_wvalid;
     wire                       bar0_m_axi_wready;
     wire [AXI_ID_WIDTH-1:0]    bar0_m_axi_bid;
     wire [1:0]                 bar0_m_axi_bresp;
     wire                       bar0_m_axi_bvalid;
     wire                       bar0_m_axi_bready;
    
     wire [AXI_ID_WIDTH-1:0]    bar0_m_axi_arid;
     wire [AXI_ADDR_WIDTH-1:0]  bar0_m_axi_araddr;
     wire [7:0]                 bar0_m_axi_arlen;
     wire [2:0]                 bar0_m_axi_arsize;
     wire [1:0]                 bar0_m_axi_arburst;
     wire                       bar0_m_axi_arlock;
     wire [3:0]                 bar0_m_axi_arcache;
     wire [2:0]                 bar0_m_axi_arprot;
     wire                       bar0_m_axi_arvalid;
     wire                       bar0_m_axi_arready;
     wire [AXI_ID_WIDTH-1:0]    bar0_m_axi_rid;
     wire [AXI_DATA_WIDTH-1:0]  bar0_m_axi_rdata;
     wire [1:0]                 bar0_m_axi_rresp;
     wire                       bar0_m_axi_rlast;
     wire                       bar0_m_axi_rvalid;
     wire                       bar0_m_axi_rready;
  

 	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_ID_WIDTH-1:0]    bar0_s_axi_awid;   
	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_ADDR_WIDTH-1:0]  bar0_s_axi_awaddr; 
	 wire [NUM_OF_BAR0_AXI_SLAVE*8-1:0]               bar0_s_axi_awlen;  
	 wire [NUM_OF_BAR0_AXI_SLAVE*3-1:0]               bar0_s_axi_awsize; 
	 wire [NUM_OF_BAR0_AXI_SLAVE*2-1:0]               bar0_s_axi_awburst;
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_awlock; 
	 wire [NUM_OF_BAR0_AXI_SLAVE*4-1:0]               bar0_s_axi_awcache;
	 wire [NUM_OF_BAR0_AXI_SLAVE*3-1:0]               bar0_s_axi_awprot; 
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_awvalid;
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]				 bar0_s_axi_awready;
	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_DATA_WIDTH-1:0]  bar0_s_axi_wdata;  
	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_STRB_WIDTH-1:0]  bar0_s_axi_wstrb;  
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]				 bar0_s_axi_wlast;  
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]				 bar0_s_axi_wvalid; 
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]				 bar0_s_axi_wready; 
	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_ID_WIDTH-1:0]    bar0_s_axi_bid;    
	 wire [NUM_OF_BAR0_AXI_SLAVE*2-1:0]               bar0_s_axi_bresp;  
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_bvalid; 
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_bready; 
	 
	 
	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_ID_WIDTH-1:0]    bar0_s_axi_arid;   
	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_ADDR_WIDTH-1:0]  bar0_s_axi_araddr; 
	 wire [NUM_OF_BAR0_AXI_SLAVE*8-1:0]               bar0_s_axi_arlen;  
	 wire [NUM_OF_BAR0_AXI_SLAVE*3-1:0]               bar0_s_axi_arsize; 
	 wire [NUM_OF_BAR0_AXI_SLAVE*2-1:0]               bar0_s_axi_arburst;
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_arlock; 
	 wire [NUM_OF_BAR0_AXI_SLAVE*4-1:0]               bar0_s_axi_arcache;
	 wire [NUM_OF_BAR0_AXI_SLAVE*3-1:0]               bar0_s_axi_arprot; 
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_arvalid;
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_arready;
	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_ID_WIDTH-1:0]    bar0_s_axi_rid;    
	 wire [NUM_OF_BAR0_AXI_SLAVE*AXI_DATA_WIDTH-1:0]  bar0_s_axi_rdata;  
	 wire [NUM_OF_BAR0_AXI_SLAVE*2-1:0]               bar0_s_axi_rresp;  
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_rlast;  
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_rvalid; 
	 wire [NUM_OF_BAR0_AXI_SLAVE-1:0]                 bar0_s_axi_rready; 

  

  //assign m_axi_resetn = ~usr_rst;
  //assign m_axi_clk = usr_clk;
  
  
//------------------------------------------------------------------------------------------------------------------//
assign  is_bar[0] = req_bar_id == 3'b000 ? 1'b1 : 1'b0;
assign  is_bar[1] = req_bar_id == 3'b001 ? 1'b1 : 1'b0;
assign  is_bar[2] = req_bar_id == 3'b010 ? 1'b1 : 1'b0;
assign  is_bar[3] = req_bar_id == 3'b011 ? 1'b1 : 1'b0;
assign  is_bar[4] = req_bar_id == 3'b100 ? 1'b1 : 1'b0;
assign  is_bar[5] = req_bar_id == 3'b101 ? 1'b1 : 1'b0;

assign wr_busy	= 1'b0;                                                                       


 completer_interface #(                                                                                                          
   .C_DATA_WIDTH               		(C_DATA_WIDTH),                                                           
   .AXISTEN_IF_CC_ALIGNMENT_MODE   	("FALSE"),                                                          
   .AXISTEN_IF_CC_PARITY_CHECK     	(0),                                                          
   .AXI4_CQ_TUSER_WIDTH            	(AXI4_CQ_TUSER_WIDTH),
   
   .MAPPED_ADDR_WIDTH                (AXI_ADDR_WIDTH)                                                                                                               
 )
 completer_interface_i
 (                                                                                                                     
   .user_clk							(usr_clk),                                                                           
   .reset_n							(~usr_rst),                                                                            
   .user_lnk_up						(user_lnk_up),                                                                        
   .s_axis_cc_tdata					(s_axis_cc_tdata),                                                                    
   .s_axis_cc_tkeep					(s_axis_cc_tkeep),                                                                    
   .s_axis_cc_tlast					(s_axis_cc_tlast),                                                                    
   .s_axis_cc_tvalid					(s_axis_cc_tvalid),                                                                   
   .s_axis_cc_tuser					(s_axis_cc_tuser),                                                                    
   .s_axis_cc_tready					(s_axis_cc_tready),                                                                   
   .m_axis_cq_tdata					(m_axis_cq_tdata),                                                                    
   .m_axis_cq_tlast					(m_axis_cq_tlast),                                                                    
   .m_axis_cq_tvalid					(m_axis_cq_tvalid),                                                                   
   .m_axis_cq_tuser					(m_axis_cq_tuser),                                                                    
   .m_axis_cq_tkeep					(m_axis_cq_tkeep),                                                                    
   .pcie_cq_np_req_count				(pcie_cq_np_req_count),                                                               
   .m_axis_cq_tready					(m_axis_cq_tready),                                                                   
   .pcie_cq_np_req					(pcie_cq_np_req),                                                                     
   .payload_len						(payload_len),
   .req_bar_id						(req_bar_id),                    
   .req_bar_aperture					(req_bar_aperture),
   .rd_addr							(rd_addr),
   .rd_be							(rd_be),
   .rd_req							(rd_req),
   .rd_data							(rd_data),
   .rd_valid							(rd_valid),
   .wr_addr							(wr_addr),
   .wr_be							(wr_be),
   .wr_data							(wr_data),
   .wr_en							(wr_en),
   .wr_last							(wr_last),
   .wr_busy      					(wr_busy)
                                                                                                                       
 ); 

assign completer_id = {cfg_ds_bus_number , 8'h00};

 always @ ( cfg_max_payload ) 
 begin
 	case(cfg_max_payload) 
	 3'b000: max_payload_size =  'b0000010000000; // 128
	 3'b001: max_payload_size =  'b0000100000000; // 256
	 3'b010: max_payload_size =  'b0001000000000; // 512
	 3'b011: max_payload_size =  'b0010000000000; // 1024
	 3'b100: max_payload_size =  'b0100000000000; // 2048
	 3'b101: max_payload_size =  'b1000000000000; // 4096
	 default: max_payload_size = 'b0000000000000;
	endcase
 end 

 always @ ( cfg_max_read_req ) 
 begin			
 	case(cfg_max_read_req) 
	 3'b000: max_read_request_size =  'b0000010000000; // 128
	 3'b001: max_read_request_size =  'b0000100000000; // 256
	 3'b010: max_read_request_size =  'b0001000000000; // 512
	 3'b011: max_read_request_size =  'b0010000000000; // 1024
	 3'b100: max_read_request_size =  'b0100000000000; // 2048
	 3'b101: max_read_request_size =  'b1000000000000; // 4096
	 default: max_read_request_size = 'b0000000000000;
 endcase
 end




  assign cfg_mgmt_addr                       = 10'h0;                // Zero out CFG MGMT 19-bit address port
  assign cfg_mgmt_write                      = 1'b0;                 // Do not write CFG space
  assign cfg_mgmt_write_data                 = 32'h0;                // Zero out CFG MGMT input data bus
  assign cfg_mgmt_byte_enable                = 4'h0;                 // Zero out CFG MGMT byte enables
  assign cfg_mgmt_read                       = 1'b0;                 // Do not read CFG space
  assign cfg_dsn                             = {`PCI_EXP_EP_DSN_2, `PCI_EXP_EP_DSN_1};  // Assign the input DSN
  

  assign cfg_err_cor_in                      = 1'b0;                 // Never report Correctable Error
  assign cfg_err_uncor_in                    = 1'b0;                 // Never report UnCorrectable Error


  assign cfg_link_training_enable            = 1'b1;                 // Always enable LTSSM to bring up the Link

  assign cfg_config_space_enable             = 1'b1;
  assign cfg_req_pm_transition_l23_ready     = 1'b0;

  assign cfg_hot_reset_out                   = 1'b0;
  assign cfg_ds_port_number                  = 8'h0;
  assign cfg_ds_bus_number                   = 8'h0;
  assign cfg_ds_device_number                = 5'h0;
  assign cfg_ds_function_number              = 3'h0;
  assign cfg_interrupt_int		    		= 3'b000;
  assign cfg_interrupt_pending               = 2'h0;
  assign cfg_interrupt_msi_select            = 2'b00;
  assign cfg_interrupt_msi_pending_status    = 64'h0;
  assign cfg_interrupt_msi_pending_status_function_num = 2'b00;
  assign cfg_interrupt_msi_pending_status_data_enable = 1'b0;

  
  assign cfg_interrupt_msi_attr              = 3'h0;
  assign cfg_interrupt_msi_tph_present       = 1'b0;
  assign cfg_interrupt_msi_tph_type          = 2'h0;
  assign cfg_interrupt_msi_tph_st_tag        = 8'h0;
  assign cfg_interrupt_msi_function_number   = 8'h0;
  
  
  reg [1:0]  cfg_flr_done_reg0;
  reg [5:0]  cfg_vf_flr_done_reg0;
  reg [1:0]  cfg_flr_done_reg1;
  reg [5:0]  cfg_vf_flr_done_reg1;


always @(posedge usr_clk)
  begin
   if (usr_clk) begin
      cfg_flr_done_reg0       <= 2'b0;
      cfg_vf_flr_done_reg0    <= 6'b0;
      cfg_flr_done_reg1       <= 2'b0;
      cfg_vf_flr_done_reg1    <= 6'b0;
    end
   else begin
      cfg_flr_done_reg0       <= cfg_flr_in_process;
      cfg_vf_flr_done_reg0    <= cfg_vf_flr_in_process;
      cfg_flr_done_reg1       <= cfg_flr_done_reg0;
      cfg_vf_flr_done_reg1    <= cfg_vf_flr_done_reg0;
    end
  end


	assign cfg_flr_done[0] = ~cfg_flr_done_reg1[0] && cfg_flr_done_reg0[0]; assign cfg_flr_done[1] = ~cfg_flr_done_reg1[1] && cfg_flr_done_reg0[1];

	assign cfg_vf_flr_done = ~cfg_vf_flr_done_reg1[0] && cfg_vf_flr_done_reg0[0]; 

  // Register and cycle through the virtual fucntion function level reset.
  // This counter will just loop over the virtual functions. Ths should be
  // repliced by user logic to perform the actual function level reset as
  // needed.
  reg     [7:0]     cfg_vf_flr_func_num_reg;
  always @(posedge usr_clk) begin
    if(usr_clk) begin
      cfg_vf_flr_func_num_reg <= 8'd0;
    end else begin
      cfg_vf_flr_func_num_reg <= cfg_vf_flr_func_num_reg + 1'b1;
    end
  end
  assign cfg_vf_flr_func_num = cfg_vf_flr_func_num_reg;
  

  assign cfg_interrupt_msix_int = 1'b0;
  assign cfg_interrupt_msix_address = 64'h0000000000000000;
  assign cfg_interrupt_msix_data = 32'h00000000;
  
  
  assign cfg_msg_transmit = 1'b0;
  assign cfg_msg_transmit_type = 3'b00;
  assign cfg_msg_transmit_data = 32'h00000000;

  assign cfg_fc_sel = 3'b00;
  
  assign cfg_hot_reset_in = 1'b0;
      
  
	turn_off_ctrl to_ctrl  
	(
		.clk                                     ( usr_clk ),
		.rst_n                                   ( !ust_rst ),
		
		.req_compl                               ( 1'b0 ),
		.compl_done                              ( 1'b0 ),
		
		.cfg_power_state_change_interrupt        ( cfg_power_state_change_interrupt ),
		.cfg_power_state_change_ack              (cfg_power_state_change_ack )
	);
  
////////////////////////////// axi4 masters instantiation ////////////////////////////////////  


 	axi_if #
 	(
 	    .AXI_DATA_WIDTH 	(32),
 	    .AXI_ADDR_WIDTH 	(AXI_ADDR_WIDTH)
 	)
 	m_axi_if_bar_0
 	(
 	    .m_axi_clk			( usr_clk ),
 	    .m_axi_rstn			(!usr_rst ),
 	
 		.m_axi_awid       	(bar0_m_axi_awid),
 		.m_axi_awaddr     	(bar0_m_axi_awaddr),
 		.m_axi_awlen      	(bar0_m_axi_awlen),
 		.m_axi_awsize     	(bar0_m_axi_awsize),
 		.m_axi_awburst    	(bar0_m_axi_awburst),
 		.m_axi_awlock     	(bar0_m_axi_awlock),
 		.m_axi_awcache    	(bar0_m_axi_awcache),
 		.m_axi_awprot     	(bar0_m_axi_awprot),
 		.m_axi_awvalid    	(bar0_m_axi_awvalid),
 		.m_axi_awready    	(bar0_m_axi_awready),
 		.m_axi_wdata      	(bar0_m_axi_wdata),
 		.m_axi_wstrb      	(bar0_m_axi_wstrb),
 		.m_axi_wlast      	(bar0_m_axi_wlast),
 		.m_axi_wvalid     	(bar0_m_axi_wvalid),
 		.m_axi_wready     	(bar0_m_axi_wready),
 		.m_axi_bid        	(bar0_m_axi_bid),
 		.m_axi_bresp      	(bar0_m_axi_bresp),
 		.m_axi_bvalid     	(bar0_m_axi_bvalid),
 		.m_axi_bready     	(bar0_m_axi_bready),
 		                  	
 		.m_axi_arid       	(bar0_m_axi_arid),
 		.m_axi_araddr     	(bar0_m_axi_araddr),
 		.m_axi_arlen      	(bar0_m_axi_arlen),
 		.m_axi_arsize     	(bar0_m_axi_arsize),
 		.m_axi_arburst    	(bar0_m_axi_arburst),
 		.m_axi_arlock     	(bar0_m_axi_arlock),
 		.m_axi_arcache    	(bar0_m_axi_arcache),
 		.m_axi_arprot     	(bar0_m_axi_arprot),
 		.m_axi_arvalid    	(bar0_m_axi_arvalid),
 		.m_axi_arready    	(bar0_m_axi_arready),
 		.m_axi_rid        	(bar0_m_axi_rid),
 		.m_axi_rdata      	(bar0_m_axi_rdata),
 		.m_axi_rresp      	(bar0_m_axi_rresp),
 		.m_axi_rlast      	(bar0_m_axi_rlast),
 		.m_axi_rvalid     	(bar0_m_axi_rvalid),
 		.m_axi_rready     	(bar0_m_axi_rready),
 	    
 	    .rd_req				(is_bar[0] && rd_req),	
 	    .rd_req_ready		(),
 	    .rd_burst_len		(20'b00000000000000000001),
 	    .rd_addr			(rd_addr),
 	    .rd_data_valid		(bar0_data_valid),
 	    .rd_data			(bar_0_rd_data),
 	    
 	    .wr_req 			(is_bar[0] && wr_en),
 	    .wr_done			(),
 	    .wr_addr			(wr_addr),
 	    .wr_data			(wr_data[31:0])
 	    
 	);
 	
 	
 	axi_if #
 	(
 	    .AXI_DATA_WIDTH 	(32),
 	    .AXI_ADDR_WIDTH 	(AXI_ADDR_WIDTH)
 	)
 	m_axi_if_bar_2
 	(
 	    .m_axi_clk			( usr_clk ),
 	    .m_axi_rstn			(!usr_rst ),
 	
 		.m_axi_awid       	(bar2_m_axi_awid),
 		.m_axi_awaddr     	(bar2_m_axi_awaddr),
 		.m_axi_awlen      	(bar2_m_axi_awlen),
 		.m_axi_awsize     	(bar2_m_axi_awsize),
 		.m_axi_awburst    	(bar2_m_axi_awburst),
 		.m_axi_awlock     	(bar2_m_axi_awlock),
 		.m_axi_awcache    	(bar2_m_axi_awcache),
 		.m_axi_awprot     	(bar2_m_axi_awprot),
 		.m_axi_awvalid    	(bar2_m_axi_awvalid),
 		.m_axi_awready    	(bar2_m_axi_awready),
 		.m_axi_wdata      	(bar2_m_axi_wdata),
 		.m_axi_wstrb      	(bar2_m_axi_wstrb),
 		.m_axi_wlast      	(bar2_m_axi_wlast),
 		.m_axi_wvalid     	(bar2_m_axi_wvalid),
 		.m_axi_wready     	(bar2_m_axi_wready),
 		.m_axi_bid        	(bar2_m_axi_bid),
 		.m_axi_bresp      	(bar2_m_axi_bresp),
 		.m_axi_bvalid     	(bar2_m_axi_bvalid),
 		.m_axi_bready     	(bar2_m_axi_bready),
 		                  	
 		.m_axi_arid       	(bar2_m_axi_arid),
 		.m_axi_araddr     	(bar2_m_axi_araddr),
 		.m_axi_arlen      	(bar2_m_axi_arlen),
 		.m_axi_arsize     	(bar2_m_axi_arsize),
 		.m_axi_arburst    	(bar2_m_axi_arburst),
 		.m_axi_arlock     	(bar2_m_axi_arlock),
 		.m_axi_arcache    	(bar2_m_axi_arcache),
 		.m_axi_arprot     	(bar2_m_axi_arprot),
 		.m_axi_arvalid    	(bar2_m_axi_arvalid),
 		.m_axi_arready    	(bar2_m_axi_arready),
 		.m_axi_rid        	(bar2_m_axi_rid),
 		.m_axi_rdata      	(bar2_m_axi_rdata),
 		.m_axi_rresp      	(bar2_m_axi_rresp),
 		.m_axi_rlast      	(bar2_m_axi_rlast),
 		.m_axi_rvalid     	(bar2_m_axi_rvalid),
 		.m_axi_rready     	(bar2_m_axi_rready),
 	    
 	    .rd_req				(is_bar[2] && rd_req),	
 	    .rd_req_ready		(),
 	    .rd_burst_len		(20'b00000000000000000001),
 	    .rd_addr			(rd_addr),
 	    .rd_data_valid		(bar2_data_valid),
 	    .rd_data			(bar_2_rd_data),
 	    
 	    .wr_req 			(is_bar[2] && wr_en),
 	    .wr_done			(),
 	    .wr_addr			(wr_addr),
 	    .wr_data			(wr_data[31:0])
 	    
 	);
	
	



msi_controller #                                                                                                                                                                   
(                                                                                                                                                                                                  
	.NUM_OF_INTERRUPTS (MAX_NUM_OF_INTERRUPTS+MAX_NUM_OF_S2C_CHANNELS+MAX_NUM_OF_C2S_CHANNELS),                        
  	.AXI_ID_WIDTH      (AXI_ID_WIDTH),                                                                             
  	.AXI_ADDR_WIDTH    (AXI_ADDR_WIDTH),                                                                           
  	.AXI_DATA_WIDTH    (AXI_DATA_WIDTH),                                                                           
  	.AXI_STRB_WIDTH    (AXI_STRB_WIDTH)                                                                            
)                                                                                                                  
msi_controller_i                                                                                                   
(                                                                                                                  
   	.reset_n_i 	(~usr_rst),                                                                                        
   	.clk 		(usr_clk),                                                                                            
                                                                                                                   
   	.int_req 	(int_req_internal),                                                                                
   	.int_ack 	(int_ack_internal),                                                                                
   	.fifo_full 	(int_req_fifo_full),                                                                               
   	                                                                                                               
                                                                                                                   
  	.cfg_interrupt_msi_enable  (cfg_interrupt_msi_enable),				                                                    
  	.cfg_interrupt_msi_int     (cfg_interrupt_msi_int), 				                         		                      
  	.cfg_interrupt_msi_sent    (cfg_interrupt_msi_sent),				                                                      
  	.cfg_interrupt_msi_fail    (cfg_interrupt_msi_fail),                                                           
  	                                                                                                               
	.s_axil_awaddr   	(bar0_s_axi_awaddr[2*AXI_ADDR_WIDTH-1:1*AXI_ADDR_WIDTH]),                                  
	.s_axil_awprot  	(bar0_s_axi_awprot[2*3-1:1*3]),                                                            
	.s_axil_awvalid  	(bar0_s_axi_awvalid[1]),               	        	                                         
	.s_axil_awready 	(bar0_s_axi_awready[1]),				            	                                                  
	.s_axil_wdata    	(bar0_s_axi_wdata[2*AXI_DATA_WIDTH-1:1*AXI_DATA_WIDTH]),                                   
	.s_axil_wstrb    	(bar0_s_axi_wstrb[2*AXI_STRB_WIDTH-1:1*AXI_STRB_WIDTH]),                                   
	.s_axil_wvalid  	(bar0_s_axi_wvalid[1]),				                  	                                             
	.s_axil_wready  	(bar0_s_axi_wready[1]),				                  	                                             
	.s_axil_bresp   	(bar0_s_axi_bresp[2*2-1:1*2]),                                                                        
	.s_axil_bvalid  	(bar0_s_axi_bvalid[1]),            	          	                                            
	.s_axil_bready  	(bar0_s_axi_bready[1]),            	          	                                            
	.s_axil_araddr   	(bar0_s_axi_araddr[2*AXI_ADDR_WIDTH-1:1*AXI_ADDR_WIDTH]),                                  
	.s_axil_arprot  	(bar0_s_axi_arprot[2*3-1:1*3]),               	                                            
	.s_axil_arvalid 	(bar0_s_axi_arlen[1]),                                                                     
	.s_axil_arready 	(bar0_s_axi_arready[1]),          	                                                        
	.s_axil_rdata    	(bar0_s_axi_rdata[2*AXI_DATA_WIDTH-1:1*AXI_DATA_WIDTH]),                                   
	.s_axil_rresp   	(bar0_s_axi_rresp[2*2-1:1*2]),                                                             
	.s_axil_rvalid   	(bar0_s_axi_rvalid[1]),               	                                                   
	.s_axil_rready   	(bar0_s_axi_rready[1])                                                                     
);                                                                                                                 



mrd_req_mux #	
(
	.NUM_OF_SG_CHANNLES		(MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS)
)
mrd_req_mux_i
(
	
	.clk_in        	(usr_clk),
	.rstn          	(~usr_rst),  
	
	 
  
	.mrd_req_req	(mrd_req_req),	   
	.mrd_req_ack 	(mrd_req_ack),	   
	.mrd_req_len	(mrd_req_len),
	.mrd_addr	 	(mrd_addr),	  
	.mrd_tag		(mrd_tag),	   
			

	.tx_req			(mrd_tx_req), 
	.tx_done	    (mrd_tx_done),
	.tx_tag			(mrd_tx_tag), 
	.tx_len			(mrd_tx_len), 
	.tx_addr		(mrd_tx_addr)
		
		      	    	
);


mwr_req_mux #	
(
	.NUM_OF_FAST_SG_IN_CHANNLES	   (MAX_NUM_OF_C2S_CHANNELS),
	.PCIE_CORE_DATA_WIDTH          (C_DATA_WIDTH)
)
mwr_req_mux_i
(
	.clk_in        	(usr_clk),
	.rstn          	(~usr_rst),   
	
	.stop			(c2s_stop),	
	
	.mwr_ack		(mwr_ack),			      
	.mwr_req		(mwr_req),			      
	.mwr_burst_len	(mwr_burst_len),	  
	.mwr_addr		(mwr_addr),		      
	.mwr_tag		(mwr_tag),			      
	.mwr_wr_active	(mwr_wr_active),	  
	                                  
	.mwr_read_req 	(mwr_read_req), 	  
	.mwr_read_data 	(mwr_read_data), 	 
	                                  
	.tx_data		(mwr_tx_data),			      
	.tx_req			(mwr_tx_req),			       
	.tx_data_req	(mwr_tx_data_req),		   
	.tx_ack			(mwr_tx_ack),			       
	.tx_done	    (mwr_tx_done),	        
	.tx_burst_len	(mwr_tx_burst_len),	   
	.tx_addr		(mwr_tx_addr),			      
	.tx_tag			(mwr_tx_tag)
				       
);


status_req_mux #	
(
	.NUM_OF_SG_CHANNLES	(MAX_NUM_OF_INTERRUPTS+NUM_OF_CHANNELS)
)
status_req_mux
(
	
	.clk_in        	(usr_clk),
	.rstn          	(~usr_rst),   
	
	.status_ack		(status_ack),	   
	.status_req		(status_req),	   
	.status_qword	(status_qword),
	.status_addr	(status_addr),
	
	.tx_req			(status_tx_req),	
	.tx_done	    (status_tx_done),	
	.tx_qword		(status_tx_qword),	
	.tx_addr		(status_tx_addr)	
      	    	
);

tx_dispatcher #
(
    .PCIE_CORE_DATA_WIDTH   (C_DATA_WIDTH),
    .AXI4_RQ_TUSER_WIDTH    (AXI4_RQ_TUSER_WIDTH),
    .KEEP_WIDTH             (KEEP_WIDTH)
)
tx_dispatcher_i
(
	.clk_in     		(usr_clk),
	.rstn       		(~usr_rst),
	
	.completer_id 		(completer_id),
	
	.rearbit_sig		(rearbit_sig),
	                	
	.mrd_tx_req			(mrd_tx_req), 
	.mrd_tx_done	    (mrd_tx_done),
	.mrd_tx_tag			(mrd_tx_tag), 
	.mrd_tx_len			(mrd_tx_len), 
	.mrd_tx_addr		(mrd_tx_addr),
	
	.mwr_tx_data		(mwr_tx_data),		   
	.mwr_tx_req			(mwr_tx_req),		    
	.mwr_tx_data_req	(mwr_tx_data_req),	
	.mwr_tx_ack			(mwr_tx_ack),		    
	.mwr_tx_done	    (mwr_tx_done),	    
	.mwr_tx_burst_len	(mwr_tx_burst_len),
	.mwr_tx_addr		(mwr_tx_addr),		   
	.mwr_tx_tag			(mwr_tx_tag),		    
	
	.status_tx_req		(status_tx_req),	  
	.status_tx_done	    (status_tx_done),	 
	.status_tx_qword	(status_tx_qword),	
	.status_tx_addr		(status_tx_addr),	 

	.m_axis_rq_tdata 	(m_axis_rq_tdata),
	.m_axis_rq_tuser 	(m_axis_rq_tuser),
	.m_axis_rq_tlast 	(m_axis_rq_tlast),
	.m_axis_rq_tkeep 	(m_axis_rq_tkeep),
	.m_axis_rq_tvalid	(m_axis_rq_tvalid),
	.m_axis_rq_tready	(m_axis_rq_tready)
		
	
	
);

mrd_comp_dispatcher #
(
	.NUM_OF_SG_CHANNLES	 	(MAX_NUM_OF_S2C_CHANNELS+MAX_NUM_OF_C2S_CHANNELS),
	.PCIE_CORE_DATA_WIDTH 	(C_DATA_WIDTH),                                                      
	.AXI4_RC_TUSER_WIDTH	(AXI4_RC_TUSER_WIDTH)                                               
)
mrd_comp_dispatcher_i
(

	.clk                 (usr_clk),   
  	.rstn                (~usr_rst),
	

 	.tag_request		(tag_request),
	.tag_valid			(tag_valid),
	.context			(context),
	.bm_sys_addr		(bm_sys_addr),
	.tag				(tag),
	
	.axis_rc_tvalid     (s_axis_rc_tvalid),
	.axis_rc_tkeep		(s_axis_rc_tkeep),
	.axis_rc_tdata 		(s_axis_rc_tdata),
	.axis_rc_tuser 		(s_axis_rc_tuser),
	.axis_rc_tlast		(s_axis_rc_tlast),
	.axis_rc_tready		(s_axis_rc_tready),
			 
	.bm_data			(bm_data),
	.bm_be             	(bm_be),
	.bm_rx_done			(bm_rx_done),
	.bm_rx_active		(bm_rx_active),
	.bm_rx_rdy			(bm_rx_rdy),
	.bm_context			(bm_context)
	
);

assign bar0_s_axi_bid = 0;
assign bar0_s_axi_rid = 0;
assign bar0_s_axi_rlast = {NUM_OF_BAR0_AXI_SLAVE{1'b1}}; 

//we have 3 regioins: rom, msix, dma channles
localparam M_REGIONS = 1;//fonr now - only one region
axi_crossbar #
(
    .S_COUNT (1), 
    .M_COUNT (NUM_OF_BAR0_AXI_SLAVE),
    .DATA_WIDTH (AXI_DATA_WIDTH),
    .ADDR_WIDTH (AXI_ADDR_WIDTH),
    .STRB_WIDTH (AXI_DATA_WIDTH/8),
    .S_ID_WIDTH (8),
    .M_REGIONS 	(M_REGIONS), 
    .M_ADDR_WIDTH  ({NUM_OF_BAR0_AXI_SLAVE{{M_REGIONS{32'd8}}}})
)
axi_crossbar_i
(
    .clk 			 (usr_clk),   
    .rst 			 (usr_rst), 
    
    .s_axi_awid   	 (bar0_m_axi_awid),   
    .s_axi_awaddr 	 (bar0_m_axi_awaddr), 
    .s_axi_awlen  	 (bar0_m_axi_awlen),  
    .s_axi_awsize 	 (bar0_m_axi_awsize), 
    .s_axi_awburst	 (bar0_m_axi_awburst),
    .s_axi_awlock 	 (bar0_m_axi_awlock), 
    .s_axi_awcache	 (bar0_m_axi_awcache),
    .s_axi_awprot 	 (bar0_m_axi_awprot), 
    .s_axi_awqos     (4'b0000), 
    .s_axi_awuser    (1'b0), 
    .s_axi_awvalid   (bar0_m_axi_awvalid), 
    .s_axi_awready   (bar0_m_axi_awready), 
    .s_axi_wdata     (bar0_m_axi_wdata), 
    .s_axi_wstrb     (bar0_m_axi_wstrb), 
    .s_axi_wlast     (bar0_m_axi_wlast), 
    .s_axi_wuser     (1'b0), 
    .s_axi_wvalid    (bar0_m_axi_wvalid),  
    .s_axi_wready    (bar0_m_axi_wready),  
    .s_axi_bid       (bar0_m_axi_bid),       
    .s_axi_bresp     (bar0_m_axi_bresp),    
    .s_axi_buser     (),  
    .s_axi_bvalid    (bar0_m_axi_bvalid), 
    .s_axi_bready    (bar0_m_axi_bready), 
    .s_axi_arid      (bar0_m_axi_arid),                    
    .s_axi_araddr    (bar0_m_axi_araddr),                  
    .s_axi_arlen     (bar0_m_axi_arlen),                   
    .s_axi_arsize    (bar0_m_axi_arsize),                  
    .s_axi_arburst   (bar0_m_axi_arburst),
    .s_axi_arlock    (bar0_m_axi_arlock), 
    .s_axi_arcache   (bar0_m_axi_arcache),
    .s_axi_arprot    (bar0_m_axi_arprot), 
    .s_axi_arqos     (4'b0000),
    .s_axi_aruser    (1'b0),
    .s_axi_arvalid   (bar0_m_axi_arvalid),
    .s_axi_arready   (bar0_m_axi_arready),
    .s_axi_rid       (bar0_m_axi_rid),    
    .s_axi_rdata     (bar0_m_axi_rdata),  
    .s_axi_rresp     (bar0_m_axi_rresp),  
    .s_axi_rlast     (bar0_m_axi_rlast),  
    .s_axi_ruser     (), 
    .s_axi_rvalid    (bar0_m_axi_rvalid), 
    .s_axi_rready    (bar0_m_axi_rready),

    .m_axi_awid      (bar0_s_axi_awid),   
    .m_axi_awaddr    (bar0_s_axi_awaddr), 
    .m_axi_awlen     (bar0_s_axi_awlen),  
    .m_axi_awsize    (bar0_s_axi_awsize), 
    .m_axi_awburst   (bar0_s_axi_awburst),
    .m_axi_awlock    (bar0_s_axi_awlock), 
    .m_axi_awcache   (bar0_s_axi_awcache),
    .m_axi_awprot    (bar0_s_axi_awprot), 
    .m_axi_awqos     (),
    .m_axi_awregion  (),
    .m_axi_awuser    (),
    .m_axi_awvalid   (bar0_s_axi_awvalid),
    .m_axi_awready   (bar0_s_axi_awready),
    .m_axi_wdata     (bar0_s_axi_wdata),  
    .m_axi_wstrb     (bar0_s_axi_wstrb),  
    .m_axi_wlast     (bar0_s_axi_wlast),  
    .m_axi_wuser     (), 
    .m_axi_wvalid    (bar0_s_axi_wvalid), 
    .m_axi_wready    (bar0_s_axi_wready), 
    .m_axi_bid       (bar0_s_axi_bid),    
    .m_axi_bresp     (bar0_s_axi_bresp),  
    .m_axi_buser     (4'b0000), 
    .m_axi_bvalid    (bar0_s_axi_bvalid),
    .m_axi_bready    (bar0_s_axi_bready),
    .m_axi_arid      (bar0_s_axi_arid),   
    .m_axi_araddr    (bar0_s_axi_araddr), 
    .m_axi_arlen     (bar0_s_axi_arlen),  
    .m_axi_arsize    (bar0_s_axi_arsize), 
    .m_axi_arburst   (bar0_s_axi_arburst),
    .m_axi_arlock    (bar0_s_axi_arlock), 
    .m_axi_arcache   (bar0_s_axi_arcache),
    .m_axi_arprot    (bar0_s_axi_arprot), 
    .m_axi_arqos     (),
    .m_axi_arregion  (),
    .m_axi_aruser    (),
    .m_axi_arvalid   (bar0_s_axi_arvalid),
    .m_axi_arready   (bar0_s_axi_arready),
    .m_axi_rid       (bar0_s_axi_rid),    
    .m_axi_rdata     (bar0_s_axi_rdata),  
    .m_axi_rresp     (bar0_s_axi_rresp),  
    .m_axi_rlast     (bar0_s_axi_rlast),  
    .m_axi_ruser     (4'b0000), 
    .m_axi_rvalid    (bar0_s_axi_rvalid), 
    .m_axi_rready    (bar0_s_axi_rready)
);


system_rom #
(
  	.NUM_OF_C2S_CHANNELS 	(NUM_OF_C2S_CHAN),
  	.NUM_OF_S2C_CHANNELS 	(NUM_OF_S2C_CHAN), 
  	.NUM_OF_INTERRUPTS 		(NUM_OF_INTERRUPTS),
	.DATAE 					(DATAE ),
	.VER_MJ 				(VER_MJ),
	.VER_MN 				(VER_MN),

  	.AXI_ID_WIDTH           (AXI_ID_WIDTH),
  	.AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
  	.AXI_DATA_WIDTH         (AXI_DATA_WIDTH),
  	.AXI_STRB_WIDTH         (AXI_STRB_WIDTH)
 
)
system_rom_i
(
	
    .s_axi_clk				(usr_clk),
    .s_axi_rstn				(~usr_rst),

    
	.s_axil_awaddr   	(bar0_s_axi_awaddr[AXI_ADDR_WIDTH-1:0]),		           
	.s_axil_awprot  	(bar0_s_axi_awprot[2:0]),                             
	.s_axil_awvalid  	(bar0_s_axi_awvalid[0:0]),               	                 
	.s_axil_awready 	(bar0_s_axi_awready[0:0]),				                                         
	.s_axil_wdata    	(bar0_s_axi_wdata[AXI_DATA_WIDTH-1:0]),	    	                
	.s_axil_wstrb    	(bar0_s_axi_wstrb[AXI_STRB_WIDTH-1:0]),	    	                
	.s_axil_wvalid  	(bar0_s_axi_wvalid[0:0]),				                                                        
	.s_axil_wready  	(bar0_s_axi_wready[0:0]),				                                            
	.s_axil_bresp   	(bar0_s_axi_bresp[1:0]),                                                                                               
	.s_axil_bvalid  	(bar0_s_axi_bvalid[0]),            	                               
	.s_axil_bready  	(bar0_s_axi_bready[0]),            	                                             
	.s_axil_araddr   	(bar0_s_axi_araddr[AXI_ADDR_WIDTH-1:0]),		          
	.s_axil_arprot  	(bar0_s_axi_arprot[2:0]),               	           
	.s_axil_arvalid 	(bar0_s_axi_arvalid[0]),          	                            
	.s_axil_arready 	(bar0_s_axi_arready[0:0]),          	                           
	.s_axil_rdata    	(bar0_s_axi_rdata[AXI_DATA_WIDTH-1:0]),	    	           
	.s_axil_rresp   	(bar0_s_axi_rresp[1:0]),                              
	.s_axil_rvalid   	(bar0_s_axi_rvalid[0:0]),               	           
	.s_axil_rready   	(bar0_s_axi_rready[0:0])               	                
                                                                        
                                                                        
);                                                                                     
 


(* keep = "true" *) reg [MAX_NUM_OF_C2S_CHANNELS+MAX_NUM_OF_S2C_CHANNELS-1 : 0]	tag_valid_d; 
(* keep = "true" *) reg [7 : 0]                        					tag_d;		

always @(posedge usr_clk) 
begin
	tag_valid_d <= tag_valid;
	tag_d <= tag;
end



genvar i;

generate 
	for(i=0;i<MAX_NUM_OF_S2C_CHANNELS;i=i+1)
	begin
		sg_s2c_chan #
		(
			.CHAN_NUM								(MAX_NUM_OF_C2S_CHANNELS+i),
			.PCIE_CORE_DATA_WIDTH 					(C_DATA_WIDTH),
			.ONE_USEC_PER_BUS_CYCLE 				(ONE_USEC_PER_BUS_CYCLE),
			.SWAP_ENDIAN			 				(SWAP_ENDIAN),
			.MAX_USER_RX_REQUEST_SIZE 				(MAX_USER_RX_REQUEST_SIZE),
			.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST 	(NUM_NUM_OF_USER_RX_PENDINNG_REQUEST),
			.BUFFES_SIZE_LOG_OF2					(BUFFES_SIZE_LOG_OF2),
				
		  	.AXI_ID_WIDTH                   		(AXI_ID_WIDTH),
		  	.AXI_ADDR_WIDTH                 		(AXI_ADDR_WIDTH),
		  	.AXI_DATA_WIDTH                 		(AXI_DATA_WIDTH),
		  	.AXI_STRB_WIDTH                 		(AXI_STRB_WIDTH)
		 
		)
		sg_s2c_chan_i
		(
			// clock for all interfaces
		    .s_axi_clk	(usr_clk),   
		    .s_axi_rstn	(~usr_rst),
		    
		    //global system enable			         
		    .sys_ena	(1'b1),     			
		
		    //AXI Lite Registes target for W/R from the host
			.s_axil_awaddr   	(bar0_s_axi_awaddr[(i+MAX_NUM_OF_C2S_CHANNELS+3)*AXI_ADDR_WIDTH-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*AXI_ADDR_WIDTH]),
			.s_axil_awprot  	(bar0_s_axi_awprot[(i+MAX_NUM_OF_C2S_CHANNELS+3)*3-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*3]),                          
			.s_axil_awvalid  	(bar0_s_axi_awvalid[i+MAX_NUM_OF_C2S_CHANNELS+2]),                                    		                     
			.s_axil_awready 	(bar0_s_axi_awready[i+MAX_NUM_OF_C2S_CHANNELS+2]),				                    		                                 
			.s_axil_wdata    	(bar0_s_axi_wdata[(i+MAX_NUM_OF_C2S_CHANNELS+3)*AXI_DATA_WIDTH-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*AXI_DATA_WIDTH]), 
			.s_axil_wstrb    	(bar0_s_axi_wstrb[(i+MAX_NUM_OF_C2S_CHANNELS+3)*AXI_STRB_WIDTH-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*AXI_STRB_WIDTH]), 
			.s_axil_wvalid  	(bar0_s_axi_wvalid[i+MAX_NUM_OF_C2S_CHANNELS+2]),				                        	                                             
			.s_axil_wready  	(bar0_s_axi_wready[i+MAX_NUM_OF_C2S_CHANNELS+2]),				                        	                                
			.s_axil_bresp   	(bar0_s_axi_bresp[(i+MAX_NUM_OF_C2S_CHANNELS+3)*2-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*2]),                                                                 
			.s_axil_bvalid  	(bar0_s_axi_bvalid[i+MAX_NUM_OF_C2S_CHANNELS+2]),            	                                               
			.s_axil_bready  	(bar0_s_axi_bready[i+MAX_NUM_OF_C2S_CHANNELS+2]),            	                        	                      
			.s_axil_araddr   	(bar0_s_axi_araddr[(i+MAX_NUM_OF_C2S_CHANNELS+3)*AXI_ADDR_WIDTH-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*AXI_ADDR_WIDTH]),
			.s_axil_arprot  	(bar0_s_axi_arprot[(i+MAX_NUM_OF_C2S_CHANNELS+3)*3-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*3]),                          
			.s_axil_arvalid 	(bar0_s_axi_arvalid[i+MAX_NUM_OF_C2S_CHANNELS+2]),          	                        	                       
			.s_axil_arready 	(bar0_s_axi_arready[i+MAX_NUM_OF_C2S_CHANNELS+2]),    		      	                                              
			.s_axil_rdata    	(bar0_s_axi_rdata[(i+MAX_NUM_OF_C2S_CHANNELS+3)*AXI_DATA_WIDTH-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*AXI_DATA_WIDTH]), 
			.s_axil_rresp   	(bar0_s_axi_rresp[(i+MAX_NUM_OF_C2S_CHANNELS+3)*2-1:(i+MAX_NUM_OF_C2S_CHANNELS+2)*2]),                           
			.s_axil_rvalid   	(bar0_s_axi_rvalid[i+MAX_NUM_OF_C2S_CHANNELS+2]),                                     		                     
			.s_axil_rready   	(bar0_s_axi_rready[i+MAX_NUM_OF_C2S_CHANNELS+2]),                                     		                     
			                                                      
		  
		    
		   //Mrd tag allocation interface
			.alloc_tag_req		(tag_request[MAX_NUM_OF_C2S_CHANNELS+i]),
			.allocated_tag_rdy	(tag_valid[MAX_NUM_OF_C2S_CHANNELS+i]),
			.allocated_tag		(tag),
		    
		    
			//Read Completion Interface
			.bm_data				(bm_data), 
			.bm_be					(bm_be),
			.bm_rx_done				(bm_rx_done[MAX_NUM_OF_C2S_CHANNELS+i]),
			.bm_rx_active 			(bm_rx_active[MAX_NUM_OF_C2S_CHANNELS+i]),
			.bm_rx_rdy				(bm_rx_rdy[MAX_NUM_OF_C2S_CHANNELS+i]),
			.bm_rx_last_in_burst	(1'b0),
			.bm_context				(bm_context),
						
			// MRd Req Interface
			.mrd_req_arbit_req			(mrd_req_req[MAX_NUM_OF_C2S_CHANNELS+i]),
			.mrd_req_arbit_grnt			(mrd_req_ack[MAX_NUM_OF_C2S_CHANNELS+i]),	
			.mrd_req_rearbit_req		(rearbit_sig),	
			.mrd_req_burst_len_out		(mrd_req_len[(MAX_NUM_OF_C2S_CHANNELS+i)*13+12:(MAX_NUM_OF_C2S_CHANNELS+i)*13]),
			.mrd_req_burst_sys_addr_out	(mrd_addr[(MAX_NUM_OF_C2S_CHANNELS+i)*64+63:(MAX_NUM_OF_C2S_CHANNELS+i)*64]),	
			.mrd_req_burst_tag			(mrd_tag[(MAX_NUM_OF_C2S_CHANNELS+i)*8+7:(MAX_NUM_OF_C2S_CHANNELS+i)*8]),
			.mrd_req_context			(context[32*(MAX_NUM_OF_C2S_CHANNELS+i)+31:32*(MAX_NUM_OF_C2S_CHANNELS+i)]),
						  	
		  	// AXI-M slave Interface to the app
		  	.m_axis_tdata 			(s2c_axis_tdata[i*C_DATA_WIDTH+C_DATA_WIDTH-1:i*C_DATA_WIDTH]),
		  	.m_axis_tkeep 			(s2c_axis_tkeep	[i*KEEP_WIDTH+KEEP_WIDTH-1:i*KEEP_WIDTH]),
		  	.m_axis_tlast 			(s2c_axis_tlast[i]),
		  	.m_axis_tvalid			(s2c_axis_tvalid[i]),
		  	.m_axis_tuser 			(s2c_axis_tuser[i*31+32:i*32]),
		  	.m_axis_tready			(s2c_axis_tready[i]),
		  	
		    //system level state 
			.max_payload_size			(max_payload_size),
			.max_read_request_size		(max_read_request_size),
			
			// interrupt request signals	
			.int_gen		(int_req_internal[MAX_NUM_OF_INTERRUPTS+MAX_NUM_OF_C2S_CHANNELS+i]),	
							 
			
			.status_ack		(status_ack[MAX_NUM_OF_C2S_CHANNELS+i]),
			.status_req		(status_req[MAX_NUM_OF_C2S_CHANNELS+i]),
			.status_qword 	(status_qword[(MAX_NUM_OF_C2S_CHANNELS+i)*64+63:(MAX_NUM_OF_C2S_CHANNELS+i)*64]),
			.status_addr  	(status_addr[(MAX_NUM_OF_C2S_CHANNELS+i)*64+63:(MAX_NUM_OF_C2S_CHANNELS+i)*64])
		    
		);
	end
endgenerate


generate 
	for(i=0;i<MAX_NUM_OF_C2S_CHANNELS;i=i+1)
	begin
		sg_c2s_chan #
		(
			.CHAN_NUM								(i),
			.PCIE_CORE_DATA_WIDTH 					(C_DATA_WIDTH),
			.ONE_USEC_PER_BUS_CYCLE 				(ONE_USEC_PER_BUS_CYCLE),
			.SWAP_ENDIAN			 				(SWAP_ENDIAN),
			.MAX_USER_RX_REQUEST_SIZE 				(MAX_USER_RX_REQUEST_SIZE),
			.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST 	(NUM_NUM_OF_USER_RX_PENDINNG_REQUEST),
			.BUFFES_SIZE_LOG_OF2					(BUFFES_SIZE_LOG_OF2),
				
		  	.AXI_ID_WIDTH                   		(AXI_ID_WIDTH),
		  	.AXI_ADDR_WIDTH                 		(AXI_ADDR_WIDTH),
		  	.AXI_DATA_WIDTH                 		(AXI_DATA_WIDTH),
		  	.AXI_STRB_WIDTH                 		(AXI_STRB_WIDTH)
		 
		)
		sg_c2s_chan_i
		(
			// clock for all interfaces
		    .s_axi_clk	(usr_clk),   
		    .s_axi_rstn	(~usr_rst),
		    
		    //global system enable			         
		    .sys_ena	(1'b1),     			
		
		    //AXI Lite Registes target for W/R from the host
			.s_axil_awaddr   	(bar0_s_axi_awaddr[(i+3)*AXI_ADDR_WIDTH-1:(i+2)*AXI_ADDR_WIDTH]), 	
			.s_axil_awprot  	(bar0_s_axi_awprot[(i+3)*3-1:(i+2)*3]),                             
			.s_axil_awvalid  	(bar0_s_axi_awvalid[i+2]),                                    		  
			.s_axil_awready 	(bar0_s_axi_awready[i+2]),				                    		                           
			.s_axil_wdata    	(bar0_s_axi_wdata[(i+3)*AXI_DATA_WIDTH-1:(i+2)*AXI_DATA_WIDTH]),  	        
			.s_axil_wstrb    	(bar0_s_axi_wstrb[(i+3)*AXI_STRB_WIDTH-1:(i+2)*AXI_STRB_WIDTH]),  	        
			.s_axil_wvalid  	(bar0_s_axi_wvalid[i+2]),				                        	                                       
			.s_axil_wready  	(bar0_s_axi_wready[i+2]),				                        	                           
			.s_axil_bresp   	(bar0_s_axi_bresp[(i+3)*2-1:(i+2)*2]),                                                                                    
			.s_axil_bvalid  	(bar0_s_axi_bvalid[i+2]),            	                                 
			.s_axil_bready  	(bar0_s_axi_bready[i+2]),            	                        	                   
			.s_axil_araddr   	(bar0_s_axi_araddr[(i+3)*AXI_ADDR_WIDTH-1:(i+2)*AXI_ADDR_WIDTH]), 	
			.s_axil_arprot  	(bar0_s_axi_arprot[(i+3)*3-1:(i+2)*3]),                             
			.s_axil_arvalid 	(bar0_s_axi_arvalid[i+2]),          	                        	
			.s_axil_arready 	(bar0_s_axi_arready[i+2]),    		      	                         
			.s_axil_rdata    	(bar0_s_axi_rdata[(i+3)*AXI_DATA_WIDTH-1:(i+2)*AXI_DATA_WIDTH]),  	
			.s_axil_rresp   	(bar0_s_axi_rresp[(i+3)*2-1:(i+2)*2]),                              
			.s_axil_rvalid   	(bar0_s_axi_rvalid[i+2]),                                     		
			.s_axil_rready   	(bar0_s_axi_rready[i+2]),                                     		
		  
		    
		   //Mrd tag allocation interface
			.alloc_tag_req		(tag_request[i]),
			.allocated_tag_rdy	(tag_valid[i]),
			.allocated_tag		(tag),
		    
		    
			//Read Completion Interface
			.bm_data				(bm_data), 
			.bm_be					(bm_be),
			.bm_rx_done				(bm_rx_done[i]),
			.bm_rx_active 			(bm_rx_active[i]),
			.bm_rx_rdy				(bm_rx_rdy[i]),
			.bm_rx_last_in_burst	(1'b0),
			.bm_context				(bm_context),
			
			
			// MRd Req Interface
			.mrd_req_arbit_req			(mrd_req_req[i]),
			.mrd_req_arbit_grnt			(mrd_req_ack[i]),	
			.mrd_req_rearbit_req		(rearbit_sig),	
			.mrd_req_burst_len_out		(mrd_req_len[i*13+12:i*13]),
			.mrd_req_burst_sys_addr_out	(mrd_addr[i*64+63:i*64]),	
			.mrd_req_burst_tag			(mrd_tag[i*8+7:i*8]),
			.mrd_req_context			(context[32*i+31:32*i]),
			
			
			

		   // TX Dispatcher Interface 
		    .tx_stop 				(c2s_stop[i]),
			.tx_arbit_req			(mwr_req[i]),
			.tx_arbit_grnt			(mwr_ack[i]),
			.tx_rearbit_req			(rearbit_sig),	
			.tx_burst_len_out 		(mwr_burst_len[13*i+12:13*i]),
			.tx_burst_sys_addr_out	(mwr_addr[64*i+63:64*i]),
			.tx_burst_tag			(mwr_tag[8*i+7:8*i]),
			.tx_wr_active 			(mwr_wr_active[i]),
			
			.read_req		(mwr_read_req[i]), 
			.read_data      (mwr_read_data[i*C_DATA_WIDTH+C_DATA_WIDTH-1:i*C_DATA_WIDTH]),
			
			
			  	
		  	// AXI-S slave Interface to the app
		  	.s_axis_tdata 			(c2s_axis_tdata[i*C_DATA_WIDTH+C_DATA_WIDTH-1:i*C_DATA_WIDTH]),
		  	.s_axis_tkeep 			(c2s_axis_tkeep	[i*KEEP_WIDTH+KEEP_WIDTH-1:i*KEEP_WIDTH]),
		  	.s_axis_tlast 			(c2s_axis_tlast[i]),
		  	.s_axis_tvalid			(c2s_axis_tvalid[i]),
		  	.s_axis_tuser 			(c2s_axis_tuser[i*32+31:i*32]),
		  	.s_axis_tready			(c2s_axis_tready[i]),
		  	
		    //system level state 
			.max_payload_size			(max_payload_size),
			.max_read_request_size		(max_read_request_size),
			
			// interrupt request signals	
			.int_gen		(int_req_internal[MAX_NUM_OF_INTERRUPTS+i]),	
			
			.status_ack		(status_ack[i]),
			.status_req		(status_req[i]),
			.status_qword 	(status_qword[i*64+63:i*64]),
			.status_addr  	(status_addr[i*64+63:i*64])
		    
		);
	end
endgenerate


wire [MAX_NUM_OF_INTERRUPTS-1:0] int_req;



assign int_req = 
{
	int_req_7,
	int_req_6,
	int_req_5,
	int_req_4,
	int_req_3,
	int_req_2,
	int_req_1,
	int_req_0	
};

generate 
if(NUM_OF_INTERRUPTS > 0)

user_interrupts #
(
    .NUM_OF_INTERRUPTS                      (MAX_NUM_OF_INTERRUPTS),
	.AXI_ID_WIDTH                   		(AXI_ID_WIDTH),
	.AXI_ADDR_WIDTH                 		(AXI_ADDR_WIDTH),
	.AXI_DATA_WIDTH                 		(AXI_DATA_WIDTH),
	.AXI_STRB_WIDTH                 		(AXI_STRB_WIDTH)
)
user_interrupts_i
(
	.s_axi_clk	(usr_clk),   
	.s_axi_rstn	(~usr_rst),
		    
	.s_axil_awaddr   	(bar0_s_axi_awaddr[(NUM_OF_CHANNELS+3)*AXI_ADDR_WIDTH-1:(NUM_OF_CHANNELS+2)*AXI_ADDR_WIDTH]),                                     
	.s_axil_awprot  	(bar0_s_axi_awprot[(NUM_OF_CHANNELS+3)*3-1:(NUM_OF_CHANNELS+2)*3]),                                                                
	.s_axil_awvalid  	(bar0_s_axi_awvalid[NUM_OF_CHANNELS+2]),                                    		                                                      
	.s_axil_awready 	(bar0_s_axi_awready[NUM_OF_CHANNELS+2]),				                    		                                                                   
	.s_axil_wdata    	(bar0_s_axi_wdata[(NUM_OF_CHANNELS+3)*AXI_DATA_WIDTH-1:(NUM_OF_CHANNELS+2)*AXI_DATA_WIDTH]),                                      
	.s_axil_wstrb    	(bar0_s_axi_wstrb[(NUM_OF_CHANNELS+3)*AXI_STRB_WIDTH-1:(NUM_OF_CHANNELS+2)*AXI_STRB_WIDTH]),                                      
	.s_axil_wvalid  	(bar0_s_axi_wvalid[NUM_OF_CHANNELS+2]),				                        	                                                                 
	.s_axil_wready  	(bar0_s_axi_wready[NUM_OF_CHANNELS+2]),				                        	                                                                 
	.s_axil_bresp   	(bar0_s_axi_bresp[(NUM_OF_CHANNELS+3)*2-1:(NUM_OF_CHANNELS+2)*2]),                                                                 
	.s_axil_bvalid  	(bar0_s_axi_bvalid[NUM_OF_CHANNELS+2]),            	                                                                                 
	.s_axil_bready  	(bar0_s_axi_bready[NUM_OF_CHANNELS+2]),            	                        	                                                        
	.s_axil_araddr   	(bar0_s_axi_araddr[(NUM_OF_CHANNELS+3)*AXI_ADDR_WIDTH-1:(NUM_OF_CHANNELS+2)*AXI_ADDR_WIDTH]),                                     
	.s_axil_arprot  	(bar0_s_axi_arprot[(NUM_OF_CHANNELS+3)*3-1:(NUM_OF_CHANNELS+2)*3]),                                                                
	.s_axil_arvalid 	(bar0_s_axi_arvalid[NUM_OF_CHANNELS+2]),          	                        	                                                         
	.s_axil_arready 	(bar0_s_axi_arready[NUM_OF_CHANNELS+2]),    		      	                                                                                
	.s_axil_rdata    	(bar0_s_axi_rdata[(NUM_OF_CHANNELS+3)*AXI_DATA_WIDTH-1:(NUM_OF_CHANNELS+2)*AXI_DATA_WIDTH]),                                      
	.s_axil_rresp   	(bar0_s_axi_rresp[(NUM_OF_CHANNELS+3)*2-1:(NUM_OF_CHANNELS+2)*2]),                                                                 
	.s_axil_rvalid   	(bar0_s_axi_rvalid[NUM_OF_CHANNELS+2]),                                     		                                                      
	.s_axil_rready   	(bar0_s_axi_rready[NUM_OF_CHANNELS+2]),                                                                                             
	                                                                                                                                                        
	.status_ack			(status_ack[MAX_NUM_OF_INTERRUPTS+NUM_OF_CHANNELS-1:NUM_OF_CHANNELS]),                                                                                                           
	.status_req			(status_req[MAX_NUM_OF_INTERRUPTS+NUM_OF_CHANNELS-1:NUM_OF_CHANNELS]),                                                                                                           
	.status_qword 		(status_qword[(MAX_NUM_OF_INTERRUPTS+NUM_OF_CHANNELS)*64-1:NUM_OF_CHANNELS*64]),                                                                        
	.status_addr  		(status_addr[(MAX_NUM_OF_INTERRUPTS+NUM_OF_CHANNELS)*64-1:NUM_OF_CHANNELS*64]),                                                                         
			
	.int_req_in			(int_req),
	.int_req			(int_req_internal[MAX_NUM_OF_INTERRUPTS-1:0])
);
endgenerate
                                                

	always @(posedge usr_clk) 
	begin
		rd_valid	= 1'b0;
	    if(bar0_data_valid)
	    begin
	   		rd_data		<= bar_0_rd_data;
	   		rd_valid	<= 1'b1;
	    end 
	    else if(bar2_data_valid)
	    begin
	   		rd_data		<= bar_2_rd_data;
	   		rd_valid	<= 1'b1;
	    end 
	end    

generate 
	if(NUM_OF_S2C_CHAN > 0)	
	begin
		assign s2c0_axis_tdata    = s2c_axis_tdata[0*C_DATA_WIDTH+C_DATA_WIDTH-1:0*C_DATA_WIDTH];
		assign s2c0_axis_tkeep    = s2c_axis_tkeep[0*KEEP_WIDTH+KEEP_WIDTH-1:0*KEEP_WIDTH];
		assign s2c0_axis_tlast    = s2c_axis_tlast[0];
		assign s2c0_axis_tvalid   = s2c_axis_tvalid[0];
		assign s2c0_axis_tuser    = s2c_axis_tuser[0*32+31:0*32];
		assign s2c_axis_tready[0] = s2c0_axis_tready;
	end
	else
	begin
		assign s2c0_axis_tdata    = 0;
		assign s2c0_axis_tkeep    = 0;
		assign s2c0_axis_tlast    = 0;
		assign s2c0_axis_tvalid   = 0;
		assign s2c0_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 0)	
	begin
		assign c2s_axis_tdata[0*C_DATA_WIDTH+C_DATA_WIDTH-1:0*C_DATA_WIDTH] = c2s0_axis_tdata;			  	
		assign c2s_axis_tkeep[0*KEEP_WIDTH+KEEP_WIDTH-1:0*KEEP_WIDTH] = c2s0_axis_tkeep; 	
		assign c2s_axis_tlast[0] = c2s0_axis_tlast; 		  	
		assign c2s_axis_tvalid[0] = c2s0_axis_tvalid; 		  	
		assign c2s_axis_tuser[0*32+31:0*32] = c2s0_axis_tuser; 	
		assign c2s0_axis_tready = c2s_axis_tready[0]; 	
	end
	else
	begin
		assign c2s0_axis_tready = 0;
	end
endgenerate		 
	

generate 
	if(NUM_OF_S2C_CHAN > 1)	
	begin
		assign s2c1_axis_tdata    = s2c_axis_tdata[1*C_DATA_WIDTH+C_DATA_WIDTH-1:1*C_DATA_WIDTH];
		assign s2c1_axis_tkeep    = s2c_axis_tkeep[1*KEEP_WIDTH+KEEP_WIDTH-1:1*KEEP_WIDTH];
		assign s2c1_axis_tlast    = s2c_axis_tlast[1];
		assign s2c1_axis_tvalid   = s2c_axis_tvalid[1];
		assign s2c1_axis_tuser    = s2c_axis_tuser[1*32+31:1*32];
		assign s2c_axis_tready[1] = s2c1_axis_tready;
	end
	else
	begin
		assign s2c1_axis_tdata    = 0;
		assign s2c1_axis_tkeep    = 0;
		assign s2c1_axis_tlast    = 0;
		assign s2c1_axis_tvalid   = 0;
		assign s2c1_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 1)	
	begin
		assign c2s_axis_tdata[1*C_DATA_WIDTH+C_DATA_WIDTH-1:1*C_DATA_WIDTH] = c2s1_axis_tdata;			  	
		assign c2s_axis_tkeep[1*KEEP_WIDTH+KEEP_WIDTH-1:1*KEEP_WIDTH] = c2s1_axis_tkeep; 	
		assign c2s_axis_tlast[1] = c2s1_axis_tlast; 		  	
		assign c2s_axis_tvalid[1] = c2s1_axis_tvalid; 		  	
		assign c2s_axis_tuser[1*32+31:1*32] = c2s1_axis_tuser; 	
		assign c2s1_axis_tready = c2s_axis_tready[1]; 	
	end
	else
	begin
		assign c2s1_axis_tready = 0;
	end
endgenerate		 
	
generate 
	if(NUM_OF_S2C_CHAN > 2)	
	begin
		assign s2c2_axis_tdata    = s2c_axis_tdata[2*C_DATA_WIDTH+C_DATA_WIDTH-1:2*C_DATA_WIDTH];
		assign s2c2_axis_tkeep    = s2c_axis_tkeep[2*KEEP_WIDTH+KEEP_WIDTH-1:2*KEEP_WIDTH];
		assign s2c2_axis_tlast    = s2c_axis_tlast[2];
		assign s2c2_axis_tvalid   = s2c_axis_tvalid[2];
		assign s2c2_axis_tuser    = s2c_axis_tuser[2*32+31:2*32];
		assign s2c_axis_tready[2] = s2c2_axis_tready;
	end
	else
	begin
		assign s2c2_axis_tdata    = 0;
		assign s2c2_axis_tkeep    = 0;
		assign s2c2_axis_tlast    = 0;
		assign s2c2_axis_tvalid   = 0;
		assign s2c2_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 2)	
	begin
		assign c2s_axis_tdata[2*C_DATA_WIDTH+C_DATA_WIDTH-1:2*C_DATA_WIDTH] = c2s2_axis_tdata;			  	
		assign c2s_axis_tkeep[2*KEEP_WIDTH+KEEP_WIDTH-1:2*KEEP_WIDTH] = c2s2_axis_tkeep; 	
		assign c2s_axis_tlast[2] = c2s2_axis_tlast; 		  	
		assign c2s_axis_tvalid[2] = c2s2_axis_tvalid; 		  	
		assign c2s_axis_tuser[2*32+31:2*32] = c2s2_axis_tuser; 	
		assign c2s2_axis_tready = c2s_axis_tready[2]; 	
	end
	else
	begin
		assign c2s2_axis_tready = 0;
	end
endgenerate		


generate 
	if(NUM_OF_S2C_CHAN > 3)	
	begin
		assign s2c3_axis_tdata    = s2c_axis_tdata[3*C_DATA_WIDTH+C_DATA_WIDTH-1:3*C_DATA_WIDTH];
		assign s2c3_axis_tkeep    = s2c_axis_tkeep[3*KEEP_WIDTH+KEEP_WIDTH-1:3*KEEP_WIDTH];
		assign s2c3_axis_tlast    = s2c_axis_tlast[3];
		assign s2c3_axis_tvalid   = s2c_axis_tvalid[3];
		assign s2c3_axis_tuser    = s2c_axis_tuser[3*32+31:3*32];
		assign s2c_axis_tready[3] = s2c3_axis_tready;
	end
	else
	begin
		assign s2c3_axis_tdata    = 0;
		assign s2c3_axis_tkeep    = 0;
		assign s2c3_axis_tlast    = 0;
		assign s2c3_axis_tvalid   = 0;
		assign s2c3_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 3)	
	begin
		assign c2s_axis_tdata[3*C_DATA_WIDTH+C_DATA_WIDTH-1:3*C_DATA_WIDTH] = c2s3_axis_tdata;			  	
		assign c2s_axis_tkeep[3*KEEP_WIDTH+KEEP_WIDTH-1:3*KEEP_WIDTH] = c2s3_axis_tkeep; 	
		assign c2s_axis_tlast[3] = c2s3_axis_tlast; 		  	
		assign c2s_axis_tvalid[3] = c2s3_axis_tvalid; 		  	
		assign c2s_axis_tuser[3*32+31:3*32] = c2s3_axis_tuser; 	
		assign c2s3_axis_tready = c2s_axis_tready[3]; 	
	end
	else
	begin
		assign c2s3_axis_tready = 0;
	end
endgenerate	

generate 
	if(NUM_OF_S2C_CHAN > 4)	
	begin
		assign s2c4_axis_tdata    = s2c_axis_tdata[4*C_DATA_WIDTH+C_DATA_WIDTH-1:4*C_DATA_WIDTH];
		assign s2c4_axis_tkeep    = s2c_axis_tkeep[4*KEEP_WIDTH+KEEP_WIDTH-1:4*KEEP_WIDTH];
		assign s2c4_axis_tlast    = s2c_axis_tlast[4];
		assign s2c4_axis_tvalid   = s2c_axis_tvalid[4];
		assign s2c4_axis_tuser    = s2c_axis_tuser[4*32+31:4*32];
		assign s2c_axis_tready[4] = s2c4_axis_tready;
	end
	else
	begin
		assign s2c4_axis_tdata    = 0;
		assign s2c4_axis_tkeep    = 0;
		assign s2c4_axis_tlast    = 0;
		assign s2c4_axis_tvalid   = 0;
		assign s2c4_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 4)	
	begin
		assign c2s_axis_tdata[4*C_DATA_WIDTH+C_DATA_WIDTH-1:4*C_DATA_WIDTH] = c2s4_axis_tdata;			  	
		assign c2s_axis_tkeep[4*KEEP_WIDTH+KEEP_WIDTH-1:4*KEEP_WIDTH] = c2s4_axis_tkeep; 	
		assign c2s_axis_tlast[4] = c2s4_axis_tlast; 		  	
		assign c2s_axis_tvalid[4] = c2s4_axis_tvalid; 		  	
		assign c2s_axis_tuser[4*32+31:4*32] = c2s4_axis_tuser; 	
		assign c2s4_axis_tready = c2s_axis_tready[4]; 	
	end
	else
	begin
		assign c2s4_axis_tready = 0;
	end
endgenerate		 

generate 
	if(NUM_OF_S2C_CHAN > 5)	
	begin
		assign s2c5_axis_tdata    = s2c_axis_tdata[5*C_DATA_WIDTH+C_DATA_WIDTH-1:5*C_DATA_WIDTH];
		assign s2c5_axis_tkeep    = s2c_axis_tkeep[5*KEEP_WIDTH+KEEP_WIDTH-1:5*KEEP_WIDTH];
		assign s2c5_axis_tlast    = s2c_axis_tlast[5];
		assign s2c5_axis_tvalid   = s2c_axis_tvalid[5];
		assign s2c5_axis_tuser    = s2c_axis_tuser[5*32+31:5*32];
		assign s2c_axis_tready[5] = s2c5_axis_tready;
	end
	else
	begin
		assign s2c5_axis_tdata    = 0;
		assign s2c5_axis_tkeep    = 0;
		assign s2c5_axis_tlast    = 0;
		assign s2c5_axis_tvalid   = 0;
		assign s2c5_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 5)	
	begin
		assign c2s_axis_tdata[5*C_DATA_WIDTH+C_DATA_WIDTH-1:5*C_DATA_WIDTH] = c2s5_axis_tdata;			  	
		assign c2s_axis_tkeep[5*KEEP_WIDTH+KEEP_WIDTH-1:5*KEEP_WIDTH] = c2s5_axis_tkeep; 	
		assign c2s_axis_tlast[5] = c2s5_axis_tlast; 		  	
		assign c2s_axis_tvalid[5] = c2s5_axis_tvalid; 		  	
		assign c2s_axis_tuser[5*32+31:5*32] = c2s5_axis_tuser; 	
		assign c2s5_axis_tready = c2s_axis_tready[5]; 	
	end
	else
	begin
		assign c2s5_axis_tready = 0;
	end
endgenerate	

generate 
	if(NUM_OF_S2C_CHAN > 6)	
	begin
		assign s2c6_axis_tdata    = s2c_axis_tdata[6*C_DATA_WIDTH+C_DATA_WIDTH-1:6*C_DATA_WIDTH];
		assign s2c6_axis_tkeep    = s2c_axis_tkeep[6*KEEP_WIDTH+KEEP_WIDTH-1:6*KEEP_WIDTH];
		assign s2c6_axis_tlast    = s2c_axis_tlast[6];
		assign s2c6_axis_tvalid   = s2c_axis_tvalid[6];
		assign s2c6_axis_tuser    = s2c_axis_tuser[6*32+31:6*32];
		assign s2c_axis_tready[6] = s2c6_axis_tready;
	end
	else
	begin
		assign s2c6_axis_tdata    = 0;
		assign s2c6_axis_tkeep    = 0;
		assign s2c6_axis_tlast    = 0;
		assign s2c6_axis_tvalid   = 0;
		assign s2c6_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 6)	
	begin
		assign c2s_axis_tdata[6*C_DATA_WIDTH+C_DATA_WIDTH-1:6*C_DATA_WIDTH] = c2s6_axis_tdata;			  	
		assign c2s_axis_tkeep[6*KEEP_WIDTH+KEEP_WIDTH-1:6*KEEP_WIDTH] = c2s6_axis_tkeep; 	
		assign c2s_axis_tlast[6] = c2s6_axis_tlast; 		  	
		assign c2s_axis_tvalid[6] = c2s6_axis_tvalid; 		  	
		assign c2s_axis_tuser[6*32+31:6*32] = c2s6_axis_tuser; 	
		assign c2s6_axis_tready = c2s_axis_tready[6]; 	
	end
	else
	begin
		assign c2s6_axis_tready = 0;
	end
endgenerate		 	 	  


generate 
	if(NUM_OF_S2C_CHAN > 7)	
	begin
		assign s2c7_axis_tdata    = s2c_axis_tdata[7*C_DATA_WIDTH+C_DATA_WIDTH-1:7*C_DATA_WIDTH];
		assign s2c7_axis_tkeep    = s2c_axis_tkeep[7*KEEP_WIDTH+KEEP_WIDTH-1:7*KEEP_WIDTH];
		assign s2c7_axis_tlast    = s2c_axis_tlast[7];
		assign s2c7_axis_tvalid   = s2c_axis_tvalid[7];
		assign s2c7_axis_tuser    = s2c_axis_tuser[7*32+31:7*32];
		assign s2c_axis_tready[7] = s2c7_axis_tready;
	end
	else
	begin
		assign s2c7_axis_tdata    = 0;
		assign s2c7_axis_tkeep    = 0;
		assign s2c7_axis_tlast    = 0;
		assign s2c7_axis_tvalid   = 0;
		assign s2c7_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 7)	
	begin
		assign c2s_axis_tdata[7*C_DATA_WIDTH+C_DATA_WIDTH-1:7*C_DATA_WIDTH] = c2s7_axis_tdata;			  	
		assign c2s_axis_tkeep[7*KEEP_WIDTH+KEEP_WIDTH-1:7*KEEP_WIDTH] = c2s7_axis_tkeep; 	
		assign c2s_axis_tlast[7] = c2s7_axis_tlast; 		  	
		assign c2s_axis_tvalid[7] = c2s7_axis_tvalid; 		  	
		assign c2s_axis_tuser[7*32+31:7*32] = c2s7_axis_tuser; 	
		assign c2s7_axis_tready = c2s_axis_tready[7]; 	
	end
	else
	begin
		assign c2s7_axis_tready = 0;
	end
endgenerate		 

generate 
	if(NUM_OF_S2C_CHAN > 8)	
	begin
		assign s2c8_axis_tdata    = s2c_axis_tdata[8*C_DATA_WIDTH+C_DATA_WIDTH-1:8*C_DATA_WIDTH];
		assign s2c8_axis_tkeep    = s2c_axis_tkeep[8*KEEP_WIDTH+KEEP_WIDTH-1:8*KEEP_WIDTH];
		assign s2c8_axis_tlast    = s2c_axis_tlast[8];
		assign s2c8_axis_tvalid   = s2c_axis_tvalid[8];
		assign s2c8_axis_tuser    = s2c_axis_tuser[8*32+31:8*32];
		assign s2c_axis_tready[8] = s2c8_axis_tready;
	end
	else
	begin
		assign s2c8_axis_tdata    = 0;
		assign s2c8_axis_tkeep    = 0;
		assign s2c8_axis_tlast    = 0;
		assign s2c8_axis_tvalid   = 0;
		assign s2c8_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 8)	
	begin
		assign c2s_axis_tdata[8*C_DATA_WIDTH+C_DATA_WIDTH-1:8*C_DATA_WIDTH] = c2s8_axis_tdata;			  	
		assign c2s_axis_tkeep[8*KEEP_WIDTH+KEEP_WIDTH-1:8*KEEP_WIDTH] = c2s8_axis_tkeep; 	
		assign c2s_axis_tlast[8] = c2s8_axis_tlast; 		  	
		assign c2s_axis_tvalid[8] = c2s8_axis_tvalid; 		  	
		assign c2s_axis_tuser[8*32+31:8*32] = c2s8_axis_tuser; 	
		assign c2s8_axis_tready = c2s_axis_tready[8]; 	
	end
	else
	begin
		assign c2s8_axis_tready = 0;
	end
endgenerate		 
	
generate 
	if(NUM_OF_S2C_CHAN > 9)	
	begin
		assign s2c9_axis_tdata    = s2c_axis_tdata[9*C_DATA_WIDTH+C_DATA_WIDTH-1:9*C_DATA_WIDTH];
		assign s2c9_axis_tkeep    = s2c_axis_tkeep[9*KEEP_WIDTH+KEEP_WIDTH-1:9*KEEP_WIDTH];
		assign s2c9_axis_tlast    = s2c_axis_tlast[9];
		assign s2c9_axis_tvalid   = s2c_axis_tvalid[9];
		assign s2c9_axis_tuser    = s2c_axis_tuser[9*32+31:9*32];
		assign s2c_axis_tready[9] = s2c9_axis_tready;
	end
	else
	begin
		assign s2c9_axis_tdata    = 0;
		assign s2c9_axis_tkeep    = 0;
		assign s2c9_axis_tlast    = 0;
		assign s2c9_axis_tvalid   = 0;
		assign s2c9_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 9)	
	begin
		assign c2s_axis_tdata[9*C_DATA_WIDTH+C_DATA_WIDTH-1:9*C_DATA_WIDTH] = c2s9_axis_tdata;			  	
		assign c2s_axis_tkeep[9*KEEP_WIDTH+KEEP_WIDTH-1:9*KEEP_WIDTH] = c2s9_axis_tkeep; 	
		assign c2s_axis_tlast[9] = c2s9_axis_tlast; 		  	
		assign c2s_axis_tvalid[9] = c2s9_axis_tvalid; 		  	
		assign c2s_axis_tuser[9*32+31:9*32] = c2s9_axis_tuser; 	
		assign c2s9_axis_tready = c2s_axis_tready[9]; 	
	end
	else
	begin
		assign c2s9_axis_tready = 0;
	end
endgenerate		 

generate 
	if(NUM_OF_S2C_CHAN > 10)	
	begin
		assign s2c10_axis_tdata    = s2c_axis_tdata[10*C_DATA_WIDTH+C_DATA_WIDTH-1:10*C_DATA_WIDTH];
		assign s2c10_axis_tkeep    = s2c_axis_tkeep[10*KEEP_WIDTH+KEEP_WIDTH-1:10*KEEP_WIDTH];
		assign s2c10_axis_tlast    = s2c_axis_tlast[10];
		assign s2c10_axis_tvalid   = s2c_axis_tvalid[10];
		assign s2c10_axis_tuser    = s2c_axis_tuser[10*32+31:10*32];
		assign s2c_axis_tready[10] = s2c10_axis_tready;
	end
	else
	begin
		assign s2c10_axis_tdata    = 0;
		assign s2c10_axis_tkeep    = 0;
		assign s2c10_axis_tlast    = 0;
		assign s2c10_axis_tvalid   = 0;
		assign s2c10_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 10)	
	begin
		assign c2s_axis_tdata[10*C_DATA_WIDTH+C_DATA_WIDTH-1:10*C_DATA_WIDTH] = c2s10_axis_tdata;			  	
		assign c2s_axis_tkeep[10*KEEP_WIDTH+KEEP_WIDTH-1:10*KEEP_WIDTH] = c2s10_axis_tkeep; 	
		assign c2s_axis_tlast[10] = c2s10_axis_tlast; 		  	
		assign c2s_axis_tvalid[10] = c2s10_axis_tvalid; 		  	
		assign c2s_axis_tuser[10*32+31:10*32] = c2s10_axis_tuser; 	
		assign c2s10_axis_tready = c2s_axis_tready[10]; 	
	end
	else
	begin
		assign c2s10_axis_tready = 0;
	end
endgenerate		 

generate 
	if(NUM_OF_S2C_CHAN > 11)	
	begin
		assign s2c11_axis_tdata    = s2c_axis_tdata[11*C_DATA_WIDTH+C_DATA_WIDTH-1:11*C_DATA_WIDTH];
		assign s2c11_axis_tkeep    = s2c_axis_tkeep[11*KEEP_WIDTH+KEEP_WIDTH-1:11*KEEP_WIDTH];
		assign s2c11_axis_tlast    = s2c_axis_tlast[11];
		assign s2c11_axis_tvalid   = s2c_axis_tvalid[11];
		assign s2c11_axis_tuser    = s2c_axis_tuser[11*32+31:11*32];
		assign s2c_axis_tready[11] = s2c11_axis_tready;
	end
	else
	begin
		assign s2c11_axis_tdata    = 0;
		assign s2c11_axis_tkeep    = 0;
		assign s2c11_axis_tlast    = 0;
		assign s2c11_axis_tvalid   = 0;
		assign s2c11_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 11)	
	begin
		assign c2s_axis_tdata[11*C_DATA_WIDTH+C_DATA_WIDTH-1:11*C_DATA_WIDTH] = c2s11_axis_tdata;			  	
		assign c2s_axis_tkeep[11*KEEP_WIDTH+KEEP_WIDTH-1:11*KEEP_WIDTH] = c2s11_axis_tkeep; 	
		assign c2s_axis_tlast[11] = c2s11_axis_tlast; 		  	
		assign c2s_axis_tvalid[11] = c2s11_axis_tvalid; 		  	
		assign c2s_axis_tuser[11*32+31:11*32] = c2s11_axis_tuser; 	
		assign c2s11_axis_tready = c2s_axis_tready[11]; 	
	end
	else
	begin
		assign c2s11_axis_tready = 0;
	end
endgenerate		 

generate 
	if(NUM_OF_S2C_CHAN > 12)	
	begin
		assign s2c12_axis_tdata    = s2c_axis_tdata[12*C_DATA_WIDTH+C_DATA_WIDTH-1:12*C_DATA_WIDTH];
		assign s2c12_axis_tkeep    = s2c_axis_tkeep[12*KEEP_WIDTH+KEEP_WIDTH-1:12*KEEP_WIDTH];
		assign s2c12_axis_tlast    = s2c_axis_tlast[12];
		assign s2c12_axis_tvalid   = s2c_axis_tvalid[12];
		assign s2c12_axis_tuser    = s2c_axis_tuser[12*32+31:12*32];
		assign s2c_axis_tready[12] = s2c12_axis_tready;
	end
	else
	begin
		assign s2c12_axis_tdata    = 0;
		assign s2c12_axis_tkeep    = 0;
		assign s2c12_axis_tlast    = 0;
		assign s2c12_axis_tvalid   = 0;
		assign s2c12_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 12)	
	begin
		assign c2s_axis_tdata[12*C_DATA_WIDTH+C_DATA_WIDTH-1:12*C_DATA_WIDTH] = c2s12_axis_tdata;			  	
		assign c2s_axis_tkeep[12*KEEP_WIDTH+KEEP_WIDTH-1:12*KEEP_WIDTH] = c2s12_axis_tkeep; 	
		assign c2s_axis_tlast[12] = c2s12_axis_tlast; 		  	
		assign c2s_axis_tvalid[12] = c2s12_axis_tvalid; 		  	
		assign c2s_axis_tuser[12*32+31:12*32] = c2s12_axis_tuser; 	
		assign c2s12_axis_tready = c2s_axis_tready[12]; 	
	end
	else
	begin
		assign c2s12_axis_tready = 0;
	end
endgenerate		 

generate 
	if(NUM_OF_S2C_CHAN > 13)	
	begin
		assign s2c13_axis_tdata    = s2c_axis_tdata[13*C_DATA_WIDTH+C_DATA_WIDTH-1:13*C_DATA_WIDTH];
		assign s2c13_axis_tkeep    = s2c_axis_tkeep[13*KEEP_WIDTH+KEEP_WIDTH-1:13*KEEP_WIDTH];
		assign s2c13_axis_tlast    = s2c_axis_tlast[13];
		assign s2c13_axis_tvalid   = s2c_axis_tvalid[13];
		assign s2c13_axis_tuser    = s2c_axis_tuser[13*32+31:13*32];
		assign s2c_axis_tready[13] = s2c13_axis_tready;
	end
	else
	begin
		assign s2c13_axis_tdata    = 0;
		assign s2c13_axis_tkeep    = 0;
		assign s2c13_axis_tlast    = 0;
		assign s2c13_axis_tvalid   = 0;
		assign s2c13_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 13)	
	begin
		assign c2s_axis_tdata[13*C_DATA_WIDTH+C_DATA_WIDTH-1:13*C_DATA_WIDTH] = c2s13_axis_tdata;			  	
		assign c2s_axis_tkeep[13*KEEP_WIDTH+KEEP_WIDTH-1:13*KEEP_WIDTH] = c2s13_axis_tkeep; 	
		assign c2s_axis_tlast[13] = c2s13_axis_tlast; 		  	
		assign c2s_axis_tvalid[13] = c2s13_axis_tvalid; 		  	
		assign c2s_axis_tuser[13*32+31:13*32] = c2s13_axis_tuser; 	
		assign c2s13_axis_tready = c2s_axis_tready[13]; 	
	end
	else
	begin
		assign c2s13_axis_tready = 0;
	end
endgenerate		 

generate 
	if(NUM_OF_S2C_CHAN > 14)	
	begin
		assign s2c14_axis_tdata    = s2c_axis_tdata[14*C_DATA_WIDTH+C_DATA_WIDTH-1:14*C_DATA_WIDTH];
		assign s2c14_axis_tkeep    = s2c_axis_tkeep[14*KEEP_WIDTH+KEEP_WIDTH-1:14*KEEP_WIDTH];
		assign s2c14_axis_tlast    = s2c_axis_tlast[14];
		assign s2c14_axis_tvalid   = s2c_axis_tvalid[14];
		assign s2c14_axis_tuser    = s2c_axis_tuser[14*32+31:14*32];
		assign s2c_axis_tready[14] = s2c14_axis_tready;
	end
	else
	begin
		assign s2c14_axis_tdata    = 0;
		assign s2c14_axis_tkeep    = 0;
		assign s2c14_axis_tlast    = 0;
		assign s2c14_axis_tvalid   = 0;
		assign s2c14_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 14)	
	begin
		assign c2s_axis_tdata[14*C_DATA_WIDTH+C_DATA_WIDTH-1:14*C_DATA_WIDTH] = c2s14_axis_tdata;			  	
		assign c2s_axis_tkeep[14*KEEP_WIDTH+KEEP_WIDTH-1:14*KEEP_WIDTH] = c2s14_axis_tkeep; 	
		assign c2s_axis_tlast[14] = c2s14_axis_tlast; 		  	
		assign c2s_axis_tvalid[14] = c2s14_axis_tvalid; 		  	
		assign c2s_axis_tuser[14*32+31:14*32] = c2s14_axis_tuser; 	
		assign c2s14_axis_tready = c2s_axis_tready[14]; 	
	end
	else
	begin
		assign c2s14_axis_tready = 0;
	end
endgenerate		 

generate 
	if(NUM_OF_S2C_CHAN > 15)	
	begin
		assign s2c15_axis_tdata    = s2c_axis_tdata[15*C_DATA_WIDTH+C_DATA_WIDTH-1:15*C_DATA_WIDTH];
		assign s2c15_axis_tkeep    = s2c_axis_tkeep[15*KEEP_WIDTH+KEEP_WIDTH-1:15*KEEP_WIDTH];
		assign s2c15_axis_tlast    = s2c_axis_tlast[15];
		assign s2c15_axis_tvalid   = s2c_axis_tvalid[15];
		assign s2c15_axis_tuser    = s2c_axis_tuser[15*32+31:15*32];
		assign s2c_axis_tready[15] = s2c15_axis_tready;
	end
	else
	begin
		assign s2c15_axis_tdata    = 0;
		assign s2c15_axis_tkeep    = 0;
		assign s2c15_axis_tlast    = 0;
		assign s2c15_axis_tvalid   = 0;
		assign s2c15_axis_tuser    = 0;	
	end
endgenerate		
		  	
generate 
	if(NUM_OF_C2S_CHAN > 15)	
	begin
		assign c2s_axis_tdata[15*C_DATA_WIDTH+C_DATA_WIDTH-1:15*C_DATA_WIDTH] = c2s15_axis_tdata;			  	
		assign c2s_axis_tkeep[15*KEEP_WIDTH+KEEP_WIDTH-1:15*KEEP_WIDTH] = c2s15_axis_tkeep; 	
		assign c2s_axis_tlast[15] = c2s15_axis_tlast; 		  	
		assign c2s_axis_tvalid[15] = c2s15_axis_tvalid; 		  	
		assign c2s_axis_tuser[15*32+31:15*32] = c2s15_axis_tuser; 	
		assign c2s15_axis_tready = c2s_axis_tready[15]; 	
	end
	else
	begin
		assign c2s15_axis_tready = 0;
	end
endgenerate		 



endmodule
