
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use     ieee.math_real.all;

-- TODO: unified the 128 fix/none fix aligne 21/10/2022


entity tag_alloc_wrapper is
generic 	
(
	NUM_OF_SG_CHANNLES	 : integer := 1;
	PCIE_CORE_DATA_WIDTH : integer := 128;
	LOG2_NUM_OF_TAGS	 : integer := 5;	
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
	complD_Tag_o			: out std_logic_vector(7 downto 0);
	bm_rx_active_o		  	: out std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	bm_rx_rdy_i				: in  std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	bm_context_o			: out std_logic_vector(31 downto 0)
		
);
end tag_alloc_wrapper;

architecture arc of tag_alloc_wrapper is

  constant CPLD_FMT_TYPE 	  : std_logic_vector(6 downto 0) := "1001010";
  constant ZERO_VECTOR_NUM_OF_SG_CHANNLES : std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0) := (others => '0');

	component tag_allocator 
    GENERIC(
        Log2_of_Depth : integer := 8;
        PCIE_CORE_DATA_WIDTH 	: integer := 128
        );
    PORT (
        C, 
        R       				: STD_LOGIC ;
        
        tag      				: OUT STD_LOGIC_VECTOR(7 downto 0);
        get      				: in STD_LOGIC ;
        tag_valid     				: out STD_LOGIC;
        
        in_context				: in std_logic_vector(31 downto 0);
        out_context 			: out std_logic_vector(31 downto 0);

        complD_transfer_done	: out std_logic;
        
        complD 					: in std_logic;
		complD_Last				: in std_logic;	
		complD_First			: in std_logic;
		complD_Data				: in std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
		complD_Lenght 			: in std_logic_vector(9 downto 0);
		complD_Attr 			: in std_logic_vector(2 downto 0);
		complD_EP 				: in std_logic;
		complD_TD 				: in std_logic;
		complD_TC  				: in std_logic_vector(2 downto 0);
		complD_ByteCount  		: in std_logic_vector(11 downto 0);
		complD_BCM   			: in std_logic;
		complD_CoplStat  		: in std_logic_vector(2 downto 0);
		complD_CompleterID  	: in std_logic_vector(15 downto 0);
		complD_LowerAddress  	: in std_logic_vector(6 downto 0);
		complD_Tag  			: in std_logic_vector(7 downto 0);
		complD_RequestorID 		: in std_logic_vector(15 downto 0)
         
    );   
    end component;
  
	component arbiter_wrapper 
	generic
	(
		NUM_OF_CHANNLES : natural := 32;
		SELECT_WIDTH	: natural := 5
	);
	Port ( 
		reset_n_i 			: std_logic;
	    clk 				: std_logic;
		
		bm_req_i			: in std_logic_vector(NUM_OF_CHANNLES-1 downto 0);
		bm_gnt_o			: out std_logic_vector(NUM_OF_CHANNLES-1 downto 0);
		
		mux_index_o			: out integer range 0 to NUM_OF_CHANNLES-1
	
	);
	end component;


	signal	arbit_gnt				: std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	signal	arbit_mux_index			: integer range 0 to NUM_OF_SG_CHANNLES-1;
	
    signal  complD_transfer_done	: std_logic;
    signal  complD 					: std_logic;
	signal	complD_Last				: std_logic;	
	signal	complD_First			: std_logic;
	signal	complD_Data				: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	signal	complD_Lenght 			: std_logic_vector(9 downto 0);
	signal	complD_Attr 			: std_logic_vector(2 downto 0);
	signal	complD_EP 				: std_logic;
	signal	complD_TD 				: std_logic;
	signal	complD_TC  				: std_logic_vector(2 downto 0);
	signal	complD_ByteCount  		: std_logic_vector(11 downto 0);
	signal	complD_BCM   			: std_logic;
	signal	complD_CoplStat  		: std_logic_vector(2 downto 0);
	signal	complD_CompleterID  	: std_logic_vector(15 downto 0);
	signal	complD_LowerAddress  	: std_logic_vector(6 downto 0);
	signal	complD_Tag  			: std_logic_vector(7 downto 0);
	signal	complD_RequestorID 		: std_logic_vector(15 downto 0);
	
	signal	complD_Data_d			: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);

	signal	rx_st_valid       		: std_logic;
	signal	rx_st_be 				: std_logic_vector((PCIE_CORE_DATA_WIDTH/8)-1 DOWNTO 0);
	signal	rx_st_data 				: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
	signal	rx_st_eop 				: std_logic;
	signal	rx_st_sop 				: std_logic;

	
	signal	rx_st_valid_d1       	: std_logic;	
	signal	rx_st_valid_d       	: std_logic;
	signal	rx_st_be_d 				: std_logic_vector((PCIE_CORE_DATA_WIDTH/8)-1 DOWNTO 0);
	signal	rx_st_data_d 			: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
	signal	rx_st_eop_d 			: std_logic;
	signal	rx_st_sop_d 			: std_logic;
	signal	rx_st_empty_d        : std_logic_vector(1 DOWNTO 0);
	signal	rx_st_empty          : std_logic_vector(1 DOWNTO 0);
		
	signal bm_data					: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
	
	signal  complD_sig				: std_logic;
	signal  last_CmplD_burst		: std_logic;
	signal  arbit_gnt_sig			: std_logic;
	signal  arbit_gnt_d				: std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	signal  sop_sig					: std_logic;	
	signal  complD_sig_int			: std_logic;
	
	signal  bm_context				: std_logic_vector(31 downto 0);
	signal  bm_context_d			: std_logic_vector(31 downto 0);
	signal  arbit_context_in        : std_logic_vector(31 downto 0);
	signal  get                     : std_logic;
	signal  tag						: std_logic_vector(7 downto 0);	
	signal  tag_valid				: std_logic;  
	signal  cpld_active				: std_logic;
	signal  done_sig				: std_logic;  
	signal  done_sig_d2             : std_logic;
	signal  done_sig_d3             : std_logic;
	signal  done_sig_d1				: std_logic;    
	
	signal  tag_valid_int				: std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);      
	
	signal local_reset_n : std_logic;
	
	attribute preserve_syn_only : boolean;
	
	attribute preserve_syn_only of local_reset_n : signal is true;
	

 attribute keep: string;
 attribute keep of tag_valid_int : signal is "ture"; 
 attribute keep of tag : signal is "true";
 
		                   
	
