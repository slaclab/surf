#create_generated_clock -name PGP_GT_RXOUTCLK -add \
#    [get_pins -hier -filter {NAME =~ */RXOUTCLK}]

#create_generated_clock -name PGP_GT_TXOUTCLK -add \
#    [get_pins -hier -filter {NAME =~ */TXOUTCLK}]

#set_clock_groups -asynchronous \
#    -group [get_clocks {PGP_GT_RXOUTCLK} -include_generated_clocks] \
#    -group [get_clocks {PGP_GT_TXOUTCLK} -include_generated_clocks] \    
