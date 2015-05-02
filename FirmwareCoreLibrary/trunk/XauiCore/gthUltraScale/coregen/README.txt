## LLR - 01MAY2015
## After generating each of the .DCP files from their corresponding .XCI files, 
## performed the following TCL commands in the DCP to generate a modified DCP file:

# Remove the IO Lock Constraints
set_property is_loc_fixed false [get_ports [list  xaui_rx_l0_p]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l1_p]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l2_p]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l3_p]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l0_p]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l1_p]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l2_p]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l3_p]]

set_property is_loc_fixed false [get_ports [list  xaui_rx_l0_n]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l1_n]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l2_n]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l3_n]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l0_n]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l1_n]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l2_n]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l3_n]]

# Removed the IO location Constraints
set_property package_pin "" [get_ports [list  xaui_rx_l0_p]]
set_property package_pin "" [get_ports [list  xaui_rx_l1_p]]
set_property package_pin "" [get_ports [list  xaui_rx_l2_p]]
set_property package_pin "" [get_ports [list  xaui_rx_l3_p]]
set_property package_pin "" [get_ports [list  xaui_tx_l0_p]]
set_property package_pin "" [get_ports [list  xaui_tx_l1_p]]
set_property package_pin "" [get_ports [list  xaui_tx_l2_p]]
set_property package_pin "" [get_ports [list  xaui_tx_l3_p]]

set_property package_pin "" [get_ports [list  xaui_rx_l0_n]]
set_property package_pin "" [get_ports [list  xaui_rx_l1_n]]
set_property package_pin "" [get_ports [list  xaui_rx_l2_n]]
set_property package_pin "" [get_ports [list  xaui_rx_l3_n]]
set_property package_pin "" [get_ports [list  xaui_tx_l0_n]]
set_property package_pin "" [get_ports [list  xaui_tx_l1_n]]
set_property package_pin "" [get_ports [list  xaui_tx_l2_n]]
set_property package_pin "" [get_ports [list  xaui_tx_l3_n]]

# Removed the Placement Constraints
set_property is_bel_fixed false [get_cells -hierarchical *GTHE3_CHANNEL_PRIM_INST*]
set_property is_loc_fixed false [get_cells -hierarchical *GTHE3_CHANNEL_PRIM_INST*]
unplace_cell [get_cells -hierarchical *GTHE3_CHANNEL_PRIM_INST*]