begin



  process(clk_i)
  begin
  	if rising_edge(clk_i) then
		local_reset_n <= rstn_i;
	end if;
 end process;


-- #################################### 64 bits bus width ########################################## 
cpld_proc_64_gen: if PCIE_CORE_DATA_WIDTH = 64 generate

done_sig <= last_CmplD_burst and rx_st_eop_i;
cpld_active_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		cpld_active <= complD;
		bm_context_o <= bm_context;
		bm_rx_done_o <= (others => '0');
		bm_rx_active_o <= (others => '0');
		done_sig_d1 <= done_sig;
		done_sig_d2 <= done_sig_d1;
		done_sig_d3 <= done_sig_d2;
		bm_context_d <= bm_context;	
		complD_Data_d <= complD_Data;	
		
		bm_be_o <= (others => '1');
		--if rx_st_eop_d = '1' and rx_st_empty_d(0) = '1' then
		--	bm_be_o(15 downto 8) <= (others => '0');
		--end if;
		 
		
		for i in 0 to NUM_OF_SG_CHANNLES-1 loop
			if cpld_active = '1' and rx_st_valid_d = '1' and conv_integer(bm_context(7 downto 0)) = i then
				bm_rx_active_o(i) <= '1';
				bm_rx_done_o(i) <= done_sig_d2;
			end if;
		end loop; 
			
	end if;	
end process;

end generate;


cpld_active_proc_64_fixed_quad_alignd_gen: if PCIE_CORE_DATA_WIDTH = 64 and FIXED_QUAD_LIGEND = 1 generate

cpld_active_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		bm_data_o <= complD_Data;
	end if;	
end process;

end generate;




cpld_active_proc_64_gen: if PCIE_CORE_DATA_WIDTH = 64   and FIXED_QUAD_LIGEND = 0  generate

cpld_active_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		bm_data_o <= complD_Data(95 downto 0) & complD_Data_d(127 downto 96);
	end if;	
end process;

end generate;

cpld_active_proc_128_fixed_quad_alignd_gen: if PCIE_CORE_DATA_WIDTH = 128 and FIXED_QUAD_LIGEND = 1 generate

done_sig <= last_CmplD_burst and rx_st_eop_i;
cpld_active_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		cpld_active <= complD;
		bm_context_o <= bm_context;
		bm_rx_done_o <= (others => '0');
		bm_rx_active_o <= (others => '0');
		bm_data_o <= complD_Data;
		done_sig_d1 <= done_sig;
		done_sig_d2 <= done_sig_d1;
		done_sig_d3 <= done_sig_d2;
		bm_context_d <= bm_context;	
		complD_Data_d <= complD_Data;	
		
		bm_be_o <= (others => '1');
		if rx_st_eop_d = '1' and rx_st_empty_d(0) = '1' then
			bm_be_o(15 downto 8) <= (others => '0');
		end if;
		 
		
		for i in 0 to NUM_OF_SG_CHANNLES-1 loop
			if cpld_active = '1' and rx_st_valid_d = '1' and conv_integer(bm_context(7 downto 0)) = i then
				bm_rx_active_o(i) <= '1';
				bm_rx_done_o(i) <= done_sig_d2;
			end if;
		end loop; 
			
	end if;	
