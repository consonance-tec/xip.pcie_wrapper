library ieee;                                                               
use ieee.std_logic_1164.all;                                                
use ieee.std_logic_arith.all;                                               
use ieee.std_logic_unsigned.all;                                            
                                                                            
                                              
                                                                            
entity axi2tlp is   
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
		m_axis_rx_tkeep                : in std_logic_vector((C_DATA_WIDTH/32)-1 downto 0);
		m_axis_rx_tlast                : in  std_logic;
		m_axis_rx_tvalid               : in  std_logic;
		m_axis_rx_tready               : out std_logic;
		m_axis_rx_tuser                : in std_logic_vector(21 downto 0)
);
end axi2tlp;



architecture arc of axi2tlp is


  constant MEM_RD32_FMT_TYPE : std_logic_vector(6 downto 0) := "0000000";
  constant MEM_WR32_FMT_TYPE : std_logic_vector(6 downto 0) := "1000000";
  constant MEM_RD64_FMT_TYPE : std_logic_vector(6 downto 0) := "0100000";
  constant MEM_WR64_FMT_TYPE : std_logic_vector(6 downto 0) := "1100000";
  constant CPLD_FMT_TYPE 	  : std_logic_vector(6 downto 0) := "1001010";


-- output signals
signal rx_st_valid_int      : std_logic;                                       
signal rx_st_bardec_int 	 : STD_LOGIC_VECTOR (7 DOWNTO 0);                       
signal rx_st_be_int 		 : STD_LOGIC_VECTOR ((C_DATA_WIDTH/8)-1 DOWNTO 0);                          
signal rx_st_data_int 		 : STD_LOGIC_VECTOR (C_DATA_WIDTH-1 DOWNTO 0);   
signal rx_st_eop_int 		 : STD_LOGIC;                                             
signal rx_st_eop_int_d		 : STD_LOGIC;
signal rx_st_sop_int 		 : STD_LOGIC;
signal rx_np_ok_int         : std_logic;
signal rx_np_req_int        : std_logic;
signal rx_st_empty_int 		: std_logic_vector(1 downto 0);

-- input sig
signal m_axis_rx_tready_int : std_logic;
signal m_axis_rx_tdata_int  : std_logic_vector((C_DATA_WIDTH - 1) downto 0);
signal m_axis_rx_tkeep_int  : std_logic_vector((C_DATA_WIDTH/32)-1 downto 0);
signal m_axis_rx_tlast_int  : std_logic;
signal m_axis_rx_tvalid_int : std_logic;
signal m_axis_rx_tuser_int  : std_logic_vector(21 downto 0);


attribute keep: boolean;
	
attribute keep of m_axis_rx_tready_int : signal is true;
attribute keep of m_axis_rx_tdata_int  : signal is true;
attribute keep of m_axis_rx_tkeep_int  : signal is true;
attribute keep of m_axis_rx_tlast_int  : signal is true;
attribute keep of m_axis_rx_tvalid_int : signal is true;
attribute keep of m_axis_rx_tuser_int  : signal is true;
                                   	
attribute keep of rx_st_valid_int  	: signal is true;
attribute keep of rx_st_bardec_int 	: signal is true;  
attribute keep of rx_st_be_int 	   	: signal is true;                        
attribute keep of rx_st_data_int   	: signal is true;
attribute keep of rx_st_eop_int    	: signal is true;      
attribute keep of rx_st_sop_int    	: signal is true;
attribute keep of rx_np_ok_int     	: signal is true;
attribute keep of rx_np_req_int  	: signal is true;


begin


	rx_np_ok_int        <= '1';
	rx_np_req_int       <= '1';


