

# User Debug Script

# Open the run
open_run synth_1

# Configure the Core
set ilaJesdClk u_ila_0
#set ilaName1 u_ila_1

# Create 1st Debug Core
CreateDebugCore ${ilaJesdClk}

SetDebugCoreClk ${ilaJesdClk} {gpioClk_OBUF}

set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaJesdClk}]

ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[0].Gtx7Core_Inst/r_jesdGtRxArr[0][dispErr][*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[0].Gtx7Core_Inst/rxCharIsKOut[*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[0].Gtx7Core_Inst/statusRxArr_i[0][*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[0].Gtx7Core_Inst/r_jesdGtRxArr[0][decErr][*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[0].Gtx7Core_Inst/rxDataOut[*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/Jesd204b_INST/statusRxArr_i[0][*]} 
ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[0].Gtx7Core_Inst/rxUserResetIn}

delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaJesdClk}]]

# Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug_probes.ltx

