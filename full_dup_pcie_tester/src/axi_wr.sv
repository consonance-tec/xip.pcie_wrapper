
`timescale 1ns / 1ps

module axi_wr #
(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8
)
(
    input  wire                       clk,
    input  wire                       rst,


    output wire [AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,
    
    input wire 						  req,
    output reg                        done,
    input wire [AXI_ADDR_WIDTH-1:0]	  addr,
    input wire [AXI_DATA_WIDTH-1:0]   data
    
);

	parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
    
	typedef enum {WR_IDLE, WR_DATA, WR_WAIT_FOR_AWREADY} WRITE_STATE;
	WRITE_STATE	wr_sm;
	
    (* keep = "true" *)  reg [AXI_ADDR_WIDTH-1:0]  		axi_awaddr_int;
    (* keep = "true" *)  reg                       		axi_awvalid_int;
    (* keep = "true" *)  reg [AXI_DATA_WIDTH-1:0]  		axi_wdata_int;
    (* keep = "true" *)  reg                       		axi_wvalid_int;
    reg						  	done_int;
	reg 						addr_done;
	reg 						data_done;
    

    wire ready_int;
    
	wire  	[AXI_DATA_WIDTH+AXI_ADDR_WIDTH-1:0] wr_req_Rd;
	wire 	[AXI_DATA_WIDTH+AXI_ADDR_WIDTH-1:0] wr_req_Wd;
	reg 	wr_req_RE;
	wire 	wr_req_Dav;
	wire	wr_req_Empty;
	reg 	axi_busy;
    
    
        
    assign m_axi_awlen	= 1'b0;
	assign m_axi_awid = {AXI_ID_WIDTH{1'b0}};
    assign m_axi_bready = 1'b1;
	assign m_axi_wstrb  = {AXI_STRB_WIDTH{1'b1}};
	assign m_axi_wlast  = 1'b1;
	assign m_axi_awsize = AXI_BURST_SIZE;
	assign m_axi_awburst = 2'b01;
	assign m_axi_awlock = 1'b0;
	assign m_axi_awcache = 4'b0011;
	assign m_axi_awprot = 3'b010;
	
	

//	assign m_axi_awaddr  = addr; 		//axi_awaddr_int;
//  assign m_axi_awvalid = ready_int; 	//axi_awvalid_int;
//  assign m_axi_wdata   = data; 		//axi_wdata_int;
//  assign m_axi_wvalid  = ready_int; 	//axi_wvalid_int;
//	assign done = m_axi_awready && m_axi_wready;                //  done_int; //

//	assign ready_int = req && m_axi_awready && m_axi_wready;    
    
reg m_axi_wready_d;	
	
	assign m_axi_awaddr  = axi_awaddr_int;
    assign m_axi_awvalid = axi_awvalid_int;
    assign m_axi_wdata   = axi_wdata_int;
    assign m_axi_wvalid  = axi_wvalid_int;
	assign done = m_axi_wready && !m_axi_wready_d;  



always @(posedge clk) 
	m_axi_wready_d <= m_axi_wready;
	

always @(posedge clk) begin
	if (rst == 1'b1) 
	begin
		axi_awaddr_int 	<= {AXI_ADDR_WIDTH{1'b0}};
	    axi_awaddr_int	<= {AXI_ADDR_WIDTH{1'b0}};
	    axi_awvalid_int	<= 1'b0;
	    axi_wdata_int	<= {AXI_DATA_WIDTH{1'b0}};
	    axi_wvalid_int	<= 1'b0;
	    done_int  <= 1'b0;
		addr_done <= 1'b0;
		data_done <= 1'b0;
	    
	end	
	else
	begin
	
		done_int <= 1'b0;
		if(data_done && addr_done)
		begin
			done_int <= 1'b1;
			addr_done <= 1'b0;
			data_done <= 1'b0;
		end
				
		if(wr_req_Dav)
		begin
			axi_awvalid_int <= 1'b1;
			axi_awaddr_int 	<= wr_req_Rd[AXI_DATA_WIDTH+AXI_ADDR_WIDTH-1:AXI_DATA_WIDTH];
		end
		
		if(axi_awvalid_int && m_axi_awready)
		begin
			axi_awvalid_int <= 1'b0;
			addr_done <= 1'b1;
		end	
			
		if(wr_req_Dav)
		begin
			axi_wvalid_int	<= 1'b1;
			axi_wdata_int	<= wr_req_Rd[AXI_DATA_WIDTH-1:0];
		end		
		
		if(axi_wvalid_int && m_axi_wready)
		begin
			axi_wvalid_int 	<= 1'b0;
			data_done 		<= 1'b1;	
		end
	
	end 
end






always @(posedge clk) begin
	if (rst == 1'b1) 
	begin
		wr_req_RE <= 1'b0;
		axi_busy <= 1'b0;
	end	
	else
	begin
		wr_req_RE <= 1'b0;
		
		if(!(axi_busy || wr_req_Empty)) //not empty and axi is not busy
		begin
			wr_req_RE <= 1'b1;
			axi_busy <= 1'b1;
		end
		
		if(done)
			axi_busy <= 1'b0;

	end 
end

 
assign wr_req_Wd = {addr,data};

FIFO_core_wc #   
(
	.Data_Width 	(AXI_DATA_WIDTH+AXI_ADDR_WIDTH),
	.Log2_of_Depth (5)
)
wr_req_fifo
(
	.C	(clk),
    .R  (~rst),
    //--Write side
    .wc		(),
    .Wd     (wr_req_Wd),
    .WE     (req),
    .Full   (),
   	//--read side
	.Rd      (wr_req_Rd),
	.RE      (wr_req_RE),
	.Dav     (wr_req_Dav),
	.Empty   (wr_req_Empty)
); 	


endmodule
