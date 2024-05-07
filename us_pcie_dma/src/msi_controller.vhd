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
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;


entity msi_controller is
generic
(
	NUM_OF_INTERRUPTS : integer := 1;
  	AXI_ID_WIDTH      : integer := 8;
  	AXI_ADDR_WIDTH    : integer := 16;
  	AXI_DATA_WIDTH    : integer := 32;
  	AXI_STRB_WIDTH    : integer := 4
	
);
port 
( 
-- clock and reset
  reset_n_i : in  STD_LOGIC;
  clk 		: in  STD_LOGIC;
   
-- app interrutp requests   
  int_req 	: in  std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
  int_ack 	: out std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
   	
  fifo_full : out std_logic;
   	
--  core interface  	
  cfg_interrupt_msi_enable  : in  std_logic_vector(3 downto 0);     					                    
  cfg_interrupt_msi_int     : out  std_logic_vector(31 downto 0);     				                         		
  cfg_interrupt_msi_sent    : in  std_logic;    										                                       
  cfg_interrupt_msi_fail    : in  std_logic;
  
  
-- AXI Lite Registes target for W/R from the host
  s_axil_awaddr   : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);    	           
  s_axil_awprot   : in  std_logic_vector(2 downto 0);               		           
  s_axil_awvalid  : in  std_logic;                   				           
  s_axil_awready  : out std_logic;                     				           
  s_axil_wdata    : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    	           
  s_axil_wstrb    : in  std_logic_vector(AXI_STRB_WIDTH-1 downto 0);    	           
  s_axil_wvalid   : in  std_logic;                     				           
  s_axil_wready   : out std_logic;                     				           
  s_axil_bresp    : out std_logic_vector(1 downto 0);               		           
  s_axil_bvalid   : out std_logic;                     				           
  s_axil_bready   : in  std_logic;                     				           
  s_axil_araddr   : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);    	
  s_axil_arprot   : in  std_logic_vector(2 downto 0);               		
  s_axil_arvalid  : in  std_logic;                     				
  s_axil_arready  : out std_logic;                     				
  s_axil_rdata    : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    	
  s_axil_rresp    : out std_logic_vector(1 downto 0);               		
  s_axil_rvalid   : out std_logic;                     				
  s_axil_rready   : in  std_logic                    				
      										                                       		
	
		
);
end msi_controller;

architecture Behavioral of msi_controller is

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



signal pending_req 	: std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
signal pending_gnt 	: std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0); 


signal int_req_d 	 : std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
signal int_req_re 	 : std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
signal pending_gnt_d : std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
signal pending_re    : std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
signal pending_gnt_er    : std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);

signal pending_req_fifo_we  	: std_logic;
signal pending_req_fifo_rd		: std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
signal pending_req_fifo_re		: std_logic;
signal pending_req_fifo_dav		: std_logic;
signal pending_req_fifo_empty   : std_logic;

signal curr_intertupt_out_pending : std_logic_vector(NUM_OF_INTERRUPTS-1 downto 0);
signal out_pending	: std_logic;


 signal cfg_interrupt_msi_enable_int  : std_logic_vector(3 downto 0);     					                    
 signal cfg_interrupt_msi_sent_int    : std_logic;    										                                       
 signal cfg_interrupt_msi_fail_int    : std_logic;
 signal cfg_interrupt_msi_int_int     : std_logic_vector(31 downto 0);     				                         		
 
attribute keep: string;
attribute keep of cfg_interrupt_msi_enable_int  : signal is "ture"; 
attribute keep of cfg_interrupt_msi_sent_int    : signal is "true";
attribute keep of cfg_interrupt_msi_fail_int    : signal is "true";
attribute keep of cfg_interrupt_msi_int_int      : signal is "true";
 
begin


process(clk)
begin
    cfg_interrupt_msi_enable_int <= cfg_interrupt_msi_enable; 
    cfg_interrupt_msi_sent_int   <= cfg_interrupt_msi_sent;
    cfg_interrupt_msi_fail_int   <= cfg_interrupt_msi_fail;
end process;

process(clk)
begin
	if rising_edge(clk) then
		if reset_n_i = '0' then
			cfg_interrupt_msi_int_int <= (others => '0');
			int_ack <= (others => '0');
			out_pending <= '0';
			pending_req_fifo_re <= '0';
			curr_intertupt_out_pending <= (others => '0');
		else
			cfg_interrupt_msi_int_int <= (others => '0');
			int_ack <= (others => '0');
			pending_req_fifo_re <= '0';

			if out_pending = '0' and  pending_req_fifo_empty = '0'then
				pending_req_fifo_re <= '1';
				out_pending <= '1';
			end if; 
			
			if pending_req_fifo_dav = '1' then
				curr_intertupt_out_pending <= pending_req_fifo_rd;
				cfg_interrupt_msi_int_int <= x"00000001";
			end if;
			
			if cfg_interrupt_msi_sent = '1' then
				out_pending <= '0';
				curr_intertupt_out_pending <= (others => '0'); 
				int_ack <= curr_intertupt_out_pending;
			end if;
			
		end if;
	end if;
end process;

process(clk)
begin
	if rising_edge(clk) then
		if reset_n_i = '0' then
			pending_req <= (others => '0');						
			pending_req_fifo_we <= '0';
		else

		
			pending_req_fifo_we <= '0';
			for i in 0 to NUM_OF_INTERRUPTS-1 loop
			   if int_req_re(i) = '1' and cfg_interrupt_msi_enable_int(0) = '1' then
			   		pending_req(i) <= '1';
			   end if;
			      
			   if pending_gnt_er(i) = '1' then
			       pending_req(i) <= '0';
			       pending_req_fifo_we <= '1';
			   end if;
			end loop;	   
			
						   
		end if;
	end if;
end process;


int_req_re <= int_req and not int_req_d;
pending_gnt_er <= pending_gnt and not pending_gnt_d;
process(clk)
begin
	if rising_edge(clk) then
		int_req_d <= int_req;
		pending_gnt_d <= pending_gnt;
	end if;
end process;


   arbiter : arbiter_wrapper 
   generic map
   (
   	NUM_OF_CHANNLES => NUM_OF_INTERRUPTS,
   	SELECT_WIDTH => 8
   )
   PORT MAP 
   (
		clk  			=> clk,
		reset_n_i       => reset_n_i,
		bm_req_i		=> pending_req,
		bm_gnt_o		=> pending_gnt,
		
		mux_index_o		=> open
   );

      
pending_req_fifo : FIFO_core_wc 
generic map
(
	Data_Width => NUM_OF_INTERRUPTS,
	Log2_of_Depth => 4
)
port map
(
        C => clk,
        R  => reset_n_i,
        --Write side
        wc	   => open,
        Wd     => pending_gnt,
        WE     => pending_req_fifo_we,
        Full   => fifo_full,
        --read side
        Rd      => pending_req_fifo_rd,
        RE      => pending_req_fifo_re,
        Dav     => pending_req_fifo_dav,
        Empty   => pending_req_fifo_empty
); 
   

  cfg_interrupt_msi_int <= cfg_interrupt_msi_int_int;	

  s_axil_awready  <= '0';                     				           
  s_axil_wready   <= '0';                     				           
  s_axil_bresp    <= (others => '0');               		           
  s_axil_bvalid   <= '0';                     				           
  s_axil_arready  <= '0';                     				
  s_axil_rdata    <= (others => '0');    	
  s_axil_rresp    <= (others => '0');               		
  s_axil_rvalid   <= '0';                     				



end Behavioral;