C_DATA_WIDTH_64_gen: if C_DATA_WIDTH = 64 generate
 
 
 input_sampling : process(clk_in)
 begin
	if(clk_in'event and clk_in = '1')then
		m_axis_rx_tready_int <= rx_st_ready;
		m_axis_rx_tdata_int  <= m_axis_rx_tdata;
		m_axis_rx_tkeep_int  <= m_axis_rx_tkeep;
		m_axis_rx_tlast_int  <= m_axis_rx_tlast;
		m_axis_rx_tvalid_int <= m_axis_rx_tvalid;
		m_axis_rx_tuser_int  <= m_axis_rx_tuser;
		
	end if;
 end process;
 
 	
 	rx_st_eop_int 	<= m_axis_rx_tlast;
 	rx_st_sop_int	<= (m_axis_rx_tvalid and not m_axis_rx_tvalid_int) or (m_axis_rx_tlast_int and m_axis_rx_tvalid);
 	rx_st_be_int 	<= m_axis_rx_tkeep;
	rx_st_valid_int	<= m_axis_rx_tvalid;
 	rx_st_data_int	<= m_axis_rx_tdata;
	rx_st_bardec_int <= m_axis_rx_tuser_int(9 downto 2);
 	
 end generate;



 C_DATA_WIDTH_128_gen: if C_DATA_WIDTH = 128 generate
 process(clk_in)
 begin
	if(clk_in'event and clk_in = '1')then
		if rstn = '0'then
			
			 rx_st_valid_int     <= '0';                                       
			 rx_st_bardec_int 	 <= (others => '0');
			 rx_st_be_int 		 <= (others => '0');                          
			 rx_st_data_int 	 <= (others => '0');   
			 rx_st_eop_int 		 <= '0';                                             
			 rx_st_sop_int 		 <= '0';
			 rx_st_empty_int 	 <= (others => '0');   

					
		else

			rx_st_eop_int 		 <= '0';                                             
			rx_st_sop_int 		 <= '0';
			
			rx_st_empty_int 	<= "00";
				
			rx_st_data_int <= m_axis_rx_tdata_int;
			
			rx_st_valid_int <= m_axis_rx_tvalid_int;
			
			-- SOF dectec
			--if  m_axis_rx_tvalid_int = '1' and rx_st_valid_int = '0' then
			if  (m_axis_rx_tvalid_int = '1' and rx_st_valid_int = '0') or (rx_st_eop_int_d = '1' and m_axis_rx_tvalid = '1') then
				rx_st_sop_int <= '1';
				rx_st_bardec_int <= m_axis_rx_tuser_int(9 downto 2);
			end if;

			rx_st_eop_int <= m_axis_rx_tlast;			
						
			rx_st_be_int <= (others => '1');

			-- if eof with no sof	
			if m_axis_rx_tlast = '1' then
				-- EOF bytes aligment				
				case m_axis_rx_tkeep(3 downto 0) is
					when "0001" =>
						rx_st_be_int <= x"000f";
						rx_st_empty_int <= "01";  
					when "0011" =>
						rx_st_be_int <= x"00ff";
						rx_st_empty_int <= "01";
					when "0111" =>
						rx_st_be_int <= x"0fff";
					when "1111" =>
						rx_st_be_int <= x"ffff";
					when others => 
						rx_st_be_int <= x"ffff";
				end case;
			end if;	
			
			 
			
		end if;
	end if;
 end process;
 
 
input_sampling : process(clk_in)
 begin
	if(clk_in'event and clk_in = '1')then
		m_axis_rx_tready_int <= rx_st_ready;
		m_axis_rx_tdata_int  <= m_axis_rx_tdata;
		m_axis_rx_tkeep_int  <= m_axis_rx_tkeep;
		m_axis_rx_tlast_int  <= m_axis_rx_tlast;
		m_axis_rx_tvalid_int <= m_axis_rx_tvalid;
		m_axis_rx_tuser_int  <= m_axis_rx_tuser;
		
		rx_st_eop_int_d <= rx_st_eop_int;
		
		rx_st_be 		  <= rx_st_be_int;                          
		rx_st_eop 		  <= rx_st_eop_int; 
		rx_st_empty		  <= rx_st_empty_int;                                            
		
	end if;
 end process; 
 
 rx_st_valid      <= rx_st_valid_int;                                       
 rx_st_bardec 	  <= rx_st_bardec_int;
 rx_st_data 	  <= rx_st_data_int;   
 rx_st_sop 		  <= rx_st_sop_int;
 rx_np_ok         <= rx_np_ok_int;
 rx_np_req        <= rx_np_req_int;
 m_axis_rx_tready <= m_axis_rx_tready_int;
 
 
 end generate;
 
 
  C_DATA_WIDTH_256_gen: if C_DATA_WIDTH = 256 generate
 process(clk_in)
 begin
	if(clk_in'event and clk_in = '1')then
		if rstn = '0'then
			
			 rx_st_valid_int     <= '0';                                       
			 rx_st_bardec_int 	 <= (others => '0');
			 rx_st_be_int 		 <= (others => '0');                          
			 rx_st_data_int 	 <= (others => '0');   
			 rx_st_eop_int 		 <= '0';                                             
			 rx_st_sop_int 		 <= '0';
			 rx_st_empty_int 	 <= (others => '0');  
					
		else

			rx_st_eop_int 		 <= '0';                                             
			rx_st_sop_int 		 <= '0';
				
			rx_st_data_int <= m_axis_rx_tdata_int;
			
			rx_st_valid_int <= m_axis_rx_tvalid_int;
			
			-- SOF dectec
			if m_axis_rx_tvalid_int = '1' and m_axis_rx_tuser_int(14) = '1' then
				rx_st_sop_int <= '1';
				rx_st_bardec_int <= m_axis_rx_tuser_int(9 downto 2);
			end if;

						
			-- EOF detected
			if m_axis_rx_tvalid_int = '1' and m_axis_rx_tuser_int(21) = '1' then
				rx_st_eop_int <= '1';
			end if;
			
			rx_st_be_int <= (others => '1');
			
			
			

			
		end if;
	end if;
 end process;
 
 
input_sampling : process(clk_in)
 begin
	if(clk_in'event and clk_in = '1')then
		m_axis_rx_tready_int <= rx_st_ready;
		m_axis_rx_tdata_int  <= m_axis_rx_tdata;
		m_axis_rx_tkeep_int  <= m_axis_rx_tkeep;
		m_axis_rx_tlast_int  <= m_axis_rx_tlast;
		m_axis_rx_tvalid_int <= m_axis_rx_tvalid;
		m_axis_rx_tuser_int  <= m_axis_rx_tuser;
		
		
		
	end if;
 end process; 

 rx_st_valid      <= rx_st_valid_int;                                       
 rx_st_bardec 	  <= rx_st_bardec_int;
 rx_st_be 		  <= rx_st_be_int;                          
 rx_st_data 	  <= rx_st_data_int;   
 rx_st_eop 		  <= rx_st_eop_int;                                             
 rx_st_sop 		  <= rx_st_sop_int;
 rx_np_ok         <= rx_np_ok_int;
 rx_np_req        <= rx_np_req_int;
 m_axis_rx_tready <= m_axis_rx_tready_int;
  
 end generate;
 
 
 
 
 
  
end arc;                                                                                                    
                                                                            
            		                                                              
                                                                         