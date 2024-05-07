# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "AXI4_CQ_TUSER_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI4_RC_TUSER_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI4_RQ_TUSER_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_ID_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_STRB_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BAR2_ENABLED" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BUFFES_SIZE_LOG_OF2" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "KEEP_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MAX_USER_RX_REQUEST_SIZE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "NUM_NUM_OF_USER_RX_PENDINNG_REQUEST" -parent ${Page_0}
  ipgui::add_param $IPINST -name "NUM_OF_C2S_CHAN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "NUM_OF_INTERRUPTS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "NUM_OF_S2C_CHAN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ONE_USEC_PER_BUS_CYCLE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SWAP_ENDIAN" -parent ${Page_0}


}

proc update_PARAM_VALUE.AXI4_CQ_TUSER_WIDTH { PARAM_VALUE.AXI4_CQ_TUSER_WIDTH } {
	# Procedure called to update AXI4_CQ_TUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI4_CQ_TUSER_WIDTH { PARAM_VALUE.AXI4_CQ_TUSER_WIDTH } {
	# Procedure called to validate AXI4_CQ_TUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.AXI4_RC_TUSER_WIDTH { PARAM_VALUE.AXI4_RC_TUSER_WIDTH } {
	# Procedure called to update AXI4_RC_TUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI4_RC_TUSER_WIDTH { PARAM_VALUE.AXI4_RC_TUSER_WIDTH } {
	# Procedure called to validate AXI4_RC_TUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.AXI4_RQ_TUSER_WIDTH { PARAM_VALUE.AXI4_RQ_TUSER_WIDTH } {
	# Procedure called to update AXI4_RQ_TUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI4_RQ_TUSER_WIDTH { PARAM_VALUE.AXI4_RQ_TUSER_WIDTH } {
	# Procedure called to validate AXI4_RQ_TUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.AXI_ADDR_WIDTH { PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to update AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_ADDR_WIDTH { PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to validate AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.AXI_DATA_WIDTH { PARAM_VALUE.AXI_DATA_WIDTH } {
	# Procedure called to update AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_DATA_WIDTH { PARAM_VALUE.AXI_DATA_WIDTH } {
	# Procedure called to validate AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.AXI_ID_WIDTH { PARAM_VALUE.AXI_ID_WIDTH } {
	# Procedure called to update AXI_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_ID_WIDTH { PARAM_VALUE.AXI_ID_WIDTH } {
	# Procedure called to validate AXI_ID_WIDTH
	return true
}

proc update_PARAM_VALUE.AXI_STRB_WIDTH { PARAM_VALUE.AXI_STRB_WIDTH } {
	# Procedure called to update AXI_STRB_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_STRB_WIDTH { PARAM_VALUE.AXI_STRB_WIDTH } {
	# Procedure called to validate AXI_STRB_WIDTH
	return true
}

proc update_PARAM_VALUE.BAR2_ENABLED { PARAM_VALUE.BAR2_ENABLED } {
	# Procedure called to update BAR2_ENABLED when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BAR2_ENABLED { PARAM_VALUE.BAR2_ENABLED } {
	# Procedure called to validate BAR2_ENABLED
	return true
}

proc update_PARAM_VALUE.BUFFES_SIZE_LOG_OF2 { PARAM_VALUE.BUFFES_SIZE_LOG_OF2 } {
	# Procedure called to update BUFFES_SIZE_LOG_OF2 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BUFFES_SIZE_LOG_OF2 { PARAM_VALUE.BUFFES_SIZE_LOG_OF2 } {
	# Procedure called to validate BUFFES_SIZE_LOG_OF2
	return true
}

proc update_PARAM_VALUE.C_DATA_WIDTH { PARAM_VALUE.C_DATA_WIDTH } {
	# Procedure called to update C_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_DATA_WIDTH { PARAM_VALUE.C_DATA_WIDTH } {
	# Procedure called to validate C_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.KEEP_WIDTH { PARAM_VALUE.KEEP_WIDTH } {
	# Procedure called to update KEEP_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.KEEP_WIDTH { PARAM_VALUE.KEEP_WIDTH } {
	# Procedure called to validate KEEP_WIDTH
	return true
}

proc update_PARAM_VALUE.MAX_USER_RX_REQUEST_SIZE { PARAM_VALUE.MAX_USER_RX_REQUEST_SIZE } {
	# Procedure called to update MAX_USER_RX_REQUEST_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_USER_RX_REQUEST_SIZE { PARAM_VALUE.MAX_USER_RX_REQUEST_SIZE } {
	# Procedure called to validate MAX_USER_RX_REQUEST_SIZE
	return true
}

proc update_PARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST { PARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST } {
	# Procedure called to update NUM_NUM_OF_USER_RX_PENDINNG_REQUEST when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST { PARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST } {
	# Procedure called to validate NUM_NUM_OF_USER_RX_PENDINNG_REQUEST
	return true
}

proc update_PARAM_VALUE.NUM_OF_C2S_CHAN { PARAM_VALUE.NUM_OF_C2S_CHAN } {
	# Procedure called to update NUM_OF_C2S_CHAN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_OF_C2S_CHAN { PARAM_VALUE.NUM_OF_C2S_CHAN } {
	# Procedure called to validate NUM_OF_C2S_CHAN
	return true
}

proc update_PARAM_VALUE.NUM_OF_INTERRUPTS { PARAM_VALUE.NUM_OF_INTERRUPTS } {
	# Procedure called to update NUM_OF_INTERRUPTS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_OF_INTERRUPTS { PARAM_VALUE.NUM_OF_INTERRUPTS } {
	# Procedure called to validate NUM_OF_INTERRUPTS
	return true
}

