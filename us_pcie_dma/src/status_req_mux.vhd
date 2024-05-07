--============================================================================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity status_req_mux is	
generic
(
	NUM_OF_SG_CHANNLES	: integer := 1
);
port
(
	
		clk_in        	: in std_logic;
      	rstn          	: in std_logic;
  
		status_ack		: out std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);     	   
		status_req		: in std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);     	   
		status_qword	: in std_logic_vector(64*(NUM_OF_SG_CHANNLES)-1 downto 0);
		status_addr		: in std_logic_vector(64*(NUM_OF_SG_CHANNLES)-1 downto 0);
		
		tx_req			: out std_logic;
		tx_done	        : in  std_logic;
		tx_qword		: out std_logic_vector(63 downto 0);
		tx_addr		: out std_logic_vector(63 downto 0)
      	    	
);
end status_req_mux;

architecture arc of status_req_mux is

	component arbiter_wrapper 
	generic
	(
		NUM_OF_CHANNLES : natural := 32;
		SELECT_WIDTH	: natural := 5
	);
	Port ( 
		-- system i/f
		reset_n_i 			: in  STD_LOGIC;
	    clk 					: in  STD_LOGIC;
		
		bm_req_i			   : in std_logic_vector(NUM_OF_CHANNLES-1 downto 0);
		bm_gnt_o			   : out std_logic_vector(NUM_OF_CHANNLES-1 downto 0);
		
		mux_index_o			: out integer range 0 to NUM_OF_CHANNLES-1
	
	);
	end component;
	
	component FIFO_core_wc 
    GENERIC(
        Data_Width : integer := 16;
        Log2_of_Depth : integer := 8
        );
    PORT (
        C, 
        R       : STD_LOGIC ;
        --Write side
		wc		: out STD_LOGIC_VECTOR (Log2_of_Depth-1 downto 0);
        Wd      : STD_LOGIC_VECTOR(Data_Width-1 downto 0);
        WE      : STD_LOGIC ;
        Full    : OUT STD_LOGIC ;
        --read side
        Rd      : OUT STD_LOGIC_VECTOR(Data_Width-1 downto 0);
        RE      : STD_LOGIC ;
        Dav     : out STD_LOGIC ; --data avaliable
        Empty   : OUT STD_LOGIC 
    );    
END component;

	function mux_2_to_1(a : in std_logic_vector; b : in std_logic_vector; 
						sel : in std_logic) return std_logic_vector is
		variable ret_val : std_logic_vector(128+NUM_OF_SG_CHANNLES-1 downto 0);
	begin
		if sel = '1' then
			ret_val := b;
		else
			ret_val := a;
		end if;
		
		return ret_val;
	end function;  	
	
	type mux_stage_vector is array (natural range <>) of std_logic_vector(128+NUM_OF_SG_CHANNLES-1 downto 0);
	
	-- for now, we supprot a maximum number of 512 input channels
	signal mux_input : mux_stage_vector(511 downto 0);
	signal mux_256   : mux_stage_vector(255 downto 0);
	signal mux_128   : mux_stage_vector(127 downto 0);
	signal mux_64    : mux_stage_vector(63 downto 0);
	signal mux_32    : mux_stage_vector(31 downto 0);
	signal mux_16    : mux_stage_vector(15 downto 0);
	signal mux_8     : mux_stage_vector(7 downto 0);
	signal mux_4     : mux_stage_vector(3 downto 0);
	signal mux_2     : mux_stage_vector(1 downto 0);
	signal mux_1     : mux_stage_vector(0 downto 0);
	
	signal mux_input_d : mux_stage_vector(511 downto 0);
	signal we_delay : std_logic_vector(9 downto 0);
  	
  	
	signal status_channel_index : integer range 0 to NUM_OF_SG_CHANNLES-1;
	signal arbistatus_ack_int 	: std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	signal arbistatus_ack_sig   : std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	signal arbistatus_ack_d     : std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);

    signal status_req_fifo_wd : std_logic_vector(128+NUM_OF_SG_CHANNLES-1 downto 0);
	signal status_req_fifo_we : std_logic;
    signal status_fifo_rd	  : std_logic_vector(128+NUM_OF_SG_CHANNLES-1 downto 0);  
	signal status_fifo_re	  : std_logic;  	
    signal status_fifo_dav	  : std_logic; 	
	signal status_fifo_empty  : std_logic;	
        
	signal wait_for_tx_done   : std_logic;
	
	signal curr_status_ack	  : std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);

