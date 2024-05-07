

-- Todo List:
-- 1) when implementing the record fifo make sure that the SYNC reset to the fifo will include the channle active 


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;





entity  status_interrupt_gen is
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
	
	tx_ready                : in  std_logic;
	tx_data                 : out std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0); 
	tx_data_valid			: out std_logic;	
	tx_last					: out std_logic;
	tx_sys_addr             : out std_logic_vector(63 downto 0);
	tx_burst_size           : out std_logic_vector(13 downto 0);
	tx_dir                  : out std_logic;
	tx_context				: out std_logic_vector(31 downto 0);
	
	desc_rdy_sig			: out std_logic;
	
	req_active				: out std_logic;

	context_in				: in std_logic_vector(31 downto 0);	
  	rx_data    	  			: in  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
	rx_done					: in  std_logic;
	rx_active				: in  std_logic;
	bm_rx_last_in_burst 	: in  std_logic;
	rx_be_i					: in  std_logic_vector((PCIE_CORE_DATA_WIDTH/8)-1 downto 0)	

	
);
end status_interrupt_gen;

architecture arc of status_interrupt_gen is




	function records_per_write_cycle return integer
	is
		variable ret : integer := 1;
	begin
		if PCIE_CORE_DATA_WIDTH = 256 then
			ret := 2;
		end if;	
		return ret;
	end function;
	
function get_fifo_width return integer
	is
		variable ret : integer := records_per_write_cycle*3*32;
	begin
		return ret;
	end function;	


constant SIZE_OF_SG_RECORD_STAUS	: std_logic_vector(13 downto 0) := "00000000001000"; -- 8 bytes 
constant SIZE_OF_SG_DESCRIPTOR 		: std_logic_vector(13 downto 0) := "00000000100000";
constant GET_DESC_REQ				: std_logic_vector(7 downto 0) := x"01";
constant GET_RECORD_REQ				: std_logic_vector(7 downto 0) := x"02";
constant BACKOFF_TIMEOUT 			: integer := 31250;
constant RECORD_SEGMENT_SIZE		: integer := 128;

function endigan_swap(vect : std_logic_vector) return std_logic_vector
is
variable swapped_vector : std_logic_vector(31 downto 0);
begin
	swapped_vector := vect(vect'low+7 downto vect'low+0) & vect(vect'low+15 downto vect'low+8) & vect(vect'low+23 downto vect'low+16) & vect(vect'low+31 downto vect'low+24);
	return swapped_vector;
end function; 


type stat_sm is
(
	SI_STATE_IDLE,
	SI_STATE_DESC_RDY,
	SI_STATE_STOP,
	SI_STATE_BACKOFF,
	SI_STATE_GET_DESCRIPTOR,
	SI_STATE_WAIT_FOR_DESCRIPTOR,								
	SI_STATE_GET_NEXT_RECORDS_BURST,	
	SI_STATE_WAIT_FOR_REQ,
	SI_STATE_WAIT_FOR_STATUS_DONE,
	SI_STATE_MSIX_ARBIT,
	SI_STATE_WAIT_OF_RECORD_GATE,	
	SI_STATE_MSIX_MWr,
	SI_STATE_MSIX_MWr_Done
);

type rec_fifo_rd_sm is
(
    REC_FIFO_RD_WAIT_ON_FIFO,
    REC_FIFO_RD_WAIT_ON_REQ_LOW,
    REC_FIFO_RD_WAIT_ON_REQ_HIGH
);
    





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


signal stat_int_state 			: stat_sm;
signal rec_fifo_rd_st 			: rec_fifo_rd_sm;
signal transfer_index			: std_logic_vector(11 downto 0);
signal status_addr_int			: std_logic_vector(63 downto 0); 
signal status_req_int			: std_logic;
signal status_req_pending 		: std_logic;
signal status_qword_int 		: std_logic_vector(63 downto 0);
signal gen_status_req_d 		: std_logic;

signal msix_interrupt_done   	: std_logic;
signal do_interrupt_int      	: std_logic;

signal sg_descriptor0			: std_logic_vector((8*32)-1 downto 0);
signal sg_desc_wrtie_index		: integer range 0 to 3;

signal desc_valid				: std_logic;

