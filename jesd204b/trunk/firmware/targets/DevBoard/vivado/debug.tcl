

# User Debug Script

# Open the run
open_run synth_1

# Configure the Core
set ilaPgpClk u_ila_0
#set ilaName1 u_ila_1

# Create 1st Debug Core
CreateDebugCore ${ilaPgpClk}

SetDebugCoreClk ${ilaPgpClk} {axiClk}

set_property C_DATA_DEPTH 1024 [get_debug_cores ${ilaPgpClk}]

#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpRxIn*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpRxOut*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpTxIn*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpTxOut*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpVcTxQuadIn[0]*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpVcTxQuadIn[1]*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpVcTxQuadOut[0]*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpVcTxQuadOut[1]*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpVcRxCommonOut*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpVcRxQuadOut[0]*}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/pgpVcRxQuadOut[1]*}

# #  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxPllResets[*]}
#  #ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxPllReset}
#  #ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/pllRefClkLost}
#  #ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxPllLock}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtRxReset}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxResetDone}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxUserRdyInt}
#  #ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxUserResetInt}
#  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxFsmResetDone}
# # ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxRstTxUserRdy}
# #  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxPmaResetDone}
# #  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxCdrLock}
# #  ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxCdrLockCnt[*]}
# # ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxDataOut[*]}
# # ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxCharIsKOut*}
# # ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxDecErrOut*}
# #ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/rxDispErrOut*}

# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/pgpRxMmcmResets*}
# #ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/gtRxResetDone*}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/gtRxUserReset*}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/gtRxUserResetIn*}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/phyRxLanesIn*}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/phyRxLanesOut*}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/phyRxReady*}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/phyRxInit*}

# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/softResetSync}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/resetDoneSync}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/pllRefClkLostSync}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/pllLockSync}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/pllLockRise}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/pmaResetDoneSync}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/pmaResetDoneFall}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/mmcmLockedSync}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/phaseAlignmentTimeoutSync}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/dataValidSync}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/Pgp2Gtp7MultiLane_1/GTP7_CORE_GEN[0].Gtp7Core_Inst/*/Gtp7RstFsm_1/r[*]}

# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/VcAxiMaster_Reg/r[*]}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/VcAxiMaster_Reg/axiReadSlave[*]}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/VcAxiMaster_Reg/axiWriteSlave[*]}
# ConfigProbe ${ilaPgpClk} {PgpFrontEndTest_1/VcAxiMaster_Reg/regSlaveOut[*]}

 ConfigProbe ${ilaPgpClk} {HpsFrontEndCore_1/BoardI2cAxiBridge/axiReadMaster[*]}
 ConfigProbe ${ilaPgpClk} {HpsFrontEndCore_1/BoardI2cAxiBridge/axiReadSlave[*]}
 #ConfigProbe ${ilaPgpClk} {HpsFrontEndCore_1/BoardI2cAxiBridge/axiWriteMaster[*]}
 #ConfigProbe ${ilaPgpClk} {HpsFrontEndCore_1/BoardI2cAxiBridge/axiWriteSlave[*]}
 ConfigProbe ${ilaPgpClk} {HpsFrontEndCore_1/BoardI2cAxiBridge/i2cRegMasterOut[*]}
 ConfigProbe ${ilaPgpClk} {HpsFrontEndCore_1/BoardI2cAxiBridge/i2cRegMasterIn[*]}

#ConfigProbe ${ilaPgpClk} {boardI2cSda}
ConfigProbe ${ilaPgpClk} {boardI2cOut[*]}
ConfigProbe ${ilaPgpClk} {n_0_bus_status_ctrl.staticfilt.sfblock.sSCL_reg[0]_i_2}
ConfigProbe ${ilaPgpClk} {n_0_bus_status_ctrl.staticfilt.sfblock.sSDA_reg[0]_i_2}



delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaPgpClk}]]

# Create 2nd Debug Core
# CreateDebugCore ${ilaName1}

# SetDebugCoreClk ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/STABLE_CLOCK

# ConfigProbe ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/rx_state[*]
# ConfigProbe ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/retry_counter_int[*]
# ConfigProbe ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/recclk_mon_restart_count[*]
# ConfigProbe ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/data_valid_sync
# ConfigProbe ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/reset_time_out
# ConfigProbe ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/time_out_wait_bypass_s3
# ConfigProbe ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/phalignment_done_sync
# ConfigProbe ${ilaName1} GLinkGtx7FixedLatWrapper_Inst/GLinkGtx7FixedLat_Inst/Gtx7Core_Inst/Gtx7RxRst_Inst/reset_time_out

#delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]

# Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx

