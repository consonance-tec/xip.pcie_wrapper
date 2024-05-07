----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    08:15:40 02/18/2022 
-- Design Name: 
-- Module Name:    
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


entity rc_to_tlp is
generic
(
	PCIE_CORE_DATA_WIDTH	: integer := 128;
	AXI4_RC_TUSER_WIDTH   : integer  := 75

);
port 
( 
	clk_i                 	: in std_logic;
	rstn_i                	: in std_logic;
	
	-- avalon stream tlp 
	m_axis_tvalid       	:  out std_logic;
	m_axis_tready       	:  in  std_logic;
	m_axis_tdata 			:  out STD_LOGIC_VECTOR (PCIE_CORE_DATA_WIDTH-1 DOWNTO 0);
	m_axis_tlast 			:  out STD_LOGIC;
	m_axis_tuser 			:  out STD_LOGIC;
	m_axis_tkeep	    	:  out STD_LOGIC_VECTOR (PCIE_CORE_DATA_WIDTH/32-1 DOWNTO 0);
	
	-- xilinx Requestor Complete AXI Stream interface3
   	s_axis_rc_tdata			: in  std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
   	s_axis_rc_tuser			: in  std_logic_vector(AXI4_RC_TUSER_WIDTH-1 downto 0);
   	s_axis_rc_tlast			: in  std_logic;
   	s_axis_rc_tkeep			: in  std_logic_vector(PCIE_CORE_DATA_WIDTH/32-1 downto 0);
   	s_axis_rc_tvalid		: in  std_logic;
   	s_axis_rc_tready		: out std_logic_vector(0 downto 0)
	

);
end rc_to_tlp;


architecture Behavioral of rc_to_tlp is

constant CPLD_FMT_TYPE 	  : std_logic_vector(6 downto 0) := "1001010";

signal empyt : std_logic_vector(PCIE_CORE_DATA_WIDTH/32-1 downto 0);

signal s_axis_rc_tdata_int		: std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
signal s_axis_rc_tuser_int		: std_logic_vector(AXI4_RC_TUSER_WIDTH-1 downto 0);
signal s_axis_rc_tlast_int		: std_logic;
signal s_axis_rc_tkeep_int		: std_logic_vector(PCIE_CORE_DATA_WIDTH/32-1 downto 0);
signal s_axis_rc_tvalid_int		: std_logic;

begin


process(clk_i)
begin
	if rising_edge(clk_i) then
		m_axis_tkeep <= (others => '0');
		if s_axis_rc_tvalid_int = '1' and s_axis_rc_tlast_int = '1' then
			m_axis_tkeep <= s_axis_rc_tkeep_int; --empyt;
		end if;
	end if;
end process;

process(clk_i)
begin
	if rising_edge(clk_i) then
		m_axis_tuser <= '0';
		if s_axis_rc_tvalid_int = '1' then
			m_axis_tuser <= s_axis_rc_tuser_int(32);
		end if;
	end if;
end process;

process(clk_i)
begin
	if rising_edge(clk_i) then
		m_axis_tvalid <=  s_axis_rc_tvalid_int;
		m_axis_tlast <=  s_axis_rc_tlast_int;
	end if;
end process;

process(clk_i)
begin
	if rising_edge(clk_i) then
		s_axis_rc_tdata_int	 <= s_axis_rc_tdata;
		s_axis_rc_tuser_int  <= s_axis_rc_tuser;
		s_axis_rc_tlast_int  <= s_axis_rc_tlast;
		s_axis_rc_tkeep_int  <= s_axis_rc_tkeep;
		s_axis_rc_tvalid_int <= s_axis_rc_tvalid;
	end if;
end process;

 
process(clk_i)
begin
	if rising_edge(clk_i) then
		m_axis_tdata 	<=	s_axis_rc_tdata_int;
		if s_axis_rc_tvalid_int = '1' and s_axis_rc_tuser_int(32) = '1' then
			m_axis_tdata(9 downto 0) <= s_axis_rc_tdata_int(41 downto 32);  -- Length
			m_axis_tdata(11 downto 10) <= "00"; -- Reserved
			m_axis_tdata(13 downto 12) <= s_axis_rc_tdata_int(93 downto 92); --Attr
			m_axis_tdata(14) <= '0'; -- EP not transfferd by ip core
			m_axis_tdata(15) <= '0'; -- TD not tranfferd by the ip core
			m_axis_tdata(19 downto 16) <= "0000"; -- Reserved
			m_axis_tdata(22 downto 20) <= s_axis_rc_tdata_int(91 downto 89); --
			m_axis_tdata(23) <= '0';
			m_axis_tdata(30 downto 24) <= CPLD_FMT_TYPE;
			m_axis_tdata(31) <= '0';
			m_axis_tdata(43 downto 32) <= s_axis_rc_tdata_int(27 downto 16);
			m_axis_tdata(44) <= '0'; --BCM
			m_axis_tdata(47 downto 45) <= s_axis_rc_tdata_int(14 downto 12); --error code
			m_axis_tdata(63 downto 48) <= s_axis_rc_tdata_int(87 downto 72); --completer id
			m_axis_tdata(70 downto 64) <= s_axis_rc_tdata_int(6 downto 0); --lower address
			m_axis_tdata(71) <= '0';-- Reserved
			m_axis_tdata(79 downto 72) <= s_axis_rc_tdata_int(71 downto 64); --tag
			m_axis_tdata(95 downto 80) <= s_axis_rc_tdata_int(63 downto 48); --requester id
		end if;	
	end if;
end process;
	
	
	
	s_axis_rc_tready(0) <= m_axis_tready;

end Behavioral;

