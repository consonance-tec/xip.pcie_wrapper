----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    08:15:40 12/24/2010 
-- Design Name: 
-- Module Name:    system_registers - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--

-- bugs:
-- suspet a situation in which bm_req = 1 and state = idle - check this

--MSIx Settings for xilix: table size 20H, table offset 80, bar 1,0 PBA offst c0

-- Todo List:
-- 1) we always have 5 recores left when going into staus_0 see why 


----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use ieee.math_real.all;


entity s2c_sg_bm is
generic
(
	CHAN_NUM			: integer := 0;
	PCIE_CORE_DATA_WIDTH : integer := 128;
	ONE_USEC_PER_BUS_CYCLE : integer := 250;
	SWAP_ENDIAN			 		: integer := 1;
	MAX_USER_RX_REQUEST_SIZE 	: integer 	:= 4096; --256; --4096;
	NUM_NUM_OF_USER_RX_PENDINNG_REQUEST : integer := 2;
	DIRECTION 					: std_logic := '0';
	RGDMA_SUPPROT				: std_logic := '0'
);
Port ( 
	-- system i/f
	reset_n_i 					: in  STD_LOGIC;
    clk 						: in  STD_LOGIC;
	
	msix_enabled_i				: in std_logic;
	max_payload_size_i			: in std_logic_vector(12 downto 0);
	max_read_request_size_i 	: in std_logic_vector(12 DOWNTO 0);
	
	msix_vector_control_i		: in std_logic_vector(31 downto 0);
	msix_msg_data_i				: in std_logic_vector(31 downto 0) := (others => '0');
	msix_msg_uppr_addr_i		: in std_logic_vector(31 downto 0);
	msix_msg_addr_i				: in std_logic_vector(31 downto 0);
	
	
	
	sys_ena_i 					: in std_logic;
	bm_ena_clr_i 				: in std_logic;
	bm_start_i					: in std_logic;
	bm_stop_i					: in std_logic;
	bm_wait_for_int_ack_i 		: in std_logic;
	bm_int_ack_i				: in std_logic;
	state_o						: out std_logic;
	
	
-- interrupt signals 	
	int_gen_o					: out std_logic;
	
  --  tx bm i/f
	tx_sys_addr_o    			: out  std_logic_vector(63 downto 0);
	tx_dir_o					: out  std_logic;
	tx_last_o					: out  std_logic;
	tx_active_i					: in  std_logic;
	tx_done_i					: in  std_logic;
	tx_burst_size_o				: out std_logic_vector(12 downto 0);
	tx_data_valid_o 	 		: out std_logic;
	tx_data_o    	  			: out  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	tx_bufffer_space_i			: in std_logic_vector(31 downto 0);
	
	
	status_ack					: in std_logic;
	status_req					: out std_logic;
	status_qword				: out std_logic_vector(63 downto 0);
	status_addr					: out std_logic_vector(63 downto 0);

	buffer_rdy_o				: out std_logic;		
	
  -- rx bm i/f
  
  	rx_data_i    	  			: in  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	rx_done_i					: in  std_logic;
	rx_active_i					: in  std_logic;
	bm_rx_rdy_o					: out std_logic;
	bm_rx_last_in_burst_i 		: in  std_logic;
	rx_be_i						: in  std_logic_vector((PCIE_CORE_DATA_WIDTH/8)-1 downto 0);
 	
 -- bus master initiator <--> arbiter i/f	
	bm_req_o			   		: out 	std_logic;
	bm_rdy_i			   		: in 	std_logic;
	context_o					: out 	std_logic_vector(31 downto 0);
	
    bm_transfer_size_o          	: out std_logic_vector(31 downto 0); 
    bm_transfer_size_valid_o    	: out std_logic;
  	
	
	bm_packet_ack_i					: in std_logic;

	bm_req_address_i				: in std_logic_vector(63 downto 0);	
	bm_tx_data_front_buff_empty_i	: in std_logic;	
	bm_tx_data_fron_buff_flush_o 	: out std_logic;
	bm_context_i					: in std_logic_vector(31 downto 0);
	stop_req_pending_o				: out std_logic;
	stop_rq_ack_i					: in std_logic;
-- bm intiator i/f
	
	bmi_bm_tag_data_o			: out 	std_logic_vector(15 downto 0);
	bmi_status_i				: in 	std_logic_vector(9 downto 0);
	bmi_rx_rdy_i				: in 	std_logic;
	bmi_tx_last_i				: in 	std_logic;
	bmi_tx_data_valid_i 	 	: in 	std_logic;
	bmi_tx_empty_i				: in	std_logic_vector(integer(log2(real(PCIE_CORE_DATA_WIDTH/8)))-1 downto 0);
	bmi_tx_data_i    	  		: in  	std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	bmi_rx_data_o				: out   std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	bmi_rx_data_valid_o			: out  	std_logic;
	bmi_rx_last_o				: out 	std_logic;
	bmi_rx_be_o					: out   std_logic_vector(integer(log2(real(PCIE_CORE_DATA_WIDTH/8)))-1 downto 0);
	bmi_rx_first_o				: out   std_logic;
	bmi_rx_pending_o			: out   std_logic_vector(31 downto 0);
	
	bmi_tx_data_rdy_o			: out  	std_logic;
	bmi_transfer_done_o 		: out  	std_logic;
		
	
	tx_error_i					: in 	std_logic;

	chnn_gp_in_0_o				: out std_logic_vector(31 downto 0);
	chnn_gp_in_1_o				: out std_logic_vector(31 downto 0);
	chnn_gp_out_0_i				: in std_logic_vector(31 downto 0);
	chnn_gp_out_1_i				: in std_logic_vector(31 downto 0);

	dbg_signal_o				: out 	std_logic;
	
	dbg0_reg_0					: out  std_logic_vector(4 downto 0);
	
	dbg_word_o					: out  std_logic_vector(255 downto 0)
);
end s2c_sg_bm;

architecture Behavioral of s2c_sg_bm is

 function log2( i : natural) return integer is
    variable temp    : integer := i;
    variable ret_val : integer := 0; 
  begin					
    while temp > 1 loop
      ret_val := ret_val + 1;
      temp    := temp / 2;     
    end loop;
  	
    return ret_val;
  end function;	 

  
 function all_ones(vec : std_logic_vector) return boolean is
 	variable r : boolean := true;
 begin
 	for i in 0 to vec'high loop
 		if vec(i) = '0' then
 			r := false;
 		end if;
 	end loop;
 	return r;
 end function; 
  
 function or_sum(vec : std_logic_vector) return std_logic is  
 	variable ored_sum : std_logic := '0';
 begin
 
 	for i in 0 to vec'high loop
 		ored_sum := ored_sum or vec(i); 
 	end loop;
 	
 	return ored_sum;
 end function;
  
  
 function or_sum_vect(res_size : integer; vec : std_logic_vector) return std_logic_vector is  
 	variable ored_sum : std_logic_vector(res_size-1 downto 0) := (others => '0');
 begin
 
 	for i in 0 to vec'high loop
 		ored_sum(0) := ored_sum(0) or vec(i); 
 	end loop;
 	
 	return ored_sum;
 end function;
 	

---input  vector: [31-24][23-16][15-8][7-0]----
---output vector: [7-0][15-8][23-16][31-24]----
	function endigan_swap(vect : std_logic_vector) return std_logic_vector
	is
	variable swapped_vector : std_logic_vector(31 downto 0);
	begin
		swapped_vector := vect(vect'low+7 downto vect'low+0) & vect(vect'low+15 downto vect'low+8) & vect(vect'low+23 downto vect'low+16) & vect(vect'low+31 downto vect'low+24);
		return swapped_vector;
	end function; 
	
	
	function records_per_write_cycle return integer
	is
		variable ret : integer := 1;
	begin
		if PCIE_CORE_DATA_WIDTH = 256 then
			ret := 2;
		end if;	
		return ret;
	end function;

component  status_interrupt_gen is
generic 
(
	PCIE_CORE_DATA_WIDTH 	: integer := 128;
	CHAN_NUM				: integer := 0;
	SWAP_ENDIAN				: integer := 1
);
port 
(
	clk_in                 	: in std_logic;
    rstn                   	: in std_logic;
    
    start_req				: in std_logic;
    stop_req				: in std_logic;
    first_desc_addr			: in std_logic_vector(63 downto 0);
    
    desc_rdy_sig			: out std_logic;
    
    tx_req 					: out std_logic; 
    tx_grnt 				: in  std_logic;
    
    msix_enabled			: in  std_logic;
    msix_vector_control		: in  std_logic_vector(31 downto 0);
	msix_msg_data			: in  std_logic_vector(31 downto 0);
	msix_msg_addr			: in  std_logic_vector(63 downto 0);
    
    do_interrupt 			: out std_logic;

    record_req				: in  std_logic;
    record_valid			: out std_logic;
    record_out				: out std_logic_vector(95 downto 0);

    bm_transfer_size_o          :  out std_logic_vector(31 downto 0); 
    bm_transfer_size_valid_o    : out std_logic;
    
            
    gen_status_req			: in  std_logic;
	status_interrupt_done	: out std_logic;
    transfer_count			: in  std_logic_vector(31 downto 0);
    
    
    status_ack				: in  std_logic;
	status_addr_out			: out std_logic_vector(63 downto 0); 
	status_req_out			: out std_logic;
	status_qword_out 		: out std_logic_vector(63 downto 0);
	
	tx_ready               : in  std_logic;
	tx_data                 : out std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0); 
	tx_data_valid			: out std_logic;	
	tx_last					: out std_logic;
	tx_sys_addr             : out std_logic_vector(63 downto 0);
	tx_burst_size           : out std_logic_vector(13 downto 0);
	tx_dir                  : out std_logic;
	tx_context				: out std_logic_vector(31 downto 0);

	req_active				: out std_logic;
	
	context_in				: in std_logic_vector(31 downto 0);	
  	rx_data    	  			: in  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	rx_done					: in  std_logic;
	rx_active				: in  std_logic;
	bm_rx_last_in_burst 	: in  std_logic;
	rx_be_i					: in  std_logic_vector((PCIE_CORE_DATA_WIDTH/8)-1 downto 0)	
	
	
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
	


