## LLR - 17JULY2019
## After generating each of the .DCP files from their corresponding .XCI files, 
## performed the following TCL commands in the DCP to generate a modified DCP file:

# Remove the IO Lock Constraints
set_property is_loc_fixed false [get_ports [list  gt_txp_out[0]]]
set_property is_loc_fixed false [get_ports [list  gt_txn_out[0]]]
set_property is_loc_fixed false [get_ports [list  gt_rxp_in[0]]]
set_property is_loc_fixed false [get_ports [list  gt_rxn_in[0]]]

# Removed the IO location Constraints
set_property package_pin "" [get_ports [list  gt_txp_out[0]]]
set_property package_pin "" [get_ports [list  gt_txn_out[0]]]
set_property package_pin "" [get_ports [list  gt_rxp_in[0]]]
set_property package_pin "" [get_ports [list  gt_rxn_in[0]]]

# Removed the Placement Constraints
set_property is_bel_fixed false [get_cells -hierarchical *GTHE4_CHANNEL_PRIM_INST*]
set_property is_loc_fixed false [get_cells -hierarchical *GTHE4_CHANNEL_PRIM_INST*]
unplace_cell [get_cells -hierarchical *GTHE4_CHANNEL_PRIM_INST*]
