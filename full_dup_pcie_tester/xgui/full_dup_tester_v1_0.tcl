# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_STRB_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CHAN_NUM" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ONE_USEC_PER_BUS_CYCLE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PCIE_CORE_DATA_WIDTH" -parent ${Page_0}


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

proc update_PARAM_VALUE.AXI_STRB_WIDTH { PARAM_VALUE.AXI_STRB_WIDTH } {
	# Procedure called to update AXI_STRB_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_STRB_WIDTH { PARAM_VALUE.AXI_STRB_WIDTH } {
	# Procedure called to validate AXI_STRB_WIDTH
	return true
}

proc update_PARAM_VALUE.CHAN_NUM { PARAM_VALUE.CHAN_NUM } {
	# Procedure called to update CHAN_NUM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CHAN_NUM { PARAM_VALUE.CHAN_NUM } {
	# Procedure called to validate CHAN_NUM
	return true
}

proc update_PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE { PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE } {
	# Procedure called to update ONE_USEC_PER_BUS_CYCLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE { PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE } {
	# Procedure called to validate ONE_USEC_PER_BUS_CYCLE
	return true
}

proc update_PARAM_VALUE.PCIE_CORE_DATA_WIDTH { PARAM_VALUE.PCIE_CORE_DATA_WIDTH } {
	# Procedure called to update PCIE_CORE_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PCIE_CORE_DATA_WIDTH { PARAM_VALUE.PCIE_CORE_DATA_WIDTH } {
	# Procedure called to validate PCIE_CORE_DATA_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.CHAN_NUM { MODELPARAM_VALUE.CHAN_NUM PARAM_VALUE.CHAN_NUM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CHAN_NUM}] ${MODELPARAM_VALUE.CHAN_NUM}
}

proc update_MODELPARAM_VALUE.PCIE_CORE_DATA_WIDTH { MODELPARAM_VALUE.PCIE_CORE_DATA_WIDTH PARAM_VALUE.PCIE_CORE_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PCIE_CORE_DATA_WIDTH}] ${MODELPARAM_VALUE.PCIE_CORE_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.ONE_USEC_PER_BUS_CYCLE { MODELPARAM_VALUE.ONE_USEC_PER_BUS_CYCLE PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ONE_USEC_PER_BUS_CYCLE}] ${MODELPARAM_VALUE.ONE_USEC_PER_BUS_CYCLE}
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

