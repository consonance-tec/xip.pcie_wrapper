
Library IEEE;
Use     IEEE.STD_Logic_1164.all; -- Reference the Std_logic_1164 system
Use     IEEE.STD_Logic_unsigned.all; 
use ieee.std_logic_arith.all;


ENTITY tag_allocator IS
    GENERIC(
        Log2_of_Depth : integer := 8;
        PCIE_CORE_DATA_WIDTH 	: integer := 128
        );
    PORT (
        C, 
        R       				: STD_LOGIC ;
        
        tag      				: OUT STD_LOGIC_VECTOR(7 downto 0);
        get      				: in STD_LOGIC ;
        tag_valid     				: out STD_LOGIC;
        
        in_context				: in std_logic_vector(31 downto 0);
        out_context 			: out std_logic_vector(31 downto 0);

        complD_transfer_done	: out std_logic;
        
        complD 					: in std_logic;
		complD_Last				: in std_logic;	
		complD_First			: in std_logic;
		complD_Data				: in std_logic_vector(PCIE_CORE_DATA_WIDTH-1 downto 0);
		complD_Lenght 			: in std_logic_vector(9 downto 0);
		complD_Attr 			: in std_logic_vector(2 downto 0);
		complD_EP 				: in std_logic;
		complD_TD 				: in std_logic;
		complD_TC  				: in std_logic_vector(2 downto 0);
		complD_ByteCount  		: in std_logic_vector(11 downto 0);
		complD_BCM   			: in std_logic;
		complD_CoplStat  		: in std_logic_vector(2 downto 0);
		complD_CompleterID  	: in std_logic_vector(15 downto 0);
		complD_LowerAddress  	: in std_logic_vector(6 downto 0);
		complD_Tag  			: in std_logic_vector(7 downto 0);
		complD_RequestorID 		: in std_logic_vector(15 downto 0)
         
    );    
END tag_allocator;    

ARCHITECTURE behave OF tag_allocator IS
    SIGNAL  Fifo_Full, Fifo_Empty : std_logic;
    SIGNAL  Wp, Rp 	: INTEGER RANGE 2**Log2_of_Depth-1 downto 0;
    SIGNAL	wc_in	: STD_LOGIC_VECTOR (Log2_of_Depth-1 downto 0);
	signal RE      : STD_LOGIC ;
	signal get_d : std_logic;
    type dpram_type is ARRAY ( 2**Log2_of_Depth-1 downto 0) of 
                        STD_LOGIC_VECTOR(7 downto 0);
      
    signal Rd_int  : STD_LOGIC_VECTOR(7 downto 0);  
    signal Dav_int : STD_LOGIC; 
    signal tag_int : STD_LOGIC_VECTOR(7 downto 0);  
                                      
    --SHARED VARIABLE dpram : dpram_type; 
    signal dpram : dpram_type;                   
    --attribute ram_style : string;

	--attribute ram_style of dpram : signal is "block";                  
    
    signal Wd      				: STD_LOGIC_VECTOR(7 downto 0);
    signal We      				: STD_LOGIC ;
	
	signal Lenght_in_bytes : std_logic_vector(11 downto 0);
	signal is_last_burst_in_mrdreq : std_logic;

	signal tag_valid_int : std_logic;
	signal temp    : std_logic;
	signal Wc_in_d : std_logic_vector(Log2_of_Depth-1 downto 0);
    signal Wc_in_not_4_cnt : std_logic_vector(31 downto 0);
   	attribute noprune: boolean;
	attribute noprune 	of Wc_in_not_4_cnt	: signal is true;
	
	
		
	component simple_dpr_infferd IS
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
	end component; 	
	                    
    
