--============================================================================================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;


entity tx_dispatcher is	
generic
(
    PCIE_CORE_DATA_WIDTH    : integer := 256;
    AXI4_RQ_TUSER_WIDTH     : integer := 60;  
	KEEP_WIDTH              : integer := 256/32    
);
port
(
	clk_in        		: in std_logic;
	rstn          		: in std_logic;
	
	completer_id 		: in std_logic_vector(15 downto 0);
	
	rearbit_sig			: out std_logic;
	                	
	mrd_tx_req			: in  std_logic;
	mrd_tx_done	    	: out std_logic;
	mrd_tx_tag			: in  std_logic_vector(7 downto 0);
	mrd_tx_len			: in  std_logic_vector(12 downto 0);
	mrd_tx_addr			: in  std_logic_vector(63 downto 0);
	
	mwr_tx_data			: in  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0); -- data to send 
	mwr_tx_req			: in  std_logic; -- request a burst to send
	mwr_tx_data_req		: out std_logic; -- request next data to send 
	mwr_tx_ack			: out std_logic; -- request acknowlage, burst started
	mwr_tx_done	        : out std_logic; -- bust is done
	mwr_tx_burst_len	: in  std_logic_vector(12 downto 0);
	mwr_tx_addr			: in  std_logic_vector(63 downto 0);
	mwr_tx_tag			: in  std_logic_vector(7 downto 0);
	
	status_tx_req		: in std_logic;
	status_tx_done	    : out  std_logic;
	status_tx_qword		: in std_logic_vector(63 downto 0);
	status_tx_addr		: in std_logic_vector(63 downto 0);

	m_axis_rq_tdata 	: out std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);   		 
	m_axis_rq_tuser 	: out std_logic_vector(AXI4_RQ_TUSER_WIDTH-1 downto 0);  
	m_axis_rq_tlast 	: out std_logic;                             			 
	m_axis_rq_tkeep 	: out std_logic_vector(KEEP_WIDTH-1 downto 0);   		 
	m_axis_rq_tvalid	: out std_logic;                             			 
	m_axis_rq_tready	: in  std_logic                            				 
		
	           	
	
);
end tx_dispatcher;



architecture arc of tx_dispatcher is

component tlp_param	
port
(
	tx_len		: in  std_logic_vector(12 downto 0);
	
	tlp_fbe 	: out std_logic_vector(3 downto 0);
	tlp_lbe 	: out std_logic_vector(3 downto 0);
	tlp_dw_len 	: out std_logic_vector(10 downto 0)	
);
end component;

	
signal mrd_tlp_fbe 	 	: std_logic_vector(3 downto 0);
signal mrd_tlp_lbe 	 	: std_logic_vector(3 downto 0);
signal mrd_tlp_dw_len 	: std_logic_vector(10 downto 0);	


signal mwr_tlp_fbe 	 	: std_logic_vector(3 downto 0);
signal mwr_tlp_lbe 	 	: std_logic_vector(3 downto 0);
signal mwr_tlp_dw_len 	: std_logic_vector(10 downto 0);	


signal status_tlp_fbe 	 	: std_logic_vector(3 downto 0);
signal status_tlp_lbe 	 	: std_logic_vector(3 downto 0);
signal status_tlp_dw_len 	: std_logic_vector(10 downto 0);	

signal axis_rq_tvalid_int	: std_logic;
signal axis_rq_tdata_int 	: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);   		 
signal axis_rq_tuser_int 	: std_logic_vector(AXI4_RQ_TUSER_WIDTH-1 downto 0);  
signal axis_rq_tlast_int 	: std_logic;                             			 
signal axis_rq_tkeep_int 	: std_logic_vector(KEEP_WIDTH-1 downto 0);   		 

signal mwr_tx_data_d : std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
signal mwr_dw_left : integer range 0 to 1024;
signal status_tx_qword_int	: std_logic_vector(63 downto 0);
signal status_pending : std_logic;

signal mrd_tx_done_int	    	:  std_logic;
signal status_tx_done_int	    :  std_logic;
signal mwr_tx_done_int	        :  std_logic;

