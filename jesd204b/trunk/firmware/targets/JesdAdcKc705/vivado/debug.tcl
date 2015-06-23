

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


ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[1].Gtx7Core_Inst/rxDispErrOut[*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[1].Gtx7Core_Inst/rxDecErrOut[*]}

ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[1].Gtx7Core_Inst/rxDataOut[*]}
ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/GT_OPER_GEN.GTX7_CORE_GEN[1].Gtx7Core_Inst/rxCharIsKOut[*]}

ConfigProbe ${ilaJesdClk} {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[1].AxiStreamLaneTx_INST/sampleData_i[*]}


delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaJesdClk}]]

# Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug_probes.ltx

