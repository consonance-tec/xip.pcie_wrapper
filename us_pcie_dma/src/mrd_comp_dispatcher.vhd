
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use     ieee.math_real.all;

entity mrd_comp_dispatcher is
generic 	
(
	NUM_OF_SG_CHANNLES	 : integer := 1;
	PCIE_CORE_DATA_WIDTH : integer := 128;
	AXI4_RC_TUSER_WIDTH	  : integer := 75; 
	FIXED_QUAD_LIGEND	 : integer := 0	
	
);
port
(

	clk                 : in  std_logic;
  	rstn                : in  std_logic;
	

 	tag_request			: in  std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	tag_valid			: out std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	context				: in  std_logic_vector(NUM_OF_SG_CHANNLES*32-1 downto 0);
	bm_sys_addr			: in  std_logic_vector((64*NUM_OF_SG_CHANNLES)-1 downto 0);
	tag					: out std_logic_vector(7 downto 0);
	
	axis_rc_tvalid      : in  std_logic;
	axis_rc_tkeep		: in  std_logic_vector ((PCIE_CORE_DATA_WIDTH/32)-1 DOWNTO 0);
	axis_rc_tdata 		: in  std_logic_vector (PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
	axis_rc_tuser 		: in  std_logic_vector(AXI4_RC_TUSER_WIDTH-1 DOWNTO 0);
	axis_rc_tlast		: in  STD_LOGIC;
	axis_rc_tready		: out  std_logic;
			 
	bm_data				: out std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	bm_be             	: out std_logic_vector(PCIE_CORE_DATA_WIDTH/8-1 downto 0);
	bm_rx_done			: out std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	bm_rx_active		: out std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	bm_rx_rdy			: in  std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	bm_context			: out std_logic_vector(31 downto 0)
	
);
end mrd_comp_dispatcher;

architecture arc of mrd_comp_dispatcher is

component rc_to_tlp 
generic
(
	PCIE_CORE_DATA_WIDTH	: integer := 128;
	AXI4_RC_TUSER_WIDTH   : integer  := 75

);
port 
( 
	clk_i                 	: in std_logic;
	rstn_i                	: in std_logic;
	
	m_axis_tvalid       	:  out std_logic;
	m_axis_tready       	:  in  std_logic;
	m_axis_tdata 			:  out STD_LOGIC_VECTOR (PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
	m_axis_tlast 			:  out STD_LOGIC;
	m_axis_tuser 			:  out std_logic;
	m_axis_tkeep	    	:  out STD_LOGIC_VECTOR (PCIE_CORE_DATA_WIDTH/32-1 DOWNTO 0);
	
	
	
	-- xilinx Requestor Complete AXI Stream interface3
   	s_axis_rc_tdata			: in  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
   	s_axis_rc_tuser			: in  std_logic_vector(AXI4_RC_TUSER_WIDTH-1 downto 0);
   	s_axis_rc_tlast			: in  std_logic;
   	s_axis_rc_tkeep			: in  std_logic_vector(PCIE_CORE_DATA_WIDTH/32-1 downto 0);
   	s_axis_rc_tvalid		: in  std_logic;
   	s_axis_rc_tready		: out std_logic_vector(0 downto 0)
   	
	

);
end component;


component tag_alloc_wrapper is
generic 	
(
	NUM_OF_SG_CHANNLES	 : integer := 1;
	PCIE_CORE_DATA_WIDTH : integer := 128;
	FIXED_QUAD_LIGEND	 : integer := 0	
	
);
port
(

	clk_i                 	: in  std_logic;
  	rstn_i                	: in  std_logic;
	

 	tag_request_i			: in  std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	tag_valid_o				: out std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	context_i				: in  std_logic_vector(NUM_OF_SG_CHANNLES*32-1 downto 0);
	bm_sys_addr_i			: in  std_logic_vector((64*NUM_OF_SG_CHANNLES)-1 downto 0);
	tag_o					: out std_logic_vector(7 downto 0);
	
	rx_st_valid_i       	: in  std_logic;
	rx_st_be_i 				: in  std_logic_vector ((PCIE_CORE_DATA_WIDTH/8)-1 DOWNTO 0);
	rx_st_data_i 			: in  std_logic_vector (PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
	rx_st_eop_i 			: in  STD_LOGIC;
	rx_st_sop_i 			: in  STD_LOGIC;
	rx_st_empty_i			: in  std_logic_vector (1 DOWNTO 0);
	
			 
	bm_data_o			   	: out std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	bm_be_o             	: out std_logic_vector(PCIE_CORE_DATA_WIDTH/8-1 downto 0);
	bm_rx_done_o		   	: out std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	bm_rx_active_o		  	: out std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	bm_rx_rdy_i				: in  std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	bm_context_o			: out std_logic_vector(31 downto 0)
	
);
end component;

component axi2tlp is   
   generic (
      C_DATA_WIDTH : integer range 64 to 256 := 64
    );
	port                                                                       
	(                                                                          
	                                                                           
		clk_in              : in std_logic;                                       
      	rstn                : in std_logic;                                  
		                                                                          
		-- Rx Port                                                                
		rx_st_valid       	:  out std_logic;                                       
		rx_st_ready       	:  in  std_logic;                                     
		rx_st_bardec 		:  out STD_LOGIC_VECTOR (7 DOWNTO 0);                       
		rx_st_be 			:  out STD_LOGIC_VECTOR ((C_DATA_WIDTH/8)-1 DOWNTO 0);                          
		rx_st_data 			:  out STD_LOGIC_VECTOR (C_DATA_WIDTH-1 DOWNTO 0);   
		rx_st_eop 			:  out STD_LOGIC;                                             
		rx_st_sop 			:  out STD_LOGIC;
		rx_st_empty	    	:  out STD_LOGIC_VECTOR (1 DOWNTO 0);
		
 		------------------------- AXI Tx Interface -----------------------
		rx_np_ok                       : out std_logic;
		rx_np_req                      : out std_logic;
		m_axis_rx_tdata                : in std_logic_vector((C_DATA_WIDTH - 1) downto 0);
		m_axis_rx_tkeep                : in std_logic_vector((C_DATA_WIDTH/32-1) downto 0);
		m_axis_rx_tlast                : in  std_logic;
		m_axis_rx_tvalid               : in  std_logic;
		m_axis_rx_tready               : out std_logic;
		m_axis_rx_tuser                : in std_logic_vector(21 downto 0)
);
end component;

signal rx_st_valid    	: std_logic;
signal rx_st_be 			: std_logic_vector ((PCIE_CORE_DATA_WIDTH/8)-1 DOWNTO 0);
signal rx_st_data 		: std_logic_vector (PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
signal rx_st_eop 		: std_logic;
signal rx_st_sop 		: std_logic;
signal rx_st_empty		: std_logic_vector (1 DOWNTO 0);

signal m_axis_tvalid    :  std_logic;
signal m_axis_tready    :  std_logic;
signal m_axis_tdata 	:  STD_LOGIC_VECTOR (PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
signal m_axis_tlast 	:  STD_LOGIC;
signal m_axis_tuser 	:  std_logic;
signal m_axis_tkeep	    :  STD_LOGIC_VECTOR (PCIE_CORE_DATA_WIDTH/32-1 DOWNTO 0);

signal m_axis_rx_tuser_int : std_logic_vector(21 downto 0);

begin

rc_to_tlp_i : rc_to_tlp 
generic map
(
	PCIE_CORE_DATA_WIDTH	=> PCIE_CORE_DATA_WIDTH,
	AXI4_RC_TUSER_WIDTH   	=> AXI4_RC_TUSER_WIDTH	

)
port map 
( 
	clk_i 			=> clk, 
  	rstn_i          => rstn,
	
	--  tlp 
	m_axis_tvalid   =>  	m_axis_tvalid,
	m_axis_tready   =>  	m_axis_tready,
	m_axis_tdata 	=>		m_axis_tdata,
	m_axis_tlast 	=>		m_axis_tlast,
	m_axis_tuser 	=>		m_axis_tuser,
	m_axis_tkeep	=>  	m_axis_tkeep,
	                                                                                                    
		
	-- xilinx Requestor Complete AXI Stream interface3
   	s_axis_rc_tdata		=> axis_rc_tdata,	
   	s_axis_rc_tuser		=> axis_rc_tuser,	
   	s_axis_rc_tlast		=> axis_rc_tlast,	
   	s_axis_rc_tkeep		=> axis_rc_tkeep,	
   	s_axis_rc_tvalid	=> axis_rc_tvalid,
   	s_axis_rc_tready(0)	=> axis_rc_tready
   	
	

);


tag_alloc_wrapper_i : tag_alloc_wrapper 
generic map	
(
	NUM_OF_SG_CHANNLES	 => NUM_OF_SG_CHANNLES,
	PCIE_CORE_DATA_WIDTH => PCIE_CORE_DATA_WIDTH,
	FIXED_QUAD_LIGEND	 => FIXED_QUAD_LIGEND
	
)
port map
(

	clk_i 			=> clk, 
  	rstn_i          => rstn,
	

 	tag_request_i	=> tag_request,	
	tag_valid_o		=> tag_valid,	  
	context_i		=> context,		   
	bm_sys_addr_i	=> bm_sys_addr,	
	tag_o			=> tag,			      
	
	rx_st_valid_i    =>  rx_st_valid,
	rx_st_be_i 		 =>  rx_st_be, 	 
	rx_st_data_i 	 =>  rx_st_data, 
	rx_st_eop_i 	 =>  rx_st_eop,  
	rx_st_sop_i 	 =>  rx_st_sop,  
	rx_st_empty_i	 =>  rx_st_empty,
	
			 
	bm_data_o		=> bm_data,		   
	bm_be_o         => bm_be,       
	bm_rx_done_o	=> bm_rx_done,	 
	bm_rx_active_o	=> bm_rx_active,
	bm_rx_rdy_i		=> bm_rx_rdy,	  
	bm_context_o	=> bm_context	 
	
);
	


axi2tlp_i : axi2tlp   
generic map
(
	C_DATA_WIDTH => PCIE_CORE_DATA_WIDTH
)
port map                                                                       
(                                                                          
                                                                           
	clk_in              => clk,                                       
  	rstn                => rstn,                                 
  	                                                        
	-- Rx Port                                                                
	rx_st_valid       	=>  rx_st_valid,                                       
	rx_st_ready       	=> '1',                                    
	rx_st_bardec 		=> open,                    
	rx_st_be 			=> rx_st_be, 	                      
	rx_st_data 			=> rx_st_data, 
	rx_st_eop 			=> rx_st_eop,     
	rx_st_sop 			=> rx_st_sop, 
	rx_st_empty			=> rx_st_empty, 
	
	------------------------- AXI Tx Interface -----------------------
	rx_np_ok            => open,
	rx_np_req           => open,
	
	m_axis_rx_tdata     => m_axis_tdata,
	m_axis_rx_tkeep     => m_axis_tkeep,
	m_axis_rx_tlast     => m_axis_tlast, 
	m_axis_rx_tvalid    => m_axis_tvalid, 
	m_axis_rx_tready    => m_axis_tready, 
	m_axis_rx_tuser     => m_axis_rx_tuser_int	
);
	
m_axis_rx_tuser_int     <= "000000000000000000000" & m_axis_tuser;		
	
end arc;