signal mrd_tx_len13 : std_logic_vector(12 downto 0);

 attribute keep: string;

 attribute keep of axis_rq_tvalid_int : signal is "ture"; 
 attribute keep of axis_rq_tdata_int  : signal is "ture"; 
 attribute keep of axis_rq_tuser_int  : signal is "ture"; 
 attribute keep of axis_rq_tlast_int : signal is "ture"; 
 attribute keep of axis_rq_tkeep_int  : signal is "ture"; 



begin

tx_proc_128: if PCIE_CORE_DATA_WIDTH = 128 generate

 process(clk_in)
 begin
 	if rising_edge(clk_in) then
		if rstn = '0' then

			axis_rq_tdata_int 	<= (others => '0'); 	 
			axis_rq_tuser_int 	<= (others => '0'); 
			axis_rq_tlast_int 	<= '0'; 			
			axis_rq_tkeep_int 	<= (others => '0'); 
			axis_rq_tvalid_int	<= '0'; 
			
			status_tx_done_int	    <= '0';
			mrd_tx_done_int	    	<= '0';
			mwr_tx_done_int	        <= '0';
			
			mwr_tx_data_req		<= '0';
			mwr_tx_ack			<= '0';
			
			rearbit_sig <= '0';
			
			mwr_dw_left			<= 0;
			status_pending		<= '0';
					
		else

			status_tx_done_int	    <= '0';
			mrd_tx_done_int	    	<= '0';
			mwr_tx_done_int	        <= '0';
		
			axis_rq_tdata_int 	<= (others => '0'); 	 
			axis_rq_tuser_int 	<= (others => '0'); 
			axis_rq_tlast_int 	<= '0'; 			
			axis_rq_tkeep_int 	<= (others => '0'); 
			axis_rq_tvalid_int	<= '0'; 
			
			rearbit_sig <= '0';
			
			mwr_tx_ack	<= '0';
			
			mwr_tx_data_req <= '0';
			
			
			if axis_rq_tvalid_int	= '1' and m_axis_rq_tready = '0' then

				axis_rq_tdata_int 	<= 	axis_rq_tdata_int;
				axis_rq_tlast_int	<= axis_rq_tlast_int;
				axis_rq_tkeep_int	<= axis_rq_tkeep_int;
		   		axis_rq_tvalid_int	<= axis_rq_tvalid_int;
				axis_rq_tuser_int <= axis_rq_tuser_int;
				
				
			elsif status_pending = '1' then
				status_pending <= '0';
				rearbit_sig <= '1';
				axis_rq_tdata_int <= 	x"0000000000000000" & status_tx_qword_int;
										 
				axis_rq_tlast_int		<= '1';
				axis_rq_tkeep_int		<= "0011";
		   		axis_rq_tvalid_int		<= '1';
				
				axis_rq_tuser_int <= (others => '0');		-- Parity
				
				rearbit_sig <= '1';
								
			elsif mwr_dw_left > 0 then
				
				
				axis_rq_tdata_int <= mwr_tx_data;
				axis_rq_tvalid_int		<= '1';
				
				if mwr_dw_left > PCIE_CORE_DATA_WIDTH/32 then
					mwr_tx_data_req		<= '1';
				end if;
				
				mwr_dw_left <= mwr_dw_left - PCIE_CORE_DATA_WIDTH/32;
				if not(mwr_dw_left > PCIE_CORE_DATA_WIDTH/32)then
					axis_rq_tlast_int <= '1';
					rearbit_sig <= '1';
				end if;

				case mwr_dw_left is
					when 1 =>
						axis_rq_tkeep_int		<= x"1";
					when 2 => 	
						axis_rq_tkeep_int		<= x"3";
					when 3 => 
						axis_rq_tkeep_int		<= x"7";
					when others => 
						axis_rq_tkeep_int		<= x"f";
		   		end case;
							
										
			elsif mrd_tx_req = '1' and mrd_tx_done_int = '0' then
			
				mrd_tx_done_int <= '1';
				axis_rq_tdata_int <= 	x"00" & x"0000" & mrd_tx_tag 					-- 127:96 
										& completer_id & '0' &  "0000" & mrd_tlp_dw_len 	-- 95:64
										& mrd_tx_addr(63 downto 2) & "00"; 				--addr and at (AT) 63:0
										 
				axis_rq_tlast_int		<= '1';
				axis_rq_tkeep_int		<= x"f";
		   		axis_rq_tvalid_int		<= '1';
				
				axis_rq_tuser_int <= x"00000000"		-- Parity
            	                       & "0000"        	-- Seq Number
            	                       & x"00"         	-- TPH Steering Tag
            	                       & '0'           	-- TPH indirect Tag Enable
            	                       & "00"          	-- TPH Type
            	                       & '0'           	-- TPH Present
            	                       & '0'           	-- Discontinue
            	                       & "000"         	-- Byte Lane number in case of Address Aligned mode
            	                       & mrd_tlp_lbe 		-- Last BE of the Read Data
            	                       & mrd_tlp_fbe; 		-- First BE of the Read Data
            	                       
            	                       
			elsif status_tx_req = '1' and status_tx_done_int = '0' then 
				status_pending <= '1';
				status_tx_done_int <= '1';
				status_tx_qword_int <= status_tx_qword;

				axis_rq_tdata_int <= 	x"00" & x"0000" & "00000000"--status_tx_tag 					-- 127:96 
										& completer_id & '0' &  "0001" & status_tlp_dw_len 	-- 95:64
										& status_tx_addr(63 downto 2) & "00"; 				--addr and at (AT) 63:0
										 
				axis_rq_tlast_int		<= '0';
				axis_rq_tkeep_int		<= x"f";
		   		axis_rq_tvalid_int		<= '1';
		   		
				axis_rq_tuser_int <= x"00000000"		-- Parity
            	                       & "0000"        	-- Seq Number
            	                       & x"00"         	-- TPH Steering Tag
            	                       & '0'           	-- TPH indirect Tag Enable
            	                       & "00"          	-- TPH Type
            	                       & '0'           	-- TPH Present
            	                       & '0'           	-- Discontinue
            	                       & "000"         	-- Byte Lane number in case of Address Aligned mode
            	                       & status_tlp_lbe 		-- Last BE of the Read Data
            	                       & status_tlp_fbe; 		-- First BE of the Read Data
		   		
								
			elsif mwr_tx_req = '1' and mwr_tx_done_int = '0' then
				mwr_tx_ack <= '1';
				mwr_tx_done_int	        <= '1';
				mwr_dw_left <= conv_integer(mwr_tlp_dw_len);
				mwr_tx_data_req <= '1';
				
				axis_rq_tdata_int <= 	x"00" & x"0000" & mwr_tx_tag 					-- 127:96 
										& completer_id & '0' &  "0001" & mwr_tlp_dw_len 	-- 95:64
										& mwr_tx_addr(63 downto 2) & "00"; 				--addr and at (AT) 63:0
										 
				axis_rq_tlast_int		<= '0';
				axis_rq_tkeep_int		<= x"f";
		   		axis_rq_tvalid_int		<= '1';
		   		
				axis_rq_tuser_int <= x"00000000"		-- Parity
            	                       & "0000"        	-- Seq Number
            	                       & x"00"         	-- TPH Steering Tag
            	                       & '0'           	-- TPH indirect Tag Enable
            	                       & "00"          	-- TPH Type
            	                       & '0'           	-- TPH Present
            	                       & '0'           	-- Discontinue
            	                       & "000"         	-- Byte Lane number in case of Address Aligned mode
            	                       & mwr_tlp_lbe 		-- Last BE of the Read Data
            	                       & mwr_tlp_fbe; 		-- First BE of the Read Data
		   		
			
			end if;
		end if; 	
 	end if;
 end process;

