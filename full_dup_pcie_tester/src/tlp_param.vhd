--============================================================================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity tlp_param is	

port
(
	                	
	tx_len		: in  std_logic_vector(12 downto 0);
	
	tlp_fbe 	: out std_logic_vector(3 downto 0);
	tlp_lbe 	: out std_logic_vector(3 downto 0);
	tlp_dw_len 	: out std_logic_vector(10 downto 0)	
	           	
	
);
end tlp_param;

architecture arc of tlp_param is

begin

	tlp_fbe <= x"f";     
	
	
	process(tx_len(1 downto 0)) 
	begin
		case tx_len(1 downto 0) is 
			when "01" => 
				tlp_lbe <= "0001";
			when "10" => 
				tlp_lbe <= "0011";
			when "11" => 
				tlp_lbe <= "0111";
			when others =>
				tlp_lbe <= "1111";
		end case;		
	end process;
	     --
	

	process(tx_len)
	begin
		case tx_len(2 downto 0) is
			when "000" => -- aligned on four
				tlp_dw_len <= tx_len(12 downto 2);	
			when "001" =>
				tlp_dw_len <= tx_len(12 downto 2)+1;
			when "010" =>
				tlp_dw_len <= tx_len(12 downto 2)+1;
			when "011" =>
				tlp_dw_len <= tx_len(12 downto 2)+1;
			when "100" => -- aligned on four
				tlp_dw_len <= tx_len(12 downto 2);
			when "101" =>
				tlp_dw_len <= tx_len(12 downto 2)+1;
			when "110" =>
				tlp_dw_len <= tx_len(12 downto 2)+1;
			when "111" =>                                        
				tlp_dw_len <= tx_len(12 downto 2)+1;       
			when others =>                                       
				tlp_dw_len <= tx_len(12 downto 2);         
		end case;                                                
	end process;                                                 


end arc;



