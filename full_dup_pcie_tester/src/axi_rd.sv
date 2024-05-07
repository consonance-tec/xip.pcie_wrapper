
`timescale 1ns / 1ps

module axi_rd #
(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    //len 
    parameter LEN_WIDTH = 20
)
(
    input  wire                       clk,
    input  wire                       rst,

    output wire [AXI_ID_WIDTH-1:0]    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]                 m_axi_arlen,
    output wire [2:0]                 m_axi_arsize,
    output wire [1:0]                 m_axi_arburst,
    output wire                       m_axi_arlock,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready,
    
    input wire 						  req,
    output wire                        req_ready,
    input wire [LEN_WIDTH-1:0]	  	  burst_len,
    input wire [AXI_ADDR_WIDTH-1:0]	  addr,
    output reg 						  data_valid,
    output reg [AXI_DATA_WIDTH-1:0]   data
    
    
);

	parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
    
	typedef enum {RD_IDLE, RD_DATA} READ_STATE;
	READ_STATE	rd_sm;
	
	reg [AXI_ADDR_WIDTH-1:0] axi_araddr_int;	
	reg axi_arvalid_int;	
	reg [AXI_ADDR_WIDTH-1:0] axi_arlen_int;
	
	assign m_axi_arlock 	= 1'b0;
	assign m_axi_arcache 	= 4'b0011;
	assign m_axi_arprot 	= 3'b010;
	assign m_axi_arlen		= (burst_len - 1) >> AXI_BURST_SIZE; //axi_arlen_int;
	assign m_axi_arburst	= 2'b01;
	assign m_axi_arsize		= AXI_BURST_SIZE;
	assign m_axi_arid 		= {AXI_ID_WIDTH{1'b0}};
	assign m_axi_araddr		= addr; //axi_araddr_int;
	assign m_axi_arvalid	= axi_arvalid_int;  //m_axi_arready && req; 
	assign m_axi_rready    	= 1'b1;

	assign req_ready 		= m_axi_arready;

always @(posedge clk) begin
	if (rst == 1'b1) 
	begin
	    axi_araddr_int	<= {AXI_ADDR_WIDTH{1'b0}};
	    axi_arvalid_int	<= 1'b0;
	    data_valid 		<= 1'b0;
	    rd_sm <= RD_IDLE;
		//req_done <= 1'b0;	
	    data <= {AXI_DATA_WIDTH{1'b0}};
	    		
	end	
	else
	begin
	
		//req_done <= 1'b0;
		data_valid <= 1'b0;
		
		case(rd_sm)
			RD_IDLE:  
			begin
				axi_araddr_int 	<= {AXI_ADDR_WIDTH{1'b0}};
			    axi_arvalid_int	<= 1'b0;
			    
			    //if(req && !req_done)
			    if(req)
			    begin
					axi_araddr_int 	<= addr;
					axi_arlen_int 	<= (burst_len - 1) >> AXI_BURST_SIZE;
			    	axi_arvalid_int	<= 1'b1;
			    	rd_sm <= RD_DATA;
			    end
			end     
			RD_DATA:
			begin
				if(m_axi_arready)
					axi_arvalid_int	<= 1'b0;
				
						 
				if(m_axi_rvalid)
				begin
					data <= m_axi_rdata;
					data_valid <= 1'b1;	
				end
				
				if(m_axi_rvalid && m_axi_rlast)
				begin
					//req_done <= 1'b1;
					rd_sm <= RD_IDLE;
				end 				
			end	
			default:
				rd_sm <= RD_IDLE;	
			    
		endcase		
	
	end 
end
	

endmodule
