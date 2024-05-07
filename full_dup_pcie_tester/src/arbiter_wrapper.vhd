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
use ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;



entity arbiter_wrapper is
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
end arbiter_wrapper;


architecture Behavioral of arbiter_wrapper is

function rouded_to_pow2(num : integer) return integer
is

variable ret : std_logic_vector(31 downto 0)  := x"00000010";
begin
	
	while ret < conv_std_logic_vector(num,ret'high+1) loop
		ret := ret(ret'high-1 downto 0) & '0';
	end loop;
	return conv_integer(ret);
end function;


component scalable_arbiter 
generic
(
	WIDTH : natural := 0;
	SELECT_WIDTH : natural := 1
);
port
(
	enable 	: in std_logic;
	req  		: in std_logic_vector(WIDTH-1 downto 0);
	grant 	: out std_logic_vector(WIDTH-1 downto 0);
	sel 		: out std_logic_vector(SELECT_WIDTH-1 downto 0);
	valid 	: out std_logic;
	
	clock : in std_logic;
	reset : in std_logic
);
end component;



signal reset_p 		: std_logic;
signal enable 		: std_logic;
signal sel 			: std_logic_vector(SELECT_WIDTH-1 downto 0);
signal valid 		: std_logic;
signal mux_index 	: integer range 0 to NUM_OF_CHANNLES-1;

signal bm_gnt_out 	: std_logic_vector(NUM_OF_CHANNLES-1 downto 0);

signal bm_req		: std_logic_vector(rouded_to_pow2(NUM_OF_CHANNLES)-1 downto 0);
signal bm_gnt	 	: std_logic_vector(rouded_to_pow2(NUM_OF_CHANNLES)-1 downto 0);


 attribute keep: string;
 attribute keep of mux_index : signal is "ture"; 
 attribute keep of bm_gnt_out : signal is "ture"; 

begin


arbit : scalable_arbiter 
generic map
(
	WIDTH => rouded_to_pow2(NUM_OF_CHANNLES),
	SELECT_WIDTH => SELECT_WIDTH
)
port map
(
	enable 	=> enable,
	req  		=> bm_req,
	grant 	=> bm_gnt,
	sel 		=> sel,
	valid 	=> valid,
	
	
	clock 		=> clk,
	reset 	=> reset_p 
);

--	bm_gnt 	<= bm_req_i;
--	sel 		<= "0000";
--	valid 	<= '1' when bm_gnt /= "0000" else '0';

bm_req(NUM_OF_CHANNLES-1 downto 0) <= bm_req_i;
BM_REQ_LEADING_ZERO_gen: for i in 0 to (rouded_to_pow2(NUM_OF_CHANNLES)- NUM_OF_CHANNLES)-1 generate
	bm_req(NUM_OF_CHANNLES+i) <=  '0';	
end generate;	

  process begin
    wait until rising_edge(clk);
    if (reset_n_i = '0') then
		mux_index <= 0;
		bm_gnt_out <= (others => '0');
	 else
		bm_gnt_out <= (others => '0');
		if(valid = '1')then
			mux_index <= conv_integer(sel);
			bm_gnt_out <= bm_gnt(bm_gnt_out'high downto 0);
		end if;
	 end if;
 end process;

enable <= '1';
reset_p <= not reset_n_i;
bm_gnt_o <= bm_gnt_out;
mux_index_o <= mux_index;

end Behavioral;