end process;

end generate;




cpld_active_proc_128_gen: if PCIE_CORE_DATA_WIDTH = 128   and FIXED_QUAD_LIGEND = 0  generate

done_sig <= last_CmplD_burst and rx_st_eop_i;
cpld_active_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		cpld_active <= complD;
		bm_context_o <= bm_context;
		bm_rx_done_o <= (others => '0');
		bm_rx_active_o <= (others => '0');
		bm_data_o <= complD_Data(95 downto 0) & complD_Data_d(127 downto 96);
		done_sig_d1 <= done_sig;
		done_sig_d2 <= done_sig_d1;
		done_sig_d3 <= done_sig_d2;
		bm_context_d <= bm_context;	
		complD_Data_d <= complD_Data;	
		
		bm_be_o <= (others => '1');
		if rx_st_eop_d = '1' and rx_st_empty_d(0) = '1' then
			bm_be_o(15 downto 8) <= (others => '0');
		end if;
		 
		
		for i in 0 to NUM_OF_SG_CHANNLES-1 loop
			if cpld_active = '1' and rx_st_valid_d = '1' and conv_integer(bm_context(7 downto 0)) = i then
				bm_rx_active_o(i) <= '1';
				bm_rx_done_o(i) <= done_sig_d2;
			end if;
		end loop; 
			
	end if;	
end process;

end generate;

cpld_active_proc_255_fixed_quad_alignd_gen: if PCIE_CORE_DATA_WIDTH = 256 and FIXED_QUAD_LIGEND = 1 generate

done_sig <= last_CmplD_burst and rx_st_eop_i;
cpld_active_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		cpld_active <= complD;
		bm_context_o <= bm_context;
		bm_rx_done_o <= (others => '0');
		bm_rx_active_o <= (others => '0');
		bm_data <= rx_st_data(127 downto 0) & complD_Data(255 downto 128);
		bm_data_o <= bm_data;
		done_sig_d1 <= done_sig;
		done_sig_d2 <= done_sig_d1;
		done_sig_d3 <= done_sig_d2;
		bm_context_d <= bm_context;	
		complD_Data_d <= complD_Data;	
				
		bm_be_o <= (others => '1');
		if rx_st_eop_d = '1' and rx_st_empty_d = "11" then
			bm_be_o(31 downto 24) <= (others => '0');
		end if;
		if rx_st_eop_d = '1' and rx_st_empty_d = "10" then
			bm_be_o(31 downto 16) <= (others => '0');
		end if;
		if rx_st_eop_d = '1' and rx_st_empty_d = "01" then
			bm_be_o(31 downto 8) <= (others => '0');
		end if;
				
		for i in 0 to NUM_OF_SG_CHANNLES-1 loop
			if cpld_active = '1' and rx_st_valid_d = '1' and  conv_integer(bm_context(7 downto 0)) = i then
				bm_rx_active_o(i) <= '1';
				bm_rx_done_o(i) <= done_sig_d2;
			end if;
		end loop; 
		
		
			
	end if;	
end process;

end generate;


	

sop_sig <= rx_st_sop_i and rx_st_valid_i;


cpld_proc_64_gen2: if PCIE_CORE_DATA_WIDTH = 64 generate