begin

	status_arbiter : arbiter_wrapper 
	generic map
	(
		NUM_OF_CHANNLES => NUM_OF_SG_CHANNLES
	)
	port map 
	(
		clk  			=> clk_in,
		reset_n_i       => rstn,
		bm_req_i		=> status_req,
		bm_gnt_o		=> arbistatus_ack_int,
		
		mux_index_o		=> status_channel_index
	);
	

		status_req_fifo : FIFO_core_wc 
	    generic map(
	        Data_Width => 128+NUM_OF_SG_CHANNLES,
	        Log2_of_Depth => 6
	        )
	    port map(
	        C 	=> clk_in, 
	        R   => rstn,
	        --Write side
			wc		=> open,
	        Wd      => status_req_fifo_wd,
	        WE      => status_req_fifo_we,
	        Full    => open,
	        --read side
	        Rd      => status_fifo_rd,
	        RE      => status_fifo_re,
	        Dav     => status_fifo_dav,
	        Empty   => status_fifo_empty 
	    ); 
	    
         
	            
        arbistatus_ack_sig <= arbistatus_ack_int and not arbistatus_ack_d;

        process (clk_in)
		begin
			if rising_edge(clk_in)then  
				if rstn = '0' then
					tx_req 	 <= '0';
					tx_qword <= (others => '0');
					tx_addr	 <= (others => '0');
				else

					if status_fifo_dav = '1' then
						tx_req  <= '1';
						tx_qword <= status_fifo_rd(63 downto 0);
						tx_addr	 <= status_fifo_rd(127 downto 64);
						curr_status_ack <= status_fifo_rd(status_fifo_rd'high downto 128);
					end if;
								
					if tx_done = '1' then
						tx_req  <= '0';
					end if;
					
				end if;
			end if ;
		end process;
			        
        process (clk_in)
		begin
			if rising_edge(clk_in)then  
				if rstn = '0' then
        			status_fifo_re <= '0';
        			wait_for_tx_done <= '0';
				else
					status_fifo_re <= '0';
					if wait_for_tx_done = '0' and status_fifo_empty = '0' then
						status_fifo_re <= '1';
						wait_for_tx_done  <= '1';
					end if;
					
					if tx_done = '1' then
						wait_for_tx_done  <= '0';
					end if;
				end if;
			end if;
		end process;                

        process (clk_in)
		begin
			if rising_edge(clk_in)then  
				status_ack <= (others => '0');
				if tx_done = '1' then
					status_ack <= curr_status_ack;
				end if; 
      		end if;
      	end process;
      	
--        process (clk_in)
--		begin
--			if rising_edge(clk_in)then  
--				if rstn = '0' then
--					status_req_fifo_we <= '0';
--				else
--					arbistatus_ack_d <= arbistatus_ack_int; 
--						
--	    			status_req_fifo_we <= '0';
--	    	    	for i in 0 to NUM_OF_SG_CHANNLES-1 loop
--	    				if arbistatus_ack_int(i) = '1' and arbistatus_ack_d(i) = '0' then
--	    					status_req_fifo_we <= '1';
--	    					status_req_fifo_wd <= arbistatus_ack_int & status_addr(i*64+63 downto i*64) & status_qword(i*64+63 downto i*64);	
--	    				end if;
--	    			end loop;
--				end if;	   
--      		end if;
--      	end process;
      	
      	
      	--======================================================================================================================
      	
   process (clk_in)
	begin
		if rising_edge(clk_in)then  
			if rstn = '0' then
				we_delay <= (others => '0');
			else
				arbistatus_ack_d <= arbistatus_ack_int;
				we_delay(0) <= '0';
				if arbistatus_ack_sig /= 0 then
					we_delay(0) <= '1';
				end if;
				
				for i in 1 to we_delay'high loop
					we_delay(i) <= we_delay(i-1);
				end loop;
				
			end if;	   
    	end if;
    end process;
    
    
    
gen_mux_input: for i in 0 to NUM_OF_SG_CHANNLES-1 generate   
	mux_input(i) <= arbistatus_ack_int & status_addr(i*64+63 downto i*64) & status_qword(i*64+63 downto i*64);
 end generate;	
 gen_mux_input_null: for i in NUM_OF_SG_CHANNLES to 511 generate   
 	mux_input(i) <= (others => '0');
 end generate;
 
 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_input'high loop
			mux_input_d(i) <= mux_input(i);		
		end loop;
	end if;
 end process;
	
 
 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_256'high loop
			mux_256(i) <= mux_2_to_1(mux_input_d(i*2),mux_input_d(1+i*2),conv_std_logic_vector(status_channel_index,9)(0));
		end loop;
	end if;
 end process;
 
 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_128'high loop
			mux_128(i) <= mux_2_to_1(mux_256(i*2),mux_256(1+i*2),conv_std_logic_vector(status_channel_index,9)(1));
		end loop;
	end if;
 end process;

 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_64'high loop
			mux_64(i) <= mux_2_to_1(mux_128(i*2),mux_128(1+i*2),conv_std_logic_vector(status_channel_index,9)(2));
		end loop;
	end if;
 end process;

 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_32'high loop
			mux_32(i) <= mux_2_to_1(mux_64(i*2),mux_64(1+i*2),conv_std_logic_vector(status_channel_index,9)(3));
		end loop;
	end if;
 end process;

 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_16'high loop
			mux_16(i) <= mux_2_to_1(mux_32(i*2),mux_32(1+i*2),conv_std_logic_vector(status_channel_index,9)(4));
		end loop;
	end if;
 end process;

 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_8'high loop
			mux_8(i) <= mux_2_to_1(mux_16(i*2),mux_16(1+i*2),conv_std_logic_vector(status_channel_index,9)(5));
		end loop;
	end if;
 end process;
 
 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_4'high loop
			mux_4(i) <= mux_2_to_1(mux_8(i*2),mux_8(1+i*2),conv_std_logic_vector(status_channel_index,9)(6));
		end loop;
	end if;
 end process;

 process (clk_in)
 begin
	if rising_edge(clk_in)then  
		for i in 0 to mux_2'high loop
			mux_2(i) <= mux_2_to_1(mux_4(i*2),mux_4(1+i*2),conv_std_logic_vector(status_channel_index,9)(7));
		end loop;
	end if;
 end process;
	
  process (clk_in)
 begin
	if rising_edge(clk_in)then  
		mux_1(0) <= mux_2_to_1(mux_2(0),mux_2(1),conv_std_logic_vector(status_channel_index,9)(8));
	end if;
 end process;
 
 
 status_req_fifo_wd <= mux_1(0);
 
 status_req_fifo_we <= we_delay(we_delay'high); 
      	

	    					
	    					
                                                                                                                           
end arc;