BEGIN
    
    ram_array : PROCESS (c)
    BEGIN
        IF rising_edge(c) THEN
        	IF (r = '0') THEN
        		for i in 0 to 2**Log2_of_Depth-1 loop
        			dpram(i) <= conv_std_logic_vector(i,8);
        		end loop;
        		Rd_int <= (others => '0');
        	ELSE
            	IF WE='1' THEN
                	dpram(Wp) <= Wd;
            	END IF;
            	Rd_int <= dpram(Rp);
            	tag_int <= Rd_int;
            END IF;
        END IF;
    END PROCESS ram_array;    

    word_count : PROCESS (c,r)
	variable selector : std_logic_vector (3 downto 0);
    BEGIN
        IF (r = '0') THEN
            --Wc_in <= (others => '0');
            Wc_in <= conv_std_logic_vector((2**Log2_of_Depth-1), Log2_of_Depth );
        ELSIF rising_edge(c) THEN
			selector:=Fifo_Full & Fifo_Empty & WE & RE;
			case std_logic_vector'(Fifo_Full,Fifo_Empty,WE,RE) is
				when "0010"|"0110"|"0111" => Wc_in<=Wc_in+'1';
				when "0001"|"1001"|"1011" => Wc_in<=Wc_in-'1';
				when "1100"|"1101"|"1110"|"1111" => Wc_in<=(others => '-');
				when others => null;
			end case;
		END IF;
    END PROCESS ;    

    
    
    Read_pointer : PROCESS (c,r)
    BEGIN
        IF (r = '0') THEN
            Rp <= 0;
            Dav_int <= '0';
            re <= '0';	
            get_d <= '0';
        ELSIF rising_edge(c) THEN
            IF (Fifo_Empty='0' and RE = '1') then 
                Rp <= (Rp + 1) mod 2**Log2_of_Depth;
                Dav_int <= '1';
                re <= '0';
            ELSE
                Dav_int <= '0';
            END IF;
            
            get_d <= get;
            if get = '1' and get_d = '0' then
        		re <= '1';
        	elsif get = '0' then
        		re <= '0';	
        	end if;
        		
        		
        END IF;
    END PROCESS ;
    
	wp<=(rp + CONV_INTEGER(wc_in)) mod 2**Log2_of_Depth;
    FIFO_Full  <= '1' WHEN (Wc_in=(2**Log2_of_Depth-1)) ELSE '0';
    FIFO_Empty <= '1' WHEN (Wc_in=0) ELSE '0';
    
    
    
    
	context_ram : simple_dpr_infferd
	generic map(
			C_RAM_WIDTH =>  32,		-- Specify RAM data width
			MEM_ADDR_SIZE => Log2_of_Depth,
			C_RAM_PERFORMANCE => "HIGH_PERFORMANCE"	-- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
	)
    port map 
    (
		C  		=> c,

		WAdd 	=> tag_int(Log2_of_Depth-1 downto 0), -- the address is the tag that we read out of the tag fifo
		Wd  	=> in_context,
		WE   	=> tag_valid_int, --Dav_int,
		Ena   	=> '1',
		
		RAdd 	=> complD_Tag(Log2_of_Depth-1 downto 0), -- the read address is the tag we return back 
		Rd 		=> out_context,
		REna	=> '1'
    ); 
    
    is_last_burst_in_mrdreq <= '0' when	complD_ByteCount = 0 or Lenght_in_bytes < complD_ByteCount  else '1';
    
    Lenght_in_bytes <= complD_Lenght & "00";
    tag_write_back : PROCESS (c,r)
    BEGIN
        IF (r = '0') THEN
		    Wd  <= (others => '0');
		    WE  <= '0';
		    complD_transfer_done <= '0'; 
        ELSIF rising_edge(c) THEN
		    Wd  <= (others => '0');
		    WE  <= '0';
		    complD_transfer_done <= '0'; 
        	if complD = '1' and complD_Last = '1' and  is_last_burst_in_mrdreq = '1' then
        		Wd  <= complD_Tag;
		    	WE  <= '1';	
		    	
		    	complD_transfer_done <= '1';        
        	end if;	
        		
        END IF;
    END PROCESS ;

    
    
    PROCESS (c,r)
    BEGIN
        IF (r = '0') THEN
			Wc_in_not_4_cnt <= x"00000000";
			Wc_in_d <= Wc_in;
			temp <= '0';
        ELSIF rising_edge(c) THEN
        	Wc_in_d <= Wc_in;
        	temp <= '0';
		    if Wc_in_d /= Wc_in and Wc_in /= "100" then
		    	Wc_in_not_4_cnt <= Wc_in_not_4_cnt+1;
		    elsif  Wc_in_d /= Wc_in then
		    	Wc_in_not_4_cnt <= x"00000000";
		    	temp <= '1';
		    end if;
        END IF;
    END PROCESS ;
    
    
     
    PROCESS (c)
    BEGIN
        if rising_edge(c) THEN
        	tag_valid_int <= Dav_int;		
        END IF;
    END PROCESS ;
       
    
    tag <= tag_int;
	tag_valid <= tag_valid_int;    
	
END behave;    