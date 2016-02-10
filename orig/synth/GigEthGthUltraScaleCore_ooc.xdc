
# This constraints file contains default clock frequencies to be used during creation of a 
# Synthesis Design Checkpoint (DCP). For best results the frequencies should be modified 
# to match the target frequencies. 
# This constraints file is not used in top-down/global synthesis (not the default flow of Vivado).

#################
#DEFAULT CLOCK CONSTRAINTS

############################################################
# Clock Period Constraints                                 #
############################################################



create_clock -name gtrefclk -period 8.00 [get_ports gtrefclk]
#-----------------------------------------------------------
# PCS/PMA Clock period Constraints: please do not relax    -
#-----------------------------------------------------------

create_clock -name userclk -period 16.000 [get_ports userclk]
create_clock -name userclk2 -period 8.000 [get_ports userclk2]

create_clock -name rxuserclk -period 16.000 [get_ports rxuserclk]
create_clock -name rxuserclk2 -period 16.000 [get_ports rxuserclk2]


 
create_clock -name independent_clock_bufg -period 16.00 [get_ports independent_clock_bufg]



