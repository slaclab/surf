
#-----------------------------------------------------------
# PCS/PMA Clock period Constraints: please do not relax    -
#-----------------------------------------------------------


  # Clock period for the Txout clock
  create_clock  -period 16.000 [get_pins -hier -filter {name =~ *transceiver_inst/gtwizard_inst/*/gtwizard_i/gt0_GTWIZARD_i/gthe2_i/TXOUTCLK}]
  

  #-----------------------------------------------------------
  # Receive Clock period Constraint: please do not relax
  #-----------------------------------------------------------
  # Clock period for the recovered Rx clock
  create_clock  -period 16.000 [get_pins -hier -filter { name =~ *transceiver_inst/gtwizard_inst/*/gtwizard_i/gt0_GTWIZARD_i/gthe2_i/RXOUTCLK}]



#***********************************************************
# The following constraints target the Transceiver Physical*
# Interface which is instantiated in the Example Design.   *
#***********************************************************


#-----------------------------------------------------------
# PCS/PMA Clock period Constraints: please do not relax    -
#-----------------------------------------------------------





#-----------------------------------------------------------
# GT Initialization circuitry clock domain crossing
#-----------------------------------------------------------

set_false_path -to [get_pins -hier -filter { name =~ */gtwizard_inst/*/gt0_txresetfsm_i/sync_*/*D } ]
set_false_path -to [get_pins -hier -filter { name =~ */gtwizard_inst/*/gt0_rxresetfsm_i/sync_*/*D } ]

set_false_path -to [get_pins -hier -filter { name =~ */gtwizard_inst/*/sync_*/*D } ]

set_false_path -to [get_pins -hier -filter { name =~ */gtwizard_inst/*/gtwizard_i/gt0_GTWIZARD_i/gtrxreset_seq_i/sync_*/*D } ]


# false path constraints to async inputs coming directly to synchronizer
set_false_path -to [get_pins -hier -filter {name =~ *SYNC_*/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ *transceiver_inst/sync_block_data_valid/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ *sync_block_tx_reset_done/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ *sync_block_rx_reset_done/data_sync*/D }]



set_false_path -to [get_pins -hier -filter {name =~ *reset_sync*/PRE }]


