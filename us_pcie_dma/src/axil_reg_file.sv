
                                                                            
`timescale 1ps / 1ps                                                           
//        

                                                                      
module	axi_reg_file #(                                                              
		parameter	C_AXI_ADDR_WIDTH = 8,                                               
		parameter	C_AXI_DATA_WIDTH = 32,
		parameter 	ADDR_VADID_BITS = 20,
		parameter   NUM_OF_REGISTERS = 4

	) (                                                                            

		input	wire					S_AXI_ACLK,                                                    
		input	wire					S_AXI_ARESETN,                                                 
		//                                                                            
		input	wire					S_AXI_AWVALID,                                                 
		output	wire					S_AXI_AWREADY,                                                
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_AWADDR,                              
		input	wire	[2:0]				S_AXI_AWPROT,                                             
		//                                                                            
		input	wire					S_AXI_WVALID,                                                  
		output	wire					S_AXI_WREADY,                                                 
		input	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_WDATA,                               
		input	wire	[C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,                              
		//                                                                            
		output	wire					S_AXI_BVALID,                                                 
		input	wire					S_AXI_BREADY,                                                  
		output	wire	[1:0]				S_AXI_BRESP,                                             
		//                                                                            
		input	wire					S_AXI_ARVALID,                                                 
		output	wire					S_AXI_ARREADY,                                                
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_ARADDR,                              
		input	wire	[2:0]				S_AXI_ARPROT,                                             
		//                                                                            
		output	wire					S_AXI_RVALID,                                                 
		input	wire					S_AXI_RREADY,                                                  
		output	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_RDATA,                              
		output	wire	[1:0]				S_AXI_RRESP,
		
		
		output	reg [31:0] reg_val,
		output	reg [7:0] reg_index,
		output  reg reg_valid,
		
		input	wire [NUM_OF_REGISTERS-1:0] [31:0] read_reg_array
                                              
		// }}}                                                                        
	);                                                                             
                                                                                
	////////////////////////////////////////////////////////////////////////       
	//                                                                             
	// Register/wire signal declarations                                           
	// {{{                                                                         
	////////////////////////////////////////////////////////////////////////       
	//                                                                             
	localparam	ADDRLSB = $clog2(C_AXI_DATA_WIDTH)-3;                               
                                                                                
	wire	i_reset = !S_AXI_ARESETN;                                                 
                                                                                
	wire				axil_write_ready;                                                      
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	awskd_addr;                                
	//                                                                             
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_data;                                         
	wire [C_AXI_DATA_WIDTH/8-1:0]	wskd_strb;                                       
	reg				axil_bvalid;                                                            
	//                                                                             
	wire				axil_read_ready;                                                       
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	arskd_addr;                                
	reg	[C_AXI_DATA_WIDTH-1:0]	axil_read_data;                                     
	reg				axil_read_valid;                                                        
                                                                                
	
	
	wire [NUM_OF_REGISTERS-1:0] [31:0] wskd_reg_array;
	
	
	localparam INVALID_BITS = C_AXI_DATA_WIDTH-ADDR_VADID_BITS;
	wire [C_AXI_DATA_WIDTH-1:0] ADDR_MASK = {{INVALID_BITS{1'b0}} , {ADDR_VADID_BITS{1'b1}}};
    
	wire [C_AXI_DATA_WIDTH-1:0]	VALID_ADDR;
	assign VALID_ADDR = S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:0] & ADDR_MASK;  
	
	                             
	// }}}                                                                         
	////////////////////////////////////////////////////////////////////////       
	//                                                                             
	// AXI-lite signaling                                                          
	//                                                                             
	////////////////////////////////////////////////////////////////////////       
	//                                                                             
	// {{{                                                                         
                                                                                
	//                                                                             
	// Write signaling                                                             
	//                                                                             
	// {{{                                                                         
                                                                                
                                                
		// {{{                                                                        
		reg	axil_awready;                                                             
                                                                                
		initial	axil_awready = 1'b0;                                                  
		always @(posedge S_AXI_ACLK)                                                  
		if (!S_AXI_ARESETN)                                                           
			axil_awready <= 1'b0;                                                        
		else                                                                          
			axil_awready <= !axil_awready                                                
				&& (S_AXI_AWVALID && S_AXI_WVALID)                                          
				&& (!S_AXI_BVALID || S_AXI_BREADY);                                         
                                                                                
		assign	S_AXI_AWREADY = axil_awready;                                          
		assign	S_AXI_WREADY  = axil_awready;                                          
                                                                                
		assign 	awskd_addr = VALID_ADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];                
		assign	wskd_data  = S_AXI_WDATA;                                              
		assign	wskd_strb  = S_AXI_WSTRB;                                              
                                                                                
		assign	axil_write_ready = axil_awready;                                       
		// }}}                                                                        
	                                                              
                                                                                
	initial	axil_bvalid = 0;                                                       
	always @(posedge S_AXI_ACLK)                                                   
	if (i_reset)                                                                   
		axil_bvalid <= 0;                                                             
	else if (axil_write_ready)                                                     
		axil_bvalid <= 1;                                                             
	else if (S_AXI_BREADY)                                                         
		axil_bvalid <= 0;                                                             
                                                                                
	assign	S_AXI_BVALID = axil_bvalid;                                             
	assign	S_AXI_BRESP = 2'b00;                                                    
	// }}}                                                                         
                                                                                
	//                                                                             
	// Read signaling                                                              
	//                                                                             
	// {{{                                                                         
                                                                                
		// {{{                                                                        
		reg	axil_arready;                                                             
                                                                                
		always @(*)                                                                   
			axil_arready = !S_AXI_RVALID;                                                
                                                                                
		assign	arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];                 
		assign	S_AXI_ARREADY = axil_arready;                                          
		assign	axil_read_ready = (S_AXI_ARVALID && S_AXI_ARREADY);                    
		// }}}                                                                        
                                                              
                                                                                
	initial	axil_read_valid = 1'b0;                                                
	always @(posedge S_AXI_ACLK)                                                   
	if (i_reset)                                                                   
		axil_read_valid <= 1'b0;                                                      
	else if (axil_read_ready)                                                      
		axil_read_valid <= 1'b1;                                                      
	else if (S_AXI_RREADY)                                                         
		axil_read_valid <= 1'b0;                                                      
                                                                                
	assign	S_AXI_RVALID = axil_read_valid;                                         
	assign	S_AXI_RDATA  = axil_read_data;                                          
	assign	S_AXI_RRESP = 2'b00;                                                    
	// }}}                                                                         
                                                                                
	// }}}                                                                         
	////////////////////////////////////////////////////////////////////////       
	//                                                                             
	// AXI-lite register logic                                                     
	//                                                                             
	////////////////////////////////////////////////////////////////////////       
	//                                                                             
	// {{{                                                                         
                                                                                
	
		
		
	genvar reg_i;
  	for (reg_i=0; reg_i < NUM_OF_REGISTERS; reg_i=reg_i+1) begin : gen
    	assign wskd_reg_array[reg_i] = apply_wstrb(0, wskd_data, wskd_strb);
  	end
	
		
	integer i;
	always @(posedge S_AXI_ACLK)                                                   
	if (i_reset)                                                                   
	begin                                                                          
	
	 	reg_val <= 0;	 
		reg_index <= 0;
		reg_valid <= 1'b0;                                                                     
	end else if (axil_write_ready)                                                 
	begin  
		
		 for(i=0; i<NUM_OF_REGISTERS; i=i+1)
		 begin
			if(awskd_addr == i)
	         	reg_val <= wskd_reg_array[i]; 
			if(awskd_addr == i)
				reg_index <= i;
			if(awskd_addr == i)
				reg_valid <= 1'b1;
		end
	end 
	else
	begin
	  	reg_val <= 0;	 
	 	reg_index <= 0;
	 	reg_valid <= 1'b0;
	end                                                                            
                                                                                
	initial	axil_read_data = 0;                                                    
	always @(posedge S_AXI_ACLK)                                                   
	if (!S_AXI_RVALID || S_AXI_RREADY)                                        
	begin  
		 for(i=0; i<NUM_OF_REGISTERS; i=i+1)
			if(arskd_addr == i)
				axil_read_data	<= read_reg_array[i];
			                                                                        
                                                                               
	end                                                                            
                                                                                
	function [C_AXI_DATA_WIDTH-1:0]	apply_wstrb;                                   
		input	[C_AXI_DATA_WIDTH-1:0]		prior_data;                                     
		input	[C_AXI_DATA_WIDTH-1:0]		new_data;                                       
		input	[C_AXI_DATA_WIDTH/8-1:0]	wstrb;                                         
                                                                                
		integer	k;                                                                    
		for(k=0; k<C_AXI_DATA_WIDTH/8; k=k+1)                                         
		begin                                                                         
			apply_wstrb[k*8 +: 8]                                                        
				= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];                     
		end                                                                           
	endfunction                                                                    
	// }}}                                                                         
                                                                                
	// Make Verilator happy                                                        
	// {{{                                                                         
	// Verilator lint_off UNUSED                                                   
	wire	unused;                                                                   
	assign	unused = &{ 1'b0, S_AXI_AWPROT, S_AXI_ARPROT,                           
			S_AXI_ARADDR[ADDRLSB-1:0],                                                   
			S_AXI_AWADDR[ADDRLSB-1:0] };                                                 
	// Verilator lint_on  UNUSED                                                   
	// }}}                                                                         

endmodule                                                                       
                                                            