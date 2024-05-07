
`timescale 1ns / 1ps

module axi_if #
(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    
    parameter LEN_WIDTH = 20
    
)
(
    input  wire                       m_axi_clk,
    input  wire                       m_axi_rstn,

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
    
    input wire 						  rd_req,
    output wire                       rd_req_ready,
    input wire [LEN_WIDTH-1:0]	  	  rd_burst_len,
    input wire [AXI_ADDR_WIDTH-1:0]	  rd_addr,
    output wire 						  rd_data_valid,
    output wire [AXI_DATA_WIDTH-1:0]   rd_data,
    
    input wire 						  wr_req,
    output wire                       wr_done,
    input wire [AXI_ADDR_WIDTH-1:0]	  wr_addr,
    input wire [AXI_DATA_WIDTH-1:0]   wr_data
    
);


axi_wr #
(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH (AXI_STRB_WIDTH),
    .AXI_ID_WIDTH 	(AXI_ID_WIDTH)
)
axi_wr_i
(
    .clk	(m_axi_clk),
    .rst	(~m_axi_rstn),


    .m_axi_awid		(m_axi_awid),
    .m_axi_awaddr	(m_axi_awaddr),
    .m_axi_awlen	(m_axi_awlen),
    .m_axi_awsize	(m_axi_awsize),
    .m_axi_awburst	(m_axi_awburst),
    .m_axi_awlock	(m_axi_awlock),
    .m_axi_awcache	(m_axi_awcache),
    .m_axi_awprot	(m_axi_awprot),
    .m_axi_awvalid	(m_axi_awvalid),
    .m_axi_awready	(m_axi_awready),
    .m_axi_wdata	(m_axi_wdata),
    .m_axi_wstrb	(m_axi_wstrb),
    .m_axi_wlast	(m_axi_wlast),
    .m_axi_wvalid	(m_axi_wvalid),
    .m_axi_wready	(m_axi_wready),
    .m_axi_bid		(m_axi_bid),
    .m_axi_bresp	(m_axi_bresp),
    .m_axi_bvalid	(m_axi_bvalid),
    .m_axi_bready	(m_axi_bready),
    
    .req			(wr_req),
    .done			(wr_done),
    .addr			(wr_addr),
    .data   		(wr_data)
    
);

axi_rd #
(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH (AXI_STRB_WIDTH),
    .AXI_ID_WIDTH 	(AXI_ID_WIDTH),
    .LEN_WIDTH 		(LEN_WIDTH)
)
axi_rd_i
(
    .clk	(m_axi_clk),
    .rst	(~m_axi_rstn),

    .m_axi_arid		(m_axi_arid),
    .m_axi_araddr	(m_axi_araddr),
    .m_axi_arlen	(m_axi_arlen),
    .m_axi_arsize	(m_axi_arsize),
    .m_axi_arburst	(m_axi_arburst),
    .m_axi_arlock	(m_axi_arlock),
    .m_axi_arcache	(m_axi_arcache),
    .m_axi_arprot	(m_axi_arprot),
    .m_axi_arvalid	(m_axi_arvalid),
    .m_axi_arready	(m_axi_arready),
    .m_axi_rid		(m_axi_rid),
    .m_axi_rdata	(m_axi_rdata),
    .m_axi_rresp	(m_axi_rresp),
    .m_axi_rlast	(m_axi_rlast),
    .m_axi_rvalid	(m_axi_rvalid),
    .m_axi_rready	(m_axi_rready),
    
    .req			(rd_req),
    .req_ready		(rd_req_ready),
    .burst_len		(rd_burst_len),
    .addr			(rd_addr),
    .data_valid		(rd_data_valid),
    .data       	(rd_data)
    
);


endmodule
