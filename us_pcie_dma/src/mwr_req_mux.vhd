--============================================================================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;


entity mwr_req_mux is	
generic
(
	NUM_OF_FAST_SG_IN_CHANNLES	: integer := 1;
	PCIE_CORE_DATA_WIDTH         : integer := 256
);
port
(
	clk_in        	: in std_logic;
	rstn          	: in std_logic;
	
	stop			: in std_logic_vector(NUM_OF_FAST_SG_IN_CHANNLES-1 downto 0);     	   
	mwr_ack			: out std_logic_vector(NUM_OF_FAST_SG_IN_CHANNLES-1 downto 0);     	   
	mwr_req			: in std_logic_vector(NUM_OF_FAST_SG_IN_CHANNLES-1 downto 0);     	   
	mwr_burst_len	: in std_logic_vector(13*NUM_OF_FAST_SG_IN_CHANNLES-1 downto 0);
	mwr_addr		: in std_logic_vector(64*NUM_OF_FAST_SG_IN_CHANNLES-1 downto 0);
	mwr_tag			: in std_logic_vector(8*NUM_OF_FAST_SG_IN_CHANNLES-1 downto 0);
	mwr_wr_active	: out std_logic_vector(NUM_OF_FAST_SG_IN_CHANNLES-1 downto 0); 
	
	mwr_read_req 	: out std_logic_vector(NUM_OF_FAST_SG_IN_CHANNLES-1 downto 0); 
	mwr_read_data 	: in std_logic_vector(NUM_OF_FAST_SG_IN_CHANNLES*PCIE_CORE_DATA_WIDTH-1 downto 0); 
	
	tx_data			: out std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0); -- data to send 
	tx_req			: out std_logic; -- request a burst to send
	tx_data_req		: in  std_logic; -- request next data to send 
	tx_ack			: in  std_logic; -- request acknowlage, burst started
	tx_done	        : in  std_logic; -- bust is done
	tx_burst_len	: out std_logic_vector(12 downto 0);
	tx_addr			: out std_logic_vector(63 downto 0);
	tx_tag			: out std_logic_vector(7 downto 0)
);
end mwr_req_mux;

architecture arc of mwr_req_mux is

    constant NUM_OF_SG_CHANNLES : integer := NUM_OF_FAST_SG_IN_CHANNLES;
    constant NUM_OF_SG_CHANNLES_INT_WIDTH : integer := integer(log2(real(NUM_OF_SG_CHANNLES)));
  	type DATA_ARRAY is array (0 to NUM_OF_FAST_SG_IN_CHANNLES-1) of std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
  	
	component arbiter_wrapper 
	generic
	(
		NUM_OF_CHANNLES : natural := 32;
		SELECT_WIDTH	: natural := 5
	);
	Port ( 
		-- system i/f
		reset_n_i 			: in  STD_LOGIC;
	    clk 				: in  STD_LOGIC;
		
		bm_req_i			: in std_logic_vector(NUM_OF_CHANNLES-1 downto 0);
		bm_gnt_o			: out std_logic_vector(NUM_OF_CHANNLES-1 downto 0);
		
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
	
  	
  	signal read_data_array : DATA_ARRAY;
  	
	signal mwr_channel_index : integer range 0 to NUM_OF_SG_CHANNLES-1;
	signal arbit_mwr_ack_int 	: std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	signal arbit_mwr_ack_sig   	: std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	signal arbit_mwr_ack_d     	: std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);

    signal mwr_req_fifo_wd 		: std_logic_vector(NUM_OF_SG_CHANNLES_INT_WIDTH+85+NUM_OF_SG_CHANNLES-1 downto 0);
	signal mwr_req_fifo_we 		: std_logic;
    signal mwr_fifo_rd	  		: std_logic_vector(NUM_OF_SG_CHANNLES_INT_WIDTH+85+NUM_OF_SG_CHANNLES-1 downto 0);  
	signal mwr_fifo_re	  		: std_logic;  	
    signal mwr_fifo_dav	  		: std_logic; 	
	signal mwr_fifo_empty  		: std_logic;	
        
	signal wait_for_tx_done   : std_logic;
	
	signal curr_tx_pending	  : std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	
	signal tx_out_sel : integer range 0 to NUM_OF_SG_CHANNLES-1;
	
	
	signal local_reset_n : std_logic;
	
	attribute preserve_syn_only : boolean;
	
	attribute preserve_syn_only of local_reset_n : signal is true;
	