signal sg_generate_interrupt	: std_logic;
signal sg_next_desc_address 	: std_logic_vector(63 downto 0);
signal sg_active				: std_logic;
signal sg_last_desc				: std_logic; 
signal sg_rec_buffer_size		: std_logic_vector(31 downto 0);
signal sg_rec_list_address 		: std_logic_vector(63 downto 0);
signal sg_cyclic				: std_logic;
signal sg_desc_signiture		: std_logic_vector(31 downto 0);
signal sg_status_addr			: std_logic_vector(63 downto 0);
    
signal record_reading_done_sig 	: std_logic; 
signal toggle_rec 				: std_logic;
signal rec_to_fifo 				: std_logic_vector((records_per_write_cycle*4*32)-1 downto 0);
signal rec_fifo_write 			: std_logic;

signal rec_burst_start_sig		: std_logic;
signal rec_read_gate			: std_logic;
signal rec_burst_end_sig		: std_logic;
signal record_reading_active    : std_logic;
signal next_rec_seg_addr		: std_logic_vector(63 downto 0);
signal records_size_left		: std_logic_vector(31 downto 0);

signal rec_fifo_clr_n			: std_logic;
signal rec_fifo_full			: std_logic;	
signal rec_fifo_rd_req  		: std_logic;
signal rec_fifo_empty   		: std_logic;
signal rec_fifo_dav     		: std_logic;
signal rec_fifo_wc				: std_logic_vector(4 downto 0);	
signal rec_fifo_wc_d			: std_logic_vector(4 downto 0);
signal rec_fifo_dav_d			: std_logic;
signal rec_active				: std_logic;

signal tx_sys_addr_int     		: std_logic_vector(63 downto 0);
signal tx_burst_size_int 		: std_logic_vector(13 downto 0);
signal tx_dir_int				: std_logic;
signal tx_context_int 			: std_logic_vector(31 downto 0);
signal record_out_int			: std_logic_vector(95 downto 0);

signal rec_fifo_rd				: std_logic_vector((records_per_write_cycle*3*32)-1 downto 0);
signal rec_high					: std_logic_vector(95 downto 0);

signal half_fifo_sig 			: std_logic;
signal record_req_d				: std_logic;
signal record_req_sig			: std_logic;
signal wait_cnt 				: std_logic_vector(31 downto 0);

signal Wd      : STD_LOGIC_VECTOR(get_fifo_width-1 downto 0);
signal tx_req_int : std_logic;

signal stall_rec_fifo_rd_req : std_logic;

signal dbg_reg : std_logic_vector(3 downto 0);

attribute keep: string;

attribute keep of dbg_reg : signal is "true";
attribute keep of tx_req_int : signal is "true";
--attribute keep of stat_int_state : sighal is "true";

begin

