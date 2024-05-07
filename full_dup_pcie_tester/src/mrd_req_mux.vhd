--============================================================================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity mrd_req_mux is	
generic
(
	NUM_OF_FAST_SG_IN_CHANNLES	: integer := 1;
	NUM_OF_FAST_SG_OUT_CHANNLES : integer := 1
);
port
(
	
		clk_in        	: in std_logic;
      	rstn          	: in std_logic;
      	
		mrd_req_req	 	: in std_logic_vector(NUM_OF_FAST_SG_IN_CHANNLES+NUM_OF_FAST_SG_OUT_CHANNLES-1 downto 0);     	   
		mrd_req_ack 	: out std_logic_vector(NUM_OF_FAST_SG_IN_CHANNLES+NUM_OF_FAST_SG_OUT_CHANNLES-1 downto 0);     	   
		mrd_req_len	 	: in  std_logic_vector(13*(NUM_OF_FAST_SG_IN_CHANNLES+NUM_OF_FAST_SG_OUT_CHANNLES)-1 downto 0);
		mrd_addr	 	: in  std_logic_vector(64*(NUM_OF_FAST_SG_IN_CHANNLES+NUM_OF_FAST_SG_OUT_CHANNLES)-1 downto 0);
		mrd_tag			: in  std_logic_vector(8*(NUM_OF_FAST_SG_IN_CHANNLES+NUM_OF_FAST_SG_OUT_CHANNLES)-1 downto 0);
			
		tx_req			: out std_logic;
		tx_done	        : in  std_logic;
		tx_tag			: out std_logic_vector(7 downto 0);
		tx_len			: out std_logic_vector(12 downto 0);
		tx_addr			: out std_logic_vector(63 downto 0)
      	    	
);
end mrd_req_mux;

architecture arc of mrd_req_mux is

  	constant 	NUM_OF_SG_CHANNLES  : integer := NUM_OF_FAST_SG_IN_CHANNLES+NUM_OF_FAST_SG_OUT_CHANNLES;

	component arbiter_wrapper 
	generic
	(
		NUM_OF_CHANNLES : natural := 32;
		SELECT_WIDTH	: natural := 5
	);
	Port ( 
		-- system i/f
		reset_n_i 			: in  std_logic;
	    clk 				: in  std_logic;
		
		bm_req_i			: in std_logic_vector(NUM_OF_CHANNLES-1 downto 0);
		bm_gnt_o			: out std_logic_vector(NUM_OF_CHANNLES-1 downto 0);
		
		mux_index_o			: out integer range 0 to NUM_OF_CHANNLES-1
	
	);
	end component;
  	
component FIFO_core_wc
 generic(
        Data_Width : integer := 16;
        Log2_of_Depth : integer := 8
        );
    port (
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
end component;    
  	
  	
	signal arbit_mrdreq_channel_index : integer range 0 to NUM_OF_SG_CHANNLES-1;
	signal arbit_mrdreq_ack_int 	: std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	signal arbit_mrdreq_ack_sig   : std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);
	signal arbit_mrdreq_ack_d     : std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);

    signal arbit_mrdreq_req_fifo_wd : std_logic_vector(85+NUM_OF_SG_CHANNLES-1 downto 0);
	signal arbit_mrdreq_req_fifo_we : std_logic;
    signal arbit_mrdreq_fifo_rd	  : std_logic_vector(85+NUM_OF_SG_CHANNLES-1 downto 0);  
	signal arbit_mrdreq_fifo_re	  : std_logic;  	
    signal arbit_mrdreq_fifo_dav	  : std_logic; 	
	signal arbit_mrdreq_fifo_empty  : std_logic;	
        
	signal wait_for_tx_done   : std_logic;
	
	signal curr_arbit_mrdreq_ack	  : std_logic_vector(NUM_OF_SG_CHANNLES-1 downto 0);

begin

	arbit_mrdreq_arbiter : arbiter_wrapper 
	generic map
	(
		NUM_OF_CHANNLES => NUM_OF_SG_CHANNLES
	)
	port map 
	(
		clk  			=> clk_in,
		reset_n_i       => rstn,
		bm_req_i		=> mrd_req_req,
		bm_gnt_o		=> arbit_mrdreq_ack_int,
		
		mux_index_o		=> arbit_mrdreq_channel_index
	);

	arbit_mrdreq_req_fifo : FIFO_core_wc 
	generic map
	(
	    Data_Width => 85+NUM_OF_SG_CHANNLES,
	    Log2_of_Depth => 6
	)
	port map
	(
	    C 	=> clk_in, 
	    R   => rstn,
	    --Write side
		wc		=> open,
	    Wd      => arbit_mrdreq_req_fifo_wd,
	    WE      => arbit_mrdreq_req_fifo_we,
	    Full    => open,
	    --read side
	    Rd      => arbit_mrdreq_fifo_rd,
	    RE      => arbit_mrdreq_fifo_re,
	    Dav     => arbit_mrdreq_fifo_dav,
	    Empty   => arbit_mrdreq_fifo_empty 
	); 
	    
       	
        
	            
    arbit_mrdreq_ack_sig <= arbit_mrdreq_ack_int and not arbit_mrdreq_ack_d;

    process (clk_in)
	begin
		if rising_edge(clk_in)then  
			if rstn = '0' then
				tx_req 	 <= '0';
				tx_len <= (others => '0');
				tx_addr	 <= (others => '0');
			else

				if arbit_mrdreq_fifo_dav = '1' then
					tx_req  <= '1';
					tx_len <= arbit_mrdreq_fifo_rd(12 downto 0);
					tx_addr	 <= arbit_mrdreq_fifo_rd(76 downto 13);
					tx_tag	 <= arbit_mrdreq_fifo_rd(84 downto 77);
					curr_arbit_mrdreq_ack <= arbit_mrdreq_fifo_rd(arbit_mrdreq_fifo_rd'high downto arbit_mrdreq_fifo_rd'high-NUM_OF_SG_CHANNLES+1);
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
    			arbit_mrdreq_fifo_re <= '0';
    			wait_for_tx_done <= '0';
			else
				arbit_mrdreq_fifo_re <= '0';
				if wait_for_tx_done = '0' and arbit_mrdreq_fifo_empty = '0' then
					arbit_mrdreq_fifo_re <= '1';
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
			mrd_req_ack <= (others => '0');
			if tx_done = '1' then
				mrd_req_ack <= curr_arbit_mrdreq_ack;
			end if; 
    	end if;
    end process;
	
	        
    process (clk_in)
	begin
		if rising_edge(clk_in)then  
			if rstn = '0' then
				arbit_mrdreq_req_fifo_we <= '0';
			else
				arbit_mrdreq_ack_d <= arbit_mrdreq_ack_int; 
				arbit_mrdreq_req_fifo_we <= '0';
		    	for i in 0 to NUM_OF_SG_CHANNLES-1 loop
					if arbit_mrdreq_ack_int(i) = '1' and arbit_mrdreq_ack_d(i) = '0' then
						arbit_mrdreq_req_fifo_we <= '1';
						arbit_mrdreq_req_fifo_wd <= arbit_mrdreq_ack_int & mrd_tag(i*8+7 downto i*8) & mrd_addr(i*64+63 downto i*64) & mrd_req_len(i*13+12 downto i*13);	
					end if;
				end loop;
			end if;	   
    	end if;
    end process;
         	   
end arc;