proc update_PARAM_VALUE.NUM_OF_S2C_CHAN { PARAM_VALUE.NUM_OF_S2C_CHAN } {
	# Procedure called to update NUM_OF_S2C_CHAN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_OF_S2C_CHAN { PARAM_VALUE.NUM_OF_S2C_CHAN } {
	# Procedure called to validate NUM_OF_S2C_CHAN
	return true
}

proc update_PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE { PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE } {
	# Procedure called to update ONE_USEC_PER_BUS_CYCLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE { PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE } {
	# Procedure called to validate ONE_USEC_PER_BUS_CYCLE
	return true
}

proc update_PARAM_VALUE.SWAP_ENDIAN { PARAM_VALUE.SWAP_ENDIAN } {
	# Procedure called to update SWAP_ENDIAN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SWAP_ENDIAN { PARAM_VALUE.SWAP_ENDIAN } {
	# Procedure called to validate SWAP_ENDIAN
	return true
}


proc update_MODELPARAM_VALUE.NUM_OF_INTERRUPTS { MODELPARAM_VALUE.NUM_OF_INTERRUPTS PARAM_VALUE.NUM_OF_INTERRUPTS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_OF_INTERRUPTS}] ${MODELPARAM_VALUE.NUM_OF_INTERRUPTS}
}

proc update_MODELPARAM_VALUE.BAR2_ENABLED { MODELPARAM_VALUE.BAR2_ENABLED PARAM_VALUE.BAR2_ENABLED } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BAR2_ENABLED}] ${MODELPARAM_VALUE.BAR2_ENABLED}
}

proc update_MODELPARAM_VALUE.NUM_OF_S2C_CHAN { MODELPARAM_VALUE.NUM_OF_S2C_CHAN PARAM_VALUE.NUM_OF_S2C_CHAN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_OF_S2C_CHAN}] ${MODELPARAM_VALUE.NUM_OF_S2C_CHAN}
}

proc update_MODELPARAM_VALUE.NUM_OF_C2S_CHAN { MODELPARAM_VALUE.NUM_OF_C2S_CHAN PARAM_VALUE.NUM_OF_C2S_CHAN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_OF_C2S_CHAN}] ${MODELPARAM_VALUE.NUM_OF_C2S_CHAN}
}

proc update_MODELPARAM_VALUE.C_DATA_WIDTH { MODELPARAM_VALUE.C_DATA_WIDTH PARAM_VALUE.C_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_DATA_WIDTH}] ${MODELPARAM_VALUE.C_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI4_CQ_TUSER_WIDTH { MODELPARAM_VALUE.AXI4_CQ_TUSER_WIDTH PARAM_VALUE.AXI4_CQ_TUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI4_CQ_TUSER_WIDTH}] ${MODELPARAM_VALUE.AXI4_CQ_TUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI4_RQ_TUSER_WIDTH { MODELPARAM_VALUE.AXI4_RQ_TUSER_WIDTH PARAM_VALUE.AXI4_RQ_TUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI4_RQ_TUSER_WIDTH}] ${MODELPARAM_VALUE.AXI4_RQ_TUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI4_RC_TUSER_WIDTH { MODELPARAM_VALUE.AXI4_RC_TUSER_WIDTH PARAM_VALUE.AXI4_RC_TUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI4_RC_TUSER_WIDTH}] ${MODELPARAM_VALUE.AXI4_RC_TUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.KEEP_WIDTH { MODELPARAM_VALUE.KEEP_WIDTH PARAM_VALUE.KEEP_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.KEEP_WIDTH}] ${MODELPARAM_VALUE.KEEP_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI_ID_WIDTH { MODELPARAM_VALUE.AXI_ID_WIDTH PARAM_VALUE.AXI_ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_ID_WIDTH}] ${MODELPARAM_VALUE.AXI_ID_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI_ADDR_WIDTH { MODELPARAM_VALUE.AXI_ADDR_WIDTH PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI_DATA_WIDTH { MODELPARAM_VALUE.AXI_DATA_WIDTH PARAM_VALUE.AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI_STRB_WIDTH { MODELPARAM_VALUE.AXI_STRB_WIDTH PARAM_VALUE.AXI_STRB_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_STRB_WIDTH}] ${MODELPARAM_VALUE.AXI_STRB_WIDTH}
}

proc update_MODELPARAM_VALUE.ONE_USEC_PER_BUS_CYCLE { MODELPARAM_VALUE.ONE_USEC_PER_BUS_CYCLE PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE}] ${MODELPARAM_VALUE.ONE_USEC_PER_BUS_CYCLE}
}

proc update_MODELPARAM_VALUE.SWAP_ENDIAN { MODELPARAM_VALUE.SWAP_ENDIAN PARAM_VALUE.SWAP_ENDIAN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SWAP_ENDIAN}] ${MODELPARAM_VALUE.SWAP_ENDIAN}
}

proc update_MODELPARAM_VALUE.MAX_USER_RX_REQUEST_SIZE { MODELPARAM_VALUE.MAX_USER_RX_REQUEST_SIZE PARAM_VALUE.MAX_USER_RX_REQUEST_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_USER_RX_REQUEST_SIZE}] ${MODELPARAM_VALUE.MAX_USER_RX_REQUEST_SIZE}
}

proc update_MODELPARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST { MODELPARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST PARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST}] ${MODELPARAM_VALUE.NUM_NUM_OF_USER_RX_PENDINNG_REQUEST}
}

proc update_MODELPARAM_VALUE.BUFFES_SIZE_LOG_OF2 { MODELPARAM_VALUE.BUFFES_SIZE_LOG_OF2 PARAM_VALUE.BUFFES_SIZE_LOG_OF2 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BUFFES_SIZE_LOG_OF2}] ${MODELPARAM_VALUE.BUFFES_SIZE_LOG_OF2}
}

