

#-----------------------------------------------------------
# PCS/PMA Clock period Constraints: please do not relax    -
#-----------------------------------------------------------
# Clock period for the recovered Rx clock
create_clock -period 16.000 [get_pins -hier -filter { name =~ */transceiver_inst/GigEthGthUltraScaleCore_gt_i/inst/rxoutclk_out* }]




# false path constraints to async inputs coming directly to synchronizer
set_false_path -to [get_pins -hier -filter {name =~ *SYNC_*/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ */sync_block_reset_done/data_sync_reg1/D }]
set_false_path -to [get_pins -hier -filter {name =~ *reset_sync*/PRE }]





