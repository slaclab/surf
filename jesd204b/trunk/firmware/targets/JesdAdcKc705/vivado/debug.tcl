

# User Debug Script

# Open the run
open_run synth_1

# Configure the Core
set ilaJesdClk u_ila_0
#set ilaName1 u_ila_1

# Create 1st Debug Core
CreateDebugCore ${ilaJesdClk}

SetDebugCoreClk ${ilaJesdClk} {jesdClk}

set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaJesdClk}]


ConfigProbe ${ilaJesdClk} {Jesd204bGthRxUltra_INST/GT_OPER_GEN.GthUltrascaleJesdCoregen_INST/gtwiz_userdata_rx_out[*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGthRxUltra_INST/GT_OPER_GEN.GthUltrascaleJesdCoregen_INST/rxctrl0_out[*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGthRxUltra_INST/GT_OPER_GEN.GthUltrascaleJesdCoregen_INST/rxctrl1_out[*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGthRxUltra_INST/GT_OPER_GEN.GthUltrascaleJesdCoregen_INST/rxctrl3_out[*]}

delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaJesdClk}]]

# Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug_probes.ltx

