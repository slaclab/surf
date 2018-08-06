Refer to https://github.com/slaclab/surf-dcp-targets/tree/master/firmware/dcp/GigEthGtyUltraScale+/ for original source code

# Remove the IO Lock Constraints
set_property is_loc_fixed false [get_ports [list  rxp]]
set_property is_loc_fixed false [get_ports [list  rxn]]
set_property is_loc_fixed false [get_ports [list  txp]]
set_property is_loc_fixed false [get_ports [list  txn]]

# Removed the IO location Constraints
set_property package_pin "" [get_ports [list  rxp]]
set_property package_pin "" [get_ports [list  rxn]]
set_property package_pin "" [get_ports [list  txp]]
set_property package_pin "" [get_ports [list  txn]]

# Removed the Placement Constraints
set_property is_bel_fixed false [get_cells -hierarchical *GTYE4_CHANNEL_PRIM_INST*]
set_property is_loc_fixed false [get_cells -hierarchical *GTYE4_CHANNEL_PRIM_INST*]
unplace_cell [get_cells -hierarchical *GTYE4_CHANNEL_PRIM_INST*]