end generate;

tx_proc_256: if PCIE_CORE_DATA_WIDTH = 256 generate


 process(clk_in)
 begin
 	if rising_edge(clk_in) then
		if rstn = '0' then

			axis_rq_tdata_int 	<= (others => '0'); 	 
			axis_rq_tuser_int 	<= (others => '0'); 
			axis_rq_tlast_int 	<= '0'; 			
			axis_rq_tkeep_int 	<= (others => '0'); 
			axis_rq_tvalid_int	<= '0'; 
			
			status_tx_done_int	    <= '0';
			mrd_tx_done_int	    	<= '0';
			mwr_tx_done_int	        <= '0';
			
			mwr_tx_data_req		<= '0';
			mwr_tx_ack			<= '0';
			
			
			mwr_dw_left			<= 0;
					
		else

			status_tx_done_int	    <= '0';
			mrd_tx_done_int	    	<= '0';
			mwr_tx_done_int	        <= '0';
		
			axis_rq_tdata_int 	<= (others => '0'); 	 
			axis_rq_tuser_int 	<= (others => '0'); 
			axis_rq_tlast_int 	<= '0'; 			
			axis_rq_tkeep_int 	<= (others => '0'); 
			axis_rq_tvalid_int	<= '0'; 
			
			status_tx_done_int	    <= '0';
			mrd_tx_done_int	    	<= '0';
			mwr_tx_done_int	        <= '0';
			
			mwr_tx_data_req		<= '0';
			mwr_tx_ack			<= '0';
			

			
			if axis_rq_tvalid_int	= '1' and m_axis_rq_tready = '0' then

				axis_rq_tdata_int 	<= 	axis_rq_tdata_int;
				axis_rq_tlast_int	<= axis_rq_tlast_int;
				axis_rq_tkeep_int	<= axis_rq_tkeep_int;
		   		axis_rq_tvalid_int	<= axis_rq_tvalid_int;
				axis_rq_tuser_int <= axis_rq_tuser_int;
							
			elsif mwr_dw_left > 0 then
				
				mwr_dw_left <= mwr_dw_left - PCIE_CORE_DATA_WIDTH/32;
				axis_rq_tdata_int <= mwr_tx_data(127 downto 0) & mwr_tx_data_d(255 downto 128);
				axis_rq_tvalid_int		<= '1';
				
				if mwr_dw_left > PCIE_CORE_DATA_WIDTH/32 then
					mwr_tx_data_req		<= '1';
				end if;
				
				if not(mwr_dw_left > PCIE_CORE_DATA_WIDTH/32)then
					axis_rq_tlast_int <= '1';
				end if;

				if mwr_dw_left = 1 then
					axis_rq_tkeep_int <= x"01";
				elsif mwr_dw_left = 2 then
					axis_rq_tkeep_int <= x"03";
				elsif mwr_dw_left = 3 then
					axis_rq_tkeep_int <= x"07";
				elsif mwr_dw_left = 4 then
					axis_rq_tkeep_int <= x"0F";
				elsif mwr_dw_left = 5 then
					axis_rq_tkeep_int <= x"1F";
				elsif mwr_dw_left = 6 then
					axis_rq_tkeep_int <= x"3F";
				elsif mwr_dw_left = 7 then
					axis_rq_tkeep_int <= x"7F";
				elsif mwr_dw_left = 8 then
					axis_rq_tkeep_int <= x"FF";
				end if;	
										
			elsif mrd_tx_req = '1' then
			
				mrd_tx_done_int <= '1';
				axis_rq_tdata_int <= 	  x"0000000000000000"
										& x"0000000000000000"
										& x"00" & x"0000" & mrd_tx_tag 					-- 127:96 
										& completer_id & '0' &  "0000" & mrd_tlp_dw_len 	-- 95:64
										& mrd_tx_addr(63 downto 2) & "00"; 				--addr and at (AT) 63:0
										 
				axis_rq_tlast_int		<= '1';
				axis_rq_tkeep_int		<= x"0f";
		   		axis_rq_tvalid_int		<= '1';
				
				axis_rq_tuser_int <= x"00000000"		-- Parity
            	                       & "0000"        	-- Seq Number
            	                       & x"00"         	-- TPH Steering Tag
            	                       & '0'           	-- TPH indirect Tag Enable
            	                       & "00"          	-- TPH Type
            	                       & '0'           	-- TPH Present
            	                       & '0'           	-- Discontinue
            	                       & "000"         	-- Byte Lane number in case of Address Aligned mode
            	                       & mrd_tlp_lbe 		-- Last BE of the Read Data
            	                       & mrd_tlp_fbe; 		-- First BE of the Read Data
            	                       
			elsif status_tx_req = '1' then 
				status_pending <= '1';
				status_tx_done <= '1';
				
				axis_rq_tdata_int <= 	x"0000000000000000"
										& status_tx_qword
										& x"00" & x"0000" & "00000000"--status_tx_tag 					-- 127:96 
										& completer_id & '0' &  "0000" & status_tlp_dw_len 	-- 95:64
										& status_tx_addr(63 downto 2) & "00"; 				--addr and at (AT) 63:0
										 
				axis_rq_tlast_int		<= '1';
				axis_rq_tkeep_int		<= x"3f";
		   		axis_rq_tvalid_int		<= '1';
								
			elsif mwr_tx_req = '1' then
				mwr_tx_ack <= '1';
				mwr_dw_left <= conv_integer(mwr_tlp_dw_len) - 8;
				axis_rq_tdata_int <= 	mwr_tx_data(127 downto 0)
										& x"00" & x"0000" & mwr_tx_tag 					-- 127:96 
										& completer_id & '0' &  "0000" & mwr_tlp_dw_len 	-- 95:64
										& mwr_tx_addr(63 downto 2) & "00"; 				--addr and at (AT) 63:0
				axis_rq_tvalid_int		<= '1';						 
				
				if not(mwr_dw_left > 4) then
					axis_rq_tlast_int		<= '1';
				end if;	
					   		
				if mwr_dw_left = 1 then
					axis_rq_tkeep_int <= x"1F";
				elsif mwr_dw_left = 2 then
					axis_rq_tkeep_int <= x"3F";
				elsif mwr_dw_left = 3 then
					axis_rq_tkeep_int <= x"7F";
				elsif mwr_dw_left = 4 then
					axis_rq_tkeep_int <= x"FF";
				end if;	
			end if; 
		end if; 
 	end if; 
 end process;



 process(clk_in)
 begin
 	if rising_edge(clk_in) then
		mwr_tx_data_d <= mwr_tx_data;
	end if;
 end process;
 
