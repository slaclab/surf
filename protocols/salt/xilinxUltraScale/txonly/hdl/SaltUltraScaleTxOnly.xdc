
####################################################################################
# Generated by Vivado 2015.3 built on 'Mon Sep 28 20:06:43 MDT 2015' by 'xbuild'
# Command Used: write_xdc -force C:/Users/ruckman/Desktop/constrs_1.xdc
####################################################################################


####################################################################################
# Constraints from file : 'SaltUltraScaleCore_board.xdc'
####################################################################################

#--------------------Physical Constraints-----------------
##++ tx and rx LOC constraints not loaded in board flow for custom mode

##++ mgt clk LOC constraints not loaded in board flow for custom mode





####################################################################################
# Constraints from file : 'SaltUltraScaleCore_ooc.xdc'
####################################################################################


# This constraints file contains default clock frequencies to be used during creation of a
# Synthesis Design Checkpoint (DCP). For best results the frequencies should be modified
# to match the target frequencies.
# This constraints file is not used in top-down/global synthesis (not the default flow of Vivado).

#################
#DEFAULT CLOCK CONSTRAINTS

############################################################
# Clock Period Constraints                                 #
############################################################



create_clock -period 8.000 -name clk125m [get_ports clk125m]
# constraints for Native mode of LVDS solution
# constraints for Component mode of LVDS solution
create_generated_clock -name clk312 -source [get_ports clk125m] -divide_by 2 -multiply_by 5 [get_ports clk312]
create_generated_clock -name clk625 -source [get_ports clk125m] -multiply_by 5 [get_ports clk625]




####################################################################################
# Constraints from file : 'SaltUltraScaleCore.xdc'
####################################################################################


# false path constraints to async inputs coming directly to synchronizer
set_false_path -to [get_pins -hier -filter {name =~ *SYNC_*/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ *SYNC_*/reset_sync*/PRE }]

set_false_path -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/*_dom_ch_reg/D }]
# set_false_path -to [get_pins -hier -filter {name =~  */lvds_transceiver_mw/serdes_1_to_10_ser8_i/rxclk_r_reg/D}]

# set_false_path -from [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/loop0[*].dataout_reg[*]/D }]
set_false_path -from [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/loop0[*].dataout_reg[*]/D }]
# set_false_path -from [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/rxdh*/D }]
# set_false_path -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/iserdes_m/RST }]
# set_false_path -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/iserdes_s/RST }]
set_false_path -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/oserdes_m/RST }]
set_false_path -to [get_pins -hier -filter {name =~ */*sync_speed_10*/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ */*gen_sync_reset/reset_sync*/PRE }]
set_false_path -to [get_pins -hier -filter { name =~ */*reset_sync_inter*/*sync*/PRE }]
set_false_path -to [get_pins -hier -filter { name =~ */*reset_sync_output_cl*/*sync*/PRE }]
# set_false_path -to [get_pins -hier -filter { name =~ */*reset_sync_rxclk_div*/*sync*/PRE }]
# set_false_path -to [get_pins -hier -filter { name =~ */*reset_rxclk_div*/*sync*/PRE }]

set_false_path -from [get_pins -hier -filter {name =~  */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/read_enable_reg/C}] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/read_enable_dom_ch_reg/D}]
# set_false_path -from [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/read_enable_reg/C}] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/read_enabler_reg/D}]




# Vivado Generated miscellaneous constraints 

#revert back to original instance
current_instance -quiet