cpld_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		if local_reset_n = '0' then
			complD <= '0';
			complD_Last <= '0';
			complD_Data <= (others => '0');
			complD_First	<= '0';
			complD_Lenght <= (others => '0');
			complD_Attr <= (others => '0');
			complD_EP <= '0';
			complD_TD <= '0';
			complD_TC  <= (others => '0');
			complD_ByteCount  <= (others => '0');
			complD_BCM   <= '0';
			complD_CoplStat  <= (others => '0');
			complD_CompleterID  <= (others => '0');
			complD_LowerAddress  <= (others => '0');
			complD_Tag  <= (others => '0');
			complD_RequestorID  <= (others => '0');
			
			complD_sig 		<= '0';
			complD_sig_int	<= '0';
			last_CmplD_burst <= '0';
						
		else 
		
		
			complD_First <= complD_sig;  
			complD_sig <= '0';
			complD_sig_int <= '0'; 
			
			if rx_st_eop_i = '1' then
				last_CmplD_burst <= '0';
			end if;
			
			
			if sop_sig = '1' and rx_st_data_i(30 downto 24) = CPLD_FMT_TYPE then
			
				complD_Lenght 		<= rx_st_data_i(9 downto 0);
				complD_Attr 		<= rx_st_data_i(18) & rx_st_data(13 downto 12);
				complD_EP 			<= rx_st_data_i(14);
				complD_TD 			<= rx_st_data_i(15);
				complD_TC  			<= rx_st_data_i(22 downto 20);
				complD_ByteCount  	<= rx_st_data_i(43 downto 32);
				complD_BCM   		<= rx_st_data_i(43);
				complD_CoplStat  	<= rx_st_data_i(46 downto 44);
				complD_CompleterID  <= rx_st_data_i(63 downto 48);
							
				complD_sig_int <= '1';   
				
				if rx_st_data_i(9 downto 0) = rx_st_data_i(43 downto 34) then
					last_CmplD_burst <= '1';				
				end if;                                                                                                       
			end if;
			
			
			if complD_sig_int = '1' then
				complD_LowerAddress <= rx_st_data_i(6 downto 0);
				complD_Tag  		<= rx_st_data_i(15 downto 8);
				complD_RequestorID  <= rx_st_data_i(31 downto 16);
				complD_sig <= '1';
				
			end if;
			
			if complD_sig = '1' then
				complD  <= '1';
			end if;
			
			if rx_st_eop = '1' then
				complD <= '0';
			end if; 
			
			complD_last <= '0';
			if rx_st_eop_i = '1' and complD = '1' then
				complD_last <= last_CmplD_burst; --'1';
			end if;
		
			if rx_st_eop_i = '1' and complD_sig = '1' then
				complD_last <= '1';
			end if;
			
			complD_Data <= rx_st_data; 
			
			
		end if;	
	end if;
end process;

end generate;



cpld_proc_not_64_gen: if PCIE_CORE_DATA_WIDTH /= 64 generate

cpld_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		if local_reset_n = '0' then
			complD <= '0';
			complD_Last <= '0';
			complD_Data <= (others => '0');
			complD_First	<= '0';
			complD_Lenght <= (others => '0');
			complD_Attr <= (others => '0');
			complD_EP <= '0';
			complD_TD <= '0';
			complD_TC  <= (others => '0');
			complD_ByteCount  <= (others => '0');
			complD_BCM   <= '0';
			complD_CoplStat  <= (others => '0');
			complD_CompleterID  <= (others => '0');
			complD_LowerAddress  <= (others => '0');
			complD_Tag  <= (others => '0');
			complD_RequestorID  <= (others => '0');
			
			complD_sig 		<= '0';
			last_CmplD_burst <= '0';
						
		else 
		
		
			complD_First <= complD_sig;  
			complD_sig <= '0';
			
			if rx_st_eop_i = '1' then
				last_CmplD_burst <= '0';
			end if;
			
			
			if sop_sig = '1' and rx_st_data_i(30 downto 24) = CPLD_FMT_TYPE then
			
				complD_Lenght 		<= rx_st_data_i(9 downto 0);
				complD_Attr 		<= rx_st_data_i(18) & rx_st_data(13 downto 12);
				complD_EP 			<= rx_st_data_i(14);
				complD_TD 			<= rx_st_data_i(15);
				complD_TC  			<= rx_st_data_i(22 downto 20);
				complD_ByteCount  	<= rx_st_data_i(43 downto 32);
				complD_BCM   		<= rx_st_data_i(43);
				complD_CoplStat  	<= rx_st_data_i(46 downto 44);
				complD_CompleterID  <= rx_st_data_i(63 downto 48);
				complD_LowerAddress <= rx_st_data_i(70 downto 64);
				complD_Tag  		<= rx_st_data_i(79 downto 72);
				complD_RequestorID  <= rx_st_data_i(95 downto 80);
							
				complD_sig <= '1';   
				
				if rx_st_data_i(9 downto 0) = rx_st_data_i(43 downto 34) then
					last_CmplD_burst <= '1';				
				end if;                                                                                                       
			end if;
			
			if complD_sig = '1' then
				complD  <= '1';
			end if;
			
			if rx_st_eop = '1' then
				complD <= '0';
			end if; 
			
			complD_last <= '0';
			if rx_st_eop_i = '1' and complD = '1' then
				complD_last <= last_CmplD_burst; --'1';
			end if;
		
			if rx_st_eop_i = '1' and complD_sig = '1' then
				complD_last <= '1';
			end if;
			
			
			
			complD_Data <= rx_st_data; 
			
			
		end if;	
	end if;
