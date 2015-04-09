LLR - 09APRIL2014
After generating the original DCP file from coregen/TenGigEthGthUltraScaleCore.xci, performed the following TCL commands in the DCP to generate a modified DCP file:

# Remove the Lock Constraints
set_property is_bel_fixed false [get_cells [list {U0/TenGigEthGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.TenGigEthGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]]
set_property is_loc_fixed false [get_cells [list {U0/TenGigEthGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.TenGigEthGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]]

unplace_cell  [get_cells [list  {U0/TenGigEthGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.TenGigEthGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}] -filter {((is_primitive==true && primitive_level!="INTERNAL")  && (loc!=""))}]

set_property is_loc_fixed false [get_ports [list  txp]]
set_property is_loc_fixed false [get_ports [list  txn]]
set_property is_loc_fixed false [get_ports [list  rxp]]
set_property is_loc_fixed false [get_ports [list  rxn]]

set_property package_pin "" [get_ports [list  txp]]
set_property package_pin "" [get_ports [list  txn]]
set_property package_pin "" [get_ports [list  rxp]]
set_property package_pin "" [get_ports [list  rxn]]
