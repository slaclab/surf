

# User Debug Script

# Open the run
open_run synth_1

# Configure the Core
set ilaPgpClk u_ila_0
#set ilaName1 u_ila_1

# Create 1st Debug Core
CreateDebugCore ${ilaPgpClk}

SetDebugCoreClk ${ilaPgpClk} {pgpClk}

set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaPgpClk}]


ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/gtwiz_userdata_rx_out[*]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/rxbyteisaligned_out[0]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/rxbyterealign_out[0]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/rxcommadet_out[0]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/rxctrl0_out[*]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/rxctrl1_out[*]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/rxctrl3_out[*]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/rxpmaresetdone_out[0]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/gtwiz_reset_rx_done_out[0]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/U_PgpGthCore/gtwiz_reset_rx_cdr_stable_out[0]}

ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[opCode][*]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[remLinkData][*]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[remOverflow][*]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[remPause][*]}

ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[cellError]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[frameRx]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[frameRxErr]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[linkDown]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[linkError]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[linkReady]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[opCodeEn]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/pgpRxOut[remLinkReady]}

ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/rxReset}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/PgpGthCoreWrapper_1/rxResetDone}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/Pgp2bAxi_1/pgpRxIn[resetRx]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/Pgp2bAxi_1/pgpRxIn[flush]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/phyRxInit}

ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/stateCnt_reg[*]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/rxDetectLtsOk}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/rxDetectLts}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/phyRxPolarity[0]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/rxDetectInvert_reg_n_6_[0]}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/rxDetectInvert[0]_i_1_n_6}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/rxDetectInvert[0]_i_2_n_6}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/rxDetectInvert[0]_i_3_n_6}
ConfigProbe ${ilaPgpClk} {PgpFrontEnd_1/REAL_PGP.Pgp2bGthUltra_1/U_Pgp2bLane/U_RxEnGen.U_Pgp2bRx/U_Pgp2bRxPhy/dly0RxData[*]}

delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaPgpClk}]]




# Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug_probes.ltx
