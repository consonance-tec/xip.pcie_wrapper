
//-----------------------------------------------------------------------------
//
// Description: Turn-off Control Unit.
//
//--------------------------------------------------------------------------------

`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module turn_off_ctrl #(
  parameter TCQ = 1
 )(

  input      clk,
  input      rst_n,

  input      req_compl,
  input      compl_done,

  input      cfg_power_state_change_interrupt,
  output reg cfg_power_state_change_ack
  );

  reg                 trn_pending;

  //  Check if completion is pending

  always @ (posedge clk)
  begin
    if (!rst_n ) begin
      trn_pending <= #TCQ 1'b0;
    end else begin
      if (!trn_pending && req_compl)
        trn_pending <= #TCQ 1'b1;
      else if (compl_done)
        trn_pending <= #TCQ 1'b0;
    end
  end


  //  Turn-off OK if requested and no transaction is pending


  always @ (posedge clk)
  begin
    if (!rst_n ) begin
      cfg_power_state_change_ack <= 1'b0;
    end else begin
      if ( cfg_power_state_change_interrupt  && !trn_pending)
        cfg_power_state_change_ack <= 1'b1;
      else
        cfg_power_state_change_ack <= 1'b0;
    end
  end


endmodule // pio_to_ctrl
