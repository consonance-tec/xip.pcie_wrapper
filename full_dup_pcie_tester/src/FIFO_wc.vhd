-------------------------------------------------------------------------
-- File name    :  FIFO_wc.vhd
-- Title        :  FIFO core
-- ----------------------------------------------------------------------
-- Revision History :
-- ----------------------------------------------------------------------
--   Version No:| Author      :| Mod. Date :|    Changes Made:
--     v1.0     |             |         	| Automatically Generated
-------------------------------------------------------------------------
--+----------------------------------------------------------------------
--|--  Interface data :
--|--  Generic parameters ----------------------------------------
--|--  Data_Width      Number of data bits in word.
--|--  Log2_of_Depth   Number of bits of the FIFO depth. Example 7 for 128.
--|--  
--|--  Port signals ----------------------------------------------
--|--  C           Clock Signal.
--|--  R           Reset signal active at LOW.  
--|--  --Write side
--|--  wc		   word count =  number of written words to the fifo.
--|--  Wd          Write data bus, width as in Data width.
--|--  WE          Write Enable signal
--|--  Full        Fifo Full signal. If at logic '1' Write pointers 
--|--              don't move even if WE is at '1'. 
--|--              Note : Data is writen into Write pointer address.
--|--  --read side
--|--  Rd          Read data bus,  width as in Data width.
--|--  RE          Read Enable signal. 
--|--  Dav         Data avaliable. One clock after RE if FIFO not Empty.
--|--              Note : Target load references the Rd only when Dav is '1'.
--|--  Empty       FIFO Empty signal. If at logic '1' Read pointers don't move 
--|--              even if RE is '1'.
--+----------------------------------------------------------------------
-------------------------------------------------------------------------

Library IEEE;
Use     IEEE.STD_Logic_1164.all; -- Reference the Std_logic_1164 system
Use     IEEE.STD_Logic_unsigned.all; 

ENTITY FIFO_core_wc IS
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
END FIFO_core_wc;    

ARCHITECTURE behave OF FIFO_core_wc IS
    SIGNAL  Fifo_Full, Fifo_Empty : std_logic;
    SIGNAL  Wp, Rp 	: INTEGER RANGE 2**Log2_of_Depth-1 downto 0 := 0;
    SIGNAL	wc_in	: STD_LOGIC_VECTOR (Log2_of_Depth-1 downto 0);

    type dpram_type is ARRAY ( 2**Log2_of_Depth-1 downto 0) of 
                        STD_LOGIC_VECTOR(Data_Width-1 downto 0);
                        
    --SHARED VARIABLE dpram : dpram_type; 
    signal dpram : dpram_type;                   
    attribute ram_style : string;

	--attribute ram_style of dpram : signal is "block";                  
                        
    
BEGIN
    Full <= FiFO_Full;
    Empty <= FIFO_Empty;

    ram_array : PROCESS (c)
    BEGIN
        IF rising_edge(c) THEN
            IF WE='1' THEN
                dpram(Wp) <= Wd;
            END IF;
            Rd <= dpram(Rp);
        END IF;
    END PROCESS ram_array;    

--     word_count : PROCESS (c,r)
-- 	variable selector : std_logic_vector (3 downto 0);
--     BEGIN
--         IF (r = '0') THEN
--             Wc_in <= (others => '0');
--         ELSIF rising_edge(c) THEN
-- 			selector:=Fifo_Full & Fifo_Empty & WE & RE;
-- 			case std_logic_vector'(Fifo_Full,Fifo_Empty,WE,RE) is
-- 				when "0010"|"0110"|"0111" => Wc_in<=Wc_in+'1';
-- 				when "0001"|"1001"|"1011" => Wc_in<=Wc_in-'1';
-- 				when "1100"|"1101"|"1110"|"1111" => Wc_in<=(others => '-');
-- 				when others => null;
-- 			end case;
-- 		END IF;
--     END PROCESS ;    

--     Read_pointer : PROCESS (c,r)
--     BEGIN
--         IF (r = '0') THEN
--             Rp <= 0;
--             Dav <= '0';
--         ELSIF rising_edge(c) THEN
--             IF (Fifo_Empty='0' and RE = '1') then 
--                 Rp <= (Rp + 1) mod 2**Log2_of_Depth;
--                 Dav <= '1';
--             ELSE
--                 Dav <= '0';
--             END IF;
--         END IF;
--     END PROCESS ;


    word_count : PROCESS (c)
	variable selector : std_logic_vector (3 downto 0);
    BEGIN
    	IF rising_edge(c) THEN
	        IF (r = '0') THEN
	            Wc_in <= (others => '0');
	        ELSE
				selector:=Fifo_Full & Fifo_Empty & WE & RE;
				case std_logic_vector'(Fifo_Full,Fifo_Empty,WE,RE) is
					when "0010"|"0110"|"0111" => Wc_in<=Wc_in+'1';
					when "0001"|"1001"|"1011" => Wc_in<=Wc_in-'1';
					when "1100"|"1101"|"1110"|"1111" => Wc_in<=(others => '-');
					when others => null;
				end case;
			END IF;
		END IF;
    END PROCESS ;    
    
    
    
    
    Read_pointer : PROCESS (c)
    BEGIN
    	IF rising_edge(c) THEN
	        IF (r = '0') THEN
	            Rp <= 0;
	            Dav <= '0';
	        ELSE
	            IF (Fifo_Empty='0' and RE = '1') then 
	                Rp <= (Rp + 1) mod 2**Log2_of_Depth;
	                Dav <= '1';
	            ELSE
	                Dav <= '0';
	            END IF;
	        END IF;
        END IF;
    END PROCESS ;
    
    
    
    wc<=Wc_in;
	wp<=(rp + CONV_INTEGER(wc_in)) mod 2**Log2_of_Depth;
    FIFO_Full  <= '1' WHEN (Wc_in=(2**Log2_of_Depth-1)) ELSE '0';
    FIFO_Empty <= '1' WHEN (Wc_in=0) ELSE '0';

END behave;    