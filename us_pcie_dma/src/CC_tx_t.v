//-----------------------------------------------------------------------------
//
// (c) Copyright 2001-2014 Consonance, LTD. All rights reserved.
//
//
//-----------------------------------------------------------------------------
// Project    PCIe DMA Egnine: 
// File       pcie_dma_engine: 
// Version    1.0: 
//
// Description:  
//
//----------------------------------------------------------------------------
`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module cc_tx_t    #(

  parameter 		C_DATA_WIDTH = 256,	
  parameter        TCQ = 1,
  parameter       AXISTEN_IF_CC_ALIGNMENT_MODE = "FALSE",
  parameter       AXISTEN_IF_CC_PARITY_CHECK   = 0,
  parameter        MAPPED_ADDR_WIDTH = 13,
  //Do not modify the parameters below this line
  parameter PARITY_WIDTH = C_DATA_WIDTH /8,
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32,
  parameter STRB_WIDTH   = C_DATA_WIDTH / 8
)(

  input                          user_clk,
  input                          reset_n,

  // AXI-S Completer Competion Interface

  output reg [C_DATA_WIDTH-1:0]  s_axis_cc_tdata,
  output reg   [KEEP_WIDTH-1:0]  s_axis_cc_tkeep,
  output reg                     s_axis_cc_tlast,
  output reg                     s_axis_cc_tvalid,
  output reg             [32:0]  s_axis_cc_tuser,
  input                          s_axis_cc_tready,


  // PIO RX Engine Interface

  input                          req_compl,
  input                   [5:0]  req_compl_wd,
  input                          req_compl_ur,
  input                          payload_len,
  output reg                     compl_done,

  input                   [2:0]  req_tc,
  input                          req_td,
  input                          req_ep,
  input                   [1:0]  req_attr,
  input                  [10:0]  req_len,
  input                  [15:0]  req_rid,
  input                   [7:0]  req_tag,
  input                   [7:0]  req_be,
  input                  [MAPPED_ADDR_WIDTH-1:0]  req_addr,
  input                   [1:0]  req_at,

  // Inputs to the TX Block in case of an UR
  // Required to form the completions

  input                  [63:0]  req_des_qword0,
  input                  [63:0]  req_des_qword1,
  input                          req_des_tph_present,
  input                   [1:0]  req_des_tph_type,
  input                   [7:0]  req_des_tph_st_tag,

  //Indicate that the Request was a Mem lock Read Req

  input                          req_mem_lock,
  input                          req_mem,

  // PIO Memory Access Control Interface

  output reg             [10:0]  rd_addr,
  output reg              [3:0]  rd_be,
  input                  [31:0]  rd_data,
  input 						 rd_valid

);

  localparam PIO_TX_RST_STATE                   = 4'b0000;
  localparam PIO_TX_COMPL_C1                    = 4'b0001;
  localparam PIO_TX_COMPL_C2                    = 4'b0010;
  localparam PIO_TX_COMPL_WD_C1                 = 4'b0011;
  localparam PIO_TX_COMPL_WD_C2                 = 4'b0100;
  localparam PIO_TX_COMPL_PYLD                  = 4'b0101;
  localparam PIO_TX_CPL_UR_C1                   = 4'b0110;
  localparam PIO_TX_CPL_UR_C2                   = 4'b0111;
  localparam PIO_TX_CPL_UR_C3                   = 4'b1000;
  localparam PIO_TX_CPL_UR_C4                   = 4'b1001;
  localparam PIO_TX_MRD_C2                      = 4'b1010;
  localparam PIO_TX_COMPL_WD_2DW                = 4'b1011;
  localparam PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1   = 4'b1100;
  localparam PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C2   = 4'b1101;

  // Local registers


  reg  [11:0]              byte_count_fbe;
  reg  [11:0]              byte_count_lbe;
  wire [11:0]              byte_count;
  reg  [06:0]              lower_addr;
  reg  [06:0]              lower_addr_q;
  reg  [06:0]              lower_addr_qq;
  reg  [15:0]              tkeep;
  reg  [15:0]              tkeep_q;
  reg  [15:0]              tkeep_qq;

  reg                      req_compl_q;
  reg                      req_compl_qq;
  reg  		               req_compl_wd_q;
  reg                      req_compl_wd_qq;
  reg                      req_compl_wd_qqq;
  reg                      req_compl_ur_q;
  reg                      req_compl_ur_qq;

  reg  [3:0]               state;

  wire  [31:0]             s_axis_cc_tparity;
  
  reg  [31:0]			   rd_letchd;
  
  reg  [31:0]              rd_data_reg; // To store the 2nd rd_data in case of 2DW payload
  reg  [1:0]               rd_dly_cntr; // Memory output delay counter
  reg                      rd_SM;       // rd_data_reg State Machine
  localparam               rd_IDLE  = 1'b0;
  localparam               rd_DW_HI = 1'b1;



  // Present address and byte enable to memory module
  // and buffer up 2nd DW data in case of 2DW Memory Read

  always @ (posedge user_clk)begin

     if (!reset_n) begin
        rd_addr          <= #TCQ 11'b0;
        rd_be            <= #TCQ 4'b0;
        rd_SM            <= #TCQ rd_IDLE;
     end
     else begin

        case ( rd_SM )

        rd_IDLE : begin

           rd_dly_cntr    <= #TCQ 2'b0;
           req_compl_wd_q <= #TCQ 1'b0;

           if (rd_valid)  
           	rd_letchd <= rd_data;
           
           if (rd_valid) begin

              if (payload_len == 0) begin // 1DW Memory Read - Start Completion immediately
                 rd_addr        <= #TCQ req_addr[10:0]; //req_addr[12:2];
                 rd_be          <= #TCQ req_be[3:0];
                 req_compl_wd_q <= #TCQ 1'b1;
              end
              else begin // 2DW Memory Read - Buffer up 2nd DW data
                 rd_addr        <= #TCQ req_addr[10:0] + 11'h001;
                 rd_be          <= #TCQ req_be[7:4];
                 rd_SM          <= #TCQ rd_DW_HI;
              end

           end

        end

        rd_DW_HI : begin

           rd_dly_cntr <= #TCQ rd_dly_cntr + 1;
	   
           // Fetch 1st DW data and can start Completion SM while waiting for returned data
           rd_addr        <= #TCQ req_addr[10:0];
           rd_be          <= #TCQ req_be[3:0];
           if (rd_dly_cntr == 2'b00)
              req_compl_wd_q <= #TCQ 1'b1;    // Start Completion SM
           else
              req_compl_wd_q <= #TCQ 1'b0;    // Assert for 1 clk cycle only

           if (rd_dly_cntr[1] == 1'b1) begin  // Wait for data turnaround delay from memory
              rd_data_reg    <= #TCQ rd_data; // Store 2nd DW
              rd_SM          <= #TCQ rd_IDLE;
           end

        end

        default : begin

              req_compl_wd_q <= #TCQ 1'b0;
              rd_SM          <= #TCQ rd_IDLE;

        end

        endcase

     end

  end

  // Calculate byte count based on byte enable

  always @ (req_be) begin
     
    casex (req_be[3:0])

      4'b1xx1 : byte_count_fbe = 12'h004;
      4'b01x1 : byte_count_fbe = 12'h003;
      4'b1x10 : byte_count_fbe = 12'h003;
      4'b0011 : byte_count_fbe = 12'h002;
      4'b0110 : byte_count_fbe = 12'h002;
      4'b1100 : byte_count_fbe = 12'h002;
      4'b0001 : byte_count_fbe = 12'h001;
      4'b0010 : byte_count_fbe = 12'h001;
      4'b0100 : byte_count_fbe = 12'h001;
      4'b1000 : byte_count_fbe = 12'h001;
      4'b0000 : byte_count_fbe = 12'h001;
      default : byte_count_fbe = 12'h000;
    endcase

    casex (req_be[7:4])

      4'b1xx1 : byte_count_lbe = 12'h004;
      4'b01x1 : byte_count_lbe = 12'h003;
      4'b1x10 : byte_count_lbe = 12'h003;
      4'b0011 : byte_count_lbe = 12'h002;
      4'b0110 : byte_count_lbe = 12'h002;
      4'b1100 : byte_count_lbe = 12'h002;
      4'b0001 : byte_count_lbe = 12'h001;
      4'b0010 : byte_count_lbe = 12'h001;
      4'b0100 : byte_count_lbe = 12'h001;
      4'b1000 : byte_count_lbe = 12'h001;
      4'b0000 : byte_count_lbe = 12'h000;
      default : byte_count_lbe = 12'h000;

    endcase

  end

  // Calculate the byte_count for 1DW or 2DW packets
  assign byte_count = (payload_len == 1)? (byte_count_lbe + byte_count_fbe) : byte_count_fbe;


  // Calculate lower address based on  byte enable

  always @ (req_be or req_addr) begin

    casex (req_be[3:0])
	4'b0000 : lower_addr = {req_addr[6:2], 2'b00};
        4'bxxx1 : lower_addr = {req_addr[6:2], 2'b00};
        4'bxx10 : lower_addr = {req_addr[6:2], 2'b01};
        4'bx100 : lower_addr = {req_addr[6:2], 2'b10};
        4'b1000 : lower_addr = {req_addr[6:2], 2'b11};
	default : lower_addr = 7'h0;
    endcase

  end
  always @  (lower_addr) begin

    casex (lower_addr[4:2])

      3'b000 : tkeep = (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" ) ? 16'h1 :16'h1; 
      3'b001 : tkeep = (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" ) ? 16'h3 :16'h1; 
      3'b010 : tkeep = (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" ) ? 16'h7 :16'h1; 
      3'b011 : tkeep = (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" ) ? 16'hf :16'h1; 
      3'b100 : tkeep = (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" ) ? 16'h1f :16'h1; 
      3'b101 : tkeep = (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" ) ? 16'h3f :16'h1; 
      3'b110 : tkeep = (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" ) ? 16'h7f :16'h1; 
      3'b111 : tkeep = (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" ) ? 16'hff :16'h1; 
    endcase

  end


  always @ (posedge user_clk)
  begin

    if (!reset_n) begin

      req_compl_q     <= #TCQ 1'b0;
      req_compl_qq    <= #TCQ 1'b0;
      req_compl_wd_qq <= #TCQ 1'b0;
      req_compl_wd_qqq <= #TCQ 1'b0;
      tkeep_q         <= #TCQ 16'h0F;
      req_compl_ur_q  <= #TCQ 1'b0;
      req_compl_ur_qq <= #TCQ 1'b0;

    end else begin

      lower_addr_q    <= #TCQ lower_addr;
      tkeep_q         <= #TCQ tkeep;
      tkeep_qq         <= #TCQ tkeep_q;
      lower_addr_qq   <= #TCQ lower_addr_q;
      req_compl_q     <= #TCQ req_compl;
      req_compl_qq    <= #TCQ req_compl_q;
      req_compl_wd_qq <= #TCQ req_compl_wd_q;
      req_compl_wd_qqq <= #TCQ req_compl_wd_qq;
      req_compl_ur_q  <= #TCQ req_compl_ur;
      req_compl_ur_qq <= #TCQ req_compl_ur_q;
    end

  end



  // Logic to compute the Parity of the CC and the RQ channel

  generate
    if(AXISTEN_IF_CC_PARITY_CHECK == 1)
    begin

      genvar a;
      for(a=0; a< STRB_WIDTH; a = a + 1) // Parity needs to be computed for every byte of data
      begin : parity_assign

        assign s_axis_cc_tparity[a] = !(  s_axis_cc_tdata[(8*a)+ 0] ^ s_axis_cc_tdata[(8*a)+ 1]
                                 ^ s_axis_cc_tdata[(8*a)+ 2] ^ s_axis_cc_tdata[(8*a)+ 3]
                                 ^ s_axis_cc_tdata[(8*a)+ 4] ^ s_axis_cc_tdata[(8*a)+ 5]
                                 ^ s_axis_cc_tdata[(8*a)+ 6] ^ s_axis_cc_tdata[(8*a)+ 7]);
      end
    end else begin
      genvar b;
      for(b=0; b< STRB_WIDTH; b = b + 1) // Drive parity low if not enabled
      begin : parity_assign
        assign s_axis_cc_tparity[b] = 32'b0;
      end
    end
  endgenerate



  generate // 256 bit Interface
  if(C_DATA_WIDTH == 256)
  begin

    always @ ( posedge user_clk )
    begin

      if(!reset_n ) begin

        state                   <= #TCQ PIO_TX_RST_STATE;
        s_axis_cc_tdata         <= #TCQ {C_DATA_WIDTH{1'b0}};
        s_axis_cc_tkeep         <= #TCQ {KEEP_WIDTH{1'b0}};
        s_axis_cc_tlast         <= #TCQ 1'b0;
        s_axis_cc_tvalid        <= #TCQ 1'b0;
        s_axis_cc_tuser         <= #TCQ 33'b0;
        compl_done              <= #TCQ 1'b0;
        
      end else begin // reset_else_block

            case (state)

              PIO_TX_RST_STATE : begin  // Reset_State

                state                   <= #TCQ PIO_TX_RST_STATE;
                s_axis_cc_tdata         <= #TCQ {C_DATA_WIDTH{1'b0}};
                s_axis_cc_tkeep         <= #TCQ {KEEP_WIDTH{1'b1}};
                s_axis_cc_tlast         <= #TCQ 1'b0;
                s_axis_cc_tvalid        <= #TCQ 1'b0;
                s_axis_cc_tuser         <= #TCQ 33'b0;
                compl_done              <= #TCQ 1'b0;
                
                if(req_compl) begin
                   state <= #TCQ PIO_TX_COMPL_C1;
                end else if (req_compl_wd != "000000") begin
                   state <= #TCQ PIO_TX_COMPL_WD_C1;
                end else if (req_compl_ur) begin
                   state <= #TCQ PIO_TX_CPL_UR_C1;
                end
              end // PIO_TX_RST_STATE

              PIO_TX_COMPL_C1 : begin // Completion Without Payload - Alignment doesnt matter
                                   // Sent in a Single Beat When Interface Width is 256 bit
                if(req_compl_qq) begin
                  s_axis_cc_tvalid  <= #TCQ 1'b1;
                  s_axis_cc_tlast   <= #TCQ 1'b1;
                  s_axis_cc_tkeep   <= #TCQ 8'h07;
                  s_axis_cc_tdata   <= #TCQ {160'b0,        // Tied to 0 for 3DW completion descriptor
                                             1'b0,          // Force ECRC
                                             1'b0, req_attr,// 3- bits
                                             req_tc,        // 3- bits
                                             1'b0,          // Completer ID to control selection of Client
                                                            // Supplied Bus number
                                             8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                             {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                             req_tag,       // Matching Request Tag
                                             req_rid,       // Requester ID - 16 bits
                                             1'b0,          // Rsvd
                                             1'b0,          // Posioned completion
                                             3'b000,        // SuccessFull completion
                                             (req_mem ? (11'h1 + payload_len) : 11'b0),         // DWord Count 0 - IO Write completions
                                             2'b0,          // Rsvd
                                             1'b0,          // Locked Read Completion
                                             {1'b0, byte_count},                                // Byte Count
                                             6'b0,          // Rsvd
                                             req_at,        // Adress Type - 2 bits
                                             1'b0,          // Rsvd
                                             lower_addr};   // Starting address of the mem byte - 7 bits
                  s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                  if(s_axis_cc_tready) begin
                    state <= #TCQ PIO_TX_RST_STATE;
                    compl_done        <= #TCQ 1'b1;
                  end else begin
                    state <= #TCQ PIO_TX_COMPL_C1;
                  end
                end

              end  //PIO_TX_COMPL

              PIO_TX_COMPL_WD_C1 : begin  // Completion With Payload
                                       // Possible Scenario's Payload can be 1 DW or 2 DW
                                       // Alignment can be either of Dword aligned or address aligned
                if (req_compl_wd_qqq) begin

                  if(payload_len == 0) // 1DW_packet - Requires just one cycle to get the data rd_data from the BRAM.
                  begin
                    if(AXISTEN_IF_CC_ALIGNMENT_MODE == "FALSE") begin // DWORD_aligned_Mode
                      s_axis_cc_tvalid  <= #TCQ 1'b1;
                      s_axis_cc_tlast   <= #TCQ 1'b1;
                      s_axis_cc_tkeep   <= #TCQ 8'h0F;
                      s_axis_cc_tdata   <= #TCQ {128'b0,        // Tied to 0 for 3DW completion descriptor
                                                 rd_letchd, //rd_data,       // 32- bit read data
                                                 1'b0,          // Force ECRC
                                                 1'b0, req_attr,// 3- bits
                                                 req_tc,        // 3- bits
                                                 1'b0,          // Completer ID to control selection of Client
                                                                // Supplied Bus number
                                                 8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                                 {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                                 req_tag,       // Matching Request Tag
                                                 req_rid,       // Requester ID - 16 bits
                                                 1'b0,          // Rsvd
                                                 1'b0,          // Posioned completion
                                                 3'b000,        // SuccessFull completion
                                                 (req_mem ? (11'h1 + payload_len) : 11'b1),         // DWord Count 0 - IO Write completions
                                                 2'b0,          // Rsvd
                                                 (req_mem_lock? 1'b1 : 1'b0),  // Locked Read Completion
                                                 {1'b0, byte_count},           // Byte Count
                                                 6'b0,          // Rsvd
                                                 req_at,        // Adress Type - 2 bits
                                                 1'b0,          // Rsvd
                                                 lower_addr};   // Starting address of the mem byte - 7 bits
                      s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                      if(s_axis_cc_tready) begin
                        state <= #TCQ PIO_TX_RST_STATE;
                        compl_done        <= #TCQ 1'b1;
                      end else begin
                        state <= #TCQ PIO_TX_COMPL_WD_C1;
                      end
                    end  //DWORD_aligned_Mode

                    else begin // Addr_aligned_mode
                      s_axis_cc_tvalid  <= #TCQ 1'b1;
                      s_axis_cc_tlast   <= #TCQ 1'b0;
                      s_axis_cc_tkeep   <= #TCQ 8'hFF;
                      s_axis_cc_tdata   <= #TCQ {160'b0,        // Tied to 0 for 3DW completion descriptor
                                                 1'b0,          // Force ECRC
                                                 1'b0, req_attr,// 3- bits
                                                 req_tc,        // 3- bits
                                                 1'b0,          // Completer ID to control selection of Client
                                                                // Supplied Bus number
                                                 8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                                 {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                                 req_tag,       // Matching Request Tag
                                                 req_rid,       // Requester ID - 16 bits
                                                 1'b0,          // Rsvd
                                                 1'b0,          // Posioned completion
                                                 3'b000,        // SuccessFull completion
                                                 (req_mem ? (11'h1 + payload_len) : 11'b1),         // DWord Count 0 - IO Write completions
                                                 2'b0,          // Rsvd
                                                 (req_mem_lock? 1'b1 : 1'b0),      // Locked Read Completion
                                                 {1'b0, byte_count},               // Byte Count
                                                 6'b0,          // Rsvd
                                                 req_at,        // Adress Type - 2 bits
                                                 1'b0,          // Rsvd
                                                 lower_addr};   // Starting address of the mem byte - 7 bits
                      s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                      compl_done        <= #TCQ 1'b0;

                      if(s_axis_cc_tready) begin
                        state <= #TCQ PIO_TX_COMPL_PYLD;
                      end else begin
                        state <= #TCQ PIO_TX_COMPL_WD_C1;
                      end
                    end    // Addr_aligned_mode

                  end //1DW_packet


                  else begin // 2DW_packet
                    if(AXISTEN_IF_CC_ALIGNMENT_MODE == "FALSE") begin // DWORD_aligned_Mode

                      state       <= #TCQ PIO_TX_COMPL_WD_2DW;

                    end  //DWORD_aligned_Mode

                    else begin // Address ALigned Mode

                      s_axis_cc_tvalid  <= #TCQ 1'b1;
                      s_axis_cc_tlast   <= #TCQ 1'b0;
                      s_axis_cc_tkeep   <= #TCQ 8'hFF;
                      s_axis_cc_tdata   <= #TCQ {160'b0,        // Tied to 0 for 3DW completion descriptor
                                                 1'b0,          // Force ECRC
                                                 1'b0, req_attr,// 3- bits
                                                 req_tc,        // 3- bits
                                                 1'b0,          // Completer ID to control selection of Client
                                                                // Supplied Bus number
                                                 8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                                 {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                                 req_tag,       // Matching Request Tag
                                                 req_rid,       // Requester ID - 16 bits
                                                 1'b0,          // Rsvd
                                                 1'b0,          // Posioned completion
                                                 3'b000,        // SuccessFull completion
                                                 (req_mem ? (11'h1 + payload_len) : 11'b1),         // DWord Count 0 - IO Write completions
                                                 2'b0,          // Rsvd
                                                 (req_mem_lock? 1'b1 : 1'b0),      // Locked Read Completion
                                                 {1'b0, byte_count},               // Byte Count
                                                 6'b0,          // Rsvd
                                                 req_at,        // Adress Type - 2 bits
                                                 1'b0,          // Rsvd
                                                 lower_addr};   // Starting address of the mem byte - 7 bits
                      s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                      compl_done        <= #TCQ 1'b0;

                      if(s_axis_cc_tready) begin
                        state <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1;
                      end else begin
                        state <= #TCQ PIO_TX_COMPL_WD_C1;
                      end
                    end  // Address ALigned mode
                  end  // 2DW_packet
                end

              end // PIO_TX_COMPL_WD

              PIO_TX_COMPL_PYLD : begin // Completion with 1DW Payload in Address Aligned mode

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ tkeep_q;
                s_axis_cc_tdata[31:0]      <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[4:2]==3'b000) ? {rd_data} : ((AXISTEN_IF_CC_ALIGNMENT_MODE == "FALSE" ) ? rd_data : 32'b0);
                s_axis_cc_tdata[63:32]     <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[4:2]==3'b001) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[95:64]     <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[4:2]==3'b010) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[127:96]    <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[4:2]==3'b011) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[159:128]   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[4:2]==3'b100) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[191:160]   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[4:2]==3'b101) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[223:192]   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[4:2]==3'b110) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[255:224]   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[4:2]==3'b111) ? {rd_data} : {32'b0};

                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state        <= #TCQ PIO_TX_RST_STATE;
                  compl_done   <= #TCQ 1'b1;
                end else begin
                  state <= #TCQ PIO_TX_COMPL_PYLD;
                end
              end // PIO_TX_COMPL_PYLD

              PIO_TX_COMPL_WD_2DW : begin // Completion with 2DW Payload in DWord Aligned mode
                                          // Requires 2 states to get the 2DW Payload

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 8'h1F;
                s_axis_cc_tdata   <= #TCQ {96'b0,         // Tied to 0 for 3DW completion descriptor with 2DW Payload
                                           rd_data_reg,   // 32 bit read data
                                           rd_data,       // 32 bit read data
                                           1'b0,          // Force ECRC
                                           1'b0, req_attr,// 3- bits
                                           req_tc,        // 3- bits
                                           1'b0,          // Completer ID to control selection of Client
                                                          // Supplied Bus number
                                           8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                           {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                           req_tag,       // Matching Request Tag
                                           req_rid,       // Requester ID - 16 bits
                                           1'b0,          // Rsvd
                                           1'b0,          // Posioned completion
                                           3'b000,        // SuccessFull completion
                                           (req_mem ? (11'h1 + payload_len) : 11'b1),         // DWord Count 0 - IO Write completions
                                           2'b0,          // Rsvd
                                           (req_mem_lock? 1'b1 : 1'b0),   // Locked Read Completion
                                           {1'b0, byte_count},            // Byte Count
                                           6'b0,          // Rsvd
                                           req_at,        // Adress Type - 2 bits
                                           1'b0,          // Rsvd
                                           lower_addr};   // Starting address of the mem byte - 7 bits
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state        <= #TCQ PIO_TX_RST_STATE;
                  compl_done   <= #TCQ 1'b1;
                end else begin
                  state <= #TCQ PIO_TX_COMPL_WD_2DW;
                end

              end //  PIO_TX_COMPL_WD_2DW

              PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1 : begin // Completions with 2-DW Payload and Addr aligned mode

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ (tkeep_q << 1 | 8'b1);
                s_axis_cc_tdata[31:0]      <= #TCQ (lower_addr_q[4:2]==3'b000) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[63:32]     <= #TCQ (lower_addr_q[4:2]==3'b001) ? {rd_data} : ((lower_addr_q[4:2]==3'b000) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tdata[95:64]     <= #TCQ (lower_addr_q[4:2]==3'b010) ? {rd_data} : ((lower_addr_q[4:2]==3'b001) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tdata[127:96]    <= #TCQ (lower_addr_q[4:2]==3'b011) ? {rd_data} : ((lower_addr_q[4:2]==3'b010) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tdata[159:128]   <= #TCQ (lower_addr_q[4:2]==3'b100) ? {rd_data} : ((lower_addr_q[4:2]==3'b011) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tdata[191:160]   <= #TCQ (lower_addr_q[4:2]==3'b101) ? {rd_data} : ((lower_addr_q[4:2]==3'b100) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tdata[223:192]   <= #TCQ (lower_addr_q[4:2]==3'b110) ? {rd_data} : ((lower_addr_q[4:2]==3'b101) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tdata[255:224]   <= #TCQ (lower_addr_q[4:2]==3'b111) ? {rd_data} : ((lower_addr_q[4:2]==3'b110) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                if(s_axis_cc_tready) begin
                   if (lower_addr_q[4:2]==3'b111) begin
                      state             <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C2;
                      s_axis_cc_tlast   <= #TCQ 1'b0;
                      compl_done        <= #TCQ 1'b0;
                   end else begin
                      state             <= #TCQ PIO_TX_RST_STATE;
                      s_axis_cc_tlast   <= #TCQ 1'b1;
                      compl_done        <= #TCQ 1'b1;
                   end
                end else begin
                  state <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1;
                end // PIO_TX_COMPL_WD_2DW_ADDR_ALGN
              end
              
              PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C2 : begin // Completions with 2-DW Payload and Addr aligned mode with lower_addr[4:2] == 3'b111 only
              
                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 8'h01;
                s_axis_cc_tdata   <= #TCQ {224'b0, rd_data_reg};
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                s_axis_cc_tlast   <= #TCQ 1'b1;
                state             <= #TCQ PIO_TX_RST_STATE;
                compl_done        <= #TCQ 1'b1;
              
              end

              PIO_TX_CPL_UR_C1 : begin // Completions with UR - Alignment mode matters here

                if (req_compl_ur_qq) begin

                     s_axis_cc_tvalid  <= #TCQ 1'b1;
                     s_axis_cc_tlast   <= #TCQ 1'b1;
                     s_axis_cc_tkeep   <= #TCQ 8'hFF;
                     s_axis_cc_tdata   <= #TCQ {req_des_qword1, // 64 bits - Descriptor of the request 2 DW
                                                req_des_qword0, // 64 bits - Descriptor of the request 2 DW
                                                8'b0,                // Rsvd
                                                req_des_tph_st_tag,  // TPH Steering tag - 8 bits
                                                5'b0,                // Rsvd
                                                req_des_tph_type,    // TPH type - 2 bits
                                                req_des_tph_present, // TPH present - 1 bit
                                                req_be,        // Request Byte enables - 8bits
                                                1'b0,          // Force ECRC
                                                1'b0, req_attr,// 3- bits
                                                req_tc,        // 3- bits
                                                1'b0,          // Completer ID to control selection of Client
                                                               // Supplied Bus number
                                                8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                                {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                                req_tag,       // Matching Request Tag
                                                req_rid,       // Requester ID - 16 bits
                                                1'b0,          // Rsvd
                                                1'b0,          // Posioned completion
                                                3'b001,        // Completion Status - UR
                                                11'h000,       // DWord Count
                                                2'b0,          // Rsvd
                                                (req_mem_lock? 1'b1 : 1'b0),   // Locked Read Completion
                                                13'h0004,      // Byte Count
                                                6'b0,          // Rsvd
                                                req_at,        // Adress Type - 2 bits
                                                1'b0,          // Rsvd
                                                lower_addr};   // Starting address of the mem byte - 7 bits
                     s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                     if(s_axis_cc_tready) begin
                       state        <= #TCQ PIO_TX_RST_STATE;
                       compl_done   <= #TCQ 1'b1;
                     end else begin
                       state        <= #TCQ PIO_TX_CPL_UR_C1;
                     end
                end

              end // PIO_TX_CPL_UR



 
            endcase

          end // reset_else_block

      end // Always Block Ends
    end // If C_DATA_WIDTH = 256

    else if(C_DATA_WIDTH == 128) // 128-bit Interface
    begin
    always @ ( posedge user_clk )
    begin

      if(!reset_n ) begin

        state                   <= #TCQ PIO_TX_RST_STATE;
        s_axis_cc_tdata         <= #TCQ {C_DATA_WIDTH{1'b0}};
        s_axis_cc_tkeep         <= #TCQ {KEEP_WIDTH{1'b0}};
        s_axis_cc_tlast         <= #TCQ 1'b0;
        s_axis_cc_tvalid        <= #TCQ 1'b0;
        s_axis_cc_tuser         <= #TCQ 33'b0;
        compl_done              <= #TCQ 1'b0;
        
      end else begin // reset_else_block

            case (state)

              PIO_TX_RST_STATE : begin  // Reset_State

                state                   <= #TCQ PIO_TX_RST_STATE;
                s_axis_cc_tdata         <= #TCQ {C_DATA_WIDTH{1'b0}};
                s_axis_cc_tkeep         <= #TCQ {KEEP_WIDTH{1'b1}};
                s_axis_cc_tlast         <= #TCQ 1'b0;
                s_axis_cc_tvalid        <= #TCQ 1'b0;
                s_axis_cc_tuser         <= #TCQ 33'b0;
                compl_done              <= #TCQ 1'b0;
                
                if(req_compl) begin
                   state <= #TCQ PIO_TX_COMPL_C1;
                end else if (req_compl_wd) begin
                   state <= #TCQ PIO_TX_COMPL_WD_C1;
                end else if (req_compl_ur) begin
                   state <= #TCQ PIO_TX_CPL_UR_C1;
                end

              end // PIO_TX_RST_STATE

              PIO_TX_COMPL_C1 : begin // Completion Without Payload - Alignment doesnt matter
                                   // Sent in a Single Beat When Interface Width is 128 bit
                if(req_compl_qq) begin
                  s_axis_cc_tvalid  <= #TCQ 1'b1;
                  s_axis_cc_tlast   <= #TCQ 1'b1;
                  s_axis_cc_tkeep   <= #TCQ 4'h7;
                  s_axis_cc_tdata   <= #TCQ {32'b0,        // Tied to 0 for 3DW completion descriptor
                                             1'b0,          // Force ECRC
                                             1'b0, req_attr,// 3- bits
                                             req_tc,        // 3- bits
                                             1'b0,          // Completer ID to control selection of Client
                                                            // Supplied Bus number
                                             8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                             {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                             req_tag,       // Matching Request Tag
                                             req_rid,       // Requester ID - 16 bits
                                             1'b0,          // Rsvd
                                             1'b0,          // Posioned completion
                                             3'b000,        // SuccessFull completion
                                             (req_mem ? (11'h1 + payload_len) : 11'b0),         // DWord Count 0 - IO Write completions
                                             2'b0,          // Rsvd
                                             1'b0,          // Locked Read Completion
                                             {1'b0, byte_count},        // Byte Count
                                             6'b0,          // Rsvd
                                             req_at,        // Adress Type - 2 bits
                                             1'b0,          // Rsvd
                                             lower_addr};   // Starting address of the mem byte - 7 bits
                  s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                  if(s_axis_cc_tready) begin
                    state <= #TCQ PIO_TX_RST_STATE;
                    compl_done        <= #TCQ 1'b1;
                  end else begin
                    state <= #TCQ PIO_TX_COMPL_C1;
                  end

                end
              end  //PIO_TX_COMPL

              PIO_TX_COMPL_WD_C1 : begin  // Completion With Payload
                                          // Possible Scenario's Payload can be 1 DW or 2 DW
                                          // Alignment can be either of Dword aligned or address aligned
                if(req_compl_wd_qqq) begin

                  if(AXISTEN_IF_CC_ALIGNMENT_MODE == "FALSE") begin // DWORD_aligned_Mode
                      s_axis_cc_tvalid  <= #TCQ 1'b1;
                      s_axis_cc_tkeep   <= #TCQ 4'hF;
                      s_axis_cc_tdata   <= #TCQ {rd_data,       // 32- bit read data
                                                 1'b0,          // Force ECRC
                                                 1'b0, req_attr,// 3- bits
                                                 req_tc,        // 3- bits
                                                 1'b0,          // Completer ID to control selection of Client
                                                                // Supplied Bus number
                                                 8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                                 {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# sel if Compl ID = 1. Function# = 0
                                                 req_tag,       // Matching Request Tag
                                                 req_rid,       // Requester ID - 16 bits
                                                 1'b0,          // Rsvd
                                                 1'b0,          // Posioned completion
                                                 3'b000,        // SuccessFull completion
                                                 (req_mem ? (11'h1 + payload_len) : 11'b1),         // DWord Count 0 - IO Write completions
                                                 2'b0,          // Rsvd
                                                 (req_mem_lock? 1'b1 : 1'b0),  // Locked Read Completion
                                                 {1'b0, byte_count},           // Byte Count
                                                 6'b0,          // Rsvd
                                                 req_at,        // Adress Type - 2 bits
                                                 1'b0,          // Rsvd
                                                 lower_addr};   // Starting address of the mem byte - 7 bits
                      s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                      if(s_axis_cc_tready) begin
                        if(payload_len == 0) begin // 1DW_packet - Requires just one cycle to get the data rd_data from the BRAM.
                          s_axis_cc_tlast   <= #TCQ 1'b1;
                          state <= #TCQ PIO_TX_RST_STATE;
                          compl_done        <= #TCQ 1'b1;
                        end else begin
                          s_axis_cc_tlast   <= #TCQ 1'b0;
                          state <= #TCQ PIO_TX_COMPL_WD_2DW;
                          compl_done        <= #TCQ 1'b0;
                        end
                      end else begin
                        state <= #TCQ PIO_TX_COMPL_WD_C1;
                      end
                    end  //DWORD_aligned_Mode

                    else begin // Addr_aligned_mode
                      s_axis_cc_tvalid  <= #TCQ 1'b1;
                      s_axis_cc_tlast   <= #TCQ 1'b0;
                      s_axis_cc_tkeep   <= #TCQ 4'hF;
                      s_axis_cc_tdata   <= #TCQ {32'b0,        // Tied to 0 for 3DW completion descriptor
                                                 1'b0,          // Force ECRC
                                                 1'b0, req_attr,// 3- bits
                                                 req_tc,        // 3- bits
                                                 1'b0,          // Completer ID to control selection of Client
                                                                // Supplied Bus number
                                                 8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                                 {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                                 req_tag,       // Matching Request Tag
                                                 req_rid,       // Requester ID - 16 bits
                                                 1'b0,          // Rsvd
                                                 1'b0,          // Posioned completion
                                                 3'b000,        // SuccessFull completion
                                                 (req_mem ? (11'h1 + payload_len) : 11'b1),         // DWord Count 0 - IO Write completions
                                                 2'b0,          // Rsvd
                                                 (req_mem_lock? 1'b1 : 1'b0),      // Locked Read Completion
                                                 {1'b0, byte_count},               // Byte Count
                                                 6'b0,          // Rsvd
                                                 req_at,        // Adress Type - 2 bits
                                                 1'b0,          // Rsvd
                                                 lower_addr};   // Starting address of the mem byte - 7 bits
                      s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                      compl_done        <= #TCQ 1'b0;

                      if(s_axis_cc_tready) begin
                        if(payload_len == 0) // 1DW_packet - Requires just one cycle to get the data rd_data from the BRAM.
                        begin
                          state <= #TCQ PIO_TX_COMPL_PYLD;
                        end else begin
                          state <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1;
                        end 
                      end else begin
                          state <= #TCQ PIO_TX_COMPL_WD_C1;
                      end
                    end    // Addr_aligned_mode
                end

              end // PIO_TX_COMPL_WD

              PIO_TX_COMPL_PYLD : begin // Completion with 1DW Payload in Address Aligned mode or 2DW Payload in DWORD Aligned mode

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ (tkeep_q[7:0]&8'hF);
                s_axis_cc_tdata[31:0]   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[3:2]==2'b00) ? {rd_data} : ((AXISTEN_IF_CC_ALIGNMENT_MODE == "FALSE" ) ? rd_data_reg : 32'b0);
                s_axis_cc_tdata[63:32]   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[3:2]==2'b01) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[95:64]   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[3:2]==2'b10) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[127:96]   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE" && lower_addr_q[3:2]==2'b11) ? {rd_data} : {32'b0};
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state           <= #TCQ PIO_TX_RST_STATE;
                  compl_done      <= #TCQ 1'b1;
                end else begin
                  state           <= #TCQ PIO_TX_COMPL_PYLD;
                end

              end // PIO_TX_COMPL_PYLD

              PIO_TX_COMPL_WD_2DW : begin // Completion with 2DW Payload in DWord Aligned mode
                                          // Requires 2 states to get the 2DW Payload

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 4'h1;
                s_axis_cc_tdata   <= #TCQ {96'b0, rd_data_reg};  // Transmit 2nd DW payload
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state           <= #TCQ PIO_TX_RST_STATE;
                  compl_done      <= #TCQ 1'b1;
                end else begin
                  state           <= #TCQ PIO_TX_COMPL_WD_2DW;
                end

              end //  PIO_TX_COMPL_WD_2DW

              PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1 : begin // Completions with 2-DW Payload and Addr aligned mode

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ (tkeep_q << 1 | 4'b1);
                s_axis_cc_tdata[31:0]      <= #TCQ (lower_addr_q[3:2]==2'b00) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[63:32]     <= #TCQ (lower_addr_q[3:2]==2'b01) ? {rd_data} : ((lower_addr_q[3:2]==2'b00) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tdata[95:64]     <= #TCQ (lower_addr_q[3:2]==2'b10) ? {rd_data} : ((lower_addr_q[3:2]==2'b01) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tdata[127:96]    <= #TCQ (lower_addr_q[3:2]==2'b11) ? {rd_data} : ((lower_addr_q[3:2]==2'b10) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                if(s_axis_cc_tready) begin
                   if (lower_addr_q[3:2]==2'b11) begin
                      state             <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C2;
                      s_axis_cc_tlast   <= #TCQ 1'b0;
                      compl_done        <= #TCQ 1'b0;
                   end else begin
                      state             <= #TCQ PIO_TX_RST_STATE;
                      s_axis_cc_tlast   <= #TCQ 1'b1;
                      compl_done        <= #TCQ 1'b1;
                   end
                end else begin
                  state <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1;
                end // PIO_TX_COMPL_WD_2DW_ADDR_ALGN
              end
              
              PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C2 : begin // Completions with 2-DW Payload and Addr aligned mode with lower_addr[4:2] == 2'b11 only
              
                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 4'h1;
                s_axis_cc_tdata   <= #TCQ {96'b0, rd_data_reg};
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                s_axis_cc_tlast   <= #TCQ 1'b1;
                state             <= #TCQ PIO_TX_RST_STATE;
                compl_done        <= #TCQ 1'b1;
              
              end

              PIO_TX_CPL_UR_C1 : begin // Completions with UR - Alignment mode matters here

                if(req_compl_ur_qq) begin

                     s_axis_cc_tvalid  <= #TCQ 1'b1;
                     s_axis_cc_tlast   <= #TCQ 1'b1;
                     s_axis_cc_tkeep   <= #TCQ 4'hF;
                     compl_done        <= #TCQ 1'b0;
                     s_axis_cc_tdata   <= #TCQ {8'b0,                // Rsvd
                                                req_des_tph_st_tag,  // TPH Steering tag - 8 bits
                                                5'b0,                // Rsvd
                                                req_des_tph_type,    // TPH type - 2 bits
                                                req_des_tph_present, // TPH present - 1 bit
                                                req_be,              // Request Byte enables - 8bits

                                                1'b0,                // Force ECRC
                                                1'b0, req_attr,      // 3- bits
                                                req_tc,              // 3- bits
                                                1'b0,                // Completer ID to control selection of Client
                                                                     // Supplied Bus number
                                                8'hAA,               // Completer Bus number - Bus# selected if Compl ID = 1
                                                {5'b11111, 3'b000},  // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                                req_tag,             // Matching Request Tag
                                                req_rid,             // Requester ID - 16 bits
                                                1'b0,                // Rsvd
                                                1'b0,                // Posioned completion
                                                3'b001,              // Completion Status - UR
                                                11'h000,             // DWord Count
                                                2'b0,                // Rsvd
                                                (req_mem_lock? 1'b1 : 1'b0),   // Locked Read Completion
                                                13'h0004,            // Byte Count
                                                6'b0,                // Rsvd
                                                req_at,              // Adress Type - 2 bits
                                                1'b0,                // Rsvd
                                                lower_addr};   // Starting address of the mem byte - 7 bits
                     s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                     if (s_axis_cc_tready) begin
                       state           <= #TCQ PIO_TX_CPL_UR_C2;
                     end else begin
                       state           <= #TCQ PIO_TX_CPL_UR_C1;
                     end
                end

              end // PIO_TX_CPL_UR_C1

              PIO_TX_CPL_UR_C2 : begin // Completion for UR - Clock 2


                 s_axis_cc_tvalid  <= #TCQ 1'b1;
                 s_axis_cc_tlast   <= #TCQ 1'b1;
                 s_axis_cc_tkeep   <= #TCQ 4'hF;
                 s_axis_cc_tdata   <= #TCQ {req_des_qword1,      // 64 bits - Descriptor of the request 2 DW
                                            req_des_qword0};     // 64 bits - Descriptor of the request 2 DW};

                 s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                 if (s_axis_cc_tready) begin
                   state           <= #TCQ PIO_TX_RST_STATE;
                   compl_done      <= #TCQ 1'b1;
                 end else begin
                   state           <= #TCQ PIO_TX_CPL_UR_C2;
                 end

              end // PIO_TX_CPL_UR_PYLD_C1


            endcase

          end // reset_else_block

      end // Always Block Ends
    end // If C_DATA_WIDTH = 128

    else
    begin // 64 Bit Interface
    always @ ( posedge user_clk )
    begin

      if(!reset_n ) begin

        state                   <= #TCQ PIO_TX_RST_STATE;
        s_axis_cc_tdata         <= #TCQ {C_DATA_WIDTH{1'b0}};
        s_axis_cc_tkeep         <= #TCQ {KEEP_WIDTH{1'b0}};
        s_axis_cc_tlast         <= #TCQ 1'b0;
        s_axis_cc_tvalid        <= #TCQ 1'b0;
        s_axis_cc_tuser         <= #TCQ 33'b0;
        compl_done              <= #TCQ 1'b0;
        
      end else begin // reset_else_block

            case (state)

              PIO_TX_RST_STATE : begin  // Reset_State

                state                   <= #TCQ PIO_TX_RST_STATE;
                s_axis_cc_tdata         <= #TCQ {C_DATA_WIDTH{1'b0}};
                s_axis_cc_tkeep         <= #TCQ {KEEP_WIDTH{1'b1}};
                s_axis_cc_tlast         <= #TCQ 1'b0;
                s_axis_cc_tvalid        <= #TCQ 1'b0;
                s_axis_cc_tuser         <= #TCQ 33'b0;
                compl_done              <= #TCQ 1'b0;
                
                if(req_compl) begin
                   state <= #TCQ PIO_TX_COMPL_C1;
                end else if (req_compl_wd) begin
                   state <= #TCQ PIO_TX_COMPL_WD_C1;
                end else if (req_compl_ur) begin
                   state <= #TCQ PIO_TX_CPL_UR_C1;
                end

              end // PIO_TX_RST_STATE

              PIO_TX_COMPL_C1 : begin // Completion Without Payload - Alignment doesnt matter
                                   // Sent in a Single Beat When Interface Width is 128 bit
                if(req_compl_qq)
                begin
                  s_axis_cc_tvalid  <= #TCQ 1'b1;
                  s_axis_cc_tlast   <= #TCQ 1'b0;
                  s_axis_cc_tkeep   <= #TCQ 2'h3;
                  compl_done        <= #TCQ 1'b0;
                  s_axis_cc_tdata   <= #TCQ {req_rid,       // Requester ID - 16 bits
                                             1'b0,          // Rsvd
                                             1'b0,          // Posioned completion
                                             3'b000,        // SuccessFull completion
                                             (req_mem ? (11'h1 + payload_len) : 11'b0),         // DWord Count 0 - IO Write completions
                                             2'b0,          // Rsvd
                                             1'b0,          // Locked Read Completion
                                             {1'b0, byte_count},        // Byte Count
                                             6'b0,          // Rsvd
                                             req_at,        // Adress Type - 2 bits
                                             1'b0,          // Rsvd
                                             lower_addr};   // Starting address of the mem byte - 7 bits
                  s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                  if(s_axis_cc_tready) begin
                    state           <= #TCQ PIO_TX_COMPL_C2;
                  end else begin
                    state           <= #TCQ PIO_TX_COMPL_C1;
                  end
                end
              end  //PIO_TX_COMPL

              PIO_TX_COMPL_C2 : begin // Completion Without Payload - Alignment doesnt matter
                                      // Sent in a Two Beats When Interface Width is 64 bit
                  s_axis_cc_tvalid  <= #TCQ 1'b1;
                  s_axis_cc_tlast   <= #TCQ 1'b1;
                  s_axis_cc_tkeep   <= #TCQ 2'h1;
                  s_axis_cc_tdata   <= #TCQ {32'b0,         // Tied to 0 for 3DW completion descriptor
                                             1'b0,          // Force ECRC
                                             1'b0, req_attr,// 3- bits
                                             req_tc,        // 3- bits
                                             1'b0,          // Completer ID to control selection of Client
                                                            // Supplied Bus number
                                             8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                             {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                             req_tag};      // Matching Request Tag
                  s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                  if(s_axis_cc_tready) begin
                    state           <= #TCQ PIO_TX_RST_STATE;
                    compl_done      <= #TCQ 1'b1;
                  end else begin
                    state           <= #TCQ PIO_TX_COMPL_C2;
                  end

              end  //PIO_TX_COMPL

              PIO_TX_COMPL_WD_C1 : begin  // Completion With Payload
                                          // Possible Scenario's Payload can be 1 DW or 2 DW
                                          // Alignment can be either of Dword aligned or address aligned
                if(req_compl_wd_qqq)
                begin

                  s_axis_cc_tvalid  <= #TCQ 1'b1;
                  s_axis_cc_tlast   <= #TCQ 1'b0;
                  s_axis_cc_tkeep   <= #TCQ 2'h3;
                  compl_done        <= #TCQ 1'b0;
                  s_axis_cc_tdata   <= #TCQ {req_rid,                                   // Requester ID - 16 bits
                                             1'b0,                                      // Rsvd
                                             1'b0,                                      // Posioned completion
                                             3'b000,                                    // SuccessFull completion
                                             (req_mem ? (11'h1 + payload_len) : 11'b1), // DWord Count 0 - IO Write completions
                                             2'b0,                                      // Rsvd
                                             (req_mem_lock? 1'b1 : 1'b0),               // Locked Read Completion
                                             {1'b0, byte_count},                        // Byte Count
                                             6'b0,                                      // Rsvd
                                             req_at,                                    // Adress Type - 2 bits
                                             1'b0,                                      // Rsvd
                                             lower_addr};                               // Starting address of the mem byte - 7 bits
                  s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                  if(s_axis_cc_tready) begin
                    state      <= #TCQ PIO_TX_COMPL_WD_C2;
                  end else begin
                    state      <= #TCQ PIO_TX_COMPL_WD_C1;
                  end
                end

              end // PIO_TX_COMPL_WD

              PIO_TX_COMPL_WD_C2 : begin  // Completion With Payload
                                          // Possible Scenario's Payload can be 1 DW or 2 DW
                                          // Alignment can be either of Dword aligned or address aligned

                  if(AXISTEN_IF_CC_ALIGNMENT_MODE == "FALSE") begin // DWORD_aligned_Mode
                      s_axis_cc_tvalid  <= #TCQ 1'b1;
                      s_axis_cc_tkeep   <= #TCQ 2'h3;
                      s_axis_cc_tdata   <= #TCQ {rd_data,       //                       s_axis_cc_tlast   <= #TCQ 1'b1;32- bit read data
                                                 1'b0,          // Force ECRC
                                                 1'b0, req_attr,// 3- bits
                                                 req_tc,        // 3- bits
                                                 1'b0,          // Completer ID to control selection of Client
                                                                // Supplied Bus number
                                                 8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                                 {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                                 req_tag};      // Matching Request Tag
                      s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                      if(s_axis_cc_tready) begin
                        if(payload_len == 0) // 1DW_packet - Requires just one cycle to get the data rd_data from the BRAM.
                        begin
                          state      <= #TCQ PIO_TX_RST_STATE;
                          s_axis_cc_tlast   <= #TCQ 1'b1;
                          compl_done <= #TCQ 1'b1;
                        end else begin
                          s_axis_cc_tlast   <= #TCQ 1'b0;
                          state      <= #TCQ PIO_TX_COMPL_WD_2DW;
                        end
                      end else begin
                        state <= #TCQ PIO_TX_COMPL_WD_C2;
                      end

                end        //DWORD_aligned_Mode
                else begin // Addr_aligned_mode
                  s_axis_cc_tvalid  <= #TCQ 1'b1;
                  s_axis_cc_tlast   <= #TCQ 1'b0;
                  s_axis_cc_tkeep   <= #TCQ 2'h3;
                  s_axis_cc_tdata   <= #TCQ {1'b0,          // Force ECRC
                                             1'b0, req_attr,// 3- bits
                                             req_tc,        // 3- bits
                                             1'b0,          // Completer ID to control selection of Client
                                                            // Supplied Bus number
                                             8'hAA,              // Completer Bus number - Bus# selected if Compl ID = 1
                                             {5'b11111, 3'b000}, // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                             req_tag};      // Matching Request Tag
                  s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                  compl_done        <= #TCQ 1'b0;

                  if(s_axis_cc_tready) begin
                    if(payload_len == 0) begin // 1DW_packet - Requires just one cycle to get the data rd_data from the BRAM.
                      state         <= #TCQ PIO_TX_COMPL_PYLD;
                    end else begin
                      state         <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1;
                    end
                  end else begin
                      state         <= #TCQ PIO_TX_COMPL_WD_C2;
                  end
//                end

              end    // Addr_aligned_mode
            end // PIO_TX_COMPL_WD

              PIO_TX_COMPL_PYLD : begin // Completion with 1DW Payload in Address Aligned mode or 2DW Payload in DWORD Aligned mode

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ tkeep_qq[1:0]&2'h3;
                s_axis_cc_tdata   <= #TCQ (AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE") ? (lower_addr_qq[2] ? {rd_data,32'b0} : {32'b0, rd_data}) : rd_data_reg;
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state           <= #TCQ PIO_TX_RST_STATE;
                  compl_done      <= #TCQ 1'b1;
                end else begin
                  state           <= #TCQ PIO_TX_COMPL_PYLD;
                end

              end // PIO_TX_COMPL_PYLD

              PIO_TX_COMPL_WD_2DW : begin // Completion with 2DW Payload in DWord Aligned mode
                                          // Requires 2 states to get the 2DW Payload

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 2'h1;
                s_axis_cc_tdata   <= #TCQ {32'b0, rd_data_reg};  // Transmit 2nd DW payload
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state           <= #TCQ PIO_TX_RST_STATE;
                  compl_done      <= #TCQ 1'b1;
                end else begin
                  state           <= #TCQ PIO_TX_COMPL_WD_2DW;
                end

              end //  PIO_TX_COMPL_WD_2DW

              PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1 : begin // Completions with 2-DW Payload and Addr aligned mode

                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ (tkeep_q << 1 | 2'b1);
                s_axis_cc_tdata[31:0]      <= #TCQ (lower_addr_qq[2]==1'b0) ? {rd_data} : {32'b0};
                s_axis_cc_tdata[63:32]     <= #TCQ (lower_addr_qq[2]==1'b1) ? {rd_data} : ((lower_addr_qq[2]==1'b0) ? {rd_data_reg} : {32'b0});
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                if(s_axis_cc_tready) begin
                   if (lower_addr_qq[2]==1'b1) begin
                      state             <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C2;
                      s_axis_cc_tlast   <= #TCQ 1'b0;
                      compl_done        <= #TCQ 1'b0;
                   end else begin
                      state             <= #TCQ PIO_TX_RST_STATE;
                      s_axis_cc_tlast   <= #TCQ 1'b1;
                      compl_done        <= #TCQ 1'b1;
                   end
                end else begin
                  state <= #TCQ PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1;
                end // PIO_TX_COMPL_WD_2DW_ADDR_ALGN
              end
              
              PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C2 : begin // Completions with 2-DW Payload and Addr aligned mode with lower_addr[2] == 1'b1 only
              
                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 2'b01;
                s_axis_cc_tdata   <= #TCQ {32'b0, rd_data_reg};
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};
                s_axis_cc_tlast   <= #TCQ 1'b1;
                state             <= #TCQ PIO_TX_RST_STATE;
                compl_done        <= #TCQ 1'b1;
              
              end

              PIO_TX_CPL_UR_C1 : begin // Completions with UR - Beat 1

                if(req_compl_ur_qq) begin

                  s_axis_cc_tvalid  <= #TCQ 1'b1;
                  s_axis_cc_tlast   <= #TCQ 1'b1;
                  s_axis_cc_tkeep   <= #TCQ 2'h3;
                  compl_done        <= #TCQ 1'b0;
                  s_axis_cc_tdata   <= #TCQ {req_rid,             // Requester ID - 16 bits
                                             1'b0,                // Rsvd
                                             1'b0,                // Posioned completion
                                             3'b001,              // Completion Status - UR
                                             11'h000,             // DWord Count
                                             2'b0,                // Rsvd
                                             (req_mem_lock? 1'b1 : 1'b0),   // Locked Read Completion
                                             13'h0004,            // Byte Count
                                             6'b0,                // Rsvd
                                             req_at,              // Adress Type - 2 bits
                                             1'b0,                // Rsvd
                                             lower_addr};   // Starting address of the mem byte - 7 bits
                  s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                  if(s_axis_cc_tready) begin
                    state           <= #TCQ PIO_TX_CPL_UR_C2;
                  end else begin
                    state           <= #TCQ PIO_TX_CPL_UR_C1;
                  end

                end
              end // PIO_TX_CPL_UR_C1

              PIO_TX_CPL_UR_C2 : begin // Completions with UR - Beat 2
                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 2'h3;
                compl_done        <= #TCQ 1'b0;
                s_axis_cc_tdata   <= #TCQ {8'b0,                // Rsvd
                                           req_des_tph_st_tag,  // TPH Steering tag - 8 bits
                                           5'b0,                // Rsvd
                                           req_des_tph_type,    // TPH type - 2 bits
                                           req_des_tph_present, // TPH present - 1 bit
                                           req_be,              // Request Byte enables - 8bits

                                           1'b0,                // Force ECRC
                                           1'b0, req_attr,      // 3- bits
                                           req_tc,              // 3- bits
                                           1'b0,                // Completer ID to control selection of Client
                                                                // Supplied Bus number
                                           8'hAA,               // Completer Bus number - Bus# selected if Compl ID = 1
                                           {5'b11111, 3'b000},  // Compl Dev / Func no - Dev# selected if Compl ID = 1. Function# = 0
                                           req_tag};            // Matching Request Tag
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state           <= #TCQ PIO_TX_CPL_UR_C3;
                end else begin
                  state           <= #TCQ PIO_TX_CPL_UR_C2;
                end

              end // PIO_TX_CPL_UR_C2

              PIO_TX_CPL_UR_C3 : begin // Completions with UR - Beat 3
                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 2'h3;
                compl_done        <= #TCQ 1'b0;
                s_axis_cc_tdata   <= #TCQ req_des_qword0;      // 64 bits - Descriptor of the request 2 DW
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state           <= #TCQ PIO_TX_CPL_UR_C4;
                end else begin
                  state           <= #TCQ PIO_TX_CPL_UR_C3;
                end

              end // PIO_TX_CPL_UR_C3

              PIO_TX_CPL_UR_C4 : begin // Completions with UR - Beat 4
                s_axis_cc_tvalid  <= #TCQ 1'b1;
                s_axis_cc_tlast   <= #TCQ 1'b1;
                s_axis_cc_tkeep   <= #TCQ 2'h3;
                s_axis_cc_tdata   <= #TCQ req_des_qword1;      // 64 bits - Descriptor of the request 2 DW
                s_axis_cc_tuser   <= #TCQ {1'b0, (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0)};

                if(s_axis_cc_tready) begin
                  state           <= #TCQ PIO_TX_RST_STATE;
                  compl_done      <= #TCQ 1'b1;
                end else begin
                  state           <= #TCQ PIO_TX_CPL_UR_C4;
                end

              end // PIO_TX_CPL_UR_C4


            endcase

          end // reset_else_block

      end // If C_DATA_WIDTH = 64
    end
  endgenerate


  // synthesis translate_off
  reg  [8*20:1] state_ascii;
  always @(state)
  begin
    case (state)
      PIO_TX_RST_STATE                    : state_ascii <= #TCQ "TX_RST_STATE";
      PIO_TX_COMPL_C1                     : state_ascii <= #TCQ "TX_COMPL_C1";
      PIO_TX_COMPL_C2                     : state_ascii <= #TCQ "TX_COMPL_C2";
      PIO_TX_COMPL_WD_C1                  : state_ascii <= #TCQ "TX_COMPL_WD_C1";
      PIO_TX_COMPL_WD_C2                  : state_ascii <= #TCQ "TX_COMPL_WD_C2";
      PIO_TX_COMPL_PYLD                   : state_ascii <= #TCQ "TX_COMPL_PYLD";
      PIO_TX_CPL_UR_C1                    : state_ascii <= #TCQ "TX_CPL_UR_C1";
      PIO_TX_CPL_UR_C2                    : state_ascii <= #TCQ "TX_CPL_UR_C2";
      PIO_TX_CPL_UR_C3                    : state_ascii <= #TCQ "TX_CPL_UR_C3";
      PIO_TX_CPL_UR_C4                    : state_ascii <= #TCQ "TX_CPL_UR_C4";
      PIO_TX_COMPL_WD_2DW                 : state_ascii <= #TCQ "TX_COMPL_WD_2DW";
      PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C1    : state_ascii <= #TCQ "TX_COMPL_WD_2DW_ADDR_ALGN_C1";
      PIO_TX_COMPL_WD_2DW_ADDR_ALGN_C2    : state_ascii <= #TCQ "TX_COMPL_WD_2DW_ADDR_ALGN_C2";
      default                             : state_ascii <= #TCQ "PIO STATE ERR";
    endcase
  end
  // synthesis translate_on

endmodule // pio_tx_engine