process(clk_in)
	begin
		if rising_edge(clk_in) then
		    case stat_int_state is
                when SI_STATE_IDLE						=> dbg_reg <= "0001";                        		
                when SI_STATE_DESC_RDY					=> dbg_reg <= "0010";                   
                when SI_STATE_STOP						=> dbg_reg <= "0011";                       
                when SI_STATE_BACKOFF					=> dbg_reg <= "0100";                    
                when SI_STATE_GET_DESCRIPTOR			=> dbg_reg <= "0101";             
                when SI_STATE_WAIT_FOR_DESCRIPTOR		=> dbg_reg <= "0110";								
                when SI_STATE_GET_NEXT_RECORDS_BURST	=> dbg_reg <= "0111";	    
                when SI_STATE_WAIT_FOR_REQ				=> dbg_reg <= "1000";               
                when SI_STATE_WAIT_FOR_STATUS_DONE		=> dbg_reg <= "1001";       
                when SI_STATE_MSIX_ARBIT				=> dbg_reg <= "1010";                 
                when SI_STATE_WAIT_OF_RECORD_GATE		=> dbg_reg <= "1011";	       
                when SI_STATE_MSIX_MWr					=> dbg_reg <= "1100";                   
                when SI_STATE_MSIX_MWr_Done          	=> dbg_reg <= "1101";
                when others 							=> dbg_reg <= "0000";    				
                end case;
		end if;
	end process;


		process(clk_in)
	begin
		if rising_edge(clk_in) then
			gen_status_req_d <= gen_status_req;
		end if;
	end process;				
    
	
			

	process(clk_in)
	begin
		if rising_edge(clk_in) then
			if rstn = '0' then
				desc_rdy_sig <= '0';
				stat_int_state 	<= SI_STATE_IDLE; 
				status_addr_int	<= (others =>  '0'); 
				status_req_int	<= '0';
				transfer_index	<= (others =>  '0');
				status_qword_int <= (others =>  '0');
				tx_req_int <= '0';
				do_interrupt_int <= '0';
				req_active	<= '0';
				tx_data	 		<= (others =>  '0');
				tx_sys_addr_int  	<= (others =>  '0');
				tx_burst_size_int  	<= (others =>  '0');
				tx_dir_int 			<= '0';
				tx_data_valid 	<= '0';
				tx_last 		<= '0';
				msix_interrupt_done <= '0';
				tx_context_int		<= (others => '0');
				desc_valid 		<= '0';
				next_rec_seg_addr <= (others => '0');
				records_size_left <= (others => '0');
				status_req_pending <=  '0';
				rec_burst_start_sig <= '0';
				rec_fifo_clr_n <= '0';	 
				wait_cnt <= (others => '0');
			else
				desc_rdy_sig <= '0';
				rec_fifo_clr_n <= '1';
				tx_req_int <= '0';
				do_interrupt_int <= '0';
				desc_valid 		<= '0';
				tx_data	 		<= (others =>  '0');
				tx_data_valid 	<= '0';
				tx_last 		<= '0';
				msix_interrupt_done <= '0';
				req_active <= '0';
				rec_burst_start_sig <= '0';
				wait_cnt <= (others => '0');
                status_req_int		<= '0'; --Ido: try with this to prevent status '1' right atfer reset
				
				if gen_status_req = '1' and gen_status_req_d = '0' then
					status_req_pending <= '1';
				elsif status_req_int = '1' then
					status_req_pending <= '0';
				else
					status_req_pending <= status_req_pending;
				end if;
								
				case stat_int_state is
					when SI_STATE_IDLE =>
						rec_fifo_clr_n <= '0';
						if start_req = '1' then
							stat_int_state <= SI_STATE_GET_DESCRIPTOR;
							tx_sys_addr_int <= first_desc_addr;
							tx_burst_size_int <= SIZE_OF_SG_DESCRIPTOR; -- 1 DW
							tx_dir_int <= '0'; 
							tx_context_int <= x"0000" & GET_DESC_REQ & conv_std_logic_vector(CHAN_NUM,8);
						end if;
					when SI_STATE_GET_DESCRIPTOR =>
						tx_req_int <= '1';
						rec_fifo_clr_n <= '0';
						if tx_grnt = '1' then

							stat_int_state 	<= stat_int_state; 	
							tx_sys_addr_int 	<= tx_sys_addr_int; 	   
							tx_burst_size_int 	<= tx_burst_size_int; 	 
							tx_dir_int 			<= tx_dir_int; 			         
							tx_context_int 		<= tx_context_int; 		   
						
							req_active	<= '1';
						
							stat_int_state <= SI_STATE_WAIT_FOR_DESCRIPTOR;
							wait_cnt <= (others => '0');
						end if;	
					when SI_STATE_WAIT_FOR_DESCRIPTOR =>
						rec_fifo_clr_n <= '0';
						req_active	<= '1';	
						if rx_done = '1' then
							desc_rdy_sig <= '1';
							stat_int_state <= SI_STATE_DESC_RDY;
						end if;
						wait_cnt <= wait_cnt+1;	
					when SI_STATE_DESC_RDY =>
	
						if stop_req = '1' then
							stat_int_state <= SI_STATE_STOP;
						elsif sg_active = '0' then
							
							stat_int_state <= SI_STATE_BACKOFF;
						else
							desc_valid <= '1';
							stat_int_state <= SI_STATE_GET_NEXT_RECORDS_BURST;
							next_rec_seg_addr <= sg_rec_list_address;
							records_size_left <= sg_rec_buffer_size;							
						end if;					
					when SI_STATE_BACKOFF =>
												
						stat_int_state <= SI_STATE_GET_DESCRIPTOR;
						tx_sys_addr_int <= tx_sys_addr_int;
						tx_burst_size_int <= SIZE_OF_SG_DESCRIPTOR; -- 1 DW
						tx_dir_int <= '0'; 
						tx_context_int <= x"0000" & GET_DESC_REQ & conv_std_logic_vector(CHAN_NUM,8);
						
											
					when SI_STATE_GET_NEXT_RECORDS_BURST =>	
					
						tx_req_int <= '1';
						tx_sys_addr_int <= next_rec_seg_addr; --max_read_request_size;
						tx_context_int <= x"0000" & GET_RECORD_REQ & conv_std_logic_vector(CHAN_NUM,8);
						tx_burst_size_int <= conv_std_logic_vector(RECORD_SEGMENT_SIZE,tx_burst_size_int'length); 
						tx_dir_int <= '0'; 
						if tx_grnt = '1' then
							stat_int_state <= SI_STATE_WAIT_FOR_REQ;
							req_active	<= '1';
							rec_burst_start_sig <= '1';
							next_rec_seg_addr <= next_rec_seg_addr+RECORD_SEGMENT_SIZE;
							if records_size_left < RECORD_SEGMENT_SIZE then
								records_size_left <= (others => '0');
							else
								records_size_left <= records_size_left - RECORD_SEGMENT_SIZE;
							end if;
						end if;
					
						
					when SI_STATE_WAIT_FOR_REQ =>
							
						wait_cnt <= wait_cnt+1;									
						
						if stop_req = '1' then
							stat_int_state <= SI_STATE_STOP;	
						elsif gen_status_req = '1' then
						--if status_req_pending = '1' then
							
							records_size_left <= (others => '0');
							rec_fifo_clr_n <= '0';
							status_addr_int	 	<= sg_status_addr;
							status_req_int		<= '1';
							 
							if SWAP_ENDIAN = 1 then
								status_qword_int <= "000" & '0' & x"1000000" & endigan_swap(transfer_count);
							else
								status_qword_int <= transfer_index & x"000" & "000" & '0' & x"1" & transfer_count;
							end if;
						    transfer_index <= transfer_index+1;
							stat_int_state <= SI_STATE_WAIT_FOR_STATUS_DONE;
							
						--elsif records_size_left /= x"00000000" and rec_burst_end_sig = '1' and rec_fifo_wc < x"09" then
						elsif half_fifo_sig = '1' then
							stat_int_state <= SI_STATE_GET_NEXT_RECORDS_BURST;
						end if;
						
					when SI_STATE_WAIT_FOR_STATUS_DONE =>
						rec_fifo_clr_n <= '0';	
						status_req_int		<= status_req_int;
						status_qword_int	<= status_qword_int;
						status_addr_int	 	<= status_addr_int;	
										
						if status_ack = '1' then
							status_req_int		<= '0';
							status_qword_int	<= (others => '0');
							status_addr_int	 	<= (others => '0');
						end if;
			
						
						if sg_generate_interrupt = '1' and msix_enabled = '1'  and status_ack = '1' then
							tx_sys_addr_int <= msix_msg_addr;
							tx_burst_size_int <= "00000000000100"; -- 1 DW
							tx_dir_int <= '1';
							stat_int_state <= SI_STATE_MSIX_ARBIT;
							tx_req_int <= '1';
							do_interrupt_int <= '1';
						elsif(sg_generate_interrupt = '1' and status_ack = '1')then  -- generate interrupt before continue the next packet
						    do_interrupt_int <= '1';
							stat_int_state <= SI_STATE_WAIT_OF_RECORD_GATE;
						elsif(status_ack = '1') then  -- no interrupt - start with next descriptor
							stat_int_state <= SI_STATE_WAIT_OF_RECORD_GATE;
						end if;
					
					when SI_STATE_MSIX_ARBIT =>
						tx_req_int <= '1';
						rec_fifo_clr_n <= '0';
						if tx_grnt = '1' then
							req_active	<= '1';
							stat_int_state <= SI_STATE_MSIX_MWr;
						end if;	
					when SI_STATE_MSIX_MWr =>
						rec_fifo_clr_n <= '0';
						req_active	<= '1';
						if tx_ready = '1' then
							tx_data_valid <= '1';
							tx_last <= '1';
						end if;
					
						
						if tx_ready = '1' and SWAP_ENDIAN = 1 then
							tx_data(31 downto 0) <= endigan_swap(msix_msg_data);
							tx_data(63 downto 32) <= endigan_swap(msix_msg_data);
						elsif tx_ready = '1' then
							tx_data(31 downto 0) <= msix_msg_data;
							tx_data(63 downto 32) <= msix_msg_data;
						end if;	
						
						if tx_ready = '1' then 
							stat_int_state <= SI_STATE_MSIX_MWr_Done;			
						end if;
						
					when SI_STATE_MSIX_MWr_Done =>	
						rec_fifo_clr_n <= '0';
						if tx_ready = '1' then
							msix_interrupt_done <= '1';
							stat_int_state <= SI_STATE_GET_DESCRIPTOR;
						end if;
					when SI_STATE_WAIT_OF_RECORD_GATE =>
						if rec_read_gate = '0' then
							stat_int_state <= SI_STATE_GET_DESCRIPTOR;
							tx_sys_addr_int <= sg_next_desc_address;
							tx_burst_size_int <= SIZE_OF_SG_DESCRIPTOR; -- 1 DW
							tx_dir_int <= '0'; 
							tx_context_int <= x"0000" & GET_DESC_REQ & conv_std_logic_vector(CHAN_NUM,8);
						end if;	
					when SI_STATE_STOP =>
						stat_int_state <= SI_STATE_IDLE; 
				end case;
			end if;
		end if;
	end process;


	
		
   	process(clk_in)
   	begin
 		if rising_edge(clk_in) then
 			if(rstn = '0')then
                bm_transfer_size_o             <= (others => '0'); 
                bm_transfer_size_valid_o       <= '0';
 			else
 			    bm_transfer_size_valid_o       <= '0';
 				if desc_valid = '1' then
                    --bm_transfer_size_o             <= sg_descriptor0(159 downto 128); 
                    bm_transfer_size_o             <= "00" & sg_descriptor0(127 downto 98); 
                    
                    bm_transfer_size_valid_o       <= '1';
 				end if;
 			end if;
 		end if;
 	end process;
	
		
	
	process(clk_in)
	begin
		if rising_edge(clk_in) then
			status_interrupt_done <= '0';
			if do_interrupt_int = '1' or msix_interrupt_done = '1' then
				status_interrupt_done <= '1';
			end if;
		end if;
	end process;  

	do_interrupt			<= do_interrupt_int;
	status_addr_out			<=  status_addr_int; 
	status_req_out			<=  status_req_int;  
	status_qword_out 		<=  status_qword_int;

---======================================================== Descriptor and Records Fetchin ==================================================	


	process(clk_in)
	begin
		if rising_edge(clk_in) then
			rec_fifo_dav_d <= rec_fifo_dav;
		end if;
	end  process;



  	record_fifo : FIFO_core_wc 
    generic map
    (
        Data_Width => get_fifo_width,
        Log2_of_Depth => 5
    )
    port map
    (
        C		=> clk_in, 
        R   	=> rec_fifo_clr_n,
        --Write side
		wc		=> rec_fifo_wc,
        Wd      => Wd,
        WE      => rec_fifo_write,
        Full    => rec_fifo_full,
        --read side
        Rd      => rec_fifo_rd,
        RE      => rec_fifo_rd_req,
        Dav     => rec_fifo_dav,
        Empty   => rec_fifo_empty 
    );  


  rec_fifo_gen_64_128: if PCIE_CORE_DATA_WIDTH = 128 or PCIE_CORE_DATA_WIDTH = 64  generate

--  	record_fifo : FIFO_core_wc 
--    generic map
--    (
--        Data_Width => 96,
--        Log2_of_Depth => 5
--    )
--    port map
--    (
--        C		=> clk_in, 
--        R   	=> rec_fifo_clr_n,
--        --Write side
--		wc		=> rec_fifo_wc,
--        Wd      => rec_to_fifo(127 downto 32),
--        WE      => rec_fifo_write,
--        Full    => rec_fifo_full,
--        --read side
--        Rd      => record_out_int,
--        RE      => rec_fifo_rd_req,
--        Dav     => rec_fifo_dav,
--        Empty   => rec_fifo_empty 
--    ); 

	record_out_int <= rec_fifo_rd; 

    Wd <= rec_to_fifo(127 downto 32); 

   process(clk_in) 
   begin
   	if rising_edge(clk_in) then 
   		if rec_fifo_clr_n = '0' then
   			half_fifo_sig <= '0';
   		else
   			rec_fifo_wc_d <= rec_fifo_wc;
   			
   			half_fifo_sig <= '0';
   			if records_size_left /= x"00000000" and rec_fifo_wc_d = 9 and rec_fifo_wc = 8 then
				half_fifo_sig <= '1';   			
   			elsif records_size_left /= x"00000000" and  rec_burst_end_sig = '1' and rec_fifo_wc < 9 then
   				half_fifo_sig <= '1';
	   		end if; 
	   		
   		end  if;	   
    end if;
   end process;
   
   record_valid <= rec_fifo_dav;
   stall_rec_fifo_rd_req <= rec_fifo_rd_req or rec_fifo_empty or rec_fifo_dav or rec_fifo_dav_d;
   process(clk_in) 
   begin
   	if rising_edge(clk_in) then 
   		if rec_fifo_clr_n = '0' then
   			rec_fifo_rd_req <= '0';
   		else
				rec_fifo_rd_req <= '0';
				if stall_rec_fifo_rd_req = '0' and 	record_req = '1' then
					rec_fifo_rd_req <= '1';
				end if;
	   		
   		end  if;	   
    end if;
   end process;
   
          
  end generate;		

  
rec_fifo_gen_256: if PCIE_CORE_DATA_WIDTH = 256  generate


--  	record_fifo_256 : FIFO_core_wc 
--    generic map
--    (
--        Data_Width => 192,
--        Log2_of_Depth => 5
--    )
--    port map
--    (
--        C		=> clk_in, 
--        R   	=> rec_fifo_clr_n,
--        --Write side
--		wc		=> rec_fifo_wc,
--        Wd      => Wd,
--        WE      => rec_fifo_write,
--        Full    => rec_fifo_full,
--        --read side
--        Rd      => rec_fifo_rd,
--        RE      => rec_fifo_rd_req,
--        Dav     => rec_fifo_dav,
--        Empty   => rec_fifo_empty 
--    );
    
    Wd <= rec_to_fifo(255 downto 160) & rec_to_fifo(127 downto 32);  


   record_req_sig <= record_req and not record_req_d; 
   process(clk_in) 
   begin
   	if rising_edge(clk_in) then 
   		if rec_fifo_clr_n = '0' then
   			 rec_fifo_rd_req <= '0';
   			 record_valid <= '0';
   			 rec_fifo_rd_st <= REC_FIFO_RD_WAIT_ON_FIFO;
   			 rec_high <= (others => '0');
   			 record_out_int <= (others => '0');
   			 rec_active <= '0';
   			 record_req_d <= '0';
   		else
   			record_req_d <= record_req;
			rec_fifo_rd_req <= '0';
			record_valid <= '0';
			rec_active <= '0';
   			case rec_fifo_rd_st is
   				when REC_FIFO_RD_WAIT_ON_FIFO =>
   					if rec_fifo_empty = '0' then
   						rec_fifo_rd_req <= '1';
   						rec_fifo_rd_st <= REC_FIFO_RD_WAIT_ON_REQ_LOW;
   					end if; 
   				when REC_FIFO_RD_WAIT_ON_REQ_LOW =>
   					
   					rec_active <= rec_active;
   					if rec_fifo_dav = '1' then
   						record_out_int <= rec_fifo_rd(95 downto 0);
   						rec_high <= rec_fifo_rd(191 downto 96);
   						rec_active <= '1';			
   					end if;
   					
   					if rec_active = '1' and record_req = '1' then
   						record_valid <= '1';
   						if record_out_int(0) = '1' then --if this is the last record
   							rec_fifo_rd_st <= REC_FIFO_RD_WAIT_ON_FIFO;			
   						else
   							rec_fifo_rd_st <= REC_FIFO_RD_WAIT_ON_REQ_HIGH;
   						end if;
   					end if;
   				when REC_FIFO_RD_WAIT_ON_REQ_HIGH =>
   					record_out_int <= rec_high;
   					if record_req_sig = '1' then
   						record_valid <= '1';
   						rec_fifo_rd_st <= REC_FIFO_RD_WAIT_ON_FIFO;
   					end if;
   			end case;
   		
   		
   		end if;
   	end if;
   end process;    
    
    
    
    
   process(clk_in) 
   begin
   	if rising_edge(clk_in) then 
   		if rec_fifo_clr_n = '0' then
   			half_fifo_sig <= '0';
   		else
   			rec_fifo_wc_d <= rec_fifo_wc;
   			
   			half_fifo_sig <= '0';
   			if records_size_left /= x"00000000" and rec_fifo_wc_d = 5 and rec_fifo_wc = 4 then
				half_fifo_sig <= '1';   			
   			elsif records_size_left /= x"00000000" and  rec_burst_end_sig = '1' and rec_fifo_wc < 5 then
   				half_fifo_sig <= '1';
	   		end if; 
	   		
   		end  if;	   
    end if;
   end process;
          
end generate;		
  

 	gne_64: if PCIE_CORE_DATA_WIDTH = 64 generate
 	
 	
    desc_in : process(clk_in)
   	begin
 		if rising_edge(clk_in) then
 			if rstn = '0' then
                sg_descriptor0             <= (others => '0'); 
                sg_desc_wrtie_index        <= 0;
 			else
 			    
 				
 				if rx_done = '1' then
 					sg_desc_wrtie_index        <= 0;
 				elsif context_in(8) = '1' and rx_active = '1' then
 					sg_desc_wrtie_index   <= sg_desc_wrtie_index+1;
 				end if;
 				
 				if context_in(8) = '1' and rx_active = '1' then
 					case sg_desc_wrtie_index is
 						when 0 =>
 							sg_descriptor0(PCIE_CORE_DATA_WIDTH-1 downto 0) <= rx_data;
 						when 1 =>
 							sg_descriptor0(2*PCIE_CORE_DATA_WIDTH-1 downto PCIE_CORE_DATA_WIDTH) <= rx_data;
 						when 2 =>
 							sg_descriptor0(3*PCIE_CORE_DATA_WIDTH-1 downto 2*PCIE_CORE_DATA_WIDTH) <= rx_data;
 						when 3 =>
 							sg_descriptor0(4*PCIE_CORE_DATA_WIDTH-1 downto 3*PCIE_CORE_DATA_WIDTH) <= rx_data;
 					end case;
 									
 				end if;
 			end if;
 		end if;
 	end process;	
 	
 	
 	rec_mem_proc : process(clk_in)
   	begin
 		if rising_edge(clk_in) then
 			if rstn = '0' then
				record_reading_done_sig <= '0'; 
				toggle_rec <= '0';
				rec_to_fifo <= (others => '0');
				rec_fifo_write <= '0';
 			else
 				rec_fifo_write <= '0';
				record_reading_done_sig <= '0'; 
				if record_reading_active = '1' then 
					
				
					if rx_active = '1' and rx_be_i = x"0F" then
						toggle_rec <= '0';
					elsif rx_active = '1' then
						toggle_rec <= not toggle_rec;
					end if;
	
					if rx_active = '1' and toggle_rec = '1' then 
						rec_to_fifo(127 downto 64) <= rx_data;
					elsif rx_active = '1' then
						rec_to_fifo(63 downto 0) <= rx_data;
					end if;
									
					if rx_active = '1' and toggle_rec = '1' then 
						rec_fifo_write <= '1';
					end if;
												
				else
					toggle_rec <= '0';	
				end if;			

 			end if;
 		end if;
 	end process;

  end generate;	

  	gne_128: if PCIE_CORE_DATA_WIDTH = 128 generate
 	
    desc_in : process(clk_in)
   	begin
 		if rising_edge(clk_in) then
 			if rstn = '0' then
                sg_descriptor0             <= (others => '0'); 
                sg_desc_wrtie_index        <= 0;
 			else
 			    
 				
 				if rx_done = '1' then
 					sg_desc_wrtie_index        <= 0;
 				elsif context_in(8) = '1' and rx_active = '1' then
 					sg_desc_wrtie_index   <= sg_desc_wrtie_index+1;
 				end if;
 				
 				if context_in(8) = '1' and rx_active = '1' then
 					case sg_desc_wrtie_index is
 						when 0 =>
 							sg_descriptor0(PCIE_CORE_DATA_WIDTH-1 downto 0) <= rx_data;
 						when 1 =>
 							sg_descriptor0(2*PCIE_CORE_DATA_WIDTH-1 downto PCIE_CORE_DATA_WIDTH) <= rx_data;
 						when others =>
 							sg_descriptor0(PCIE_CORE_DATA_WIDTH-1 downto 0) <= rx_data;
 					end case;
 									
 				end if;
 			end if;
 		end if;
 	end process;
  	  	
  	rec_fifo_write <= rx_active when record_reading_active = '1' else '0';
    rec_to_fifo <= rx_data;
    	
 

  end generate;	
  
  	gne_256: if PCIE_CORE_DATA_WIDTH = 256 generate
 	
    desc_in : process(clk_in)
   	begin
 		if rising_edge(clk_in) then
 			if rstn = '0' then
                sg_descriptor0 <= (others => '0'); 
 			elsif context_in(8) = '1' and rx_active = '1' then
				sg_descriptor0 <= rx_data;
 			end if;
 		end if;
 	end process;
  	  	
  	rec_fifo_write <= rx_active when record_reading_active = '1' else '0';
    rec_to_fifo <= rx_data;

  end generate;		
  

    rec_read_gate_proc : process(clk_in)
   	begin
 		if rising_edge(clk_in) then
 			if rstn = '0' then
                rec_read_gate <= '0'; 
 			else
 				if rec_burst_start_sig = '1' then
 					rec_read_gate <= '1';
 				end if;
 				if rec_burst_end_sig = '1' then
					rec_read_gate <= '0';
				end if;
 			end if;
 		end if;
 	end process;
    
  		
  

	tx_sys_addr <= tx_sys_addr_int;
	tx_burst_size <= tx_burst_size_int;
	tx_dir <= tx_dir_int;
	tx_context <= tx_context_int;
	record_out <= record_out_int;
  
  record_reading_active <= rx_active when context_in(11 downto 8) = GET_RECORD_REQ else '0';

  rec_burst_end_sig <= rx_done  and record_reading_active;
  	
	
  
	--                                                   Scatter Gather Descriptor
	--					+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--					+31+30+29+28+27+26+25+24+23+22+21+20+19+18+17+16+15+14+13+12+11+10+09+08+07+06+05+04+03+02+01+00+ 				 	
	--					+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	W0	31-00 		+                         Next Pointer  32/ Source Address 64 High	         	      		    +
	--					+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	W1	63-32		+							  Next Pointer  32/Source Address 64 Low					  +I + L+
	--					+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	W2	95-64 		+									 Transfer Data Count										+
	--					+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	W3	127-96   	+                            		User Tagging Area 	             		  		  		 + S+ 
	--					+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	W4	159-128		+				  				   Number Of Transfer Addresses								    +
	--					+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	W5	191-160		+				  				  	Record List Address Low							   	  +0 +C +
	--			  		+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	W6	223-192 	+				  				   Record List Address High		    							+
	--			  		+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	W6	255-224 	+				  				   		   Reserved		    									+
	--			  		+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+

	sg_next_desc_address 	<= sg_descriptor0(63 downto 2) & "00";
	sg_active				<= sg_descriptor0(97);
	sg_last_desc			<= sg_descriptor0(0); 
	sg_generate_interrupt	<= sg_descriptor0(1);
	sg_rec_buffer_size		<= sg_descriptor0(159 downto 128);
	sg_rec_list_address 	<= sg_descriptor0(223 downto 162) & "00";
	sg_cyclic				<= sg_descriptor0(160);
	sg_desc_signiture		<= sg_descriptor0(sg_descriptor0'high downto sg_descriptor0'high-31);
	sg_status_addr			<= sg_descriptor0(255 downto 224) & sg_descriptor0(95 downto 64);

	
	tx_req <= tx_req_int;
	
	
	--     mem                                 Scatter Gather record 												vector
	--			+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	 95-64	+											   Transfer Size                                    +
	--			+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--	 63-32	+                                Source Address High	       	   			   			     	+ 
	--	   		+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
	--   31-0 	+											Source Address 64 Low				          +R + D+ 
	--			+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
		
    
  	
end arc;

	
	
	
		