type state_type is 
(
	SG_STATE_IDLE,
	SG_STATE_WAIT_FOR_REC,
	SG_WAIT_FOR_CLI_ZERO,
	SG_STATE_WAIT_CLI_PRE_STATUS,
	SG_READ_NEX_RECORD,
	SG_PREPARE_NEXT_RECORD_SEGMENT,
	SG_WAIT_FOR_DATA_IN_DONE,
	SG_DATA_TRANSFER_RDY,
	SG_WAIT_FOR_FRONT_BUFF_EMPTY,
	SG_WAIT_FOR_RX_RDY,
	SG_DATA_ARBIT_REQ,
	SG_DATA_TRANSFER,
	SG_STATE_STATUS_0,
	SG_STATE_STOP,
	SG_WAIT_FOR_DATA_TRANSFER,
	SG_WAIT_FOR_GNT,
	SG_OUT_ADDR_INC,
	SG_WAIT_FOR_GRNAT_SIG,
	SG_WAIT_ON_RX_USER_BUFFER
);
signal sm_state : state_type;
signal sm_next_state : state_type;
signal prev_state : state_type;

constant	BUS_WORDS_PER_PACKET : integer		:= MAX_USER_RX_REQUEST_SIZE/(PCIE_CORE_DATA_WIDTH/8); 

constant	FIFO_DEPTH	: integer := BUS_WORDS_PER_PACKET*(NUM_NUM_OF_USER_RX_PENDINNG_REQUEST+1);
constant	USER_FIFO_DEPTH_LOG2 : integer := log2(FIFO_DEPTH); 

constant GET_DATA_REQ	: std_logic_vector(7 downto 0) := x"04";


signal expected_rec_add	: std_logic_vector(31 downto 0);



-- entity port signals:
-- in
signal max_payload_size				:  std_logic_vector(12 downto 0);
signal max_read_request_size 		:  std_logic_vector(12 DOWNTO 0);
signal sys_ena 						:  std_logic;
signal bm_rdy			   			:  std_logic;
signal bm_packet_ack				:  std_logic;
signal bm_req_address				:  std_logic_vector(63 downto 0);
signal bm_tx_data_front_buff_empty	:  std_logic;
signal bm_tx_data_front_buff_empty_d	:  std_logic;
signal bm_tx_data_front_buff_empty_sig	:  std_logic;
signal stop_sig 					:  std_logic;
signal flush_sig 					:  std_logic;	
signal rx_be						:  std_logic_vector(log2(PCIE_CORE_DATA_WIDTH/8)-1 downto 0);
signal rx_data   	  				:  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
signal rx_data_d					:  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
signal rx_data_d1					:  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
signal rx_done						:  std_logic;
signal rx_done_d					:  std_logic;
signal rx_done_d1					:  std_logic;
signal rx_active					:  std_logic;
signal bm_rx_last_in_burst 			:  std_logic;
signal tx_active					:  std_logic;
signal bm_ena_clr 					:  std_logic;
signal bm_start						:  std_logic;
signal bm_stop						:  std_logic;
signal tx_data_valid_int 			:  std_logic;
signal tx_data    	  				:  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);

-- out
signal tx_sys_addr	  				:  std_logic_vector(63 downto 0);
signal bm_req			   			:  std_logic;
signal tx_dir						:  std_logic;
signal tx_last						:  std_logic;
signal rx_last 						:  std_logic;

signal user_context_s				:  std_logic_vector(31 downto 0);
signal tx_sys_addr_s 				:  std_logic_vector(63 downto 0);
signal tx_burst_size_s				:  std_logic_vector(13 downto 0);
signal tx_dir_s 					:  std_logic;
signal bm_transfer_size             :  std_logic_vector(31 downto 0); 
signal bm_transfer_size_valid       :  std_logic;


signal bmi_tx_data_valid			:  std_logic;
signal bmi_tx_last					:  std_logic;
signal bmi_tx_last_d				:  std_logic;
signal bmi_tx_last_sig				:  std_logic;
signal bmi_tx_last_sig_d			:  std_logic;
signal bmi_tx_last_sig_d1			:  std_logic;	

signal bm_grnt_cnt					:  std_logic_vector(31 downto 0);

signal data_burst_arbit				:  std_logic;	
signal data_arbit_rdy               :  std_logic;

signal desc_rdy_sig					:  std_logic;

signal dbg0_reg						:  std_logic_vector(5 downto 0);
signal dbg_out_state				:  std_logic_vector(5 downto 0);

signal stall_end_of_buffer			:  std_logic;
 
signal bm_rdy_d						:  std_logic;
signal bm_rdy_re					:  std_logic;

signal toggle_rec					: std_logic;
signal rx_data_arbit_req 			: std_logic;
signal last_read_req 				: std_logic;
signal desc_valid       			: std_logic;

signal transfer_index				: std_logic_vector(11 downto 0);

signal msix_msg_addr			:   std_logic_vector(63 downto 0);

signal stat_int_tx_req 				: std_logic; 
signal stat_int_tx_grnt 			: std_logic := '0';
signal stat_int_tx_grnt_d 			: std_logic;
signal stat_int_tx_grnt_sig			: std_logic;
signal stat_int_tx_data             : std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0); 
signal stat_int_tx_data_valid		: std_logic;	
signal stat_int_tx_last				: std_logic;
signal stat_int_tx_sys_addr         : std_logic_vector(63 downto 0);
signal stat_int_tx_burst_size       : std_logic_vector(13 downto 0);
signal stat_int_tx_dir              : std_logic;
signal stat_int_context				: std_logic_vector(31 downto 0);

signal stat_int_status_addr			: std_logic_vector(63 downto 0); 
signal stat_int_status_req			: std_logic;
signal stat_int_status_qword 		: std_logic_vector(63 downto 0);


-----------------------------------------------------------------------------------------------------
-------------------------------------------- internal signals ---------------------------------------
-----------------------------------------------------------------------------------------------------


signal recores_left				: integer range 0 to 40996;
signal rec_load_buff			: std_logic_vector(3 downto 0);
signal records_mem_we			: std_logic;
signal records_mem_we_odd 		: std_logic;
signal records_mem_we_even		: std_logic;

signal records_mem_wd			: std_logic_vector((records_per_write_cycle*3*32)-1 downto 0);
signal rec_fifo_write			: std_logic;
signal data_fifo_rd_ena			: std_logic;
signal rec_fifo_dav				: std_logic;

signal data_fifo_rd_ena_d2      : std_logic;
signal data_fifo_rd_ena_d1 		: std_logic;

signal rec_to_fifo_d			: std_logic_vector((records_per_write_cycle*3*32)+32-1 downto 0);
signal rec_fifo_write_d			: std_logic;	

signal rec_mem_wr_address		: std_logic_vector(31 downto 0);
signal rec_mem_rd_address		: std_logic_vector(31 downto 0);
signal rec_to_fifo				: std_logic_vector((records_per_write_cycle*3*32)+32-1 downto 0);
signal rec_fifo_read_data		: std_logic_vector((3*32)-1 downto 0);
signal sg_buffer_address 		: std_logic_vector(63 downto 0);
signal sg_transfer_size 		: std_logic_vector(31 downto 0);
signal sg_next_record_address 	: std_logic_vector(63 downto 0);
signal sg_rec					: std_logic_vector(95 downto 0);
signal sg_rec_buffer_size 		: std_logic_vector(31 downto 0);
signal sg_rec_list_address		: std_logic_vector(63 downto 0);
signal sg_last_record			: std_logic;
signal sg_first_record			: std_logic;
signal first_record_sig			: std_logic;
signal first_rec				: std_logic;



signal sg_dir					: std_logic;
signal sg_last_desc					: std_logic;
signal sg_cyclic				: std_logic;
signal curr_raq_add				: std_logic_vector(63 downto 0);
signal sg_active				: std_logic;
signal sg_status_addr			: std_logic_vector(63 downto 0);
signal sg_desc_signiture		: std_logic_vector(31 downto 0);

signal rec_0_dry				: std_logic;

signal cli_count				:  integer range 0 to (2**30);
signal tx_accum_for_burst		: integer range 0 to (2**30);
signal bm_rec_req_pending 		: std_logic;
signal bm_data_system_address : std_logic_vector(63 downto 0);
signal rec_rdy					: std_logic;
signal do_data_req				: std_logic;
signal stop_req					: std_logic;
signal bm_active				: std_logic;
signal curr_transfer_size 		: std_logic_vector(31 downto 0);
signal curr_transfer_done  		: std_logic;
signal burst_active				: std_logic;
signal bm_inturnal_req_active	: std_logic;
signal tx_burst_size			: std_logic_vector(13 downto 0);
signal rx_data_rdy				: std_logic;
signal rx_data_rdy_mult			: std_logic;
signal rx_data_rdy_fe			: std_logic;
signal rx_data_rdy_d			: std_logic;
signal tx_data_rdy				: std_logic;
signal do_interrupt				: std_logic;


signal dbg_out						: std_logic;
signal dbg_out1					: std_logic;

signal state_tics_cnt			: integer range 0 to 30000;


--signal pre_data_arbit_wait_cnt : integer range 0 to 200;

signal tx_error					: std_logic;
signal curr_transfer_done_d	: std_logic;
signal transfer_done_sig	: std_logic;

signal record_reading_active	: std_logic;
signal record_reading_done_sig	: std_logic;

signal data_aligned 			:   std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
signal data_rdy_aligned		:   std_logic;
signal be_aligned				:   std_logic_vector((PCIE_CORE_DATA_WIDTH/8)-1 downto 0);
signal transfer_done_aligned	:   std_logic;
signal transfer_done_aligned_d	:   std_logic;
signal transfer_done_aligned_d1	:   std_logic;
signal rec_fifo_dav_d			:	std_logic;

signal user_fifo_rx_data_rdy			:	std_logic;
signal pending_mrd_requests : integer range 0 to 256;
signal transfer_count			: std_logic_vector(31 downto 0);
signal curr_tx_burst_len  		: std_logic_vector(13 downto 0);
signal tx_burst_rdy				: std_logic;			
signal record_fifo_reset_n		: std_logic;