end generate;

mrd_tx_len13 <= mrd_tx_len;
mrd_tlp_param : tlp_param	
port map
(
	tx_len		=> mrd_tx_len13,
	
	tlp_fbe 	=> mrd_tlp_fbe, 	 
	tlp_lbe 	=> mrd_tlp_lbe, 	 
	tlp_dw_len 	=> mrd_tlp_dw_len	
);


mwr_tlp_param : tlp_param	
port map
(
	tx_len		=> mwr_tx_burst_len,
	
	tlp_fbe 	=> mwr_tlp_fbe, 	 
	tlp_lbe 	=> mwr_tlp_lbe, 	 
	tlp_dw_len 	=> mwr_tlp_dw_len	
);


--status_tlp_param : tlp_param	
--port map
--(
--	tx_len		=> "0000000000010",
--	
--	tlp_fbe 	=> status_tlp_fbe, 	 
--	tlp_lbe 	=> status_tlp_lbe, 	 
--	tlp_dw_len 	=> status_tlp_dw_len	
--);

status_tlp_fbe		<= x"f"; 	
status_tlp_lbe		<= x"f"; 	
status_tlp_dw_len   <= "00000000010";


mrd_tx_done		<= mrd_tx_done_int;
status_tx_done 	<= status_tx_done_int;
mwr_tx_done	 	<= mwr_tx_done_int;
	

m_axis_rq_tvalid	<= axis_rq_tvalid_int;
m_axis_rq_tdata		<= axis_rq_tdata_int;  
m_axis_rq_tuser		<= axis_rq_tuser_int; 
m_axis_rq_tlast		<= axis_rq_tlast_int; 
m_axis_rq_tkeep		<= axis_rq_tkeep_int; 	
                                                

end arc;



