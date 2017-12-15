## LLR - 05MAY2015
## After generating each of the .DCP files from their corresponding .XCI files, 
## performed the following TCL commands in the DCP to generate a modified DCP file:

# Remove the IO Lock Constraints
set_property is_loc_fixed false [get_ports [list  txp]]
set_property is_loc_fixed false [get_ports [list  txn]]
set_property is_loc_fixed false [get_ports [list  rxp]]
set_property is_loc_fixed false [get_ports [list  rxn]]

# Removed the IO location Constraints
set_property package_pin "" [get_ports [list  txp]]
set_property package_pin "" [get_ports [list  txn]]
set_property package_pin "" [get_ports [list  rxp]]
set_property package_pin "" [get_ports [list  rxn]]

# Removed the Placement Constraints
set_property is_bel_fixed false [get_cells -hierarchical *GTHE3_CHANNEL_PRIM_INST*]
set_property is_loc_fixed false [get_cells -hierarchical *GTHE3_CHANNEL_PRIM_INST*]
unplace_cell [get_cells -hierarchical *GTHE3_CHANNEL_PRIM_INST*]