signal transfer_count_fixed		: std_logic_vector(31 downto 0);

signal unallocated_user_fifo_spacce	: std_logic_vector(curr_tx_burst_len'high +1 - LOG2((PCIE_CORE_DATA_WIDTH/8))  downto 0);


signal 	user_data_rx_fifo_wc	: std_logic_vector(31 downto 0);
signal 	user_data_rx_fifo_Wd	: std_logic_vector(log2(PCIE_CORE_DATA_WIDTH/8)+PCIE_CORE_DATA_WIDTH+1 downto 0);
signal 	user_data_rx_fifo_WE	: std_logic;
signal 	user_data_rx_fifo_Full	: std_logic;
signal 	user_data_rx_fifo_Rd	: std_logic_vector(log2(PCIE_CORE_DATA_WIDTH/8)+PCIE_CORE_DATA_WIDTH+1 downto 0);
signal 	user_data_rx_fifo_RE	: std_logic;
signal 	user_data_rx_fifo_Dav	: std_logic;
signal 	user_data_rx_fifo_Empty	: std_logic;

signal 	user_last_write_sig		: std_logic;
 
signal  user_write				: std_logic;
signal  user_write_d			: std_logic;
signal 	bmi_rx_data_valid		: std_logic;
signal 	bmi_rx_data				: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
signal 	bmi_rx_last				: std_logic;
signal 	bmi_rx_be				: std_logic_vector(log2(PCIE_CORE_DATA_WIDTH/8)-1 downto 0);
signal  bmi_rx_first			: std_logic;
signal 	bmi_rx_first_sig        : std_logic;
signal  bmi_rx_first_d          : std_logic;


signal stall_tx					: std_logic;
signal stall_tx_sfr				: std_logic_vector(2 downto 0);
signal stall_latch				: std_logic;
signal stall_sig				: std_logic;

signal tx_last_letch			: std_logic;

signal status_req_int 			: std_logic;
signal status_qword_int			: std_logic_vector(63 downto 0);
signal status_addr_int			: std_logic_vector(63 downto 0);

signal do_stat_int				: std_logic;
signal status_interrupt_done	: std_logic;

signal context_in0				: std_logic_vector(31 downto 0);
signal context_in1				: std_logic_vector(31 downto 0);
signal context_in2				: std_logic_vector(31 downto 0);
signal context_in3				: std_logic_vector(31 downto 0);

signal user_context	: std_logic_vector(31 downto 0);
signal ss_sel : std_logic_vector(4 downto 0);
signal cout : std_logic_vector(2 downto 0);

signal direct_dma_counter : std_logic_vector(31 downto 0);

signal debug_out_register : std_logic_vector(31 downto 0);
signal dbg_cnt : integer range 0 to 2048;
signal curr_state_cnt :  std_logic_vector(31 downto 0);

signal arbit_backoff_cnt : integer range 0 to 4;

signal dbg_signal		: std_logic;

signal cc : integer range 0 to 250000;
signal bc : std_logic_vector(63 downto 0);

signal err_in_record : std_logic;

signal prev_desc_req : std_logic_vector(63 downto 0);

signal flush_out_buffers : std_logic;
signal flush_out  : std_logic;

signal last_cycle_in_transfer : std_logic;

signal next_user_data_rx_fifo_Wd : std_logic_vector(31 downto 0);

attribute keep: string;

attribute keep of user_last_write_sig : signal is "ture"; 
attribute keep of dbg0_reg : signal is "true";
attribute keep of dbg_out : signal is "true";
attribute keep of bmi_tx_data_valid : signal IS "true";
--attribute keep of tx_accum_for_burst : signal is "true";
attribute keep of transfer_count : signal is "true";
attribute keep of cli_count : signal is "true";
attribute keep of tx_burst_rdy : signal is "true";
attribute keep of stall_tx_sfr : signal is "true";
attribute keep of bm_inturnal_req_active : signal is "true";
attribute keep of tx_data : signal is "true"; 
attribute keep of tx_data_valid_int : signal is "true";


signal dbg_cycle_counter : std_logic_vector(63 downto 0) := (others => '0');

attribute syn_keep: boolean;
attribute syn_keep of rec_to_fifo_d: signal is true;



begin





  process(clk)
  begin
  
  if rising_edge(clk) then

		case sm_state is
				when SG_STATE_IDLE						=> dbg0_reg <= "000001";
				when SG_STATE_WAIT_FOR_REC				=> dbg0_reg <= "000011";
				when SG_WAIT_FOR_CLI_ZERO				=> dbg0_reg <= "000101";
				when SG_STATE_WAIT_CLI_PRE_STATUS		=> dbg0_reg <= "000110"; 
				when SG_READ_NEX_RECORD					=> dbg0_reg <= "000111";
				when SG_PREPARE_NEXT_RECORD_SEGMENT 	=> dbg0_reg <= "001000";
				when SG_WAIT_FOR_FRONT_BUFF_EMPTY		=> dbg0_reg <= "001001"; 
				when SG_WAIT_FOR_DATA_IN_DONE			=> dbg0_reg <= "001011"; 
				when SG_DATA_TRANSFER_RDY				=> dbg0_reg <= "001100";
				when SG_WAIT_FOR_RX_RDY					=> dbg0_reg <= "001101";
				when SG_DATA_ARBIT_REQ					=> dbg0_reg <= "001110";
				when SG_DATA_TRANSFER					=> dbg0_reg <= "001111";
				--when SG_STATE_STATUS_ARBIT_REQ			=> dbg0_reg <= "010000";
				when SG_STATE_STATUS_0					=> dbg0_reg <= "010001";	
				when SG_STATE_STOP						=> dbg0_reg <= "010011";
				when SG_WAIT_FOR_DATA_TRANSFER			=> dbg0_reg <= "010101";
				when SG_WAIT_FOR_GNT					=> dbg0_reg <= "011110";
				when SG_OUT_ADDR_INC			   		=> dbg0_reg <= "011111";
				when SG_WAIT_FOR_GRNAT_SIG				=> dbg0_reg <= "100010";
				when SG_WAIT_ON_RX_USER_BUFFER			=> dbg0_reg <= "100011";
				
			end case;
		end if;
	end process;

  process(clk)
  begin
  	if rising_edge(clk) then
		dbg_out1 <= dbg0_reg(0) or dbg0_reg(1) or dbg0_reg(2) or dbg0_reg(3) or dbg0_reg(4) or dbg0_reg(5);
	end if;
  end process;
    
  
  user_fifo_rx_data_rdy <= '1' 	when conv_integer(unallocated_user_fifo_spacce) > 0 else '0';
  
  
  
  

SWAP_USER_DATA_ON: if SWAP_ENDIAN = 1 generate
  process(clk)
  begin
  	if rising_edge(clk) then
  		for i in 0 to PCIE_CORE_DATA_WIDTH/32-1 loop 
			rx_data_d1(i*32+31 downto i*32)	<=  rx_data_d(i*32+7 downto i*32) & rx_data_d(i*32+15 downto i*32+8) & rx_data_d(i*32+23 downto i*32+16) & rx_data_d(i*32+31 downto i*32+24); 
		end loop;
	end if;
  end process;
end generate;
  
SWAP_USER_DATA_OFF: if SWAP_ENDIAN = 0 generate
  process(clk)
  begin
  	if rising_edge(clk) then
  		rx_data_d1	<=  rx_data_d; 
		
	end if;
  end process;
end generate;

  
	process(clk)
	begin
		if rising_edge(clk) then
			if reset_n_i = '0' then
				 unallocated_user_fifo_spacce <= conv_std_logic_vector(FIFO_DEPTH,unallocated_user_fifo_spacce'high+1);				
			else
				if(flush_sig = '1')then
					unallocated_user_fifo_spacce <= conv_std_logic_vector(FIFO_DEPTH,unallocated_user_fifo_spacce'high+1);
				elsif rx_data_arbit_req = '1' and user_data_rx_fifo_Dav = '1' then -- MRd reqeuest started and data shifted out of the fifo
					unallocated_user_fifo_spacce <= unallocated_user_fifo_spacce + 1 - (curr_tx_burst_len(curr_tx_burst_len'high downto LOG2((PCIE_CORE_DATA_WIDTH/8)))) + OR_SUM_VECT(curr_tx_burst_len'high+1-LOG2((PCIE_CORE_DATA_WIDTH/8))+1,curr_tx_burst_len(LOG2((PCIE_CORE_DATA_WIDTH/8))-1 downto 0));
				elsif rx_data_arbit_req = '1' then -- MRd reqeuest started
					unallocated_user_fifo_spacce <= unallocated_user_fifo_spacce - ((curr_tx_burst_len(curr_tx_burst_len'high downto LOG2((PCIE_CORE_DATA_WIDTH/8)))) + OR_SUM_VECT(curr_tx_burst_len'high+1-LOG2((PCIE_CORE_DATA_WIDTH/8))+1,curr_tx_burst_len(LOG2((PCIE_CORE_DATA_WIDTH/8))-1 downto 0)));
				elsif user_data_rx_fifo_Dav = '1' then -- data shifted out of the fifo
					unallocated_user_fifo_spacce <= unallocated_user_fifo_spacce + 1; 
				else
					unallocated_user_fifo_spacce <= unallocated_user_fifo_spacce;
				end if;
			end if;
		end if;
	end process; 	
    
 
gen_rx_be_128: if PCIE_CORE_DATA_WIDTH = 128 generate  
  process(clk)                                                   
  begin                                                          
  	if rising_edge(clk) then                                        
		user_data_rx_fifo_WE 	<= '0';
		user_data_rx_fifo_Wd	<= (others => '0');
  		if rx_active = '1' and context_in0(15 downto 8) = x"4" then    
			user_data_rx_fifo_WE 	<= '1';	  	
			
			case(conv_integer(rx_be_i)) is
			
				when 1  => 	rx_be	<=  conv_std_logic_vector(1,log2(PCIE_CORE_DATA_WIDTH/8));
				when 3  => 	rx_be	<=  conv_std_logic_vector(2,log2(PCIE_CORE_DATA_WIDTH/8));
				when 7  =>	rx_be	<=  conv_std_logic_vector(3,log2(PCIE_CORE_DATA_WIDTH/8));
				when 15 => 	rx_be	<=  conv_std_logic_vector(4,log2(PCIE_CORE_DATA_WIDTH/8));

				when 31  => 	rx_be	<=  conv_std_logic_vector(5,log2(PCIE_CORE_DATA_WIDTH/8));
				when 63  => 	rx_be	<=  conv_std_logic_vector(6,log2(PCIE_CORE_DATA_WIDTH/8));
				when 127 => 	rx_be	<=  conv_std_logic_vector(7,log2(PCIE_CORE_DATA_WIDTH/8));
				when 255 => 	rx_be	<=  conv_std_logic_vector(8,log2(PCIE_CORE_DATA_WIDTH/8));
				
				when 511  => 	rx_be	<=  conv_std_logic_vector(9,log2(PCIE_CORE_DATA_WIDTH/8));
				when 1023 => 	rx_be	<=  conv_std_logic_vector(10,log2(PCIE_CORE_DATA_WIDTH/8));
				when 2047 => 	rx_be	<=  conv_std_logic_vector(11,log2(PCIE_CORE_DATA_WIDTH/8));
				when 4095 => 	rx_be	<=  conv_std_logic_vector(12,log2(PCIE_CORE_DATA_WIDTH/8));

				when 8191  => rx_be	<=  conv_std_logic_vector(13,log2(PCIE_CORE_DATA_WIDTH/8));
				when 16383 => rx_be	<=  conv_std_logic_vector(14,log2(PCIE_CORE_DATA_WIDTH/8));
				when 32767 => rx_be	<=  conv_std_logic_vector(15,log2(PCIE_CORE_DATA_WIDTH/8));
	
				when others => rx_be <= (others => '0');			
								
			end case;
			
			        
			user_data_rx_fifo_Wd	<= rx_be & last_cycle_in_transfer & first_rec & rx_data;  
			
  		end if;                                             
	end if;                                                 
  end process;
 
end generate;
    
gen_rx_be_256: if PCIE_CORE_DATA_WIDTH = 256 generate  
  process(clk)                                                   
  begin                                                          
  	if rising_edge(clk) then                                        
		user_data_rx_fifo_WE 	<= '0';
		user_data_rx_fifo_Wd	<= (others => '0');
  		if rx_active = '1' and context_in0(15 downto 8) = x"4" then    
			user_data_rx_fifo_WE 	<= '1';	  	
			
			case(conv_integer(rx_be_i)) is
			
				when 1  => 	rx_be	<=  conv_std_logic_vector(1,log2(PCIE_CORE_DATA_WIDTH/8));
				when 3  => 	rx_be	<=  conv_std_logic_vector(2,log2(PCIE_CORE_DATA_WIDTH/8));
				when 7  =>	rx_be	<=  conv_std_logic_vector(3,log2(PCIE_CORE_DATA_WIDTH/8));
				when 15 => 	rx_be	<=  conv_std_logic_vector(4,log2(PCIE_CORE_DATA_WIDTH/8));

				when 31  => 	rx_be	<=  conv_std_logic_vector(5,log2(PCIE_CORE_DATA_WIDTH/8));
				when 63  => 	rx_be	<=  conv_std_logic_vector(6,log2(PCIE_CORE_DATA_WIDTH/8));
				when 127 => 	rx_be	<=  conv_std_logic_vector(7,log2(PCIE_CORE_DATA_WIDTH/8));
				when 255 => 	rx_be	<=  conv_std_logic_vector(8,log2(PCIE_CORE_DATA_WIDTH/8));
				
				when 511  => 	rx_be	<=  conv_std_logic_vector(9,log2(PCIE_CORE_DATA_WIDTH/8));
				when 1023 => 	rx_be	<=  conv_std_logic_vector(10,log2(PCIE_CORE_DATA_WIDTH/8));
				when 2047 => 	rx_be	<=  conv_std_logic_vector(11,log2(PCIE_CORE_DATA_WIDTH/8));
				when 4095 => 	rx_be	<=  conv_std_logic_vector(12,log2(PCIE_CORE_DATA_WIDTH/8));

				when 8191  => rx_be	<=  conv_std_logic_vector(13,log2(PCIE_CORE_DATA_WIDTH/8));
				when 16383 => rx_be	<=  conv_std_logic_vector(14,log2(PCIE_CORE_DATA_WIDTH/8));
				when 32767 => rx_be	<=  conv_std_logic_vector(15,log2(PCIE_CORE_DATA_WIDTH/8));
				when 65535 => rx_be	<=  conv_std_logic_vector(16,log2(PCIE_CORE_DATA_WIDTH/8));
	
				when others => rx_be <= (others => '0');			
								
			end case;
			
			        
			user_data_rx_fifo_Wd	<= rx_be & last_cycle_in_transfer & first_rec & rx_data;  
			
  		end if;                                             
	end if;                                                 
  end process;
end generate;
  
  
  last_cycle_in_transfer <=  rx_done and context_in3(context_in3'high); --sg_last_record;                                           
                           

  bmi_rx_data_valid	<= user_data_rx_fifo_Dav;
  bmi_rx_first		<= user_data_rx_fifo_Rd(PCIE_CORE_DATA_WIDTH) and user_data_rx_fifo_Dav;
  bmi_rx_last		<= user_data_rx_fifo_Rd(PCIE_CORE_DATA_WIDTH+1) and user_data_rx_fifo_Dav;
  bmi_rx_data		<= user_data_rx_fifo_Rd(bmi_rx_data_o'high downto 0) when user_data_rx_fifo_Dav = '1' else (others => '0');
  bmi_rx_be			<= user_data_rx_fifo_Rd(user_data_rx_fifo_Rd'high downto PCIE_CORE_DATA_WIDTH+2);
      
  user_data_rx_fifo_RE	<= bmi_rx_rdy_i and not user_data_rx_fifo_Empty;
  
  
  user_data_rx_fifo : FIFO_core_wc 
  generic map
  (
       Data_Width => PCIE_CORE_DATA_WIDTH+2+log2(PCIE_CORE_DATA_WIDTH/8),
       Log2_of_Depth => USER_FIFO_DEPTH_LOG2+1  -- We added 1 to the fifo depth because all our calcualations are based on the
       											-- assumption that the fifo depth is an integral of read_packet_size
       											-- since FIFO_core_wc REAL size is  2 pow(USER_FIFO_DEPTH_LOG2-1) we add 1 to make suer
       											-- that the fifo is big enough  
 
  )
  port map
  (
	C		=> clk, 
	R       =>bm_active,
       --Write side
 	wc		=> user_data_rx_fifo_wc(USER_FIFO_DEPTH_LOG2 downto 0),
	Wd      => user_data_rx_fifo_Wd,
    WE      => user_data_rx_fifo_WE,
    Full    => user_data_rx_fifo_Full,
       --read side
    Rd      => user_data_rx_fifo_Rd,
    RE      => user_data_rx_fifo_RE,
    Dav     => user_data_rx_fifo_Dav,
    Empty   => user_data_rx_fifo_Empty 
   );    
   
   user_data_rx_fifo_wc(user_data_rx_fifo_wc'high downto  1+USER_FIFO_DEPTH_LOG2) <= (others => '0');
  
 
  	
  	stall_sig <= '1' when (bmi_tx_data_valid = '1' and tx_accum_for_burst =  max_payload_size-PCIE_CORE_DATA_WIDTH/8) or  bmi_tx_last_sig = '1' else '0';   
  	tx_data_rdy <=  tx_active and not (stall_tx or stall_end_of_buffer) when  burst_active = '1' and cli_count > 0  else '0';
  	stall_tx 	<=  or_sum(stall_tx_sfr) or stall_latch;
  	
  	process(clk)
   	begin
 		if rising_edge(clk) then
 			if(reset_n_i = '0' or flush_sig = '1')then
 				stall_latch 	<= '0';
 				stall_tx_sfr <=	(others => '0');
 			else
 			
 				if  stall_sig = '1' then 
 				 	stall_latch <=	'1';
 				elsif stall_tx_sfr = 0 and not (tx_bufffer_space_i < max_payload_size_i(max_payload_size_i'high downto 3)) then
 					stall_latch <=	'0';
 				end if;
 				
 				stall_tx_sfr(0) <=	stall_sig;
 				for i in 1 to stall_tx_sfr'high loop  
 					stall_tx_sfr(i) <= stall_tx_sfr(i-1);
 				end loop;		
 				 				
 			end if;
 		end if;
 	end process;
 
   
  
	 	
  process(clk)
  begin
	if rising_edge(clk) then
		
		if(reset_n_i = '0' or flush_sig = '1')then
			
		
			bm_req <= '0';
			bm_rdy_d <= '0';

			data_burst_arbit <= '0'; 
			
			 
			buffer_rdy_o <= '0'; 
			
			sm_next_state <= SG_STATE_IDLE; 
			sm_state <= SG_STATE_IDLE; --SG_STATE_WAIT_FOR_REC; --SG_STATE_IDLE; -- SG_WAIT_FOR_DESC;
			prev_state <= SG_STATE_IDLE;
			dbg_out_state <= "000000";
			curr_state_cnt <= (others => '0');
			
			flush_out_buffers <= '0';
			expected_rec_add <= (others => '0');
			
			tx_sys_addr <= (others => '0');
			tx_burst_size <= (others => '0');
			
			user_context_s		<= (others => '0');
			tx_sys_addr_s 		<= (others => '0');
			tx_burst_size_s		<= (others => '0');
			tx_dir_s 			<= '0';
			
			tx_dir <= '0';
			tx_last <= '0';
			rx_last <= '0';
			
			curr_transfer_done <= '0';
			curr_transfer_size <= (others => '0');
						
			
			dbg_out <= '0';
			--dbg_out1 <= '0';
			
			tx_data_valid_int 	<= '0';
			tx_data <= (others => '0');	
	
			rx_data_rdy 	<= '0';
			
			curr_raq_add <= (others => '0');	
	
			cli_count <= 0;	
			tx_accum_for_burst <= 0;
			--pre_data_arbit_wait_cnt <= 0;
			
			
			stop_req <= '0';
			bm_active <= '0';
			
			err_in_record <= '0';
			
			--sg_descriptor 	<= (others => '0');
			sg_rec	  		<= (others => '0');
			
			prev_desc_req <= (others => '0');
			
			data_fifo_rd_ena <= '0';

			ss_sel <= (others => '0');
			
			debug_out_register <= (others => '0');
			dbg_cnt <= 0;
			
			pending_mrd_requests <= 0;
			record_reading_active <= '0';
			
	
			dbg_signal	<= '0';
			
					
			stall_end_of_buffer <= '0';
			tx_last_letch	<= '0';
			transfer_count <= (others => '0');
			curr_tx_burst_len <= (others => '0');
			tx_burst_rdy <= '0';			
			stop_sig <= '0';
			user_context <= (others => '0');
			last_read_req <= '0';
			rx_data_arbit_req <= '0';
			desc_valid <= '0';
	
			transfer_count_fixed <= (others => '0');
			
			transfer_index 	<= (others => '0');	
			
			status_req_int		<= '0';
			status_qword_int	<= (others => '0');	
			status_addr_int	 	<= (others => '0');	
			do_stat_int 		<= '0';
			next_user_data_rx_fifo_Wd <= (others => '0'); 
		else
		
			
			dbg_signal	<= '0';
			
			stall_end_of_buffer <= '0';
			status_qword_int	<= (others => '0');
			status_addr_int	 	<= (others => '0');	
			
			
			if(bm_stop = '1')then
				stop_req <= '1';
			end if;
		
			bm_rdy_d 					<= bm_rdy;
			
			tx_data_valid_int 		<= '0';
			tx_data 					<= (others => '0');
			rx_last 					<= '0';
			tx_last					<= '0';
			
			
			
			
			
			stop_sig 	<= '0';
			
			


			
			if bmi_tx_last_i = '1' then
				tx_last_letch <= '1';
			end if;		
			
			if bmi_tx_last_sig = '1' then
				cli_count <= 0;
			elsif(bmi_tx_data_valid = '1' and  cli_count > (PCIE_CORE_DATA_WIDTH/8))then 
				cli_count <= cli_count-(PCIE_CORE_DATA_WIDTH/8);
			elsif(bmi_tx_data_valid = '1' )then
				cli_count <= 0;
			end if;

			if tx_last = '0' and tx_active_i = '1' and bmi_tx_data_valid = '1' and bmi_tx_last_sig = '1' then
				tx_last <= '1';
			elsif(tx_last = '0' and bmi_tx_data_valid = '1' and  not(cli_count > (PCIE_CORE_DATA_WIDTH/8)))then 
				tx_last <= '1';
			end if;						

			if(bmi_tx_data_valid = '1' and cli_count < PCIE_CORE_DATA_WIDTH/8) and cli_count > 0 then
				transfer_count <= transfer_count + cli_count;
			elsif bmi_tx_data_valid = '1' then
				transfer_count <= transfer_count +  (PCIE_CORE_DATA_WIDTH/8);
			end if;
			
			if sg_dir = '0' and bm_transfer_size_valid = '1' then
				transfer_count_fixed <= bm_transfer_size;
			elsif bmi_tx_last_sig_d1 = '1' then
				transfer_count_fixed <= transfer_count-bmi_tx_empty_i;
			elsif bmi_tx_data_valid = '1' then 
				transfer_count_fixed <= transfer_count;
			else
				transfer_count_fixed <= transfer_count_fixed;				
			end if;	
			
						
			tx_burst_rdy <= '0';
			if bmi_tx_data_valid = '1' and (tx_accum_for_burst =  max_payload_size-(PCIE_CORE_DATA_WIDTH/8) or  bmi_tx_last_sig = '1') then
				curr_tx_burst_len <=  conv_std_logic_vector(tx_accum_for_burst+(PCIE_CORE_DATA_WIDTH/8),curr_tx_burst_len'high+1);
				tx_burst_rdy <= '1';
			elsif bmi_tx_last_sig = '1' and tx_accum_for_burst > 0 then
				curr_tx_burst_len <=  conv_std_logic_vector(tx_accum_for_burst,curr_tx_burst_len'high+1);
				tx_burst_rdy <= '1';	
			end if;	

			
			if burst_active = '1' then -- and cli_count > 0 then
				tx_data_valid_int <= bmi_tx_data_valid; -- data valid form the client
				tx_data <= bmi_tx_data_i; -- client data
			end if;

						
			if bmi_tx_data_valid = '1' and ((tx_accum_for_burst+(PCIE_CORE_DATA_WIDTH/8) =  max_payload_size) or  bmi_tx_last_sig = '1') then
				tx_accum_for_burst <= 0;
			elsif bmi_tx_last_sig = '1' then
				tx_accum_for_burst <= 0;
			elsif bmi_tx_data_valid = '1' and cli_count < (PCIE_CORE_DATA_WIDTH/8) and cli_count > 0 then 
				tx_accum_for_burst <= tx_accum_for_burst +  cli_count;
			elsif bmi_tx_data_valid = '1' then --and cli_count > 0 then
				tx_accum_for_burst <= tx_accum_for_burst +  (PCIE_CORE_DATA_WIDTH/8);
			end if;
	
									
			if sg_dir = '0' and rx_data_rdy = '1' and cli_count > (PCIE_CORE_DATA_WIDTH/8) then
				cli_count <= cli_count-(PCIE_CORE_DATA_WIDTH/8);
			elsif sg_dir = '0' and rx_data_rdy = '1' then --rx_data_rdy_mult = '1' then 
				cli_count <= 0;
			end if;	

			--if sg_dir = '0' and context_in1(15 downto 8) = GET_DATA_REQ and  rx_data_rdy = '1' then
			--	transfer_count <= transfer_count +  (PCIE_CORE_DATA_WIDTH/8);
			--end if;
				
			
			if sg_dir = '0' and context_in3(context_in3'high) = '1' and rx_data_rdy = '1' and cli_count = (PCIE_CORE_DATA_WIDTH/8) then
				rx_last <= '1';
			end if;			

			if bm_inturnal_req_active = '0' then
				rx_data_rdy <= rx_active;			
			else
				rx_data_rdy <= '0';
			end if;
			
			flush_out_buffers <= '0';
						
			--dbg_out <= '0';
			state_tics_cnt <= 0;
			
			bm_req <= '0';
			
			data_fifo_rd_ena <= '0';
			bm_active <= '1';
			desc_valid <= '0';
			rx_data_arbit_req <= '0';
			do_stat_int <= '0';						
			
			-- ido check if works with altera 
			--if bm_inturnal_req_active = '0' and rx_done = '1' and pending_mrd_requests > 0 and bm_req = '0' 
			if context_in0(15 downto 8) = GET_DATA_REQ and rx_done = '1' and pending_mrd_requests > 0 and rec_fifo_dav = '0' then
				pending_mrd_requests <= pending_mrd_requests-1;
			--elsif bm_inturnal_req_active = '0' and sg_dir = '0' and rx_done = '0'  and bm_req = '1' then
			elsif rec_fifo_dav = '1'  and sg_dir = '0' then
				pending_mrd_requests <= pending_mrd_requests+1;
			end if;
			
			
			--rec_to_fifo_d <= rec_to_fifo;
			--rec_fifo_write_d <= rec_fifo_write;
  			--if rec_fifo_write_d = '1' and rec_to_fifo_d(31 downto 16) /= x"abcd" then
			--	err_in_record <= '1';
			--	dbg_out <= '1';
			--end if;
			
--- for debug only -----------------------------------

		dbg_out <= '0';
		
		--if user_data_rx_fifo_WE	= '1' and next_user_data_rx_fifo_Wd /= user_data_rx_fifo_Wd(31 downto 0) then
		--	dbg_out <= '1';
		--end if;			
	    --
		--if bmi_tx_data_valid_i = '1'  and next_user_data_rx_fifo_Wd /= bmi_tx_data_i(31 downto 0) then
		--	dbg_out <= '1';
		--end if;
		--	
		--if bmi_tx_data_valid_i = '1' then
		--	next_user_data_rx_fifo_Wd <= bmi_tx_data_i(31 downto 0)+(PCIE_CORE_DATA_WIDTH/32);
		--end if;	
		--
		--
		--if user_data_rx_fifo_WE	= '1' then
		--	next_user_data_rx_fifo_Wd <= user_data_rx_fifo_Wd(31 downto 0)+(PCIE_CORE_DATA_WIDTH/32);
		--end if;	
		--
		--
		--
		--if bmi_rx_last = '1' or bmi_tx_last_i = '1' then
		--	next_user_data_rx_fifo_Wd <= (others => '0');
		--end if; 
		
		
	

			
			prev_state <= sm_state;
			--if sm_state /= SG_STATE_IDLE and sm_state /= SG_DATA_ARBIT_REQ and sm_state = prev_state then
			if sm_state /= SG_STATE_IDLE and sm_state = prev_state then
				curr_state_cnt <= curr_state_cnt+1;
				if curr_state_cnt > conv_std_logic_vector(6000,32) then
					dbg_out_state <= dbg0_reg;
					dbg_out <= '1';
				end if;
			elsif sm_state /= SG_STATE_IDLE then
				curr_state_cnt <= (others => '0');	 	
			end if;
		
			
			
			--if rec_fifo_write = '1' and rec_to_fifo(31 downto 0) /= expected_rec_add then
			--	dbg_out <= '1';
			--elsif rec_fifo_write = '1' then
			--	expected_rec_add <= expected_rec_add+1; 		
			--end if;
-----------------------------------------------------
			
			case sm_state is
				when SG_STATE_IDLE =>
					bm_active <= '0';
					stop_req <= '0';
					flush_out_buffers <= '1';
					curr_transfer_done <= '0';
					record_reading_active <= '0'; 
					
					if bm_start = '1' then
						sm_state <= SG_STATE_WAIT_FOR_REC;
					end if;
				when SG_WAIT_FOR_GNT =>
		
												
					bm_active 			<= bm_active;
									
-- 					dbg_out <= '0';
-- 					if dbg_out = '0' then
-- 						state_tics_cnt <= state_tics_cnt+1;
-- 					end if;
-- 					if state_tics_cnt > 3000 then
-- 							dbg_out <= '1';
-- 					end if;						
				
					if data_arbit_rdy = '1' then
						data_burst_arbit <= '0';
						sm_state <= sm_next_state;
						bm_req <= '1';
						
						tx_sys_addr <= tx_sys_addr_s;
						tx_burst_size <= tx_burst_size_s;
						tx_dir <= tx_dir_s;				
						user_context <= user_context_s;
						
					end if;
				when SG_WAIT_FOR_GRNAT_SIG =>	
					if bm_rdy_re = '1' then
						sm_state <= SG_PREPARE_NEXT_RECORD_SEGMENT;
						tx_sys_addr <= tx_sys_addr + tx_burst_size_s; --MAX_USER_RX_REQUEST_SIZE; --max_payload_size;
					end if;	
				when SG_STATE_WAIT_FOR_REC =>	

					sm_state <= SG_READ_NEX_RECORD;
					
				when SG_WAIT_FOR_CLI_ZERO =>
												
					--if cli_count = 0  and recores_left = 0 and bm_tx_data_front_buff_empty = '1' then	
					if cli_count = 0  and sg_last_record = '1' and bm_tx_data_front_buff_empty = '1' then	
						curr_transfer_done <= '0';
						buffer_rdy_o <= '0';
						sm_state <= SG_STATE_STATUS_0;
						do_stat_int <= '1';
					elsif stop_req = '1' then
						sm_state <= SG_STATE_STOP;						
					elsif cli_count = 0 and sg_last_record = '0' then
						sm_state <= SG_READ_NEX_RECORD;
					end if;
				when SG_READ_NEX_RECORD =>	
					
					data_fifo_rd_ena <= '1';
					if  rec_fifo_dav = '1' then
						sg_rec <= rec_fifo_read_data;
					end if;
					
					if  rec_fifo_dav = '1' and sg_dir = '0'	then
						sm_state <= SG_WAIT_FOR_RX_RDY;
					elsif rec_fifo_dav = '1' then
						sm_state <= SG_DATA_TRANSFER_RDY;
					end if;	

					if  rec_fifo_dav = '1' then
						curr_transfer_size <= rec_fifo_read_data(95 downto 64); 
						cli_count <= conv_integer(rec_fifo_read_data(95 downto 64)) - tx_accum_for_burst;
						tx_sys_addr <= rec_fifo_read_data(63 downto 2) & "00";
					end if;
					
					
					
 				when SG_WAIT_FOR_FRONT_BUFF_EMPTY =>
 						
 					if bm_tx_data_front_buff_empty = '1' then	
 						curr_transfer_done <= '0';
 						sm_state <= SG_STATE_STOP;
 					end if;
					
				when SG_WAIT_FOR_RX_RDY =>

						
					state_tics_cnt <= 0;	
					
					if curr_transfer_size > MAX_USER_RX_REQUEST_SIZE then --max_read_request_size then
						curr_tx_burst_len <= conv_std_logic_vector(MAX_USER_RX_REQUEST_SIZE,curr_tx_burst_len'high+1); --max_read_request_size; 
					else
						curr_tx_burst_len <= curr_transfer_size(curr_tx_burst_len'high downto 0);
					end if;
					
					if sg_last_record = '1' and not(curr_transfer_size > MAX_USER_RX_REQUEST_SIZE) then --max_read_request_size) then
						last_read_req <= '1';
					end if;

					sm_state <= SG_WAIT_ON_RX_USER_BUFFER;

										
				when SG_WAIT_ON_RX_USER_BUFFER =>					

					if stop_req = '1' then
						sm_state <= SG_STATE_STOP;
					elsif stop_req = '0' and OR_SUM(curr_tx_burst_len(LOG2((PCIE_CORE_DATA_WIDTH/8))-1 downto 0)) = '1' and not((curr_tx_burst_len(curr_tx_burst_len'high downto LOG2((PCIE_CORE_DATA_WIDTH/8))) + 1) > unallocated_user_fifo_spacce)	then
						rx_data_arbit_req <= '1';
						state_tics_cnt <= 0;
						sm_state <= SG_DATA_ARBIT_REQ;
					elsif stop_req = '0' and  not(curr_tx_burst_len(curr_tx_burst_len'high downto LOG2((PCIE_CORE_DATA_WIDTH/8))) > unallocated_user_fifo_spacce) 	then
						rx_data_arbit_req <= '1';
						state_tics_cnt <= 0;
						sm_state <= SG_DATA_ARBIT_REQ;
					end if;

				when SG_DATA_TRANSFER_RDY =>
					
					--dbg_out <= dbg_out; 	
					 
						 state_tics_cnt <= 0;
						 sm_state <= SG_DATA_ARBIT_REQ;
					
					
				when SG_DATA_ARBIT_REQ =>
									
					sm_state <= SG_DATA_ARBIT_REQ;
					
					if sg_dir = '0' then 
						tx_dir_s <= sg_dir;
						tx_sys_addr_s <= tx_sys_addr;
						user_context_s <= last_read_req & "00" & "0000000000000" &  GET_DATA_REQ & conv_std_logic_vector(CHAN_NUM,8);
						last_read_req <= '0';						
						state_tics_cnt <= 0;
						
						data_burst_arbit <= '1';
						sm_state <= SG_WAIT_FOR_GNT;
						tx_burst_size_s <=  curr_tx_burst_len;
						sm_next_state <= SG_WAIT_FOR_DATA_TRANSFER;
						curr_transfer_done <= '0';
						
						
						if curr_transfer_size > MAX_USER_RX_REQUEST_SIZE then --max_read_request_size then
							curr_transfer_size <= curr_transfer_size - MAX_USER_RX_REQUEST_SIZE; --max_read_request_size; -
						 else
							curr_transfer_done <= '1';
							curr_transfer_size <= (others => '0');
						end if;

                     elsif sg_dir = '1' then
                     		
 						tx_dir_s <= sg_dir;
 						tx_sys_addr_s <= tx_sys_addr;
 						
 						tx_burst_size_s <=  curr_tx_burst_len;

						if bmi_tx_last_sig = '1' then
							curr_transfer_done <= '1';
						end if;
						
						if cli_count = PCIE_CORE_DATA_WIDTH/4 and bmi_tx_data_valid_i = '1' and sg_last_record = '1' then
							stall_end_of_buffer <= '1';
						end if;
						
 						if stop_req = '1' then
							sm_state <= SG_STATE_STOP;					 						
						elsif tx_burst_rdy = '0' and bmi_tx_last_sig_d = '1' and tx_accum_for_burst = 0 then -- last with no data, tx_accum_for_burst = 0
 							curr_transfer_done <= '1';
 							curr_transfer_size <= (others => '0');
 							sm_state <= SG_STATE_WAIT_CLI_PRE_STATUS;
						elsif tx_burst_rdy = '0' and bmi_tx_last_sig_d = '1' then -- last with no data, tx_accum_for_burst != 0
 							curr_transfer_done <= '1';
 							curr_transfer_size <= (others => '0');
 							sm_next_state <= SG_WAIT_FOR_DATA_TRANSFER;
 							data_burst_arbit <= '1';
 							sm_state <= SG_WAIT_FOR_GNT;
	 					elsif tx_burst_rdy = '1' and stop_req = '1' then			
 							curr_transfer_done <= '1';
 							curr_transfer_size <= (others => '0');
 							state_tics_cnt <= 0;
 							sm_next_state <= SG_WAIT_FOR_FRONT_BUFF_EMPTY;
 							data_burst_arbit <= '1';
 							sm_state <= SG_WAIT_FOR_GNT;
 							tx_sys_addr_s <= tx_sys_addr or x"0000000000000001";
 						elsif tx_burst_rdy = '1' and bmi_tx_last_sig_d = '1' then -- last with data
 							curr_transfer_done <= '1';
 							curr_transfer_size <= (others => '0');
 							state_tics_cnt <= 0;
 							sm_next_state <= SG_WAIT_FOR_DATA_TRANSFER;
 							data_burst_arbit <= '1';
 							sm_state <= SG_WAIT_FOR_GNT;
 						elsif tx_burst_rdy = '1' and bmi_tx_last_sig = '1' then -- in case the user sets bmi_tx_last 1 cyle after valid is set to 0 
 							curr_transfer_done <= '1';
 							curr_transfer_size <= (others => '0');
 							sm_next_state <= SG_WAIT_FOR_DATA_TRANSFER;
 							data_burst_arbit <= '1';
 							sm_state <= SG_WAIT_FOR_GNT;
 						elsif(tx_burst_rdy = '1' and curr_transfer_size > max_payload_size)then -- got tx_burst_rdy because accum for burts is max_payload_size
 							--tx_burst_size_s <= max_payload_size;
 							curr_transfer_done <= '0';
 							curr_transfer_size <= curr_transfer_size - max_payload_size; --Ido
 							state_tics_cnt <= 0;
 							sm_next_state <= SG_WAIT_FOR_DATA_TRANSFER;
 							data_burst_arbit <= '1';
 							sm_state <= SG_WAIT_FOR_GNT;
 						elsif tx_burst_rdy = '1' or cli_count = 0 then
 							curr_transfer_done <= '1';
 							curr_transfer_size <= (others => '0');
 							state_tics_cnt <= 0;
 							sm_next_state <= SG_WAIT_FOR_DATA_TRANSFER;
 							data_burst_arbit <= '1';
 							sm_state <= SG_WAIT_FOR_GNT;
 						end if;
 					end if;
				
				when SG_WAIT_FOR_DATA_TRANSFER =>	
				
				
					--if state_tics_cnt > 3000 then
					--		dbg_out <= '1';
					--end if;				

				
					if(sg_dir = '1')then
						sm_state <= SG_DATA_TRANSFER;
					else
						
						--------- New Implementation ----------------------------------------
						--if curr_transfer_size > 0 then
						--	sm_state <= SG_OUT_ADDR_INC;
						--else
						--	sm_state <= SG_READ_NEX_RECORD;
						--end if; 
												
						if curr_transfer_size > 0 then
							sm_state <= SG_OUT_ADDR_INC;
						--elsif recores_left > 0 then
						elsif pending_mrd_requests < NUM_NUM_OF_USER_RX_PENDINNG_REQUEST and sg_last_record = '0' then 
							sm_state <= SG_READ_NEX_RECORD;
						else --if curr_transfer_done = '0' then
							sm_state <= SG_WAIT_FOR_DATA_IN_DONE;
						end if;	
						--------------------------------------------------------------------------
						
						
						dbg_cnt <= 0;
					end if;	
				when SG_OUT_ADDR_INC =>
						
						if bm_rdy_re = '1' then
							state_tics_cnt <= 0;
							sm_state <= SG_WAIT_FOR_RX_RDY;
							tx_sys_addr <= tx_sys_addr + tx_burst_size;
						end if;
					
								
					
				when SG_WAIT_FOR_DATA_IN_DONE =>	
					
					if(curr_transfer_done = '1' and pending_mrd_requests = 0 and user_data_rx_fifo_Empty = '1')then
						
						curr_transfer_done <= '0';
						--dbg_out <= '0';
						--state_tics_cnt <= 0;
						--sm_state <= SG_STATE_STATUS_ARBIT_REQ;
						sm_state <= SG_WAIT_FOR_CLI_ZERO;
					elsif(curr_transfer_done = '0' and rx_done = '1')then
						-- end of burst
						state_tics_cnt <= 0;
						tx_sys_addr <= tx_sys_addr + tx_burst_size;
						sm_state <= SG_DATA_ARBIT_REQ;	
					end if;

				when SG_DATA_TRANSFER =>
															
					--if(curr_transfer_done = '1'  and recores_left > 0)then
					if curr_transfer_done = '1'  and sg_last_record = '0' then
						--dbg_out <= '0';
						--state_tics_cnt <= 0;
						sm_state <= SG_WAIT_FOR_CLI_ZERO;
					elsif curr_transfer_done = '1'  then
						-- end of transfer
					--	sm_state <= SG_STATE_STATUS_0;  xxxx
						sm_state <= SG_STATE_WAIT_CLI_PRE_STATUS;
					elsif(curr_transfer_done = '0'  )then
						-- end of burst 
						state_tics_cnt <= 0;
						tx_sys_addr <= tx_sys_addr + tx_burst_size;   
						sm_state <= SG_DATA_ARBIT_REQ;
					end if;
				 when SG_STATE_WAIT_CLI_PRE_STATUS =>
				 		
				 		if cli_count = 0 then --and bm_tx_data_front_buff_empty = '1' then
				 			buffer_rdy_o <= '0';
				 			curr_transfer_done <= '0';
				 			do_stat_int <= '1';
							sm_state <= SG_STATE_STATUS_0; --SG_WAIT_FOR_FRONT_BUFF_EMPTY; 
				 		end if;
				 		
				 		
				 		
				 		
				 when SG_STATE_STATUS_0 =>
				 
				 		do_stat_int <= '1';
				 		if status_interrupt_done = '1' then
							transfer_count <= (others => '0');				 		
							
							--if tx_active = '1' and sg_cyclic = '1' then
							--	sm_state <= SG_READ_NEX_RECORD;						
							--elsif sg_last_desc = '1' then
							--	sm_state <= SG_STATE_IDLE;
							--
							--	-- wait for the grant rising edge that will occur after the transmission of the MSIx Write is lunched
							--elsif tx_active = '1' then --and bm_rdy_re = '1' then  
							--	sm_state <= SG_STATE_WAIT_FOR_REC;
							--end if;

							if sg_last_desc = '1' then
								sm_state <= SG_STATE_IDLE;
							else
								sm_state <= SG_STATE_WAIT_FOR_REC;
							end if;
							
											 		
				 		end if;
																
				when others => 
					sm_state <= SG_STATE_IDLE;
			end case;
		end if;
	end if;
  end process;
  
 
  
 process(clk) 
 begin
 	if rising_edge(clk) then
		user_last_write_sig <= context_in1(31) and not context_in0(31);
	end if;  
 end process;
  
  
  --user_last_write_sig <= context_in2(31) and not context_in1(31);  
  
  
 input_signals_sampling : process(clk) 
 begin
    if rising_edge(clk) then
		if (reset_n_i = '0') then
			max_payload_size	<= (others => '0');			
			sys_ena 			<=	 '0'; 								
				
			rx_done				<=  '0';	
			rx_done_d			<=  '0';	
			rx_done_d1			<=  '0'; 	
			rx_data				<= (others => '0');
			

			tx_active			<= '0';
			rx_active			<= '0';	
			bm_ena_clr			<= '0';
			bm_start				<= '0';
			bm_stop				<= '0';
			bm_rx_last_in_burst <= '0';
			
			bmi_tx_last			<= '0';
			context_in0			<= (others => '0');		
			context_in1			<= (others => '0');
			context_in2			<= (others => '0');
			context_in3			<= (others => '0');
	
			
		else
		
		
			context_in0 <= bm_context_i;
			context_in1 <= context_in0;
			context_in2 <= context_in1;
			context_in3 <= context_in2;
			
		
			max_payload_size	<=  max_payload_size_i;
			max_read_request_size <= max_read_request_size_i;			
			sys_ena 				<=	 sys_ena_i; 								
			
			bm_packet_ack		<= bm_packet_ack_i;	
				
			rx_data				<=  rx_data_i;
			rx_data_d			<=  rx_data;
			user_write_d		<= user_write;
			rx_done				<=  rx_done_i;	
			rx_done_d 			<=  rx_done;
			rx_done_d1			<=	 rx_done_d; 
			rx_active			<=  rx_active_i;
			bm_rx_last_in_burst <= bm_rx_last_in_burst_i;
			
			
			tx_active			<= tx_active_i;
			bm_req_address		<= bm_req_address_i;
			bm_ena_clr			<= bm_ena_clr_i;
			bm_start			<= bm_start_i;
			bm_stop				<= bm_stop_i;
			bmi_tx_last			<= bmi_tx_last_i;
			bm_tx_data_front_buff_empty <=	bm_tx_data_front_buff_empty_i;
			
			
			dbg_cycle_counter <= dbg_cycle_counter+1;
			
			 
			
		end if;
	end if;
 end process;
 
 
 bmi_tx_data_valid	<= bmi_tx_data_valid_i; -- and tx_data_rdy when  sm_state /= SG_STATE_IDLE and sm_state /= SG_STATE_STOP else '0';

 bm_rdy			   <=  bm_rdy_i;
 
 transfer_done_proc : process(clk)
 begin
	if rising_edge(clk)then
		if(reset_n_i = '0')then
			curr_transfer_done_d <= '0'; 
			bmi_tx_last_d <= '0';
		else
			curr_transfer_done_d <= curr_transfer_done;
			bmi_tx_last_d <= bmi_tx_last_sig;
		end if;
	end if;
 end process;	
 
 process(clk)
 begin
 	if rising_edge(clk)then
 		bm_tx_data_front_buff_empty_d <= bm_tx_data_front_buff_empty;
 		transfer_done_aligned_d <= transfer_done_aligned;
 		transfer_done_aligned_d1 <= transfer_done_aligned_d;
 		bmi_tx_last_sig_d <= bmi_tx_last_sig;
 		bmi_tx_last_sig_d1 <= bmi_tx_last_sig_d;
 		rec_fifo_dav_d 		<= rec_fifo_dav;
 		
 		rx_data_rdy_d <= rx_data_rdy;
 	end if;
 end process;

 
 
	data_aligned        		<= rx_data_i;
	data_rdy_aligned    		<= rx_active_i;
	be_aligned          		<= rx_be_i;
	transfer_done_aligned		<= rx_done_i;


  bmi_tx_last_sig <= bmi_tx_last_i and not bmi_tx_last;
  process(clk)
  begin
	if rising_edge(clk) then
		if sg_cyclic = '1' then
			record_fifo_reset_n <= reset_n_i and not flush_sig;
		else
			record_fifo_reset_n <= reset_n_i and not ( flush_sig or bmi_tx_last_sig);
		end if;
	end if;
 end process;
 
 

status_interrupt_gen_i :  status_interrupt_gen 
generic map
(
	PCIE_CORE_DATA_WIDTH 	=> PCIE_CORE_DATA_WIDTH,
	CHAN_NUM				=> CHAN_NUM,
	SWAP_ENDIAN				=> SWAP_ENDIAN 
)
port map
(


	clk_in   => clk,
    rstn     => reset_n_i,
    
    start_req	=> bm_start_i,
    stop_req	=> stop_req,
    first_desc_addr	  => bm_req_address_i,
    
    
    tx_req 	 => stat_int_tx_req,  
    tx_grnt  => stat_int_tx_grnt,
    
    desc_rdy_sig => desc_rdy_sig,
        
    msix_enabled			=> msix_enabled_i,
    msix_vector_control		=> msix_vector_control_i,
	msix_msg_data			=> msix_msg_data_i,
	msix_msg_addr			=> 	msix_msg_addr,
    
    do_interrupt 			=> do_interrupt,
    
    record_req				=> data_fifo_rd_ena,  
    record_valid			=> rec_fifo_dav,      
    record_out				=> rec_fifo_read_data,
 
    bm_transfer_size_o        => bm_transfer_size,       
    bm_transfer_size_valid_o  => bm_transfer_size_valid,
    
           
    gen_status_req			=> do_stat_int,
    status_interrupt_done	=> status_interrupt_done,
    transfer_count			=> transfer_count_fixed, --transfer_count,
    
    status_ack				=> status_ack,
	status_addr_out			=> stat_int_status_addr,  
	status_req_out			=> stat_int_status_req,   
	status_qword_out 		=> stat_int_status_qword, 
		
	tx_ready                => tx_active,
	tx_data                 => stat_int_tx_data,      
	tx_data_valid			=> stat_int_tx_data_valid,
	tx_last					=> stat_int_tx_last,		    
	tx_sys_addr             => stat_int_tx_sys_addr,  
	tx_burst_size           => stat_int_tx_burst_size,
	tx_dir                  => stat_int_tx_dir, 
	tx_context				=> stat_int_context,
	

	req_active				=> bm_inturnal_req_active,	
  	
	context_in				=> bm_context_i,
	rx_data   				=> rx_data_i, 	  			
	rx_done					=> rx_done_i,				
	rx_active				=> rx_active_i,				
	bm_rx_last_in_burst 	=> bm_rx_last_in_burst_i,
	rx_be_i					=> rx_be_i					
	

  		      

    		
  
	);

    msix_msg_addr <= msix_msg_uppr_addr_i & msix_msg_addr_i;

	 

	flush_sig <= stop_sig or bm_wait_for_int_ack_i;
	
	
	 process(clk)
	 begin
		if rising_edge(clk) then
			if(reset_n_i = '0')then
				flush_out <= '0';
			else
				flush_out <= '0';
				
				if flush_sig = '1' or flush_out_buffers = '1' or desc_rdy_sig = '1' then
					flush_out <= '1';
				end if;
			end if;			
		end if;
	 end process;	
 
 	bm_rdy_re <= bm_rdy and not bm_rdy_d;
 	
 	stat_int_tx_grnt_sig <= stat_int_tx_grnt and not stat_int_tx_grnt_d;
 	
	tx_arbiterer_proc : process(clk)
	 begin
		if rising_edge(clk) then
			if(reset_n_i = '0')then
				data_arbit_rdy <= '0';
				stat_int_tx_grnt <= '0';
				stat_int_tx_grnt_d <= '0';
				arbit_backoff_cnt <= 0;
			else
				data_arbit_rdy <= '0';
				stat_int_tx_grnt <= '0';
				stat_int_tx_grnt_d <= stat_int_tx_grnt; 
				if arbit_backoff_cnt = 0 and stat_int_tx_req = '1'  and bm_rdy = '1' and tx_data_valid_int = '0'  then
					stat_int_tx_grnt <= '1';
					arbit_backoff_cnt <= 4; 	
				elsif arbit_backoff_cnt = 0 and data_burst_arbit = '1' and  stat_int_tx_req = '1' and bm_rdy = '1'  then
					stat_int_tx_grnt <= '1';
					arbit_backoff_cnt <= 4; 				
				elsif arbit_backoff_cnt = 0 and  data_burst_arbit = '1' and bm_rdy = '1'  then
					data_arbit_rdy <= '1';
					arbit_backoff_cnt <= 4;
				end if;
				
				if arbit_backoff_cnt > 0 then
					arbit_backoff_cnt <= arbit_backoff_cnt - 1;
				end if;
			end if;			
		end if;
	 end process;	
 	
 	 	
 	
 
   
--TODO: Make state reflect the real STATE
	state_o <= bm_active;

	sg_dir	<= DIRECTION; --sg_rec(0);
	
	bm_tx_data_fron_buff_flush_o	<= flush_out;																
	bmi_bm_tag_data_o				<= sg_rec(sg_rec'low+31 downto sg_rec'low+16);

	bm_tx_data_front_buff_empty_sig <= bm_tx_data_front_buff_empty and not bm_tx_data_front_buff_empty_d;
	transfer_done_sig 				<= curr_transfer_done_d and not curr_transfer_done;

	rec_rdy 						<= rx_done and bm_rec_req_pending;
	burst_active 					<= not bm_inturnal_req_active;
	
	rx_data_rdy_mult 				<= rx_data_rdy_d and rx_data_rdy;
	rx_data_rdy_fe 					<= rx_data_rdy_d and not rx_data_rdy;

	bm_rx_rdy_o						<= bm_inturnal_req_active or not user_data_rx_fifo_Full; 
		
-- entity port outputs
	int_gen_o						<= do_interrupt;
	

	bmi_rx_data_o 					<= bmi_rx_data;	
	bmi_rx_data_valid_o				<= bmi_rx_data_valid;
	bmi_rx_last_o					<= bmi_rx_last;
	bmi_rx_first_o					<= bmi_rx_first_sig;
	
		
	bmi_tx_data_rdy_o				<= tx_data_rdy;
	bmi_rx_be_o						<= bmi_rx_be;
	bmi_transfer_done_o 			<= transfer_done_sig;
	

	
	 process(clk)
	 begin
		if rising_edge(clk) then
			if reset_n_i = '0' then
				bm_req_o			   			<= 	'0';
				tx_sys_addr_o					<=  (others => '0'); 
				tx_burst_size_o					<=  (others => '0'); 
				tx_dir_o						<=  '0';
				context_o						<=  (others => '0');
				
				tx_last_o						<=  '0'; 
				tx_data_valid_o 				<=  '0';
				tx_data_o  						<=   (others => '0');
				
			else
			
			
				bm_req_o <= '0';
				if  stat_int_tx_grnt_sig = '1' then
					bm_req_o			<= '1';
					tx_sys_addr_o		<= stat_int_tx_sys_addr;
					tx_burst_size_o		<= stat_int_tx_burst_size(tx_burst_size_o'high downto 0);
					tx_dir_o			<= stat_int_tx_dir;
					context_o			<= stat_int_context;  
					
				elsif bm_req = '1' then
					bm_req_o			<= '1';
					tx_sys_addr_o		<= tx_sys_addr;
					tx_burst_size_o		<= tx_burst_size(tx_burst_size_o'high downto 0);
					tx_dir_o			<= tx_dir;
					--context_o			<= user_context;
				end if;
				
				-- PATCH for IN Channels only:  to prevent the context_o to go to x"00000000" when the req/deciptor context was not saved by the tag_allocator and the bm_req is issued.
				-- user context is no used for IN payload, so we ony need to set the context to USER PAYLOAD if we are instantiating an IN channel.
				-- So, we only set contex_o to hold the user_context for IN channles (i.e if DIRECTION equals '1'_)
				if DIRECTION = '0' and bm_req = '1' then
					context_o			<= user_context;
				end if;
				
				tx_last_o						<=  '0'; 
				tx_data_valid_o 				<=  '0';
				tx_data_o  						<=   (others => '0');
				
				if stat_int_tx_data_valid = '1' then
					tx_last_o						<=  stat_int_tx_last;
					tx_data_valid_o 				<= '1';
					tx_data_o  						<=  stat_int_tx_data;
				elsif tx_data_valid_int = '1' then
					tx_last_o						<=   tx_last;
					tx_data_valid_o 				<= '1';
					tx_data_o  						<=  tx_data;
				end if;
			end if;	
				
		end if;
	 end process;	
	
	
	 
	 first_record_sig <= '1' when rec_fifo_read_data(1) = '1'  and (sg_first_record /= '1') else '0';
	 	
	 bmi_rx_first_sig <= bmi_rx_first and not bmi_rx_first_d;
	 
	 process(clk)
	 begin
		if rising_edge(clk) then
			if reset_n_i = '0' then
				first_rec	<= '0';
				sg_first_record	<= '0';
				bmi_rx_first_d <= '0';
			else
				
				bmi_rx_first_d <= bmi_rx_first;
				sg_first_record	<= rec_fifo_read_data(1);
				
				if first_record_sig = '1' then
					first_rec <= '1';
				end if;
				
				if rx_active = '1' and user_data_rx_fifo_WE = '1' then
					first_rec <= '0';
				end if;
				
				 
				
			end if;
		end if;
	 end process;
	 
	 
	 

	 process(clk)
	 begin
		if rising_edge(clk) then
			if reset_n_i = '0' then
				sg_last_record	<= '0';
			else
				if  rec_fifo_dav = '1' then
					sg_last_record	<= rec_fifo_read_data(0); --
				--elsif bmi_tx_last_i = '1' then
				elsif bmi_tx_last_sig = '1' then
					sg_last_record	<= '1';		
				end if;
			end if;
		end if;
	 end process;
	 
	 
	 bmi_rx_pending_o(log2(PCIE_CORE_DATA_WIDTH/8)-1 downto 0) <= (others => '0');
	 bmi_rx_pending_o(log2(PCIE_CORE_DATA_WIDTH/8)+USER_FIFO_DEPTH_LOG2 downto log2(PCIE_CORE_DATA_WIDTH/8)) <=	user_data_rx_fifo_wc(USER_FIFO_DEPTH_LOG2 downto 0);
	 bmi_rx_pending_o(bmi_rx_pending_o'high downto log2(PCIE_CORE_DATA_WIDTH/8)+USER_FIFO_DEPTH_LOG2+1) <= (others => '0');
	 
	sg_transfer_size 				<=  sg_rec(95 downto 64);
	sg_dir							<= DIRECTION; --sg_rec(0);
	sg_buffer_address  				<= sg_rec(63 downto 2) & "00"; 
	 
	 
    stop_req_pending_o			<= stop_req;
    
    status_req 					<= stat_int_status_req; --status_req_int;
    status_qword				<= stat_int_status_qword; --status_qword_int;
    status_addr					<= stat_int_status_addr; --status_addr_int;
    
    bm_transfer_size_o        	<= bm_transfer_size;       
    bm_transfer_size_valid_o  	<= bm_transfer_size_valid;
    
    
    
	dbg_word_o					<= 	  x"00000000"
									& x"00000000"
									& x"00000000"
									& x"00000000"
									& x"00000000"
									& x"00000000"
									& x"00000000"
									& x"0000" & dbg_out & '0' & dbg_out_state & "00" & dbg0_reg;
	
	--(others => '0');
	
	
--	dbg_out0_o <=  dbg_out; --sm_state(2);
--	dbg_out1_o <= dbg_out1;

	chnn_gp_in_0_o	<= curr_state_cnt;
	chnn_gp_in_1_o	<= x"0000000" & "000" & dbg_out;

	
	
	dbg_signal_o	<= dbg_out; --dbg_signal;
	
	dbg0_reg_0 <= dbg0_reg(4 downto 0);	
	
	
	
	
end Behavioral;