begin

	process(clk_in)
	begin
	  	if rising_edge(clk_in) then
			local_reset_n <= rstn;
		end if;
	end process;

	
	rd_data_in_gen: for i in 0 to NUM_OF_SG_CHANNLES-1 generate
		read_data_array(i) <= mwr_read_data(i*PCIE_CORE_DATA_WIDTH+PCIE_CORE_DATA_WIDTH-1 downto i*PCIE_CORE_DATA_WIDTH);
		mwr_read_req(i) <=  curr_tx_pending(i) and tx_data_req;
	end generate;
	
		
	--tx_data <= read_data_array(mwr_channel_index);
	tx_data <= read_data_array(tx_out_sel);


	status_arbiter : arbiter_wrapper 
	generic map
	(
		NUM_OF_CHANNLES => NUM_OF_FAST_SG_IN_CHANNLES
	)
	port map 
	(
		clk  			=> clk_in,
		reset_n_i       => local_reset_n,
		bm_req_i		=> mwr_req,
		bm_gnt_o		=> arbit_mwr_ack_int,
		
		mux_index_o		=> mwr_channel_index
	);
	

		status_req_fifo : FIFO_core_wc 
	    generic map(
	        Data_Width => NUM_OF_SG_CHANNLES_INT_WIDTH+85+NUM_OF_FAST_SG_IN_CHANNLES,
	        Log2_of_Depth => 6
	        )
	    port map(
	        C 	=> clk_in, 
	        R   => local_reset_n,
	        --Write side
			wc		=> open,
	        Wd      => mwr_req_fifo_wd,
	        WE      => mwr_req_fifo_we,
	        Full    => open,
	        --read side
	        Rd      => mwr_fifo_rd,
	        RE      => mwr_fifo_re,
	        Dav     => mwr_fifo_dav,
	        Empty   => mwr_fifo_empty 
	    ); 
	    
         
	            
        arbit_mwr_ack_sig <= arbit_mwr_ack_int and not arbit_mwr_ack_d;

        process (clk_in)
		begin
			if rising_edge(clk_in)then  
				if local_reset_n = '0' then
					tx_req 	 <= '0';
					tx_addr <= (others => '0');
					tx_burst_len <= (others => '0');
					tx_tag <= (others => '0');
					curr_tx_pending <= (others => '0');
					tx_out_sel <= 0;
				else

					if mwr_fifo_dav = '1' then
						tx_req  <= '1';
						
						tx_out_sel <= conv_integer(mwr_fifo_rd(mwr_fifo_rd'high downto NUM_OF_FAST_SG_IN_CHANNLES+85));
	    				tx_addr <= mwr_fifo_rd(84 downto 21);
	    				tx_burst_len <= mwr_fifo_rd(20 downto 8);
	    				tx_tag <= mwr_fifo_rd(7 downto 0);	
						--curr_tx_pending <= mwr_fifo_rd(mwr_fifo_rd'high downto 85);
						curr_tx_pending <=  mwr_fifo_rd(NUM_OF_FAST_SG_IN_CHANNLES+84 downto 85);
					end if;
								
					if tx_ack = '1' then
						tx_req  <= '0';
					end if;
					
				end if;
			end if ;
		end process;
			        
        process (clk_in)
		begin
			if rising_edge(clk_in)then  
				if local_reset_n = '0' then
        			mwr_fifo_re <= '0';
        			wait_for_tx_done <= '0';
				else
					mwr_fifo_re <= '0';
					--if (wait_for_tx_done = '0' or tx_done = '1') and mwr_fifo_empty = '0' then
					if wait_for_tx_done = '0' and mwr_fifo_empty = '0' then
						mwr_fifo_re <= '1';
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
				--mwr_ack <= (others => '0');
				--if tx_done = '1' then
				--	mwr_ack <= arbit_mwr_ack_int;
				--end if; 
				mwr_ack <= arbit_mwr_ack_sig;
      		end if;
      	end process;
		
		        
        process (clk_in)
		begin
			if rising_edge(clk_in)then  
				if local_reset_n = '0' then
					mwr_req_fifo_we <= '0';
					mwr_req_fifo_wd <= (others => '0');
				else
					arbit_mwr_ack_d <= arbit_mwr_ack_int; 
	    			mwr_req_fifo_we <= '0';
	    	    	for i in 0 to NUM_OF_SG_CHANNLES-1 loop
	    				if arbit_mwr_ack_int(i) = 	'1' and arbit_mwr_ack_d(i) = '0' and stop(i) = '0' then
	    					mwr_req_fifo_we <= 	'1';
	    					mwr_req_fifo_wd <=	conv_std_logic_vector(mwr_channel_index,NUM_OF_SG_CHANNLES_INT_WIDTH) &
	    									 	arbit_mwr_ack_int & 
	    										mwr_addr(i*64+63 downto i*64) & 
	    										mwr_burst_len(i*13+12 downto i*13) &
	    										mwr_tag(i*8+7 downto i*8);	
	    				end if;
	    			end loop;
				end if;	   
      		end if;
      	end process;


end arc;