end process;

end generate;

process(clk_i)
begin
	if rising_edge(clk_i) then
		rx_st_valid   <= rx_st_valid_i; 
		rx_st_be 	  <= rx_st_be_i; 	  
		rx_st_data 	  <= rx_st_data_i; 	
		rx_st_eop 	  <= rx_st_eop_i; 	 
		rx_st_sop 	  <= rx_st_sop_i;
		rx_st_empty	  <= rx_st_empty_i;
		
		rx_st_valid_d   <= rx_st_valid; 
		rx_st_valid_d1 <= rx_st_valid_d;
		rx_st_be_d 	  	<= rx_st_be; 	  
		rx_st_data_d 	<= rx_st_data; 	
		rx_st_eop_d 	<= rx_st_eop; 	 
		rx_st_sop_d 	<= rx_st_sop; 
		
		rx_st_empty_d	  <= rx_st_empty;	
		 
		
		 	 
	end if;
end process; 



tag_rec_arbit : arbiter_wrapper 
generic map
(
	NUM_OF_CHANNLES => NUM_OF_SG_CHANNLES,
	SELECT_WIDTH	=> 12 --log2(NUM_OF_SG_CHANNLES)
)
port map
( 
	reset_n_i 			=> local_reset_n, 
    clk 				=> clk_i,  
	
	bm_req_i			=> tag_request_i,
	bm_gnt_o			=> arbit_gnt,
	
	mux_index_o			=> arbit_mux_index

);


arbit_gnt_sig <= '1' when (arbit_gnt /= ZERO_VECTOR_NUM_OF_SG_CHANNLES) and (arbit_gnt /= arbit_gnt_d) else '0';

arbit_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		if local_reset_n = '0' then
			arbit_gnt_d <= (others => '0');
			arbit_context_in <= (others => '0');
			tag_valid_int <= (others => '0');
			get <= '0';
		else
			arbit_gnt_d <= arbit_gnt;
			
			if arbit_gnt_sig = '1' then
				get <= '1';
			elsif tag_valid = '1' then
				get <= '0';	
			else 
				get <= get;
			end if;
			
			
			for i in 0 to NUM_OF_SG_CHANNLES-1 loop
				if arbit_gnt_sig = '1' and arbit_mux_index = i  then
					arbit_context_in <= context_i(i*32+31 downto i*32);
				end if;
			end loop;
			
			tag_valid_int <= (others => '0');
			for i in 0 to NUM_OF_SG_CHANNLES-1 loop
				if tag_valid = '1' and arbit_mux_index = i  then
					tag_valid_int(i) <= '1';
				end if;
			end loop;
			
			 
			
			
		end if;
	end if;
end process;

process(clk_i)
begin
	if rising_edge(clk_i) then
		tag_o <= tag;	
	end if;
end process;	


tag_allocator_i : tag_allocator
generic map (
	Log2_of_Depth 			=> LOG2_NUM_OF_TAGS,
	PCIE_CORE_DATA_WIDTH 	=> PCIE_CORE_DATA_WIDTH
)
port map (
    C						=> clk_i, 
    R       				=> local_reset_n,
    
    tag      				=>  tag,         
    get      				=>  get,     
    tag_valid     			=>  tag_valid,
    
                       
    in_context	 			=> arbit_context_in,
    out_context  			=> bm_context,
    
		
    complD_transfer_done	=> complD_transfer_done,
    
	complD 					=>  complD,
	complD_Last				=>  complD_Last,
	complD_First 			=>  complD_First,
	complD_Data				=>  complD_Data,
	complD_Lenght 			=>  complD_Lenght,
	complD_Attr 			=>  complD_Attr,
	complD_EP 				=>  complD_EP,
	complD_TD 				=>  complD_TD,
	complD_TC  				=>  complD_TC,
	complD_ByteCount  		=>  complD_ByteCount,
	complD_BCM   			=>  complD_BCM,
	complD_CoplStat  		=>  complD_CoplStat,
	complD_CompleterID  	=>  complD_CompleterID,
	complD_LowerAddress  	=>  complD_LowerAddress,
	complD_Tag  			=>  complD_Tag,
	complD_RequestorID  	=>  complD_RequestorID 
    
    
     
);

	tag_valid_o <= tag_valid_int;
	
	complD_Tag_o <= complD_Tag;
		
end arc;