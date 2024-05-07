
library IEEE;
use IEEE.std_logic_1164.all;

use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity mrd_requestor is 	
generic
(
	CHAN_ID				 : integer := 0 
);
port
(
	-- signals at system clock
	clk_i  					: in std_logic;
	reset_n_i         		: in std_logic;
	
	
		
	alloc_tag_req_o			: out std_logic;
	allocated_tag_rdy_i		: in std_logic;
	allocated_tag_i			: in std_logic_vector(7 downto 0);
	
	
	burst_req_i				: in std_logic;
	burst_rdy_o				: out std_logic;
	burst_len_i			   	: in std_logic_vector(12 downto 0);
	burst_sys_addr_i		: in std_logic_vector(63 downto 0);
	
	arbit_req_o				: out std_logic;
	arbit_grnt_i			: in std_logic;
	rearbit_req_i			: in std_logic;	
	
	burst_len_out_o			: out std_logic_vector(12 downto 0);
	burst_dir_out_o			: out std_logic;
	burst_sys_addr_out_o	: out std_logic_vector(63 downto 0);
	burst_tag_o				: out std_logic_vector(7 downto 0)
	

		
);
end mrd_requestor;




architecture arc of mrd_requestor is



-- ========================== deprecated signals =====================
constant PCIE_CORE_DATA_WIDTH	: integer := 128;
constant BUFFES_SIZE_LOG_OF2 	: integer := 6;
constant write_ena_i		: std_logic := '0';
constant write_last_i		: std_logic := '0';
constant write_data_i		: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0) := (others => '0');
constant read_index_i		: std_logic_vector(BUFFES_SIZE_LOG_OF2-1 downto 0) := (others => '0');
constant flush_i			: std_logic := '0';
constant stop_req_pending_i	: std_logic := '0';
constant wr_active_i		: std_logic := '0';

signal write_rdy_o			: std_logic;
signal tx_buffer_space_o	: std_logic_vector(31 downto 0);
signal read_data_o			: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
signal read_empty_o			: std_logic;
signal wc_o 				: integer range 0 to (2**BUFFES_SIZE_LOG_OF2+1)*(PCIE_CORE_DATA_WIDTH/32);
signal overflow_o			: std_logic;
signal stop_rq_ack_o		: std_logic;



--=====================================================================





component  FIFO_core_wc IS
   generic
	(
		Data_Width : integer := 16;
		Log2_of_Depth : integer := 8
   );
	port 
	(
			  C, 
			  R       : STD_LOGIC ;
			  --Write side
			  wc		: out STD_LOGIC_VECTOR (Log2_of_Depth-1 DOWNTO 0);
			  Wd      : STD_LOGIC_VECTOR(85 downto 0);
			  WE      : STD_LOGIC ;
			  Full    : OUT STD_LOGIC ;
			  --read side
			  Rd      : OUT STD_LOGIC_VECTOR(85 downto 0);
			  RE      : STD_LOGIC ;
			  Dav     : out STD_LOGIC ; --data avaliable
			  Empty   : OUT STD_LOGIC 
	);    
	end component;

	component tx_front_buff_fifo_wrapper IS
	port 
	(
			  C, 
			  R       : STD_LOGIC ;
			  --Write side
			  wc		: out STD_LOGIC_VECTOR (9 DOWNTO 0);
			  Wd      : STD_LOGIC_VECTOR(85 downto 0);
			  WE      : STD_LOGIC ;
			  Full    : OUT STD_LOGIC ;
			  --read side
			  Rd      : OUT STD_LOGIC_VECTOR(85 downto 0);
			  RE      : STD_LOGIC ;
			  Dav     : out STD_LOGIC ; --data avaliable
			  Empty   : OUT STD_LOGIC 
	);    
	end component;


 constant LOG2_OF_FIFO_DEPTH	: integer := 4; --10;	
 constant WRITE_ENA_THRESHOLD	:  integer := 18;
 constant ARRAY_SIZE	: integer := (2**BUFFES_SIZE_LOG_OF2); --256;
 constant DATA_ARRAY_WIDTH_LSB : integer := 8;
 type DATA_ARRAY is array (ARRAY_SIZE-1 downto 0) of std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);

type sb_state_machine is
(
 bs_idle,
 bs_wait_for_dav,
 bs_wait_for_data,
 bs_arbit_req,
 bs_wait_for_rearbit
);

