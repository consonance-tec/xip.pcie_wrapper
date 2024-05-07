Library IEEE;

-- Following libraries have to be used
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


ENTITY simple_dpr_infferd IS
	GENERIC (
			-- Note : 
			-- If the chosen width and depth values are low, Synthesis will infer Distributed RAM. 
			-- C_RAM_DEPTH should be a power of 2
			C_RAM_WIDTH : integer := 16;		-- Specify RAM data width
			MEM_ADDR_SIZE : integer := 2;
			C_RAM_PERFORMANCE : string := "HIGH_PERFORMANCE"	-- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
	);
    PORT (
			signal C  		: in std_logic;                                             -- Clock

			signal WAdd 	: in std_logic_vector(MEM_ADDR_SIZE-1 downto 0);            -- Port A Address bus, width determined from RAM_DEPTH
			signal Wd  		: in std_logic_vector(C_RAM_WIDTH-1 downto 0);              -- Port A RAM input data
			signal WE   	: in std_logic;                                             -- Port A Write enable
			signal Ena   	: in std_logic;                                             -- Port A RAM Enable, for additional power savings, disable port when not in use
			
			signal RAdd 	: in std_logic_vector(MEM_ADDR_SIZE-1 downto 0);            -- Port B Address bus, width determined from RAM_DEPTH
			signal Rd 		: out std_logic_vector(C_RAM_WIDTH-1 downto 0);             -- Port B RAM output data
			signal REna		: in std_logic                                              -- Port B Output register enable
    );    
END simple_dpr_infferd;    

ARCHITECTURE behave OF simple_dpr_infferd IS


constant C_RAM_DEPTH : integer := 2**MEM_ADDR_SIZE;        -- Specify RAM depth (number of entries)


--Insert the following in the architecture before the begin keyword 
--  The following function calculates the address width based on specified RAM depth
function clogb2( depth : natural) return integer is
variable temp    : integer := depth;
variable ret_val : integer := 0; 
begin					
    while temp > 1 loop
        ret_val := ret_val + 1;
        temp    := temp / 2;     
    end loop;
    return ret_val;
end function;



type ram_type is array (C_RAM_DEPTH-1 downto 0) of std_logic_vector (C_RAM_WIDTH-1 downto 0);      -- 2D Array Declaration for RAM signal
signal ram_data_a : std_logic_vector(C_RAM_WIDTH-1 downto 0) ;                                   
signal ram_data_b : std_logic_vector(C_RAM_WIDTH-1 downto 0) ;                                   


-- Define RAM 
signal ram_name : ram_type;
signal doutb_reg 	: std_logic_vector(C_RAM_WIDTH-1 downto 0) := (others => '0');  -- Port B RAM output data when RAM_PERFORMANCE = HIGH_PERFORMANCE

			
begin


process(C)
begin
    if(C'event and C = '1') then
        if(Ena = '1') then
            if(WE = '1') then
                ram_name(to_integer(unsigned(WAdd))) <= Wd;
            end if;
        end if;
    end if;
end process;

process(C)
begin
    if(C'event and C = '1') then
        ram_data_b <= ram_name(to_integer(unsigned(RAdd)));
    end if;
end process;



--  Following code generates LOW_LATENCY (no output register)
--  Following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing

no_output_register : if C_RAM_PERFORMANCE = "LOW_LATENCY" generate
    Rd <= ram_data_b;
end generate;

--  Following code generates HIGH_PERFORMANCE (use output register) 
--  Following is a 2 clock cycle read latency with improved clock-to-out timing

output_register : if C_RAM_PERFORMANCE = "HIGH_PERFORMANCE"  generate
process(C)
begin
    if(C'event and C = '1') then
		if(REna = '1') then
            doutb_reg <= ram_data_b;
        end if;
    end if;
end process;

Rd <= doutb_reg;

end generate;

END behave;