--constant	 bs_idle				: std_logic_vector(2 downto 0) := "001";
--constant	 bs_wait_for_dav		: std_logic_vector(2 downto 0) := "010";
--constant	 bs_wait_for_data		: std_logic_vector(2 downto 0) := "011";
--constant	 bs_arbit_req			: std_logic_vector(2 downto 0) := "100";
--constant	 bs_wait_for_rearbit    : std_logic_vector(2 downto 0) := "101";

 
--type alloc_machine is
--(
--wait_for_data,	   
--wait_for_user_req,
--tag_alloc,		      
--tag_commint,	     
--tag_commint_delay
--);
 
constant	 wait_for_data			: std_logic_vector(2 downto 0) := "000";
constant	 wait_for_user_req		: std_logic_vector(2 downto 0) := "001";
constant	 tag_alloc				: std_logic_vector(2 downto 0) := "010";
constant	 tag_commint			: std_logic_vector(2 downto 0) := "011";
constant	 tag_commint_delay		: std_logic_vector(2 downto 0) := "100";

-- signal br_state			: std_logic_vector(2 downto 0); 
 signal tag_alloc_stat 		: std_logic_vector(2 downto 0); 

 signal br_state			: sb_state_machine; 
-- signal tag_alloc_stat 		: alloc_machine; 

 
 signal payload_data_array 		: DATA_ARRAY;
 signal data_out 		: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
 signal write_index 	: integer range 0 to DATA_ARRAY'high;
 signal read_index 		: integer range 0 to DATA_ARRAY'high;
 signal read_index_d 	: integer range 0 to DATA_ARRAY'high;
 signal read_sig 		: std_logic;
 signal write_rdy		: std_logic;  
 signal write_ena_int	: std_logic;
 signal write_last_int	: std_logic;
 signal write_last_int_d	: std_logic;
 signal rw_diff			: integer range 0 to DATA_ARRAY'high+1 := 0;
 signal dw_in_buff		: integer range 0 to (DATA_ARRAY'high+1)*(PCIE_CORE_DATA_WIDTH/32);
 signal tx_buffer_space : std_logic_vector(31 downto 0);
 signal read_empty		: std_logic;
 
 signal overflow				: std_logic;
 
 signal burst_vector 		: std_logic_vector(77 downto 0);
 signal burst_rdy			: std_logic;
 signal burst_req			: std_logic;
 signal flush				: std_logic;
 signal burst_fifo_wc 		: std_logic_vector(LOG2_OF_FIFO_DEPTH-1 downto 0);
 signal burst_fifo_full		: std_logic;
 signal burst_fifo_rd_vect	: std_logic_vector(85 downto 0);
 signal burst_fifo_re		: std_logic;
 signal burst_fifo_dav		: std_logic;
 signal burst_fifo_empty	: std_logic;
 signal bytes_in_fifo		: integer range 0 to ARRAY_SIZE*32;
 signal curr_burst_len		: integer range 0 to 4096;
 signal curr_burst_dir		: std_logic;
 signal curr_burst_sys_addr	: std_logic_vector(63 downto 0);	
 signal arbit_req			: std_logic;
 signal arbit_grnt			: std_logic;
 signal rearbit_req			: std_logic; 
 signal burst_out_vect		: std_logic_vector(85 downto 0);
 signal alloc_tag_req		: std_logic;
  
 
 signal tag_2_commit		: std_logic_vector(7 downto 0);
 
 signal burst_fifo_Wd		: std_logic_vector(85 downto 0);
 signal burst_fifo_We		: std_logic;
 
 signal burst_len			:  std_logic_vector(12 downto 0);
 signal burst_sys_addr		:  std_logic_vector(63 downto 0);
 signal reset_fifo			:  std_logic;
 signal tag_counter			:  std_logic_vector(3 downto 0);
 
 signal allocated_tag_rdy	:  std_logic;
 signal allocated_tag		:  std_logic_vector(7 downto 0);
 
 signal r_cnt : std_logic_vector(31 downto  0);
 signal w_cnt : std_logic_vector(31 downto  0);
 
 signal evabl_disable 	: std_logic;
 signal eval_1usec_cnt  : integer range 0 to 125000000;
 signal eval_sec_cnt   :  integer range 0 to 100000000;

 signal write_mem_tag	: std_logic_vector(7 downto 0);
 
 attribute keep: string;
 attribute keep of rw_diff : signal is "ture"; 
 attribute keep of br_state : signal is "ture";
 attribute keep of curr_burst_len : signal is "true";

 attribute keep of burst_req : signal is "true";
 attribute keep of burst_len : signal is "true";
 attribute keep of burst_sys_addr : signal is "true"; 
 attribute keep of burst_fifo_empty : signal is "true";	
 attribute keep of tag_alloc_stat : signal is "true";
 attribute keep of arbit_req	 : signal is "true";
 attribute keep of arbit_grnt	 : signal is "true";
 attribute keep of alloc_tag_req : signal is "true";
 attribute keep of allocated_tag_rdy : signal is "true";
 attribute keep of allocated_tag	 : signal is "true";
 attribute keep of tag_2_commit 	: signal is "true";
 attribute keep of burst_fifo_Wd 	: signal is "true";
 attribute keep of burst_fifo_We    : signal is "ture";
 
 
begin



 

 	data_out <= payload_data_array(read_index);
 
 



 
 write_rdy_proc : process(clk_i)
 begin
 	if rising_edge(clk_i) then
		if reset_n_i = '0' or flush = '1' then
			write_rdy <= '0';
		else
			-- after a read check if there is space to enable a nother read
			--if read_sig = '1' and rw_diff > 32 then
			write_rdy <= '1';
			if rw_diff < WRITE_ENA_THRESHOLD then --DATA_ARRAY'high-40 then
				write_rdy <= '0';
			end if;
		end if; 	
 	end if;
 end process;

 
read_empty_proc :  process(clk_i)
 begin
 	if rising_edge(clk_i) then
		if reset_n_i = '0' or flush = '1' then
			read_empty <= '1';
			dw_in_buff <= 0;
		else
			dw_in_buff <= DATA_ARRAY'high+1 - rw_diff; 		
		
			read_empty <= '0';
			--if read_sig = '1' and dw_in_buff = 0 then
			--if dw_in_buff = 0 then
			if rw_diff = DATA_ARRAY'high+1  or w_cnt = r_cnt then
				read_empty <= '1';		
			end if;
		end if; 	
 	end if;
 end process;
 
 
 process(clk_i)
 begin
 	if rising_edge(clk_i) then
		read_index_d <= read_index; 
  	end if;
 end process;	
 
 process(clk_i)
 begin
 	if rising_edge(clk_i) then
		if reset_n_i = '0' or flush = '1' then
			write_ena_int <= '0';
			write_last_int <= '0';
			
			write_last_int_d <= '0';
		else
			write_ena_int <= write_ena_i;
			write_last_int <= write_last_i;
			
			write_last_int_d <= write_last_int;
		end if; 	
 	end if;
 end process;
 
 read_sig <= '1' when read_index /= read_index_d else '0' ;
 tx_buffer_space <= conv_std_logic_vector(rw_diff,tx_buffer_space'high+1);
 
rw_diff_proc : process(clk_i)
begin
	if rising_edge(clk_i) then
		if reset_n_i = '0' or flush = '1' then
			rw_diff <= DATA_ARRAY'high+1;
			r_cnt <= (others => '0');
			w_cnt <= (others => '0');
		else
		
			if read_sig = '1' then
				r_cnt <= r_cnt+1;
			end if;

			if write_ena_i = '1' then
				w_cnt <= w_cnt+1;
			end if;
			
	 		if read_sig = '1' and  write_ena_i = '0' then
	 			rw_diff <= rw_diff + 1;
	 		elsif read_sig = '0' and  write_ena_i = '1' then
	 			rw_diff <= rw_diff - 1;
	 		end if;
	 			 		
		end if;
	end if;
end process;
 

  
 process(clk_i)
 begin
 	if rising_edge(clk_i) then
 		if reset_n_i = '0' or flush = '1' then
 			write_index <= read_index;
 		else
	 		if write_ena_i = '1' then 
	 			payload_data_array(write_index)   <= write_data_i;
	 		end if;
	 			
	 		if write_ena_i = '1' and write_index = DATA_ARRAY'high then
	 			write_index <= 0;
	 		elsif write_ena_i = '1' then
	 			write_index <= write_index+1;
	 		end if;
 		end if;	
 	end if;
 end process;
 
 process(clk_i)
 begin
	if rising_edge(clk_i) then
		if reset_n_i = '0' or flush = '1' then
			overflow <= '0';
		else
			if write_index = read_index and read_empty = '0' then
				overflow <= '1';
			end if;
		end if;
	end if;
 end process;
 
 process(clk_i)
 begin
	if rising_edge(clk_i) then
		burst_vector <= 	'0' & burst_len_i & burst_sys_addr_i;
		rearbit_req <= rearbit_req_i;
		arbit_grnt <= arbit_grnt_i;
	end if;
 end process;


 process(clk_i)
 begin
 	if rising_edge(clk_i) then
 		flush <= flush_i;
 		reset_fifo <= reset_n_i and not flush;
 	end if;
 end process;
 
 process(clk_i)
 begin
	if rising_edge(clk_i) then
		if reset_n_i = '0' then
			burst_len 		<= (others => '0');
			burst_sys_addr 	<= (others => '0');
			burst_req <= '0';
		else
			burst_req <= burst_req_i;
			if burst_req = '1' then
				burst_len 		<= 	burst_len_i;
				burst_sys_addr 	<= burst_sys_addr_i;
				
			end if;
		end if;
	end if;
 end process;
 

process(clk_i)
 begin
	if rising_edge(clk_i) then
		if reset_n_i = '0' or flush = '1' then
			burst_rdy <= '0';
			tag_alloc_stat <= wait_for_data;
			
			burst_fifo_Wd	<= (others => '0');
			burst_fifo_We <='0';
			alloc_tag_req <= '0';
			tag_counter <= (others => '0');
			tag_2_commit <= (others => '0');
			write_mem_tag <= (others => '0');
			allocated_tag_rdy <= '0';
			allocated_tag <= (others => '0');
		else
			burst_rdy <= '0';
			burst_fifo_We <='0';
			burst_fifo_Wd	<= (others => '0');
			alloc_tag_req <= '0';
			tag_2_commit <= (others => '0');
			
			allocated_tag_rdy <= allocated_tag_rdy_i;
			allocated_tag	  <= allocated_tag_i;
			
			case tag_alloc_stat is 
				when wait_for_data =>
					--if burst_fifo_wc < 30 then
					if burst_fifo_full = '0' then
						tag_alloc_stat <= wait_for_user_req;
					end if;
				when wait_for_user_req =>
					
					burst_rdy <= '1';
					if burst_req = '1'   then	
						tag_alloc_stat <= tag_alloc;
						burst_rdy <= '0';
						alloc_tag_req <= '1';
					end if;
					 
				when tag_alloc =>
						alloc_tag_req <= '1';
						if allocated_tag_rdy = '1' then
							tag_2_commit <= allocated_tag;
							tag_alloc_stat <= tag_commint;				
						end if;
				when tag_commint =>
						burst_fifo_We <= '1';
						burst_fifo_Wd <=  tag_2_commit &  '0' & burst_len & burst_sys_addr;--burst_vector;
						tag_counter <= tag_counter+1;
						tag_alloc_stat <= tag_commint_delay;
				when tag_commint_delay =>
						tag_alloc_stat <= wait_for_data;		
				when others =>
				        tag_alloc_stat <= wait_for_data;		
			end case;
		end if;
	end if;
 end process;
 
 process(clk_i)
 begin
 	if rising_edge(clk_i) then
	 	if reset_n_i = '0' or flush = '1' then
			burst_fifo_re <= '0';
			arbit_req <= '0';
			br_state <= bs_idle;
			burst_out_vect <= (others => '0');
			curr_burst_len	<= 0;
			stop_rq_ack_o <= '0';			
		else
			burst_fifo_re <= '0';
			arbit_req <= '0';
			stop_rq_ack_o <= '0';
			
			case br_state is
				when bs_idle =>
					if burst_fifo_empty = '0'  then
						burst_fifo_re <= '1';
						br_state <= bs_wait_for_dav;
					end if;	 
					
					-- 
					if burst_fifo_empty = '1' and stop_req_pending_i = '1' and wr_active_i = '0' then
						stop_rq_ack_o <= '1';		
					end if;
					
				when bs_wait_for_dav =>
					if burst_fifo_dav = '1' then
						burst_out_vect <= burst_fifo_rd_vect;
					end if; 	
					
					curr_burst_len	<= conv_integer(burst_fifo_rd_vect(76 downto 64));
					
					
					if stop_req_pending_i = '1' and burst_fifo_dav = '1' and burst_fifo_rd_vect(77) = '1' then
						stop_rq_ack_o <= '1';		
						br_state <= bs_idle;
					elsif burst_fifo_dav = '1' and burst_fifo_rd_vect(77) = '1' and conv_integer(burst_fifo_rd_vect(76 downto 64)) > bytes_in_fifo then
						br_state <= bs_wait_for_data;
					elsif burst_fifo_dav = '1' then
						br_state <= bs_arbit_req;
						arbit_req <= '1';
					end if;
					
				when bs_wait_for_data =>
				
					if stop_req_pending_i = '0'  then
						stop_rq_ack_o <= '1';		
						br_state <= bs_idle;
					elsif curr_burst_len >  bytes_in_fifo then   
						br_state <= bs_wait_for_data;
					else
						br_state <= bs_arbit_req;
						arbit_req <= '1';
					end if;		
						
				when  bs_arbit_req =>
					arbit_req <= '1';
					
					if arbit_grnt = '1' then
						--br_state <= bs_wait_for_rearbit;
						arbit_req <= '0';
						br_state <= bs_idle;
					end if;	
				--when bs_wait_for_rearbit =>
				--	arbit_req <= '1';
				--	
				--	if rearbit_req = '1' then
				--		arbit_req <= '0';
				--	end if;
				--	
				--	if rearbit_req = '1' then
				--		br_state <= bs_idle;
				--	end if;
				when others =>
				    br_state <= bs_idle;                        		
			
			end case;
				
		end if;
	end  if;
end process;
 
-- front_buff_xilinx_gen: if XILINX_MODE = 1 generate 
-- 
-- burst_info_fifo : tx_front_buff_fifo_wrapper 
-- port map
-- (
--         C => clk_i,
--         R  => reset_fifo, --reset_n_i,
--         --Write side
--         wc	   => burst_fifo_wc,
--         Wd     => burst_fifo_Wd,
--         WE     => burst_fifo_We,
--         Full   => burst_fifo_full,
--         --read side
--         Rd      => burst_fifo_rd_vect,
--         RE      => burst_fifo_re,
--         Dav     => burst_fifo_dav,
--         Empty   => burst_fifo_empty
-- ); 
-- end generate;

--front_buff_altera_gen: if XILINX_MODE = 0 generate 
burst_info_fifo : FIFO_core_wc --tx_front_buff_fifo_wrapper 
generic map
(
	Data_Width => 86,
	Log2_of_Depth => LOG2_OF_FIFO_DEPTH --10
)
port map
(
        C => clk_i,
        R  => reset_fifo, --reset_n_i,
        --Write side
        wc		=> burst_fifo_wc,
        Wd     => burst_fifo_Wd,
        WE     => burst_fifo_We,
        Full   => burst_fifo_full,
        --read side
        Rd      => burst_fifo_rd_vect,
        RE      => burst_fifo_re,
        Dav     => burst_fifo_dav,
        Empty   => burst_fifo_empty
); 
--end generate;


 --curr_burst_len	<= conv_integer(burst_out_vect(76 downto 64));
 
 bytes_in_fifo_64_gen:  if PCIE_CORE_DATA_WIDTH = 64 generate
 	bytes_in_fifo	<= conv_integer((conv_std_logic_vector(dw_in_buff,13) & "000"));
 end generate;
 
 bytes_in_fifo_128_gen:  if PCIE_CORE_DATA_WIDTH = 128 generate
 	bytes_in_fifo	<= conv_integer((conv_std_logic_vector(dw_in_buff,13) & "0000"));
 end generate;

 bytes_in_fifo_256_gen:  if PCIE_CORE_DATA_WIDTH =256 generate
 	bytes_in_fifo	<= conv_integer((conv_std_logic_vector(dw_in_buff,13) & "00000"));
 end generate;
 
 
  
 curr_burst_dir				<= burst_out_vect(77);
 curr_burst_sys_addr		<= burst_out_vect(63 downto 0);	
	
 
 read_index <= conv_integer(read_index_i);
 	
 tx_buffer_space_o <= tx_buffer_space;
 wc_o			<= dw_in_buff;
 write_rdy_o 	<= write_rdy;
 read_data_o 	<= data_out;
 read_empty_o 	<= read_empty;
 arbit_req_o	<= arbit_req;
 overflow_o <= overflow;
 burst_rdy_o <= burst_rdy;
 alloc_tag_req_o <= alloc_tag_req;
 burst_len_out_o		<= burst_out_vect(76 downto 64);
 burst_dir_out_o		<= burst_out_vect(77);
 burst_sys_addr_out_o	<= burst_out_vect(63 downto 0);
 burst_tag_o			<= burst_out_vect(85 downto 78);

 
  
 
 

 
end arc;